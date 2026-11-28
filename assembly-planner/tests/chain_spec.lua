-- chain.lua against the real prototypes, at full research, on nauvis: the walk, one blueprint
-- for the chain, and what the row must keep true between its cells.

local chain = require("scripts.chain")
local plan = require("scripts.plan")
local proto = require("scripts.proto")
local research = require("tests.support.research")
local fingerprint = require("tests.support.fingerprint")

local function force() return game.forces.player end
local function nauvis() return game.surfaces["nauvis"] end

local function build(choices, cells)
  return chain.build(force(), nauvis(), choices, cells)
end

local function items_of(nodes)
  local out = {}
  for i, node in ipairs(nodes) do out[i] = node.item end
  return table.concat(out, ",")
end

-- The machine crafting each recipe, by recipe name.
local function machines(p)
  local out = {}
  for _, e in ipairs(p.entities) do
    if e.recipe then out[e.recipe] = e end
  end
  return out
end

local function has_warning(p, key)
  for _, warning in ipairs(p.warnings) do
    if warning[1] == "apl-message." .. key then return true end
    -- An ingredient cell's warning rides behind its icon: { "", icon, warning }.
    if warning[1] == "" and type(warning[3]) == "table" and warning[3][1] == "apl-message." .. key then
      return true
    end
  end
  return false
end

local AM3 = "assembling-machine-3"

describe("chain.build", function()
  before_all(function() research.full(force()) end)

  test("with nothing ticked, or nothing reachable, it is plan.build", function()
    -- The plan.build plan, less the one-row list and the cell count a chain adds for the window.
    local function single(choices, cells)
      local p = build(choices, cells)
      assert(#p.cells == 1 and p.cells[1].item == choices.item and p.copies == 1, "a lone cell should list itself")
      p.cells, p.copies = nil, nil
      return fingerprint.of(p)
    end
    local choices = { item = "electronic-circuit", machine = AM3 }
    local alone = fingerprint.of(plan.build(force(), nauvis(), choices))
    assert(single(choices, {}) == alone, "an empty chain changed the plan")
    assert(single(choices, { ["copper-cable"] = { machine = AM3 } }) == alone, "an unticked entry changed the plan")
    local gears = { item = "iron-gear-wheel", machine = AM3 }
    assert(single(gears, { ["copper-cable"] = { on = true } }) == fingerprint.of(plan.build(force(), nauvis(), gears)),
      "a ticked cell nothing in the chain uses changed the plan")
  end)

  test("circuits and their cable: two cells side by side, one blueprint", function()
    local p = assert(build({ item = "electronic-circuit", machine = AM3 },
      { ["copper-cable"] = { on = true, machine = AM3 } }))
    assert(#p.cells == 2 and p.cells[2].item == "copper-cable", "expected the root and the cable cell")
    local m = machines(p)
    assert(m["electronic-circuit"].dx == 0 and m["copper-cable"].dx == 3,
      "the cable cell should abut the circuit cell on its right")
    assert(p.width == 6, "footprint " .. p.width .. "x" .. p.height)
    local requested = {}
    for _, e in ipairs(p.entities) do
      for _, request in ipairs(e.requests or {}) do requested[request.name] = true end
    end
    assert(requested["copper-plate"] and requested["copper-cable"] and requested["iron-plate"],
      "the circuit cell asks for cable and plates, the cable cell for copper plates")
    assert(p.product == "electronic-circuit", "the chain is named for its root")
  end)

  test("a cell keeps its own machine and modules; the rest is the chain's", function()
    local p = assert(build({ item = "electronic-circuit", machine = AM3, inserter = "fast-inserter",
      module = "speed-module-3" },
      { ["copper-cable"] = { on = true, machine = "electromagnetic-plant", module = "productivity-module-3" } }))
    local m = machines(p)
    assert(m["copper-cable"].name == "electromagnetic-plant", "the cell's machine was not its own")
    assert(m["copper-cable"].modules.name == "productivity-module-3", "the cell's modules were not its own")
    assert(m["electronic-circuit"].modules.name == "speed-module-3", "the root lost its modules")
    for _, e in ipairs(p.entities) do
      assert(e.name ~= "bulk-inserter", "every cell should use the chain's inserter")
    end
  end)

  test("a ticked ingredient's own ingredients nest under it", function()
    local nodes = chain.walk(force(), { item = "inserter", machine = AM3 }, {
      ["electronic-circuit"] = { on = true, machine = AM3 },
      ["copper-cable"] = { on = true, machine = AM3 },
    })
    assert(items_of(nodes) == "inserter,electronic-circuit,copper-cable", "walk " .. items_of(nodes))
    assert(nodes[2].depth == 1 and nodes[3].depth == 2, "the cable should stand under the circuits")
  end)

  test("advanced circuits and their circuits share one cable cell", function()
    local cells = {
      ["electronic-circuit"] = { on = true, machine = AM3 },
      ["copper-cable"] = { on = true, machine = AM3 },
    }
    local nodes = chain.walk(force(), { item = "advanced-circuit", machine = AM3 }, cells)
    assert(#nodes == 3, "walk " .. items_of(nodes))
    for _, node in ipairs(nodes) do
      for _, ingredient in ipairs(node.ingredients) do
        if ingredient.name == "copper-cable" then
          assert(ingredient.on, node.item .. " should show the cable as in the chain")
        elseif ingredient.name == "plastic-bar" then
          assert(not ingredient.on, "unticked plastic should show as out")
        end
      end
    end
    local p = assert(build({ item = "advanced-circuit", machine = AM3 }, cells))
    local count = 0
    for _, e in ipairs(p.entities) do
      if e.recipe == "copper-cable" then count = count + 1 end
    end
    assert(count == 1, "expected one cable cell, got " .. count)
  end)

  test("a refusing cell refuses the chain and says which", function()
    local p, message = build({ item = "fast-inserter", machine = AM3 },
      { inserter = { on = true, machine = AM3, module = "productivity-module-3" } })
    assert(p == nil, "a productivity module on inserters should refuse")
    assert(message[1] == "" and message[2] == "[item=inserter] "
      and message[3][1] == "apl-message.module-not-accepted-by-recipe",
      "the refusal should carry the cell's icon: " .. serpent.line(message))
  end)

  test("at most eight cells", function()
    local cells = {}
    for _, item in ipairs(proto.items()) do cells[item] = { on = true } end
    local nodes = chain.walk(force(), { item = "rocket-silo" }, cells)
    assert(#nodes == chain.MAX_CELLS, "the walk took " .. #nodes .. " cells")
  end)

  test("a pipe row stands one tile from its neighbour", function()
    local p = assert(build({ item = "advanced-circuit", machine = AM3 },
      { ["plastic-bar"] = { on = true, machine = "chemical-plant" } }))
    local first
    for _, e in ipairs(p.entities) do
      if e.name == "pipe" and (not first or e.dx < first) then first = e.dx end
    end
    assert(first == 4, "the plastic cell's pipes should start one tile past the circuit cell, at " .. tostring(first))
  end)

  test("one pole network for the whole row", function()
    local p = assert(build({ item = "electronic-circuit", machine = AM3, beacon = "beacon",
      pole = "medium-electric-pole" }, { ["copper-cable"] = { on = true, machine = AM3 } }))
    local unwired, poles = 0, 0
    for _, e in ipairs(p.entities) do
      if e.name == "medium-electric-pole" then
        poles = poles + 1
        if not e.wire_to then unwired = unwired + 1 end
      end
    end
    assert(poles > 1 and unwired == 1, poles .. " poles, " .. unwired .. " of them wired to none")
  end)

  test("an ingredient cell that falls short says so with both rates", function()
    local p = assert(build({ item = "electronic-circuit", machine = AM3 },
      { ["copper-cable"] = { on = true, machine = AM3 } }))
    assert(has_warning(p, "chain-short"), "one AM3 of cable cannot feed one AM3 of circuits")
    -- An AM3 crafts circuits at 150 a minute, 3 cables each; cable at 150 crafts of 2.
    local cable = p.cells[2]
    assert(cable.short and math.abs(cable.made - 300) < 1e-6 and math.abs(cable.wanted - 450) < 1e-6,
      "cable makes " .. tostring(cable.made) .. " against " .. tostring(cable.wanted))
    local fast = assert(build({ item = "electronic-circuit", machine = AM3 },
      { ["copper-cable"] = { on = true, machine = "electromagnetic-plant" } }))
    assert(not has_warning(fast, "chain-short"), "an EM plant makes cable faster than an AM3 eats it")
  end)

  test("at the top tier nothing rolls better, so no output is held back", function()
    local choices = { item = "electronic-circuit", machine = AM3, recipe_quality = "legendary" }
    local cable = { machine = AM3, module = "quality-module-3" }
    local p = assert(build(choices, { ["copper-cable"] = { on = true, machine = cable.machine, module = cable.module } }))
    local alone = assert(plan.build(force(), nauvis(), {
      item = "copper-cable", machine = cable.machine, module = cable.module, recipe_quality = "legendary",
    }))
    assert(math.abs(p.cells[2].made - alone.stats.crafts_per_minute * 2) < 1e-6,
      "a legendary cable cell makes " .. p.cells[2].made .. ", not twice its " .. alone.stats.crafts_per_minute .. " crafts")
  end)

  test("a row's count stands copies of its cell side by side", function()
    local p = assert(build({ item = "electronic-circuit", machine = AM3 },
      { ["copper-cable"] = { on = true, machine = AM3, count = 2 } }))
    local cable = 0
    for _, e in ipairs(p.entities) do
      if e.recipe == "copper-cable" then cable = cable + 1 end
    end
    assert(cable == 2 and p.copies == 3 and p.width == 9, cable .. " cable machines, " .. p.copies .. " cells, "
      .. p.width .. " wide")
    assert(not p.cells[2].short and math.abs(p.cells[2].made - 600) < 1e-6,
      "two AM3s make 600 cable a minute, more than the 450 the circuits take")
  end)

  test("a root count alone stands copies of the root, at their rate together", function()
    local p = assert(build({ item = "electronic-circuit", machine = AM3, count = 3 }, {}))
    assert(p.copies == 3 and p.width == 9, p.copies .. " cells, " .. p.width .. " wide")
    assert(math.abs(p.stats.crafts_per_minute - 450) < 1e-6, "three AM3s make 450 circuits a minute, not "
      .. p.stats.crafts_per_minute)
  end)

  test("the balanced counts follow the users, top down", function()
    -- An AM3 crafts inserters at 150 a minute, each taking a circuit; circuits at 150 crafts, each
    -- taking 3 cables; cable at 150 crafts of 2.
    local cells = {
      ["electronic-circuit"] = { on = true, machine = AM3 },
      ["copper-cable"] = { on = true, machine = AM3 },
    }
    local p = assert(build({ item = "inserter", machine = AM3 }, cells))
    assert(p.cells[2].best == 1 and p.cells[3].best == 2, "best " .. p.cells[2].best .. ", " .. p.cells[3].best)
    assert(math.abs(p.cells[3].need - 1.5) < 1e-6, "the cable needs 1.5 cells, not " .. p.cells[3].need)
    local four = assert(build({ item = "inserter", machine = AM3, count = 4 }, cells))
    assert(four.cells[2].best == 4 and four.cells[3].best == 6,
      "four inserter cells balance at 4 and 6, not " .. four.cells[2].best .. " and " .. four.cells[3].best)
  end)

  test("more cells than a blueprint holds refuses", function()
    local p, message = build({ item = "advanced-circuit", machine = AM3, count = 10 }, {
      ["electronic-circuit"] = { on = true, machine = AM3, count = 10 },
      ["copper-cable"] = { on = true, machine = AM3, count = 10 },
      ["plastic-bar"] = { on = true, machine = "chemical-plant", count = 3 },
    })
    assert(p == nil and message[1] == "apl-message.chain-too-big", "33 cells should refuse: " .. serpent.line(message))
  end)

  test("the network warning shows once for the whole chain", function()
    local p = assert(build({ item = "electronic-circuit", machine = AM3, cap_mode = "network" },
      { ["copper-cable"] = { on = true, machine = AM3 } }))
    local network = 0
    for _, warning in ipairs(p.warnings) do
      if warning[1] == "apl-message.network-cap" then network = network + 1 end
    end
    assert(network == 1, "the network warning shows " .. network .. " times")
  end)
end)
