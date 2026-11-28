-- A chain's cells side by side in one blueprint: where each one stands. PURE like cell.lua --
-- plain values in, offsets out -- so tests/pure runs it on host Lua too.
--
-- Left to right in the order given, bottom-aligned so the chest rows make one line. A cell
-- stands apart from the one before it only for a reason, the larger of:
--   * a free tile beside a pipe row, unless both carry the same fluid at the same height --
--     those join into one line, as copies side by side always have. The tile keeps two fluids
--     from meeting and leaves each line an end to feed it from;
--   * the smallest gap, up to MAX_BEACON_GAP more tiles, at which no beacon of the new cell
--     reaches any earlier cell's machine, nor any earlier beacon its machine (cell.lua's
--     measured reach rule) -- that machine would craft faster and roll less quality than its
--     plan says. Past the cap the cells abut and `shared` says so.

local cell = require("scripts.cell")

local row = {}

row.MAX_BEACON_GAP = 6

-- Whether any beacon of cell `a` reaches the machine of cell `b`, each at its offset.
local function reaches_machine(a, ax, ay, b, bx, by)
  if not a.beacon then return false end
  local machine = b.built.machine
  local mx, my = bx + machine.dx, by + machine.dy
  for _, at in ipairs(a.built.beacons) do
    if cell.reaches(a.beacon, ax + at.dx - mx, ay + at.dy - my, machine) then return true end
  end
  return false
end

local function joins(a, ay, b, by)
  return a.fluid ~= nil and a.fluid == b.fluid and ay + a.built.pipe_y == by + b.built.pipe_y
end

-- Whether cell `i` at x, y keeps clear of every cell placed before it, both ways round.
local function clear(cells, offsets, i, x, y)
  for j = 1, i - 1 do
    local o = offsets[j]
    if reaches_machine(cells[j], o.x, o.y, cells[i], x, y) or reaches_machine(cells[i], x, y, cells[j], o.x, o.y) then
      return false
    end
  end
  return true
end

-- cells: { built = a cell.build result, beacon = its beacon params or nil, fluid = the fluid
-- its pipe row carries or nil }, in row order.
-- Returns { offsets = { { x, y } per cell }, width, height, shared }.
function row.place(cells)
  local height = 0
  for _, c in ipairs(cells) do height = math.max(height, c.built.height) end

  local offsets, shared, right = {}, false, 0
  for i, c in ipairs(cells) do
    local y = height - c.built.height
    local x = right
    if i > 1 then
      local before = cells[i - 1]
      if (before.fluid or c.fluid) and not joins(before, offsets[i - 1].y, c, y) then x = x + 1 end
      local gap = 0
      while gap <= row.MAX_BEACON_GAP and not clear(cells, offsets, i, x + gap, y) do gap = gap + 1 end
      if gap > row.MAX_BEACON_GAP then shared = true else x = x + gap end
    end
    offsets[i] = { x = x, y = y }
    right = x + c.built.width
  end
  return { offsets = offsets, width = right, height = height, shared = shared }
end

return row
