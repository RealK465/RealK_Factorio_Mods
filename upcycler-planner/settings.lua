-- The two settings, both per-player and both off by default: offer unresearched items, and
-- show every build option picker rather than only the ones with a real choice.
--
-- They are mod SETTINGS rather than a private copy in storage, even though the modal's own
-- settings window is where a player will actually tick them. A mod may overwrite its own
-- per-player settings, and doing so raises on_runtime_mod_setting_changed exactly as the game's
-- settings menu does (both measured on 2.1.14), so the window is a second face on one value
-- instead of a second value -- and a setting made here follows the player into their next save,
-- which a storage-backed one would not. Factory Planner keeps its own preferences in storage;
-- it has thirty of them and no use for the settings menu, which is the difference.
data:extend({
  {
    type = "bool-setting",
    name = "upcycler-planner-show-all",
    setting_type = "runtime-per-user",
    default_value = false,
    order = "a",
  },
  {
    type = "bool-setting",
    name = "upcycler-planner-show-all-build-options",
    setting_type = "runtime-per-user",
    default_value = false,
    order = "b",
  },
})
