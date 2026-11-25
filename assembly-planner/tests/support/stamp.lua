-- Stamping a plan for the specs: the blueprint-in-a-script-inventory dance, and the one
-- number every spec that cares about coordinates needs. Adapted from Upcycler Planner.
--
-- The engine centres a blueprint on the position it is stamped at, by its own rule over the
-- bounding box. Rather than reproduce that rule, this measures it: the leftmost-topmost
-- position the plan asked for against the leftmost-topmost the engine produced. Only a
-- complete, unrotated stamp yields an offset; an incomplete one returns none, so a caller using
-- it anyway fails on the spot instead of being quietly off by a tile.

local blueprint = require("scripts.blueprint")

local stamp = {}

local function min_corner(list)
  local x, y = math.huge, math.huge
  for _, item in pairs(list) do
    x = math.min(x, item.position.x)
    y = math.min(y, item.position.y)
  end
  return x, y
end

-- Stamps the plan with its top-left corner near `origin` and returns the ghosts plus the
-- plan-to-world offset.
function stamp.place(plan, surface, force, origin, overrides)
  local entities = blueprint.entities(plan)
  local inventory = game.create_inventory(1)
  inventory.insert({ name = "blueprint", count = 1 })
  local stack = inventory[1]
  stack.set_blueprint_entities(entities)
  local options = {
    surface = surface, force = force,
    position = { x = origin.x + plan.width / 2, y = origin.y + plan.height / 2 },
    build_mode = defines.build_mode.forced,
  }
  for key, value in pairs(overrides or {}) do options[key] = value end
  local ghosts = stack.build_blueprint(options)
  inventory.destroy()
  if #ghosts ~= #entities then return ghosts end
  local want_x, want_y = min_corner(entities)
  local got_x, got_y = min_corner(ghosts)
  return ghosts, got_x - want_x, got_y - want_y
end

-- Revives every ghost in the area and returns the entities.
function stamp.revive_all(surface, area)
  local out = {}
  for _, ghost in pairs(surface.find_entities_filtered({ name = "entity-ghost", area = area })) do
    if ghost.valid then
      local _, revived = ghost.revive()
      assert(revived, "a ghost refused to revive on clear ground")
      out[#out + 1] = revived
    end
  end
  return out
end

-- A surface of lab tiles with its middle generated: no water, no trees, no cliffs, so a stamp
-- in normal or forced mode always lands whole.
function stamp.lab()
  local surface = game.surfaces["apl-lab"]
  if not surface then
    surface = game.create_surface("apl-lab")
    surface.generate_with_lab_tiles = true
  end
  surface.request_to_generate_chunks({ 0, 0 }, 3)
  surface.force_generate_chunk_requests()
  return surface
end

-- Destroys everything in the area but characters, so a spec starts on clear ground.
function stamp.wipe(surface, area)
  for _, entity in pairs(surface.find_entities_filtered({ area = area })) do
    if entity.valid and entity.type ~= "character" then entity.destroy() end
  end
end

-- An electric energy interface and a substation, powering a square around the point.
function stamp.power(surface, force, x, y)
  surface.create_entity({ name = "electric-energy-interface", position = { x, y }, force = force })
  surface.create_entity({ name = "substation", position = { x + 2, y }, force = force })
end

return stamp
