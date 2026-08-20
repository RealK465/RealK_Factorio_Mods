-- Lifecycle and event wiring, and nothing else -- the work lives in scripts/.
--
-- Every registration is at the top level and appears exactly once. script.on_event silently
-- REPLACES an earlier handler for the same event, so a second registration anywhere would make
-- the first one quietly stop running; and top level is the only place that runs on both init
-- and load, which is what makes the handlers exist again after a save is reloaded.
--
-- There is deliberately no on_load. Its three legitimate uses are reattaching metatables,
-- re-registering conditional handlers, and taking local references into storage, and this mod
-- does none of them: storage holds plain strings, every handler is unconditional, and the plan
-- is designed and handed over inside a single event, so no work is ever left in flight across
-- a save.

local state = require("scripts.state")
local dispatch = require("scripts.dispatch")
local gui = require("scripts.gui")

-- The shortcut and its hotkey share gui.SHORTCUT as their prototype name; only the confirm
-- input's name lives here.
local CONFIRM_INPUT = "upl-confirm"

script.on_init(state.init)

script.on_configuration_changed(function()
  -- A removed mod can leave a choice pointing at a prototype that no longer exists, and an
  -- open frame would still be showing the old one.
  state.prune()
  for _, player in pairs(game.players) do
    gui.close(player)
  end
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name ~= gui.SHORTCUT then return end
  gui.toggle(game.get_player(event.player_index))
end)

-- The same toggle from the keyboard -- CTRL+SHIFT+U by default, rebindable in the controls
-- menu. The custom input shares the shortcut's prototype name, and gui.toggle_key is what
-- keeps the key behind the same recycling unlock as the button: a custom input fires whether
-- or not the shortcut is available.
script.on_event(gui.SHORTCUT, function(event)
  gui.toggle_key(game.get_player(event.player_index))
end)

-- The game's "Confirm window" key -- E by default -- reaching the modal's Place button, so the
-- planner confirms like any vanilla dialog. Registered by prototype name, the way custom-inputs
-- are; gui.confirm_key does the deciding, because it is the one that knows whether there is a
-- modal to confirm and whether an element chooser is presumed to be floating over it -- a press
-- aimed at THAT belongs to the chooser, not to Place. The key fires wherever the player is, so
-- this handler is on every press of E in the game and its first act must stay cheap lookups.
--
-- The engine's own close still runs straight after this, since the input is linked with
-- consuming "none" and prototypes/planner/input.lua says why that cannot change. It costs
-- nothing on the paths that matter: a confirm closes the modal itself, and a press with nothing
-- to confirm should close it anyway.
script.on_event(CONFIRM_INPUT, function(event)
  gui.confirm_key(game.get_player(event.player_index))
end)

-- All four GUI events go through the one dispatcher, which reads the handler name off the
-- element's tags; on_gui_closed below is separate because it is about the frame, not a widget.
script.on_event(defines.events.on_gui_click, dispatch.on_gui_event)
script.on_event(defines.events.on_gui_elem_changed, dispatch.on_gui_event)
script.on_event(defines.events.on_gui_selection_state_changed, dispatch.on_gui_event)
script.on_event(defines.events.on_gui_checked_state_changed, dispatch.on_gui_event)

script.on_event(defines.events.on_gui_closed, function(event)
  local element = event.element
  if not (element and element.valid) then return end
  local player = game.get_player(event.player_index)
  if element.name == gui.SETTINGS_FRAME then
    gui.close_settings(player)
  elseif element.name == gui.FRAME and not gui.settings_open(player) then
    -- The guard is not defensive: only one element at a time can own player.opened, so the
    -- settings window taking it ASKS the modal to close and this handler is where that
    -- arrives (measured 2.1.14 -- without the check the modal is destroyed the instant the
    -- window opens). A real Esc can only reach here while the modal still owns `opened`,
    -- which is exactly when no settings window exists.
    gui.close(player)
  end
end)

-- There is deliberately no placement handler: Confirm hands over an ordinary blueprint, and
-- everything after that is the engine's. What that buys, and why none of it is ours to
-- reimplement, is in scripts/blueprint.lua.

-- Both settings arrive here whichever surface changed them: the modal's own settings
-- window writes the setting rather than keeping a private copy, so its ticks and the game's
-- settings menu take one path.
script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if not (event.player_index and gui.is_setting(event.setting)) then return end
  gui.on_setting_changed(game.get_player(event.player_index))
end)

script.on_event(defines.events.on_player_removed, function(event)
  state.forget(event.player_index)
end)

-- Test suite, active only when the factorio-test framework mod is loaded -- never in a normal
-- game. Registered last so the framework's own hooks (it drives runs off on_tick, which this
-- mod does not use) land after every real handler above. Run via the factorio-testing skill.
if script.active_mods["factorio-test"] then
  -- Replaces the plain state.init registration above -- deliberately, and only in test runs:
  -- the graphics tier loads a --create save, and freeplay's intro dialog plus crash-site
  -- cutscene would otherwise block the first join waiting for a human click.
  script.on_init(function()
    state.init()
    if remote.interfaces["freeplay"] then
      remote.call("freeplay", "set_skip_intro", true)
      remote.call("freeplay", "set_disable_crashsite", true)
    end
  end)

  require("__factorio-test__/init")({
    "tests.pure.layout_spec",
    "tests.pure.poles_spec",
    "tests.state_spec",
    "tests.planner_spec",
    "tests.plan_spec",
    "tests.blueprint_spec",
    "tests.loop_spec",
    "tests.fluid_spec",
    "tests.gui_spec",
  }, { default_ticks_between_tests = 1 })
end
