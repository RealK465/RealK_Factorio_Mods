-- One mall cell's geometry: the machine, the inserter and chest rows under it, the beacons
-- beside and above it, and the pipe row behind it. PURE -- plain values in, plan entities out,
-- nothing of defines but defines.direction -- so tests/pure runs this on host Lua too.
--
--   B B B B B B B B B     beacons above, spanning the side columns too
--   = = = = = = = = =     pipe row, fluid recipes only -- full width, so cells side by side join
--   B B B M M M B B B     side beacons, stacked down from the machine's top
--   B B B M M M B B B
--   B B B M M M B B B
--         i o q           inserters: input, output, quality output
--         R P Q           chests:    requester, output (the capped one), quality output
--
-- Coordinates are tiles from the cell's top-left corner; an entity covering dx..dx+w-1 has its
-- centre half a footprint in. The cell's bounding box is its footprint, so two cells stamped
-- side by side abut exactly. Rotating or flipping the blueprint in hand puts the rows anywhere.

local cell = {}

local NORTH, SOUTH = defines.direction.north, defines.direction.south

-- The beacon reach rule (measured, upcycler-planner api.md §25, re-measured for this cell's
-- positions on 2.1.23): the supply area is the beacon's collision box grown by its supply
-- distance on every side, and a machine receives when its collision box overlaps that area.
-- Strict, so boxes that merely touch reach nothing. Boxes are tile rects shrunk by each
-- prototype's collision margin.
local function overlap(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
  return ax0 < bx1 and bx0 < ax1 and ay0 < by1 and by0 < ay1
end

-- Both positions relative to the machine's top-left tile.
local function reaches(beacon, bx, by, machine)
  local m, d, mm = beacon.margin, beacon.supply, machine.margin
  return overlap(bx + m - d, by + m - d, bx + beacon.w - m + d, by + beacon.h - m + d,
    mm, mm, machine.w - mm, machine.h - mm)
end

-- The side column's stack, top-aligned: as many beacons as fit beside the machine and its two
-- rows, and only those that reach it. Offsets are rows below the machine's top. A beacon that
-- would hang below the chest row is never offered -- the cell stays one tidy rectangle.
local function side_offsets(machine, beacon)
  local out = {}
  local k = 0
  while (k + 1) * beacon.h <= machine.h + 2 do
    local y = k * beacon.h
    if not reaches(beacon, -beacon.w, y, machine) then break end
    out[#out + 1] = y
    k = k + 1
  end
  return out
end

-- The row above, centred on the cell's width (the side columns included when there are any)
-- and standing above the pipe row when there is one. Offsets are columns from the machine's
-- left edge; a position that does not reach is left out.
local function above_offsets(machine, beacon, fluid, sided)
  local sw = sided and beacon.w or 0
  local base = machine.w + 2 * sw
  local count = math.floor(base / beacon.w)
  local x0 = math.floor((base - count * beacon.w) / 2) - sw
  local y = -((fluid and 1 or 0) + beacon.h)
  local out = {}
  for j = 0, count - 1 do
    local x = x0 + j * beacon.w
    if reaches(beacon, x, y, machine) then out[#out + 1] = x end
  end
  return out
end

-- How many beacons the cell can hold: per side column, and in the row above with and without
-- side columns (the row is wider with them). Asked by the planner to clamp counts and by the
-- modal to fill its count drop-downs.
function cell.capacity(machine, beacon, fluid)
  return {
    side = #side_offsets(machine, beacon),
    above_sided = #above_offsets(machine, beacon, fluid, true),
    above_alone = #above_offsets(machine, beacon, fluid, false),
  }
end

-- `n` of a row's positions, nearest the middle first, back in left-to-right order -- so two
-- beacons above a three-wide row stand left and middle rather than at both ends.
local function centred(list, n)
  if n >= #list then return list end
  local middle = (#list + 1) / 2
  local order = {}
  for i = 1, #list do order[i] = i end
  table.sort(order, function(a, b)
    local da, db = math.abs(a - middle), math.abs(b - middle)
    if da ~= db then return da < db end
    return a < b
  end)
  local picked = {}
  for i = 1, n do picked[i] = order[i] end
  table.sort(picked)
  local out = {}
  for i, index in ipairs(picked) do out[i] = list[index] end
  return out
end

local function beacon_entity(beacon, dx, dy)
  return {
    name = beacon.name, quality = beacon.quality, dx = dx, dy = dy, w = beacon.w, h = beacon.h,
    modules = beacon.modules, module_inventory = beacon.module_inventory,
  }
end

-- p.machine  { name, quality, w, h, margin, direction, recipe, recipe_quality, modules }
--            w and h are the footprint AFTER rotation.
-- p.slots    the inserter-and-chest pairs, left to right, each { role, inserter, chest,
--            filters, requests, bar, control_behavior }; role "input" picks from its chest,
--            every other role from the machine.
-- p.pipe     the pipe row's pipe name, or nil for a recipe with no fluid.
-- p.beacon   { name, quality, w, h, margin, supply, modules, module_inventory, side, above }
--            or nil; side is per column, both counts clamped to the capacity here.
-- p.pole_column  the width of an extra column on the right for poles, or nil.
-- p.pole_row     the height of an extra row along the top for poles, or nil -- the only
--                ground a short-reach pole can power a full row of beacons above from.
--
-- Returns { entities, width, height }.
function cell.build(p)
  local machine, beacon = p.machine, p.beacon
  local fluid = p.pipe ~= nil

  local side_list, above_list = {}, {}
  if beacon then
    local sides = side_offsets(machine, beacon)
    for i = 1, math.min(beacon.side or 0, #sides) do side_list[i] = sides[i] end
    local above = above_offsets(machine, beacon, fluid, #side_list > 0)
    above_list = centred(above, math.max(0, math.min(beacon.above or 0, #above)))
  end

  local sw = #side_list > 0 and beacon.w or 0
  local ah = #above_list > 0 and beacon.h or 0
  local oy = p.pole_row or 0
  local mx, my = sw, oy + ah + (fluid and 1 or 0)
  local iy = my + machine.h
  local cy = iy + 1
  local base = machine.w + 2 * sw
  local column = p.pole_column or 0
  local width, height = base + column, cy + 1

  local entities = {}
  local function add(entity) entities[#entities + 1] = entity end

  for _, x in ipairs(above_list) do add(beacon_entity(beacon, mx + x, oy)) end

  if fluid then
    for x = 0, width - 1 do add({ name = p.pipe, dx = x, dy = oy + ah, w = 1, h = 1 }) end
  end

  for _, y in ipairs(side_list) do
    add(beacon_entity(beacon, 0, my + y))
    add(beacon_entity(beacon, mx + machine.w, my + y))
  end

  add({
    name = machine.name, quality = machine.quality, dx = mx, dy = my, w = machine.w, h = machine.h,
    direction = machine.direction, recipe = machine.recipe, recipe_quality = machine.recipe_quality,
    modules = machine.modules,
  })

  -- An inserter's direction is the side it picks up from (upcycler-planner layout.lua, measured):
  -- the input faces its chest to the south, the outputs face the machine to the north.
  for c, slot in ipairs(p.slots) do
    local x = mx + c - 1
    add({
      name = slot.inserter.name, quality = slot.inserter.quality, dx = x, dy = iy, w = 1, h = 1,
      direction = slot.role == "input" and SOUTH or NORTH,
      filters = slot.filters, control_behavior = slot.control_behavior,
    })
    add({
      name = slot.chest.name, quality = slot.chest.quality, dx = x, dy = cy, w = 1, h = 1,
      requests = slot.requests, bar = slot.bar,
    })
  end

  return { entities = entities, width = width, height = height }
end

return cell
