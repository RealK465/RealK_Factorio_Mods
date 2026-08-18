-- Stamping a plan for the specs: one owner for the blueprint-in-a-script-inventory dance, and
-- for the one number every spec that cares about coordinates needs.
--
-- The engine centres a blueprint on the position it is stamped at, by its own rule over the
-- blueprint's bounding box. Rather than reproduce that rule -- and be silently wrong the day it
-- changes -- this measures it: the leftmost-topmost position the plan asked for, against the
-- leftmost-topmost the engine actually produced. The difference is the offset from plan
-- coordinates to world coordinates, and a spec that needs to reach a specific tile adds it.
--
-- That measurement is only meaningful under a complete, unrotated stamp. If anything was
-- dropped, the two min corners can belong to DIFFERENT entities and the offset is quietly
-- wrong by a tile or two -- which is exactly the kind of near-miss a coordinate test cannot
-- tell from a real bug. So an incomplete stamp returns no offset at all: a caller that uses it
-- anyway gets an arithmetic error on the spot instead.

local blueprint = require("scripts.blueprint")

local stamp = {}

-- The leftmost-topmost corner of a list of anything carrying a position -- which a
-- BlueprintEntity and a LuaEntity both do, so one accessor spans both sides of the comparison.
local function min_corner(list)
  local x, y = math.huge, math.huge
  for _, item in pairs(list) do
    x = math.min(x, item.position.x)
    y = math.min(y, item.position.y)
  end
  return x, y
end

-- Stamps the plan and returns the created ghosts plus the plan-to-world offset.
function stamp.place(plan, surface, force, overrides)
  local entities = blueprint.entities(plan)

  local options = {
    surface = surface,
    force = force,
    position = { x = plan.width / 2, y = plan.height / 2 },
    build_mode = defines.build_mode.normal,
  }
  for key, value in pairs(overrides or {}) do options[key] = value end

  local inventory = game.create_inventory(1)
  inventory.insert({ name = "blueprint", count = 1 })
  local stack = inventory[1]
  stack.set_blueprint_entities(entities)
  local ghosts = stack.build_blueprint(options)
  inventory.destroy()

  if #ghosts ~= #entities then return ghosts end

  local want_x, want_y = min_corner(entities)
  local got_x, got_y = min_corner(ghosts)
  return ghosts, got_x - want_x, got_y - want_y
end

-- Revives everything a stamp put down, which is how a spec gets from ghosts to entities that
-- actually run. Ghosts are re-found rather than taken from the stamp's return value, so a spec
-- that stamped more than once still revives the lot.
function stamp.revive_all(surface)
  for _, ghost in pairs(surface.find_entities_filtered({ name = "entity-ghost" })) do
    if ghost.valid then
      local _, revived = ghost.revive()
      assert(revived, "a ghost refused to revive on clear ground")
    end
  end
end

return stamp
