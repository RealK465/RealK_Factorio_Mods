-- The modal, in two blocks: what the loop MAKES -- item, target quality, machine, recycler --
-- and, under a "Build options" caption, what it is built OUT OF: the belt, the inserter, the
-- four chests, the quality module, the top machine's own module, the electric pole, the pipe,
-- the beacon and its module, and whether the chests trash their surplus.
--
-- A picker is only built visible when it has something to choose BETWEEN: one option is not a
-- choice, so in a vanilla game the recycler and the pipe are hidden, and a modset that adds an
-- alternative brings each of them back. Five pickers are exempt because they are the choice
-- whatever the count -- item, target quality, machine, belt, quality module -- and two more
-- because clearing them IS the second option: the pole ("no poles") and the top machine's
-- module ("leave it empty"). The pipe has one more condition of its own: it is out of the
-- strip entirely until the recipe takes a fluid. The four chests go the other way and are
-- hidden whatever the count -- see the loop that builds them -- and the beacon and its module
-- go with them: hidden whatever the count and whatever is researched, revealed by show-all,
-- and kept visible once a beacon is actually chosen (beacon_visible below).
--
-- A settings PANEL opens beside the pickers -- a second column inside this same frame -- when
-- the titlebar's settings button is pressed. It holds the two per-player settings the pickers
-- read: offer unresearched items, and show every picker whatever the count. The second is the
-- escape hatch for what hiding costs, since a hidden picker takes its QUALITY box with it;
-- ticked, every picker is shown, the pipe included even for a recipe with no fluid.
--
-- A CHILD, not a second screen frame, and that is the whole design: the API reads no element's
-- rendered size, so a separate window can only be placed beside this one by inferring the
-- modal's width from its auto-centred position -- an inference a drag silently invalidates, and
-- 2.1.14 raises on_gui_location_changed for the engine's own auto_center layout too (measured
-- in game, 2026-08-20), so "has the player moved it" cannot be answered reliably either. Making
-- the panel a sibling column hands the whole problem to the engine's layout: side by side by
-- construction, dragging moves both, and there is nothing to measure. Even Distribution reaches
-- the same conclusion from the other side -- its settings panel is anchored to the inventory
-- screen rather than positioned by coordinates.
--
-- The screen element itself is an INVISIBLE container (vanilla's invisible_frame: no graphics,
-- no padding), and each column inside it is a frame styled as a window of its own. So the pair
-- still LOOKS like the two separate windows it used to be -- titlebars level, map visible
-- between and around them -- one big grey slab was the first attempt, and it read as exactly
-- that (owner's screenshot, 2026-08-20).
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
local blueprint = require("scripts.blueprint")
local state = require("scripts.state")

local FRAME = "upl-frame"
local SETTINGS_FRAME = "upl-settings"
-- The shortcut button AND its hotkey custom-input share this prototype name (the Krastorio 2
-- pairing shape), so the button, the key and the tooltip's keybind hint all rename together.
local SHORTCUT = "upl-open"

-- Shared with control.lua, so the event wiring and the GUI cannot drift on a rename.
gui.FRAME = FRAME
gui.SETTINGS_FRAME = SETTINGS_FRAME
gui.SHORTCUT = SHORTCUT

local function frame_of(player)
  local frame = player.gui.screen[FRAME]
  if frame and frame.valid then return frame end
  return nil
end

-- The panel lives inside the container, so it is found through it -- and dies with it, which
-- is most of what used to need code.
local function settings_frame_of(player)
  local frame = frame_of(player)
  local panel = frame and frame[SETTINGS_FRAME]
  if panel and panel.valid then return panel end
  return nil
end

-- control.lua asks this on a close request for the modal: with the panel up, Esc (or the
-- engine's confirm, or another window taking over) dismisses the panel first, the way a nested
-- window would go, and only a second request closes the planner itself.
function gui.settings_open(player)
  return settings_frame_of(player) ~= nil
end

-- The engine's element chooser -- the window a choose-elem-button opens -- is invisible to
-- mods: no event announces it, no readable names it, and it never touches player.opened
-- (api.md §23). What IS visible is the click that opens one, and every LATER gui event means
-- it closed -- picking fires on_gui_elem_changed, and clicking anything else dismisses it. So
-- the last event stands in: a click on one of the modal's own pickers presumes a chooser open
-- until the next gui event for that player. Registered as the dispatcher's observer, so it
-- sees every event, other mods' elements included -- interacting anywhere closes a chooser.
--
-- The presumption lives in storage, never in a module local: every client sees the same
-- events, but a player who joins mid-presumption would not, and the two sides would then take
-- different branches on the same press of E -- a desync.
function gui.note_gui_event(event)
  local element = event.element
  if event.name == defines.events.on_gui_click and element and element.valid
    and element.type == "choose-elem-button" and element.tags[dispatch.TAG] then
    state.of(event.player_index).chooser_maybe_open = true
  else
    -- peek, not of: this runs for every player's every gui event, and a player who never
    -- opened the planner must not gain a state entry from it.
    local entry = state.peek(event.player_index)
    if entry then entry.chooser_maybe_open = nil end
  end
end

-- The -with-quality pickers hand back a {name, quality} table and take one, but storage keeps
-- the two halves as separate plain strings -- control.lua's contract is that storage holds
-- nothing but strings, and a nested table there fails silently rather than loudly. The pair
-- itself is planner's, so the modal and the plan cannot disagree about its shape.
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

-- What the settings panel edits, in the order it lists them. Element and setting names are
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

-- A names list rather than a type filter, for the chests' reason: show-all with a bare type
-- filter would offer slot-less and unplaceable beacons the planner refuses to plan with.
local function beacon_options(player)
  return offered(player, planner.beacons(), planner.buildable)
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

-- What the beacon's module picker offers: the modules the chosen beacon accepts, every module
-- before one is chosen -- the terminal module's own fallback shape, minus the recipe half a
-- beacon does not have.
local function beacon_module_options(player, choices)
  local beacon = choices.beacon and prototypes.entity[choices.beacon]
  local names = beacon and planner.modules_for(beacon) or planner.modules()
  return offered(player, names, planner.unlocked)
end

-- BOTH beacon pickers are hidden by default, whatever the count and whatever is researched
-- (owner's call, 2026-08-22, the chests' direction): a beacon is an opt-in extra, and a
-- picker apiece in the default strip reads as a decision every player has to make. Show-all
-- reveals them, and a CHOSEN beacon keeps them visible with show-all off again -- the opt-in
-- stays on display and clearable, never a hidden passenger in the plan.
local function beacon_visible(player, choices)
  if show_all_options(player) then return true end
  return choices.beacon ~= nil
end

-- The beacon's module follows the beacon under it, resolve_terminal_module's shape: a pick the
-- beacon refuses is replaced by the default, an untouched picker follows the beacon, and an
-- explicit clear survives both. The beacon itself is never defaulted -- off is its resting
-- state -- so there is nothing to resolve until one is picked.
local function resolve_beacon_module(player, choices)
  if choices.no_beacon_module then return end
  if not (choices.beacon and planner.is_beacon(choices.beacon)) then return end
  local beacon = prototypes.entity[choices.beacon]
  if planner.module_fits(choices.beacon_module, beacon) then return end
  choices.beacon_module = planner.beacon_module(player.force, beacon)
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
  local main = frame["upl-main"]
  local status = main["upl-status"]
  local confirm = main["upl-buttons"]["upl-confirm"]

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

local function destroy_modal(player)
  local frame = frame_of(player)
  if frame then frame.destroy() end
end

function gui.close(player)
  -- The settings panel is a child, so it goes with the frame for free.
  destroy_modal(player)
  -- A chooser dies with the picker button it hangs off, so the presumption goes with the frame.
  local entry = state.peek(player.index)
  if entry then entry.chooser_maybe_open = nil end
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

-- The draggable header the modal and the settings panel wear: title, then a stretchy filler
-- that is itself a drag handle, so the bar can be grabbed anywhere and not only on its label.
-- Buttons stay the caller's, because their order is what keeps the close X last. The filler's
-- height matches frame_action_button's fixed 24x24, or the bar grows around it.
--
-- drag_target must be an element in gui.screen, so the settings panel -- a child frame --
-- passes the outer modal: grabbing the panel's header drags the whole window.
local function add_titlebar(parent, name, caption, drag_target)
  drag_target = drag_target or parent
  local bar = parent.add({ type = "flow", name = name, direction = "horizontal" })
  bar.drag_target = drag_target
  bar.add({
    type = "label", style = "frame_title", caption = caption, ignored_by_interaction = true,
  })
  local filler = bar.add({ type = "empty-widget", style = "draggable_space_header" })
  filler.style.height = 24
  filler.style.horizontally_stretchable = true
  filler.drag_target = drag_target
  return bar
end

-- The settings panel: a second column inside the modal's body, holding the two per-player
-- settings. It edits the mod's own settings rather than a private copy, so this panel and the
-- game's settings menu are two faces on one value; settings.lua says why. Rebuilt from scratch
-- whenever it opens -- gui.open re-creates it after a modal rebuild too -- so a stale tick is
-- impossible rather than merely unlikely.
local function build_settings_panel(player, frame)
  local panel = frame.add({ type = "frame", name = SETTINGS_FRAME, direction = "vertical" })
  -- The gap that used to separate two windows; the invisible container's own spacing is zero,
  -- so the map shows through it.
  panel.style.left_margin = 12
  local titlebar = add_titlebar(panel, "upl-settings-titlebar", { "upl-gui.settings" }, frame)
  titlebar.add({
    type = "sprite-button", style = "frame_action_button", sprite = "utility/close",
    tags = dispatch.tags("settings-close"),
  })

  local content = panel.add({
    type = "frame", name = "upl-settings-content", style = "inside_shallow_frame_with_padding",
    direction = "vertical",
  })
  -- Captions come straight from the mod-setting locale categories, so this panel and the game's
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
  -- The inserter and the chests default like the belt, and for the same reason: the strip
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
  -- And nothing to resolve until a beacon is picked -- choices.beacon itself is deliberately
  -- never defaulted here, which is the whole of "beacons are off by default".
  resolve_beacon_module(player, choices)
  return offered_targets
end

function gui.open(player)
  -- A rebuild keeps the modal exactly where it was. Flipping a setting re-enters here, and a
  -- re-centred frame would jump out from under the cursor. It has to be read off the OLD
  -- frame: a new one reports 0,0 until it has been laid out. The settings panel is a child,
  -- so a rebuild takes it down with the frame -- remembered here and re-created at the end.
  local old = frame_of(player)
  local keep = old and old.location
  if keep and keep.x == 0 and keep.y == 0 then keep = nil end
  local had_settings = settings_frame_of(player) ~= nil
  destroy_modal(player)
  -- Before 0.4.2 the settings lived in a second gui.screen frame; a save from those builds can
  -- still carry one, and nothing else would ever remove it.
  local legacy = player.gui.screen[SETTINGS_FRAME]
  if legacy and legacy.valid then legacy.destroy() end

  local entry = state.of(player.index)
  -- A rebuild destroys every picker button, and a chooser dies with its button -- so no
  -- presumption of one survives into the new frame.
  entry.chooser_maybe_open = nil
  local choices = entry.choices
  local offered_targets = apply_defaults(player, choices)

  -- The screen element is an invisible container; what the player sees is its children, each a
  -- window-styled frame of its own -- see the file comment. Everything positional (location,
  -- auto_center, drag, player.opened) belongs to the container.
  local frame = player.gui.screen.add({
    type = "frame", name = FRAME, style = "invisible_frame", direction = "horizontal",
  })
  if keep then
    frame.location = keep
  else
    frame.auto_center = true
  end
  -- Makes Esc and E close the modal the way every other window in the game closes. The
  -- container owns player.opened whether or not the settings panel is up -- the panel is a
  -- child, not a window of its own -- and control.lua turns a close request into "panel first".
  player.opened = frame

  -- The planner window itself: the left column, wearing the frame style the whole modal used
  -- to be.
  local main = frame.add({ type = "frame", name = "upl-main", direction = "vertical" })

  local titlebar = add_titlebar(main, "upl-titlebar", { "upl-gui.title" }, frame)
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
  local content = main.add({
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
  local caption = main.add({
    type = "label", style = "caption_label", caption = { "upl-gui.build-options" },
  })
  caption.style.top_margin = 8

  local options = main.add({
    type = "frame", name = "upl-options", style = "inside_shallow_frame_with_padding",
    direction = "vertical",
  })
  options.style.horizontally_stretchable = true

  -- Six per row, wrapping. A table rather than a flow so the row length is a rule instead of an
  -- accident: ten pickers in one line drag the modal wider than the block above it, and a modset
  -- adding an eleventh would keep dragging. Six is what the vanilla set fills.
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

  -- One button per chest role, driven by the role list so they cannot drift apart. The role
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
    -- The one set of pickers hidden whatever the count (owner's call, 2026-08-18). The buffer has
    -- wooden, iron and steel to choose between, but the default -- the largest inventory the force
    -- has researched -- is the answer nearly every time, and a chest button apiece in the strip
    -- reads as that many decisions the player has to make. Show-all brings them back, quality
    -- included.
    chest_button.visible = show_all_options(player)
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

  -- The beacon: one per tier when picked, off until then -- and hidden with its module picker
  -- until show-all or an actual pick brings the pair out (beacon_visible above).
  local beacon_button = strip.add({
    type = "choose-elem-button", name = "upl-beacon", elem_type = "entity-with-quality",
    elem_filters = name_filter(beacon_options(player)),
    tooltip = titled_tooltip("beacon"),
    tags = dispatch.tags("beacon"),
  })
  beacon_button.elem_value = with_quality(choices.beacon, choices.beacon_quality)
  beacon_button.visible = beacon_visible(player, choices)

  local beacon_module_button = strip.add({
    type = "choose-elem-button", name = "upl-beacon-module", elem_type = "item-with-quality",
    elem_filters = name_filter(beacon_module_options(player, choices)),
    tooltip = titled_tooltip("beacon-module"),
    tags = dispatch.tags("beacon-module"),
  })
  beacon_module_button.elem_value =
    with_quality(choices.beacon_module, choices.beacon_module_quality)
  beacon_module_button.visible = beacon_visible(player, choices)

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
  local status = main.add({ type = "label", name = "upl-status", caption = "" })
  status.style.top_margin = 8
  status.style.single_line = false
  status.style.maximal_width = 360

  local buttons = main.add({ type = "flow", name = "upl-buttons", direction = "horizontal" })
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

  -- The rebuild took the panel down with the old frame; a player who had it open keeps it.
  if had_settings then build_settings_panel(player, frame) end

  gui.refresh(player)
end

function gui.toggle(player)
  if frame_of(player) then gui.close(player) else gui.open(player) end
end

-- What the HOTKEY runs, as opposed to the shortcut button. A custom input fires whether or not
-- the shortcut is unlocked, so the key re-checks the same per-save availability the button
-- stands behind (technology_to_unlock plus unavailable_until_unlocked on the shortcut
-- prototype) -- without this, the key would open a planner the recycling technology has not
-- delivered a recycler for yet. is_shortcut_available is the engine's own answer, so a
-- scenario that grants or revokes the shortcut by script is honoured the same way.
--
-- A refused press says why: the button greys out visibly, but a dead key reads as a broken
-- binding. The message names the gating technology off the shortcut prototype, so the two
-- cannot drift; a scripted revoke with no gating tech stays silent, since the scenario chose
-- to hide the planner. The refusal is returned so the spec can pin it -- print itself is
-- unobservable from a test.
function gui.toggle_key(player)
  if not player.is_shortcut_available(SHORTCUT) then
    local tech = prototypes.shortcut[SHORTCUT].technology_to_unlock
    if not tech then return end
    local refusal = { "upl-message.planner-not-researched", tech.localised_name }
    player.print(refusal)
    return refusal
  end
  gui.toggle(player)
end

-- Opens the settings panel in the modal's body. The panel touches player.opened not at all --
-- the modal keeps it, and control.lua turns the next close request into "panel first".
function gui.open_settings(player)
  gui.close_settings(player)
  local frame = frame_of(player)
  if not frame then return end
  build_settings_panel(player, frame)
end

function gui.close_settings(player)
  -- The pre-0.4.2 layout put the settings in its own gui.screen frame; sweep one a save from
  -- those builds may still carry, so its close X keeps working across the upgrade.
  local legacy = player.gui.screen[SETTINGS_FRAME]
  if legacy and legacy.valid then legacy.destroy() end
  local panel = settings_frame_of(player)
  if panel then panel.destroy() end
end

-- Reopened rather than repainted when a setting flips: open() rereads both settings and
-- rebuilds every filter, the quality list and every picker's visibility from them -- and
-- re-creates the settings panel with fresh ticks on the way. Reached from the panel and from
-- the game's own settings menu by the same event.
function gui.on_setting_changed(player)
  if frame_of(player) then gui.open(player) end
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

-- One click on a picker raises on_gui_click AND on_gui_elem_changed, and dispatch routes on the
-- element's tags rather than on the event type -- so every handler below runs twice for one pick,
-- the first time carrying the value the button already held. The recipe handler above guards that
-- inline because its second run rebuilt the modal under the open chooser and visibly flashed; the
-- rest were left unguarded because gui.refresh touches no elements at all and so showed nothing.
-- What it does do is design the whole loop again, which on a long modded quality chain is the
-- most expensive thing the mod does.
--
-- Snapshot before the handler resolves and compare AFTER, never before: an emptied picker snaps
-- back to the value it already held, and a guard placed ahead of that would skip the write that
-- redraws the button.
local function settled_on(choices, ...)
  local keys, before = { ... }, {}
  for _, key in pairs(keys) do before[key] = choices[key] end
  return function()
    for _, key in pairs(keys) do
      if choices[key] ~= before[key] then return false end
    end
    return true
  end
end

dispatch.register("quality", function(event)
  local choices = state.of(event.player_index).choices
  local settled = settled_on(choices, "quality")
  -- Read the list this dropdown was built from, never a re-derived one: research finishing
  -- while the modal is open would shift a re-derived list under the selected index.
  local targets = event.element.tags.targets
  choices.quality = targets[event.element.selected_index]
  if settled() then return end
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
  local settled = settled_on(choices, "recycler", "recycler_quality")
  local value = event.element.elem_value
  choices.recycler = value and value.name
  -- Kept on clear, same reasoning as the machine above.
  if value then choices.recycler_quality = planner.build_quality(value.quality) end
  if settled() then return end
  gui.refresh(game.get_player(event.player_index))
end)

dispatch.register("belt", function(event)
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  local settled = settled_on(choices, "belt")
  choices.belt = event.element.elem_value
  -- An emptied button falls straight back to the fastest researched belt, and shows it, so the
  -- strip always displays the belt that would actually be placed.
  if not choices.belt then
    choices.belt = planner.belt(player.force)
    event.element.elem_value = choices.belt
  end
  if settled() then return end
  gui.refresh(player)
end)

dispatch.register("inserter", function(event)
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  local settled = settled_on(choices, "inserter", "inserter_quality")
  local value = event.element.elem_value
  choices.inserter = value and value.name
  if value then choices.inserter_quality = planner.build_quality(value.quality) end
  -- The belt's rule: emptied means "back to the best I have researched", and shown.
  if not choices.inserter then
    choices.inserter = planner.inserter(player.force, planner.filters_needed(chosen_recipe(choices)))
    event.element.elem_value = with_quality(choices.inserter, choices.inserter_quality)
  end
  if settled() then return end
  gui.refresh(player)
end)

-- Every chest, told apart by the role their button carries.
dispatch.register("chest", function(event)
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  local role = event.element.tags.role
  local settled = settled_on(choices, role, role .. "_quality")
  local value = event.element.elem_value
  choices[role] = value and value.name
  if value then
    choices[role .. "_quality"] = planner.build_quality(value.quality)
  end
  if not choices[role] then
    choices[role] = planner.chest(player.force, role)
    event.element.elem_value = with_quality(choices[role], choices[role .. "_quality"])
  end
  if settled() then return end
  gui.refresh(player)
end)

dispatch.register("quality-module", function(event)
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  local settled = settled_on(choices, "quality_module", "quality_module_quality")
  local value = event.element.elem_value
  choices.quality_module = value and value.name
  if value then choices.quality_module_quality = planner.build_quality(value.quality) end
  -- Same rule as the belt: emptied means "back to the best I have researched", and shown.
  if not choices.quality_module then
    choices.quality_module = planner.quality_module(player.force)
    event.element.elem_value =
      with_quality(choices.quality_module, choices.quality_module_quality)
  end
  if settled() then return end
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
  local settled =
    settled_on(choices, "terminal_module", "terminal_module_quality", "no_terminal_module")
  choices.terminal_module = value and value.name
  -- The pole's rule, not the belt's: an emptied picker means "leave the top machine empty", which
  -- is a legitimate plan and the honest default whenever productivity is refused.
  choices.no_terminal_module = not value
  if value then choices.terminal_module_quality = planner.build_quality(value.quality) end
  if settled() then return end
  gui.refresh(game.get_player(event.player_index))
end)

dispatch.register("pipe", function(event)
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  local settled = settled_on(choices, "pipe")
  choices.pipe = event.element.elem_value
  -- The belt's rule: emptied means "back to the best I have researched", and shown.
  if not choices.pipe then
    choices.pipe = planner.pipe(player.force)
    event.element.elem_value = choices.pipe
  end
  if settled() then return end
  gui.refresh(player)
end)

dispatch.register("pole", function(event)
  local choices = state.of(event.player_index).choices
  local settled = settled_on(choices, "pole", "pole_quality", "no_poles")
  local value = event.element.elem_value
  choices.pole = value and value.name
  -- The one picker where an emptied button does NOT snap back: clearing means "place no
  -- poles", and the empty button showing nothing is exactly that state on display.
  choices.no_poles = not value
  if value then choices.pole_quality = planner.build_quality(value.quality) end
  if settled() then return end
  gui.refresh(game.get_player(event.player_index))
end)

dispatch.register("beacon", function(event)
  local player = game.get_player(event.player_index)
  local choices = state.of(event.player_index).choices
  local value = event.element.elem_value
  -- The terminal module's guard, same reason: with no real beacon candidate in the modset the
  -- picker is unfiltered, and a non-beacon pick would sit in the strip while chosen_beacon
  -- silently read it as off. Reachable only when every beacon is slot-less or unplaceable.
  if value and not planner.is_beacon(value.name) then
    event.element.elem_value = with_quality(choices.beacon, choices.beacon_quality)
    return
  end
  local picked = value and value.name
  -- Clearing keeps the quality, the machine handler's reasoning.
  local quality = value and planner.build_quality(value.quality)
    or planner.build_quality(choices.beacon_quality)
  -- Unchanged means a click rather than a pick, and rebuilding on a click destroys the chooser
  -- the click just opened -- see the machine handler.
  if picked == choices.beacon and quality == planner.build_quality(choices.beacon_quality) then
    return
  end
  choices.beacon = picked
  if value then choices.beacon_quality = quality end
  -- The beacon-module picker's options and visibility both follow this pick, and gui.open is
  -- what re-derives them -- the machine handler's reason for a full rebuild.
  gui.open(player)
end)

dispatch.register("beacon-module", function(event)
  local choices = state.of(event.player_index).choices
  local value = event.element.elem_value
  -- The terminal module's guard, same reason: an empty option list leaves the picker
  -- unfiltered, and a non-module pick would ride into an insert plan nothing ever fills.
  if value and not planner.is_module(value.name) then
    event.element.elem_value =
      with_quality(choices.beacon_module, choices.beacon_module_quality)
    return
  end
  local settled =
    settled_on(choices, "beacon_module", "beacon_module_quality", "no_beacon_module")
  choices.beacon_module = value and value.name
  -- The terminal module's rule: an emptied picker means "place the beacon empty".
  choices.no_beacon_module = not value
  if value then choices.beacon_module_quality = planner.build_quality(value.quality) end
  if settled() then return end
  gui.refresh(game.get_player(event.player_index))
end)

dispatch.register("trash", function(event)
  -- One click fires this from both on_gui_click and on_gui_checked_state_changed; reading the
  -- element's current state makes the second run a harmless repeat.
  state.of(event.player_index).choices.trash_unrequested = event.element.state
end)

-- Confirm does not build anything. It designs the loop and hands the player the blueprint, and
-- from there the engine owns everything: preview, rotation, flipping, snapping, undo, and the
-- build. There is no snapshot to keep, because the blueprint IS the frozen plan -- reopening
-- the modal cannot change what is already in the player's hand.
--
-- Public and guarded rather than left inside the button's handler, because the "Confirm window"
-- key reaches it too and arrives from anywhere: with no modal up, or with the settings panel
-- open beside the pickers. A press of E while the panel is up should dismiss the panel -- the
-- engine's own close, which always runs after this handler, does exactly that through
-- control.lua -- never place a blueprint.
function gui.confirm(player)
  if not frame_of(player) or settings_frame_of(player) then return end

  local choices = state.of(player.index).choices

  -- The gathered resources ride along, exactly as the status line's own call does: the plan
  -- the player was shown and the plan they are handed then come off one derivation rather than
  -- two that could drift.
  local ok, _, gathered = planner.validate(player.force, choices)
  if not ok then return end

  -- validate covers everything plan() needs, so this is the belt to its braces rather than a
  -- reachable branch -- but a tool that silently did nothing was the worst failure the old
  -- flow could have, and a cursor that silently stays empty is its successor.
  local plan = planner.plan(player.force, choices, gathered)
  if not plan then
    player.print({ "upl-message.plan-failed" })
    return
  end

  -- Left open on a refusal, so freeing a hand and pressing Place again is the whole recovery.
  -- That holds for the button; the KEY closes it anyway, because the engine's own close runs
  -- after this handler and cannot be blocked without breaking the control everywhere. The
  -- message still lands either way, and the shortcut reopens with every choice remembered.
  local given, reason = blueprint.give(player, plan)
  if not given then
    player.print(reason)
    return
  end

  gui.close(player)
end

dispatch.register("confirm", function(event)
  gui.confirm(game.get_player(event.player_index))
end)

-- What the Confirm KEY runs, as opposed to the button. The key fires on every press of E in
-- the game -- including one aimed at the element chooser floating over the modal, where
-- confirming would trade the player's pick for a blueprint and tear the chooser down with the
-- frame. So one press is swallowed while a chooser is presumed open; the engine's own confirm,
-- which always runs after this handler (api.md §22), then lands on the chooser exactly as it
-- does in a vanilla dialog.
--
-- The presumption can go stale -- a chooser dismissed with Esc or a click on nothing leaves no
-- event behind -- and that one press then costs a close instead of a confirm: the swallow
-- returns, the engine's close runs as it always has, and the shortcut reopens with every
-- choice remembered. The button never swallows, because reaching it is itself the click that
-- clears the presumption.
function gui.confirm_key(player)
  local entry = state.peek(player.index)
  if entry and entry.chooser_maybe_open then
    entry.chooser_maybe_open = nil
    return
  end
  gui.confirm(player)
end

-- The observer that keeps the chooser presumption current -- see gui.note_gui_event. Attached
-- here, at require time, so it exists again on every load exactly like the handlers above.
dispatch.observe(gui.note_gui_event)

return gui
