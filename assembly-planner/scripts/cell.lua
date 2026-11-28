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
-- When the inserters cannot keep up, the planner adds extra pairs: first on the bottom edge,
-- then up the left side and the right, each side's beacons stepping two tiles out:
--
--   B B B R i M M M B B B
--

-- Coordinates are tiles from the cell's top-left corner; an entity covering dx..dx+w-1 has its
-- centre half a footprint in. The cell's bounding box is its footprint, so two cells stamped
-- side by side abut exactly. Rotating or flipping the blueprint in hand puts the rows anywhere.

local cell = {}

local NORTH, SOUTH = defines.direction.north, defines.direction.south
local EAST, WEST = defines.direction.east, defines.direction.west

-- A side holding inserters puts each one beside the machine and its chest beyond it, so that
-- side's beacon column steps this many tiles out.
local STEP = 2

local ROLE_ORDER = { input = 1, output = 2, quality = 3 }

-- The beacon reach rule (measured, upcycler-planner api.md §25, re-measured for this cell's
-- positions on 2.1.23): the supply area is the beacon's collision box grown by its supply
-- distance on every side, and a machine receives when its collision box overlaps that area.
-- Strict, so boxes that merely touch reach nothing. Boxes are tile rects shrunk by each
-- prototype's collision margin.
local function overlap(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
  return ax0 < bx1 and bx0 < ax1 and ay0 < by1 and by0 < ay1
end

-- Both positions relative to the machine's top-left tile. row.lua asks it across cells too.
local function reaches(beacon, bx, by, machine)
  local m, d, mm = beacon.margin, beacon.supply, machine.margin
  return overlap(bx + m - d, by + m - d, bx + beacon.w - m + d, by + beacon.h - m + d,
    mm, mm, machine.w - mm, machine.h - mm)
end
cell.reaches = reaches

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

-- How many inserters one side of the machine can take: its height, provided every beacon the
-- plan stands on that side still reaches from STEP tiles out. Both sides alike, so one number.
function cell.side_room(machine, beacon)
  if beacon and (beacon.side or 0) > 0 then
    local sides = side_offsets(machine, beacon)
    for i = 1, math.min(beacon.side, #sides) do
      if not reaches(beacon, -beacon.w - STEP, sides[i], machine) then return 0 end
    end
  end
  return machine.h
end

-- The slots by edge. The bottom takes every first-of-its-role slot and as many extras as fit,
-- grouped inputs, outputs, quality; the rest go up the left side, then the right, top first.
-- The planner sizes the extras by side_room, so neither side is ever asked for more.
local function by_edge(slots, machine)
  local free = machine.w
  for _, slot in ipairs(slots) do
    if not slot.extra then free = free - 1 end
  end
  local bottom, overflow = {}, {}
  for index, slot in ipairs(slots) do
    if not slot.extra or free > 0 then
      if slot.extra then free = free - 1 end
      bottom[#bottom + 1] = { slot = slot, index = index }
    else
      overflow[#overflow + 1] = slot
    end
  end
  table.sort(bottom, function(a, b)
    local ra, rb = ROLE_ORDER[a.slot.role] or 9, ROLE_ORDER[b.slot.role] or 9
    if ra ~= rb then return ra < rb end
    return a.index < b.index
  end)
  for i, entry in ipairs(bottom) do bottom[i] = entry.slot end
  local left, right = {}, {}
  for i, slot in ipairs(overflow) do
    if i <= machine.h then left[#left + 1] = slot else right[#right + 1] = slot end
  end
  return bottom, left, right
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
-- p.slots    the inserter-and-chest pairs, each { role, extra, inserter, chest, filters,
--            requests, bar, control_behavior }; role "input" picks from its chest, every other
--            role from the machine. `extra` marks the second and later of a role, the ones that
--            may go up a side when the bottom edge is full.
-- p.pipe     the pipe row's pipe name, or nil for a recipe with no fluid.
-- p.beacon   { name, quality, w, h, margin, supply, modules, module_inventory, side, above }
--            or nil; side is per column, both counts clamped to the capacity here.
-- p.pole_column  the width of an extra column on the right for poles, or nil.
-- p.pole_row     the height of an extra row along the top for poles, or nil -- the only
--                ground a short-reach pole can power a full row of beacons above from.
--
-- Returns { entities, width, height, machine, beacons, pipe_y }: the machine's rect
-- { dx, dy, w, h, margin }, every beacon's { dx, dy }, and the pipe row's dy when there is one
-- -- what row.lua needs to stand cells side by side without touching each other.
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

  local bottom, left, right = by_edge(p.slots, machine)
  local gap_left = #left > 0 and STEP or 0
  local gap_right = #right > 0 and STEP or 0

  local sw = #side_list > 0 and beacon.w or 0
  local ah = #above_list > 0 and beacon.h or 0
  local oy = p.pole_row or 0
  local mx, my = sw + gap_left, oy + ah + (fluid and 1 or 0)
  local iy = my + machine.h
  local cy = iy + 1
  local base = machine.w + 2 * sw + gap_left + gap_right
  local column = p.pole_column or 0
  local width, height = base + column, cy + 1

  local entities, beacons = {}, {}
  local function add(entity) entities[#entities + 1] = entity end
  local function add_beacon(dx, dy)
    add(beacon_entity(beacon, dx, dy))
    beacons[#beacons + 1] = { dx = dx, dy = dy }
  end

  for _, x in ipairs(above_list) do add_beacon(mx + x, oy) end

  if fluid then
    for x = 0, width - 1 do add({ name = p.pipe, dx = x, dy = oy + ah, w = 1, h = 1 }) end
  end

  for _, y in ipairs(side_list) do
    add_beacon(0, my + y)
    add_beacon(mx + machine.w + gap_right, my + y)
  end

  add({
    name = machine.name, quality = machine.quality, dx = mx, dy = my, w = machine.w, h = machine.h,
    direction = machine.direction, recipe = machine.recipe, recipe_quality = machine.recipe_quality,
    modules = machine.modules,
  })

  local function add_slot(slot, inserter_x, inserter_y, chest_x, chest_y, toward_chest, toward_machine)
    add({
      name = slot.inserter.name, quality = slot.inserter.quality, dx = inserter_x, dy = inserter_y,
      w = 1, h = 1, direction = slot.role == "input" and toward_chest or toward_machine,
      filters = slot.filters, control_behavior = slot.control_behavior,
    })
    add({
      name = slot.chest.name, quality = slot.chest.quality, dx = chest_x, dy = chest_y, w = 1, h = 1,
      requests = slot.requests, bar = slot.bar,
    })
  end

  -- An inserter's direction is the side it picks up from (upcycler-planner layout.lua, measured):
  -- an input faces its chest, an output faces the machine.
  for c, slot in ipairs(bottom) do
    local x = mx + c - 1
    add_slot(slot, x, iy, x, cy, SOUTH, NORTH)
  end
  for k, slot in ipairs(left) do
    local y = my + k - 1
    add_slot(slot, mx - 1, y, mx - 2, y, WEST, EAST)
  end
  for k, slot in ipairs(right) do
    local y = my + k - 1
    add_slot(slot, mx + machine.w, y, mx + machine.w + 1, y, EAST, WEST)
  end

  return {
    entities = entities, width = width, height = height,
    machine = { dx = mx, dy = my, w = machine.w, h = machine.h, margin = machine.margin },
    beacons = beacons, pipe_y = fluid and oy + ah or nil,
  }
end

return cell
