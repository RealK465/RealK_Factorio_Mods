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

-- Which tab holds each Build options child: spelled out once, so a control moved between tabs
-- breaks here loudly and the paths below keep naming the controls rather than the tab around
-- them.
local TAB_OF = {
  ["upl-buildings-table"] = "buildings", ["upl-columns-content"] = "buildings",
  ["upl-modules-table"] = "modules", ["upl-split-enabled"] = "modules",
  ["upl-split-content"] = "modules",
  ["upl-chests-table"] = "chests", ["upl-buffer-stock"] = "chests",
  ["upl-stock-requests"] = "chests", ["upl-terminal-requests"] = "chests",
  ["upl-trash"] = "chests", ["upl-requests-label"] = "chests",
  ["upl-ingredients-content"] = "chests",
  ["upl-circuit-enabled"] = "circuits", ["upl-circuits-content"] = "circuits",
}
local TAB_INDEX = { buildings = 1, modules = 2, chests = 3, circuits = 4 }

-- `name` defaults to on_gui_elem_changed, the event a completed pick raises; pass
-- on_gui_click when the test means a CLICK, because the chooser presumption in gui.lua keys
-- on exactly that difference.
local function fire(element, name)
  dispatch.on_gui_event({
    element = element, player_index = player().index,
    name = name or defines.events.on_gui_elem_changed,
  })
end

-- An engine event, raised the way the engine raises it: through whatever control.lua
-- registered, so the wiring is under test too. Absent registration, nothing hears it.
local function raise(id, data)
  local handler = script.get_event_handler(id)
  data.name, data.tick, data.player_index = id, game.tick, player().index
  if handler then handler(data) end
end

-- What the engine raises once its centring of the window lands (analysis/api.md S19, S39).
-- A headless run never lays a frame out, so the specs raise it in the engine's place.
local function engine_centres()
  raise(defines.events.on_gui_location_changed, { element = frame() })
end

-- A player's drag: the window moves, auto_center is left as the drag found it -- trusting a
-- drag to clear it was the 2.0.0 bug -- and the engine reports the move. The flag is lifted
-- around the write only because a location written over auto_center does not stick (S38).
local function drag_to(x, y)
  local f = frame()
  local was = f.auto_center
  f.auto_center = false
  f.location = { x = x, y = y }
  f.auto_center = was
  raise(defines.events.on_gui_location_changed, { element = f })
end

-- The framework runs the suite at game speed 1000, many ticks to each drawn frame, and the
-- engine lays a GUI out per drawn frame -- so a spec waiting on a layout waits at speed 1.
-- game.speed is writable (runtime-api.json); luacheck's std reads all of game as read-only.
local function after_drawn_ticks(ticks, fn)
  local speed = game.speed
  game.speed = 1 -- luacheck: ignore 122
  after_ticks(ticks, function()
    game.speed = speed -- luacheck: ignore 122
    fn()
  end)
end

-- A player's tab click, as the engine reports one: the index written, then the event. Only
-- the selected tab is filled, so this is also what makes a tab's controls exist at all.
local function open_tab(key)
  local pane = frame()["upl-main"]["upl-options"]
  if pane.selected_tab_index == TAB_INDEX[key] then return end
  pane.selected_tab_index = TAB_INDEX[key]
  fire(pane, defines.events.on_gui_selected_tab_changed)
end

local function find_widget(path, strict)
  -- The screen element is an invisible container; the planner window itself is its upl-main
  -- child, the settings panel's sibling, and every widget lives inside it. A path into the
  -- tabs gains its tab here, from TAB_OF -- unless it names the tab itself -- and the tab is
  -- picked first, the way a player reaches it. A reference taken in another tab dies there.
  local names = path
  if path[1] == "upl-options" and path[2] and not path[2]:match("^upl%-tab") then
    local tab = TAB_OF[path[2]]
    assert(tab, "no tab holds " .. path[2])
    open_tab(tab)
    names = { "upl-options", "upl-tab-" .. tab }
    for i = 2, #path do names[#names + 1] = path[i] end
  end
  local element = frame()["upl-main"]
  for _, name in pairs(names) do
    element = element[name]
    if not element then
      assert(not strict, "widget path broke at " .. name)
      return nil
    end
  end
  return element
end

local function widget(path)
  return find_widget(path, true)
end

-- The same path, or nil where it breaks: for asserting that a section is absent. A walk, not
-- a pcall, so an error while the tab fills still fails the test instead of reading as absent.
local function maybe_widget(path)
  return find_widget(path, false)
end

local function choices()
  return state.of(player().index).choices
end

-- The settings panel is a second COLUMN inside the modal's body, not a second screen frame, so
-- it is reached through the frame. Element names are spelled out here on purpose: they are the
-- contract a rename has to break loudly.
local SHOW_ALL_BOX = "upl-setting-show-all"

local function settings_panel()
  local f = frame()
  return f and f[gui.SETTINGS_FRAME]
end

-- The circuit limits, inline in the Circuits tab.
local function circuits_content()
  return widget({ "upl-options", "upl-circuits-content" })
end

-- The limits' row list, then one row (nil when the tier has none), then a row's field --
-- one owner for the inner path, so a container rename breaks one helper instead of every
-- assertion.
local function circuit_list()
  return circuits_content()["upl-circuits-list"]
end

local function circuit_row(tier)
  return circuit_list()["upl-circuit-row-" .. tier]
end

local function circuit_field(tier)
  return circuit_row(tier)["upl-circuit-limit-" .. tier]
end

-- The ingredient amounts, inline in the Chests tab.
local function ingredients_content()
  return widget({ "upl-options", "upl-ingredients-content" })
end

local function request_field(item)
  local list = ingredients_content()["upl-ingredients-list"]
  return list["upl-request-row-" .. item]["upl-request-" .. item]
end

-- The Minutes field above the rows.
local function minutes_field()
  return ingredients_content()["upl-feed-minutes-row"]["upl-feed-minutes"]
end

local function settings_widget(name)
  local panel = settings_panel()
  assert(panel and panel.valid, "the settings panel is not open")
  return panel["upl-settings-content"][name]
end

-- The productivity mix under the Modules tab's rows, or nil where the pair cannot mix.
local function split_section()
  return maybe_widget({ "upl-options", "upl-split-content" })
end

local function split_field(tier)
  local section = split_section()
  assert(section, "the ratio rows are not standing")
  return section["upl-split-list"]["upl-split-row-" .. tier]["upl-split-count-" .. tier]
end

-- The column counts at the foot of the Buildings tab.
local function columns_content()
  return widget({ "upl-options", "upl-columns-content" })
end

local function columns_field(tier)
  return columns_content()["upl-columns-list"]["upl-columns-row-" .. tier]["upl-columns-count-" .. tier]
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

-- Gears picked and Circuit limits ticked, the way most limits tests start: the tick through
-- its own handler, so the fields are armed by the refresh a player's click runs.
local function open_with_limits()
  open_with_gears()
  local box = widget({ "upl-options", "upl-circuit-enabled" })
  box.state = true
  fire(box, defines.events.on_gui_checked_state_changed)
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
    -- A setting left switched on would contradict the premise of every filter assertion in
    -- this file. Written only when it is actually on, so the ordinary case raises no
    -- setting-changed event that could land mid-way through the next test.
    if player().mod_settings[gui.SHOW_ALL_SETTING].value then
      player().mod_settings[gui.SHOW_ALL_SETTING] = { value = false }
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
    widget({ "upl-content", "upl-table", "upl-layout" })
    -- The build options are a tabbed pane of four, in order, opening on Buildings -- and only
    -- that tab holds anything, so no short tab sits over a tall one's blank space.
    local pane = widget({ "upl-options" })
    assert(pane.type == "tabbed-pane" and #pane.tabs == 4, "the build options are not four tabs")
    for index, key in ipairs({ "buildings", "modules", "chests", "circuits" }) do
      assert(pane.tabs[index].content.name == "upl-tab-" .. key, "tab " .. index .. " is "
        .. pane.tabs[index].content.name)
    end
    assert(pane.selected_tab_index == 1, "the pane opened on tab " .. tostring(pane.selected_tab_index))
    for _, key in pairs({ "modules", "chests", "circuits" }) do
      assert(#pane["upl-tab-" .. key].children == 0, "the unselected " .. key .. " tab is filled")
    end
    widget({ "upl-options", "upl-buildings-table", "upl-belt" })
    widget({ "upl-options", "upl-buildings-table", "upl-inserter" })
    widget({ "upl-options", "upl-buildings-table", "upl-pipe" })
    widget({ "upl-options", "upl-buildings-table", "upl-pole" })
    widget({ "upl-options", "upl-columns-content", "upl-columns-list" })
    widget({ "upl-options", "upl-modules-table", "upl-quality-module" })
    widget({ "upl-options", "upl-modules-table", "upl-terminal-module" })
    widget({ "upl-options", "upl-modules-table", "upl-beacon" })
    widget({ "upl-options", "upl-modules-table", "upl-beacon-module" })
    widget({ "upl-options", "upl-modules-table", "upl-beacon-count" })
    for _, role in pairs(planner.CHEST_ROLES) do
      widget({ "upl-options", "upl-chests-table", "upl-" .. role })
    end
    widget({ "upl-options", "upl-requests-label" })
    widget({ "upl-options", "upl-ingredients-content" })
    assert(widget({ "upl-options", "upl-buffer-stock" }).state == true,
      "buffer chests default checked")
    assert(widget({ "upl-options", "upl-stock-requests" }).state == true,
      "the stock request defaults checked")
    assert(widget({ "upl-options", "upl-terminal-requests" }).state == true,
      "the final machine's request defaults checked")
    assert(widget({ "upl-options", "upl-trash" }).state == true, "trash defaults checked")
    widget({ "upl-options", "upl-circuit-enabled" })
    widget({ "upl-options", "upl-circuits-content", "upl-circuits-list" })
    -- Picking a tab filled it and emptied the one before.
    assert(#pane["upl-tab-buildings"].children == 0, "the Buildings tab outlived the switch")

    -- Every row is a label beside its control, and the label goes wherever its control goes:
    -- an orphaned label is the obvious way to get a hidden row wrong.
    for _, entry in pairs({ { "upl-buildings-table", "belt" }, { "upl-buildings-table", "pole" },
                            { "upl-modules-table", "terminal-module" },
                            { "upl-chests-table", "stock" } }) do
      local rows = widget({ "upl-options", entry[1] })
      local label = rows["upl-" .. entry[2] .. "-label"]
      assert(label and label.caption[1] == "upl-gui." .. entry[2],
        entry[2] .. " has no label of its own")
      assert(label.visible == rows["upl-" .. entry[2]].visible, entry[2] .. "'s label strayed")
    end

    -- Everything the plan builds has its row, so every quality is one click away -- the lone
    -- recycler of this modset included, which used to hide for being the only one.
    assert(#planner.recyclers() == 1, "test premise: SA ships exactly one recycler")
    assert(widget({ "upl-content", "upl-table", "upl-recycler" }).visible == true,
      "the only recycler there is must still show: its quality is a choice")
    assert(widget({ "upl-content", "upl-table", "upl-recycler-label" }).visible == true,
      "the recycler's label went missing")
    for _, entry in pairs({ { "upl-buildings-table", "upl-belt" },
                            { "upl-buildings-table", "upl-inserter" },
                            { "upl-buildings-table", "upl-pole" },
                            { "upl-modules-table", "upl-quality-module" },
                            { "upl-modules-table", "upl-terminal-module" },
                            { "upl-modules-table", "upl-beacon" } }) do
      assert(widget({ "upl-options", entry[1], entry[2] }).visible == true,
        entry[2] .. " must stay visible")
    end
    for _, role in pairs(planner.CHEST_ROLES) do
      if role ~= "overflow" then
        assert(widget({ "upl-options", "upl-chests-table", "upl-" .. role }).visible == true,
          "the " .. role .. " picker must show in the Chests tab")
      end
    end
    -- And what the loop as chosen does not build stays out: no overflow chest on a belt ring
    -- to legendary, where nothing can roll higher; no pipe without a fluid recipe; no beacon
    -- module or count without a beacon.
    assert(widget({ "upl-options", "upl-chests-table", "upl-overflow" }).visible == false,
      "a legendary belt plan builds no overflow chest, yet its row shows")
    assert(widget({ "upl-options", "upl-buildings-table", "upl-pipe" }).visible == false,
      "no recipe takes a fluid yet: the pipe row must wait")
    for _, name in pairs({ "upl-beacon-module", "upl-beacon-count" }) do
      assert(widget({ "upl-options", "upl-modules-table", name }).visible == false,
        name .. " stands with no beacon to fill")
    end

    local c = choices()
    -- The one picker with no default at all: beacons are off until asked for.
    assert(c.beacon == nil, "a beacon choice appeared from nowhere")
    assert(widget({ "upl-options", "upl-modules-table", "upl-beacon" }).elem_value == nil,
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
    local button = widget({ "upl-options", "upl-buildings-table", "upl-belt" })
    button.elem_value = nil
    fire(button)
    assert(choices().belt == "turbo-transport-belt", "belt did not snap back")
    assert(button.elem_value == "turbo-transport-belt", "snap-back not shown on the strip")
  end)

  test("clearing the pipe snaps back like the belt -- a fluid plan cannot go without one", function()
    open_with_gears()
    local button = widget({ "upl-options", "upl-buildings-table", "upl-pipe" })
    button.elem_value = nil
    fire(button)
    assert(choices().pipe == "pipe", "pipe did not snap back")
    assert(button.elem_value == "pipe", "snap-back not shown on the strip")
  end)

  test("clearing the pole means no poles -- the one picker that stays empty", function()
    open_with_gears()
    local button = widget({ "upl-options", "upl-buildings-table", "upl-pole" })
    button.elem_value = nil
    fire(button)
    assert(choices().no_poles == true, "cleared pole picker did not record the choice")
    assert(choices().pole == nil, "pole name survived the clear")

    button.elem_value = { name = "medium-electric-pole", quality = "normal" }
    fire(button)
    assert(choices().no_poles == false, "re-picking a pole did not clear no_poles")
  end)

  test("picking a beacon brings out its module and count rows, the module defaulted to efficiency", function()
    open_with_gears()
    -- The beacon row stands from the start, empty -- off is its resting state -- and the two
    -- rows that only mean something with a beacon wait for one.
    local beacon = widget({ "upl-options", "upl-modules-table", "upl-beacon" })
    assert(beacon.visible == true, "the beacon row must stand before any pick")
    assert(widget({ "upl-options", "upl-modules-table", "upl-beacon-module" }).visible == false,
      "test premise: the beacon module row starts hidden")
    beacon.elem_value = { name = "beacon", quality = "normal" }
    fire(beacon)
    -- The beacon handler rebuilds the modal -- the module picker's options and the rows'
    -- visibility follow the pick -- so every reference above is stale from here.
    assert(choices().beacon == "beacon", "the beacon pick did not take")
    for _, key in pairs({ "beacon-module", "beacon-count" }) do
      local rows = widget({ "upl-options", "upl-modules-table" })
      assert(rows["upl-" .. key].visible == true and rows["upl-" .. key .. "-label"].visible == true,
        "the " .. key .. " row must come out with the pick, label and all")
    end
    assert(choices().beacon_module == "efficiency-module-3",
      "the module must default to the strongest researched efficiency module, got "
      .. tostring(choices().beacon_module))
    local module_button = widget({ "upl-options", "upl-modules-table", "upl-beacon-module" })
    local shown = module_button.elem_value
    assert(shown and shown.name == "efficiency-module-3", "the default is not on the picker")
    -- The count dropdown comes out with the pick too, offering exactly what fits: the vanilla
    -- pair leaves 13 interior rows, four 3-tall beacons.
    local dropdown = widget({ "upl-options", "upl-modules-table", "upl-beacon-count" })
    assert(dropdown.visible == true, "the count dropdown must show once a beacon is chosen")
    assert(#dropdown.items == 4, "count options " .. #dropdown.items .. ", expected 4")
    assert(dropdown.selected_index == 1, "the count must default to one")
    assert(choices().beacon_count == 1, "the default count must be recorded")
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled == true,
      "Place disabled by a beacon pick")
  end)

  test("the beacon count stores a plain number, read from the dropdown's own tags", function()
    open_with_gears()
    local beacon = widget({ "upl-options", "upl-modules-table", "upl-beacon" })
    beacon.elem_value = { name = "beacon", quality = "normal" }
    fire(beacon)

    local dropdown = widget({ "upl-options", "upl-modules-table", "upl-beacon-count" })
    dropdown.selected_index = 3
    fire(dropdown, defines.events.on_gui_selection_state_changed)
    assert(choices().beacon_count == 3, "the count pick did not take")
    assert(type(choices().beacon_count) == "number", "the count must store as a plain number")
    -- The count moves the ratio rows' numbers, so the Modules tab is refilled in place -- and
    -- only the tab: the top block stands, and the new drop-down shows the pick.
    assert(widget({ "upl-options", "upl-modules-table", "upl-beacon-count" }).selected_index == 3,
      "the refilled tab lost the count")
  end)

  test("a remembered count that outgrew the geometry snaps down on open", function()
    open_with_gears()
    local beacon = widget({ "upl-options", "upl-modules-table", "upl-beacon" })
    beacon.elem_value = { name = "beacon", quality = "normal" }
    fire(beacon)
    choices().beacon_count = 99
    gui.open(player())
    assert(choices().beacon_count == 4,
      "count " .. tostring(choices().beacon_count) .. ", expected the snap to the max of 4")
    assert(widget({ "upl-options", "upl-modules-table", "upl-beacon-count" }).selected_index == 4,
      "the dropdown must show the snapped count")
  end)

  test("a recycler pick rebuilds the modal, so the count list follows its height", function()
    -- The count dropdown's item list is derived at build time from the recycler's rotated
    -- height, so the recycler handler must gui.open like the machine's, never just refresh.
    -- Pinned structurally: any widget from before the pick must die with the rebuild.
    open_with_gears()
    local button = widget({ "upl-content", "upl-table", "upl-recycler" })
    local before = widget({ "upl-content", "upl-table", "upl-quality" })
    button.elem_value = { name = "recycler", quality = "rare" }
    fire(button)
    assert(choices().recycler_quality == "rare", "the recycler quality did not take")
    assert(not before.valid, "a recycler pick must rebuild the modal")
  end)

  test("clearing the beacon means none, keeps its quality, and hides the module row", function()
    open_with_gears()
    local beacon = widget({ "upl-options", "upl-modules-table", "upl-beacon" })
    beacon.elem_value = { name = "beacon", quality = "rare" }
    fire(beacon)
    assert(choices().beacon_quality == "rare", "the beacon quality did not take")

    -- Re-fetched: the beacon handler rebuilds the modal, so the reference above is stale.
    beacon = widget({ "upl-options", "upl-modules-table", "upl-beacon" })
    beacon.elem_value = nil
    fire(beacon)
    assert(choices().beacon == nil, "the beacon survived the clear")
    -- The machine's rule: the player asked for rare buildings, not a rare beacon specifically.
    assert(choices().beacon_quality == "rare", "quality reset by the clear")
    -- Clearing takes the module and count rows back out, labels and all; the beacon row
    -- itself stays, empty, ready for the next pick.
    local rows = widget({ "upl-options", "upl-modules-table" })
    assert(rows["upl-beacon"].visible == true, "the beacon row went with the clear")
    for _, key in pairs({ "beacon-module", "beacon-count" }) do
      assert(rows["upl-" .. key].visible == false and rows["upl-" .. key .. "-label"].visible == false,
        "the " .. key .. " row outlived the clear")
    end
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled == true,
      "Place must stay enabled -- a loop without beacons is the default plan")
  end)

  test("a non-beacon in the beacon picker snaps back instead of being kept", function()
    -- Reachable only on a modset whose beacons are all slot-less or unplaceable, where the
    -- empty candidate list leaves the picker unfiltered -- the terminal module's own guard,
    -- driven here by writing past the filter, which the API allows.
    open_with_gears()
    local beacon = widget({ "upl-options", "upl-modules-table", "upl-beacon" })
    beacon.elem_value = { name = "steel-chest", quality = "normal" }
    assert(beacon.elem_value ~= nil,
      "test premise: the API must accept an off-filter elem_value write")
    fire(beacon)
    assert(choices().beacon == nil, "a chest was kept as the beacon choice")
    assert(beacon.elem_value == nil, "the snap-back must show the empty resting state")
  end)

  test("clearing the beacon's module plans an empty beacon; a pick survives", function()
    open_with_gears()
    local beacon = widget({ "upl-options", "upl-modules-table", "upl-beacon" })
    beacon.elem_value = { name = "beacon", quality = "normal" }
    fire(beacon)

    local button = widget({ "upl-options", "upl-modules-table", "upl-beacon-module" })
    button.elem_value = nil
    fire(button)
    assert(choices().beacon_module == nil, "clearing did not empty the beacon")
    assert(choices().no_beacon_module == true, "clearing did not record the choice")

    -- Re-fetched: a module change refills the Modules tab, the ratio rows' numbers moving.
    button = widget({ "upl-options", "upl-modules-table", "upl-beacon-module" })
    button.elem_value = { name = "speed-module-3", quality = "rare" }
    fire(button)
    assert(choices().beacon_module == "speed-module-3", "the pick did not take")
    assert(choices().beacon_module_quality == "rare", "the pick's quality did not take")
    assert(choices().no_beacon_module == false, "picking must clear the emptied flag")
  end)

  test("clearing the inserter snaps back to the best researched, visibly", function()
    open_with_gears()
    local button = widget({ "upl-options", "upl-buildings-table", "upl-inserter" })
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
    -- which is what makes it the honest one to drive through the shared handler.
    open_with_gears()
    local button = widget({ "upl-options", "upl-chests-table", "upl-container" })
    button.elem_value = { name = "iron-chest", quality = "uncommon" }
    fire(button)
    assert(choices().container == "iron-chest", "plain-chest pick lost")
    assert(choices().container_quality == "uncommon", "plain-chest quality lost on pick")
    -- One handler serves all five pickers, so the role in the tags is load-bearing: a write
    -- that reached a sibling role would silently swap the wrong chest.
    assert(choices().requester == "requester-chest", "the requester role was overwritten")
    assert(choices().provider == "passive-provider-chest", "the provider role was overwritten")

    button.elem_value = nil
    fire(button)
    assert(choices().container == "steel-chest", "plain chest did not snap back to the largest")
    local shown = button.elem_value
    assert(shown and shown.name == "steel-chest", "snap-back not shown on the strip")
  end)

  test("a recipe the chosen inserter can still filter split keeps the pick, and Place", function()
    -- Fusion reactor equipment takes six ingredients and every vanilla inserter carries five
    -- filter slots: one inserter cannot serve it, two stacks of three can, so the re-pick --
    -- which exists so no outgrown pick is left behind to fail validation -- must NOT fire on
    -- a pick the split still serves. It used to empty the picker and disarm Place here.
    open_with_gears()
    local inserter = widget({ "upl-options", "upl-buildings-table", "upl-inserter" })
    inserter.elem_value = { name = "fast-inserter", quality = "normal" }
    fire(inserter)
    assert(choices().inserter == "fast-inserter", "test setup: the pick did not take")

    assert(planner.recipe_for_item("fusion-reactor-equipment"),
      "test premise: fusion reactor equipment should be upcyclable")
    local recipe_button = widget({ "upl-content", "upl-table", "upl-recipe" })
    recipe_button.elem_value = "fusion-reactor-equipment"
    fire(recipe_button)
    assert(choices().inserter == "fast-inserter", "a pick the split serves was re-picked")
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled == true,
      "Place went down for a recipe two feed stacks can filter")
  end)

  test("the top machine's module follows the recipe, and clearing means empty", function()
    open_with_gears()
    -- Gears allow productivity, so the pair defaults to the strongest researched one.
    assert(choices().terminal_module == "productivity-module-3",
      "terminal default " .. tostring(choices().terminal_module))
    local function module_button()
      return widget({ "upl-options", "upl-modules-table", "upl-terminal-module" })
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

    -- Re-fetched: a module change refills the Modules tab, the ratio rows' numbers moving.
    button = module_button()
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

  test("the pipe row follows the recipe's fluids", function()
    -- The one Buildings row the loop as chosen may not build: it waits for a recipe that takes
    -- a fluid, whatever the pipe count -- the SA modset's single pipe included, whose row used
    -- to stay hidden for being the only one.
    open_with_gears()
    local pipe = widget({ "upl-options", "upl-buildings-table", "upl-pipe" })
    assert(pipe.visible == false, "gears take no fluid: the pipe row must wait")
    -- Defaulted all the same, so the row opens showing the pipe the plan would use.
    assert(choices().pipe == "pipe", "the pipe default must stand behind the hidden row")

    local recipe_button = widget({ "upl-content", "upl-table", "upl-recipe" })
    recipe_button.elem_value = "battery"
    fire(recipe_button)
    assert(choices().recipe == "battery", "test setup: the battery recipe did not take")
    -- Re-fetched: the recipe handler rebuilds the modal, so the reference above is stale.
    local rows = widget({ "upl-options", "upl-buildings-table" })
    assert(rows["upl-pipe"].visible == true and rows["upl-pipe-label"].visible == true,
      "a fluid recipe must bring the pipe row out, label and all")
    assert(rows["upl-pipe"].elem_value == "pipe", "the pipe row opened empty")
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
    -- The box reads the SETTING, not a private copy -- that is the whole storage decision --
    -- and it is the only one: nothing the plan builds hides for having one option any more.
    assert(settings_widget(SHOW_ALL_BOX).state == false, "the show-all box does not read its setting")
    assert(#panel["upl-settings-content"].children == 1,
      "the settings panel holds " .. #panel["upl-settings-content"].children .. " settings")
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
    local button = widget({ "upl-options", "upl-buildings-table", "upl-belt" })
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

  test("the settings tick reaches the setting and back, through one rebuild", function()
    -- The one setting left: the second, show all build options, went with the rule it undid --
    -- nothing the plan builds hides for having one option any more.
    assert(prototypes.mod_setting["upcycler-planner-show-all-build-options"] == nil,
      "the retired setting is still declared")
    gui.open(player())
    gui.open_settings(player())
    local box = settings_widget(SHOW_ALL_BOX)
    box.state = true
    fire(box, defines.events.on_gui_checked_state_changed)

    -- The handler writes the setting and stops; the repaint belongs to the one
    -- on_runtime_mod_setting_changed handler, which serves the settings menu identically. So the
    -- modal is REBUILT here, and every widget reference taken above is stale from now on.
    after_ticks(2, function()
      assert(player().mod_settings[gui.SHOW_ALL_SETTING].value == true, "the tick never landed")
      assert(frame() and frame().valid, "the modal did not come back after the setting flipped")
      assert(settings_widget(SHOW_ALL_BOX).state == true, "the rebuilt panel lost the tick")
      -- And it reverses: the same path, from the settings menu's side of the setting.
      player().mod_settings[gui.SHOW_ALL_SETTING] = { value = false }
      after_ticks(2, function()
        assert(settings_widget(SHOW_ALL_BOX).state == false,
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

  test("the two request checkboxes reach the choices and the plan, and survive a rebuild", function()
    open_with_gears()
    for _, entry in pairs({
      { box = "upl-stock-requests", key = "stock_requests" },
      { box = "upl-terminal-requests", key = "terminal_requests" },
    }) do
      assert(choices()[entry.key] == true, entry.key .. " did not default to ticked")
      local box = widget({ "upl-options", entry.box })
      box.state = false
      fire(box)
      assert(choices()[entry.key] == false, "unticking " .. entry.box .. " did not reach the choices")
      -- The double-fire rule: the second event must be a harmless repeat.
      fire(box)
      assert(choices()[entry.key] == false, "the double-fire changed " .. entry.key)
    end

    -- The plan the modal would hand over: stock chests that request nothing, and a plain
    -- chest in front of the final machine.
    local plan = planner.plan(player().force, choices())
    assert(plan, "the unticked choices no longer plan")
    local requesters, stock_requests = 0, 0
    for _, e in pairs(plan.entities) do
      if e.name == "requester-chest" then requesters = requesters + 1 end
      if e.name == "buffer-chest" and e.requests then stock_requests = stock_requests + 1 end
    end
    -- One machine per tier and one feed chest each, the final machine's now a plain chest.
    assert(requesters == plan.machines - 1, "requesting feed chests " .. requesters
      .. " for " .. plan.machines .. " machines, expected every tier but the last")
    assert(stock_requests == 0, stock_requests .. " stock chests still request")

    -- An item change sweeps the per-item request_<item> overrides. The two checkboxes are
    -- not of that family -- which is why neither key may start with request_ -- and ride
    -- through it, as they do through the rebuild the pick causes.
    local recipe = widget({ "upl-content", "upl-table", "upl-recipe" })
    recipe.elem_value = "copper-cable"
    fire(recipe)
    assert(choices().recipe == "copper-cable", "test setup: the item did not change")
    assert(choices().stock_requests == false and choices().terminal_requests == false,
      "an item change swept a request checkbox")
    assert(widget({ "upl-options", "upl-stock-requests" }).state == false
      and widget({ "upl-options", "upl-terminal-requests" }).state == false,
      "a rebuilt modal re-ticked a request the player had unticked")
  end)

  test("the buffer-chests checkbox swaps the stock picker's kind, refilling its best", function()
    open_with_gears()
    -- A deliberate quality on the stock pick, to prove the toggle keeps it: the player asked
    -- for uncommon chests, not for an uncommon buffer chest specifically.
    local button = widget({ "upl-options", "upl-chests-table", "upl-stock" })
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
    local shown = widget({ "upl-options", "upl-chests-table", "upl-stock" }).elem_value
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

  test("the Circuits tab: the checkbox arms a field per tier, standing inline", function()
    open_with_gears()
    local box = widget({ "upl-options", "upl-circuit-enabled" })
    assert(box.state == false, "circuit limits must start off")
    -- Full research defaults the target to the top of the chain, so every tier is a row --
    -- built whether or not the limits are on, and greyed until they are.
    local tiers = { "normal", "uncommon", "rare", "epic", "legendary" }
    for _, tier in pairs(tiers) do
      assert(circuit_field(tier).enabled == false, tier .. " field is live with the limits off")
    end

    box.state = true
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().circuit_enabled == true, "the tick did not reach the choices")
    -- A refresh, never a rebuild, so the reference itself survives -- which is also worth
    -- asserting: a rebuild here would eat the click's second event.
    assert(box.valid, "the tick rebuilt the modal")
    for _, tier in pairs(tiers) do
      assert(circuit_field(tier).enabled == true, tier .. " field stayed greyed after the tick")
    end
    assert(player().gui.screen["upl-circuits"] == nil and frame()["upl-circuits"] == nil,
      "the limits must stand in their tab, not in a window of their own")
    -- The lower tiers open as Min 0 -- keep nothing back -- and the target as Max one stack
    -- of gears; the row's first label says which rule the field sets.
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

  test("Start paused: armed by the cap, stored on the tick, dead under a zero cap", function()
    open_with_limits()
    local paused = circuits_content()["upl-circuit-paused"]
    assert(paused, "Start paused is not at the foot of the limits")
    -- The backfilled cap (one stack of gears) arms it from the first open.
    assert(paused.state == false and paused.enabled == true,
      "Start paused must open unticked and armed by the backfilled cap")

    paused.state = true
    fire(paused, defines.events.on_gui_checked_state_changed)
    assert(choices().circuit_paused == true, "the tick did not reach the choices")
    assert(paused.valid, "the tick rebuilt the limits under the cursor")

    -- No cap, nothing the switch could pause through: zeroing the Max greys it in place,
    -- and a cap typed back arms it again.
    local field = circuit_field("legendary")
    field.text = "0"
    fire(field, defines.events.on_gui_text_changed)
    assert(paused.valid and paused.enabled == false, "Start paused stayed armed under a zero cap")
    assert(choices().circuit_paused == true, "greying the box must not forget the choice")
    field.text = "20"
    fire(field, defines.events.on_gui_text_changed)
    assert(paused.enabled == true, "Start paused did not re-arm with the cap")

    -- Unticking the limits greys it too, and keeps the choice for a re-tick.
    local box = widget({ "upl-options", "upl-circuit-enabled" })
    box.state = false
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(paused.valid and paused.enabled == false, "unticking the limits left Start paused live")
    assert(choices().circuit_paused == true, "unticking the limits forgot Start paused")
  end)

  test("Count the logistic network sits above Start paused: armed by the cap, stored on the tick, dead under a zero cap", function()
    open_with_limits()
    local content = circuits_content()
    local network = content["upl-circuit-network"]
    assert(network, "the network box is not with the limits")
    assert(network.state == false and network.enabled == true,
      "the network box must open unticked and armed by the backfilled cap")
    -- The two share the foot, the cap's own option first.
    local order = {}
    for index, child in pairs(content.children) do order[child.name] = index end
    assert(order["upl-circuit-network"] < order["upl-circuit-paused"],
      "the network box is not above Start paused")

    network.state = true
    fire(network, defines.events.on_gui_checked_state_changed)
    assert(choices().circuit_network == true, "the tick did not reach the choices")
    assert(network.valid, "the tick rebuilt the limits under the cursor")

    -- Nothing to count without a cap: zeroing the Max greys it in place, a cap typed back
    -- arms it again, and the stored tick survives both.
    local field = circuit_field("legendary")
    field.text = "0"
    fire(field, defines.events.on_gui_text_changed)
    assert(network.valid and network.enabled == false, "the network box stayed armed under a zero cap")
    assert(choices().circuit_network == true, "greying the box must not forget the choice")
    field.text = "20"
    fire(field, defines.events.on_gui_text_changed)
    assert(network.enabled == true, "the network box did not re-arm with the cap")

    network.state = false
    fire(network, defines.events.on_gui_checked_state_changed)
    assert(choices().circuit_network == false, "the untick did not reach the choices")
  end)

  test("typing commits without a rebuild; Enter snaps the text to what holds", function()
    open_with_limits()

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

  test("Hand size: the researched hand by default, armed by a minimum, only an edit stored", function()
    open_with_limits()
    local function hand_field()
      return circuits_content()["upl-circuit-hand-row"]["upl-circuit-hand"]
    end
    -- Full research and the default pick -- the bulk inserter -- read 12 (api.md S33), and
    -- nothing is stored for an untouched field: the number follows the pick and the research.
    assert(hand_field().text == "12", "the hand field opened as " .. hand_field().text)
    assert(choices().circuit_hand == nil, "opening the limits stored the default hand")
    assert(hand_field().enabled == false, "the hand must be dead while no minimum is set")

    -- A minimum arms it in place, through the Min field's own keystroke refresh.
    local minimum = circuit_field("uncommon")
    minimum.text = "20"
    fire(minimum, defines.events.on_gui_text_changed)
    assert(hand_field().valid and hand_field().enabled == true,
      "a minimum did not arm the hand field in place")

    -- Typing commits; Enter on an emptied field deletes the override and shows the default.
    local field = hand_field()
    field.text = "3"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices().circuit_hand == 3, "the keystroke did not commit")
    assert(field.valid, "the keystroke rebuilt the modal under the cursor")
    field.text = ""
    fire(field, defines.events.on_gui_confirmed)
    assert(choices().circuit_hand == nil, "Enter on an emptied field kept the override")
    assert(field.text == "12", "Enter left the field showing " .. field.text)

    -- Enter on the untouched default stores nothing -- the focus click's case.
    fire(field, defines.events.on_gui_confirmed)
    assert(choices().circuit_hand == nil, "Enter on the default froze it as an override")

    -- A different inserter moves the untouched field to its own researched hand: the pick is
    -- in the Buildings tab, so the Circuits tab comes back refilled with the new number, the
    -- text and the default Enter is judged against moving together.
    local picker = widget({ "upl-options", "upl-buildings-table", "upl-inserter" })
    picker.elem_value = { name = "fast-inserter", quality = "normal" }
    fire(picker)
    field = hand_field()
    assert(field.text == "4", "the fast inserter's hand reads " .. field.text)
    assert(field.tags.default == 4, "the default in the tags did not follow the pick")
    fire(field, defines.events.on_gui_confirmed)
    assert(choices().circuit_hand == nil, "Enter on the moved default froze it as an override")

    -- And in place, for a change the tab is standing through: the refresh that follows an
    -- inserter swap keeps an untouched field's text and default on the new hand.
    choices().inserter = "bulk-inserter"
    gui.refresh(player())
    assert(field.valid, "a refresh rebuilt the limits under the cursor")
    assert(field.text == "12" and field.tags.default == 12,
      "the standing field did not follow the inserter: " .. field.text)
  end)

  test("an empty inserter pick leaves the limits standing, not crashed", function()
    -- With no inserter picked the Hand size default has no prototype to read and must fall
    -- back rather than index nil -- validate refuses such a plan anyway, so the number shown
    -- does not matter, the survival of the build does. Fusion reactor equipment used to
    -- empty the pick here (six ingredients, five slots); since the second feed stack no
    -- vanilla recipe does, so the pick is emptied by hand, as a force with only fuelled
    -- inserters researched would leave it.
    open_with_limits()
    local recipe_button = widget({ "upl-content", "upl-table", "upl-recipe" })
    recipe_button.elem_value = "fusion-reactor-equipment"
    fire(recipe_button)
    assert(choices().inserter ~= nil, "test premise: six ingredients should keep a pick now")

    -- A rebuild would default the pick again, so the empty pick meets the refresh that keeps
    -- an untouched Hand size following the inserter -- the path with nothing to read.
    choices().inserter = nil
    gui.refresh(player())
    local field = circuits_content()["upl-circuit-hand-row"]["upl-circuit-hand"]
    assert(field.text == "1", "the hand field reads " .. field.text .. " with no inserter")
  end)

  test("unticking the limits greys the fields and keeps their numbers", function()
    open_with_limits()
    local field = circuit_field("uncommon")
    field.text = "25"
    fire(field, defines.events.on_gui_text_changed)
    local box = widget({ "upl-options", "upl-circuit-enabled" })
    box.state = false
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().circuit_enabled == false, "the untick did not reach the choices")
    assert(field.valid and field.enabled == false, "an unticked limit stayed live")
    assert(choices().circuit_min_uncommon == 25, "unticking forgot the number for a re-tick")
  end)

  test("Esc on the Circuits tab closes the planner in one step: no panel stands to take it", function()
    open_with_limits()
    player().opened = nil
    after_ticks(2, function()
      assert(frame() == nil, "Esc left the planner standing with no side panel open")
    end)
  end)

  test("the Confirm key places from the Circuits tab, the typed numbers already committed", function()
    -- Every valid keystroke commits, so E reaching Place mid-edit places what is typed: the
    -- inline fields need none of the old wizard's guard.
    open_with_limits()
    local field = circuit_field("legendary")
    field.text = "40"
    fire(field, defines.events.on_gui_text_changed)
    gui.confirm_key(player())

    local stack = player().cursor_stack
    assert(stack and stack.valid_for_read and stack.is_blueprint,
      "the key placed nothing from the Circuits tab")
    assert(frame() == nil, "placing did not close the planner")
    assert(choices().circuit_max_legendary == 40,
      "the typed maximum was not committed: " .. tostring(choices().circuit_max_legendary))
  end)

  test("the Place button places from the Circuits tab", function()
    open_with_limits()
    fire(widget({ "upl-buttons", "upl-confirm" }), defines.events.on_gui_click)

    local stack = player().cursor_stack
    assert(stack and stack.valid_for_read and stack.is_blueprint,
      "the button did not place a blueprint from the Circuits tab")
    assert(frame() == nil, "placing did not close the planner")
  end)

  test("a target change reshapes the Circuits tab's rows in place", function()
    open_with_limits()
    assert(circuit_field("legendary"), "test premise: the default target lists every tier")

    local dropdown = widget({ "upl-content", "upl-table", "upl-quality" })
    dropdown.selected_index = 1 -- uncommon, the first offered target
    fire(dropdown, defines.events.on_gui_selection_state_changed)

    assert(choices().quality == "uncommon", "the target change did not land")
    -- In place: the drop-down that asked survives, where a rebuild would have replaced it.
    assert(dropdown.valid, "the target change rebuilt the modal")
    assert(circuit_field("uncommon"), "the limits lost the tier the new target keeps")
    assert(circuit_row("rare") == nil, "the limits still list a tier the new target dropped")
    assert(circuit_row("uncommon").children[1].caption[1] == "upl-gui.circuit-max",
      "the new target's row is not labelled Max")
    assert(circuit_field("uncommon").enabled == true, "the rebuilt rows came back greyed")
    assert(circuit_field("uncommon").text == "100",
      "the new target's Max was not backfilled: " .. circuit_field("uncommon").text)
  end)

  test("the Chests tab's amounts wait for an item, then stand inline at the plan's own numbers", function()
    gui.open(player())
    local hint = ingredients_content()["upl-hint"]
    assert(hint and hint.caption[1] == "upl-gui.pick-a-recipe",
      "the amounts must say what they wait for before an item is picked")
    assert(ingredients_content()["upl-ingredients-list"] == nil, "rows stood with no recipe")

    open_with_gears()
    assert(frame()["upl-ingredients"] == nil and player().gui.screen["upl-ingredients"] == nil,
      "the amounts must stand in their tab, not in a window of their own")
    -- Gears: 2 plates per 0.5 s craft is 240 a minute, 480 for the default two minutes --
    -- the formula's own value on display, because nothing is stored until the player edits.
    assert(request_field("iron-plate").text == "480",
      "the field opened as " .. request_field("iron-plate").text)
    assert(choices()["request_iron-plate"] == nil,
      "building the amounts stored an override the player never made")
    assert(minutes_field().text == "2", "the minutes opened as " .. minutes_field().text)
    assert(choices().feed_minutes == nil, "building the amounts stored the default minutes")
  end)

  test("typing commits an override; Enter on an emptied field returns to automatic", function()
    open_with_gears()

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
    assert(field.text == "480", "the display did not snap to the automatic amount")

    -- Zero cannot be typed into a request: the floor is one.
    field.text = "0"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices()["request_iron-plate"] == 1, "a zero committed below the floor")
  end)

  test("picking a different item resets the overrides and refills the amounts", function()
    open_with_gears()
    choices()["request_iron-plate"] = 250

    local button = widget({ "upl-content", "upl-table", "upl-recipe" })
    button.elem_value = "transport-belt"
    fire(button)

    assert(choices().recipe == "transport-belt", "premise: the pick landed")
    assert(choices()["request_iron-plate"] == nil,
      "an override sized for gears survived onto belts")
    -- The rebuild stood the NEW recipe's ingredients at their own automatic amounts: belts
    -- eat gears, which gears did not -- one per 0.5 s craft, two minutes' worth.
    assert(request_field("iron-gear-wheel").text == "240",
      "the new recipe's field opened as " .. request_field("iron-gear-wheel").text)
  end)

  test("the Minutes field re-sizes every row in place and replaces their overrides", function()
    open_with_gears()
    local master = minutes_field()
    -- The focus click and Enter on the untouched default store nothing, request-count's
    -- rule: the default keeps following planner.DEFAULT_FEED_MINUTES.
    fire(master, defines.events.on_gui_click)
    fire(master, defines.events.on_gui_confirmed)
    assert(choices().feed_minutes == nil, "a non-edit stored the default minutes")

    -- A per-ingredient override, then the minutes move: the override goes, the row shows the
    -- new automatic amount with its default moved alongside, and neither field was rebuilt
    -- under the cursor.
    local field = request_field("iron-plate")
    field.text = "250"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices()["request_iron-plate"] == 250, "premise: the override landed")
    master.text = "1"
    fire(master, defines.events.on_gui_text_changed)
    assert(choices().feed_minutes == 1, "the keystroke did not commit the minutes")
    assert(choices()["request_iron-plate"] == nil, "the minutes change kept the override")
    assert(master.valid and field.valid, "the minutes change rebuilt the rows under the cursor")
    assert(field.text == "240", "the row was not re-sized: " .. field.text)
    assert(field.tags.default == 240, "the row's default did not follow the minutes")
    -- Enter on the re-sized row is the untouched case again: nothing stored.
    fire(field, defines.events.on_gui_confirmed)
    assert(choices()["request_iron-plate"] == nil, "Enter on the re-sized row froze it")
    -- Re-stating the same minutes moves nothing, so an override typed after it survives.
    field.text = "50"
    fire(field, defines.events.on_gui_text_changed)
    master.text = "1"
    fire(master, defines.events.on_gui_confirmed)
    assert(choices()["request_iron-plate"] == 50, "an unmoved master dropped the override")

    -- Out of range clamps; an emptied field mid-edit keeps the last value; Enter on it
    -- returns to two and re-sizes the rows again.
    master.text = "500"
    fire(master, defines.events.on_gui_text_changed)
    assert(choices().feed_minutes == planner.MAX_FEED_MINUTES, "the minutes did not clamp")
    assert(choices()["request_iron-plate"] == nil, "the clamped change kept the override")
    master.text = ""
    fire(master, defines.events.on_gui_text_changed)
    assert(choices().feed_minutes == planner.MAX_FEED_MINUTES,
      "an emptied field mid-edit clobbered the minutes")
    fire(master, defines.events.on_gui_confirmed)
    assert(choices().feed_minutes == nil, "Enter on empty kept the minutes")
    assert(master.text == "2", "the display did not snap to the default minutes")
    assert(field.text == "480", "the rows did not return to two minutes: " .. field.text)
  end)

  test("picking a different item keeps the minutes", function()
    open_with_gears()
    local master = minutes_field()
    master.text = "4"
    fire(master, defines.events.on_gui_text_changed)
    assert(choices().feed_minutes == 4, "premise: the minutes landed")

    local button = widget({ "upl-content", "upl-table", "upl-recipe" })
    button.elem_value = "transport-belt"
    fire(button)
    assert(choices().recipe == "transport-belt", "premise: the pick landed")
    -- A preference, not a size fitted to one recipe: it outlives the item, and the rebuilt
    -- rows size the new recipe from it -- one gear per 0.5 s craft, four minutes.
    assert(choices().feed_minutes == 4, "the item change reset the minutes")
    assert(minutes_field().text == "4", "the rebuilt amounts lost the minutes")
    assert(request_field("iron-gear-wheel").text == "480",
      "the new recipe's field opened as " .. request_field("iron-gear-wheel").text)
  end)

  test("an amount past the ingredient chest's slots warns, following every keystroke", function()
    open_with_gears()
    assert(status_entry("upl-message-1") == nil, "premise: two minutes of gears warn already")

    -- A hundred minutes of plates is 24000: 240 slots of a 48-slot chest.
    local master = minutes_field()
    master.text = "100"
    fire(master, defines.events.on_gui_text_changed)
    local line = status_entry("upl-message-1")
    assert(line and line[3][1] == "upl-message.request-too-big",
      "no too-big warning after the minutes: " .. serpent.line(line))
    -- Build-through: Place stays enabled, and the fields survived the repaint.
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled == true, "the warning disabled Place")
    assert(master.valid, "the warning rebuilt the rows under the cursor")
    master.text = "2"
    fire(master, defines.events.on_gui_text_changed)
    assert(status_entry("upl-message-1") == nil, "the warning outlived the minutes")

    -- One row can overflow the chest on its own, and clears the same way.
    local field = request_field("iron-plate")
    field.text = "10000"
    fire(field, defines.events.on_gui_text_changed)
    line = status_entry("upl-message-1")
    assert(line and line[3][1] == "upl-message.request-too-big",
      "no too-big warning after a row edit: " .. serpent.line(line))
    assert(field.valid, "the row's refresh rebuilt the rows under the cursor")
    field.text = ""
    fire(field, defines.events.on_gui_confirmed)
    assert(status_entry("upl-message-1") == nil, "the warning outlived the override")
  end)

  test("the productivity picker defaults with the pair, and snaps back", function()
    open_with_gears()
    assert(choices().productivity_module == "productivity-module-3",
      "gears should default the split's module to prod-3, got "
      .. tostring(choices().productivity_module))
    local function picker()
      return widget({ "upl-options", "upl-split-content", "upl-split-table", "upl-productivity-module" })
    end
    assert(picker().elem_value and picker().elem_value.name == "productivity-module-3",
      "the picker does not show the default")

    -- The belt's rule: emptied snaps back to the default, visibly -- through the refill a
    -- rates change runs on the Modules tab.
    local button = picker()
    button.elem_value = nil
    fire(button)
    assert(choices().productivity_module == "productivity-module-3", "clearing did not snap back")
    assert(picker().elem_value.name == "productivity-module-3", "the snap-back is not shown")
  end)

  test("the mix stands only where productivity can mix", function()
    gui.open(player())
    open_tab("modules")
    assert(maybe_widget({ "upl-options", "upl-split-enabled" }) == nil,
      "no recipe picked, yet the mix shows")
    open_with_gears()
    assert(maybe_widget({ "upl-options", "upl-split-enabled" }) ~= nil,
      "gears take productivity, yet the mix hides")

    -- A recipe that refuses productivity takes the whole mix away -- the checkbox, the
    -- productivity picker and the counts -- and leaves its module empty, Place enabled.
    local recipe_button = widget({ "upl-content", "upl-table", "upl-recipe" })
    recipe_button.elem_value = "wooden-chest"
    fire(recipe_button)
    assert(maybe_widget({ "upl-options", "upl-split-enabled" }) == nil,
      "a productivity-refusing recipe kept the mix on display")
    assert(split_section() == nil, "a productivity-refusing recipe kept the ratio rows")
    assert(choices().productivity_module == nil,
      "a refusing recipe left " .. tostring(choices().productivity_module) .. " in choices")
    assert(widget({ "upl-buttons", "upl-confirm" }).enabled,
      "a productivity-refusing recipe disabled Place")
  end)

  test("the mix checkbox starts on, and an untick takes the counts away", function()
    open_with_gears()
    local box = widget({ "upl-options", "upl-split-enabled" })
    assert(box.state == true, "the mix must start on")
    assert(split_section() ~= nil, "a ticked mix must show its counts")

    box.state = false
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().split_enabled == false, "the untick did not reach the choices")
    assert(split_section() == nil, "unticking left the counts standing")
    -- The refill replaced the checkbox; the new one reads the untick.
    box = widget({ "upl-options", "upl-split-enabled" })
    assert(box.state == false, "the refilled checkbox lost the untick")

    box.state = true
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().split_enabled == true, "the re-tick did not land")
    assert(split_section() ~= nil, "the re-tick did not bring the counts back")
  end)

  test("the ratio rows open at the computed optimum and store nothing", function()
    open_with_gears()
    -- Gears at normal modules: the computed optimum is all-quality, shown as 0 productivity
    -- slots per lower tier -- and NOTHING stored, the ingredient amounts' rule.
    for _, tier in pairs({ "normal", "uncommon" }) do
      assert(split_field(tier).text == "0", tier .. " opened as " .. split_field(tier).text)
      assert(choices()["split_prod_" .. tier] == nil,
        "building the rows stored an override for " .. tier)
    end
    -- The target tier has no row -- its machine is the final machine module's business -- and
    -- at full research the untouched target defaults to the top of the chain.
    assert(choices().quality == "legendary", "test premise: the default target moved")
    local list = split_section()["upl-split-list"]
    assert(list["upl-split-row-epic"], "the tier below the target lost its row")
    assert(list["upl-split-row-legendary"] == nil, "the target tier grew a ratio row")
  end)

  test("typing a ratio moves the yield line without waiting for Enter", function()
    -- The field commits every keystroke, and clicking to the next field never fires a
    -- confirm -- so if only Enter repainted, a player typing through the rows would watch
    -- the stats sit still while the plan underneath already changed (reported 2026-08-28).
    open_with_gears()
    local field = split_field("normal")
    local before = yield_entry()
    assert(before, "a valid plan must carry the yield line")

    field.text = "4"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices().split_prod_normal == 4, "the keystroke did not commit")
    assert(field.valid, "the keystroke repaint tore down the field under the cursor")
    local after = yield_entry()
    assert(after, "the yield line vanished mid-type")
    assert(after[2] ~= before[2],
      "the override is live but the yield line still shows " .. tostring(after[2]))
  end)

  test("a ratio override commits, clamps, resets on empty Enter, and moves the yield line", function()
    open_with_gears()
    local field = split_field("normal")
    local before = yield_entry()
    assert(before, "a valid plan must carry the yield line")

    field.text = "2"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices().split_prod_normal == 2, "the keystroke did not commit")
    assert(field.valid, "the keystroke rebuilt the modal under the cursor")

    -- Enter refreshes -- the ratio is a number the status line follows -- and the field must
    -- survive its own commit.
    fire(field, defines.events.on_gui_confirmed)
    assert(field.valid, "Enter rebuilt the rows under the cursor")
    local after = yield_entry()
    assert(after, "the yield line vanished on an override")
    assert(after[2] ~= before[2],
      "forcing half the slots to productivity left the yield at " .. tostring(after[2]))

    -- Over the slot count clamps; empty plus Enter deletes the override and shows the
    -- optimum again.
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

  test("the ratio rows follow the target and the modules", function()
    open_with_gears()
    open_tab("modules")
    -- A target change reshapes the rows in place: the drop-down that asked stands.
    local dropdown = widget({ "upl-content", "upl-table", "upl-quality" })
    dropdown.selected_index = 1 -- uncommon
    fire(dropdown, defines.events.on_gui_selection_state_changed)
    assert(dropdown.valid, "the target change rebuilt the modal")
    assert(split_field("normal"), "the rows lost the tier the new target keeps")
    assert(split_section()["upl-split-list"]["upl-split-row-uncommon"] == nil,
      "the rows list the new target as a lower tier")

    -- A quality-module change refills the rows to fresh defaults rather than stale ones.
    local before = split_field("normal")
    local module_button = widget({ "upl-options", "upl-modules-table", "upl-quality-module" })
    module_button.elem_value = { name = "quality-module-2", quality = "normal" }
    fire(module_button)
    assert(not before.valid, "a module change left the ratio rows as they were")
    assert(split_field("normal"), "the module change lost the rows")
  end)

  test("with no productivity module researched, the mix says so in words", function()
    -- The pair can mix -- gears take productivity -- but nothing is researched to mix in, so
    -- the section shows the honestly empty picker and a sentence, never rows of dead zeroes.
    local force = player().force
    research.only(force, { "recycling", "quality-module", "automation" })
    choices().recipe = "iron-gear-wheel"
    choices().machine = "assembling-machine-3"
    gui.open(player())
    local section = split_section()
    local has_list = section and section["upl-split-list"] ~= nil
    local sentence = section and section["upl-hint"]
    local picked = section and section["upl-split-table"]["upl-productivity-module"].elem_value
    research.full(force)
    player().set_shortcut_available(gui.SHORTCUT, true)
    assert(section, "the mix section is missing for a pair that can mix")
    assert(not has_list, "rows stood with nothing to mix in")
    assert(sentence and sentence.caption[1] == "upl-gui.split-no-productivity",
      "the nothing-mixes sentence is missing")
    assert(picked == nil, "the picker shows a module nobody has researched")
  end)

  test("clearing the item leaves the amounts standing on the pick-a-recipe hint", function()
    open_with_gears()
    local button = widget({ "upl-content", "upl-table", "upl-recipe" })
    button.elem_value = nil
    fire(button)
    assert(choices().recipe == nil, "premise: the clear landed")
    assert(ingredients_content()["upl-ingredients-list"] == nil,
      "recipe-less amounts still list ingredient rows")
    local sentence = ingredients_content()["upl-hint"]
    assert(sentence and sentence.caption[1] == "upl-gui.pick-a-recipe",
      "the pick-a-recipe hint is missing")
  end)

  test("the column rows stand inline, one each by default, nothing stored", function()
    gui.open(player())
    -- No item needed: the rows follow the target, which the first open defaults.
    assert(choices().quality == "legendary", "test premise: the default target moved")
    for _, tier in pairs({ "normal", "uncommon", "rare", "epic" }) do
      assert(columns_field(tier).text == "1", tier .. " opened as " .. columns_field(tier).text)
      assert(choices()["column_count_" .. tier] == nil,
        "building the rows stored a count for " .. tier)
    end
    local content = columns_content()
    assert(content["upl-columns-list"]["upl-columns-row-legendary"] == nil,
      "the target tier grew a columns row")
    -- A caption and the rows, nothing else: the balanced-counts line and its one-click write
    -- went at the owner's ask (2026-08-29), and must not creep back.
    assert(content["upl-columns-label"] and #content.children == 2,
      "the columns section holds " .. #content.children .. " children")
  end)

  test("typing a count moves the counts line without waiting for Enter", function()
    open_with_gears()
    local field = columns_field("normal")
    local before = layout_entry()
    assert(before, "a valid plan must carry the counts line")

    field.text = "3"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices().column_count_normal == 3, "the keystroke did not commit")
    assert(field.valid, "the keystroke repaint tore down the field under the cursor")
    local after = layout_entry()
    assert(after, "the counts line vanished mid-type")
    assert(after[2] ~= before[2],
      "three normal columns but the machine count still shows " .. tostring(after[2]))
  end)

  test("a count clamps at the ceiling and an empty Enter returns to one", function()
    open_with_gears()
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

  test("the column rows follow the target in place", function()
    open_with_gears()
    open_tab("buildings")
    local dropdown = widget({ "upl-content", "upl-table", "upl-quality" })
    dropdown.selected_index = 1 -- uncommon
    fire(dropdown, defines.events.on_gui_selection_state_changed)
    assert(dropdown.valid, "the target change rebuilt the modal")
    assert(columns_field("normal"), "the rows lost the tier the new target keeps")
    assert(columns_content()["upl-columns-list"]["upl-columns-row-uncommon"] == nil,
      "the rows list the new target as a lower tier")
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
    -- Fetched first: reaching the Chests tab is itself an interaction, which would clear the
    -- presumption before the trash click had to.
    local trash = widget({ "upl-options", "upl-trash" })
    fire(widget({ "upl-content", "upl-table", "upl-machine" }), defines.events.on_gui_click)
    fire(trash, defines.events.on_gui_click)
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
  -- technology unlock manages, so the gate is proven without depending on how the engine maps
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

  test("with only the official expansions loaded, the gate resolves to recycling", function()
    -- The scan on real data. It cannot see the wiring -- shortcut.lua's own default is the same
    -- answer -- which the hand-built runs of analysis/api.md S35 proved instead; the modded
    -- shapes that move the gate are tests/pure/gate_spec.lua's.
    local tech = prototypes.shortcut[gui.SHORTCUT].technology_to_unlock
    assert(tech and tech.name == "recycling", "the gate resolved to " .. tostring(tech and tech.name))
  end)

  test("a configuration change opens a gate that stands researched, and never closes one", function()
    player().set_shortcut_available(gui.SHORTCUT, false)
    gui.unlock_shortcut(player())
    assert(player().is_shortcut_available(gui.SHORTCUT), "a researched gate stayed shut")

    research.fresh(player().force)
    player().set_shortcut_available(gui.SHORTCUT, false)
    gui.unlock_shortcut(player())
    assert(not player().is_shortcut_available(gui.SHORTCUT), "an unresearched gate was opened")

    player().set_shortcut_available(gui.SHORTCUT, true)
    gui.unlock_shortcut(player())
    assert(player().is_shortcut_available(gui.SHORTCUT), "the unlock closed an open shortcut")
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

tags("gui")
describe("the tabs and the layout", function()
  before_all(function()
    assert(#game.connected_players > 0, "gui specs need a connected player")
    research.full(player().force)
  end)

  after_each(function()
    gui.close(player())
    player().clear_cursor()
    state.forget(player().index)
  end)

  local function pane()
    return widget({ "upl-options" })
  end

  local function pick_layout(index)
    local dropdown = widget({ "upl-content", "upl-table", "upl-layout" })
    dropdown.selected_index = index
    fire(dropdown, defines.events.on_gui_selection_state_changed)
  end

  test("the tab event reaches the dispatcher", function()
    assert(script.get_event_handler(defines.events.on_gui_selected_tab_changed) ~= nil,
      "nothing listens for a tab change: the selection would never be remembered")
  end)

  test("the chosen tab survives a rebuild, and a close and reopen", function()
    open_with_gears()
    open_tab("chests")
    assert(state.of(player().index).tab == "chests", "the selection was not remembered")
    -- A machine pick rebuilds the modal from scratch.
    local machine = widget({ "upl-content", "upl-table", "upl-machine" })
    machine.elem_value = { name = "assembling-machine-2", quality = "normal" }
    fire(machine)
    assert(not machine.valid, "test premise: a machine pick rebuilds the modal")
    assert(pane().selected_tab_index == 3, "a rebuild went back to the first tab")
    gui.close(player())
    gui.open(player())
    assert(pane().selected_tab_index == 3, "reopening went back to the first tab")
    open_tab("circuits")
    gui.open(player())
    assert(pane().selected_tab_index == 4, "the Circuits tab did not stick")
    -- And the remembered tab is the one filled on the way back in.
    assert(#pane()["upl-tab-circuits"].children > 0, "the reopened tab stands empty")
  end)

  test("only the picked tab holds anything, and a switch fills the new one in place", function()
    -- A tabbed pane sizes to its tallest tab, so a short tab built beside tall ones sat over
    -- a band of blank space (owner's screenshot, 2026-11-27): the empty tabs are the fix.
    open_with_gears()
    local p = pane()
    local function filled()
      local names = {}
      for _, key in pairs({ "buildings", "modules", "chests", "circuits" }) do
        if #p["upl-tab-" .. key].children > 0 then names[#names + 1] = key end
      end
      return table.concat(names, ",")
    end
    assert(filled() == "buildings", "filled on open: " .. filled())
    local top = widget({ "upl-content", "upl-table", "upl-recipe" })
    for _, key in pairs({ "modules", "chests", "circuits", "buildings" }) do
      open_tab(key)
      assert(filled() == key, "after picking " .. key .. ", filled: " .. filled())
    end
    -- In place: the top block and the pane itself stand through every switch.
    assert(top.valid and p.valid, "a tab switch rebuilt the modal")
    -- A click on the pane itself fills nothing anew: the tab it shows is already standing.
    local table_before = widget({ "upl-options", "upl-buildings-table" })
    fire(p, defines.events.on_gui_click)
    assert(table_before.valid, "a click on the pane refilled the standing tab")
  end)

  test("a tab switch plans nothing again: the status lines stand as they were", function()
    -- A switch changes no choice the plan reads, and a huge layout takes seconds to plan.
    open_with_gears()
    local line = widget({ "upl-status", "upl-stat-layout" })
    for _, key in pairs({ "modules", "chests", "circuits", "buildings" }) do
      open_tab(key)
      assert(line.valid, "switching to " .. key .. " re-planned the loop")
    end
  end)

  -- Every pick that moves the solve refills the Modules tab in place, so the ratio rows reopen
  -- at the new optimum: the beacon pickers once shipped refresh-only (TAB_BUILDERS' comment).
  for _, case in pairs({
    { key = "beacon-count", event = defines.events.on_gui_selection_state_changed,
      set = function(e) e.selected_index = 2 end },
    { key = "beacon-module",
      set = function(e) e.elem_value = { name = "efficiency-module", quality = "normal" } end },
    { key = "terminal-module",
      set = function(e) e.elem_value = { name = "productivity-module-2", quality = "normal" } end },
  }) do
    test("a " .. case.key .. " pick refills the ratio rows, and only the tab", function()
      open_with_gears()
      local beacon = widget({ "upl-options", "upl-modules-table", "upl-beacon" })
      beacon.elem_value = { name = "beacon", quality = "normal" }
      fire(beacon)
      local before = split_field("normal")
      local top = widget({ "upl-content", "upl-table", "upl-recipe" })
      local control = widget({ "upl-options", "upl-modules-table", "upl-" .. case.key })
      case.set(control)
      fire(control, case.event)
      assert(not before.valid, "the " .. case.key .. " pick left the ratio rows as they were")
      assert(top.valid, "the " .. case.key .. " pick rebuilt the whole modal")
      assert(split_field("normal"), "the refill lost the ratio rows")
    end)
  end

  test("a productivity-module pick refills the ratio rows, and only the tab", function()
    open_with_gears()
    local before = split_field("normal")
    local top = widget({ "upl-content", "upl-table", "upl-recipe" })
    local picker = split_section()["upl-split-table"]["upl-productivity-module"]
    picker.elem_value = { name = "productivity-module-2", quality = "normal" }
    fire(picker)
    assert(choices().productivity_module == "productivity-module-2", "the pick did not take")
    assert(not before.valid, "the pick left the ratio rows as they were")
    assert(top.valid, "the pick rebuilt the whole modal")
  end)

  test("the overflow row follows what the loop builds: the target and the layout", function()
    open_with_gears()
    local function overflow_shown()
      return widget({ "upl-options", "upl-chests-table", "upl-overflow" }).visible
    end
    assert(overflow_shown() == false, "a legendary belt ring stands no overflow chest")
    -- The target moves with the Chests tab open, and the tab is refilled for it.
    local dropdown = widget({ "upl-content", "upl-table", "upl-quality" })
    local epic
    for index, name in pairs(dropdown.tags.targets) do
      if name == "epic" then epic = index end
    end
    dropdown.selected_index = epic
    fire(dropdown, defines.events.on_gui_selection_state_changed)
    assert(overflow_shown() == true, "an epic belt ring taps legendary rolls into its overflow chest")
    dropdown.selected_index = #dropdown.tags.targets
    fire(dropdown, defines.events.on_gui_selection_state_changed)
    assert(overflow_shown() == false, "back at legendary, the overflow row stayed")
    pick_layout(2)
    assert(overflow_shown() == true, "a bot loop hands every tier on through overflow chests")
  end)

  test("a beacon count survives a trip to Bots and back", function()
    -- The bot loop's column stacks one fewer vanilla beacon than the ring's: shown clamped
    -- there, never stored clamped.
    open_with_gears()
    local beacon = widget({ "upl-options", "upl-modules-table", "upl-beacon" })
    beacon.elem_value = { name = "beacon", quality = "normal" }
    fire(beacon)
    local count = widget({ "upl-options", "upl-modules-table", "upl-beacon-count" })
    local max_belt = #count.items
    count.selected_index = max_belt
    fire(count, defines.events.on_gui_selection_state_changed)
    pick_layout(2)
    local on_bots = widget({ "upl-options", "upl-modules-table", "upl-beacon-count" })
    assert(#on_bots.items < max_belt, "test premise: bots stack fewer beacons")
    assert(on_bots.selected_index == #on_bots.items, "bots must show the count clamped to their max")
    pick_layout(1)
    assert(choices().beacon_count == max_belt, "the trip cost the belt plan a beacon: "
      .. tostring(choices().beacon_count))
    assert(widget({ "upl-options", "upl-modules-table", "upl-beacon-count" }).selected_index == max_belt,
      "belts came back showing fewer beacons")
  end)

  test("clicking an empty module picker after research finishes is a browse, not a refill", function()
    -- Opened before any quality module was researched, the picker stands empty; a click on it
    -- once research lands must open the chooser, not fill a default and refill the tab -- which
    -- took the chooser down with the picker and left the next E swallowed.
    local force = player().force
    research.only(force, { "recycling", "automation" })
    choices().recipe = "iron-gear-wheel"
    choices().machine = "assembling-machine-2"
    gui.open(player())
    local picker = widget({ "upl-options", "upl-modules-table", "upl-quality-module" })
    local empty = picker.elem_value == nil and choices().quality_module == nil
    research.full(force)
    player().set_shortcut_available(gui.SHORTCUT, true)
    assert(empty, "test premise: no quality module was researched at open")
    fire(picker, defines.events.on_gui_click)
    assert(picker.valid, "a click on the empty picker refilled the tab under the chooser")
    assert(choices().quality_module == nil, "a browse click wrote a module")
  end)

  local function pick_machine_2()
    local machine = widget({ "upl-content", "upl-table", "upl-machine" })
    machine.elem_value = { name = "assembling-machine-2", quality = "normal" }
    fire(machine)
  end

  test("a window the player never moved re-centres after every change of size", function()
    -- The engine neither re-centres a frame whose content grew nor keeps one on screen, so a
    -- tall tab grown from a short one's centred spot ran past the bottom (S38). Every change
    -- of size asks for the centring again, and the engine's report of each centring pins the
    -- window where it landed -- never read as a drag, or the next change would not re-centre.
    open_with_gears()
    assert(frame().auto_center == true, "test premise: the planner opens centring")
    engine_centres()
    assert(frame().auto_center == false, "the engine's centring was not pinned where it landed")
    -- Someone else's screen frame moving is no drag of ours.
    local other = player().gui.screen.add({ type = "frame", name = "upl-spec-other-frame" })
    raise(defines.events.on_gui_location_changed, { element = other })
    other.destroy()
    local changes = {
      { "a tab switch", function() open_tab("chests") end },
      { "opening the settings panel", function() gui.open_settings(player()) end },
      { "closing the settings panel", function()
        assert(gui.close_settings(player()) == true, "closing an open panel must say it closed one")
      end },
      { "a rebuild", pick_machine_2 },
    }
    for _, change in ipairs(changes) do
      change[2]()
      assert(frame().auto_center == true, change[1] .. " did not re-centre an unmoved window")
      engine_centres()
      assert(frame().auto_center == false, "the centring after " .. change[1] .. " was not pinned")
    end
    assert(gui.close_settings(player()) == false, "closing no panel must say so")
  end)

  test("a window the player dragged stays where they dropped it, through every change", function()
    -- The owner's report on 2.0.0: move the window, change a setting, and it jumps back to the
    -- centre. 2.0.0 read auto_center as "never moved", and a drag leaves the flag on.
    open_with_gears()
    engine_centres()
    drag_to(40, 60)
    local function stays(what)
      local at = frame().location
      assert(frame().auto_center == false and at.x == 40 and at.y == 60,
        what .. " moved the window to " .. serpent.line(at))
    end
    stays("the drag itself")
    open_tab("chests")
    stays("a tab switch")
    gui.open_settings(player())
    stays("opening the settings panel")
    pick_machine_2()
    stays("a rebuild")
    -- The owner's own steps: the setting, ticked in the panel. The rebuild comes through
    -- on_runtime_mod_setting_changed, a tick or so later.
    local box = settings_widget(SHOW_ALL_BOX)
    box.state = true
    fire(box, defines.events.on_gui_checked_state_changed)
    after_ticks(2, function()
      assert(player().mod_settings[gui.SHOW_ALL_SETTING].value == true, "the tick never landed")
      stays("flipping the setting")
      assert(gui.close_settings(player()) == true, "the rebuild dropped the settings panel")
      stays("closing the settings panel")
      player().mod_settings[gui.SHOW_ALL_SETTING] = { value = false }
      after_ticks(2, function()
        stays("flipping the setting back from outside the window")
        -- Closed and opened again, the window starts over centred.
        gui.close(player())
        gui.open(player())
        assert(frame().auto_center == true, "a fresh open kept the last window's drag")
      end)
    end)
  end)

  test("a new resolution or UI scale re-centres even a moved window", function()
    -- A pinned window no longer follows the screen the way an auto-centring one did, and the
    -- old spot can lie off the new screen.
    for _, id in ipairs({ defines.events.on_player_display_resolution_changed,
      defines.events.on_player_display_scale_changed }) do
      open_with_gears()
      engine_centres()
      drag_to(40, 60)
      raise(id, {})
      assert(frame().auto_center == true, "a display change left a moved window where it was")
      engine_centres()
      gui.open_settings(player())
      assert(frame().auto_center == true, "after a display change the window stayed moved")
      gui.close(player())
    end
  end)

  test("in a real client, each centring lands as an event and is pinned there", function()
    -- The specs above raise the engine's event themselves; this one waits for the engine. Only
    -- a client lays frames out -- a headless run leaves every frame at 0,0 and raises nothing
    -- -- so a bare frame of the spec's own tells the two tiers apart, whatever the planner
    -- does. Measured on the way in: laid out and pinned within one tick at speed 1.
    local bare = player().gui.screen.add({ type = "frame", name = "upl-spec-layout-probe" })
    bare.auto_center = true
    open_with_gears()
    after_drawn_ticks(10, function()
      local client = bare.location.x ~= 0 or bare.location.y ~= 0
      bare.destroy()
      if not client then return end
      local alone = frame().location
      assert(frame().auto_center == false and (alone.x ~= 0 or alone.y ~= 0),
        "the opening centring was not pinned where it landed: " .. serpent.line(alone))
      gui.open_settings(player())
      after_drawn_ticks(10, function()
        local pair = frame().location
        assert(frame().auto_center == false, "the panel's re-centre was left auto-centring")
        assert(pair.x < alone.x, "the wider pair did not re-centre: from " .. serpent.line(alone)
          .. " to " .. serpent.line(pair))
      end)
    end)
  end)

  test("a kept tab nobody knows reads as the first", function()
    for _, junk in pairs({ "bogus", 7 }) do
      state.of(player().index).tab = junk
      gui.open(player())
      assert(pane().selected_tab_index == 1, "a junk tab " .. tostring(junk) .. " opened tab "
        .. tostring(pane().selected_tab_index))
    end
  end)

  test("the layout row: belts by default, bots stored as bot, belts stored as nothing", function()
    gui.open(player())
    local dropdown = widget({ "upl-content", "upl-table", "upl-layout" })
    assert(dropdown.selected_index == 1, "the layout did not open on belts")
    widget({ "upl-content", "upl-table", "upl-layout-label" })
    pick_layout(2)
    assert(choices().layout == "bot", "picking bots stored " .. tostring(choices().layout))
    assert(not dropdown.valid, "a layout change must rebuild the modal")
    assert(widget({ "upl-content", "upl-table", "upl-layout" }).selected_index == 2,
      "the rebuild forgot bots")
    pick_layout(1)
    assert(choices().layout == nil, "belts must store nothing, got " .. tostring(choices().layout))
  end)

  test("re-stating the layout rebuilds nothing", function()
    gui.open(player())
    local dropdown = widget({ "upl-content", "upl-table", "upl-layout" })
    fire(dropdown, defines.events.on_gui_click)
    assert(dropdown.valid, "a click on the unchanged layout rebuilt the modal")
  end)

  test("with bots: no belt, no relay chest, no request boxes, the network box ticked and greyed", function()
    open_with_gears()
    choices().stock_requests = false
    choices().circuit_network = false
    pick_layout(2)
    assert(widget({ "upl-options", "upl-buildings-table", "upl-belt" }).visible == false,
      "the belt picker stayed with bots")
    assert(widget({ "upl-options", "upl-chests-table", "upl-container" }).visible == false,
      "the relay chest stayed with bots")
    for _, name in pairs({ "upl-stock-requests", "upl-terminal-requests" }) do
      assert(widget({ "upl-options", name }).visible == false, name .. " stayed with bots")
    end
    local network = widget({ "upl-options", "upl-circuits-content", "upl-circuit-network" })
    assert(network.state == true and network.enabled == false,
      "the network box must read ticked and greyed with bots")
    -- Nothing was written over the player's own ticks: belts get them back.
    assert(choices().stock_requests == false and choices().circuit_network == false,
      "bots overwrote the stored ticks")
    -- What bots still build stands: the inserter, the other four chests.
    assert(widget({ "upl-options", "upl-buildings-table", "upl-inserter" }).visible == true,
      "the inserter went with the belt")
    for _, role in pairs({ "requester", "stock", "provider", "overflow" }) do
      assert(widget({ "upl-options", "upl-chests-table", "upl-" .. role }).visible == true,
        role .. " went with bots")
    end
    pick_layout(1)
    assert(widget({ "upl-options", "upl-buildings-table", "upl-belt" }).visible == true,
      "belts lost the belt picker")
    assert(widget({ "upl-options", "upl-stock-requests" }).state == false,
      "belts lost the player's own untick")
  end)

  test("Place with bots hands over a loop without a single belt", function()
    open_with_gears()
    pick_layout(2)
    fire(widget({ "upl-buttons", "upl-confirm" }), defines.events.on_gui_click)
    local stack = player().cursor_stack
    assert(stack and stack.valid_for_read and stack.is_blueprint, "Place gave no blueprint")
    local belts, entities = 0, stack.get_blueprint_entities() or {}
    for _, e in pairs(entities) do
      if prototypes.entity[e.name].type == "transport-belt" then belts = belts + 1 end
    end
    assert(#entities > 0 and belts == 0, "the bot blueprint carries " .. belts .. " belts")
  end)
end)
