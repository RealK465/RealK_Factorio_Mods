-- proto.lua against the real prototypes: the measured fluid rotations, which machines and
-- items a cell can use, and the research and module rules. Space Age's set, the runner's
-- default.

local proto = require("scripts.proto")
local research = require("tests.support.research")

local function force()
  return game.forces.player
end

describe("fluid rotation", function()
  test("each vanilla machine turns a fluid input to face the pipe row", function()
    -- AM3 and the chemical plant author inputs north; the foundry and cryogenic plant author
    -- them south; the EM plant on its flanks. Measured on 2.1.23 with a live pipe row.
    local expected = {
      ["assembling-machine-3"] = defines.direction.north,
      ["chemical-plant"] = defines.direction.north,
      ["foundry"] = defines.direction.south,
      ["cryogenic-plant"] = defines.direction.south,
      ["electromagnetic-plant"] = defines.direction.east,
    }
    for name, direction in pairs(expected) do
      local got = proto.fluid_rotation(prototypes.entity[name], "pipe")
      assert(got == direction, name .. " turned to " .. tostring(got) .. ", expected " .. direction)
    end
  end)
end)

describe("machine and item candidates", function()
  test("assembling machines that take a recipe and electricity, nothing else", function()
    for _, name in pairs({ "assembling-machine-1", "assembling-machine-3", "chemical-plant", "foundry",
      "electromagnetic-plant" }) do
      assert(proto.is_machine(name), name .. " is missing from the machine list")
    end
    for _, name in pairs({ "electric-furnace", "recycler", "stone-furnace", "biochamber" }) do
      assert(not proto.is_machine(name), name .. " should not be a cell machine")
    end
  end)

  test("every catalogued recipe can run in a cell", function()
    for _, item in pairs(proto.items()) do
      for _, name in pairs(proto.recipes_for_item(item)) do
        local recipe = prototypes.recipe[name]
        local makes_it, fluids = false, 0
        for _, product in pairs(recipe.products) do
          assert(product.type ~= "fluid", name .. " makes a fluid")
          if product.name == item then makes_it = true end
        end
        for _, ingredient in pairs(recipe.ingredients) do
          if ingredient.type == "fluid" then fluids = fluids + 1 end
        end
        assert(makes_it, name .. " is listed for " .. item .. " but does not make it")
        assert(fluids <= 1, name .. " takes " .. fluids .. " fluids")
        assert(#proto.machines_for(recipe) > 0, name .. " has no machine")
        for _, category in pairs(recipe.categories) do
          assert(category ~= "recycling", name .. " is a recycling recipe")
        end
      end
    end
  end)

  test("the two-fluid sulfur recipe is left out", function()
    assert(not proto.contains(proto.recipes_for_item("sulfur"), "sulfur"),
      "sulfur from water and petroleum gas would need two pipe rows")
  end)

  test("only researched items are offered", function()
    research.fresh(force())
    local unlocked = proto.unlocked_items(force())
    assert(proto.contains(unlocked, "iron-gear-wheel"), "gears are craftable from the start")
    assert(not proto.contains(unlocked, "assembling-machine-3"), "AM3 offered before its research")
    research.full(force())
    assert(proto.contains(proto.unlocked_items(force()), "assembling-machine-3"), "AM3 missing at full research")
  end)
end)

describe("picks and modules", function()
  before_all(function() research.full(force()) end)

  test("the best researched pieces", function()
    local inserter = prototypes.entity[proto.best_inserter(force())]
    assert(inserter.bulk, "the default inserter should move a stack per swing")
    assert(proto.best_chest(force(), "requester") == "requester-chest", "requester default wrong")
    assert(proto.best_chest(force(), "output") == "passive-provider-chest", "output default wrong")
    assert(proto.best_pipe(force()) == "pipe", "pipe default wrong")
  end)

  test("the long-handed inserter does not fit a cell", function()
    assert(not proto.is_inserter("long-handed-inserter"), "it reaches past the chest")
    assert(not proto.is_inserter("burner-inserter"), "nothing fuels it")
    assert(proto.is_inserter("fast-inserter"), "the fast inserter must fit")
  end)

  test("a beacon takes speed modules and refuses quality ones", function()
    local beacon = prototypes.entity["beacon"]
    assert(proto.module_fits("speed-module-3", beacon), "speed refused by a beacon")
    assert(not proto.module_fits("quality-module-3", beacon), "quality accepted by a beacon")
    assert(proto.best_module(force(), "speed", beacon) == "speed-module-3", "best speed module wrong")
  end)
end)
