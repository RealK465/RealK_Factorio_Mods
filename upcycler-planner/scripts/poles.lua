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

-- Centres follow the plan's own rule -- half a footprint in -- so odd sizes sit mid-tile and
-- even ones on a tile boundary, and the supply square shifts with them.
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
-- estimate leans on it -- the blueprint's wires are still subject to the engine's own reach,
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

-- Consumer indices filed by tile column, so a candidate only asks about the consumers its
-- supply square could possibly reach. A consumer is filed under every column its tile rect
-- spans; a candidate queries the columns its supply square spans. That is always a superset
-- of the true answer -- a pole that covers a consumer must overlap it in x, and the margin
-- only ever shrinks the consumer inside the columns it was filed under -- so the list this
-- produces is exactly the list the plain scan produced.
--
-- A plan is one tier column per quality tier, so both the candidates and the consumers grow
-- with the tier count and the plain scan was their product. That was fine while the chain
-- was five tiers and unnoticeable at the 32 the planner used to cap it at; a mod that adds
-- 250 makes it the whole cost of the solve.
local function index_consumers(consumers)
  local columns = {}
  for i = 1, #consumers do
    local c = consumers[i]
    for x = math.floor(c.dx), math.ceil(c.dx + c.w) do
      local bucket = columns[x]
      if not bucket then
        bucket = {}
        columns[x] = bucket
      end
      bucket[#bucket + 1] = i
    end
  end
  return columns
end

-- One solve's derived state: the column index, built once, and the per-candidate coverage
-- lists, filled lazily.
local function memo_for(consumers)
  return { columns = index_consumers(consumers), lists = {} }
end

-- Which consumers a candidate covers, as an array of consumer indices, memoised in
-- `memo.lists` on first use. The geometry never changes while poles are placed -- only
-- membership in `uncovered` does -- so the greedy pass, the free-tile retry and the final
-- honesty tally all share one answer per candidate instead of re-running the overlap
-- arithmetic per round. Lazy rather than precomputed for the whole plan: a solve whose
-- utility columns already cover never asks about the free tiles at all. Keyed by the
-- candidate table itself, which within_columns and without_overlapping both preserve.
--
-- `seen` is not an optimisation. A consumer wider than one tile is filed in several columns,
-- and counting it twice would inflate the greedy pass's gain and change which pole it picks.
local function coverage(memo, pole, candidate, consumers)
  local list = memo.lists[candidate]
  if not list then
    list = {}
    local cx = candidate.dx + pole.width / 2
    local d = pole.supply_distance
    local seen = {}
    for x = math.floor(cx - d), math.ceil(cx + d) do
      local bucket = memo.columns[x]
      if bucket then
        for bi = 1, #bucket do
          local i = bucket[bi]
          if not seen[i] then
            seen[i] = true
            if covers(pole, candidate, consumers[i]) then list[#list + 1] = i end
          end
        end
      end
    end
    memo.lists[candidate] = list
  end
  return list
end

-- `>` and never `>=`: the first candidate to reach the best count keeps it. Iteration is by
-- index on purpose -- the scan-order determinism the candidate list promises must not depend
-- on pairs() happening to walk an array part in order.
local function greedy_cover(candidates, consumers, pole, cover_of)
  local placed = {}
  local uncovered, remaining = {}, #consumers
  for i = 1, #consumers do uncovered[i] = true end

  while remaining > 0 do
    local best, best_count = nil, 0
    for ci = 1, #candidates do
      local list = coverage(cover_of, pole, candidates[ci], consumers)
      -- A candidate's score can never exceed the number of consumers it covers at all, so one
      -- whose whole list is no longer than the incumbent's score cannot beat it -- and the walk
      -- below is the round's inner loop. Skipping it changes no outcome: `count <= #list` always.
      if #list > best_count then
        local count = 0
        for li = 1, #list do
          if uncovered[list[li]] then count = count + 1 end
        end
        if count > best_count then best, best_count = candidates[ci], count end
      end
    end
    if not best then break end
    placed[#placed + 1] = best
    local list = cover_of.lists[best]
    for li = 1, #list do
      local i = list[li]
      if uncovered[i] then
        uncovered[i] = nil
        remaining = remaining - 1
      end
    end
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

  -- Placed poles filed by the column their centre sits in, so scoring a candidate consults the
  -- poles near it instead of every pole in every component. Same superset argument as
  -- coverage's index: a candidate within wire reach of a pole is within wire reach in x alone,
  -- so the pole's centre column lies inside the queried window.
  --
  -- Without this the round costs candidates x placed, and a bridging round, the candidate count
  -- and the pole count all grow with the quality chain -- cubic, which is what hung the game on
  -- a 254-tier chain (a 5x5 machine and a medium pole: 82 s for one solve).
  local pole_columns = {}
  local function file(i)
    local x = math.floor(placed[i].dx + pole.width / 2)
    local bucket = pole_columns[x]
    if not bucket then
      bucket = {}
      pole_columns[x] = bucket
    end
    bucket[#bucket + 1] = i
  end
  for i = 1, #placed do file(i) end

  while #components > 1 do
    -- Which component each pole is in now. Rebuilt per round because the merge below renumbers
    -- them, and it is what lets a candidate be scored from a pole rather than from a component.
    local component_of = {}
    for ci, component in pairs(components) do
      for _, i in pairs(component) do component_of[i] = ci end
    end

    local best, best_touch, best_count = nil, nil, 0
    for _, candidate in pairs(candidates) do
      local touched, count = {}, 0
      local cx = candidate.dx + pole.width / 2
      local reach = pole.wire_distance
      for x = math.floor(cx - reach), math.ceil(cx + reach) do
        local bucket = pole_columns[x]
        if bucket then
          for bi = 1, #bucket do
            local i = bucket[bi]
            local ci = component_of[i]
            -- One component counts once however many of its poles are in reach, which is what
            -- the old per-component `break` did.
            if not touched[ci] and within_wire_reach(pole, candidate, placed[i]) then
              touched[ci] = true
              count = count + 1
            end
          end
        end
      end
      if count > best_count then best, best_touch, best_count = candidate, touched, count end
    end
    if best_count < 2 then break end

    placed[#placed + 1] = best
    file(#placed)
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

-- One full attempt against one candidate set: cover, bridge, tally. Every placed pole is a
-- candidate reference -- greedy and bridge both pick from the candidate arrays -- so the
-- coverage lists answer the honesty tally too.
local function attempt(candidates, consumers, pole, cover_of)
  local placed, remaining = greedy_cover(candidates, consumers, pole, cover_of)
  bridge(placed, remaining, pole)

  local lit = {}
  for _, i in pairs(largest_component(components_of(placed, pole))) do
    local list = coverage(cover_of, pole, placed[i], consumers)
    for li = 1, #list do lit[list[li]] = true end
  end
  local unpowered = 0
  for i = 1, #consumers do
    if not lit[i] then unpowered = unpowered + 1 end
  end

  return placed, unpowered
end

-- One copper wire per pole, to its nearest already-wired neighbour -- a spanning tree per
-- component rather than a mesh, so the built network reads as a line, not a cobweb. Every
-- chosen edge is within reach: a connected component always has SOME in-reach edge across
-- any cut, and the minimum-distance pair can only be shorter. Computed here rather than in
-- the serialiser because which pole can reach which is this module's geometry; blueprint.lua just
-- executes the list.
local function spanning_wires(placed, pole)
  local wires = {}
  for _, component in pairs(components_of(placed, pole)) do
    -- Prim's, carrying each outside pole's best edge INTO the tree rather than rescanning the
    -- whole tree on every edge. Rescanning made this cubic in the pole count, which is one per
    -- quality tier or so -- invisible at five tiers, most of the solve at two hundred.
    --
    -- The tie-breaks are the old scan's and are reproduced exactly: among equal distances the
    -- earliest component position wins, at BOTH ends of the edge. That second half is the one
    -- worth stating, because a ring plan is full of equal distances and nothing in the suite
    -- pins a wire_to value -- a rewired plan would still be connected, and still pass.
    local order = {}
    for position, i in pairs(component) do order[i] = position end

    local best_dist, best_to = {}, {}
    local in_tree = { [component[1]] = true }

    -- Every pole still outside the tree reconsiders its edge against the one just added.
    local function offer(j)
      for _, i in pairs(component) do
        if not in_tree[i] then
          local dist = distance_sq(pole, placed[i], placed[j])
          local current = best_dist[i]
          if not current or dist < current
            or (dist == current and order[j] < order[best_to[i]])
          then
            best_dist[i], best_to[i] = dist, j
          end
        end
      end
    end
    offer(component[1])

    for _ = 2, #component do
      local best_from
      for _, i in pairs(component) do
        if not in_tree[i] and (not best_from or best_dist[i] < best_dist[best_from]) then
          best_from = i
        end
      end
      in_tree[best_from] = true
      wires[best_from] = best_to[best_from]
      offer(best_from)
    end
  end
  return wires
end

-- pole: { name, quality, width, height, supply_distance, wire_distance } -- plain values;
-- the planner resolves them, this file never touches prototypes. consumer_margins maps
-- entity names to the collision-box margin their stand-in is shrunk by, false for entities
-- that draw no power.
--
-- Returns { entities, unpowered }: pole entity dicts each carrying wire_to -- the index, in
-- their own order, of the pole it wires back to, which planner.plan rebases onto plan indices
-- when it appends them -- and how many
-- consumers no pole of the main network reaches.
function poles.plan(built, pole, consumer_margins)
  local consumers = consumers_of(built.entities, consumer_margins)
  local candidates = candidate_positions(occupied(built.entities), built.width, built.height, pole)
  -- One memo for the whole solve: the column index up front, the coverage lists lazily.
  local cover_of = memo_for(consumers)

  -- Columns first, free tiles as the honest fallback: the layout already sized the utility
  -- columns to this pole, so the tidy vertical line is the common case -- but a pole whose
  -- supply cannot cover from the columns alone still gets the full free-tile search rather
  -- than a shrug. The fallback is kept only when it powers strictly more, so a tie stays
  -- with the columns.
  local placed, unpowered
  local column_candidates = built.utility_columns
    and within_columns(candidates, built.utility_columns, pole) or {}
  if #column_candidates > 0 then
    placed, unpowered = attempt(column_candidates, consumers, pole, cover_of)
  end
  if not placed or unpowered > 0 then
    local free_placed, free_unpowered = attempt(candidates, consumers, pole, cover_of)
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
      wire_to = wires[i],
    }
  end

  return { entities = entities, unpowered = unpowered }
end

return poles
