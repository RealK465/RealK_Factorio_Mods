-- planner.plan() end to end against real prototypes at full research: geometry with real
-- footprints, the five measured pole scenarios (analysis/poles.md), the trash tri-state, and
-- the terminal-module rules. Numbers here are the ones the 2026-08-16 harnesses measured on
-- 2.1.14 with the SA modset; a drift means the plan changed shape, which a release should know.

local planner = require("scripts.planner")
local research = require("tests.support.research")

local function force()
  return game.forces.player
end

local function choices_with(overrides)
  local choices = {
    recipe = "iron-gear-wheel", quality = "rare",
    machine = "assembling-machine-3", recycler = "recycler",
  }
  for key, value in pairs(overrides or {}) do choices[key] = value end
  return choices
end

local function count_by_name(plan, name)
  local n = 0
  for _, e in pairs(plan.entities) do
    if e.name == name then n = n + 1 end
  end
  return n
end

describe("planner.plan", function()
  before_all(function() research.full(force()) end)

  test("nil and incomplete choices yield nil, never an error", function()
    assert(planner.plan(force(), nil) == nil, "nil choices")
    assert(planner.plan(force(), {}) == nil, "empty choices")
    assert(planner.plan(force(), { recipe = "iron-gear-wheel" }) == nil, "missing machine")
  end)

  test("vanilla gears to rare: 11 wide, 3 machines, 2 recyclers", function()
    local plan = planner.plan(force(), choices_with())
    assert(plan, "plan failed")
    assert(plan.width == 11, "width " .. plan.width)
    assert(plan.machines == 3 and plan.recyclers == 2, "column counts wrong")
    assert(count_by_name(plan, "assembling-machine-3") == 3, "machine entities")
    assert(count_by_name(plan, "recycler") == 2, "recycler entities")
  end)

  describe("the five pole scenarios", function()
    test("medium pole, rare target: 5 poles in the free tiles, width stays 11", function()
      local plan = planner.plan(force(), choices_with({ pole = "medium-electric-pole" }))
      assert(plan.width == 11, "growth used where free tiles suffice, width " .. plan.width)
      assert(count_by_name(plan, "medium-electric-pole") == 5,
        "pole count " .. count_by_name(plan, "medium-electric-pole"))
      assert(plan.unpowered == nil, "unpowered " .. tostring(plan.unpowered))
    end)

    test("legendary medium pole: one covers the whole loop", function()
      -- Quality genuinely grows the supply radius (+1 per level): a legendary medium pole's
      -- 17x17 square blankets an 11x15 plan from the middle.
      local plan = planner.plan(force(), choices_with({
        pole = "medium-electric-pole", pole_quality = "legendary",
      }))
      assert(count_by_name(plan, "medium-electric-pole") == 1,
        "pole count " .. count_by_name(plan, "medium-electric-pole"))
      assert(plan.unpowered == nil, "unpowered " .. tostring(plan.unpowered))
    end)

    test("substation to legendary: the plan grows 17 to 25 and two substations power it", function()
      local plan = planner.plan(force(), choices_with({
        quality = "legendary", pole = "substation",
      }))
      assert(plan.width == 25, "width " .. plan.width .. ", expected growth to 25")
      assert(count_by_name(plan, "substation") == 2,
        "substation count " .. count_by_name(plan, "substation"))
      assert(plan.unpowered == nil, "unpowered " .. tostring(plan.unpowered))
    end)

    test("big electric pole, rare: best effort -- growth kept, 7 consumers stay dark", function()
      -- The honesty rule end to end: the 2x2 pole's supply is simply too small, growth still
      -- buys strictly more coverage so the width is kept, and the shortfall is REPORTED
      -- rather than the covered-but-unwired islands being counted as powered.
      local plan = planner.plan(force(), choices_with({ pole = "big-electric-pole" }))
      assert(plan.width == 15, "width " .. plan.width .. ", expected growth to 15")
      assert(plan.unpowered == 7, "unpowered " .. tostring(plan.unpowered) .. ", expected 7")
    end)

    test("a cleared picker places no poles and warns about nothing", function()
      local plan = planner.plan(force(), choices_with({ no_poles = true }))
      assert(count_by_name(plan, "medium-electric-pole") == 0, "poles placed despite the clear")
      assert(plan.unpowered == nil, "an intentionally dark loop must not warn")
    end)
  end)

  describe("the trash flag rides the plan", function()
    test("never touched reads as checked -- the pre-checkbox snapshot rule", function()
      local plan = planner.plan(force(), choices_with())
      assert(plan.trash_unrequested == true, "nil must read as checked")
    end)

    test("explicitly unchecked stays unchecked", function()
      local plan = planner.plan(force(), choices_with({ trash_unrequested = false }))
      assert(plan.trash_unrequested == false, "false must survive")
    end)
  end)

  describe("modules on the terminal machine", function()
    test("gears allow productivity: the last machine crafts for yield", function()
      local plan = planner.plan(force(), choices_with())
      local terminal
      for _, e in pairs(plan.entities) do
        if e.name == "assembling-machine-3" and e.recipe_quality == "rare" then terminal = e end
      end
      assert(terminal, "no terminal machine found")
      assert(terminal.modules.name == "productivity-module-3",
        "terminal module " .. tostring(terminal.modules.name))
    end)

    test("wooden chests refuse productivity: the last machine is left empty", function()
      -- The H8 regression (allow_productivity defaults to FALSE): the fallthrough idiom
      -- would quietly hand the terminal machine a quality module instead of nothing.
      local plan = planner.plan(force(), choices_with({ recipe = "wooden-chest" }))
      assert(plan, "wooden chest plan failed")
      local terminal, lower = nil, {}
      for _, e in pairs(plan.entities) do
        if e.name == "assembling-machine-3" then
          if e.recipe_quality == "rare" then terminal = e else lower[#lower + 1] = e end
        end
      end
      assert(terminal, "no terminal machine found")
      assert(terminal.modules.name == nil,
        "terminal must stay empty, holds " .. tostring(terminal.modules.name))
      for _, e in pairs(lower) do
        assert(e.modules.name == "quality-module-3", "lower tier lost its quality module")
      end
    end)
  end)

  test("feed requests are a minute of crafting, capped at a stack", function()
    -- Gears: 2 plates per 0.5s craft is 240/min, capped at the plate's stack of 100.
    local plan = planner.plan(force(), choices_with())
    local seen
    for _, e in pairs(plan.entities) do
      if e.name == "requester-chest" and e.requests and e.requests[1]
        and e.requests[1].name == "iron-plate" then
        seen = e.requests[1].count
        break
      end
    end
    assert(seen == 100, "iron-plate request " .. tostring(seen) .. ", expected 100")
  end)
end)
