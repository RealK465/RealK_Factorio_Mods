-- One per-player setting: offer unresearched items too. A mod setting rather than a copy in
-- storage, so the planner's own Settings panel and the game's settings menu are two faces on
-- one value -- writing it from the panel raises on_runtime_mod_setting_changed exactly as the
-- menu does -- and it follows the player into their next save.
data:extend({
  {
    type = "bool-setting",
    name = "assembly-planner-show-all",
    setting_type = "runtime-per-user",
    default_value = false,
    order = "a",
  },
})
