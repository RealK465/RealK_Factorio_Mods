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

-- Widgets by name, wherever the layout puts them: every name in the window is unique.
local function find(element, name)
  if element.name == name then return element end
  for _, child in pairs(element.children) do
    local found = find(child, name)
    if found then return found end
  end
  return nil
end

local function widget(name)
  local element = find(frame(), name)
  assert(element, "no widget named " .. name)
  return element
end

local function fire(element, name)
  dispatch.on_gui_event({
    element = element, player_index = player().index,
    name = name or defines.events.on_gui_elem_changed,
  })
end

local function pick(name, item, quality)
  local element = widget(name)
  element.elem_value = { name = item, quality = quality or "normal" }
  fire(element)
end

local function click(name) fire(widget(name), defines.events.on_gui_click) end

local function amount_field(item)
  local list = frame()[gui.INGREDIENTS_FRAME][gui.INGREDIENTS_FRAME .. "-content"]["apl-ingredients-list"]
  return list["apl-request-row-" .. item]["apl-request-" .. item]
end

local function cells() return state.of(player().index).cells end

local function reset()
  gui.close(player())
  local entry = state.of(player().index)
  entry.choices = {}
  entry.cells = {}
  entry.chooser_maybe_open = nil
  player().clear_cursor()
  player().mod_settings[gui.SHOW_ALL_SETTING] = { value = false }
end

describe("the planner window", function()
  before_all(function() research.full(player().force) end)
  after_each(reset)

  test("opens focused, closes, and toggles", function()
    gui.toggle(player())
    assert(frame() and player().opened == frame(), "the window did not open focused")
    gui.toggle(player())
    assert(frame() == nil, "the window did not close")
  end)

  test("an empty window holds the hint beside the item picker and no status", function()
    gui.open(player())
    assert(widget("apl-hint").visible, "the hint should stand beside the empty item picker")
    assert(not widget("apl-status").visible, "the status area should stay shut before an item is picked")
    assert(not widget("apl-confirm").enabled, "Place should wait for an item")
  end)

  test("picking an item fills in what would be placed", function()
    gui.open(player())
    pick("apl-item", "fast-inserter")
    local c = choices()
    assert(c.item == "fast-inserter" and c.machine and c.inserter and c.requester and c.output,
      "the defaults were not written back")
    assert(widget("apl-confirm").enabled, "Place is disabled on a plannable item")
    assert(not widget("apl-recipe").visible, "one recipe makes fast inserters, so the recipe list should hide")
    assert(serpent.line(widget("apl-item-name").caption) == serpent.line(prototypes.item["fast-inserter"].localised_name),
      "the item's name should stand beside its picker")
    assert(find(frame(), "apl-hint") == nil, "the hint should go once an item is picked")
    assert(not widget("apl-pipe").visible, "fast inserters take no fluid, so the pipe should hide")
    assert(widget("apl-status").visible and widget("apl-stats"), "a standing plan should show its numbers")
  end)

  test("an item with several recipes shows the list, defaulting to the one the machine crafts", function()
    gui.open(player())
    pick("apl-machine", "assembling-machine-3")
    pick("apl-item", "iron-gear-wheel")
    local list = widget("apl-recipe")
    assert(list.visible, "Space Age's casting recipe makes gears too, so the list should show")
    assert(list.tags.recipes[list.selected_index] == "iron-gear-wheel",
      "an assembler should default to the plate recipe, not casting")
    assert(find(frame(), "apl-item-name") == nil, "the list names the recipe, so the item's name should go")
  end)

  test("the click that opens a chooser changes nothing", function()
    gui.open(player())
    pick("apl-item", "iron-gear-wheel")
    local before = frame().index
    click("apl-item")
    assert(frame().index == before, "a click carrying the same value rebuilt the window")
  end)

  test("an emptied picker that cannot be cleared snaps back", function()
    gui.open(player())
    pick("apl-item", "iron-gear-wheel")
    local held = choices().inserter
    local element = widget("apl-inserter")
    element.elem_value = nil
    fire(element)
    assert(choices().inserter == held and widget("apl-inserter").elem_value.name == held, "the inserter was cleared")
  end)

  test("the module picker follows the machine's slots, the pipe the recipe's fluid", function()
    gui.open(player())
    pick("apl-item", "iron-gear-wheel")
    pick("apl-machine", "assembling-machine-1")
    assert(not widget("apl-module").visible, "an AM1 has no module slots")
    pick("apl-machine", "assembling-machine-3")
    assert(widget("apl-module").visible, "an AM3 has module slots")
    pick("apl-item", "electric-engine-unit")
    assert(widget("apl-pipe").visible, "a lubricant recipe needs the pipe")
  end)

  test("the beacon counts wait for a beacon, then offer exactly what fits", function()
    gui.open(player())
    pick("apl-machine", "assembling-machine-3")
    pick("apl-item", "iron-gear-wheel")
    assert(not widget("apl-beacons-side").enabled and not widget("apl-beacon-module").enabled,
      "with no beacon the counts and the module should be off")
    pick("apl-beacon", "beacon")
    local capacity = plan.capacity(player().force, choices())
    local side = widget("apl-beacons-side")
    assert(side.enabled and #side.items == capacity.side + 1,
      "the side count should offer 0 to " .. capacity.side .. ", offers " .. #side.items)
    assert(side.selected_index == capacity.side + 1, "an untouched count should default to as many as fit")
  end)

  test("the split box follows the modules, and keeps an override only while it disagrees", function()
    gui.open(player())
    pick("apl-item", "iron-gear-wheel")
    pick("apl-machine", "assembling-machine-3")
    pick("apl-module", "quality-module-3")
    assert(widget("apl-split").state, "quality modules should tick the split")
    local box = widget("apl-split")
    box.state = false
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().split == false and not widget("apl-split").state, "unticking did not hold")
    box.state = true
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().split == nil, "ticking back to the automatic answer should drop the override")
  end)

  test("the split box keeps its override while the plan is refused", function()
    gui.open(player())
    pick("apl-machine", "assembling-machine-3")
    pick("apl-item", "personal-roboport-mk2-equipment")
    pick("apl-module", "productivity-module-3")
    assert(not widget("apl-confirm").enabled, "the plan should be refused")
    assert(widget("apl-status").visible and widget("apl-message-1"), "a refusal should say why")
    local box = widget("apl-split")
    box.state = true
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().split == true and widget("apl-split").state, "ticking on a refused plan did not hold")
    box.state = false
    fire(box, defines.events.on_gui_checked_state_changed)
    assert(choices().split == false and not widget("apl-split").state, "unticking on a refused plan did not hold")
  end)

  test("a quality change on the item keeps the recipe and the hand-set amounts", function()
    gui.open(player())
    pick("apl-machine", "assembling-machine-3")
    pick("apl-item", "iron-gear-wheel")
    choices().recipe = "iron-gear-wheel"
    choices()["request_iron-plate"] = 50
    pick("apl-item", "iron-gear-wheel", "uncommon")
    assert(choices().recipe_quality == "uncommon", "the quality was not taken")
    assert(choices().recipe == "iron-gear-wheel" and choices()["request_iron-plate"] == 50,
      "a quality change reset the recipe or the amounts")
  end)

  test("the amounts panel follows the pace in minutes mode", function()
    gui.open(player())
    pick("apl-machine", "assembling-machine-3")
    pick("apl-item", "iron-gear-wheel")
    local mode = widget("apl-size-mode")
    mode.selected_index = 2
    fire(mode, defines.events.on_gui_selection_state_changed)
    assert(choices().size_mode == "minutes", "the sizing rule did not switch")
    click("apl-requests-edit")
    local before = amount_field("iron-plate").text
    pick("apl-module", "speed-module-3")
    local expected = plan.build(player().force, player().surface, choices()).request_rows[1].default
    assert(amount_field("iron-plate").text == tostring(expected) and amount_field("iron-plate").text ~= before,
      "the panel shows " .. amount_field("iron-plate").text .. " after speed modules, the cell requests " .. expected)
  end)

  test("the pencil opens and closes the amounts panel and shows which", function()
    gui.open(player())
    pick("apl-item", "iron-gear-wheel")
    assert(not widget("apl-requests-edit").toggled, "the pencil should start up")
    click("apl-requests-edit")
    assert(frame()[gui.INGREDIENTS_FRAME] and widget("apl-requests-edit").toggled,
      "the panel did not open, or the pencil did not show it")
    pick("apl-beacon", "beacon")
    assert(frame()[gui.INGREDIENTS_FRAME] and widget("apl-requests-edit").toggled,
      "a rebuild should keep the panel and the pressed pencil")
    assert(gui.close_side_panel(player()), "the close request should take the panel first")
    assert(frame()[gui.INGREDIENTS_FRAME] == nil and not widget("apl-requests-edit").toggled,
      "closing the panel should raise the pencil")
    click("apl-requests-edit")
    click(gui.INGREDIENTS_FRAME .. "-close")
    assert(frame()[gui.INGREDIENTS_FRAME] == nil and not widget("apl-requests-edit").toggled,
      "the panel's own close should raise the pencil")
  end)

  test("Place hands over the blueprint and closes", function()
    gui.open(player())
    pick("apl-item", "iron-gear-wheel")
    click("apl-confirm")
    assert(frame() == nil, "the window stayed open")
    local cursor = player().cursor_stack
    assert(cursor.valid_for_read and cursor.name == "blueprint", "no blueprint in the cursor")
  end)

  test("the confirm key yields once to a chooser presumed open", function()
    gui.open(player())
    pick("apl-item", "iron-gear-wheel")
    click("apl-item")
    gui.confirm_key(player())
    assert(frame() ~= nil, "E confirmed while a chooser was presumed open")
    gui.confirm_key(player())
    assert(frame() == nil, "the second press did not place")
  end)

  test("the confirm key places nothing while the amounts panel is up", function()
    gui.open(player())
    pick("apl-item", "iron-gear-wheel")
    click("apl-requests-edit")
    gui.confirm_key(player())
    assert(frame() ~= nil and not player().cursor_stack.valid_for_read, "E placed past the panel")
  end)

  test("the amounts panel stores an override, and the rule change replaces it", function()
    gui.open(player())
    pick("apl-item", "iron-gear-wheel")
    click("apl-requests-edit")
    assert(frame()[gui.INGREDIENTS_FRAME], "the amounts panel did not open")
    local field = amount_field("iron-plate")
    field.text = "123"
    fire(field, defines.events.on_gui_text_changed)
    assert(choices()["request_iron-plate"] == 123, "the override was not stored")
    local size = widget("apl-size-value")
    size.text = "7"
    fire(size, defines.events.on_gui_text_changed)
    assert(choices().size_crafts == 7 and choices()["request_iron-plate"] == nil,
      "a new craft count should replace the hand-set amounts")
  end)

  test("the machine row offers only ingredients a cell can make", function()
    gui.open(player())
    pick("apl-machine", "assembling-machine-3")
    pick("apl-item", "wooden-chest")
    assert(find(frame(), "apl-chain-strip/wooden-chest") == nil, "nothing makes wood, so no strip")
    pick("apl-item", "electronic-circuit")
    local cable = widget("apl-chain-electronic-circuit/copper-cable")
    assert(cable.number == 3 and cable.style.name == "slot_button", "cable should be offered, 3 a craft, unlit")
  end)

  test("ticking an ingredient adds its row, whose pickers write its own entry", function()
    gui.open(player())
    pick("apl-machine", "assembling-machine-3")
    pick("apl-item", "electronic-circuit")
    click("apl-chain-electronic-circuit/copper-cable")
    assert(cells()["copper-cable"] and cells()["copper-cable"].on, "the cable was not ticked")
    assert(widget("apl-chain-electronic-circuit/copper-cable").style.name == "yellow_slot_button",
      "a ticked ingredient should be lit")
    assert(widget("apl-cell-row/copper-cable") and widget("apl-cell/copper-cable"), "the cable's row is missing")
    assert(cells()["copper-cable"].machine, "the cell's machine default was not written back")
    pick("apl-machine/copper-cable", "assembling-machine-2")
    assert(cells()["copper-cable"].machine == "assembling-machine-2", "the cell's pick missed its entry")
    assert(choices().machine == "assembling-machine-3", "the cell's pick leaked into the root")
    assert(widget("apl-status").visible and widget("apl-stats"), "the chain should plan")
    click("apl-chain-electronic-circuit/copper-cable")
    assert(not cells()["copper-cable"].on and cells()["copper-cable"].machine == "assembling-machine-2",
      "unticking should keep the entry for later")
    assert(find(frame(), "apl-cell-row/copper-cable") == nil, "the row should go with the tick")
  end)

  test("a cell made from its own product cannot untick itself from its row", function()
    gui.open(player())
    pick("apl-item", "atomic-bomb")
    click("apl-chain-atomic-bomb/uranium-235")
    local own = widget("apl-chain-uranium-235/uranium-235")
    assert(own.style.name == "yellow_slot_button" and not own.enabled,
      "kovarex takes its own product, which should stay lit and locked in its row")
  end)

  test("a row's count lands in its own entry, and Balance sets every count", function()
    gui.open(player())
    pick("apl-machine", "assembling-machine-3")
    pick("apl-item", "electronic-circuit")
    click("apl-chain-electronic-circuit/copper-cable")
    pick("apl-machine/copper-cable", "assembling-machine-3")
    local count = widget("apl-count/copper-cable")
    assert(count.items[2]:find("[color=", 1, true), "the balanced count, two cable cells, should be green")
    assert(widget("apl-balance"), "one cable cell is not balanced, so Balance should be offered")
    count.selected_index = 3
    fire(count, defines.events.on_gui_selection_state_changed)
    assert(cells()["copper-cable"].count == 3 and choices().count == nil, "the count missed its own entry")
    click("apl-balance")
    assert(cells()["copper-cable"].count == 2, "Balance should set the cable to its balanced two cells")
    assert(find(frame(), "apl-balance") == nil, "a balanced chain offers no Balance")
    assert(widget("apl-count/copper-cable").selected_index == 2, "the drop-down should show the new count")
  end)

  test("Balance waits when the balanced chain would not fit in a blueprint", function()
    gui.open(player())
    pick("apl-machine", "assembling-machine-3")
    pick("apl-item", "inserter")
    click("apl-chain-inserter/electronic-circuit")
    click("apl-chain-inserter/iron-gear-wheel")
    click("apl-chain-electronic-circuit/copper-cable")
    for _, item in ipairs({ "electronic-circuit", "iron-gear-wheel", "copper-cable" }) do
      pick("apl-machine/" .. item, "assembling-machine-1")
    end
    local count = widget("apl-count")
    count.selected_index = 10
    fire(count, defines.events.on_gui_selection_state_changed)
    -- Ten AM3s of inserters outrun ten AM1s of anything they take: 40 cells balanced, capped.
    local balance = widget("apl-balance")
    assert(not balance.enabled, "a balanced chain of 40 cells cannot be placed, so Balance should wait")
    local before = serpent.line(cells())
    fire(balance, defines.events.on_gui_click)
    assert(serpent.line(cells()) == before, "a disabled Balance changed the counts")
  end)

  test("the root's count copies the root", function()
    gui.open(player())
    pick("apl-item", "iron-gear-wheel")
    local count = widget("apl-count")
    count.selected_index = 3
    fire(count, defines.events.on_gui_selection_state_changed)
    assert(choices().count == 3, "the root's count was not stored")
    count = widget("apl-count")
    count.selected_index = 1
    fire(count, defines.events.on_gui_selection_state_changed)
    assert(choices().count == nil, "a count of one should store nothing")
  end)

  test("a new root item drops the chain", function()
    gui.open(player())
    pick("apl-item", "electronic-circuit")
    click("apl-chain-electronic-circuit/copper-cable")
    pick("apl-item", "iron-gear-wheel")
    assert(next(cells()) == nil, "the old chain survived a new item")
  end)

  test("the amounts panel groups the chain, each cell's amounts in its own entry", function()
    gui.open(player())
    pick("apl-machine", "assembling-machine-3")
    pick("apl-item", "electronic-circuit")
    click("apl-chain-electronic-circuit/copper-cable")
    click("apl-requests-edit")
    assert(widget("apl-ingredients-head/copper-cable"), "the cable's group has no header")
    local field = widget("apl-request-copper-cable/copper-plate")
    field.text = "77"
    fire(field, defines.events.on_gui_text_changed)
    assert(cells()["copper-cable"]["request_copper-plate"] == 77, "the cell's amount missed its entry")
    assert(choices()["request_copper-plate"] == nil, "the cell's amount leaked into the root")
    local size = widget("apl-size-value")
    size.text = "9"
    fire(size, defines.events.on_gui_text_changed)
    assert(cells()["copper-cable"]["request_copper-plate"] == nil, "a new craft count should reset every cell")
  end)

  test("every name in a window with a chain and its panel is unique", function()
    gui.open(player())
    pick("apl-machine", "assembling-machine-3")
    pick("apl-item", "advanced-circuit")
    click("apl-chain-advanced-circuit/electronic-circuit")
    click("apl-chain-electronic-circuit/copper-cable")
    click("apl-requests-edit")
    local seen = {}
    local function walk(element)
      if element.name ~= "" then
        assert(not seen[element.name], "two widgets are named " .. element.name)
        seen[element.name] = true
      end
      for _, child in pairs(element.children) do walk(child) end
    end
    walk(frame())
    assert(seen["apl-chain-advanced-circuit/copper-cable"] and seen["apl-chain-electronic-circuit/copper-cable"],
      "the cable should be offered in both rows that take it")
  end)

  test("Place hands over the whole chain", function()
    gui.open(player())
    pick("apl-machine", "assembling-machine-3")
    pick("apl-item", "electronic-circuit")
    click("apl-chain-electronic-circuit/copper-cable")
    click("apl-confirm")
    local cursor = player().cursor_stack
    assert(cursor.valid_for_read and cursor.name == "blueprint", "no blueprint in the cursor")
    local recipes = {}
    for _, e in pairs(cursor.get_blueprint_entities()) do
      if e.recipe then recipes[e.recipe] = true end
    end
    assert(recipes["electronic-circuit"] and recipes["copper-cable"], "the blueprint lacks a cell")
    assert(#cursor.preview_icons == 2 and cursor.preview_icons[2].signal.name == "copper-cable",
      "the icons should name both products")
  end)

  test("the titlebar toggle flips the per-player setting, and the window follows it", function()
    gui.open(player())
    assert(not widget("apl-show-all").toggled, "the toggle should start up")
    click("apl-show-all")
    assert(player().mod_settings[gui.SHOW_ALL_SETTING].value == true, "the setting was not written")
    assert(widget("apl-show-all").toggled, "the reopened window should show the toggle down")
    click("apl-show-all")
    assert(player().mod_settings[gui.SHOW_ALL_SETTING].value == false, "the second click did not turn it off")
  end)
end)
