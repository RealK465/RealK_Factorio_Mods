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
})
