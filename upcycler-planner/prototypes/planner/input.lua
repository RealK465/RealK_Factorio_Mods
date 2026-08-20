-- The game's own "Confirm window" key -- E by default -- pointed at the modal's Place button, so
-- the planner confirms the way every vanilla dialog does. Nothing else gives a mod GUI that:
-- on_gui_closed carries no key, so the close handler cannot tell E from Esc, and on_gui_confirmed
-- fires only for Enter in a textfield, which this modal has none of.
--
-- LINKED rather than bound to a key of its own. A linked custom-input rides whatever the player
-- has bound the vanilla control to, stays out of the controls GUI, and so needs no locale key and
-- no second binding to keep in step with theirs.
--
-- `consuming` is left at its default "none", and that is a constraint rather than a preference:
-- "game-only" blocks the linked control everywhere, so E would stop opening the inventory. The
-- price is that the engine's own close still runs after our handler -- control.lua says what that
-- costs.

data:extend({
  {
    type = "custom-input",
    name = "upl-confirm",
    key_sequence = "",
    linked_game_control = "confirm-gui",
  },
  -- The keyboard way to the shortcut button: same prototype name as the shortcut, which is the
  -- Krastorio 2 pairing shape -- the button's `associated_control_input` points here, so its
  -- tooltip advertises the binding and the two rename together. Unlike upl-confirm this one is
  -- a real binding of its own, so it appears in the controls menu and needs its [controls]
  -- locale key. CONTROL is the control key on every platform; a mac's COMMAND is its own
  -- modifier name, not a translation of this one.
  {
    type = "custom-input",
    name = "upl-open",
    key_sequence = "CONTROL + U",
  },
})
