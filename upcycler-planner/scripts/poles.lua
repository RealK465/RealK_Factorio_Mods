-- Places electric poles over a finished plan: enough of them, wired into one network, that
-- every machine, recycler and inserter has power -- belts, chests and pipes need none. PURE,
-- the same contract as layout.lua: no storage, no game state, so the same plan grows the same
-- poles on every client.
--
-- Deliberately blind to layout.lua's row plan: it asks "is this tile free?", discovered from
-- the plan's own entities, never "where is the buffer sub-column?". The one thing it accepts
-- from the layout is the utility-column list -- the dedicated columns the plan already sized
-- to the pole -- so poles prefer a tidy vertical line there and fall back to any free tile
-- only when the columns alone cannot cover.
--
-- Cover, then connect, then be honest. A greedy set cover picks positions (within ln(n)+1 of
-- the true minimum, which is NP-hard and nothing this small needs), a bridge pass joins stray
-- islands, and the reported shortfall counts a consumer as powered only when a pole of the
-- LARGEST connected network reaches it -- a covered consumer on an unwired island would be a
-- lie that only surfaces in game as a mystery.

local poles = {}

-- The engine powers a consumer when its collision box OVERLAPS the supply square (measured,
-- api.md S10). Each consumer therefore carries a stand-in for its collision box -- its tile
-- rect shrunk by the margin the planner computed from the real prototype, always a SUBSET of
-- the real box -- so the test can under-promise (an extra pole, an over-honest warning) but
-- never credit a pole with a machine the game would leave dark.

-- Strict inequalities: an area that merely touches at the border covers nothing.
local function overlap(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
  return ax0 < bx1 and bx0 < ax1 and ay0 < by1 and by0 < ay1
end

-- Centres follow builder.position_of's rule -- half a footprint in -- so odd sizes sit
-- mid-tile and even ones on a tile boundary, and the supply square shifts with them.
local function centre_of(p, pole)
  return p.dx + pole.width / 2, p.dy + pole.height / 2
end

local function covers(pole, p, consumer)
  local cx, cy = centre_of(p, pole)
  local d = pole.supply_distance
  local m = consumer.margin
  return overlap(cx - d, cy - d, cx + d, cy + d,
    consumer.dx + m, consumer.dy + m,
    consumer.dx + consumer.w - m, consumer.dy + consumer.h - m)
end

-- Centre-to-centre, squared to skip the sqrt -- shared by the reach test and the
-- spanning-tree search.
local function distance_sq(pole, a, b)
  local ax, ay = centre_of(a, pole)
  local bx, by = centre_of(b, pole)
  return (ax - bx) ^ 2 + (ay - by) ^ 2
end

-- An approximation of wherever the engine anchors its wire ends, but only the planning
-- estimate leans on it -- the builder's connect_to keeps reach_check on, so the engine has
-- the final word on every wire.
local function within_wire_reach(pole, a, b)
  return distance_sq(pole, a, b) <= pole.wire_distance ^ 2
end

local function occupied(entities)
  local occ = {}
  for _, e in pairs(entities) do
    for x = e.dx, e.dx + e.w - 1 do
      local column = occ[x]
      if not column then
        column = {}
        occ[x] = column
      end
      for y = e.dy, e.dy + e.h - 1 do column[y] = true end
    end
  end
  return occ
end

local function consumers_of(entities, consumer_margins)
  local out = {}
  for _, e in pairs(entities) do
    local margin = consumer_margins[e.name]
    if margin then
      out[#out + 1] = { dx = e.dx, dy = e.dy, w = e.w, h = e.h, margin = margin }
    end
  end
  return out
end

local function fits(occ, width, height, px, py, pole)
  if px < 0 or py < 0 or px + pole.width > width or py + pole.height > height then
    return false
  end
  for x = px, px + pole.width - 1 do
    local column = occ[x]
    if column then
      for y = py, py + pole.height - 1 do
        if column[y] then return false end
      end
    end
  end
  return true
end

-- Row-major scan order is load-bearing: every tie-break below is "first found in this order
-- wins", which is what makes the whole pass deterministic without tie-break tables.
local function candidate_positions(occ, width, height, pole)
  local out = {}
  for py = 0, height - pole.height do
    for px = 0, width - pole.width do
      if fits(occ, width, height, px, py, pole) then out[#out + 1] = { dx = px, dy = py } end
    end
  end
  return out
end

-- The candidates lying wholly inside a utility column -- the pole's own dedicated ground.
-- Pipes already sit in those columns as ordinary occupied tiles, so a fluid plan's east edge
-- excludes itself without this function knowing pipes exist.
local function within_columns(candidates, columns, pole)
  local kept = {}
  for _, c in pairs(candidates) do
    for _, col in pairs(columns) do
      if c.dx >= col.x and c.dx + pole.width <= col.x + col.width then
        kept[#kept + 1] = c
        break
      end
    end
  end
  return kept
end

local function without_overlapping(candidates, taken, pole)
  local kept = {}
  for _, c in pairs(candidates) do
    if not overlap(c.dx, c.dy, c.dx + pole.width, c.dy + pole.height,
      taken.dx, taken.dy, taken.dx + pole.width, taken.dy + pole.height)
    then
      kept[#kept + 1] = c
    end
  end
  return kept
end

-- `>` and never `>=`: the first candidate to reach the best count keeps it.
local function greedy_cover(candidates, consumers, pole)
  local placed = {}
  local uncovered = {}
  for i, consumer in pairs(consumers) do uncovered[i] = consumer end

  while next(uncovered) do
    local best, best_hits, best_count = nil, nil, 0
    for _, candidate in pairs(candidates) do
      local hits, count = {}, 0
      for i, consumer in pairs(uncovered) do
        if covers(pole, candidate, consumer) then
          count = count + 1
          hits[count] = i
        end
      end
      if count > best_count then best, best_hits, best_count = candidate, hits, count end
    end
    if not best then break end
    placed[#placed + 1] = best
    for _, i in pairs(best_hits) do uncovered[i] = nil end
    candidates = without_overlapping(candidates, best, pole)
  end

  return placed, candidates
end

local function components_of(placed, pole)
  local visited, components = {}, {}
  for start = 1, #placed do
    if not visited[start] then
      visited[start] = true
      local component, stack = { start }, { start }
      while #stack > 0 do
        local i = stack[#stack]
        stack[#stack] = nil
        for j = 1, #placed do
          if not visited[j] and within_wire_reach(pole, placed[i], placed[j]) then
            visited[j] = true
            component[#component + 1] = j
            stack[#stack + 1] = j
          end
        end
      end
      components[#components + 1] = component
    end
  end
  return components
end

-- Joins stray islands: repeatedly the free position reaching the most separate components,
-- until one network remains or no position joins two. Terminates because the component count
-- strictly drops on every accepted pole.
local function bridge(placed, candidates, pole)
  local components = components_of(placed, pole)
  while #components > 1 do
    local best, best_touch, best_count = nil, nil, 0
    for _, candidate in pairs(candidates) do
      local touched, count = {}, 0
      for ci, component in pairs(components) do
        for _, i in pairs(component) do
          if within_wire_reach(pole, candidate, placed[i]) then
            touched[ci] = true
            count = count + 1
            break
          end
        end
      end
      if count > best_count then best, best_touch, best_count = candidate, touched, count end
    end
    if best_count < 2 then break end

    placed[#placed + 1] = best
    candidates = without_overlapping(candidates, best, pole)
    local merged, kept = { #placed }, {}
    for ci, component in pairs(components) do
      if best_touch[ci] then
        for _, i in pairs(component) do merged[#merged + 1] = i end
      else
        kept[#kept + 1] = component
      end
    end
    kept[#kept + 1] = merged
    components = kept
  end
end

local function largest_component(components)
  local best, best_size = {}, 0
  for _, component in pairs(components) do
    if #component > best_size then best, best_size = component, #component end
  end
  return best
end

-- One full attempt against one candidate set: cover, bridge, tally.
local function attempt(candidates, consumers, pole)
  local placed, remaining = greedy_cover(candidates, consumers, pole)
  bridge(placed, remaining, pole)

  local main = largest_component(components_of(placed, pole))
  local unpowered = 0
  for _, consumer in pairs(consumers) do
    local hit = false
    for _, i in pairs(main) do
      if covers(pole, placed[i], consumer) then
        hit = true
        break
      end
    end
    if not hit then unpowered = unpowered + 1 end
  end

  return placed, unpowered
end

-- One copper wire per pole, to its nearest already-wired neighbour -- a spanning tree per
-- component rather than a mesh, so the built network reads as a line, not a cobweb. Every
-- chosen edge is within reach: a connected component always has SOME in-reach edge across
-- any cut, and the minimum-distance pair can only be shorter. Computed here rather than in
-- the builder because which pole can reach which is this module's geometry; the builder just
-- executes the list.
local function spanning_wires(placed, pole)
  local wires = {}
  for _, component in pairs(components_of(placed, pole)) do
    local in_tree = { [component[1]] = true }
    for _ = 2, #component do
      local best_from, best_to, best_dist
      for _, i in pairs(component) do
        if not in_tree[i] then
          for _, j in pairs(component) do
            if in_tree[j] then
              local dist = distance_sq(pole, placed[i], placed[j])
              if not best_dist or dist < best_dist then
                best_from, best_to, best_dist = i, j, dist
              end
            end
          end
        end
      end
      in_tree[best_from] = true
      wires[best_from] = best_to
    end
  end
  return wires
end

-- pole: { name, quality, width, height, supply_distance, wire_distance } -- plain values;
-- the planner resolves them, this file never touches prototypes. consumer_margins maps
-- entity names to the collision-box margin their stand-in is shrunk by, false for entities
-- that draw no power.
--
-- Returns { entities, unpowered }: pole entity dicts tagged pole = true, each carrying
-- wire_to -- the index, in their own order, of the pole it wires back to -- and how many
-- consumers no pole of the main network reaches.
function poles.plan(built, pole, consumer_margins)
  local consumers = consumers_of(built.entities, consumer_margins)
  local candidates = candidate_positions(occupied(built.entities), built.width, built.height, pole)

  -- Columns first, free tiles as the honest fallback: the layout already sized the utility
  -- columns to this pole, so the tidy vertical line is the common case -- but a pole whose
  -- supply cannot cover from the columns alone still gets the full free-tile search rather
  -- than a shrug. The fallback is kept only when it powers strictly more, so a tie stays
  -- with the columns.
  local placed, unpowered
  local column_candidates = built.utility_columns
    and within_columns(candidates, built.utility_columns, pole) or {}
  if #column_candidates > 0 then
    placed, unpowered = attempt(column_candidates, consumers, pole)
  end
  if not placed or unpowered > 0 then
    local free_placed, free_unpowered = attempt(candidates, consumers, pole)
    if not placed or free_unpowered < unpowered then
      placed, unpowered = free_placed, free_unpowered
    end
  end

  local wires = spanning_wires(placed, pole)
  local entities = {}
  for i, p in pairs(placed) do
    entities[i] = {
      name = pole.name, quality = pole.quality,
      dx = p.dx, dy = p.dy, w = pole.width, h = pole.height,
      pole = true, wire_to = wires[i],
    }
  end

  return { entities = entities, unpowered = unpowered }
end

return poles
