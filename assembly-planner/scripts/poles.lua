-- Electric poles for a finished cell: enough of them, wired into one network, that every
-- powered entity in it -- machine, inserters, beacons -- has power. PURE: plain values in,
-- pole entities out, so the same cell grows the same poles on every client.
--
-- A greedy cover over the layout's free tiles, connected by construction: after the first pole,
-- a candidate counts only when it is within wire reach of a pole already placed, and when no
-- connected candidate covers anything new the next pole is a bridge toward the best one that
-- does. A chain's row can hold dozens of cells, so the scans stay linear in the candidates:
-- each consumer is filed by the columns it spans, and each candidate carries flags that every
-- placement updates once. Row-major scan order is load-bearing: every tie goes to the first
-- candidate found, which is what makes the result deterministic.

local poles = {}

-- The engine powers a consumer when its collision box OVERLAPS the pole's supply square
-- (measured, upcycler-planner api.md §10). Each consumer is its tile rect shrunk by the margin
-- the planner computed from its prototype -- always a subset of the real box -- so the test can
-- under-promise (an extra pole, an honest warning) but never claim power the game won't give.
-- Strict, so an area that merely touches covers nothing.
local function overlap(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
  return ax0 < bx1 and bx0 < ax1 and ay0 < by1 and by0 < ay1
end

local function occupied(entities)
  local occ = {}
  for _, e in pairs(entities) do
    for x = e.dx, e.dx + e.w - 1 do
      occ[x] = occ[x] or {}
      for y = e.dy, e.dy + e.h - 1 do occ[x][y] = true end
    end
  end
  return occ
end

local function fits(occ, width, height, px, py, pole)
  if px < 0 or py < 0 or px + pole.width > width or py + pole.height > height then return false end
  for x = px, px + pole.width - 1 do
    for y = py, py + pole.height - 1 do
      if occ[x] and occ[x][y] then return false end
    end
  end
  return true
end

local function covers(pole, cx, cy, consumer)
  local d, m = pole.supply_distance, consumer.margin
  return overlap(cx - d, cy - d, cx + d, cy + d,
    consumer.dx + m, consumer.dy + m, consumer.dx + consumer.w - m, consumer.dy + consumer.h - m)
end

local function distance_sq(a, b)
  local dx, dy = a.cx - b.cx, a.cy - b.cy
  return dx * dx + dy * dy
end

-- built: { entities, width, height }, entities carrying dx, dy, w, h and name.
-- pole: { name, quality, width, height, supply_distance, wire_distance } -- plain values.
-- margins: entity name -> collision margin for the ones that draw power; absent means none.
--
-- Returns { entities, unpowered }: the poles in placement order, each carrying wire_to -- the
-- index, in that same order, of the earlier pole it wires to -- and how many consumers no pole
-- reaches.
function poles.plan(built, pole, margins)
  local consumers = {}
  for _, e in pairs(built.entities) do
    local margin = margins[e.name]
    if margin then
      consumers[#consumers + 1] = { dx = e.dx, dy = e.dy, w = e.w, h = e.h, margin = margin }
    end
  end

  -- Each consumer filed under every column it spans, so a candidate tests only the consumers
  -- its supply square can reach. The order of a candidate's cover list never matters: it is
  -- only ever counted and marked.
  local by_column = {}
  for i, consumer in ipairs(consumers) do
    for x = consumer.dx, consumer.dx + consumer.w - 1 do
      by_column[x] = by_column[x] or {}
      by_column[x][#by_column[x] + 1] = i
    end
  end

  local occ = occupied(built.entities)
  local candidates = {}
  local d = pole.supply_distance
  for py = 0, built.height - pole.height do
    for px = 0, built.width - pole.width do
      if fits(occ, built.width, built.height, px, py, pole) then
        local c = { dx = px, dy = py, cx = px + pole.width / 2, cy = py + pole.height / 2, covers = {} }
        local tested = {}
        for x = math.floor(c.cx - d) - 1, math.ceil(c.cx + d) do
          for _, i in ipairs(by_column[x] or {}) do
            if not tested[i] then
              tested[i] = true
              if covers(pole, c.cx, c.cy, consumers[i]) then c.covers[#c.covers + 1] = i end
            end
          end
        end
        candidates[#candidates + 1] = c
      end
    end
  end

  local covered, remaining, placed = {}, #consumers, {}
  local reach_sq = pole.wire_distance * pole.wire_distance

  -- The nearest placed pole within wire reach, or nil; asked once per placement.
  local function wire_target(c)
    local best, best_d
    for i, p in ipairs(placed) do
      local dist = distance_sq(c, p)
      if dist <= reach_sq and (not best_d or dist < best_d) then best, best_d = i, dist end
    end
    return best
  end

  local function gain_of(c)
    local gain = 0
    for _, i in ipairs(c.covers) do
      if not covered[i] then gain = gain + 1 end
    end
    return gain
  end

  -- The open candidate with the highest score, first found on a tie; score returns nil to skip.
  -- `blocked` marks one a placed pole overlaps, a placed pole's own spot included.
  local function best_candidate(score)
    local best, best_score
    for _, c in ipairs(candidates) do
      if not c.blocked then
        local s = score(c)
        if s and (not best_score or s > best_score) then best, best_score = c, s end
      end
    end
    return best
  end

  -- Places a pole and brings every candidate's flags up to date: `blocked` once this pole
  -- overlaps it, `near` once this pole stands within its wire reach.
  local function place(c)
    for _, i in ipairs(c.covers) do
      if not covered[i] then
        covered[i] = true
        remaining = remaining - 1
      end
    end
    local p = { dx = c.dx, dy = c.dy, cx = c.cx, cy = c.cy, wire_to = wire_target(c) }
    placed[#placed + 1] = p
    for _, other in ipairs(candidates) do
      if not other.blocked and other.dx < p.dx + pole.width and p.dx < other.dx + pole.width
        and other.dy < p.dy + pole.height and p.dy < other.dy + pole.height then
        other.blocked = true
      end
      if not other.near and distance_sq(other, p) <= reach_sq then other.near = true end
    end
  end

  while remaining > 0 do
    local best = best_candidate(function(c)
      if #placed > 0 and not c.near then return nil end
      local gain = gain_of(c)
      return gain > 0 and gain or nil
    end)
    if not best then
      -- Nothing within reach covers anything new; bridge toward the best candidate that would,
      -- only while each bridge really gets closer, so the walk always ends.
      local target = best_candidate(function(c)
        local gain = gain_of(c)
        return gain > 0 and gain or nil
      end)
      if not target then break end
      local current
      for _, p in ipairs(placed) do
        local dist = distance_sq(p, target)
        if not current or dist < current then current = dist end
      end
      best = best_candidate(function(c)
        local dist = distance_sq(c, target)
        if not c.near or dist >= current then return nil end
        return -dist
      end)
      if not best then break end
    end
    place(best)
  end

  local entities = {}
  for i, p in ipairs(placed) do
    entities[i] = {
      name = pole.name, quality = pole.quality,
      dx = p.dx, dy = p.dy, w = pole.width, h = pole.height, wire_to = p.wire_to,
    }
  end
  return { entities = entities, unpowered = remaining }
end

return poles
