-- The modal, in two blocks: what the loop MAKES -- item, target quality, machine, recycler --
-- and, under a "Build options" caption, what it is built OUT OF: the belt, the inserter, the
-- three chests, the quality module, the top machine's own module, the electric pole, the pipe,
-- and whether the chests trash their surplus.
--
-- A picker is only built visible when it has something to choose BETWEEN: one option is not a
-- choice, so in a vanilla game the recycler, the requester chest, the output chest and the pipe
-- are hidden, and a modset that adds an alternative brings each of them back. Five pickers are
-- exempt because they are the choice whatever the count -- item, target quality, machine, belt,
-- quality module -- and two more because clearing them IS the second option: the pole ("no
-- poles") and the top machine's module ("leave it empty"). The pipe has one more condition of its
-- own: it is out of the strip entirely until the recipe takes a fluid.
--
-- A second, smaller frame opens BESIDE the modal -- to its right, top edges level -- when the
-- titlebar's settings button is pressed. It holds the two per-player settings the pickers read:
-- offer unresearched items, and show every picker whatever the count. The second is the escape
-- hatch for what hiding costs, since a hidden picker takes its QUALITY box with it; ticked, every
-- picker is shown, the pipe included even for a recipe with no fluid.
--
-- Built from scratch every time it opens and destroyed when it closes. At a couple dozen
-- elements that is simpler than repainting a persistent frame, and it makes stale state
-- impossible rather than merely unlikely. Nothing about the frame is kept in storage -- only
-- the choices, which are re-read from prototypes on the way back in.
--
-- Handlers are reached through the tag dispatcher, so what lands in saved state is a name
-- string and never a function.

local gui = {}

local util = require("util")
local dispatch = require("scripts.dispatch")
local planner = require("scripts.planner")
local state = require("scripts.state")

local FRAME = "upl-frame"
local SETTINGS_FRAME = "upl-settings"
local TOOL = "upl-planner"

-- Shared with control.lua, so the event wiring and the GUI cannot drift on a rename.
gui.FRAME = FRAME
gui.SETTINGS_FRAME = SETTINGS_FRAME
gui.TOOL = TOOL

local function frame_of(player)
  local frame = player.gui.screen[FRAME]
  if frame and frame.valid then return frame end
  return nil
end

local function settings_frame_of(player)
  local frame = player.gui.screen[SETTINGS_FRAME]
  if frame and frame.valid then return frame end
  return nil
end

-- control.lua asks this before honouring a close on the modal: the settings window taking
-- player.opened ASKS the modal to close, and only the window's existence tells that apart from a
-- real Esc. See gui.open_settings.
function gui.settings_open(player)
  return settings_frame_of(player) ~= nil
end

-- Put the settings window beside the modal, top edges level, rather than centred on top of it.
--
-- Nothing in the API reads an element's rendered size -- `location` and `anchor` are all there is --
-- so the modal's own centred position IS the measurement: auto_center puts a frame at
-- (resolution - width) / 2, which makes its width `resolution - 2x`. That holds in every language,
-- where a hardcoded offset would drift the moment a translation changed a label's width. Locations
-- are physical pixels, so the gap is the only part that needs the display scale.
--
-- Measured 2026-08-17, and it is why this is only ever called for a modal already on screen:
-- `location` reads 0,0 until the frame has been laid out once, which is a tick after it is built.
local SETTINGS_GAP = 12
-- How much of the window must stay on screen when the modal sits too far right for the whole of
-- it: enough to read and to grab by, since a window placed past the edge reads as a dead button.
local SETTINGS_MIN_VISIBLE = 240
-- What a modal can plausibly measure, in logical pixels before the display scale. The real one is
-- around 400 wide; this only has to be tight enough to recognise an inference that went wrong.
local MODAL_WIDTH_MIN, MODAL_WIDTH_MAX = 200, 1000

-- The last width that could be trusted, per player. A cache and not state: it is rebuilt from the
-- next centred measurement, and losing it on load costs one centred window.
local modal_width = {}

-- The modal's width, inferred from its own position -- auto_center puts a frame at
-- (resolution - width) / 2, so its width is `resolution - 2x`. That arithmetic holds for a
-- CENTRED modal, and the titlebar makes the modal draggable, so it is only ever an estimate:
-- dragged left it overshoots (the window lands far to the right, which is what this looked like
-- in game), dragged right it goes negative. Neither errors and neither is detectable directly --
-- but both leave the plausible range, so an implausible answer is thrown away and the last good
-- one stands. Nothing is measurable at all until the frame has been laid out, a tick after it is
-- built, when location still reads 0,0.
local function modal_width_at(player, at)
  local scale = player.display_scale
  local width = player.display_resolution.width - 2 * at.x
  if width >= MODAL_WIDTH_MIN * scale and width <= MODAL_WIDTH_MAX * scale then
    modal_width[player.index] = width
  end
  return modal_width[player.index]
end

local function place_beside_modal(player, window)
  local modal = frame_of(player)
  local at = modal and modal.location
  -- 0,0 is a modal that has not been laid out yet. Nothing a player does reaches it -- the button
  -- lives on a modal that is already up -- but centring is the right answer with nothing to read.
  if not at or (at.x == 0 and at.y == 0) then
    window.auto_center = true
    return
  end

  local width = modal_width_at(player, at)
  -- No trustworthy measurement yet: the modal was dragged before this window was ever opened.
  if not width then
    window.auto_center = true
    return
  end
  local x = at.x + width + math.floor(SETTINGS_GAP * player.display_scale)
  window.location = {
    x = math.min(x, player.display_resolution.width - SETTINGS_MIN_VISIBLE),
    y = at.y,
  }
end

-- The -with-quality pickers hand back a {name, quality} table and take one, but storage keeps
-- the two halves as separate plain strings. Two reasons, and both fail silently: control.lua's
-- contract is that storage holds nothing but strings, and state.arm's snapshot is a SHALLOW
-- copy -- a nested table would stay shared with the live choices instead of frozen at Confirm.
-- The pair itself is planner's, so the modal and the plan cannot disagree about its shape.
local with_quality = planner.with_quality

-- The chosen recipe as a prototype, or nil before an item is picked. The planner's questions
-- take the prototype, and the modal stores the name.
local function chosen_recipe(choices)
  return choices.recipe and prototypes.recipe[choices.recipe]
end

-- Machines are offered per recipe, so the list has to be rebuilt whenever the item changes.
-- An empty name list is not a legal filter, so an unusable recipe drops the filter entirely
-- and leaves validation to explain why nothing works.
local function name_filter(names)
  if not names or #names == 0 then return nil end
  return { { filter = "name", name = names } }
end

local SHOW_ALL_SETTING = "upcycler-planner-show-all"
local SHOW_ALL_OPTIONS_SETTING = "upcycler-planner-show-all-build-options"
gui.SHOW_ALL_SETTING = SHOW_ALL_SETTING
gui.SHOW_ALL_OPTIONS_SETTING = SHOW_ALL_OPTIONS_SETTING

-- What the settings window edits, in the order it lists them. Element and setting names are
-- written out rather than derived from each other because the two follow different conventions:
-- GUI elements carry the mod's short upl- prefix, settings the full mod name (CLAUDE.md, Naming).
local EDITED_SETTINGS = {
  { element = "upl-setting-show-all", setting = SHOW_ALL_SETTING },
  { element = "upl-setting-show-all-build-options", setting = SHOW_ALL_OPTIONS_SETTING },
}

-- Lets control.lua route a setting change here without naming any setting itself, so a third
-- setting is one line in the table above and nothing else.
function gui.is_setting(name)
  for _, entry in pairs(EDITED_SETTINGS) do
    if entry.setting == name then return true end
  end
  return false
end

-- The game's "Show all items in selection lists" option is not readable by mods, so this
-- per-player setting stands in for it.
local function show_all(player)
  return player.mod_settings[SHOW_ALL_SETTING].value
end

-- The other half of the same idea, and the reason it exists: hiding a single-option picker hides
-- the QUALITY box on it, which is what put legendary recyclers and legendary logistic chests out
-- of reach in a vanilla game. This brings every picker back.
local function show_all_options(player)
  return player.mod_settings[SHOW_ALL_OPTIONS_SETTING].value
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

-- The hideable pickers work from a NAMES list rather than straight from an elem_filters table, for
-- two reasons at once. The same list answers both questions -- what to offer, and whether there is
-- more than one of it -- and several of these sets cannot be written as a prototype TYPE filter
-- anyway: an inserter has to reach exactly one tile and never build belt stacks, a chest has to be
-- one tile in the right logistic role. Filtering by name is what keeps the stack inserter and the
-- 4x4 warehouse out even with show-all on, where a type filter would let them straight back in.
-- `narrow` is planner.buildable for entities and planner.unlocked for module items; the show-all
-- rule itself is `narrowed`'s, restated here for a list instead of a filter.
local function offered(player, names, narrow)
  if not show_all(player) then
    local unlocked = narrow(player.force, names)
    if #unlocked > 0 then return unlocked end
  end
  return names
end

-- One option is not a choice -- unless the player has asked to see everything anyway. Exemptions
-- and the trade this makes are in the file header.
local function worth_showing(player, names)
  return show_all_options(player) or #names > 1
end

local function recycler_options(player)
  return offered(player, planner.recyclers(), planner.buildable)
end

local function inserter_options(player)
  return offered(player, planner.inserters(), planner.buildable)
end

local function chest_options(player, role)
  return offered(player, planner.chests(role), planner.buildable)
end

local function pipe_options(player)
  return offered(player, planner.pipes(), planner.buildable)
end

local function quality_module_filters(player)
  return narrowed(player, planner.unlocked_quality_modules,
    name_filter(planner.quality_modules()))
end

local function pole_filters(player)
  return narrowed(player, planner.buildable_poles,
    { { filter = "type", type = "electric-pole" } })
end

-- The pair the top machine's module has to satisfy. Either half missing means there is nothing to
-- ask yet -- the modal opens before an item is picked -- so callers fall back rather than guess.
local function chosen_pair(choices)
  local machine = choices.machine and prototypes.entity[choices.machine]
  local recipe = choices.recipe and prototypes.recipe[choices.recipe]
  if machine and recipe then return machine, recipe end
  return nil
end

-- Only the modules this machine and this recipe both accept. Before either is chosen every module
-- in the game stands in, the way the machine picker falls back to every machine.
local function terminal_module_options(player, choices)
  local machine, recipe = chosen_pair(choices)
  local names = machine and planner.modules_for(machine, recipe) or planner.modules()
  return offered(player, names, planner.unlocked)
end

-- The pipe is the one picker with a condition beyond the count: it plumbs nothing unless the
-- recipe takes a fluid, so it stays out of the strip until one does. Exactly one fluid, matching
-- what the plan can actually build -- a two-fluid recipe is refused outright.
local function pipe_visible(player, choices, names)
  -- "Show all build options" overrides the fluid rule as well as the count: the player asked to
  -- see every picker, and this one still holds the pipe the loop would use the moment a fluid
  -- recipe is chosen.
  if show_all_options(player) then return true end
  return planner.needs_pipe(chosen_recipe(choices)) and worth_showing(player, names)
end

-- The top machine's module follows BOTH the machine and the recipe, either of which the player can
-- change under it, so the default is resolved here rather than only at open: a pick the pair no
-- longer accepts is replaced by what it would default to, and an untouched picker follows the
-- pair. An explicit clear -- "leave the top machine empty" -- survives all of it, the pole's rule.
local function resolve_terminal_module(player, choices)
  if choices.no_terminal_module then return end
  local machine, recipe = chosen_pair(choices)
  if not machine then return end
  if planner.module_fits(choices.terminal_module, machine, recipe) then return end
  choices.terminal_module = planner.terminal_module(player.force, machine, recipe)
end

-- The list the dropdown was BUILT from rides in its tags: research can finish while the
-- modal is open, and an index into a re-derived list would then name the wrong quality.
local function quality_options(player)
  return offered(player, planner.target_qualities(), planner.unlocked_targets)
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
  local status = frame["upl-status"]
  local confirm = frame["upl-buttons"]["upl-confirm"]

  -- validate hands back the resources it gathered so plan() does not pay for the same
  -- prototype scans twice in one refresh.
  local ok, message, gathered = planner.validate(player.force, choices)
  confirm.enabled = ok

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
    status.caption = caption
    status.style.font_color = warned and COLOR_WARNING or COLOR_PLAIN
  else
    status.caption = message or { "upl-gui.pick-a-recipe" }
    status.style.font_color = COLOR_ERROR
  end
end

-- The modal alone. Split out because a rebuild must leave the settings window standing --
-- flipping a setting in it is exactly what triggers one -- while closing the planner must not.
local function destroy_modal(player)
  local frame = frame_of(player)
  if frame then frame.destroy() end
end

function gui.close(player)
  -- The settings window belongs to the modal: closing the modal takes it along, or it is left
  -- floating with nothing behind it. Destroyed directly rather than through gui.close_settings,
  -- which would hand focus back to a modal that is about to go.
  local window = settings_frame_of(player)
  if window then window.destroy() end
  destroy_modal(player)
end

-- A tooltip for a control with no visible label: the row label it would have had, promoted to a
-- bold first line, so the tooltip names its own control the way the game's icon buttons do.
-- Every picker in the strip leans on it; the titlebar's button has a caption instead.
local function titled_tooltip(key)
  return {
    "", "[font=default-bold]", { "upl-gui." .. key }, "[/font]\n",
    { "upl-gui." .. key .. "-tooltip" },
  }
end

-- The draggable header both frames wear: title, then a stretchy filler that is itself a drag
-- handle, so the bar can be grabbed anywhere and not only on its label. Buttons stay the
-- caller's, because their order is what keeps the close X last. The filler's height matches
-- frame_action_button's fixed 24x24, or the bar grows around it.
local function add_titlebar(frame, name, caption)
  local bar = frame.add({ type = "flow", name = name, direction = "horizontal" })
  bar.drag_target = frame
  bar.add({
    type = "label", style = "frame_title", caption = caption, ignored_by_interaction = true,
  })
  local filler = bar.add({ type = "empty-widget", style = "draggable_space_header" })
  filler.style.height = 24
  filler.style.horizontally_stretchable = true
  filler.drag_target = frame
  return bar
end

-- Everything decided before a single widget exists: a default for anything never picked, and
-- the top machine's module re-resolved against the pair it depends on. Split out of gui.open
-- because it touches no element -- a reader after "where is the inserter button built" should
-- not have to scroll through it. Hands back the offered target list, which the dropdown is
-- built from and must not re-derive (see the dropdown's own comment).
local function apply_defaults(player, choices)
  -- Default anything not chosen yet, so the modal opens usable rather than empty.
  if not choices.recycler then
    choices.recycler = planner.best_recycler(player.force)
  end
  -- Highest offered target by default -- and a remembered choice that is no longer offered
  -- (legendary picked under "show all", say, then the setting turned off) snaps back too,
  -- because the dropdown could not display it.
  local offered_targets = quality_options(player)
  if not util.contains_value(offered_targets, choices.quality) then
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
  -- The inserter and the three chests default like the belt, and for the same reason: the strip
  -- should show what would actually be placed. Neither can be cleared to nothing -- there is no
  -- loop without them -- so the handlers snap an emptied picker straight back.
  if not choices.inserter then
    choices.inserter = planner.inserter(player.force, planner.filters_needed(chosen_recipe(choices)))
  end
  for _, role in ipairs(planner.CHEST_ROLES) do
    if not choices[role] then
      choices[role] = planner.chest(player.force, role)
    end
  end
  -- The pole differs from the pair above: clearing it is a real choice ("no poles"),
  -- recorded in no_poles, so only a never-touched picker gets the default.
  if not choices.pole and not choices.no_poles then
    choices.pole = planner.pole(player.force)
  end
  -- The build quality -- what the buildings and modules are placed AT, nothing to do with the
  -- target -- is deliberately NOT normalised here. Every read goes through planner.build_quality
  -- or with_quality, which turn a nil or a tier some mod has since removed into "normal", so
  -- writing it back would only be a line to remember for each new picker.
  --
  -- nil means the checkbox has never been touched; it starts checked.
  if choices.trash_unrequested == nil then
    choices.trash_unrequested = true
  end

  -- Nothing to resolve until an item is picked, so this is safe before the recipe exists.
  resolve_terminal_module(player, choices)
  return offered_targets
end

function gui.open(player)
  -- A rebuild keeps the modal exactly where it was. Flipping a setting re-enters here, and a
  -- re-centred frame would jump out from under the cursor -- taking with it the top edge the
  -- settings window is levelled against, which is also why no re-placement is needed below.
  -- It has to be read off the OLD frame: a new one reports 0,0 until it has been laid out.
  local old = frame_of(player)
  local keep = old and old.location
  if keep and keep.x == 0 and keep.y == 0 then keep = nil end
  destroy_modal(player)

  local choices = state.of(player.index).choices
  local offered_targets = apply_defaults(player, choices)

  local frame = player.gui.screen.add({ type = "frame", name = FRAME, direction = "vertical" })
  if keep then
    frame.location = keep
  else
    frame.auto_center = true
  end
  -- Makes Esc and E close the modal the way every other window in the game closes -- unless the
  -- settings window is up, which owns player.opened while it is open. Only one element can.
  if not settings_frame_of(player) then player.opened = frame end

  local titlebar = add_titlebar(frame, "upl-titlebar", { "upl-gui.title" })
  -- Named rather than drawn. The base game ships no gear, and its settings sliders read as a
  -- preset switcher; a word says what it opens. frame_button is frame_action_button's own parent,
  -- so this carries the same chrome as the close X beside it -- minus the fixed 24x24 square that
  -- leaves no room for a caption, and minus a picture inversion a text button has no picture for.
  local settings_button = titlebar.add({
    type = "button", name = "upl-settings-button", style = "frame_button",
    caption = { "upl-gui.settings" }, tooltip = { "upl-gui.settings-tooltip" },
    tags = dispatch.tags("settings"),
  })
  -- frame_button inherits button's 108px minimum width and 28px height, both sized for a dialog
  -- button at the bottom of a frame. A titlebar is 24 tall and the caption is one word.
  settings_button.style.minimal_width = 0
  settings_button.style.height = 24
  settings_button.style.padding = { 0, 8 }
  -- And it inherits button's font colours, which are black in BOTH states (vanilla's
  -- `button_default_font_color` is an empty table -- pure black -- and hovered matches). On a
  -- titlebar that reads inside out: the close X beside it is white and darkens under the cursor,
  -- so the caption does the same, which is what frame_action_button's picture inversion would
  -- have done for a glyph.
  settings_button.style.font_color = { 1, 1, 1 }
  settings_button.style.hovered_font_color = { 0, 0, 0 }
  settings_button.style.clicked_font_color = { 0, 0, 0 }
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
  -- convention is stated once here instead of at every row below. Returned and named because a
  -- hidden row has to hide its label with it -- an orphaned label is the obvious way to get this
  -- wrong, and the one a spec can catch.
  local function label(key)
    return rows.add({
      type = "label", name = "upl-" .. key .. "-label",
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

  local recycler_names = recycler_options(player)
  local recycler_label = label("recycler")
  local recycler_button = rows.add({
    type = "choose-elem-button", name = "upl-recycler", elem_type = "entity-with-quality",
    elem_filters = name_filter(recycler_names),
    tags = dispatch.tags("recycler"),
  })
  recycler_button.elem_value = with_quality(choices.recycler, choices.recycler_quality)
  -- Vanilla ships one recycler, so this row is normally not there at all; the default still
  -- stands behind it, and its quality with it.
  recycler_label.visible = worth_showing(player, recycler_names)
  recycler_button.visible = recycler_label.visible

  -- What the loop is built out of. These pickers carry no row label -- they read as a strip of
  -- icons, the way the game's own tool settings do -- so each one leans on titled_tooltip above.
  local caption = frame.add({
    type = "label", style = "caption_label", caption = { "upl-gui.build-options" },
  })
  caption.style.top_margin = 8

  local options = frame.add({
    type = "frame", name = "upl-options", style = "inside_shallow_frame_with_padding",
    direction = "vertical",
  })
  options.style.horizontally_stretchable = true

  -- Six per row, wrapping. A table rather than a flow so the row length is a rule instead of an
  -- accident: nine pickers in one line drag the modal wider than the block above it, and a modset
  -- adding a tenth would keep dragging. Six is what the vanilla set fills.
  local strip = options.add({ type = "table", name = "upl-strip", column_count = 6 })

  -- No quality on the belt: belt_speed is a plain attribute with no quality variant, unlike
  -- get_crafting_speed(quality), so a legendary belt would carry exactly as much.
  local belt_button = strip.add({
    type = "choose-elem-button", name = "upl-belt", elem_type = "entity",
    elem_filters = belt_filters(player),
    tooltip = titled_tooltip("belt"),
    tags = dispatch.tags("belt"),
  })
  belt_button.elem_value = choices.belt

  local inserter_names = inserter_options(player)
  local inserter_button = strip.add({
    type = "choose-elem-button", name = "upl-inserter", elem_type = "entity-with-quality",
    elem_filters = name_filter(inserter_names),
    tooltip = titled_tooltip("inserter"),
    tags = dispatch.tags("inserter"),
  })
  inserter_button.elem_value = with_quality(choices.inserter, choices.inserter_quality)
  inserter_button.visible = worth_showing(player, inserter_names)

  -- One button per chest role, driven by the role list so the three cannot drift apart. The role
  -- rides in the tags, which is what lets them share a single handler.
  for _, role in ipairs(planner.CHEST_ROLES) do
    local chest_names = chest_options(player, role)
    local chest_button = strip.add({
      type = "choose-elem-button", name = "upl-" .. role, elem_type = "entity-with-quality",
      elem_filters = name_filter(chest_names),
      tooltip = titled_tooltip(role),
      tags = dispatch.tags("chest", { role = role }),
    })
    chest_button.elem_value = with_quality(choices[role], choices[role .. "_quality"])
    -- Vanilla has one requester chest and one passive provider, so those two are normally absent;
    -- the plain buffer has wooden, iron and steel to choose between and stays.
    chest_button.visible = worth_showing(player, chest_names)
  end

  local module_button = strip.add({
    type = "choose-elem-button", name = "upl-quality-module", elem_type = "item-with-quality",
    elem_filters = quality_module_filters(player),
    tooltip = titled_tooltip("quality-module"),
    tags = dispatch.tags("quality-module"),
  })
  module_button.elem_value = with_quality(choices.quality_module, choices.quality_module_quality)

  local terminal_button = strip.add({
    type = "choose-elem-button", name = "upl-terminal-module", elem_type = "item-with-quality",
    elem_filters = name_filter(terminal_module_options(player, choices)),
    tooltip = titled_tooltip("terminal-module"),
    tags = dispatch.tags("terminal-module"),
  })
  terminal_button.elem_value =
    with_quality(choices.terminal_module, choices.terminal_module_quality)

  local pole_button = strip.add({
    type = "choose-elem-button", name = "upl-pole", elem_type = "entity-with-quality",
    elem_filters = pole_filters(player),
    tooltip = titled_tooltip("pole"),
    tags = dispatch.tags("pole"),
  })
  pole_button.elem_value = with_quality(choices.pole, choices.pole_quality)

  -- No quality on the pipe for the belt's reason: nothing about a pipe scales with quality.
  local pipe_names = pipe_options(player)
  local pipe_button = strip.add({
    type = "choose-elem-button", name = "upl-pipe", elem_type = "entity",
    elem_filters = name_filter(pipe_names),
    tooltip = titled_tooltip("pipe"),
    tags = dispatch.tags("pipe"),
  })
  pipe_button.elem_value = choices.pipe
  pipe_button.visible = pipe_visible(player, choices, pipe_names)

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

-- The settings window. It edits the mod's own per-player settings rather than a private copy,
-- so this window and the game's settings menu are two faces on one value; settings.lua says why.
function gui.open_settings(player)
  gui.close_settings(player)

  local frame = player.gui.screen.add({ type = "frame", name = SETTINGS_FRAME, direction = "vertical" })
  -- Deliberately NOT auto_center: it would re-centre itself over the modal on every window
  -- resize, undoing the placement below. Still draggable by its titlebar.
  place_beside_modal(player, frame)

  local titlebar = add_titlebar(frame, "upl-settings-titlebar", { "upl-gui.settings" })
  titlebar.add({
    type = "sprite-button", style = "frame_action_button", sprite = "utility/close",
    tags = dispatch.tags("settings-close"),
  })

  local content = frame.add({
    type = "frame", name = "upl-settings-content", style = "inside_shallow_frame_with_padding",
    direction = "vertical",
  })
  -- Captions come straight from the mod-setting locale categories, so this window and the game's
  -- own settings menu cannot word the same setting two different ways.
  for _, entry in pairs(EDITED_SETTINGS) do
    content.add({
      type = "checkbox", name = entry.element,
      state = player.mod_settings[entry.setting].value,
      caption = { "mod-setting-name." .. entry.setting },
      tooltip = { "mod-setting-description." .. entry.setting },
      tags = dispatch.tags("setting", { setting = entry.setting }),
    })
  end

  -- Taking player.opened is what makes Esc dismiss this window rather than the modal -- and it
  -- ASKS the modal to close, which control.lua refuses on gui.settings_open. Measured on 2.1.14:
  -- without that guard the modal really is destroyed the moment this window opens.
  player.opened = frame
end

function gui.close_settings(player)
  local frame = settings_frame_of(player)
  if not frame then return end
  frame.destroy()
  -- Destroy FIRST, then hand focus back: the engine nils player.opened when a window closes, so
  -- the modal has to be given it explicitly or Esc would do nothing at all next time. Reassigning
  -- while this frame still existed would instead ask IT to close, and come straight back here.
  --
  -- Only when nothing else has claimed it. This also runs from on_gui_closed, and opening a GUI
  -- during that event is documented to make the engine force-close whichever one it was not asked
  -- for -- so a player who clicks a chest while this window is up would have the planner snatched
  -- back over it, and then torn down by the close that follows. Measured in gui_spec.
  if player.opened ~= nil then return end
  local modal = frame_of(player)
  if modal then player.opened = modal end
end

-- Reopened rather than repainted when a setting flips: open() rereads both settings and
-- rebuilds every filter, the quality list and every picker's visibility from them. Reached from
-- the settings window and from the game's own settings menu by the same event.
function gui.on_setting_changed(player)
  if frame_of(player) then gui.open(player) end
  -- A change made in the settings menu leaves this window showing a stale tick.
  local window = settings_frame_of(player)
  if not window then return end
  for _, entry in pairs(EDITED_SETTINGS) do
    window["upl-settings-content"][entry.element].state = player.mod_settings[entry.setting].value
  end
end

dispatch.register("close", function(event)
  gui.close(game.get_player(event.player_index))
end)

dispatch.register("settings", function(event)
  local player = game.get_player(event.player_index)
  if gui.settings_open(player) then gui.close_settings(player) else gui.open_settings(player) end
end)

dispatch.register("settings-close", function(event)
  gui.close_settings(game.get_player(event.player_index))
end)

dispatch.register("setting", function(event)
  local player = game.get_player(event.player_index)
  -- Writing our own per-player setting raises on_runtime_mod_setting_changed just as the settings
  -- menu does (measured 2.1.14), so the repaint is left to that one handler instead of being done
  -- again here -- and a change made from the menu takes the identical path. Reading the element's
  -- state rather than toggling makes the second of the two events one click fires harmless; the
  -- equality check then keeps that second event from costing a whole second rebuild.
  local setting = event.element.tags.setting
  local checked = event.element.state
  if player.mod_settings[setting].value == checked then return end
  player.mod_settings[setting] = { value = checked }
end)

dispatch.register("recipe", function(event)
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  -- The button holds the item; the recipe that makes it is what everything else works from.
  local picked = planner.recipe_for_item(event.element.elem_value)

  -- A CLICK on a choose-elem-button reaches this handler too, carrying the value already in the
  -- button -- control.lua routes on_gui_click and on_gui_elem_changed to the same dispatcher. The
  -- click arrives as the engine opens its chooser, so rebuilding the modal here destroys the
  -- button and takes the chooser down with it: the picker appears to flash open and vanish. So
  -- nothing happens unless the value actually changed.
  if picked == choices.recipe then return end
  choices.recipe = picked

  -- The machine list depends on the recipe, so a machine that can no longer craft it is
  -- replaced rather than left behind to fail validation confusingly. Its QUALITY survives the
  -- swap: the player asked for legendary machines, not for a legendary assembler specifically.
  local recipe = choices.recipe and prototypes.recipe[choices.recipe]
  if recipe and not util.contains_value(planner.machines_for(recipe), choices.machine) then
    choices.machine = planner.best_machine(player.force, recipe)
  end

  -- Filter slots are needed one per ingredient, so a recipe with more of them can outgrow the
  -- chosen inserter. Re-picked for the machine's reason: a choice left behind to fail validation
  -- reads as a bug in the modal rather than as the refusal it is.
  local needed = planner.filters_needed(chosen_recipe(choices))
  local slots = planner.inserter_filter_count(choices.inserter)
  if slots and slots < needed then
    choices.inserter = planner.inserter(player.force, needed)
  end

  -- Rebuilt rather than repainted by hand. The recipe decides the machine picker's filter, the
  -- top module's options and the pipe picker's visibility, and gui.open derives all three
  -- already -- so hand-repainting them here was a second place to remember, and the pipe's
  -- visibility only ever had one. gui.open keeps the modal where it is and resolves the top
  -- module on the way through, so the rebuild is invisible.
  gui.open(player)
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
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  local value = event.element.elem_value
  local picked = value and value.name
  -- Clearing the button keeps the quality. The recipe handler already reasons that the player
  -- asked for legendary machines rather than for a legendary assembler specifically, and
  -- clearing to re-pick is the same intent; resetting to normal would quietly undo it.
  local quality = value and planner.build_quality(value.quality)
    or planner.build_quality(choices.machine_quality)

  -- Unchanged means a click rather than a pick, and rebuilding on a click destroys the chooser
  -- the click just opened -- see the recipe handler. Compared against the NORMALISED quality,
  -- because the stored one is nil until the player picks a tier and the button always reports one.
  if picked == choices.machine and quality == planner.build_quality(choices.machine_quality) then
    return
  end
  choices.machine = picked
  if value then choices.machine_quality = quality end

  -- A different machine accepts different modules, so the top machine's module has to be
  -- resolved and its picker re-offered. gui.open does both; see the recipe handler.
  gui.open(player)
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

dispatch.register("inserter", function(event)
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  local value = event.element.elem_value
  choices.inserter = value and value.name
  if value then choices.inserter_quality = planner.build_quality(value.quality) end
  -- The belt's rule: emptied means "back to the best I have researched", and shown.
  if not choices.inserter then
    choices.inserter = planner.inserter(player.force, planner.filters_needed(chosen_recipe(choices)))
    event.element.elem_value = with_quality(choices.inserter, choices.inserter_quality)
  end
  gui.refresh(player)
end)

-- All three chests, told apart by the role their button carries.
dispatch.register("chest", function(event)
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  local role = event.element.tags.role
  local value = event.element.elem_value
  choices[role] = value and value.name
  if value then
    choices[role .. "_quality"] = planner.build_quality(value.quality)
  end
  if not choices[role] then
    choices[role] = planner.chest(player.force, role)
    event.element.elem_value = with_quality(choices[role], choices[role .. "_quality"])
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

dispatch.register("terminal-module", function(event)
  local choices = state.of(event.player_index).choices
  local value = event.element.elem_value
  -- An empty option list leaves elem_filters nil, and an unfiltered item picker offers every item
  -- in the game. Only a module can go in a machine, and nothing downstream refuses one: the plan
  -- would drop it silently and build an empty machine while the strip still showed the pick. So
  -- snap back instead. Reachable only on a modset that restricts a machine's module categories.
  if value and not planner.is_module(value.name) then
    event.element.elem_value =
      with_quality(choices.terminal_module, choices.terminal_module_quality)
    return
  end
  choices.terminal_module = value and value.name
  -- The pole's rule, not the belt's: an emptied picker means "leave the top machine empty", which
  -- is a legitimate plan and the honest default whenever productivity is refused.
  choices.no_terminal_module = not value
  if value then choices.terminal_module_quality = planner.build_quality(value.quality) end
  gui.refresh(game.get_player(event.player_index))
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
