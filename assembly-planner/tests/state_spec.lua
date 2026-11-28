-- state.prune: what a configuration change leaves of a player's choices.

local state = require("scripts.state")

describe("state.prune", function()
  test("drops picks that no longer qualify, and amounts for ingredients the recipe lost", function()
    local saved = storage.players
    storage.players = { [1] = { choices = {
      item = "iron-gear-wheel",
      machine = "electric-furnace",            -- a furnace is no cell machine
      requester = "passive-provider-chest",    -- wrong role
      output = "passive-provider-chest",
      module = "no-such-module",
      ["request_iron-plate"] = 10,
      ["request_copper-plate"] = 10,           -- not a gear ingredient
      machine_quality = "no-such-quality",
      recipe_quality = "normal",
    } } }
    state.prune()
    local c = storage.players[1].choices
    storage.players = saved
    assert(c.item == "iron-gear-wheel", "a valid item was dropped")
    assert(c.machine == nil and c.requester == nil and c.module == nil, "a stale pick survived")
    assert(c.output == "passive-provider-chest", "a valid output chest was dropped")
    assert(c["request_iron-plate"] == 10 and c["request_copper-plate"] == nil, "the amounts were swept wrong")
    assert(c.machine_quality == nil and c.recipe_quality == "normal", "the quality sweep was wrong")
  end)

  test("a chain's cells are pruned like the root, and go whole when no cell can make them", function()
    local saved = storage.players
    storage.players = { [1] = {
      choices = { item = "electronic-circuit" },
      cells = {
        ["copper-cable"] = {
          on = true, machine = "electric-furnace", module = "speed-module-3", count = 2,
          ["request_copper-plate"] = 10, ["request_iron-plate"] = 10, machine_quality = "no-such-quality",
        },
        ["iron-gear-wheel"] = { on = true, count = 11 },
        ["no-such-item"] = { on = true },
      },
    } }
    state.prune()
    local cells = storage.players[1].cells
    storage.players = saved
    local cable = cells["copper-cable"]
    assert(cable and cable.on and cable.module == "speed-module-3" and cable.count == 2,
      "a valid cell lost its entry, its picks or its count")
    assert(cells["iron-gear-wheel"].count == nil, "a count past the cap survived")
    assert(cable.machine == nil and cable.machine_quality == nil, "a stale cell pick survived")
    assert(cable["request_copper-plate"] == 10 and cable["request_iron-plate"] == nil,
      "the cell's amounts were swept against the wrong recipe")
    assert(cells["no-such-item"] == nil, "a cell no recipe can make survived")
  end)

  test("an entry from before chains gains its cells on first use", function()
    local saved = storage.players
    storage.players = { [1] = { choices = { item = "iron-gear-wheel" } } }
    state.prune()
    local entry = state.of(1)
    storage.players = saved
    assert(type(entry.cells) == "table", "an old entry should gain an empty chain")
  end)

  test("an item no cell can make goes, and its recipe with it", function()
    local saved = storage.players
    storage.players = { [1] = { choices = { item = "lubricant-barrel-nonexistent", recipe = "sulfur" } } }
    state.prune()
    local c = storage.players[1].choices
    storage.players = saved
    assert(c.item == nil and c.recipe == nil, "an unplannable item survived")
  end)
end)
