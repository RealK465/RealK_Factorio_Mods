-- Lifecycle and event wiring, and nothing else -- the work lives in scripts/.
--
-- Every registration is at the top level and appears exactly once: script.on_event silently
-- REPLACES an earlier handler for the same event, and top level is the only place that runs on
-- both init and load.
--
-- There is deliberately no on_load: storage holds plain values, every handler is
-- unconditional, and a plan is designed and handed over inside a single event, so nothing is
-- ever left in flight across a save.

local state = require("scripts.state")
local dispatch = require("scripts.dispatch")
local gui = require("scripts.gui")

local CONFIRM_INPUT = "apl-confirm"

script.on_init(state.init)

script.on_configuration_changed(function()
  -- A removed mod can leave a choice pointing at a prototype that no longer exists, and an open
  -- window would still be showing it. A changed mod set can also move the shortcut's gate onto
  -- a technology this save already has.
  state.prune()
  for _, player in pairs(game.players) do
    gui.close(player)
    gui.unlock_shortcut(player)
  end
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name ~= gui.SHORTCUT then return end
  gui.toggle(game.get_player(event.player_index))
end)

-- The same toggle from the keyboard. A custom input fires whether or not the shortcut is
-- unlocked, which is why gui.toggle_key re-checks the gate.
script.on_event(gui.SHORTCUT, function(event)
  gui.toggle_key(game.get_player(event.player_index))
end)

-- The game's "Confirm window" key, E by default, reaching Place. It fires on every press of E
-- anywhere in the game, so gui.confirm_key's first act is a cheap lookup. The engine's own
-- close still runs after it (prototypes/planner/input.lua says why).
script.on_event(CONFIRM_INPUT, function(event)
  gui.confirm_key(game.get_player(event.player_index))
end)

script.on_event({
  defines.events.on_gui_click,
  defines.events.on_gui_elem_changed,
  defines.events.on_gui_selection_state_changed,
  defines.events.on_gui_checked_state_changed,
  defines.events.on_gui_text_changed,
  defines.events.on_gui_confirmed,
}, dispatch.on_gui_event)

script.on_event(defines.events.on_gui_closed, function(event)
  local element = event.element
  if not (element and element.valid) or element.name ~= gui.FRAME then return end
  local player = game.get_player(event.player_index)
  if gui.close_side_panel(player) then
    -- Esc with a side panel up dismisses just the panel, the way a nested window would go. The
    -- engine has already nilled player.opened; retake it only when nothing else claimed it, so a
    -- clicked chest keeps its chest.
    if player.opened == nil then player.opened = element end
  else
    gui.close(player)
  end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if not (event.player_index and gui.is_setting(event.setting)) then return end
  gui.on_setting_changed(game.get_player(event.player_index))
end)

-- The closes the engine performs without raising on_gui_closed -- dying, becoming a spectator,
-- disconnecting -- reach gui.close_if_unfocused. A disconnect raises no controller change, so
-- the rejoin is where that one is caught.
script.on_event({
  defines.events.on_player_controller_changed,
  defines.events.on_player_joined_game,
}, function(event)
  gui.close_if_unfocused(game.get_player(event.player_index))
end)

script.on_event(defines.events.on_player_removed, function(event)
  state.forget(event.player_index)
end)

-- Test suite, active only when the factorio-test framework mod is loaded -- never in a normal
-- game. Registered last so the framework's own hooks land after every real handler. Run via
-- the repo's factorio-testing skill.
if script.active_mods["factorio-test"] then
  -- Replaces the plain state.init registration above, and only in test runs: freeplay's intro
  -- and crash-site cutscene would otherwise block a graphics run's first join.
  script.on_init(function()
    state.init()
    if remote.interfaces["freeplay"] then
      remote.call("freeplay", "set_skip_intro", true)
      remote.call("freeplay", "set_disable_crashsite", true)
    end
  end)

  require("__factorio-test__/init")({
    "tests.pure.cell_spec",
    "tests.pure.calc_spec",
    "tests.pure.poles_spec",
    "tests.pure.gate_spec",
    "tests.proto_spec",
    "tests.plan_spec",
    "tests.blueprint_spec",
    "tests.cell_live_spec",
    "tests.throughput_live_spec",
    "tests.state_spec",
    "tests.gui_spec",
  }, { default_ticks_between_tests = 1 })
end
