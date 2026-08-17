-- The modal, in two blocks: what the loop MAKES -- item, target quality, machine, recycler --
-- and, under a "Build options" caption, what it is built OUT OF: the belt, the quality module,
-- the electric pole, the pipe, and whether the chests trash their surplus.
--
-- Built from scratch every time it opens and destroyed when it closes. At a couple dozen
-- elements that is simpler than repainting a persistent frame, and it makes stale state
-- impossible rather than merely unlikely. Nothing about the frame is kept in storage -- only
-- the choices, which are re-read from prototypes on the way back in.
--
-- Handlers are reached through the tag dispatcher, so what lands in saved state is a name
-- string and never a function.

local gui = {}

local dispatch = require("scripts.dispatch")
local planner = require("scripts.planner")
local state = require("scripts.state")

local FRAME = "upl-frame"
local TOOL = "upl-planner"

-- 2.0 fork: core's util.contains_value only exists from 2.1, so this branch carries the
-- four-line local where main calls util's.
local function contains_value(list, value)
  for _, entry in pairs(list) do
    if entry == value then return true end
  end
  return false
end

-- Shared with control.lua, so the event wiring and the GUI cannot drift on a rename.
gui.FRAME = FRAME
gui.TOOL = TOOL

local function frame_of(player)
  local frame = player.gui.screen[FRAME]
  if frame and frame.valid then return frame end
  return nil
end

local function widgets(frame)
  return {
    machine = frame["upl-content"]["upl-table"]["upl-machine"],
    status = frame["upl-status"],
    confirm = frame["upl-buttons"]["upl-confirm"],
  }
end

-- The -with-quality pickers hand back a {name, quality} table and take one, but storage keeps
-- the two halves as separate plain strings. Two reasons, and both fail silently: control.lua's
-- contract is that storage holds nothing but strings, and state.arm's snapshot is a SHALLOW
-- copy -- a nested table would stay shared with the live choices instead of frozen at Confirm.
local function with_quality(name, quality)
  if not name then return nil end
  return { name = name, quality = planner.build_quality(quality) }
end

-- Machines are offered per recipe, so the list has to be rebuilt whenever the item changes.
-- An empty name list is not a legal filter, so an unusable recipe drops the filter entirely
-- and leaves validation to explain why nothing works.
local function name_filter(names)
  if not names or #names == 0 then return nil end
  return { { filter = "name", name = names } }
end

local SHOW_ALL_SETTING = "upcycler-planner-show-all"
gui.SHOW_ALL_SETTING = SHOW_ALL_SETTING

-- The game's "Show all items in selection lists" option is not readable by mods, so this
-- per-player setting stands in for it.
local function show_all(player)
  return player.mod_settings[SHOW_ALL_SETTING].value
end

-- The one owner of the show-all rule: with the setting off, offer only what unlocked_of(force)
-- returns -- and an EMPTY researched subset falls back to the full filter, so the modal
-- explains itself through validation instead of turning into a dead end (an empty name list
-- is not even a legal elem_filters).
local function narrowed(player, unlocked_of, fallback)
  if not show_all(player) then
    local unlocked = unlocked_of(player.force)
    if #unlocked > 0 then return name_filter(unlocked) end
  end
  return fallback
end

local function item_filters(player)
  return narrowed(player, planner.unlocked_upcyclable_items,
    name_filter(planner.upcyclable_items()))
end

local function machine_filters(player, recipe_name)
  local recipe = recipe_name and prototypes.recipe[recipe_name]
  -- No item chosen yet is not the same as no filter: nil elem_filters would offer every
  -- entity in the game. Fall back to every machine the mod could ever plan with.
  local names = recipe and planner.machines_for(recipe) or planner.machine_candidates()
  return narrowed(player, function(force) return planner.buildable(force, names) end,
    name_filter(names))
end

local function belt_filters(player)
  return narrowed(player, planner.buildable_belts,
    { { filter = "type", type = "transport-belt" } })
end

local function recycler_filters(player)
  return narrowed(player, function(force) return planner.buildable(force, planner.recyclers()) end,
    { { filter = "crafting-category", crafting_category = "recycling" } })
end

local function quality_module_filters(player)
  return narrowed(player, planner.unlocked_quality_modules,
    name_filter(planner.quality_modules()))
end

local function pole_filters(player)
  return narrowed(player, planner.buildable_poles,
    { { filter = "type", type = "electric-pole" } })
end

local function pipe_filters(player)
  return narrowed(player, planner.buildable_pipes,
    { { filter = "type", type = "pipe" } })
end

-- The list the dropdown was BUILT from rides in its tags: research can finish while the
-- modal is open, and an index into a re-derived list would then name the wrong quality.
local function quality_options(player)
  if not show_all(player) then
    local unlocked = planner.unlocked_targets(player.force)
    if #unlocked > 0 then return unlocked end
  end
  return planner.target_qualities()
end

-- Status colours: red is "Place is disabled and this is why"; orange is "it will place, but
-- know this"; plain white is the footprint line.
local COLOR_ERROR = { r = 1, g = 0.35, b = 0.35 }
local COLOR_WARNING = { r = 1, g = 0.7, b = 0.3 }
local COLOR_PLAIN = { r = 1, g = 1, b = 1 }

function gui.refresh(player)
  local frame = frame_of(player)
  if not frame then return end

  local choices = state.of(player.index).choices
  local w = widgets(frame)

  -- validate hands back the resources it gathered so plan() does not pay for the same
  -- prototype scans twice in one refresh.
  local ok, message, gathered = planner.validate(player.force, choices)
  w.confirm.enabled = ok

  -- validate() and plan() check the same things, so a validated set of choices always yields
  -- a plan; the guard is here because a mismatch would otherwise show as a blank label.
  local plan = ok and planner.plan(player.force, choices, gathered) or nil
  if plan then
    local caption = {
      "", { "upl-gui.footprint", plan.width, plan.height },
      "  ", { "upl-gui.summary", plan.machines, plan.recyclers },
    }
    -- A message alongside ok is a warning the player can build through -- it used to be
    -- silently dropped here, which made the warnings unreachable.
    local warned = message ~= nil
    if message then
      caption[#caption + 1] = "\n"
      caption[#caption + 1] = message
    end
    -- The pole pass reports its shortfall on the plan rather than through validate, because
    -- only the built geometry knows it. Same orange as any other build-through warning.
    if plan.unpowered then
      warned = true
      caption[#caption + 1] = "\n"
      caption[#caption + 1] = { "upl-message.consumers-unpowered", plan.unpowered }
    end
    w.status.caption = caption
    w.status.style.font_color = warned and COLOR_WARNING or COLOR_PLAIN
  else
    w.status.caption = message or { "upl-gui.pick-a-recipe" }
    w.status.style.font_color = COLOR_ERROR
  end
end

function gui.close(player)
  local frame = frame_of(player)
  if frame then frame.destroy() end
end

function gui.open(player)
  gui.close(player)

  local entry = state.of(player.index)
  local choices = entry.choices

  -- Default anything not chosen yet, so the modal opens usable rather than empty.
  if not choices.recycler then
    choices.recycler = planner.best_recycler(player.force)
  end
  -- Highest offered target by default -- and a remembered choice that is no longer offered
  -- (legendary picked under "show all", say, then the setting turned off) snaps back too,
  -- because the dropdown could not display it.
  local offered_targets = quality_options(player)
  if not contains_value(offered_targets, choices.quality) then
    choices.quality = offered_targets[#offered_targets]
  end

  if not choices.belt then
    choices.belt = planner.belt(player.force)
  end
  if not choices.quality_module then
    choices.quality_module = planner.quality_module(player.force)
  end
  -- Only used when the recipe takes a fluid, but always defaulted so the strip never shows
  -- an empty button for a material that has a researched answer.
  if not choices.pipe then
    choices.pipe = planner.pipe(player.force)
  end
  -- The pole differs from the pair above: clearing it is a real choice ("no poles"),
  -- recorded in no_poles, so only a never-touched picker gets the default.
  if not choices.pole and not choices.no_poles then
    choices.pole = planner.pole(player.force)
  end
  -- The quality the buildings and modules are placed AT, which is nothing to do with the
  -- target above. Normal until the player says otherwise, and normalised on the way in so a
  -- tier some mod has since removed can never reach a picker.
  choices.machine_quality = planner.build_quality(choices.machine_quality)
  choices.recycler_quality = planner.build_quality(choices.recycler_quality)
  choices.quality_module_quality = planner.build_quality(choices.quality_module_quality)
  choices.pole_quality = planner.build_quality(choices.pole_quality)
  -- nil means the checkbox has never been touched; it starts checked.
  if choices.trash_unrequested == nil then
    choices.trash_unrequested = true
  end

  local frame = player.gui.screen.add({ type = "frame", name = FRAME, direction = "vertical" })
  frame.auto_center = true
  -- Makes Esc and E close the modal the way every other window in the game closes.
  player.opened = frame

  local titlebar = frame.add({ type = "flow", direction = "horizontal" })
  titlebar.drag_target = frame
  titlebar.add({
    type = "label", style = "frame_title", caption = { "upl-gui.title" },
    ignored_by_interaction = true,
  })
  local filler = titlebar.add({ type = "empty-widget", style = "draggable_space_header" })
  filler.style.height = 24
  filler.style.horizontally_stretchable = true
  filler.drag_target = frame
  titlebar.add({
    type = "sprite-button", style = "frame_action_button", sprite = "utility/close",
    tags = dispatch.tags("close"),
  })

  -- What the loop makes.
  local content = frame.add({
    type = "frame", name = "upl-content", style = "inside_shallow_frame_with_padding",
    direction = "vertical",
  })
  content.style.horizontally_stretchable = true
  local rows = content.add({ type = "table", name = "upl-table", column_count = 2 })

  -- Each row is a label whose caption and tooltip follow the same locale convention, so the
  -- convention is stated once here instead of at every row below.
  local function label(key)
    rows.add({
      type = "label",
      caption = { "upl-gui." .. key },
      tooltip = { "upl-gui." .. key .. "-tooltip" },
    })
  end

  -- An ITEM picker, not a recipe picker: it is how the mod is described, and it is also the
  -- only one the engine can restrict to a computed list, since RecipePrototypeFilter has no
  -- "name" filter while ItemPrototypeFilter does. The recipe is derived from the item.
  --
  -- elem_value is assigned AFTER add() on every picker below: it is a runtime attribute, not
  -- a creation parameter, and add() ignores unknown fields without a word -- passed inline it
  -- simply never took, and the pickers opened empty.
  label("recipe")
  local recipe_button = rows.add({
    type = "choose-elem-button", name = "upl-recipe", elem_type = "item",
    elem_filters = item_filters(player),
    tags = dispatch.tags("recipe"),
  })
  recipe_button.elem_value = choices.recipe and planner.product_of(prototypes.recipe[choices.recipe])

  local quality_items, selected = {}, 1
  for index, name in pairs(offered_targets) do
    quality_items[index] = { "", "[quality=" .. name .. "] ", prototypes.quality[name].localised_name }
    if name == choices.quality then selected = index end
  end
  label("quality")
  rows.add({
    type = "drop-down", name = "upl-quality", items = quality_items, selected_index = selected,
    tags = dispatch.tags("quality", { targets = offered_targets }),
  })

  label("machine")
  local machine_button = rows.add({
    type = "choose-elem-button", name = "upl-machine", elem_type = "entity-with-quality",
    elem_filters = machine_filters(player, choices.recipe),
    tags = dispatch.tags("machine"),
  })
  machine_button.elem_value = with_quality(choices.machine, choices.machine_quality)

  -- Vanilla ships exactly one recycler, so this used to be a choice between one thing and the
  -- row was hidden. It is a real choice on any modset now, because the quality the recyclers
  -- are BUILT at is picked here.
  label("recycler")
  local recycler_button = rows.add({
    type = "choose-elem-button", name = "upl-recycler", elem_type = "entity-with-quality",
    elem_filters = recycler_filters(player),
    tags = dispatch.tags("recycler"),
  })
  recycler_button.elem_value = with_quality(choices.recycler, choices.recycler_quality)

  -- What the loop is built out of. These pickers carry no row label -- they read as a strip of
  -- icons, the way the game's own tool settings do -- so each tooltip has to name its own
  -- control: the row label it would have had, promoted to a bold first line.
  local function strip_tooltip(key)
    return {
      "", "[font=default-bold]", { "upl-gui." .. key }, "[/font]\n",
      { "upl-gui." .. key .. "-tooltip" },
    }
  end

  local caption = frame.add({
    type = "label", style = "caption_label", caption = { "upl-gui.build-options" },
  })
  caption.style.top_margin = 8

  local options = frame.add({
    type = "frame", name = "upl-options", style = "inside_shallow_frame_with_padding",
    direction = "vertical",
  })
  options.style.horizontally_stretchable = true

  local strip = options.add({ type = "flow", name = "upl-strip", direction = "horizontal" })

  -- No quality on the belt: belt_speed is a plain attribute with no quality variant, unlike
  -- get_crafting_speed(quality), so a legendary belt would carry exactly as much.
  local belt_button = strip.add({
    type = "choose-elem-button", name = "upl-belt", elem_type = "entity",
    elem_filters = belt_filters(player),
    tooltip = strip_tooltip("belt"),
    tags = dispatch.tags("belt"),
  })
  belt_button.elem_value = choices.belt

  local module_button = strip.add({
    type = "choose-elem-button", name = "upl-quality-module", elem_type = "item-with-quality",
    elem_filters = quality_module_filters(player),
    tooltip = strip_tooltip("quality-module"),
    tags = dispatch.tags("quality-module"),
  })
  module_button.elem_value = with_quality(choices.quality_module, choices.quality_module_quality)

  local pole_button = strip.add({
    type = "choose-elem-button", name = "upl-pole", elem_type = "entity-with-quality",
    elem_filters = pole_filters(player),
    tooltip = strip_tooltip("pole"),
    tags = dispatch.tags("pole"),
  })
  pole_button.elem_value = with_quality(choices.pole, choices.pole_quality)

  -- No quality on the pipe for the belt's reason: nothing about a pipe scales with quality.
  local pipe_button = strip.add({
    type = "choose-elem-button", name = "upl-pipe", elem_type = "entity",
    elem_filters = pipe_filters(player),
    tooltip = strip_tooltip("pipe"),
    tags = dispatch.tags("pipe"),
  })
  pipe_button.elem_value = choices.pipe

  local trash = options.add({
    type = "checkbox", name = "upl-trash", state = choices.trash_unrequested,
    caption = { "upl-gui.trash-unrequested" },
    tooltip = { "upl-gui.trash-unrequested-tooltip" },
    tags = dispatch.tags("trash"),
  })
  -- Margin, never padding: padding shifts a checkbox's CONTENT -- the check mark -- while the
  -- box graphic stays put, so the mark ends up hanging half out of the square.
  trash.style.top_margin = 8

  -- Wrapped rather than single-line: the longest validation messages run to a sentence and a
  -- half, and an unbounded label drags the whole modal out to their width.
  local status = frame.add({ type = "label", name = "upl-status", caption = "" })
  status.style.top_margin = 8
  status.style.single_line = false
  status.style.maximal_width = 360

  local buttons = frame.add({ type = "flow", name = "upl-buttons", direction = "horizontal" })
  buttons.style.top_padding = 4
  -- Same handler as the titlebar's close button: cancelling IS closing.
  buttons.add({
    type = "button", name = "upl-cancel", style = "back_button",
    caption = { "upl-gui.cancel" }, tags = dispatch.tags("close"),
  })
  local spacer = buttons.add({ type = "empty-widget" })
  spacer.style.horizontally_stretchable = true
  buttons.add({
    type = "button", name = "upl-confirm", style = "confirm_button",
    caption = { "upl-gui.confirm" }, tags = dispatch.tags("confirm"),
  })

  gui.refresh(player)
end

function gui.toggle(player)
  if frame_of(player) then gui.close(player) else gui.open(player) end
end

-- Reopened rather than repainted when the show-all setting flips: open() rereads the setting
-- and rebuilds every filter and the quality list from it.
function gui.on_setting_changed(player)
  if frame_of(player) then gui.open(player) end
end

dispatch.register("close", function(event)
  gui.close(game.get_player(event.player_index))
end)

dispatch.register("recipe", function(event)
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  -- The button holds the item; the recipe that makes it is what everything else works from.
  choices.recipe = planner.recipe_for_item(event.element.elem_value)

  -- The machine list depends on the recipe, so a machine that can no longer craft it is
  -- replaced rather than left behind to fail validation confusingly. Its QUALITY survives the
  -- swap: the player asked for legendary machines, not for a legendary assembler specifically.
  local recipe = choices.recipe and prototypes.recipe[choices.recipe]
  if recipe and not contains_value(planner.machines_for(recipe), choices.machine) then
    choices.machine = planner.best_machine(player.force, recipe)
  end

  -- The machine picker's filter depends only on the recipe, so it is rebuilt here (and at
  -- open) rather than on every widget event in refresh.
  local frame = frame_of(player)
  if frame then
    local machine_button = widgets(frame).machine
    machine_button.elem_filters = machine_filters(player, choices.recipe)
    machine_button.elem_value = with_quality(choices.machine, choices.machine_quality)
  end
  gui.refresh(player)
end)

dispatch.register("quality", function(event)
  local choices = state.of(event.player_index).choices
  -- Read the list this dropdown was built from, never a re-derived one: research finishing
  -- while the modal is open would shift a re-derived list under the selected index.
  local targets = event.element.tags.targets
  choices.quality = targets[event.element.selected_index]
  gui.refresh(game.get_player(event.player_index))
end)

dispatch.register("machine", function(event)
  local choices = state.of(event.player_index).choices
  local value = event.element.elem_value
  choices.machine = value and value.name
  -- Clearing the button keeps the quality. The recipe handler already reasons that the player
  -- asked for legendary machines rather than for a legendary assembler specifically, and
  -- clearing to re-pick is the same intent; resetting to normal would quietly undo it.
  if value then choices.machine_quality = planner.build_quality(value.quality) end
  gui.refresh(game.get_player(event.player_index))
end)

dispatch.register("recycler", function(event)
  local choices = state.of(event.player_index).choices
  local value = event.element.elem_value
  choices.recycler = value and value.name
  -- Kept on clear, same reasoning as the machine above.
  if value then choices.recycler_quality = planner.build_quality(value.quality) end
  gui.refresh(game.get_player(event.player_index))
end)

dispatch.register("belt", function(event)
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  choices.belt = event.element.elem_value
  -- An emptied button falls straight back to the fastest researched belt, and shows it, so the
  -- strip always displays the belt that would actually be placed.
  if not choices.belt then
    choices.belt = planner.belt(player.force)
    event.element.elem_value = choices.belt
  end
  gui.refresh(player)
end)

dispatch.register("quality-module", function(event)
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  local value = event.element.elem_value
  choices.quality_module = value and value.name
  if value then choices.quality_module_quality = planner.build_quality(value.quality) end
  -- Same rule as the belt: emptied means "back to the best I have researched", and shown.
  if not choices.quality_module then
    choices.quality_module = planner.quality_module(player.force)
    event.element.elem_value =
      with_quality(choices.quality_module, choices.quality_module_quality)
  end
  gui.refresh(player)
end)

dispatch.register("pipe", function(event)
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  choices.pipe = event.element.elem_value
  -- The belt's rule: emptied means "back to the best I have researched", and shown.
  if not choices.pipe then
    choices.pipe = planner.pipe(player.force)
    event.element.elem_value = choices.pipe
  end
  gui.refresh(player)
end)

dispatch.register("pole", function(event)
  local choices = state.of(event.player_index).choices
  local value = event.element.elem_value
  choices.pole = value and value.name
  -- The one picker where an emptied button does NOT snap back: clearing means "place no
  -- poles", and the empty button showing nothing is exactly that state on display.
  choices.no_poles = not value
  if value then choices.pole_quality = planner.build_quality(value.quality) end
  gui.refresh(game.get_player(event.player_index))
end)

dispatch.register("trash", function(event)
  -- One click fires this from both on_gui_click and on_gui_checked_state_changed; reading the
  -- element's current state makes the second run a harmless repeat.
  state.of(event.player_index).choices.trash_unrequested = event.element.state
end)

-- Confirm does not build anything. It snapshots the choices and hands the player a tool, so
-- the ghosts land where they click and nowhere else.
dispatch.register("confirm", function(event)
  local player = game.get_player(event.player_index)
  local entry = state.of(event.player_index)

  local ok = planner.validate(player.force, entry.choices)
  if not ok then return end

  -- A spectator has no cursor_stack at all, so there is nowhere to put the tool.
  if not player.cursor_stack then
    player.print({ "upl-message.no-cursor" })
    return
  end

  -- clear_cursor can FAIL -- full cursor, full inventory -- and set_stack on top of that
  -- failure would overwrite, and so destroy, whatever the player is holding. The modal stays
  -- open, so freeing a hand and pressing Place again is the whole recovery.
  if not (player.clear_cursor() and player.cursor_stack.set_stack({ name = TOOL, count = 1 })) then
    player.print({ "upl-message.cursor-full" })
    return
  end

  -- Armed only after the tool is actually in the cursor, so a failed confirm leaves no
  -- snapshot behind for a stale tool to act on.
  state.arm(event.player_index)

  gui.close(player)
end)

return gui
