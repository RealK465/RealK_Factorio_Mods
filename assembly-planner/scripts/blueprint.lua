-- Turns a plan into the blueprint the player holds. Once the stack is in the cursor this mod is
-- finished: the engine owns the preview, rotation, flipping, snapping, undo and the build, so a
-- normal click refuses over anything in the way, shift-click builds through trees and
-- ctrl-shift-click clears buildings -- the way every blueprint behaves.
--
-- The per-type fields (recipe, filters, request_filters, bar) are not in the documented
-- BlueprintEntity concept but in its variant_parameter_groups; the shapes below were read out
-- of the engine (Upcycler Planner api.md §21, and bar on 2.1.23 -- .ai-support/analysis/api.md).

local blueprint = {}

local BLUEPRINT_ITEM = "blueprint"

-- Plan coordinates are tile indices from the cell's top-left; an entity covering dx..dx+w-1
-- has its centre half a footprint in. The cell's corner serves as the blueprint's origin and
-- the engine centres the whole thing on the cursor.
local function position_of(entity)
  return { x = entity.dx + entity.w / 2, y = entity.dy + entity.h / 2 }
end

-- One BlueprintInsertPlan for the module identity, its stacks 0-based and contiguous -- the
-- engine's own encoding. The inventory rides in on the entity: crafter_modules for the
-- machine, beacon_modules for a beacon, resolved by the planner because cell.lua also runs on
-- the host interpreter where defines.inventory does not exist.
local function items_of(entity)
  local spec = entity.modules
  if not (spec and spec.name and (spec.count or 0) > 0) then return nil end
  local inventory = entity.module_inventory or defines.inventory.crafter_modules
  local positions = {}
  for stack = 0, spec.count - 1 do
    positions[#positions + 1] = { inventory = inventory, stack = stack }
  end
  return { { id = { name = spec.name, quality = spec.quality }, items = { in_inventory = positions } } }
end

-- Every field of a filter but `index` is optional; the cell's are nameless quality filters,
-- which the engine reads as "anything at all, at this quality" (measured, api.md).
local function filters_of(entity)
  if not entity.filters then return nil end
  local filters = {}
  for index, filter in ipairs(entity.filters) do
    filters[index] = {
      index = index, name = filter.name, quality = filter.quality,
      comparator = filter.comparator or "=",
    }
  end
  return filters
end

-- A blueprint's logistic filter is FLATTER than the runtime one: the count sits on the filter,
-- where LuaLogisticSection.set_slot takes { value = {...}, min = count }. Getting it wrong yields
-- an empty section rather than an error. A count needs comparator "=" and a quality.
local function request_filters_of(entity, trash_unrequested)
  if not entity.requests then return nil end
  local filters = {}
  for index, request in ipairs(entity.requests) do
    filters[index] = {
      index = index, name = request.name, quality = request.quality,
      comparator = "=", count = request.count,
    }
  end
  return {
    sections = { { index = 1, filters = filters } },
    -- Players commonly keep intermediates in buffer chests, and a request that ignores them
    -- looks broken.
    request_from_buffers = true,
    trash_not_requested = trash_unrequested,
  }
end

-- A copper wire between two poles, written on BOTH ends -- what create_blueprint emits.
local function connect(a, b)
  local connector = defines.wire_connector_id.pole_copper
  a.wires = a.wires or {}
  b.wires = b.wires or {}
  a.wires[#a.wires + 1] = { a.entity_number, connector, b.entity_number, connector }
  b.wires[#b.wires + 1] = { b.entity_number, connector, a.entity_number, connector }
end

function blueprint.entities(plan)
  local entities = {}
  for index, entity in ipairs(plan.entities) do
    entities[index] = {
      entity_number = index,
      name = entity.name,
      position = position_of(entity),
      direction = entity.direction,
      quality = entity.quality,
      recipe = entity.recipe,
      recipe_quality = entity.recipe_quality,
      items = items_of(entity),
      filters = filters_of(entity),
      use_filters = entity.filters and true or nil,
      request_filters = request_filters_of(entity, plan.trash_unrequested),
      -- The number of usable slots: bar = 2 leaves two slots open (measured both ways on
      -- 2.1.23; the runtime's get_bar reads one more, the index where the red area starts).
      bar = entity.bar,
      control_behavior = entity.control_behavior,
    }
  end
  -- A second pass, because a pole may wire to one later in the array.
  for index, entity in ipairs(plan.entities) do
    if entity.wire_to then connect(entities[index], entities[entity.wire_to]) end
  end
  return entities
end

-- Puts the plan in the player's cursor. Returns true, or nil plus a ready-made message.
function blueprint.give(player, plan)
  -- A spectator has no cursor_stack at all.
  local cursor = player.cursor_stack
  if not cursor then return nil, { "apl-message.no-cursor" } end

  -- clear_cursor can FAIL -- full cursor, full inventory -- and set_stack on top of that failure
  -- would destroy whatever the player is holding.
  if not (player.clear_cursor() and cursor.set_stack({ name = BLUEPRINT_ITEM, count = 1 })) then
    return nil, { "apl-message.cursor-full" }
  end

  cursor.set_blueprint_entities(blueprint.entities(plan))

  -- The product at its quality says what the cell is for; the engine would pick the machine. A
  -- chain shows its first four products, the root's first; a plan straight from plan.build
  -- has no cells list. Written AFTER set_blueprint_entities, which resets what it touches --
  -- do not reorder.
  local icons = {}
  for index, cell in ipairs(plan.cells or { { item = plan.product } }) do
    if index > 4 then break end
    icons[index] = { index = index, signal = { type = "item", name = cell.item, quality = plan.product_quality } }
  end
  cursor.preview_icons = icons

  -- Q throws it away and nothing lands in the inventory; dragging it into a slot keeps it.
  player.cursor_stack_temporary = true
  return true
end

return blueprint
