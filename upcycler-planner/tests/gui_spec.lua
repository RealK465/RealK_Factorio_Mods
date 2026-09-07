-- gui.lua with a real player: the modal's construction, and every dispatch handler driven the
-- honest way -- mutate the REAL widget through the API, then hand dispatch.on_gui_event a
-- hand-shaped event naming it. No clicks are simulated (the engine offers no input faking);
-- what stays untested is the click-to-event wiring itself, which control.lua registers in four
-- lines. Needs the graphics tier: headless runs have no connected player, and the file says so
-- These specs run in BOTH tiers, which was a discovery: a singleplayer save's player stays
-- flagged connected under --benchmark, so the CLI's bundled save gives even headless runs a
-- real LuaPlayer with a working cursor and gui root (measured 2.1.14 -- this overturns the
-- old "no player without a client" assumption). The graphics tier remains the real-client
-- check. Tagged "gui" -- note tags() marks the NEXT block defined, hence above describe --
-- so either tier can filter them in or out by tag.

local gui = require("scripts.gui")
local dispatch = require("scripts.dispatch")
local planner = require("scripts.planner")
local state = require("scripts.state")
local research = require("tests.support.research")

local function player()
  return game.connected_players[1]
end

local function frame()
  return player().gui.screen[gui.FRAME]
end

local function widget(path)
  -- The screen element is an invisible container; the planner window itself is its upl-main
  -- child, the settings panel's sibling, and every widget lives inside it.
  local element = frame()["upl-main"]
  for _, name in pairs(path) do
    element = element[name]
    assert(element, "widget path broke at " .. name)
  end
  return element
end

-- `name` defaults to on_gui_elem_changed, the event a completed pick raises; pass
-- on_gui_click when the test means a CLICK, because the chooser presumption in gui.lua keys
-- on exactly that difference.
local function fire(element, name)
  dispatch.on_gui_event({
    element = element, player_index = player().index,
    name = name or defines.events.on_gui_elem_changed,
  })
end

local function choices()
  return state.of(player().index).choices
end

-- The settings panel is a second COLUMN inside the modal's body, not a second screen frame, so
-- it is reached through the frame. Element names are spelled out here on purpose: they are the
-- contract a rename has to break loudly.
local SHOW_ALL_BOX = "upl-setting-show-all"
local ALL_OPTIONS_BOX = "upl-setting-show-all-build-options"

local function settings_panel()
  local f = frame()
  return f and f[gui.SETTINGS_FRAME]
end

-- The circuit wizard, reached the settings panel's way: through the frame, never the screen.
local function circuits_panel()
  local f = frame()
  return f and f[gui.CIRCUITS_FRAME]
end

-- The wizard's row list, then one row (nil when the tier has none), then a row's field --
-- one owner for the inner path, so a container rename breaks one helper instead of every
-- assertion.
local function circuit_list()
  local panel = circuits_panel()
  assert(panel and panel.valid, "the circuit wizard is not open")
  return panel["upl-circuits-content"]["upl-circuits-list"]
end

local function circuit_row(tier)
  return circuit_list()["upl-circuit-row-" .. tier]
end

local function circuit_field(tier)
  return circuit_row(tier)["upl-circuit-limit-" .. tier]
end

-- The ingredient-amounts panel, the wizard's way: through the frame, never the screen.
local function ingredients_panel()
  local f = frame()
  return f and f[gui.INGREDIENTS_FRAME]
end

local function request_field(item)
  local panel = ingredients_panel()
  assert(panel and panel.valid, "the ingredient-amounts panel is not open")
  local list = panel["upl-ingredients-content"]["upl-ingredients-list"]
  return list["upl-request-row-" .. item]["upl-request-" .. item]
end

local function settings_widget(name)
  local panel = settings_panel()
  assert(panel and panel.valid, "the settings panel is not open")
  return panel["upl-settings-content"][name]
end

-- The module-ratio wizard, reached like the other panels: through the frame, never the screen.
local function split_panel()
  local f = frame()
  return f and f[gui.SPLIT_FRAME]
end

local function split_field(tier)
  local panel = split_panel()
  assert(panel and panel.valid, "the ratio wizard is not open")
  local list = panel["upl-split-content"]["upl-split-list"]
  return list["upl-split-row-" .. tier]["upl-split-count-" .. tier]
end

-- The columns wizard, reached like the other panels: through the frame, never the screen.
local function columns_panel()
  local f = frame()
  return f and f[gui.COLUMNS_FRAME]
end

local function columns_field(tier)
  local panel = columns_panel()
  assert(panel and panel.valid, "the columns wizard is not open")
  local list = panel["upl-columns-content"]["upl-columns-list"]
  return list["upl-columns-row-" .. tier]["upl-columns-count-" .. tier]
end

-- A status-area line's caption, or nil -- each line is its own named label in the status
-- flow, so no caption ever has to be scanned for a key. The layout line's caption is the
-- summary pair, whose [2] is the machine count; the footprint rides its tooltip.
local function status_entry(name)
  local label = widget({ "upl-status" })[name]
  return label and label.caption or nil
end

local function yield_entry()
  return status_entry("upl-stat-yield")
end

local function layout_entry()
  return status_entry("upl-stat-layout")
end

-- Open the modal and pick gears through the real recipe handler, the way every later test
-- needs it: item into the real picker, then the dispatcher.
local function open_with_gears()
  gui.open(player())
  local button = widget({ "upl-content", "upl-table", "upl-recipe" })
  button.elem_value = "iron-gear-wheel"
  fire(button)
end

tags("gui")
describe("the modal", function()
  before_all(function()
    assert(#game.connected_players > 0,
      "gui specs need a connected player -- the run's save has none; use the graphics tier "
      .. "or a save carrying a player, or blacklist the 'gui' tag")
    research.full(player().force)
  end)

  after_each(function()
    gui.close(player())
    player().clear_cursor()
    state.forget(player().index)
    -- A setting left switched on would contradict the premise of every hidden-picker assertion
    -- in this file. Written only when it is actually on, so the ordinary case raises no
    -- setting-changed event that could land mid-way through the next test.
    for _, setting in pairs({ gui.SHOW_ALL_SETTING, gui.SHOW_ALL_OPTIONS_SETTING }) do
      if player().mod_settings[setting].value then
        player().mod_settings[setting] = { value = false }
      end
    end
  end)

  test("open builds the tree and defaults every build material", function()
    gui.open(player())
    assert(frame(), "no frame after open")
    -- The named children gui.refresh and the handlers navigate by; a rename breaks here
    -- before it breaks as a nil-index deep inside refresh.
    widget({ "upl-content", "upl-table", "upl-recipe" })
    widget({ "upl-content", "upl-table", "upl-quality" })
    widget({ "upl-content", "upl-table", "upl-machine" })
    widget({ "upl-content", "upl-table", "upl-recycler" })
    widget({ "upl-options", "upl-requests-strip", "upl-requests" })
    widget({ "upl-options", "upl-columns-strip", "upl-columns" })
    widget({ "upl-options", "upl-transport-strip", "upl-belt" })
    widget({ "upl-options", "upl-transport-strip", "upl-inserter" })
    widget({ "upl-options", "upl-transport-strip", "upl-pipe" })
    widget({ "upl-options", "upl-chests-strip", "upl-requester" })
    widget({ "upl-options", "upl-chests-strip", "upl-stock" })
    widget({ "upl-options", "upl-chests-strip", "upl-container" })
    widget({ "upl-options", "upl-chests-strip", "upl-provider" })
    widget({ "upl-options", "upl-chests-strip", "upl-overflow" })
    widget({ "upl-options", "upl-modules-strip", "upl-quality-module" })
    widget({ "upl-options", "upl-modules-strip", "upl-terminal-module" })
    widget({ "upl-options", "upl-beacons-strip", "upl-beacon" })
    widget({ "upl-options", "upl-beacons-strip", "upl-beacon-module" })
    widget({ "upl-options", "upl-beacons-strip", "upl-beacon-count" })
    widget({ "upl-options", "upl-power-strip", "upl-pole" })
    assert(widget({ "upl-options", "upl-buffer-stock" }).state == true,
      "buffer chests default checked")
    assert(widget({ "upl-options", "upl-trash" }).state == true, "trash defaults checked")

    -- The paths above pin which picker lives in which concept group; what is left is that each
    -- group row carries its caption. Their visibility is pinned further down with the hide rules.
    for _, key in pairs({ "transport", "chests", "modules", "beacons", "power" }) do
      widget({ "upl-options", "upl-" .. key .. "-label" })
    end

    -- One option is not a choice. In the SA modset that hides two pickers: one recycler and one
    -- pipe. Both are still BUILT, and still hold the default the plan uses -- only the widget is
    -- gone. The counts are asserted through the planner so a modset that adds an alternative
    -- fails here loudly rather than quietly showing a picker this spec claims is hidden.
    assert(#planner.recyclers() == 1, "test premise: SA ships exactly one recycler")
    assert(#planner.pipes() == 1, "test premise: one pipe")
    assert(widget({ "upl-content", "upl-table", "upl-recycler" }).visible == false,
      "the recycler picker is the only recycler there is -- it must be hidden")
    -- The row's LABEL has to go with it; an orphaned label is the obvious way to get this wrong.
    assert(widget({ "upl-content", "upl-table", "upl-recycler-label" }).visible == false,
      "the recycler label outlived its row")
    assert(widget({ "upl-options", "upl-transport-strip", "upl-pipe" }).visible == false,
      "no recipe and one pipe: the pipe picker must be hidden twice over")

    -- The chests are the exception the other way: hidden whatever the count, so the plain
    -- chest goes even though wooden, iron and steel are a real choice. The count is asserted so
    -- this keeps testing the rule rather than accidentally agreeing with the count rule. The
    -- rule lives on the GROUP -- caption and row hide together, the buttons stay built inside.
    assert(#planner.chests("container") > 1, "test premise: the plain chest has real alternatives")
    assert(widget({ "upl-options", "upl-chests-strip" }).visible == false,
      "the chests group must be hidden until show all build options is on")
    assert(widget({ "upl-options", "upl-chests-label" }).visible == false,
      "the chests caption outlived its row")

    -- And what stays: three usable inserters, four belts, and the two whose clear is itself the
    -- second option -- each in its own group, whose caption stays up with it.
    assert(#planner.inserters() > 1, "test premise: inserters have real alternatives")
    for _, entry in pairs({ { "upl-transport-strip", "upl-belt" },
                            { "upl-transport-strip", "upl-inserter" },
                            { "upl-modules-strip", "upl-quality-module" },
                            { "upl-modules-strip", "upl-terminal-module" },
                            { "upl-power-strip", "upl-pole" } }) do
      assert(widget({ "upl-options", entry[1], entry[2] }).visible == true,
        entry[2] .. " must stay visible")
    end
    for _, key in pairs({ "transport", "modules", "power" }) do
      assert(widget({ "upl-options", "upl-" .. key .. "-label" }).visible == true,
        key .. "'s caption must stay visible")
    end
    -- The beacon pair goes the chests' way, and further: hidden by default whatever the count
    -- AND whatever is researched -- this save has full research, which is the premise that
    -- makes the assertion mean something. Show-all or an actual pick brings the group out.
    assert(widget({ "upl-options", "upl-beacons-strip" }).visible == false,
      "the beacons group must be hidden by default, researched or not")
    assert(widget({ "upl-options", "upl-beacons-label" }).visible == false,
      "the beacons caption outlived its row")
    for _, name in pairs({ "upl-recipe", "upl-quality", "upl-machine" }) do
      assert(widget({ "upl-content", "upl-table", name }).visible == true,
        name .. " must stay visible whatever the count")
    end

    local c = choices()
    -- The one strip picker with no default at all: beacons are off until asked for.
    assert(c.beacon == nil, "a beacon choice appeared from nowhere")
    assert(widget({ "upl-options", "upl-beacons-strip", "upl-beacon" }).elem_value == nil,
      "the beacon picker must open empty")
    assert(c.recycler == "recycler", "recycler default " .. tostring(c.recycler))
    assert(c.quality == "legendary", "target defaults to the highest offered")
    assert(c.belt == "turbo-transport-belt", "belt default " .. tostring(c.belt))
    assert(c.quality_module == "quality-module-3", "module default " .. tostring(c.quality_module))
    assert(c.pole == "medium-electric-pole", "pole default " .. tostring(c.pole))
    assert(c.pipe == "pipe", "pipe default " .. tostring(c.pipe))
    -- Bulk beats speed in the scoring, and the belt-stacking one is not a candidate at all.
    assert(c.inserter == "bulk-inserter", "inserter default " .. tostring(c.inserter))
    assert(c.requester == "requester-chest", "requester default " .. tostring(c.requester))
    assert(c.buffer_stock == true, "buffer chests must default on")
    assert(c.stock == "buffer-chest", "stock default " .. tostring(c.stock))
    assert(c.container == "steel-chest", "plain chest default " .. tostring(c.container))
    assert(c.provider == "passive-provider-chest", "provider default " .. tostring(c.provider))
    -- Nothing to default before an item is picked: the top machine's module follows the pair.
    assert(c.terminal_module == nil, "terminal module defaulted with no recipe chosen")

    -- No item picked yet: Place must be disabled and the status must say why.
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled == false,
      "Place enabled with nothing to place")
  end)

  test("picking an item derives the recipe, the best machine, and enables Place", function()
    open_with_gears()
    local c = choices()
    assert(c.recipe == "iron-gear-wheel", "recipe " .. tostring(c.recipe))
    assert(c.machine == "assembling-machine-3", "machine " .. tostring(c.machine))
    local shown = widget({ "upl-content", "upl-table", "upl-machine" }).elem_value
    assert(shown and shown.name == "assembling-machine-3", "machine picker not updated")
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled == true,
      "Place disabled for a valid set of choices")
  end)

  test("the quality dropdown reads the list it was built from, not a re-derived one", function()
    -- The regression this guards: research changing while the modal is open would shift a
    -- freshly-derived list under the selected index. So the test must make the two lists
    -- DIFFER before firing: the dropdown was built at full research (four targets), then two
    -- quality technologies are un-researched -- a re-deriving handler would now see a
    -- two-entry list where index 4 points at nothing.
    open_with_gears()
    local dropdown = widget({ "upl-content", "upl-table", "upl-quality" })
    assert(#dropdown.tags.targets == 4, "test setup: expected four targets at full research")
    local f = player().force
    f.technologies["epic-quality"].researched = false
    f.technologies["legendary-quality"].researched = false
    dropdown.selected_index = 4
    fire(dropdown)
    research.full(f)
    assert(choices().quality == "legendary",
      "quality " .. tostring(choices().quality) .. " -- the handler re-derived the list "
      .. "instead of reading the dropdown's own tags")
  end)

  test("clearing the machine picker keeps its quality", function()
    -- The H8 fix: the player asked for rare machines, not for a rare assembler specifically;
    -- clearing to re-pick must not quietly reset the quality to normal.
    open_with_gears()
    local function machine_button()
      return widget({ "upl-content", "upl-table", "upl-machine" })
    end
    local button = machine_button()
    button.elem_value = { name = "assembling-machine-2", quality = "rare" }
    fire(button)
    assert(choices().machine == "assembling-machine-2", "machine pick lost")
    assert(choices().machine_quality == "rare", "machine quality lost on pick")

    -- Re-fetched, not reused: the machine handler rebuilds the modal rather than repainting
    -- pickers by hand, so every element reference taken before a fire() is stale after it.
    button = machine_button()
    button.elem_value = nil
    fire(button)
    assert(choices().machine == nil, "machine survived the clear")
    assert(choices().machine_quality == "rare", "quality reset by the clear")
  end)

  test("clearing the belt snaps back to the fastest researched, visibly", function()
    open_with_gears()
    local button = widget({ "upl-options", "upl-transport-strip", "upl-belt" })
    button.elem_value = nil
    fire(button)
    assert(choices().belt == "turbo-transport-belt", "belt did not snap back")
    assert(button.elem_value == "turbo-transport-belt", "snap-back not shown on the strip")
  end)

  test("clearing the pipe snaps back like the belt -- a fluid plan cannot go without one", function()
    open_with_gears()
    local button = widget({ "upl-options", "upl-transport-strip", "upl-pipe" })
    button.elem_value = nil
    fire(button)
    assert(choices().pipe == "pipe", "pipe did not snap back")
    assert(button.elem_value == "pipe", "snap-back not shown on the strip")
  end)

  test("clearing the pole means no poles -- the one picker that stays empty", function()
    open_with_gears()
    local button = widget({ "upl-options", "upl-power-strip", "upl-pole" })
    button.elem_value = nil
    fire(button)
    assert(choices().no_poles == true, "cleared pole picker did not record the choice")
    assert(choices().pole == nil, "pole name survived the clear")

    button.elem_value = { name = "medium-electric-pole", quality = "normal" }
    fire(button)
    assert(choices().no_poles == false, "re-picking a pole did not clear no_poles")
  end)

  test("picking a beacon reveals both beacon pickers, the module defaulted to efficiency", function()
    open_with_gears()
    -- Hidden by default -- the GROUP is, caption and row together -- but a hidden picker is
    -- still built and still handles its events, the chests' own precedent, which is what lets
    -- this drive the pick without show-all.
    local beacon = widget({ "upl-options", "upl-beacons-strip", "upl-beacon" })
    assert(widget({ "upl-options", "upl-beacons-strip" }).visible == false,
      "test premise: the beacons group starts hidden")
    beacon.elem_value = { name = "beacon", quality = "normal" }
    fire(beacon)
    -- The beacon handler rebuilds the modal -- the module picker's options and the group's
    -- visibility follow the pick -- so every reference above is stale from here.
    assert(choices().beacon == "beacon", "the beacon pick did not take")
    assert(widget({ "upl-options", "upl-beacons-strip" }).visible == true,
      "a chosen beacon must keep its group visible, or it cannot be cleared")
    assert(widget({ "upl-options", "upl-beacons-label" }).visible == true,
      "the beacons caption must come out with its row")
    assert(choices().beacon_module == "efficiency-module-3",
      "the module must default to the strongest researched efficiency module, got "
      .. tostring(choices().beacon_module))
    local module_button = widget({ "upl-options", "upl-beacons-strip", "upl-beacon-module" })
    local shown = module_button.elem_value
    assert(shown and shown.name == "efficiency-module-3", "the default is not on the strip")
    -- The count dropdown comes out with the pick too, offering exactly what fits: the vanilla
    -- pair leaves 13 interior rows, four 3-tall beacons.
    local dropdown = widget({ "upl-options", "upl-beacons-strip", "upl-beacon-count" })
    assert(dropdown.visible == true, "the count dropdown must show once a beacon is chosen")
    assert(#dropdown.items == 4, "count options " .. #dropdown.items .. ", expected 4")
    assert(dropdown.selected_index == 1, "the count must default to one")
    assert(choices().beacon_count == 1, "the default count must be recorded")
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled == true,
      "Place disabled by a beacon pick")
  end)

  test("the beacon count stores a plain number, read from the dropdown's own tags", function()
    open_with_gears()
    local beacon = widget({ "upl-options", "upl-beacons-strip", "upl-beacon" })
    beacon.elem_value = { name = "beacon", quality = "normal" }
    fire(beacon)

    local dropdown = widget({ "upl-options", "upl-beacons-strip", "upl-beacon-count" })
    dropdown.selected_index = 3
    fire(dropdown, defines.events.on_gui_selection_state_changed)
    assert(choices().beacon_count == 3, "the count pick did not take")
    assert(type(choices().beacon_count) == "number", "the count must store as a plain number")
    -- gui.refresh, not gui.open: a count changes no other picker's options, so the widget
    -- must survive its own pick -- the quality dropdown's behaviour.
    assert(dropdown.valid, "a count pick rebuilt the modal")
  end)

  test("a remembered count that outgrew the geometry snaps down on open", function()
    open_with_gears()
    local beacon = widget({ "upl-options", "upl-beacons-strip", "upl-beacon" })
    beacon.elem_value = { name = "beacon", quality = "normal" }
    fire(beacon)
    choices().beacon_count = 99
    gui.open(player())
    assert(choices().beacon_count == 4,
      "count " .. tostring(choices().beacon_count) .. ", expected the snap to the max of 4")
    assert(widget({ "upl-options", "upl-beacons-strip", "upl-beacon-count" }).selected_index == 4,
      "the dropdown must show the snapped count")
  end)

  test("a recycler pick rebuilds the modal, so the count list follows its height", function()
    -- The count dropdown's item list is derived at build time from the recycler's rotated
    -- height, so the recycler handler must gui.open like the machine's, never just refresh.
    -- Pinned structurally: any widget from before the pick must die with the rebuild.
    open_with_gears()
    local button = widget({ "upl-content", "upl-table", "upl-recycler" })
    local before = widget({ "upl-options", "upl-power-strip", "upl-pole" })
    button.elem_value = { name = "recycler", quality = "rare" }
    fire(button)
    assert(choices().recycler_quality == "rare", "the recycler quality did not take")
    assert(not before.valid, "a recycler pick must rebuild the modal")
  end)

  test("clearing the beacon means none, keeps its quality, and hides the module picker", function()
    open_with_gears()
    local beacon = widget({ "upl-options", "upl-beacons-strip", "upl-beacon" })
    beacon.elem_value = { name = "beacon", quality = "rare" }
    fire(beacon)
    assert(choices().beacon_quality == "rare", "the beacon quality did not take")

    -- Re-fetched: the beacon handler rebuilds the modal, so the reference above is stale.
    beacon = widget({ "upl-options", "upl-beacons-strip", "upl-beacon" })
    beacon.elem_value = nil
    fire(beacon)
    assert(choices().beacon == nil, "the beacon survived the clear")
    -- The machine's rule: the player asked for rare buildings, not a rare beacon specifically.
    assert(choices().beacon_quality == "rare", "quality reset by the clear")
    -- Clearing takes the whole group back out: with no beacon chosen and show-all off, it
    -- returns to its hidden-by-default state, caption and row together.
    assert(widget({ "upl-options", "upl-beacons-strip" }).visible == false,
      "the beacons group outlived the clear")
    assert(widget({ "upl-options", "upl-beacons-label" }).visible == false,
      "the beacons caption outlived the clear")
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled == true,
      "Place must stay enabled -- a loop without beacons is the default plan")
  end)

  test("a non-beacon in the beacon picker snaps back instead of being kept", function()
    -- Reachable only on a modset whose beacons are all slot-less or unplaceable, where the
    -- empty candidate list leaves the picker unfiltered -- the terminal module's own guard,
    -- driven here by writing past the filter, which the API allows.
    open_with_gears()
    local beacon = widget({ "upl-options", "upl-beacons-strip", "upl-beacon" })
    beacon.elem_value = { name = "steel-chest", quality = "normal" }
    assert(beacon.elem_value ~= nil,
      "test premise: the API must accept an off-filter elem_value write")
    fire(beacon)
    assert(choices().beacon == nil, "a chest was kept as the beacon choice")
    assert(beacon.elem_value == nil, "the snap-back must show the empty resting state")
  end)

  test("clearing the beacon's module plans an empty beacon; a pick survives", function()
    open_with_gears()
    local beacon = widget({ "upl-options", "upl-beacons-strip", "upl-beacon" })
    beacon.elem_value = { name = "beacon", quality = "normal" }
    fire(beacon)

    local button = widget({ "upl-options", "upl-beacons-strip", "upl-beacon-module" })
    button.elem_value = nil
    fire(button)
    assert(choices().beacon_module == nil, "clearing did not empty the beacon")
    assert(choices().no_beacon_module == true, "clearing did not record the choice")

    button.elem_value = { name = "speed-module-3", quality = "rare" }
    fire(button)
    assert(choices().beacon_module == "speed-module-3", "the pick did not take")
    assert(choices().beacon_module_quality == "rare", "the pick's quality did not take")
    assert(choices().no_beacon_module == false, "picking must clear the emptied flag")
  end)

  test("clearing the inserter snaps back to the best researched, visibly", function()
    open_with_gears()
    local button = widget({ "upl-options", "upl-transport-strip", "upl-inserter" })
    button.elem_value = { name = "fast-inserter", quality = "rare" }
    fire(button)
    assert(choices().inserter == "fast-inserter", "inserter pick lost")
    assert(choices().inserter_quality == "rare", "inserter quality lost on pick")

    button.elem_value = nil
    fire(button)
    assert(choices().inserter == "bulk-inserter", "inserter did not snap back")
    -- The quality survives the clear, exactly as the machine's does: the player asked for rare
    -- buildings, not for a rare fast-inserter specifically.
    assert(choices().inserter_quality == "rare", "quality reset by the clear")
    local shown = button.elem_value
    assert(shown and shown.name == "bulk-inserter", "snap-back not shown on the strip")
  end)

  test("a chest picker writes its own role, and clearing snaps that role back", function()
    -- The plain-chest role is the one with a real choice in vanilla (wooden, iron, steel),
    -- which is what makes it the honest one to drive through the shared handler. Its group is
    -- hidden by default, but a hidden picker is still built and handles its events -- the point.
    open_with_gears()
    local button = widget({ "upl-options", "upl-chests-strip", "upl-container" })
    button.elem_value = { name = "iron-chest", quality = "uncommon" }
    fire(button)
    assert(choices().container == "iron-chest", "plain-chest pick lost")
    assert(choices().container_quality == "uncommon", "plain-chest quality lost on pick")
    -- One handler serves all three buttons, so the role in the tags is load-bearing: a write
    -- that reached a sibling role would silently swap the wrong chest.
    assert(choices().requester == "requester-chest", "the requester role was overwritten")
    assert(choices().provider == "passive-provider-chest", "the provider role was overwritten")

    button.elem_value = nil
    fire(button)
    assert(choices().container == "steel-chest", "plain chest did not snap back to the largest")
    local shown = button.elem_value
    assert(shown and shown.name == "steel-chest", "snap-back not shown on the strip")
  end)

  test("a recipe the chosen inserter cannot filter re-picks it, like the machine", function()
    -- Filter slots are needed one per ingredient: fusion reactor equipment takes six and every
    -- vanilla inserter carries five, so the modal must not leave behind a pick that cannot
    -- serve the new recipe.
    open_with_gears()
    local inserter = widget({ "upl-options", "upl-transport-strip", "upl-inserter" })
    inserter.elem_value = { name = "fast-inserter", quality = "normal" }
    fire(inserter)
    assert(choices().inserter == "fast-inserter", "test setup: the pick did not take")

    assert(planner.recipe_for_item("fusion-reactor-equipment"),
      "test premise: fusion reactor equipment should be upcyclable")
    local recipe_button = widget({ "upl-content", "upl-table", "upl-recipe" })
    recipe_button.elem_value = "fusion-reactor-equipment"
    fire(recipe_button)
    -- Nothing in the game has six filter slots, so the honest re-pick is no inserter at all --
    -- and Place has to go down rather than arm a tool that would do nothing.
    assert(choices().inserter == nil, "the outgrown pick survived the recipe change")
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled == false,
      "Place stayed enabled for a recipe no inserter can filter")
  end)

  test("the top machine's module follows the recipe, and clearing means empty", function()
    open_with_gears()
    -- Gears allow productivity, so the pair defaults to the strongest researched one.
    assert(choices().terminal_module == "productivity-module-3",
      "terminal default " .. tostring(choices().terminal_module))
    local function module_button()
      return widget({ "upl-options", "upl-modules-strip", "upl-terminal-module" })
    end
    local shown = module_button().elem_value
    assert(shown and shown.name == "productivity-module-3", "the default is not on the strip")

    -- A recipe that refuses productivity must not leave the pick behind: nothing fits, so the
    -- top machine is planned empty and the picker says so.
    local recipe_button = widget({ "upl-content", "upl-table", "upl-recipe" })
    recipe_button.elem_value = "wooden-chest"
    fire(recipe_button)
    assert(choices().terminal_module == nil,
      "a recipe refusing productivity kept " .. tostring(choices().terminal_module))

    -- And a pick of its own survives, at its own quality. Re-fetched, because the recipe
    -- handler rebuilds the modal rather than repainting its pickers by hand.
    local button = module_button()
    button.elem_value = { name = "speed-module-3", quality = "rare" }
    fire(button)
    assert(choices().terminal_module == "speed-module-3", "the pick did not take")
    assert(choices().terminal_module_quality == "rare", "the pick's quality did not take")
    assert(choices().no_terminal_module == false, "picking must clear the emptied flag")

    button.elem_value = nil
    fire(button)
    assert(choices().terminal_module == nil, "clearing did not empty the top machine")
    assert(choices().no_terminal_module == true, "clearing did not record the choice")
  end)

  test("swapping the machine keeps a module the new machine also accepts", function()
    -- The machine is the other half of the pair, and re-resolving must not become re-picking:
    -- the drop direction is covered by the recipe test above, so what this pins is that a pick
    -- the new machine accepts is LEFT ALONE. Every vanilla machine that crafts gears allows
    -- every effect, which is why the premise is asserted rather than assumed.
    open_with_gears()
    assert(choices().terminal_module == "productivity-module-3", "test setup: default missing")
    local swapped = prototypes.entity["assembling-machine-2"]
    local gears = prototypes.recipe["iron-gear-wheel"]
    assert(planner.module_fits("productivity-module-3", swapped, gears),
      "test premise: assembling machine 2 should accept productivity on gears")

    local machine = widget({ "upl-content", "upl-table", "upl-machine" })
    machine.elem_value = { name = "assembling-machine-2", quality = "normal" }
    fire(machine)
    assert(choices().terminal_module == "productivity-module-3",
      "a machine that also allows productivity must keep the pick")
  end)

  test("the pipe picker follows the recipe's fluids", function()
    -- Two conditions, and vanilla can only show one of them: the SA modset has a single pipe, so
    -- the count keeps the picker hidden even for a fluid recipe. The fluid half is what this
    -- pins -- that picking a fluid recipe repaints the pipe's visibility at all rather than
    -- leaving it stale -- and it needs a second pipe prototype to be seen going the other way.
    open_with_gears()
    local pipe = widget({ "upl-options", "upl-transport-strip", "upl-pipe" })
    assert(pipe.visible == false, "gears take no fluid: the pipe picker must be hidden")

    local recipe_button = widget({ "upl-content", "upl-table", "upl-recipe" })
    recipe_button.elem_value = "battery"
    fire(recipe_button)
    assert(choices().recipe == "battery", "test setup: the battery recipe did not take")
    -- The plan still builds pipes -- the picker being hidden never means the default is not used.
    assert(choices().pipe == "pipe", "the pipe default must stand behind the hidden picker")
    -- Re-fetched: the recipe handler rebuilds the modal, so the reference above is stale.
    assert(widget({ "upl-options", "upl-transport-strip", "upl-pipe" }).visible == (#planner.pipes() > 1),
      "with one pipe in the game the picker stays hidden; with more it must appear")
  end)

  test("the settings button opens the panel beside the pickers, without closing the modal", function()
    gui.open(player())
    local modal = frame()
    -- A captioned button rather than a glyph, so the titlebar says what it opens. Pinned because
    -- the difference is invisible to every other assertion in this file.
    local button = widget({ "upl-titlebar", "upl-settings-button" })
    assert(button.type == "button", "the settings button must be a text button, not a sprite one")
    assert(button.caption and button.caption[1] == "upl-gui.settings",
      "the settings button lost its caption")
    fire(button)

    local panel = settings_panel()
    assert(panel and panel.valid, "the settings button opened nothing")
    -- A COLUMN in the modal, not a window of its own: a second screen frame can only be placed
    -- beside this one by inference, and that is the bug this layout exists to end.
    assert(player().gui.screen[gui.SETTINGS_FRAME] == nil,
      "the settings must not be a separate screen window")
    -- Both boxes read the SETTINGS, not a private copy -- that is the whole storage decision.
    assert(settings_widget(SHOW_ALL_BOX).state == false, "the show-all box does not read its setting")
    assert(settings_widget(ALL_OPTIONS_BOX).state == false,
      "the build-options box does not read its setting")
    -- The modal keeps the focus: the panel is a child, so Esc still lands on the frame and
    -- control.lua turns it into "panel first".
    assert(player().opened == modal, "the modal must keep player.opened under the panel")

    after_ticks(2, function()
      assert(modal.valid, "the modal was torn down by the settings panel opening")
      gui.close_settings(player())
      assert(not panel.valid, "close_settings left the panel standing")
      assert(player().opened == modal, "closing the panel must not cost the modal the focus")
    end)
  end)

  test("Esc with the settings panel open dismisses the panel, not the modal", function()
    gui.open(player())
    gui.open_settings(player())
    -- Writing nil is exactly what Esc does -- the engine asks whatever holds the focus to close --
    -- so this drives the real on_gui_closed path in control.lua rather than the button's handler.
    player().opened = nil
    after_ticks(2, function()
      assert(settings_panel() == nil, "the panel survived Esc")
      assert(frame() and frame().valid, "Esc with the panel up closed the modal too")
      assert(player().opened == frame(),
        "the modal did not get the focus back, so Esc would do nothing next time")
    end)
  end)

  test("another GUI taking focus does not drag the planner down with the panel", function()
    gui.open(player())
    gui.open_settings(player())
    -- Clicking a chest while the panel is up asks the MODAL to close -- the panel is a child,
    -- so the frame is what owns player.opened -- and that lands in the same on_gui_closed
    -- handler as Esc. Reclaiming the focus THERE is what the API warns about: the engine
    -- force-closes whichever GUI it was not asked for, and the modal went with it.
    local surface = player().surface
    local at = surface.find_non_colliding_position("iron-chest", { x = 12, y = 12 }, 32, 1)
    local chest = surface.create_entity({
      name = "iron-chest", position = at, force = player().force,
    })
    assert(chest, "test setup: no chest to open")

    player().opened = chest
    after_ticks(2, function()
      assert(frame() and frame().valid, "opening a chest tore the planner down")
      assert(settings_panel() == nil, "the close request should have dismissed the panel")
      assert(player().opened == chest, "the planner snatched the focus back from the chest")
      player().opened = nil
      chest.destroy()
    end)
  end)

  test("a close the engine never announces takes the modal with it", function()
    -- Restore whatever we find rather than assuming a character: by the time this file runs in
    -- the full suite the player has none, and only the character controller takes an entity.
    local was = player().controller_type
    local character = player().character
    gui.open(player())
    assert(frame() and frame().valid, "test setup: the modal did not open")

    -- Becoming a spectator closes a player's GUIs WITHOUT raising on_gui_closed -- the docs say
    -- so and api.md S28 measures it -- which used to leave the modal standing with its focus
    -- gone, so Esc stopped closing it. Driven by controller rather than by dying because
    -- character.die() hangs a headless benchmark run outright.
    player().set_controller({ type = defines.controllers.spectator })
    after_ticks(3, function()
      assert(not frame(), "the modal outlived the focus the engine silently took off it")
      if character and character.valid then
        player().set_controller({ type = defines.controllers.character, character = character })
      else
        player().set_controller({ type = was })
      end
    end)
  end)

  test("a death and respawn leaves no modal Esc cannot close", function()
    gui.open(player())
    assert(frame() and frame().valid, "test setup: the modal did not open")

    -- The respawn state is where a death puts the player, reached here without a death screen
    -- for the benchmark to sit waiting on.
    player().ticks_to_respawn = 120
    after_ticks(3, function()
      assert(not frame(), "the modal survived the death that unfocused it")
      player().ticks_to_respawn = nil
      after_ticks(3, function()
        assert(not frame(), "a modal came back with the player")
        assert(player().character and player().character.valid,
          "test teardown: the player did not respawn with a character")
      end)
    end)
  end)

  test("the sweep leaves a modal that still holds the focus alone", function()
    -- The guard earns its keep on the common path: a controller change is a player flipping to
    -- remote view far more often than it is a death, and every one of them reaches the handler.
    gui.close_if_unfocused(player())
    assert(not frame(), "the sweep conjured a modal out of nothing")

    gui.open(player())
    gui.close_if_unfocused(player())
    assert(frame() and frame().valid, "the sweep closed a modal that was perfectly focused")
    assert(player().opened == frame(), "the sweep disturbed the focus it was checking")
  end)

  test("the sweep leaves a modal alone while another GUI holds the focus", function()
    -- The state the test above cannot see: the planner standing with the focus deliberately
    -- somewhere else, which is what clicking a chest with the settings panel up leaves behind
    -- (pinned by "another GUI taking focus" earlier in this file). Sweeping on "not the modal"
    -- rather than on "nothing at all" would close the planner out from under that chest.
    gui.open(player())
    -- The panel has to be up for the chest to get the focus at all: without one, the close
    -- request the chest raises is honoured and takes the modal with it, and the engine then
    -- force-closes the chest for having been opened during on_gui_closed (api.md S17).
    gui.open_settings(player())
    local surface = player().surface
    -- Beside the player, not at a fixed spot: by this point in the file the respawn test above
    -- has given them a character again, and a character has a reach the earlier chest test --
    -- which runs while the suite's player has none -- never had to satisfy.
    local at = surface.find_non_colliding_position("iron-chest", player().position, 32, 1)
    local chest = surface.create_entity({ name = "iron-chest", position = at, force = player().force })
    assert(chest, "test setup: no chest to open")

    player().opened = chest
    after_ticks(2, function()
      assert(player().opened == chest,
        "test setup: the chest never took the focus, opened is " .. tostring(player().opened))
      assert(frame() and frame().valid, "test setup: the planner should have survived the chest")

      gui.close_if_unfocused(player())
      assert(frame() and frame().valid, "the sweep closed a planner whose focus was lent out")
      assert(player().opened == chest, "the sweep stole the focus back from the chest")

      player().opened = nil
      chest.destroy()
    end)
  end)

  test("clicking a picker without changing it leaves the modal standing", function()
    -- on_gui_click reaches the same handler as on_gui_elem_changed, carrying the value already in
    -- the button -- and it arrives as the engine opens its chooser. A handler that rebuilds the
    -- modal there destroys the button and takes the chooser with it, which in game looked like
    -- the picker flashing open and vanishing. Only the two pickers that rebuild can hit this.
    open_with_gears()
    local modal = frame()

    local recipe_button = widget({ "upl-content", "upl-table", "upl-recipe" })
    fire(recipe_button, defines.events.on_gui_click)
    assert(modal.valid, "clicking the item picker tore the modal down")
    assert(recipe_button.valid, "clicking the item picker destroyed the button under the chooser")
    assert(choices().recipe == "iron-gear-wheel", "the click changed the choice")

    local machine_button = widget({ "upl-content", "upl-table", "upl-machine" })
    local machine = choices().machine
    fire(machine_button, defines.events.on_gui_click)
    assert(machine_button.valid, "clicking the machine picker destroyed the button")
    assert(choices().machine == machine, "the click changed the machine")
  end)

  test("a click that changes nothing does not design the loop again", function()
    -- The same double event reaches the nine pickers that only REFRESH, where it cost a second
    -- validate + plan rather than a flash -- invisible, because the status area repaints in
    -- place. That is also what makes it the observable here: refresh always rebuilds the
    -- status flow's children, so a child label SURVIVING proves the second run was skipped.
    -- On a long modded quality chain the skipped run is the most expensive thing the mod does.
    open_with_gears()
    local button = widget({ "upl-options", "upl-transport-strip", "upl-belt" })
    local layout = widget({ "upl-status" })["upl-stat-layout"]

    layout.caption = "sentinel"
    fire(button, defines.events.on_gui_click)
    assert(layout.valid and layout.caption == "sentinel",
      "an unchanged click re-planned the loop")

    -- And a genuine pick still repaints, so the guard cannot be swallowing real changes.
    button.elem_value = "transport-belt"
    fire(button)
    assert(choices().belt == "transport-belt", "the pick did not land")
    assert(not layout.valid, "a genuine pick left the status stale")
  end)

  test("the settings panel can never separate from the planner window", function()
    -- The panel used to be a second gui.screen frame placed beside this one by inferring the
    -- modal's width from its auto-centred position -- wrong after any drag, and 2.1.14 raises
    -- on_gui_location_changed for its own auto_center layout too, so even "was it moved" had no
    -- reliable answer. A sibling column inside one screen element has no position of its own to
    -- get wrong, wherever the window goes.
    gui.open(player())
    gui.open_settings(player())
    local panel = settings_panel()
    assert(panel and panel.valid, "the panel did not open")
    assert(panel.parent == frame(),
      "the panel must be a column inside the planner's own screen element")
    assert(player().gui.screen[gui.SETTINGS_FRAME] == nil,
      "the settings must not be a separate screen window")

    frame().location = { x = 40, y = 60 }
    assert(settings_panel().valid, "moving the window lost the panel")

    -- A rebuild (a setting flip does one) keeps an open panel open, and a closed one closed.
    gui.open(player())
    assert(settings_panel() ~= nil, "a rebuild dropped the settings panel")
    gui.close_settings(player())
    gui.open(player())
    assert(settings_panel() == nil, "a rebuild resurrected a closed settings panel")
  end)

  test("a leftover settings window from a pre-0.4.2 save is swept", function()
    -- Those builds kept the settings in its own gui.screen frame; a save can carry one across
    -- the upgrade, and nothing else would ever remove it.
    local orphan = player().gui.screen.add({
      type = "frame", name = gui.SETTINGS_FRAME, direction = "vertical",
    })
    assert(orphan.valid, "test setup: no orphan window")
    gui.open(player())
    assert(not orphan.valid, "opening the planner must sweep the orphan window")

    local again = player().gui.screen.add({
      type = "frame", name = gui.SETTINGS_FRAME, direction = "vertical",
    })
    gui.close_settings(player())
    assert(not again.valid, "close_settings must sweep the orphan window too")
  end)

  test("closing the modal takes the settings panel with it", function()
    gui.open(player())
    gui.open_settings(player())
    gui.close(player())
    assert(frame() == nil, "the planner survived close")
    assert(not player().gui.screen[gui.SETTINGS_FRAME],
      "something named after the settings panel outlived the planner")
  end)

  test("show all build options reveals every hidden picker, pipe included", function()
    gui.open(player())
    assert(widget({ "upl-content", "upl-table", "upl-recycler" }).visible == false,
      "test premise: the recycler picker starts hidden in this modset")

    gui.open_settings(player())
    local box = settings_widget(ALL_OPTIONS_BOX)
    box.state = true
    fire(box)

    -- The handler writes the setting and stops; the repaint belongs to the one
    -- on_runtime_mod_setting_changed handler, which serves the settings menu identically. So the
    -- modal is REBUILT here, and every widget reference taken above is stale from now on.
    after_ticks(2, function()
      assert(frame() and frame().valid, "the modal did not come back after the setting flipped")
      for _, path in pairs({ { "upl-content", "upl-table", "upl-recycler" },
                             { "upl-content", "upl-table", "upl-recycler-label" },
                             { "upl-options", "upl-chests-strip" },
                             { "upl-options", "upl-chests-label" } }) do
        assert(widget(path).visible == true, path[#path] .. " stayed hidden")
      end
      -- The pipe carries a second condition of its own, and the setting overrides that too: no
      -- recipe is chosen here, so nothing except the setting can be showing it.
      assert(widget({ "upl-options", "upl-transport-strip", "upl-pipe" }).visible == true,
        "the pipe must be shown even for no recipe at all")
      -- No beacon is picked, so only the setting can be showing the beacons group.
      assert(widget({ "upl-options", "upl-beacons-strip" }).visible == true,
        "the beacons group must be shown under show-all")
      assert(widget({ "upl-options", "upl-beacons-label" }).visible == true,
        "the beacons caption must be shown with its row")
      -- With no beacon chosen the count list holds the lone "1"; show-all overrides the
      -- one-option-is-no-choice rule here as it does everywhere, so it shows anyway.
      local count = widget({ "upl-options", "upl-beacons-strip", "upl-beacon-count" })
      assert(count.visible == true, "show-all must reveal the count dropdown too")
      assert(#count.items == 1, "with no beacon chosen the count list must hold only the 1")
      -- And it reverses: the same path, from the settings menu's side of the setting.
      player().mod_settings[gui.SHOW_ALL_OPTIONS_SETTING] = { value = false }
      after_ticks(2, function()
        assert(widget({ "upl-options", "upl-transport-strip", "upl-pipe" }).visible == false,
          "unticking the setting must hide the pipe again")
        assert(widget({ "upl-options", "upl-chests-strip" }).visible == false,
          "unticking the setting must hide the chests group again")
        assert(settings_widget(ALL_OPTIONS_BOX).state == false,
          "a change from outside the window left its tick stale")
      end)
    end)
  end)

  test("the trash checkbox reads current element state", function()
    open_with_gears()
    local box = widget({ "upl-options", "upl-trash" })
    box.state = false
    fire(box)
    assert(choices().trash_unrequested == false, "unticking did not reach the choices")
    -- The double-fire rule: one click arrives as two events; the second run must be a
    -- harmless repeat because the handler reads the element, not the event.
    fire(box)
    assert(choices().trash_unrequested == false, "the double-fire changed the answer")
  end)

  test("the buffer-chests checkbox swaps the stock picker's kind, refilling its best", function()
    open_with_gears()
    -- A deliberate quality on the stock pick, to prove the toggle keeps it: the player asked
    -- for uncommon chests, not for an uncommon buffer chest specifically.
    local button = widget({ "upl-options", "upl-chests-strip", "upl-stock" })
    button.elem_value = { name = "buffer-chest", quality = "uncommon" }
    fire(button)
    assert(choices().stock_quality == "uncommon", "test setup: the quality did not take")

    local box = widget({ "upl-options", "upl-buffer-stock" })
    box.state = false
    fire(box)
    -- The toggle rebuilds the modal (the picker's offered list changes kind), so every widget
    -- is re-fetched; the pick of the old kind is forgotten and the new kind's best fills in.
    assert(choices().buffer_stock == false, "unticking did not reach the choices")
    assert(choices().stock == "requester-chest",
      "stock did not refill as a requester: " .. tostring(choices().stock))
    assert(choices().stock_quality == "uncommon", "the quality did not survive the toggle")
    local shown = widget({ "upl-options", "upl-chests-strip", "upl-stock" }).elem_value
    assert(shown and shown.name == "requester-chest", "the refill is not shown on the strip")
    assert(widget({ "upl-options", "upl-buffer-stock" }).state == false,
      "the rebuilt checkbox lost its tick")

    -- The double-fire pair: the settled guard must keep the second event from rebuilding
    -- the modal again, and the answer must hold.
    fire(widget({ "upl-options", "upl-buffer-stock" }))
    assert(choices().buffer_stock == false, "the double-fire changed the answer")

    box = widget({ "upl-options", "upl-buffer-stock" })
    box.state = true
    fire(box)
    assert(choices().stock == "buffer-chest",
      "re-ticking did not refill the buffer kind: " .. tostring(choices().stock))
  end)

  test("Confirm hands over a filled blueprint and closes", function()
    open_with_gears()
    fire(widget({ "upl-buttons", "upl-confirm" }))

    local stack = player().cursor_stack
    assert(stack and stack.valid_for_read and stack.is_blueprint,
      "the cursor does not hold a blueprint")
    assert(stack.is_blueprint_setup(), "the blueprint in the cursor is empty")
    assert(stack.get_blueprint_entity_count() > 0, "the blueprint carries no entities")
    -- Temporary, so Q throws it away exactly as the old placement tool did and nothing lands
    -- in the player's inventory unless they deliberately drag it there.
    assert(player().cursor_stack_temporary, "the blueprint would survive a cleared cursor")
    -- The icon says what the loop is for; the engine's own default would be the belt.
    local icons = stack.preview_icons
    assert(icons and icons[1] and icons[1].signal.name == "iron-gear-wheel",
      "the blueprint does not wear its product as an icon")
    assert(frame() == nil, "the modal stayed open after Confirm")
  end)

  -- The Confirm KEY, which control.lua points at the same gui.confirm the button reaches. What
  -- these cannot cover is the keypress itself: the engine offers no input faking, so whether the
  -- linked custom-input really fires on E is a human check in a live game. What they do cover is
  -- everything that happens once it fires -- including the two ways it can arrive with nothing to
  -- confirm, which the button never can.
  test("the Confirm key hands over the blueprint, exactly as the button does", function()
    open_with_gears()
    gui.confirm_key(player())

    local stack = player().cursor_stack
    assert(stack and stack.valid_for_read and stack.is_blueprint,
      "the key did not put a blueprint in the cursor")
    assert(stack.is_blueprint_setup(), "the key handed over an empty blueprint")
    assert(frame() == nil, "the modal stayed open after the Confirm key")
  end)

  test("the Confirm key does nothing with no modal open", function()
    -- E is pressed constantly in an ordinary game, so this is the common case rather than an
    -- edge one: the handler runs on every press and must be inert unless the planner is up.
    assert(frame() == nil, "the modal was already open, so this proves nothing")
    gui.confirm_key(player())
    local stack = player().cursor_stack
    assert(not (stack and stack.valid_for_read),
      "the key put something in the cursor with no modal open")
  end)

  test("the Confirm key is refused while the settings panel is open", function()
    open_with_gears()
    gui.open_settings(player())
    gui.confirm_key(player())

    local stack = player().cursor_stack
    assert(not (stack and stack.valid_for_read),
      "the key placed a blueprint while the settings panel was open")
    assert(frame() and frame().valid, "the key closed the planner under the panel")
  end)

  -- The key's panel guard is the key's alone: a click on Place beside an open panel is an
  -- unambiguous ask, and a button that silently did nothing there read as broken (owner's
  -- report, 2026-08-26).
  test("the Place button places with the settings panel open", function()
    open_with_gears()
    gui.open_settings(player())
    fire(widget({ "upl-buttons", "upl-confirm" }), defines.events.on_gui_click)

    local stack = player().cursor_stack
    assert(stack and stack.valid_for_read and stack.is_blueprint,
      "the button did not place a blueprint while the settings panel was open")
    assert(frame() == nil, "placing did not close the planner, panel and all")
  end)

  test("the circuits group: the checkbox arms Limits, and the wizard lists a field per tier", function()
    open_with_gears()
    local box = widget({ "upl-options", "upl-circuits-strip", "upl-circuit-enabled" })
    local button = widget({ "upl-options", "upl-circuits-strip", "upl-circuit-limits" })
    assert(box.state == false, "circuit limits must start off")
    assert(button.enabled == false, "Limits must be dead until the checkbox is ticked")

    box.state = true
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().circuit_enabled == true, "the tick did not reach the choices")
    -- Re-fetched: the handler refreshes, never rebuilds, so the reference itself survives --
    -- which is also worth asserting, a rebuild here would eat the click's second event.
    assert(button.valid and button.enabled == true, "the tick did not arm Limits in place")

    fire(button, defines.events.on_gui_click)
    local panel = circuits_panel()
    assert(panel and panel.valid, "Limits opened nothing")
    assert(panel.parent == frame(), "the wizard must be a column inside the planner's element")
    assert(player().gui.screen[gui.CIRCUITS_FRAME] == nil,
      "the wizard must not be a separate screen window")
    -- Full research defaults the target to the top of the chain, so every tier is a row.
    -- The lower tiers open as Min 0 -- keep nothing back -- and the target as Max one
    -- stack of gears; the row's first label says which rule the field sets.
    for _, tier in pairs({ "normal", "uncommon", "rare", "epic" }) do
      assert(circuit_field(tier).text == "0",
        tier .. " field opened as " .. circuit_field(tier).text)
      assert(circuit_row(tier).children[1].caption[1] == "upl-gui.circuit-min",
        tier .. " row is not labelled Min")
    end
    assert(circuit_field("legendary").text == "100",
      "the target field opened as " .. circuit_field("legendary").text)
    assert(circuit_row("legendary").children[1].caption[1] == "upl-gui.circuit-max",
      "the target row is not labelled Max")
  end)

  test("Start paused: dead until a cap arms it, stored on the tick, dead again under a zero cap", function()
    open_with_gears()
    local box = widget({ "upl-options", "upl-circuits-strip", "upl-circuit-enabled" })
    local paused = widget({ "upl-options", "upl-circuits-strip", "upl-circuit-paused" })
    assert(paused.state == false and paused.enabled == false,
      "Start paused must start off and dead")

    -- Ticking the limits on arms it at once: the backfilled cap is one stack of gears.
    box.state = true
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(paused.valid and paused.enabled == true, "Start paused did not arm with the cap")

    paused.state = true
    fire(paused, defines.events.on_gui_checked_state_changed)
    assert(choices().circuit_paused == true, "the tick did not reach the choices")
    assert(paused.valid, "the tick rebuilt the modal under the cursor")

    -- No cap, nothing the switch could pause through: zeroing the Max greys it again.
    gui.open_circuits(player())
    local field = circuit_field("legendary")
    field.text = "0"
    fire(field, defines.events.on_gui_text_changed)
    paused = widget({ "upl-options", "upl-circuits-strip", "upl-circuit-paused" })
    assert(paused.enabled == false, "Start paused stayed armed under a zero cap")
    assert(choices().circuit_paused == true, "greying the box must not forget the choice")
  end)

  test("typing commits without a rebuild; Enter snaps the text to what holds", function()
    open_with_gears()
    choices().circuit_enabled = true
    gui.open_circuits(player())

    local field = circuit_field("uncommon")
    field.text = "25"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices().circuit_min_uncommon == 25, "the keystroke did not commit")
    assert(field.valid, "the keystroke rebuilt the modal under the cursor")

    -- An emptied field mid-edit keeps the last value; Enter then restores the display.
    field.text = ""
    fire(field, defines.events.on_gui_text_changed)
    assert(choices().circuit_min_uncommon == 25, "an emptied field clobbered the value")
    fire(field, defines.events.on_gui_confirmed)
    assert(field.text == "25", "Enter left the field showing " .. field.text)
  end)

  test("unchecking the checkbox takes the wizard with it", function()
    open_with_gears()
    choices().circuit_enabled = true
    gui.open_circuits(player())
    local box = widget({ "upl-options", "upl-circuits-strip", "upl-circuit-enabled" })
    box.state = false
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().circuit_enabled == false, "the untick did not reach the choices")
    assert(circuits_panel() == nil, "limits on a loop that will not be wired are noise")
  end)

  test("the wizard and the settings panel swap; Esc dismisses the wizard first", function()
    open_with_gears()
    choices().circuit_enabled = true
    gui.open_circuits(player())
    gui.open_settings(player())
    assert(circuits_panel() == nil, "the settings panel did not close the wizard")
    gui.open_circuits(player())
    assert(settings_panel() == nil, "the wizard did not close the settings panel")

    -- Esc asks the container to close; control.lua turns that into "panel first", the
    -- settings panel's own path.
    player().opened = nil
    after_ticks(2, function()
      assert(circuits_panel() == nil, "the wizard survived Esc")
      assert(frame() and frame().valid, "Esc with the wizard up closed the modal too")
      assert(player().opened == frame(), "the modal did not take the focus back")
    end)
  end)

  test("the Confirm key is refused while the wizard is open", function()
    -- The guard is also what stands between a focused threshold field and E placing the
    -- blueprint mid-edit, whatever the engine does with the keypress.
    open_with_gears()
    choices().circuit_enabled = true
    gui.open_circuits(player())
    gui.confirm_key(player())

    local stack = player().cursor_stack
    assert(not (stack and stack.valid_for_read),
      "the key placed a blueprint while the wizard was open")
    assert(frame() and frame().valid, "the key closed the planner under the wizard")
  end)

  -- The settings panel's button test, on the wizard: the fields commit every keystroke, so
  -- the click places exactly the thresholds on display.
  test("the Place button places with the wizard open", function()
    open_with_gears()
    choices().circuit_enabled = true
    gui.open_circuits(player())
    fire(widget({ "upl-buttons", "upl-confirm" }), defines.events.on_gui_click)

    local stack = player().cursor_stack
    assert(stack and stack.valid_for_read and stack.is_blueprint,
      "the button did not place a blueprint while the wizard was open")
    assert(frame() == nil, "placing did not close the planner, wizard and all")
  end)

  test("a target change with the wizard open reshapes its rows", function()
    open_with_gears()
    choices().circuit_enabled = true
    gui.open_circuits(player())
    assert(circuit_field("legendary"), "test premise: the default target lists every tier")

    local dropdown = widget({ "upl-content", "upl-table", "upl-quality" })
    dropdown.selected_index = 1 -- uncommon, the first offered target
    fire(dropdown, defines.events.on_gui_selection_state_changed)

    assert(choices().quality == "uncommon", "the target change did not land")
    assert(circuits_panel() and circuits_panel().valid, "the rebuild dropped the wizard")
    assert(circuit_field("uncommon"), "the wizard lost the tier the new target keeps")
    assert(circuit_row("rare") == nil,
      "the wizard still lists a tier the new target dropped")
  end)

  test("the Edit button waits for an item, then opens the ingredient-amounts panel", function()
    gui.open(player())
    local button = widget({ "upl-options", "upl-requests-strip", "upl-requests" })
    assert(button.enabled == false, "Edit must be dead until an item is picked")

    -- Picking gears rebuilds the modal, so the button is re-fetched rather than reused.
    open_with_gears()
    button = widget({ "upl-options", "upl-requests-strip", "upl-requests" })
    assert(button.enabled == true, "picking an item did not arm Edit")

    fire(button, defines.events.on_gui_click)
    local panel = ingredients_panel()
    assert(panel and panel.valid, "Edit opened nothing")
    assert(panel.parent == frame(), "the panel must be a column inside the planner's element")
    assert(player().gui.screen[gui.INGREDIENTS_FRAME] == nil,
      "the panel must not be a separate screen window")
    -- Gears: 2 plates per 0.5 s craft is 240 a minute, capped at the plate stack of 100 --
    -- the formula's own value on display, because nothing is stored until the player edits.
    assert(request_field("iron-plate").text == "100",
      "the field opened as " .. request_field("iron-plate").text)
    assert(choices()["request_iron-plate"] == nil,
      "opening the panel stored an override the player never made")
  end)

  test("typing commits an override; Enter on an emptied field returns to automatic", function()
    open_with_gears()
    gui.open_ingredients(player())

    local field = request_field("iron-plate")
    -- The focus CLICK reaches the handler too, carrying the displayed default -- it must not
    -- become a stored override, or every field the player merely touched freezes.
    fire(field, defines.events.on_gui_click)
    assert(choices()["request_iron-plate"] == nil, "a click stored the default as an override")
    -- Enter on the untouched field is the same non-edit, one event later.
    fire(field, defines.events.on_gui_confirmed)
    assert(choices()["request_iron-plate"] == nil, "Enter stored the default as an override")
    field.text = "250"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices()["request_iron-plate"] == 250, "the keystroke did not commit")
    assert(field.valid, "the keystroke rebuilt the modal under the cursor")

    -- An emptied field mid-edit keeps the last value; Enter on it deletes the override and
    -- snaps the display back to the automatic amount.
    field.text = ""
    fire(field, defines.events.on_gui_text_changed)
    assert(choices()["request_iron-plate"] == 250, "an emptied field clobbered the override")
    fire(field, defines.events.on_gui_confirmed)
    assert(choices()["request_iron-plate"] == nil, "Enter on empty kept the override")
    assert(field.text == "100", "the display did not snap to the automatic amount")

    -- Zero cannot be typed into a request: the floor is one.
    field.text = "0"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices()["request_iron-plate"] == 1, "a zero committed below the floor")
  end)

  test("picking a different item resets the overrides and refills an open panel", function()
    open_with_gears()
    gui.open_ingredients(player())
    choices()["request_iron-plate"] = 250

    local button = widget({ "upl-content", "upl-table", "upl-recipe" })
    button.elem_value = "transport-belt"
    fire(button)

    assert(choices().recipe == "transport-belt", "premise: the pick landed")
    assert(choices()["request_iron-plate"] == nil,
      "an override sized for gears survived onto belts")
    -- The rebuild re-created the open panel over the NEW recipe's ingredients, at their own
    -- automatic amounts: belts eat gears, which gears did not.
    assert(ingredients_panel() and ingredients_panel().valid, "the rebuild dropped the panel")
    assert(request_field("iron-gear-wheel").text == "100",
      "the new recipe's field opened as " .. request_field("iron-gear-wheel").text)
  end)

  test("the ingredient panel shares the slot with the other four", function()
    open_with_gears()
    gui.open_ingredients(player())
    gui.open_settings(player())
    assert(ingredients_panel() == nil, "the settings panel did not close the ingredient panel")
    gui.open_ingredients(player())
    assert(settings_panel() == nil, "the ingredient panel did not close the settings panel")
    choices().circuit_enabled = true
    gui.open_circuits(player())
    assert(ingredients_panel() == nil, "the wizard did not close the ingredient panel")
    gui.open_ingredients(player())
    assert(circuits_panel() == nil, "the ingredient panel did not close the wizard")
    gui.open_split(player())
    assert(ingredients_panel() == nil, "the ratio wizard did not close the ingredient panel")
    gui.open_ingredients(player())
    assert(split_panel() == nil, "the ingredient panel did not close the ratio wizard")
    gui.open_columns(player())
    assert(ingredients_panel() == nil, "the columns wizard did not close the ingredient panel")
    gui.open_ingredients(player())
    assert(columns_panel() == nil, "the ingredient panel did not close the columns wizard")
  end)

  -- The picker lives inside the wizard since the UI revision, so every look at it opens the
  -- panel first; one owner for the inner path, the circuit helpers' rule.
  local function split_module_picker()
    local panel = split_panel()
    assert(panel and panel.valid, "the ratio wizard is not open")
    return panel["upl-split-content"]["upl-split-module-row"]["upl-productivity-module"]
  end

  test("the productivity picker defaults with the pair, snaps back, and empties honestly", function()
    open_with_gears()
    assert(choices().productivity_module == "productivity-module-3",
      "gears should default the split's module to prod-3, got "
      .. tostring(choices().productivity_module))
    gui.open_split(player())
    local button = split_module_picker()
    assert(button.elem_value and button.elem_value.name == "productivity-module-3",
      "the picker does not show the default")

    -- The belt's rule: emptied snaps back to the default, visibly -- through the rebuild
    -- the escalation runs with the wizard open.
    button.elem_value = nil
    fire(button)
    assert(choices().productivity_module == "productivity-module-3",
      "clearing did not snap back")
    assert(split_module_picker().elem_value.name == "productivity-module-3",
      "the snap-back is not shown")

    -- A recipe that refuses productivity leaves the picker honestly empty beside the
    -- sentence saying why -- the forced-all-quality case -- and Place stays enabled.
    local recipe_button = widget({ "upl-content", "upl-table", "upl-recipe" })
    recipe_button.elem_value = "wooden-chest"
    fire(recipe_button)
    assert(choices().productivity_module == nil,
      "a refusing recipe left " .. tostring(choices().productivity_module) .. " in choices")
    assert(split_module_picker().elem_value == nil,
      "the picker still shows a module the plan cannot use")
    assert(split_panel()["upl-split-content"]["upl-split-list"] == nil,
      "a productivity-refusing recipe still lists ratio rows")
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled,
      "a productivity-refusing recipe disabled Place")
  end)

  test("the mix row appears only where productivity can mix", function()
    gui.open(player())
    assert(widget({ "upl-options", "upl-mix-strip" }).visible == false,
      "no recipe picked, yet the mix row shows")
    open_with_gears()
    assert(widget({ "upl-options", "upl-mix-strip" }).visible == true,
      "gears take productivity, yet the mix row hides")

    local recipe_button = widget({ "upl-content", "upl-table", "upl-recipe" })
    recipe_button.elem_value = "wooden-chest"
    fire(recipe_button)
    assert(widget({ "upl-options", "upl-mix-strip" }).visible == false,
      "a productivity-refusing recipe kept the mix row on display")

    -- Show-all reveals it, the pipe's rule: asking to see everything means everything.
    player().mod_settings["upcycler-planner-show-all-build-options"] = { value = true }
    assert(widget({ "upl-options", "upl-mix-strip" }).visible == true,
      "show-all did not reveal the mix row")
    player().mod_settings["upcycler-planner-show-all-build-options"] = { value = false }
  end)

  test("the mix checkbox starts on, disarms Ratios and closes the wizard when unticked", function()
    open_with_gears()
    local box = widget({ "upl-options", "upl-mix-strip", "upl-split-enabled" })
    local button = widget({ "upl-options", "upl-mix-strip", "upl-split" })
    assert(box.state == true, "the mix must start on")
    assert(button.enabled == true, "an item is picked, Ratios must be armed")
    gui.open_split(player())

    box.state = false
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().split_enabled == false, "the untick did not reach the choices")
    assert(split_panel() == nil, "unticking left the wizard standing")
    -- Re-fetched: the handler refreshes, never rebuilds, so the reference itself survives.
    assert(button.valid and button.enabled == false, "the untick did not disarm Ratios in place")

    box.state = true
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().split_enabled == true, "the re-tick did not land")
    assert(button.enabled == true, "the re-tick did not re-arm Ratios")
  end)

  test("the Ratios button waits for an item, then opens rows at the computed optimum", function()
    gui.open(player())
    local button = widget({ "upl-options", "upl-mix-strip", "upl-split" })
    assert(button.enabled == false, "Ratios must be dead until an item is picked")

    open_with_gears()
    button = widget({ "upl-options", "upl-mix-strip", "upl-split" })
    assert(button.enabled == true, "picking an item did not arm Ratios")

    fire(button, defines.events.on_gui_click)
    local panel = split_panel()
    assert(panel and panel.valid, "Ratios opened nothing")
    assert(panel.parent == frame(), "the wizard must be a column inside the planner's element")
    assert(player().gui.screen[gui.SPLIT_FRAME] == nil,
      "the wizard must not be a separate screen window")
    -- Gears at normal modules: the computed optimum is all-quality, shown as 0 productivity
    -- slots per lower tier -- and NOTHING stored, the ingredient panel's rule.
    for _, tier in pairs({ "normal", "uncommon" }) do
      assert(split_field(tier).text == "0",
        tier .. " opened as " .. split_field(tier).text)
      assert(choices()["split_prod_" .. tier] == nil,
        "opening the wizard stored an override for " .. tier)
    end
    -- The target tier has no row -- its machine is the terminal picker's business -- and at
    -- full research the untouched target defaults to the top of the chain.
    assert(choices().quality == "legendary", "test premise: the default target moved")
    local list = panel["upl-split-content"]["upl-split-list"]
    assert(list["upl-split-row-epic"], "the tier below the target lost its row")
    assert(list["upl-split-row-legendary"] == nil, "the target tier grew a ratio row")
  end)

  test("typing a ratio moves the yield line without waiting for Enter", function()
    -- The field commits every keystroke, and clicking to the next field never fires a
    -- confirm -- so if only Enter repainted, a player typing through the rows would watch
    -- the stats sit still while the plan underneath already changed (reported 2026-08-28).
    open_with_gears()
    gui.open_split(player())
    local before = yield_entry()
    assert(before, "a valid plan must carry the yield line")

    local field = split_field("normal")
    field.text = "4"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices().split_prod_normal == 4, "the keystroke did not commit")
    assert(field.valid, "the keystroke repaint tore down the wizard's own field")
    local after = yield_entry()
    assert(after, "the yield line vanished mid-type")
    assert(after[2] ~= before[2],
      "the override is live but the yield line still shows " .. tostring(after[2]))
  end)

  test("a ratio override commits, clamps, resets on empty Enter, and moves the yield line", function()
    open_with_gears()
    gui.open_split(player())
    local before = yield_entry()
    assert(before, "a valid plan must carry the yield line")

    local field = split_field("normal")
    field.text = "2"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices().split_prod_normal == 2, "the keystroke did not commit")
    assert(field.valid, "the keystroke rebuilt the modal under the cursor")

    -- Enter refreshes -- the one wizard whose number moves the status line -- and the field
    -- must survive its own commit.
    fire(field, defines.events.on_gui_confirmed)
    assert(field.valid, "Enter rebuilt the wizard under the cursor")
    local after = yield_entry()
    assert(after, "the yield line vanished on an override")
    assert(after[2] ~= before[2],
      "forcing half the slots to productivity left the yield at " .. tostring(after[2]))

    -- Over the slot count clamps; empty plus Enter deletes the override and shows the
    -- optimum again.
    field = split_field("normal")
    field.text = "9"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices().split_prod_normal == 4, "an over-slots count did not clamp")
    field.text = ""
    fire(field, defines.events.on_gui_text_changed)
    assert(choices().split_prod_normal == 4, "an emptied field clobbered the override")
    fire(field, defines.events.on_gui_confirmed)
    assert(choices().split_prod_normal == nil, "Enter on empty kept the override")
    assert(split_field("normal").text == "0", "the display did not return to the optimum")
  end)

  test("the wizard follows the target, survives a module change, and says when nothing mixes", function()
    open_with_gears()
    gui.open_split(player())

    -- A target change reshapes the rows, the circuit wizard's rule.
    local dropdown = widget({ "upl-content", "upl-table", "upl-quality" })
    dropdown.selected_index = 1 -- uncommon
    fire(dropdown, defines.events.on_gui_selection_state_changed)
    assert(split_panel() and split_panel().valid, "the rebuild dropped the wizard")
    assert(split_field("normal"), "the wizard lost the tier the new target keeps")
    assert(split_panel()["upl-split-content"]["upl-split-list"]["upl-split-row-uncommon"] == nil,
      "the wizard lists the new target as a lower tier")

    -- A quality-module change rebuilds an open wizard to fresh defaults rather than leaving
    -- stale ones on display.
    local module_button = widget({ "upl-options", "upl-modules-strip", "upl-quality-module" })
    module_button.elem_value = { name = "quality-module-2", quality = "normal" }
    fire(module_button)
    assert(split_panel() and split_panel().valid, "the module change dropped the wizard")

    -- A recipe that refuses productivity replaces the rows with the honest sentence.
    local recipe_button = widget({ "upl-content", "upl-table", "upl-recipe" })
    recipe_button.elem_value = "wooden-chest"
    fire(recipe_button)
    local panel = split_panel()
    assert(panel and panel.valid, "the recipe change dropped the wizard")
    assert(panel["upl-split-content"]["upl-split-list"] == nil,
      "a productivity-refusing recipe still lists ratio rows")
    local sentence = panel["upl-split-content"]["upl-hint"]
    assert(sentence and sentence.caption[1] == "upl-gui.split-no-productivity",
      "the refusing sentence is missing")
  end)

  test("clearing the item leaves an open panel standing on the pick-a-recipe hint", function()
    open_with_gears()
    gui.open_ingredients(player())
    local button = widget({ "upl-content", "upl-table", "upl-recipe" })
    button.elem_value = nil
    fire(button)
    assert(choices().recipe == nil, "premise: the clear landed")
    local panel = ingredients_panel()
    assert(panel and panel.valid, "the rebuild dropped the panel")
    assert(panel["upl-ingredients-content"]["upl-ingredients-list"] == nil,
      "a recipe-less panel still lists ingredient rows")
    local sentence = panel["upl-ingredients-content"]["upl-hint"]
    assert(sentence and sentence.caption[1] == "upl-gui.pick-a-recipe",
      "the pick-a-recipe hint is missing")
  end)

  test("the Columns button waits for an item, then opens rows defaulting to one", function()
    gui.open(player())
    local button = widget({ "upl-options", "upl-columns-strip", "upl-columns" })
    assert(button.enabled == false, "Columns must be dead until an item is picked")

    open_with_gears()
    button = widget({ "upl-options", "upl-columns-strip", "upl-columns" })
    assert(button.enabled == true, "picking an item did not arm Columns")

    fire(button, defines.events.on_gui_click)
    local panel = columns_panel()
    assert(panel and panel.valid, "Columns opened nothing")
    assert(panel.parent == frame(), "the wizard must be a column inside the planner's element")
    -- At full research the untouched target is the top of the chain, so every lower tier
    -- has a row at the default one, nothing stored -- the ratio wizard's own rule.
    assert(choices().quality == "legendary", "test premise: the default target moved")
    for _, tier in pairs({ "normal", "uncommon", "rare", "epic" }) do
      assert(columns_field(tier).text == "1", tier .. " opened as " .. columns_field(tier).text)
      assert(choices()["column_count_" .. tier] == nil,
        "opening the wizard stored a count for " .. tier)
    end
    local list = panel["upl-columns-content"]["upl-columns-list"]
    assert(list["upl-columns-row-legendary"] == nil, "the target tier grew a columns row")
  end)

  test("typing a count moves the counts line without waiting for Enter", function()
    open_with_gears()
    gui.open_columns(player())
    local before = layout_entry()
    assert(before, "a valid plan must carry the counts line")

    local field = columns_field("normal")
    field.text = "3"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices().column_count_normal == 3, "the keystroke did not commit")
    assert(field.valid, "the keystroke repaint tore down the wizard's own field")
    local after = layout_entry()
    assert(after, "the counts line vanished mid-type")
    assert(after[2] ~= before[2],
      "three normal columns but the machine count still shows " .. tostring(after[2]))
  end)

  test("a count clamps at the ceiling and an empty Enter returns to one", function()
    open_with_gears()
    gui.open_columns(player())
    local field = columns_field("normal")
    field.text = "9999"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices().column_count_normal == planner.MAX_COLUMNS_PER_TIER,
      "an over-ceiling count did not clamp: " .. tostring(choices().column_count_normal))
    field.text = ""
    fire(field, defines.events.on_gui_text_changed)
    assert(choices().column_count_normal == planner.MAX_COLUMNS_PER_TIER,
      "an emptied field clobbered the count mid-type")
    fire(field, defines.events.on_gui_confirmed)
    assert(choices().column_count_normal == nil, "Enter on empty kept the count")
    assert(columns_field("normal").text == "1", "the display did not return to one")
  end)

  test("the wizard shows nothing below the rows and opening it stores nothing", function()
    -- The balanced-counts hint that used to close the panel went at the owner's ask
    -- (2026-08-29); its one-click Apply had already gone after a click on a big layout
    -- asked the engine for a plan it could not survive (2026-08-28). What remains must
    -- store nothing the player did not type.
    open_with_gears()
    gui.open_columns(player())
    local panel = columns_panel()
    local content = panel["upl-columns-content"]
    assert(content["upl-columns-balanced-line"] == nil, "the balanced line is back")
    assert(content["upl-columns-sep"] == nil, "the balanced separator is back")
    assert(content["upl-columns-use-balanced"] == nil, "the one-click balanced write is back")
    local tiers = planner.tiers_up_to(choices().quality)
    for index = 1, #tiers - 1 do
      assert(choices()["column_count_" .. tiers[index]] == nil,
        "opening the wizard stored a count for " .. tiers[index])
    end
  end)

  test("the columns wizard follows the target and survives rate changes", function()
    open_with_gears()
    gui.open_columns(player())

    -- A target change reshapes the rows, the circuit wizard's rule.
    local dropdown = widget({ "upl-content", "upl-table", "upl-quality" })
    dropdown.selected_index = 1 -- uncommon
    fire(dropdown, defines.events.on_gui_selection_state_changed)
    assert(columns_panel() and columns_panel().valid, "the rebuild dropped the wizard")
    assert(columns_field("normal"), "the wizard lost the tier the new target keeps")
    assert(columns_panel()["upl-columns-content"]["upl-columns-list"]["upl-columns-row-uncommon"] == nil,
      "the wizard lists the new target as a lower tier")

    -- Rate changes -- modules, the mix checkbox, beacons -- move nothing this wizard shows
    -- since the balanced line went, so the open panel SURVIVES all of them: the same panel
    -- reference staying valid is what proves the cheap refresh ran, not a rebuild.
    local before_panel = columns_panel()
    local module_button = widget({ "upl-options", "upl-modules-strip", "upl-quality-module" })
    module_button.elem_value = { name = "quality-module-2", quality = "normal" }
    fire(module_button)
    assert(before_panel.valid, "a module change rebuilt the columns wizard for nothing")

    local box = widget({ "upl-options", "upl-mix-strip", "upl-split-enabled" })
    box.state = false
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(before_panel.valid, "the mix untick rebuilt the columns wizard for nothing")

    local beacon_module = widget({ "upl-options", "upl-beacons-strip", "upl-beacon-module" })
    beacon_module.elem_value = { name = "efficiency-module", quality = "normal" }
    fire(beacon_module)
    assert(before_panel.valid, "a beacon change rebuilt the columns wizard for nothing")
    assert(columns_panel() and columns_panel().valid, "the beacon change dropped the wizard")
  end)
end)

tags("gui")
describe("the confirm key and the element chooser", function()
  -- The engine's chooser -- the window a picker button opens -- is invisible to mods
  -- (api.md §23), so gui.lua presumes one open from the click that opens it until the next
  -- gui event, and the confirm KEY swallows one press while the presumption holds: the
  -- engine's own confirm, which runs after the handler, is what selects in the chooser.
  -- These drive that machinery the file's usual way; what no tier can cover is the real E
  -- over a real chooser, which stays a human check like the keypress itself.
  before_all(function()
    assert(#game.connected_players > 0,
      "gui specs need a connected player -- the run's save has none; use the graphics tier "
      .. "or a save carrying a player, or blacklist the 'gui' tag")
    research.full(player().force)
  end)

  after_each(function()
    gui.close(player())
    player().clear_cursor()
    state.forget(player().index)
  end)

  local function cursor_holds_blueprint()
    local stack = player().cursor_stack
    return (stack and stack.valid_for_read and stack.is_blueprint) or false
  end

  test("a click on a picker makes the next confirm key the chooser's, not Place", function()
    open_with_gears()
    fire(widget({ "upl-content", "upl-table", "upl-machine" }), defines.events.on_gui_click)
    gui.confirm_key(player())
    assert(not cursor_holds_blueprint(), "the key placed a blueprint over an open chooser")
    assert(frame() and frame().valid, "the swallowed key tore the modal down")
    -- One press deep: the engine's own confirm has handled the chooser by the time a second
    -- press can arrive, so that one belongs to the modal again.
    gui.confirm_key(player())
    assert(cursor_holds_blueprint(), "the second press did not confirm the modal")
  end)

  test("picking a value hands the key straight back to Place", function()
    open_with_gears()
    local machine = widget({ "upl-content", "upl-table", "upl-machine" })
    fire(machine, defines.events.on_gui_click)
    machine.elem_value = { name = "assembling-machine-2", quality = "normal" }
    fire(machine)
    gui.confirm_key(player())
    assert(cursor_holds_blueprint(), "a completed pick left the key swallowed")
  end)

  test("any later interaction hands the key back too", function()
    -- The trash checkbox does not rebuild the modal, so this proves the observer's clear
    -- alone -- the pick test above also passes through gui.open's.
    open_with_gears()
    fire(widget({ "upl-content", "upl-table", "upl-machine" }), defines.events.on_gui_click)
    fire(widget({ "upl-options", "upl-trash" }), defines.events.on_gui_click)
    gui.confirm_key(player())
    assert(cursor_holds_blueprint(), "an unrelated interaction left the key swallowed")
  end)

  test("the Confirm button never swallows", function()
    -- Reaching the button is itself a click, and a click anywhere closes a chooser -- so the
    -- button's own event clears the presumption before its handler runs.
    open_with_gears()
    fire(widget({ "upl-content", "upl-table", "upl-machine" }), defines.events.on_gui_click)
    fire(widget({ "upl-buttons", "upl-confirm" }), defines.events.on_gui_click)
    assert(cursor_holds_blueprint(), "the button was swallowed -- only the key may be")
  end)

  test("another mod's element picker never arms the presumption", function()
    open_with_gears()
    -- A bare picker with no upl tag stands in for another mod's: same type, not ours.
    local foreign = player().gui.screen.add({ type = "choose-elem-button", elem_type = "item" })
    fire(foreign, defines.events.on_gui_click)
    gui.confirm_key(player())
    local held = cursor_holds_blueprint()
    foreign.destroy()
    assert(held, "a foreign picker armed the presumption and swallowed our key")
  end)

  test("closing drops the presumption with the frame", function()
    open_with_gears()
    fire(widget({ "upl-content", "upl-table", "upl-machine" }), defines.events.on_gui_click)
    gui.close(player())
    gui.open(player())
    gui.confirm_key(player())
    assert(cursor_holds_blueprint(), "a dead frame's chooser swallowed the reopened modal's key")
  end)
end)

tags("gui")
describe("the open hotkey", function()
  -- The custom input that opens the planner from the keyboard. The keypress itself is the
  -- untestable wiring every key here shares; what these pin is the prototype pairing and
  -- gui.toggle_key's gate -- driven through set_shortcut_available, the same engine state the
  -- recycling unlock manages, so the gate is proven without depending on how the engine maps
  -- technologies onto availability.
  before_all(function()
    assert(#game.connected_players > 0,
      "gui specs need a connected player -- the run's save has none; use the graphics tier "
      .. "or a save carrying a player, or blacklist the 'gui' tag")
    research.full(player().force)
  end)

  after_each(function()
    gui.close(player())
    state.forget(player().index)
    -- Recycling stays researched in this save, so available is the correct standing state.
    player().set_shortcut_available(gui.SHORTCUT, true)
  end)

  test("the hotkey shares the shortcut's name, its binding, and the button's tooltip", function()
    local input = prototypes.custom_input[gui.SHORTCUT]
    assert(input, "no custom input shares the shortcut's prototype name")
    assert(input.key_sequence == "CONTROL + U",
      "default binding is " .. tostring(input.key_sequence))
    assert(prototypes.shortcut[gui.SHORTCUT].associated_control_input == gui.SHORTCUT,
      "the shortcut button does not advertise the keybind in its tooltip")
  end)

  test("the key toggles the planner: open, then closed", function()
    assert(player().is_shortcut_available(gui.SHORTCUT),
      "test premise: full research must leave the shortcut available")
    gui.toggle_key(player())
    assert(frame() and frame().valid, "the key did not open the planner")
    gui.toggle_key(player())
    assert(frame() == nil, "the key did not close the planner again")
  end)

  test("a locked shortcut keeps the key from opening, and the refusal names the tech", function()
    player().set_shortcut_available(gui.SHORTCUT, false)
    -- The print is unobservable from here; the returned refusal is the seam that pins it.
    local refusal = gui.toggle_key(player())
    assert(frame() == nil, "the key opened the planner while the shortcut was locked")
    assert(type(refusal) == "table" and refusal[1] == "upl-message.planner-not-researched",
      "a locked key must say why, got " .. serpent.line(refusal))
    local tech = prototypes.shortcut[gui.SHORTCUT].technology_to_unlock
    assert(tech, "test premise: the shortcut prototype declares a gating technology")
    assert(refusal[2] ~= nil, "the refusal does not name the gating technology")
  end)

  test("an unlocked key returns no refusal", function()
    assert(gui.toggle_key(player()) == nil, "an ordinary toggle must not report a refusal")
  end)
end)

tags("gui")
describe("the status area", function()
  -- The one thing planner_spec cannot see. It pins that validate RETURNS a warning; nothing
  -- pinned that the modal SHOWS one, and gui.refresh records that warnings were once dropped
  -- here silently -- ok was read and the message thrown away, so every build-through warning
  -- was unreachable with no error anywhere. These are that regression's guard, plus the
  -- area's structure: one label per line, so a message's colour cannot bleed into the stats.

  local function status()
    return widget({ "upl-status" })
  end

  -- A line's position in the flow shifts with however many other lines landed, so a line is
  -- found by scanning captions for its key, never by index. Two caption shapes: a stat line
  -- nests its keys under a leading "", a message line nests the message after its icon.
  local function line_with(key)
    for _, child in pairs(status().children) do
      local caption = child.caption
      if type(caption) == "table" then
        if caption[1] == key then return child end
        for _, part in pairs(caption) do
          if type(part) == "table" and part[1] == key then return child end
        end
      end
    end
    return nil
  end

  local function open_with(item)
    gui.open(player())
    local button = widget({ "upl-content", "upl-table", "upl-recipe" })
    button.elem_value = item
    fire(button)
  end

  test("the message icons are real sprite paths", function()
    -- The engine renders an unknown [img=...] as the literal bracket text, silently; these
    -- two names are the premise the icon prefixes stand on.
    assert(helpers.is_valid_sprite_path("utility/warning_icon"), "warning icon path is gone")
    assert(helpers.is_valid_sprite_path("utility/not_available"), "error icon path is gone")
  end)

  test("a warning gets its own orange line and the stats stay plain", function()
    research.full(player().force)
    -- Productivity module 3 takes biter eggs, which rot in 30 minutes -- a real Space Age
    -- upcycling target that warns rather than refusing.
    open_with("productivity-module-3")
    local warning = line_with("upl-message.item-spoils")
    assert(warning, "the spoilage warning never reached the status area")
    -- A warning is build-through by definition; a warning that disabled Place would be a
    -- refusal wearing the wrong colour.
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled == true,
      "a build-through warning disabled Place")
    local colour = warning.style.font_color
    assert(math.abs(colour.g - 0.7) < 0.01 and math.abs(colour.b - 0.3) < 0.01,
      "warning colour is " .. serpent.line({ colour.r, colour.g, colour.b }))
    assert(warning.caption[2] == "[img=utility/warning_icon] ",
      "the warning line carries no icon: " .. serpent.line(warning.caption))
    -- The stats still show, in their own plain white: a warning ANNOTATES a plan, it neither
    -- replaces it nor repaints it -- the whole-block orange was the old shape's flaw.
    local layout = line_with("upl-gui.summary")
    assert(layout, "the warning ate the counts line")
    assert(layout.style.font_color.g > 0.99 and layout.style.font_color.b > 0.99,
      "the warning bled into the stats' colour")
    assert(line_with("upl-gui.yield"), "the warning ate the yield line")
    -- And the separator stands between the two groups.
    assert(status()["upl-status-sep"] ~= nil, "no separator between stats and messages")
  end)

  test("two warnings stack as two lines behind one separator", function()
    research.full(player().force)
    -- Two independent sources at once: the spoiling ingredient (validate's one message) and
    -- a pole that cannot cover the loop (the plan's own shortfall) -- plan_spec's big-pole
    -- scenario, driven through the modal with the machine pinned to the same assembler so
    -- the proven too-small-supply geometry carries over. This is the per-line promise: a
    -- regression that merged the warnings back into one block would pass every
    -- single-warning test.
    choices().recipe = "productivity-module-3"
    choices().quality = "rare"
    choices().machine = "assembling-machine-3"
    choices().pole = "big-electric-pole"
    gui.open(player())
    local first = status()["upl-message-1"]
    local second = status()["upl-message-2"]
    assert(first and second, "two warnings did not get two lines: "
      .. serpent.line(status().children_names))
    assert(first.caption[3][1] == "upl-message.item-spoils",
      "the first line is not the spoilage warning: " .. serpent.line(first.caption))
    assert(second.caption[3][1] == "upl-message.consumers-unpowered",
      "the second line is not the pole shortfall: " .. serpent.line(second.caption))
    for _, line in pairs({ first, second }) do
      local colour = line.style.font_color
      assert(math.abs(colour.g - 0.7) < 0.01, "a stacked warning lost the warning colour")
    end
    assert(status()["upl-stat-layout"] ~= nil, "the stacked warnings ate the stats")
    assert(status()["upl-status-sep"] ~= nil, "the stacked warnings lost the separator")
    -- The pinned picks would leak into the later tests' plans; back to defaults.
    choices().pole = nil
    choices().quality = nil
    choices().machine = nil
  end)

  test("an ordinary plan is stats only: no separator, no message lines", function()
    research.full(player().force)
    open_with("iron-gear-wheel")
    local layout = line_with("upl-gui.summary")
    assert(layout, "no counts line on a valid plan")
    local colour = layout.style.font_color
    assert(colour.g > 0.99 and colour.b > 0.99,
      "an unremarkable plan was coloured " .. serpent.line({ colour.r, colour.g, colour.b }))
    -- The footprint left the line for its tooltip (owner's call, 2026-08-28) -- still
    -- reachable on hover, never holding a stats row.
    assert(type(layout.tooltip) == "table" and layout.tooltip[1] == "upl-gui.footprint",
      "the footprint is not in the counts line's tooltip: " .. serpent.line(layout.tooltip))
    -- The pace stands with the stats, whatever unit its number picked.
    local pace = status()["upl-stat-time"]
    assert(pace, "no pace line on a valid plan")
    assert(tostring(pace.caption[1]):find("^upl%-gui%.time%-"),
      "pace caption " .. serpent.line(pace.caption))
    assert(status()["upl-status-sep"] == nil, "a clean plan drew the separator anyway")
    assert(status()["upl-message-1"] == nil, "a clean plan shows a message")
  end)

  test("a refusal is a red line with the error icon, and the stats go with the plan", function()
    research.full(player().force)
    -- The quantum processor's recipe returns a fluid alongside the item, so the loop cannot
    -- recycle its output back -- the faq's own example of a refused recipe.
    choices().recipe = "quantum-processor"
    gui.open(player())
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled == false,
      "Place enabled on a refused recipe")
    local refusal = status()["upl-message-1"]
    assert(refusal, "the refusal never reached the status area")
    local colour = refusal.style.font_color
    assert(math.abs(colour.g - 0.35) < 0.01 and math.abs(colour.b - 0.35) < 0.01,
      "error colour is " .. serpent.line({ colour.r, colour.g, colour.b }))
    assert(refusal.caption[2] == "[img=utility/not_available] ",
      "the refusal line carries no icon: " .. serpent.line(refusal.caption))
    -- No plan, no stats: a footprint for a loop that cannot exist would be a lie.
    assert(status()["upl-stat-layout"] == nil, "a refused plan still shows stats")
  end)

  test("nothing picked is a grey hint, not an error", function()
    -- Cleared rather than assumed: choices persist per player across tests, so an earlier
    -- pick would reopen the modal already valid. apply_defaults deliberately never defaults
    -- the recipe, so clearing it IS the never-picked state.
    choices().recipe = nil
    gui.open(player())
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled == false,
      "Place enabled with nothing picked")
    local hint = status()["upl-hint"]
    assert(hint, "the empty state shows no hint")
    assert(hint.caption[1] == "upl-gui.pick-a-recipe",
      "the hint says " .. serpent.line(hint.caption))
    local colour = hint.style.font_color
    assert(math.abs(colour.r - 0.7) < 0.01 and math.abs(colour.g - 0.7) < 0.01,
      "hint colour is " .. serpent.line({ colour.r, colour.g, colour.b }))
    assert(status()["upl-message-1"] == nil, "the empty state reads as an error line")
  end)
end)
