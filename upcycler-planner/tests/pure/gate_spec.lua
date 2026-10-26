-- gate.technology as pure data: hand-built tables shaped like data.raw, no game. The vanilla
-- shape first, then each way a mod moves the recycler -- a second technology unlocking it, a
-- recycler of its own, a recipe enabled from the start -- and the ranking rules between them.

local gate = require("prototypes.planner.gate")

local ITEM_TYPES = { item = 0 }

local function unlocks(recipe)
  return { { type = "unlock-recipe", recipe = recipe } }
end

local function makes(item)
  return { { type = "item", name = item, amount = 1 } }
end

-- Vanilla in miniature: the recycler behind a three-deep chain, a crafting machine that does
-- not recycle, and a quality module technology that unlocks nothing of the recycler's.
local function vanilla()
  return {
    furnace = { recycler = { crafting_categories = { "recycling" } } },
    ["assembling-machine"] = {
      ["assembling-machine-3"] = { crafting_categories = { "crafting", "advanced-crafting" } },
    },
    item = {
      recycler = { place_result = "recycler" },
      ["assembling-machine-3"] = { place_result = "assembling-machine-3" },
      ["iron-plate"] = {},
    },
    recipe = {
      recycler = { enabled = false, results = makes("recycler") },
      ["assembling-machine-3"] = { enabled = false, results = makes("assembling-machine-3") },
      ["iron-plate"] = { categories = { "smelting" }, results = makes("iron-plate") },
    },
    technology = {
      ["space-science-pack"] = {},
      ["space-platform"] = { prerequisites = { "space-science-pack" } },
      ["planet-discovery-fulgora"] = { prerequisites = { "space-platform" } },
      recycling = { prerequisites = { "planet-discovery-fulgora" }, effects = unlocks("recycler") },
      ["quality-module"] = { effects = unlocks("quality-module") },
    },
  }
end

describe("gate.technology", function()
  test("vanilla gates on recycling", function()
    local technology = gate.technology(vanilla(), ITEM_TYPES)
    assert(technology == "recycling", "vanilla gated on " .. tostring(technology))
  end)

  test("an earlier technology that also unlocks the recycler takes the gate", function()
    -- Early Quality & Recyclers' shape: the recycler recipe added to the first quality module
    -- technology, with recycling left as it was.
    local raw = vanilla()
    table.insert(raw.technology["quality-module"].effects, unlocks("recycler")[1])
    local technology = gate.technology(raw, ITEM_TYPES)
    assert(technology == "quality-module", "the early unlock lost to " .. tostring(technology))
  end)

  test("a modded recycler on an earlier technology takes the gate", function()
    -- Recycler Progression's shape: a recycler of its own, its own recipe and technology.
    local raw = vanilla()
    raw["assembling-machine"]["recycler-1"] = { crafting_categories = { "recycling" } }
    raw.item["recycler-1"] = { place_result = "recycler-1" }
    raw.recipe["recycler-1"] = { enabled = false, results = makes("recycler-1") }
    raw.technology["recycler-1"] = { prerequisites = { "space-science-pack" }, effects = unlocks("recycler-1") }
    local technology = gate.technology(raw, ITEM_TYPES)
    assert(technology == "recycler-1", "the modded recycler lost to " .. tostring(technology))
  end)

  test("a recycler recipe enabled from the start removes the gate", function()
    local raw = vanilla()
    raw.recipe.recycler.enabled = nil
    assert(gate.technology(raw, ITEM_TYPES) == false, "an unset enabled defaults to true")
    raw.recipe.recycler.enabled = true
    assert(gate.technology(raw, ITEM_TYPES) == false, "an enabled recipe still left a gate")
  end)

  test("a recycling recipe or a hidden one is no way to build a recycler", function()
    -- The self-recycling fallback hands back the item itself, and cheat tools ship enabled
    -- recipes hidden from Factoriopedia -- neither may read as "buildable from the start".
    local raw = vanilla()
    raw.recipe["recycler-recycling"] = { categories = { "recycling" }, results = makes("recycler") }
    raw.recipe["cheat-recycler"] = { hidden = true, results = makes("recycler") }
    local technology = gate.technology(raw, ITEM_TYPES)
    assert(technology == "recycling", "a non-producer opened the gate: " .. tostring(technology))

    -- hidden_in_factoriopedia set false wins over hidden: that recipe counts.
    raw.recipe["shown-cheat"] = { hidden = true, hidden_in_factoriopedia = false, results = makes("recycler") }
    assert(gate.technology(raw, ITEM_TYPES) == false,
      "a recipe shown in Factoriopedia was ignored for being hidden")
  end)

  test("a prerequisite reached along two paths counts once", function()
    -- z-diamond stands behind three technologies, one of them reached twice; a-chain behind
    -- four. Counted twice, the diamond would tie at four and lose on the name. Recycling is
    -- taken out of the race, since it too stands three deep.
    local raw = vanilla()
    raw.technology.recycling.effects = {}
    raw.technology["shared"] = {}
    raw.technology["left"] = { prerequisites = { "shared" } }
    raw.technology["right"] = { prerequisites = { "shared" } }
    raw.technology["z-diamond"] = { prerequisites = { "left", "right" }, effects = unlocks("recycler") }
    raw.technology["c1"] = {}
    raw.technology["c2"] = { prerequisites = { "c1" } }
    raw.technology["c3"] = { prerequisites = { "c2" } }
    raw.technology["c4"] = { prerequisites = { "c3" } }
    raw.technology["a-chain"] = { prerequisites = { "c4" }, effects = unlocks("recycler") }
    local technology = gate.technology(raw, ITEM_TYPES)
    assert(technology == "z-diamond", "the shared prerequisite was counted twice: " .. tostring(technology))
  end)

  test("a technology disabled at the start ranks behind every enabled one", function()
    local raw = vanilla()
    raw.technology["scenario-unlock"] = { enabled = false, effects = unlocks("recycler") }
    assert(gate.technology(raw, ITEM_TYPES) == "recycling", "a disabled technology took the gate")

    -- Alone, it is still the answer: a scenario may research it by script.
    raw.technology.recycling.effects = {}
    assert(gate.technology(raw, ITEM_TYPES) == "scenario-unlock",
      "the only technology delivering the recycler was passed over")
  end)

  test("ties go to the name", function()
    local raw = vanilla()
    raw.technology["b-tie"] = { effects = unlocks("recycler") }
    raw.technology["a-tie"] = { effects = unlocks("recycler") }
    local technology = gate.technology(raw, ITEM_TYPES)
    assert(technology == "a-tie", "an equal rank went to " .. tostring(technology))
  end)

  test("the recycler's item is found in any item type it is given", function()
    local raw = vanilla()
    raw["item-with-entity-data"] = { recycler = raw.item.recycler }
    raw.item.recycler = nil
    assert(gate.technology(raw, ITEM_TYPES) == nil, "an item type outside the set was searched")
    local technology = gate.technology(raw, { item = 0, ["item-with-entity-data"] = 0 })
    assert(technology == "recycling", "the second item type was not searched: " .. tostring(technology))
  end)

  test("nothing that recycles leaves the gate alone", function()
    local raw = vanilla()
    raw.furnace.recycler.crafting_categories = { "smelting" }
    assert(gate.technology(raw, ITEM_TYPES) == nil, "a gate was chosen with no recycler in the data")
  end)
end)
