-- gui.lua with a real player: the window's construction, and the handlers driven the honest way
-- -- mutate the REAL widget through the API, then hand dispatch.on_gui_event a hand-shaped event
-- naming it. A singleplayer save's player stays connected under --benchmark, so this runs
-- headless too (Upcycler Planner api.md §12). The click-to-event wiring itself stays untested;
-- no input faking exists.

local gui = require("scripts.gui")
local dispatch = require("scripts.dispatch")
local plan = require("scripts.plan")
local state = require("scripts.state")
local research = require("tests.support.research")

local function player() return game.connected_players[1] end
local function frame() return player().gui.screen[gui.FRAME] end
local function choices() return state.of(player().index).choices end

local function widget(path)
  local element = frame()["apl-main"]
  for _, name in pairs(path) do
    element = element[name]
    assert(element, "widget path broke at " .. name)
  end
  return element
end

local function fire(element, name)
  dispatch.on_gui_event({
    element = element, player_index = player().index,
    name = name or defines.events.on_gui_elem_changed,
  })
end

local ITEM = { "apl-content", "apl-table", "apl-item" }
local MODULE = { "apl-content", "apl-table", "apl-module" }
local INSERTER = { "apl-options", "apl-logistics-strip", "apl-inserter" }
local PIPE = { "apl-options", "apl-logistics-strip", "apl-pipe" }
local SPLIT = { "apl-options", "apl-split" }

local function pick(path, name, quality)
  local element = widget(path)
  element.elem_value = { name = name, quality = quality or "normal" }
  fire(element)
end

local function reset()
  gui.close(player())
  local entry = state.of(player().index)
  entry.choices = {}
  entry.chooser_maybe_open = nil
  player().clear_cursor()
end

describe("the planner window", function()
  before_all(function() research.full(player().force) end)
  after_each(reset)

  test("opens focused, closes, and toggles", function()
    gui.toggle(player())
    assert(frame() and player().opened == frame(), "the window did not open focused")
    assert(widget({ "apl-status", "apl-hint" }), "an empty window should show the hint")
    gui.toggle(player())
    assert(frame() == nil, "the window did not close")
  end)

  test("picking an item fills in what would be placed", function()
    gui.open(player())
    pick(ITEM, "fast-inserter")
    local c = choices()
    assert(c.item == "fast-inserter" and c.machine and c.inserter and c.requester and c.output,
      "the defaults were not written back")
    assert(widget({ "apl-buttons", "apl-confirm" }).enabled, "Place is disabled on a plannable item")
    assert(not widget({ "apl-content", "apl-table", "apl-recipe" }).visible,
      "one recipe makes fast inserters, so the recipe list should hide")
    assert(not widget(PIPE).visible, "fast inserters take no fluid, so the pipe should hide")
  end)

  test("an item with several recipes shows the list, defaulting to the one the machine crafts", function()
    gui.open(player())
    pick({ "apl-content", "apl-table", "apl-machine" }, "assembling-machine-3")
    pick(ITEM, "iron-gear-wheel")
    local list = widget({ "apl-content", "apl-table", "apl-recipe" })
    assert(list.visible, "Space Age's casting recipe makes gears too, so the list should show")
    assert(list.tags.recipes[list.selected_index] == "iron-gear-wheel",
      "an assembler should default to the plate recipe, not casting")
  end)

  test("the click that opens a chooser changes nothing", function()
    gui.open(player())
    pick(ITEM, "iron-gear-wheel")
    local before = frame().index
    fire(widget(ITEM), defines.events.on_gui_click)
    assert(frame().index == before, "a click carrying the same value rebuilt the window")
  end)

  test("an emptied picker that cannot be cleared snaps back", function()
    gui.open(player())
    pick(ITEM, "iron-gear-wheel")
    local held = choices().inserter
    local element = widget(INSERTER)
    element.elem_value = nil
    fire(element)
    assert(choices().inserter == held and widget(INSERTER).elem_value.name == held, "the inserter was cleared")
  end)

  test("the module picker follows the machine's slots, the pipe the recipe's fluid", function()
    gui.open(player())
    pick(ITEM, "iron-gear-wheel")
    pick({ "apl-content", "apl-table", "apl-machine" }, "assembling-machine-1")
    assert(not widget(MODULE).visible, "an AM1 has no module slots")
    pick({ "apl-content", "apl-table", "apl-machine" }, "assembling-machine-3")
    assert(widget(MODULE).visible, "an AM3 has module slots")
    pick(ITEM, "electric-engine-unit")
    assert(widget(PIPE).visible, "a lubricant recipe needs the pipe")
  end)

  test("the split box follows the modules, and keeps an override only while it disagrees", function()
    gui.open(player())
    pick(ITEM, "iron-gear-wheel")
    pick({ "apl-content", "apl-table", "apl-machine" }, "assembling-machine-3")
    pick(MODULE, "quality-module-3")
    assert(widget(SPLIT).state, "quality modules should tick the split")
    local box = widget(SPLIT)
    box.state = false
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().split == false and not widget(SPLIT).state, "unticking did not hold")
    box.state = true
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().split == nil, "ticking back to the automatic answer should drop the override")
  end)

  test("the split box keeps its override while the plan is refused", function()
    gui.open(player())
    pick({ "apl-content", "apl-table", "apl-machine" }, "assembling-machine-3")
    pick(ITEM, "personal-roboport-mk2-equipment")
    pick(MODULE, "productivity-module-3")
    assert(not widget({ "apl-buttons", "apl-confirm" }).enabled, "the plan should be refused")
    local box = widget(SPLIT)
    box.state = true
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().split == true and widget(SPLIT).state, "ticking on a refused plan did not hold")
    box.state = false
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().split == false and not widget(SPLIT).state, "unticking on a refused plan did not hold")
  end)

  test("a quality change on the item keeps the recipe and the hand-set amounts", function()
    gui.open(player())
    pick({ "apl-content", "apl-table", "apl-machine" }, "assembling-machine-3")
    pick(ITEM, "iron-gear-wheel")
    choices().recipe = "iron-gear-wheel"
    choices()["request_iron-plate"] = 50
    pick(ITEM, "iron-gear-wheel", "uncommon")
    assert(choices().recipe_quality == "uncommon", "the quality was not taken")
    assert(choices().recipe == "iron-gear-wheel" and choices()["request_iron-plate"] == 50,
      "a quality change reset the recipe or the amounts")
  end)

  test("the amounts panel follows the pace in minutes mode", function()
    gui.open(player())
    pick({ "apl-content", "apl-table", "apl-machine" }, "assembling-machine-3")
    pick(ITEM, "iron-gear-wheel")
    local mode = widget({ "apl-options", "apl-requests-strip", "apl-size-mode" })
    mode.selected_index = 2
    fire(mode, defines.events.on_gui_selection_state_changed)
    assert(choices().size_mode == "minutes", "the sizing rule did not switch")
    fire(widget({ "apl-options", "apl-requests-strip", "apl-requests-edit" }), defines.events.on_gui_click)
    local function field()
      return frame()[gui.INGREDIENTS_FRAME][gui.INGREDIENTS_FRAME .. "-content"]["apl-ingredients-list"]
        ["apl-request-row-iron-plate"]["apl-request-iron-plate"]
    end
    local before = field().text
    pick(MODULE, "speed-module-3")
    local expected = plan.build(player().force, player().surface, choices()).request_rows[1].default
    assert(field().text == tostring(expected) and field().text ~= before,
      "the panel shows " .. field().text .. " after speed modules, the cell requests " .. expected)
  end)

  test("Place hands over the blueprint and closes", function()
    gui.open(player())
    pick(ITEM, "iron-gear-wheel")
    fire(widget({ "apl-buttons", "apl-confirm" }), defines.events.on_gui_click)
    assert(frame() == nil, "the window stayed open")
    local cursor = player().cursor_stack
    assert(cursor.valid_for_read and cursor.name == "blueprint", "no blueprint in the cursor")
  end)

  test("the confirm key yields once to a chooser presumed open", function()
    gui.open(player())
    pick(ITEM, "iron-gear-wheel")
    fire(widget(ITEM), defines.events.on_gui_click)
    gui.confirm_key(player())
    assert(frame() ~= nil, "E confirmed while a chooser was presumed open")
    gui.confirm_key(player())
    assert(frame() == nil, "the second press did not place")
  end)

  test("the amounts panel stores an override, and the rule change replaces it", function()
    gui.open(player())
    pick(ITEM, "iron-gear-wheel")
    fire(widget({ "apl-options", "apl-requests-strip", "apl-requests-edit" }), defines.events.on_gui_click)
    local panel = frame()[gui.INGREDIENTS_FRAME]
    assert(panel, "the amounts panel did not open")
    local field = panel[gui.INGREDIENTS_FRAME .. "-content"]["apl-ingredients-list"]["apl-request-row-iron-plate"]["apl-request-iron-plate"]
    field.text = "123"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices()["request_iron-plate"] == 123, "the override was not stored")
    local size = widget({ "apl-options", "apl-requests-strip", "apl-size-value" })
    size.text = "7"
    fire(size, defines.events.on_gui_text_changed)
    assert(choices().size_crafts == 7 and choices()["request_iron-plate"] == nil,
      "a new craft count should replace the hand-set amounts")
  end)

  test("the settings panel writes the per-player setting", function()
    gui.open(player())
    fire(widget({ "apl-titlebar", "apl-settings-button" }), defines.events.on_gui_click)
    local panel = frame()[gui.SETTINGS_FRAME]
    assert(panel, "the settings panel did not open")
    local box = panel[gui.SETTINGS_FRAME .. "-content"]["apl-setting-show-all"]
    box.state = true
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(player().mod_settings[gui.SHOW_ALL_SETTING].value == true, "the setting was not written")
    player().mod_settings[gui.SHOW_ALL_SETTING] = { value = false }
  end)
end)
