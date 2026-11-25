-- The game's own "Confirm window" key -- E by default -- pointed at the planner's Place button,
-- so it confirms the way every vanilla dialog does. LINKED rather than bound to a key of its
-- own: it rides whatever the player bound the vanilla control to, stays out of the controls
-- GUI and needs no locale key.
--
-- `consuming` stays at its default "none": "game-only" would block the linked control
-- everywhere, so E would stop opening the inventory. The engine's own close therefore still
-- runs after our handler, which control.lua accounts for.

data:extend({
  {
    type = "custom-input",
    name = "apl-confirm",
    key_sequence = "",
    linked_game_control = "confirm-gui",
  },
  -- The keyboard way to the shortcut: same prototype name as the shortcut, so the button's
  -- tooltip advertises the binding and the two rename together. A real binding of its own,
  -- so it appears in the controls menu and needs its [controls] locale key.
  {
    type = "custom-input",
    name = "apl-open",
    key_sequence = "CONTROL + SHIFT + A",
  },
})
