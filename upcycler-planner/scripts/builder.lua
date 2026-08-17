-- Puts a plan on the ground as ghosts.
--
-- All or nothing: every position is checked before anything is created, so a blocked spot
-- leaves the world untouched and the player still holding the tool. Retrying somewhere else is
-- then just another click, with no half-built mess to clear up first.
--
-- The whole thing runs inside one event. The plan is a few dozen entities, so there is no need
-- for the tick-budgeted machinery a terrain-scanning planner has to carry -- and because
-- nothing is left half-finished between ticks, no in-flight state can straddle a save.

local builder = {}

-- Plan coordinates are tile indices from the layout's top-left corner. An entity covering
-- tiles dx..dx+w-1 has its centre half a footprint in, which lands on a tile centre for odd
-- sizes and a tile boundary for even ones -- exactly what the engine expects.
local function position_of(anchor, entity)
  return {
    x = anchor.x + entity.dx + entity.w / 2,
    y = anchor.y + entity.dy + entity.h / 2,
  }
end

local function apply_recipe(ghost, entity)
  if entity.recipe then
    ghost.set_recipe(entity.recipe, entity.recipe_quality)
  end
end

local function apply_modules(ghost, entity)
  local modules = entity.modules
  -- count can be nil, not just 0: a modded machine without module support reports no
  -- module_inventory_size at all, and the comparison would be the crash.
  if not (modules and modules.name and (modules.count or 0) > 0) then return end

  local positions = {}
  for stack = 0, modules.count - 1 do
    -- Module stacks are 0-based, and crafter_modules is the module inventory for both
    -- assembling machines and the furnace-type recycler.
    positions[#positions + 1] = { inventory = defines.inventory.crafter_modules, stack = stack }
  end

  -- insert_plan, not an item-request-proxy: the plan is writable on a ghost, item_requests is
  -- read-only, and the proxy would need the ghost to exist first anyway.
  --
  -- The module's quality is the player's pick from the modal, normal unless they changed it.
  -- Since 0.3.0 there are two picks, not one -- the quality module and the top machine's own --
  -- so this reads whichever quality the plan attached to this module rather than a single
  -- loop-wide one. What is still deferred is the SPLIT: which module belongs in which tier once
  -- the player's modules are themselves high quality, to drive from get_roll_chances().
  ghost.insert_plan = { {
    id = { name = modules.name, quality = modules.quality or "normal" },
    items = { in_inventory = positions },
  } }
end

local function apply_filters(ghost, entity)
  if not entity.filters then return end

  ghost.use_filters = true
  for index, filter in pairs(entity.filters) do
    ghost.set_filter(index, { name = filter.name, quality = filter.quality, comparator = "=" })
  end
  -- Set the mode after the filters: on an inserter with no filters yet it reads back nil.
  ghost.inserter_filter_mode = entity.filter_mode or "whitelist"
end

local function apply_requests(ghost, entity, trash_unrequested)
  if not entity.requests then return end

  local point = ghost.get_logistic_point(defines.logistic_member_index.logistic_container)
  if not point then return end

  -- Request from buffers, because players commonly hold intermediates in buffer chests and a
  -- request that ignores them looks broken. Trash unrequested -- so a wrong-quality roll or a
  -- leftover goes back to the network instead of sitting in a slot forever -- is the player's
  -- checkbox at Confirm, on by default. Both verified settable on a ghost and to survive being
  -- built (2.1.14).
  ghost.request_from_buffers = true
  point.trash_not_requested = trash_unrequested

  -- A chest already comes with one empty section. Filling that one keeps the chest's GUI
  -- tidy; add_section would work too but leaves the blank one sitting above ours.
  local section = point.sections[1]
  if not (section and section.is_manual and #section.filters == 0) then
    section = point.add_section()
  end
  if not section then return end

  for index, request in pairs(entity.requests) do
    -- A request with a non-zero min is quality-exact by engine rule, which is what keeps each
    -- tier's items separate from the player's base and from each other.
    section.set_slot(index, {
      value = { name = request.name, quality = request.quality, comparator = "=" },
      min = request.count,
    })
  end
end

-- Wires the pole ghosts into their planned network. Explicit rather than trusted to happen:
-- since 2.0 wires are first-class blueprint content, and whether a bare scripted ghost
-- auto-connects on revive is unverified -- a ghost-to-ghost wire is verified machinery and
-- previews the network for the player besides. The default wire_origin is player, which
-- keeps the wires visible and hand-editable; reach_check stays on, so the engine has the
-- final word on any span the plan got wrong.
local function connect_poles(pole_ghosts)
  for _, entry in pairs(pole_ghosts) do
    local target = entry.wire_to and pole_ghosts[entry.wire_to]
    if target and entry.ghost.valid and target.ghost.valid then
      entry.ghost.get_wire_connector(defines.wire_connector_id.pole_copper, true)
        .connect_to(target.ghost.get_wire_connector(defines.wire_connector_id.pole_copper, true))
    end
  end
end

-- Trees and rocks are cleared by marking them, the same way a player would, rather than being
-- deleted outright -- the loop's ghosts and these orders then get built by the same bots.
-- Returns what it NEWLY marked, so a refused placement can be rolled back without cancelling
-- orders the player had already placed themselves.
local function clear_obstacles(surface, force, player, area)
  local marked = {}
  for _, entity in pairs(surface.find_entities_filtered({
    area = area,
    type = { "tree", "simple-entity" },
  })) do
    if (entity.prototype.count_as_rock_for_filtered_deconstruction or entity.type == "tree")
      and not entity.to_be_deconstructed()
    then
      entity.order_deconstruction(force, player)
      marked[#marked + 1] = entity
    end
  end
  return marked
end

-- Returns the number of ghosts placed, or nil plus the blocking position.
-- `context` carries surface, force and (optionally) player: the surface comes from the
-- selection event, which is authoritative over player.surface when the two could differ.
function builder.place(plan, anchor, context)
  local surface = context.surface
  local force = context.force
  local player = context.player

  -- Marking has to happen BEFORE the check: `forced` below is what lets the check see past
  -- exactly these orders. A refused placement therefore has to cancel what it marked, or the
  -- player's bots go off to fell a forest at a spot where nothing was built.
  local marked = clear_obstacles(surface, force, player, {
    left_top = { x = anchor.x, y = anchor.y },
    right_bottom = { x = anchor.x + plan.width, y = anchor.y + plan.height },
  })

  -- Check the REAL prototype with `manual_ghost`, not `name = "entity-ghost"` with an
  -- inner_name. Both of the obvious alternatives are wrong, and both fail quietly:
  --
  --   * `script_ghost` does not test for obstructions at all -- it answers true while a
  --     building is standing on the spot, so nothing would ever be rejected.
  --   * the `entity-ghost` + `inner_name` form answers FALSE for transport belts on perfectly
  --     clear ground, while the same belt places fine and every other entity answers true.
  --
  -- Measured on 2.1.14. `manual_ghost` is the one combination that accepts clear ground and
  -- refuses occupied ground for every entity this layout uses. `forced` lets it ignore what
  -- was just marked for deconstruction above.
  for _, entity in pairs(plan.entities) do
    local position = position_of(anchor, entity)
    if not surface.can_place_entity({
      name = entity.name,
      position = position,
      direction = entity.direction,
      force = force,
      build_check_type = defines.build_check_type.manual_ghost,
      forced = true,
    }) then
      for _, obstacle in pairs(marked) do
        if obstacle.valid then obstacle.cancel_deconstruction(force, player) end
      end
      return nil, position
    end
  end

  local placed = 0
  -- Already a real boolean: plan() owns the default (including old-snapshot normalisation).
  local trash_unrequested = plan.trash_unrequested
  -- Pole ghosts, keyed by their order among the plan's poles: entity.wire_to points into
  -- that same order, and may point at a pole created LATER in the loop, so wiring runs as a
  -- second pass once every ghost exists.
  local pole_ghosts, pole_count = {}, 0
  for _, entity in pairs(plan.entities) do
    local ghost = surface.create_entity({
      name = "entity-ghost",
      inner_name = entity.name,
      -- A common create_entity parameter, not one of the entity-ghost variant group, so unlike
      -- `recipe` it does apply here. nil means normal.
      quality = entity.quality,
      position = position_of(anchor, entity),
      direction = entity.direction,
      force = force,
      player = player,
      raise_built = true,
    })

    if entity.pole then pole_count = pole_count + 1 end
    if ghost then
      placed = placed + 1
      apply_recipe(ghost, entity)
      apply_modules(ghost, entity)
      apply_filters(ghost, entity)
      apply_requests(ghost, entity, trash_unrequested)
      if entity.pole then pole_ghosts[pole_count] = { ghost = ghost, wire_to = entity.wire_to } end
    end
  end

  connect_poles(pole_ghosts)

  return placed
end

return builder
