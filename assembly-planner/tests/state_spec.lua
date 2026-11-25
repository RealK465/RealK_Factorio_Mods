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

  test("an item no cell can make goes, and its recipe with it", function()
    local saved = storage.players
    storage.players = { [1] = { choices = { item = "lubricant-barrel-nonexistent", recipe = "sulfur" } } }
    state.prune()
    local c = storage.players[1].choices
    storage.players = saved
    assert(c.item == nil and c.recipe == nil, "an unplannable item survived")
  end)
end)
