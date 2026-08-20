-- Turns a plan into the blueprint the player holds.
--
-- Every field name below was read out of the engine rather than recalled: a plan was placed as
-- ghosts, captured with create_blueprint, and get_blueprint_entities() named exactly thirteen
-- fields across a solid and a fluid loop. Those thirteen are all of it, and the capture is
-- reproducible -- tests/blueprint_spec.lua stamps what this builds and reads the result back.
--
-- Once the stack is in the cursor this mod is finished. The engine owns the preview, rotation,
-- flipping, snapping, undo and the build itself, so there is no placement event to handle and
-- no ground to check: a normal click refuses on anything in the way, shift-click force-builds
-- and clears the trees, ctrl-shift-click bulldozes. That is how every other blueprint behaves,
-- which is the whole point of handing over one.

local blueprint = {}

-- A plain vanilla blueprint rather than a prototype of our own. It is the item every player
-- already knows how to hold, it costs no prototype in a flat global namespace, and a custom
-- one would buy only an icon -- preview_icons below does that anyway.
local BLUEPRINT_ITEM = "blueprint"

-- The same arithmetic the ghost route used: plan coordinates are tile indices from the layout's
-- top-left, and an entity covering dx..dx+w-1 has its centre half a footprint in -- a tile
-- centre for odd sizes, a tile boundary for even ones. Blueprint positions are relative to the
-- blueprint's own origin, so the plan's corner serves as that origin and the engine centres the
-- whole thing on the cursor for us.
local function position_of(entity)
  return { x = entity.dx + entity.w / 2, y = entity.dy + entity.h / 2 }
end

local function items_of(entity)
  local modules = entity.modules
  -- count can be nil, not just 0: a modded machine without module support reports no
  -- module_inventory_size at all, and the comparison would be the crash.
  if not (modules and modules.name and (modules.count or 0) > 0) then return nil end

  local positions = {}
  for stack = 0, modules.count - 1 do
    -- Stack indices are 0-based, and crafter_modules is the module inventory for both the
    -- assembling machines and the furnace-type recycler.
    positions[#positions + 1] = { inventory = defines.inventory.crafter_modules, stack = stack }
  end

  -- id.quality nil means normal, which is how the engine writes it too.
  return { {
    id = { name = modules.name, quality = modules.quality },
    items = { in_inventory = positions },
  } }
end

-- Every field of a blueprint filter but `index` is optional, and this mod uses all three ways of
-- leaving one out (analysis/api.md S24): the ordinary filters name an item and a quality and mean
-- exactly that; the terminal catcher adds ">=" to mean the target and everything above; and the
-- overflow tap names a QUALITY AND NO ITEM, which the engine reads as "anything at all, above
-- this tier". The engine normalises ">=" to the single glyph on the way in, so what comes back
-- out of a blueprint is not the string written here.
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

-- A blueprint's logistic filter is a FLATTER table than the runtime one the ghost route wrote:
-- the count sits on the filter itself, where LuaLogisticSection.set_slot takes
-- { value = { name, quality, comparator }, min = count }. Same request, different shape, and
-- getting it wrong yields a chest with an empty section rather than an error.
local function request_filters_of(entity, trash_unrequested)
  if not entity.requests then return nil end

  local filters = {}
  for index, request in ipairs(entity.requests) do
    -- A request carrying a count is quality-exact by engine rule, which is what keeps each
    -- tier's items separate from the player's base and from each other.
    filters[index] = {
      index = index, name = request.name, quality = request.quality,
      comparator = "=", count = request.count,
    }
  end

  return {
    sections = { { index = 1, filters = filters } },
    -- Request from buffers, because players commonly hold intermediates in buffer chests and a
    -- request that ignores them looks broken. Trashing the surplus is the player's checkbox.
    request_from_buffers = true,
    trash_not_requested = trash_unrequested,
  }
end

-- Copper between two pole entries, written on BOTH ends -- which is what create_blueprint emits
-- for a pair of connected poles, and there is no reason to hand the engine a shape it would not
-- have produced itself.
local function connect(a, b)
  local connector = defines.wire_connector_id.pole_copper
  a.wires = a.wires or {}
  b.wires = b.wires or {}
  a.wires[#a.wires + 1] = { a.entity_number, connector, b.entity_number, connector }
  b.wires[#b.wires + 1] = { b.entity_number, connector, a.entity_number, connector }
end

-- The plan as an array of BlueprintEntity. entity_number is the plan's own index, which is what
-- lets the wire pass below name an entity this loop has not reached yet.
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
      -- use_filters is the flag the engine wants alongside filters, and the plan's intent is
      -- simply that filters exist. nil filter_mode is whitelist to the engine, which is the
      -- same default the ghost route wrote explicitly.
      use_filters = entity.filters and true or nil,
      filter_mode = entity.filter_mode,
      request_filters = request_filters_of(entity, plan.trash_unrequested),
    }
  end

  -- A second pass, because connect() writes BOTH ends and so needs the partner's entry to
  -- exist -- and wire_to genuinely can name an entity later in the array, since poles.lua grows
  -- its spanning tree by distance rather than by index.
  for index, entity in ipairs(plan.entities) do
    if entity.wire_to then connect(entities[index], entities[entity.wire_to]) end
  end

  return entities
end

-- Puts the plan in the player's cursor. Returns true, or nil plus a ready-made message -- the
-- same shape planner.validate hands back, so a refusal from either can be printed or shown
-- without the caller knowing which produced it.
function blueprint.give(player, plan)
  -- A spectator has no cursor_stack at all, so there is nowhere to put it.
  local cursor = player.cursor_stack
  if not cursor then return nil, { "upl-message.no-cursor" } end

  -- clear_cursor can FAIL -- full cursor, full inventory -- and set_stack on top of that
  -- failure would overwrite, and so destroy, whatever the player is holding.
  if not (player.clear_cursor() and cursor.set_stack({ name = BLUEPRINT_ITEM, count = 1 })) then
    return nil, { "upl-message.cursor-full" }
  end

  cursor.set_blueprint_entities(blueprint.entities(plan))

  -- Left to itself the engine picks the belt and the machine as the blueprint's icons, which
  -- says nothing about what the loop is for. The product at the target quality does. Written
  -- AFTER set_blueprint_entities, like the snap grid that call is known to clear (api.md S21) --
  -- do not reorder these.
  if plan.product then
    cursor.preview_icons = { {
      index = 1,
      signal = { type = "item", name = plan.product, quality = plan.target_quality },
    } }
  end

  -- Makes the blueprint behave like the tool it replaces: Q throws it away and nothing lands
  -- in the inventory. A player who wants to keep the design drags it into a slot instead --
  -- "manually putting it into inventory still preserves the item". Silently ignored on a stack
  -- type that does not support it; a blueprint is one of the four that does.
  player.cursor_stack_temporary = true

  return true
end

return blueprint
