-- planner.plan() end to end against real prototypes at full research: geometry with real
-- footprints, the measured pole scenarios (analysis/poles.md), the fluid plans, the trash
-- tri-state, and the terminal-module rules. The widths follow the 0.2.0 utility-column
-- formula -- W = 2 + t*G + (t-1)*P + Wm, G = pole width plus one when the recipe takes a
-- fluid -- and the pole counts are measured on 2.1.14 with the SA modset; a drift means the
-- plan changed shape, which a release should know.

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

  test("vanilla gears to rare: 14 wide with the pole columns, 3 machines, 2 recyclers", function()
    -- The default medium pole opens a 1-wide utility column before every tier:
    -- 2 + 3*1 + 2*3 + 3.
    local plan = planner.plan(force(), choices_with())
    assert(plan, "plan failed")
    assert(plan.width == 14, "width " .. plan.width)
    assert(plan.machines == 3 and plan.recyclers == 2, "column counts wrong")
    assert(count_by_name(plan, "assembling-machine-3") == 3, "machine entities")
    assert(count_by_name(plan, "recycler") == 2, "recycler entities")
  end)

  describe("the five pole scenarios", function()
    test("medium pole, rare target: poles line the utility columns, width 14", function()
      local plan = planner.plan(force(), choices_with({ pole = "medium-electric-pole" }))
      assert(plan.width == 14, "width " .. plan.width .. ", expected 2 + 3*1 + 2*3 + 3 = 14")
      assert(count_by_name(plan, "medium-electric-pole") == 3,
        "pole count " .. count_by_name(plan, "medium-electric-pole"))
      assert(plan.unpowered == nil, "unpowered " .. tostring(plan.unpowered))
    end)

    test("legendary medium pole: one covers the whole loop", function()
      -- Quality genuinely grows the supply radius (+1 per level): a legendary medium pole's
      -- 17x17 square blankets a 14x15 plan from the middle.
      local plan = planner.plan(force(), choices_with({
        pole = "medium-electric-pole", pole_quality = "legendary",
      }))
      assert(count_by_name(plan, "medium-electric-pole") == 1,
        "pole count " .. count_by_name(plan, "medium-electric-pole"))
      assert(plan.unpowered == nil, "unpowered " .. tostring(plan.unpowered))
    end)

    test("substation to legendary: 27 wide on its 2-wide columns, two substations", function()
      -- The column is sized to the pole from the start -- the old grow-on-shortfall retry is
      -- gone because its reason is: 2 + 5*2 + 4*3 + 3.
      local plan = planner.plan(force(), choices_with({
        quality = "legendary", pole = "substation",
      }))
      assert(plan.width == 27, "width " .. plan.width .. ", expected 27")
      assert(count_by_name(plan, "substation") == 2,
        "substation count " .. count_by_name(plan, "substation"))
      assert(plan.unpowered == nil, "unpowered " .. tostring(plan.unpowered))
    end)

    test("big electric pole, rare: best effort, and the shortfall is reported honestly", function()
      -- The honesty rule end to end: the 2x2 pole's supply is simply too small even from its
      -- own 2-wide columns plus the free-tile fallback, and the shortfall is REPORTED rather
      -- than the covered-but-unwired islands being counted as powered.
      local plan = planner.plan(force(), choices_with({ pole = "big-electric-pole" }))
      assert(plan.width == 17, "width " .. plan.width .. ", expected 2 + 3*2 + 2*3 + 3 = 17")
      -- Measured 2026-08-17: three consumers out of reach -- down from the old free-tile
      -- growth's seven, because the 2-wide columns stand poles beside every machine.
      assert(plan.unpowered == 3, "unpowered " .. tostring(plan.unpowered) .. ", expected 3")
    end)

    test("a cleared picker places no poles, no columns, and warns about nothing", function()
      local plan = planner.plan(force(), choices_with({ no_poles = true }))
      assert(plan.width == 11, "width " .. plan.width .. ", expected the columns to collapse")
      assert(count_by_name(plan, "medium-electric-pole") == 0, "poles placed despite the clear")
      assert(plan.unpowered == nil, "an intentionally dark loop must not warn")
    end)
  end)

  describe("fluid recipes", function()
    local function battery_choices(overrides)
      local choices = choices_with({
        recipe = "battery", machine = "chemical-plant", pole = "medium-electric-pole",
      })
      for key, value in pairs(overrides or {}) do choices[key] = value end
      return choices
    end

    test("battery to rare: pipes join the pole columns and nothing leaves the ring", function()
      -- G = 1 pole + 1 pipe run: width 2 + 3*2 + 2*3 + 3 = 17. The height stays the ring's
      -- own 15 -- the fluid network reaches outside only as underground stubs.
      local plan = planner.plan(force(), battery_choices())
      assert(plan, "battery plan failed")
      assert(plan.width == 17, "width " .. plan.width .. ", expected 17")
      assert(plan.height == 15, "height " .. plan.height .. ", expected the ring's own 15")
      -- A full-height run of 11 rides beside each of the three machines, stub pair at the ends.
      assert(count_by_name(plan, "pipe") == 3 * 11,
        "pipe count " .. count_by_name(plan, "pipe"))
      assert(count_by_name(plan, "pipe-to-ground") == 6,
        "pipe-to-ground count " .. count_by_name(plan, "pipe-to-ground"))
      for _, e in pairs(plan.entities) do
        if e.name == "chemical-plant" then
          assert(e.direction == defines.direction.west,
            "chemical plant faces " .. tostring(e.direction) .. ", expected west")
        end
      end
      assert(plan.unpowered == nil,
        "unpowered " .. tostring(plan.unpowered) .. " -- poles must still cover a fluid plan")
    end)

    test("no poles still means a pipe column: the run has nowhere else to live", function()
      local plan = planner.plan(force(), battery_choices({ no_poles = true }))
      assert(plan, "poleless battery plan failed")
      assert(plan.width == 14, "width " .. plan.width .. ", expected 2 + 3*1 + 2*3 + 3 = 14")
      assert(count_by_name(plan, "pipe-to-ground") == 6, "stub pairs missing")
    end)

    test("a two-fluid recipe cannot be planned", function()
      -- validate() refuses it with its own message; plan() must agree rather than draw
      -- something with a second, unbuilt network.
      assert(planner.plan(force(), choices_with({ recipe = "sulfur" })) == nil,
        "a two-fluid recipe produced a plan")
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
