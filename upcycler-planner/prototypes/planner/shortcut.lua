-- The button that opens the planner. `action = "lua"` is what makes clicking it raise
-- on_lua_shortcut; the other actions are engine behaviours and none of them fit.
--
-- Gated on `recycling`, not on a quality technology. The loop this mod plans is built out of
-- recyclers, so a quality gate would offer the player a menu that cannot yet produce anything.
-- Both fields are needed: `technology_to_unlock` on its own unlocks the shortcut for every
-- future save once it has been researched in any one of them, which is not a gate at all --
-- `unavailable_until_unlocked` is what makes it per-save.

local icons = require("prototypes.planner.icons")

data:extend({
  {
    type = "shortcut",
    name = "upl-open",
    order = "b[blueprints]-u[upcycler-planner]",
    action = "lua",
    technology_to_unlock = "recycling",
    unavailable_until_unlocked = true,
    style = "green",
    icons = icons.shortcut,
    small_icons = icons.shortcut_small,
  },
})
