-- The button that opens the planner. `action = "lua"` is what makes clicking it raise
-- on_lua_shortcut; the other actions are engine behaviours and none of them fit.
--
-- Gated on the technology that delivers a recycler, not on a quality technology. The loop this
-- mod plans is built out of recyclers, so a quality gate would offer the player a menu that
-- cannot yet produce anything. `recycling` is vanilla's answer and only the default:
-- data-final-fixes.lua moves the gate to whichever technology unlocks a recycler first once
-- every mod has had its say. Both fields are needed: `technology_to_unlock` on its own unlocks
-- the shortcut for every future save once it has been researched in any one of them, which is
-- not a gate at all -- `unavailable_until_unlocked` is what makes it per-save.

local icons = require("prototypes.planner.icons")

data:extend({
  {
    type = "shortcut",
    name = "upl-open",
    order = "b[blueprints]-u[upcycler-planner]",
    action = "lua",
    technology_to_unlock = "recycling",
    unavailable_until_unlocked = true,
    -- Shows the hotkey in the button's tooltip, and nothing else -- the input itself lives in
    -- input.lua under the same name, and control.lua honours this gate for it.
    associated_control_input = "upl-open",
    style = "green",
    icons = icons.shortcut,
    small_icons = icons.shortcut_small,
  },
})
