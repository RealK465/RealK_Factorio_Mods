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
  local element = frame()
  for _, name in pairs(path) do
    element = element[name]
    assert(element, "widget path broke at " .. name)
  end
  return element
end

local function fire(element)
  dispatch.on_gui_event({ element = element, player_index = player().index })
end

local function choices()
  return state.of(player().index).choices
end

-- The settings window is a SECOND frame, so it is reached from gui.screen rather than through
-- widget() above. Element names are spelled out here on purpose: they are the contract a rename
-- has to break loudly.
local SHOW_ALL_BOX = "upl-setting-show-all"
local ALL_OPTIONS_BOX = "upl-setting-show-all-build-options"

local function settings_widget(name)
  local window = player().gui.screen[gui.SETTINGS_FRAME]
  assert(window and window.valid, "the settings window is not open")
  return window["upl-settings-content"][name]
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
    widget({ "upl-options", "upl-strip", "upl-belt" })
    widget({ "upl-options", "upl-strip", "upl-inserter" })
    widget({ "upl-options", "upl-strip", "upl-requester" })
    widget({ "upl-options", "upl-strip", "upl-container" })
    widget({ "upl-options", "upl-strip", "upl-provider" })
    widget({ "upl-options", "upl-strip", "upl-quality-module" })
    widget({ "upl-options", "upl-strip", "upl-terminal-module" })
    widget({ "upl-options", "upl-strip", "upl-pole" })
    widget({ "upl-options", "upl-strip", "upl-pipe" })
    assert(widget({ "upl-options", "upl-trash" }).state == true, "trash defaults checked")

    -- Six per row, and a hidden picker takes no cell with it -- measured in a real client, where
    -- six of nine visible came out one row and all nine came out two (analysis/api.md S19). Only
    -- the column count is assertable here; a headless run never lays the frame out, so nothing
    -- about geometry or screen position can be checked from a spec.
    assert(widget({ "upl-options", "upl-strip" }).column_count == 6,
      "the build options grid must stay six wide")

    -- One option is not a choice. In the SA modset that hides four pickers: one recycler, one
    -- requester chest, one passive provider and one pipe. Every one of them is still BUILT, and
    -- still holds the default the plan uses -- only the widget is gone. The counts are asserted
    -- through the planner so a modset that adds an alternative fails here loudly rather than
    -- quietly showing a picker this spec claims is hidden.
    assert(#planner.recyclers() == 1, "test premise: SA ships exactly one recycler")
    assert(#planner.chests("requester") == 1, "test premise: one requester chest")
    assert(#planner.chests("provider") == 1, "test premise: one passive provider")
    assert(#planner.pipes() == 1, "test premise: one pipe")
    assert(widget({ "upl-content", "upl-table", "upl-recycler" }).visible == false,
      "the recycler picker is the only recycler there is -- it must be hidden")
    -- The row's LABEL has to go with it; an orphaned label is the obvious way to get this wrong.
    assert(widget({ "upl-content", "upl-table", "upl-recycler-label" }).visible == false,
      "the recycler label outlived its row")
    assert(widget({ "upl-options", "upl-strip", "upl-requester" }).visible == false,
      "one requester chest is not a choice")
    assert(widget({ "upl-options", "upl-strip", "upl-provider" }).visible == false,
      "one passive provider is not a choice")
    assert(widget({ "upl-options", "upl-strip", "upl-pipe" }).visible == false,
      "no recipe and one pipe: the pipe picker must be hidden twice over")

    -- And what stays: three plain chests, three usable inserters, four belts, and the two whose
    -- clear is itself the second option.
    assert(#planner.chests("container") > 1 and #planner.inserters() > 1,
      "test premise: buffer chests and inserters have real alternatives")
    for _, name in pairs({ "upl-belt", "upl-inserter", "upl-container", "upl-quality-module",
                           "upl-terminal-module", "upl-pole" }) do
      assert(widget({ "upl-options", "upl-strip", name }).visible == true,
        name .. " must stay visible")
    end
    for _, name in pairs({ "upl-recipe", "upl-quality", "upl-machine" }) do
      assert(widget({ "upl-content", "upl-table", name }).visible == true,
        name .. " must stay visible whatever the count")
    end

    local c = choices()
    assert(c.recycler == "recycler", "recycler default " .. tostring(c.recycler))
    assert(c.quality == "legendary", "target defaults to the highest offered")
    assert(c.belt == "turbo-transport-belt", "belt default " .. tostring(c.belt))
    assert(c.quality_module == "quality-module-3", "module default " .. tostring(c.quality_module))
    assert(c.pole == "medium-electric-pole", "pole default " .. tostring(c.pole))
    assert(c.pipe == "pipe", "pipe default " .. tostring(c.pipe))
    -- Bulk beats speed in the scoring, and the belt-stacking one is not a candidate at all.
    assert(c.inserter == "bulk-inserter", "inserter default " .. tostring(c.inserter))
    assert(c.requester == "requester-chest", "requester default " .. tostring(c.requester))
    assert(c.container == "steel-chest", "buffer chest default " .. tostring(c.container))
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
    local button = widget({ "upl-options", "upl-strip", "upl-belt" })
    button.elem_value = nil
    fire(button)
    assert(choices().belt == "turbo-transport-belt", "belt did not snap back")
    assert(button.elem_value == "turbo-transport-belt", "snap-back not shown on the strip")
  end)

  test("clearing the pipe snaps back like the belt -- a fluid plan cannot go without one", function()
    open_with_gears()
    local button = widget({ "upl-options", "upl-strip", "upl-pipe" })
    button.elem_value = nil
    fire(button)
    assert(choices().pipe == "pipe", "pipe did not snap back")
    assert(button.elem_value == "pipe", "snap-back not shown on the strip")
  end)

  test("clearing the pole means no poles -- the one picker that stays empty", function()
    open_with_gears()
    local button = widget({ "upl-options", "upl-strip", "upl-pole" })
    button.elem_value = nil
    fire(button)
    assert(choices().no_poles == true, "cleared pole picker did not record the choice")
    assert(choices().pole == nil, "pole name survived the clear")

    button.elem_value = { name = "medium-electric-pole", quality = "normal" }
    fire(button)
    assert(choices().no_poles == false, "re-picking a pole did not clear no_poles")
  end)

  test("clearing the inserter snaps back to the best researched, visibly", function()
    open_with_gears()
    local button = widget({ "upl-options", "upl-strip", "upl-inserter" })
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
    -- The buffer role is the one with a real choice in vanilla (wooden, iron, steel), which is
    -- what makes it the honest one to drive through the shared handler.
    open_with_gears()
    local button = widget({ "upl-options", "upl-strip", "upl-container" })
    button.elem_value = { name = "iron-chest", quality = "uncommon" }
    fire(button)
    assert(choices().container == "iron-chest", "buffer pick lost")
    assert(choices().container_quality == "uncommon", "buffer quality lost on pick")
    -- One handler serves all three buttons, so the role in the tags is load-bearing: a write
    -- that reached a sibling role would silently swap the wrong chest.
    assert(choices().requester == "requester-chest", "the requester role was overwritten")
    assert(choices().provider == "passive-provider-chest", "the provider role was overwritten")

    button.elem_value = nil
    fire(button)
    assert(choices().container == "steel-chest", "buffer did not snap back to the largest")
    local shown = button.elem_value
    assert(shown and shown.name == "steel-chest", "snap-back not shown on the strip")
  end)

  test("a recipe the chosen inserter cannot filter re-picks it, like the machine", function()
    -- Filter slots are needed one per ingredient: fusion reactor equipment takes six and every
    -- vanilla inserter carries five, so the modal must not leave behind a pick that cannot
    -- serve the new recipe.
    open_with_gears()
    local inserter = widget({ "upl-options", "upl-strip", "upl-inserter" })
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
      return widget({ "upl-options", "upl-strip", "upl-terminal-module" })
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
    local pipe = widget({ "upl-options", "upl-strip", "upl-pipe" })
    assert(pipe.visible == false, "gears take no fluid: the pipe picker must be hidden")

    local recipe_button = widget({ "upl-content", "upl-table", "upl-recipe" })
    recipe_button.elem_value = "battery"
    fire(recipe_button)
    assert(choices().recipe == "battery", "test setup: the battery recipe did not take")
    -- The plan still builds pipes -- the picker being hidden never means the default is not used.
    assert(choices().pipe == "pipe", "the pipe default must stand behind the hidden picker")
    -- Re-fetched: the recipe handler rebuilds the modal, so the reference above is stale.
    assert(widget({ "upl-options", "upl-strip", "upl-pipe" }).visible == (#planner.pipes() > 1),
      "with one pipe in the game the picker stays hidden; with more it must appear")
  end)

  test("the settings button opens a window beside the modal, without closing it", function()
    gui.open(player())
    local modal = frame()
    -- A captioned button rather than a glyph, so the titlebar says what it opens. Pinned because
    -- the difference is invisible to every other assertion in this file.
    local button = widget({ "upl-titlebar", "upl-settings-button" })
    assert(button.type == "button", "the settings button must be a text button, not a sprite one")
    assert(button.caption and button.caption[1] == "upl-gui.settings",
      "the settings button lost its caption")
    fire(button)

    local window = player().gui.screen[gui.SETTINGS_FRAME]
    assert(window and window.valid, "the settings button opened nothing")
    -- Both boxes read the SETTINGS, not a private copy -- that is the whole storage decision.
    assert(settings_widget(SHOW_ALL_BOX).state == false, "the show-all box does not read its setting")
    assert(settings_widget(ALL_OPTIONS_BOX).state == false,
      "the build-options box does not read its setting")
    assert(player().opened == window,
      "the window must own player.opened, or Esc would close the modal underneath it")

    -- The measured trap: only one element at a time owns player.opened, so taking it ASKS the
    -- modal to close and control.lua's handler is where that arrives. Without its gui.settings_open
    -- guard the modal is already destroyed by now.
    after_ticks(2, function()
      assert(modal.valid, "the modal was torn down by the settings window taking focus")
      gui.close_settings(player())
      assert(not window.valid, "close_settings left the window standing")
      assert(player().opened == modal,
        "focus was not handed back to the modal, so Esc would do nothing")
    end)
  end)

  test("Esc on the settings window hands the focus back to the modal", function()
    gui.open(player())
    gui.open_settings(player())
    -- Writing nil is exactly what Esc does -- the engine asks whatever holds the focus to close --
    -- so this drives the real on_gui_closed path in control.lua rather than the button's handler.
    player().opened = nil
    after_ticks(2, function()
      assert(not player().gui.screen[gui.SETTINGS_FRAME], "the window survived Esc")
      assert(frame() and frame().valid, "Esc on the window closed the modal behind it")
      assert(player().opened == frame(),
        "the modal did not get the focus back, so Esc would do nothing next time")
    end)
  end)

  test("another GUI taking focus does not drag the planner down with the window", function()
    gui.open(player())
    gui.open_settings(player())
    -- Clicking a chest while the window is up asks the window to close, which lands in the same
    -- on_gui_closed handler as Esc. Reclaiming the focus THERE is what the API warns about:
    -- the engine force-closes whichever GUI it was not asked for, and the modal went with it.
    local surface = player().surface
    local at = surface.find_non_colliding_position("iron-chest", { x = 12, y = 12 }, 32, 1)
    local chest = surface.create_entity({
      name = "iron-chest", position = at, force = player().force,
    })
    assert(chest, "test setup: no chest to open")

    player().opened = chest
    after_ticks(2, function()
      assert(frame() and frame().valid, "opening a chest tore the planner down")
      assert(player().opened == chest, "the planner snatched the focus back from the chest")
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
    fire(recipe_button)
    assert(modal.valid, "clicking the item picker tore the modal down")
    assert(recipe_button.valid, "clicking the item picker destroyed the button under the chooser")
    assert(choices().recipe == "iron-gear-wheel", "the click changed the choice")

    local machine_button = widget({ "upl-content", "upl-table", "upl-machine" })
    local machine = choices().machine
    fire(machine_button)
    assert(machine_button.valid, "clicking the machine picker destroyed the button")
    assert(choices().machine == machine, "the click changed the machine")
  end)

  test("the settings window follows a dragged modal instead of crossing the screen", function()
    -- The window's x is derived from the modal's CENTRED position, and the titlebar makes the
    -- modal draggable, so the derivation is only ever an estimate. Dragged LEFT it overshoots,
    -- and the window used to land against the right edge -- the wrong side of everything.
    local resolution = player().display_resolution.width
    local scale = player().display_scale
    local width = math.floor(400 * scale)

    gui.open(player())
    -- Where auto_center would put a modal this wide: the one position the inference is exact at,
    -- and so the only chance the code gets to learn the width. (Headless never lays a frame out,
    -- so a real auto_center would read 0,0 -- an explicit location is how this is measurable.)
    frame().location = { x = math.floor((resolution - width) / 2), y = 60 }
    gui.open_settings(player())
    local centred_x = player().gui.screen[gui.SETTINGS_FRAME].location.x
    assert(centred_x > 0 and centred_x < resolution,
      "beside a centred modal the window belongs on screen, got " .. centred_x)
    gui.close_settings(player())

    -- Dragged hard left. The remembered width is what keeps the window beside the modal.
    frame().location = { x = 40, y = 60 }
    gui.open_settings(player())
    local dragged_x = player().gui.screen[gui.SETTINGS_FRAME].location.x
    assert(dragged_x < centred_x,
      "dragging the modal left must carry the window left too, got " .. dragged_x)
    assert(dragged_x <= 40 + width + 40,
      "the window must sit beside the modal, not across the screen: " .. dragged_x)
    gui.close_settings(player())

    -- Dragged hard right, where there is no room beside it at all: the window has to stay
    -- reachable rather than being placed past the edge.
    frame().location = { x = resolution - 40, y = 60 }
    gui.open_settings(player())
    assert(player().gui.screen[gui.SETTINGS_FRAME].location.x <= resolution - 240,
      "with no room to the right the window must stay on screen")
  end)

  test("closing the modal takes the settings window with it", function()
    gui.open(player())
    gui.open_settings(player())
    gui.close(player())
    assert(not player().gui.screen[gui.SETTINGS_FRAME], "the window outlived the modal it belongs to")
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
                             { "upl-options", "upl-strip", "upl-requester" },
                             { "upl-options", "upl-strip", "upl-provider" } }) do
        assert(widget(path).visible == true, path[#path] .. " stayed hidden")
      end
      -- The pipe carries a second condition of its own, and the setting overrides that too: no
      -- recipe is chosen here, so nothing except the setting can be showing it.
      assert(widget({ "upl-options", "upl-strip", "upl-pipe" }).visible == true,
        "the pipe must be shown even for no recipe at all")
      -- And it reverses: the same path, from the settings menu's side of the setting.
      player().mod_settings[gui.SHOW_ALL_OPTIONS_SETTING] = { value = false }
      after_ticks(2, function()
        assert(widget({ "upl-options", "upl-strip", "upl-pipe" }).visible == false,
          "unticking the setting must hide the pipe again")
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

  test("Confirm snapshots the choices, hands over the tool, and closes", function()
    open_with_gears()
    fire(widget({ "upl-buttons", "upl-confirm" }))

    local stack = player().cursor_stack
    assert(stack and stack.valid_for_read and stack.name == gui.TOOL,
      "the placement tool is not in the cursor")
    local entry = state.of(player().index)
    assert(entry.pending and entry.pending.recipe == "iron-gear-wheel",
      "Confirm did not arm the snapshot")
    assert(frame() == nil, "the modal stayed open after Confirm")
  end)
end)
