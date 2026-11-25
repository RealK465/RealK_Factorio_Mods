-- The button that opens the planner. `action = "lua"` is what makes clicking it raise
-- on_lua_shortcut.
--
-- Gated on the technology that delivers a requester chest: the cell feeds its machine from
-- one, so the planner would only ever hand over a blueprint that cannot run without it.
-- `logistic-system` is vanilla's answer and only the default -- data-final-fixes.lua moves the
-- gate to whichever technology unlocks a requester first once every mod has had its say. Both
-- fields are needed: `technology_to_unlock` alone unlocks the shortcut for every future save
-- once it has been researched in any one of them; `unavailable_until_unlocked` makes it per-save.

local icons = require("prototypes.planner.icons")

data:extend({
  {
    type = "shortcut",
    name = "apl-open",
    order = "b[blueprints]-a[assembly-planner]",
    action = "lua",
    technology_to_unlock = "logistic-system",
    unavailable_until_unlocked = true,
    -- Shows the hotkey in the tooltip; the input lives in input.lua under the same name.
    associated_control_input = "apl-open",
    style = "green",
    icons = icons.shortcut,
    small_icons = icons.shortcut_small,
  },
})
