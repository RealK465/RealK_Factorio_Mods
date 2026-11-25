-- gate.technology as pure data: hand-built tables shaped like data.raw, no game. Vanilla's
-- shape first, then each way a mod moves the requester chest, and the ranking rules.

local gate = require("prototypes.planner.gate")

local ITEM_TYPES = { item = 0 }

local function unlocks(recipe)
  return { { type = "unlock-recipe", recipe = recipe } }
end

local function makes(item)
  return { { type = "item", name = item, amount = 1 } }
end

-- Vanilla in miniature: the requester behind logistic-system, a passive provider earlier, and
-- an infinity chest that reports a logistic mode but is not a logistic container.
local function vanilla()
  return {
    ["logistic-container"] = {
      ["requester-chest"] = { logistic_mode = "requester" },
      ["passive-provider-chest"] = { logistic_mode = "passive-provider" },
    },
    ["infinity-container"] = { ["infinity-chest"] = { logistic_mode = "requester" } },
    item = {
      ["requester-chest"] = { place_result = "requester-chest" },
      ["passive-provider-chest"] = { place_result = "passive-provider-chest" },
      ["infinity-chest"] = { place_result = "infinity-chest" },
    },
    recipe = {
      ["requester-chest"] = { enabled = false, results = makes("requester-chest") },
      ["passive-provider-chest"] = { enabled = false, results = makes("passive-provider-chest") },
      ["infinity-chest"] = { results = makes("infinity-chest") },
    },
    technology = {
      ["logistic-robotics"] = { effects = unlocks("passive-provider-chest") },
      ["space-science-pack"] = { prerequisites = { "logistic-robotics" } },
      ["logistic-system"] = { prerequisites = { "space-science-pack" }, effects = unlocks("requester-chest") },
    },
  }
end

describe("gate.technology", function()
  test("vanilla gates on logistic-system", function()
    local technology = gate.technology(vanilla(), ITEM_TYPES)
    assert(technology == "logistic-system", "vanilla gated on " .. tostring(technology))
  end)

  test("an infinity chest's logistic mode does not count", function()
    -- Its recipe is enabled from the start; were it counted, the gate would vanish.
    assert(gate.technology(vanilla(), ITEM_TYPES) ~= false, "the infinity chest opened the gate")
  end)

  test("an earlier technology that also unlocks a requester takes the gate", function()
    local raw = vanilla()
    table.insert(raw.technology["logistic-robotics"].effects, unlocks("requester-chest")[1])
    local technology = gate.technology(raw, ITEM_TYPES)
    assert(technology == "logistic-robotics", "the early unlock lost to " .. tostring(technology))
  end)

  test("a modded requester of its own on an earlier technology takes the gate", function()
    local raw = vanilla()
    raw["logistic-container"]["warehouse-requester"] = { logistic_mode = "requester" }
    raw.item["warehouse-requester"] = { place_result = "warehouse-requester" }
    raw.recipe["warehouse-requester"] = { enabled = false, results = makes("warehouse-requester") }
    raw.technology["warehouses"] = { effects = unlocks("warehouse-requester") }
    local technology = gate.technology(raw, ITEM_TYPES)
    assert(technology == "warehouses", "the modded requester lost to " .. tostring(technology))
  end)

  test("a requester recipe enabled from the start removes the gate", function()
    local raw = vanilla()
    raw.recipe["requester-chest"].enabled = nil
    assert(gate.technology(raw, ITEM_TYPES) == false, "an unset enabled defaults to true")
  end)

  test("a recycling recipe or a hidden one is no way to build a requester", function()
    local raw = vanilla()
    raw.recipe["requester-chest-recycling"] = { categories = { "recycling" }, results = makes("requester-chest") }
    raw.recipe["cheat-requester"] = { hidden = true, results = makes("requester-chest") }
    local technology = gate.technology(raw, ITEM_TYPES)
    assert(technology == "logistic-system", "a non-producer opened the gate: " .. tostring(technology))
  end)

  test("ties go to the name", function()
    local raw = vanilla()
    raw.technology["b-tie"] = { effects = unlocks("requester-chest") }
    raw.technology["a-tie"] = { effects = unlocks("requester-chest") }
    assert(gate.technology(raw, ITEM_TYPES) == "a-tie", "an equal rank went elsewhere")
  end)

  test("nothing that requests leaves the gate alone", function()
    local raw = vanilla()
    raw["logistic-container"]["requester-chest"].logistic_mode = "buffer"
    assert(gate.technology(raw, ITEM_TYPES) == nil, "a gate was chosen with no requester in the data")
  end)
end)
