-- The canonical vanilla layout_params fixture the pure specs share: the 3-tier iron-gear
-- loop with vanilla footprints, exactly the shape planner.plan() hands layout.build(). One
-- copy on purpose -- the two pure specs carried it independently for a day and drifted on
-- their first unattended field. Pure by construction: only defines.direction is touched, and
-- only when called, so the host runner loads this file identically to the game.

local layout_params = {}

function layout_params.vanilla(overrides)
  local params = {
    recipe = {
      name = "iron-gear-wheel", product = "iron-gear-wheel",
      ingredients = { { name = "iron-plate", amount = 2, type = "item" } },
    },
    tiers = { "normal", "uncommon", "rare" },
    above_target = { "epic", "legendary" },
    machine = { name = "assembling-machine-2", quality = "normal", width = 3, height = 3, module_slots = 2 },
    recycler = {
      name = "recycler", quality = "normal", width = 2, height = 4, module_slots = 4,
      direction = defines.direction.north,
    },
    -- A bare name where the thing has no quality (belt, pipe), a { name, quality } pair where
    -- the player picks one -- the same split planner.plan hands over.
    belt = "transport-belt",
    inserter = { name = "fast-inserter", quality = "normal" },
    requester = { name = "requester-chest", quality = "normal" },
    container = { name = "iron-chest", quality = "normal" },
    provider = { name = "passive-provider-chest", quality = "normal" },
    modules = {
      quality_module = { name = "quality-module", quality = "normal" },
      terminal_module = { name = "productivity-module", quality = "normal" },
    },
    requests = { ["iron-plate"] = 100 },
    product_buffer = 50,
  }
  for key, value in pairs(overrides or {}) do params[key] = value end
  return params
end

return layout_params
