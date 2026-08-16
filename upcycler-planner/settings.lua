-- The game's own "Show all items in selection lists" interface option is not readable by
-- mods, so this stands in for it: with it off (the default) the planner's pickers offer only
-- what the force has researched.
data:extend({
  {
    type = "bool-setting",
    name = "upcycler-planner-show-all",
    setting_type = "runtime-per-user",
    default_value = false,
    order = "a",
  },
})
