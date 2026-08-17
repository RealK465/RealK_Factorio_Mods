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
    widget({ "upl-options", "upl-strip", "upl-quality-module" })
    widget({ "upl-options", "upl-strip", "upl-pole" })
    widget({ "upl-options", "upl-strip", "upl-pipe" })
    assert(widget({ "upl-options", "upl-trash" }).state == true, "trash defaults checked")

    local c = choices()
    assert(c.recycler == "recycler", "recycler default " .. tostring(c.recycler))
    assert(c.quality == "legendary", "target defaults to the highest offered")
    assert(c.belt == "turbo-transport-belt", "belt default " .. tostring(c.belt))
    assert(c.quality_module == "quality-module-3", "module default " .. tostring(c.quality_module))
    assert(c.pole == "medium-electric-pole", "pole default " .. tostring(c.pole))
    assert(c.pipe == "pipe", "pipe default " .. tostring(c.pipe))

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
    local button = widget({ "upl-content", "upl-table", "upl-machine" })
    button.elem_value = { name = "assembling-machine-2", quality = "rare" }
    fire(button)
    assert(choices().machine == "assembling-machine-2", "machine pick lost")
    assert(choices().machine_quality == "rare", "machine quality lost on pick")

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
