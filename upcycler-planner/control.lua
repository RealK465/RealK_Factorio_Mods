-- Lifecycle and event wiring, and nothing else -- the work lives in scripts/.
--
-- Every registration is at the top level and appears exactly once. script.on_event silently
-- REPLACES an earlier handler for the same event, so a second registration anywhere would make
-- the first one quietly stop running; and top level is the only place that runs on both init
-- and load, which is what makes the handlers exist again after a save is reloaded.
--
-- There is deliberately no on_load. Its three legitimate uses are reattaching metatables,
-- re-registering conditional handlers, and taking local references into storage, and this mod
-- does none of them: storage holds plain strings, every handler is unconditional, and
-- placement happens inside a single event so no work is ever left in flight across a save.

local state = require("scripts.state")
local dispatch = require("scripts.dispatch")
local gui = require("scripts.gui")
local planner = require("scripts.planner")
local builder = require("scripts.builder")

local SHORTCUT = "upl-open"

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
  if event.prototype_name ~= SHORTCUT then return end
  gui.toggle(game.get_player(event.player_index))
end)

-- All four GUI events go through the one dispatcher, which reads the handler name off the
-- element's tags; on_gui_closed below is separate because it is about the frame, not a widget.
script.on_event(defines.events.on_gui_click, dispatch.on_gui_event)
script.on_event(defines.events.on_gui_elem_changed, dispatch.on_gui_event)
script.on_event(defines.events.on_gui_selection_state_changed, dispatch.on_gui_event)
script.on_event(defines.events.on_gui_checked_state_changed, dispatch.on_gui_event)

script.on_event(defines.events.on_gui_closed, function(event)
  local element = event.element
  if element and element.valid and element.name == gui.FRAME then
    gui.close(game.get_player(event.player_index))
  end
end)

-- The click that decides where the loop goes. The plan is rebuilt from the snapshot taken at
-- Confirm rather than from the live choices, so reopening the modal while the tool is in hand
-- cannot change what is about to be placed.
local function place_selection(event)
  if event.item ~= gui.TOOL then return end

  local player = game.get_player(event.player_index)
  local entry = state.of(event.player_index)

  -- Either a configuration change pruned the snapshot while the tool was armed, or -- despite
  -- validate() covering everything plan() needs -- the plan failed. Both end the same way:
  -- take the tool back and say so, because a tool that silently does nothing on every click,
  -- with the player left holding it and no idea why, is the worst failure this flow can have.
  local plan = entry.pending and planner.plan(player.force, entry.pending)
  if not plan then
    entry.pending = nil
    player.clear_cursor()
    player.print({ "upl-message.plan-failed" })
    return
  end

  -- Centre the layout on the click, the way stamping a blueprint centres it on the cursor.
  local area = event.area
  local anchor = {
    x = math.floor((area.left_top.x + area.right_bottom.x) / 2 - plan.width / 2),
    y = math.floor((area.left_top.y + area.right_bottom.y) / 2 - plan.height / 2),
  }

  -- The surface comes from the event, not the player: on_player_selected_area names the
  -- surface the selection actually happened on, which is the authoritative one.
  local placed, blocked_at = builder.place(plan, anchor, {
    surface = event.surface,
    force = player.force,
    player = player,
  })
  if not placed then
    -- The tool stays in the cursor, so trying somewhere else is just another click.
    player.create_local_flying_text({
      text = { "upl-message.placement-blocked" },
      position = blocked_at,
    })
    return
  end

  entry.pending = nil
  player.clear_cursor()
  if plan.unpowered then
    player.print({ "upl-message.placed-unpowered", placed, plan.unpowered })
  else
    player.print({ "upl-message.placed", placed })
  end
end

script.on_event(defines.events.on_player_selected_area, place_selection)
script.on_event(defines.events.on_player_alt_selected_area, place_selection)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting ~= gui.SHOW_ALL_SETTING or not event.player_index then return end
  gui.on_setting_changed(game.get_player(event.player_index))
end)

script.on_event(defines.events.on_player_removed, function(event)
  state.forget(event.player_index)
end)
