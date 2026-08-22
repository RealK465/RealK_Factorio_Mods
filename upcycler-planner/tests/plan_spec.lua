-- planner.plan() end to end against real prototypes at full research: geometry with real
-- footprints, the measured pole scenarios (analysis/poles.md), the fluid plans, the trash
-- tri-state, and the terminal-module rules. The widths follow the utility-column formula
-- W = 2 + sum(G_i) + (t-1)*P + Wm, where G_i is the column before tier i -- zero unless a
-- pole stands there, and at least one whenever the recipe takes a fluid. WHICH tiers open a
-- column is solved rather than assumed (planner.plan tries the compact plan first and only
-- keeps a column a pole turned out to need), so these widths and pole counts are measured on
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

-- The machine crafting at the target tier. Both halves of the test are fixture facts owned by
-- choices_with, so finding nothing means the fixture moved, not that the plan is wrong -- which
-- is why this asserts rather than handing back a nil for each caller to trip over separately.
local function terminal_machine(plan)
  for _, e in pairs(plan.entities) do
    if e.name == "assembling-machine-3" and e.recipe_quality == "rare" then return e end
  end
  assert(false, "no machine crafting at the target quality -- the fixture moved")
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
    -- The default medium pole covers the loop from the ring's own free ground, so no tier
    -- opens a column and the plan is the bare 2 + 2*3 + 3.
    local plan = planner.plan(force(), choices_with())
    assert(plan, "plan failed")
    assert(plan.width == 11, "width " .. plan.width)
    assert(plan.machines == 3 and plan.recyclers == 2, "column counts wrong")
    assert(count_by_name(plan, "assembling-machine-3") == 3, "machine entities")
    assert(count_by_name(plan, "recycler") == 2, "recycler entities")
  end)

  describe("the five pole scenarios", function()
    test("medium pole, rare target: the compact plan covers, so no column opens", function()
      -- The trade the compact-first rule makes: poles in the ring's dead ground instead of
      -- three lined up in columns, and three tiles of width back. Narrower wins.
      --
      -- Six since the overflow tap landed. The tap is a consumer in the terminal column's
      -- bottom corner, which had none before, and it stands on two tiles the pole pass could
      -- otherwise have used -- so the honest price of draining the ring is one more pole. The
      -- WIDTH is what the compact-first rule protects, and that is unchanged.
      local plan = planner.plan(force(), choices_with({ pole = "medium-electric-pole" }))
      assert(plan.width == 11, "width " .. plan.width .. ", expected the columns to stay shut")
      assert(count_by_name(plan, "medium-electric-pole") == 6,
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

    test("substation to legendary: two of the five columns open, 21 wide", function()
      -- The mixed case, and the whole point of solving the columns rather than assuming them:
      -- free ground alone leaves consumers dark here, but only two tiers turn out to need a
      -- column. 17 compact + two 2-wide columns = 21, where opening all five cost 27.
      local plan = planner.plan(force(), choices_with({
        quality = "legendary", pole = "substation",
      }))
      assert(plan.width == 21, "width " .. plan.width .. ", expected 17 + two 2-wide columns")
      assert(count_by_name(plan, "substation") == 2,
        "substation count " .. count_by_name(plan, "substation"))
      assert(plan.unpowered == nil, "unpowered " .. tostring(plan.unpowered))
    end)

    test("big electric pole, rare: best effort, and the shortfall is reported honestly", function()
      -- The honesty rule end to end: the 2x2 pole's supply is simply too small even from its
      -- own 2-wide columns plus the free-tile fallback, and the shortfall is REPORTED rather
      -- than the covered-but-unwired islands being counted as powered.
      --
      -- It is also the case that proves the columns still GROW: every one of the three opens
      -- and none is collapsed again, because each holds a pole that is doing real work. A
      -- width of 11 here would mean the compact plan had been kept despite powering less.
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

  describe("beacon-count plans", function()
    test("a stack of four costs no width and keeps everything powered", function()
      -- The vanilla max: interior 13 rows over a 3-tall beacon. The stack leaves exactly one
      -- free row per column, and the default pole still covers from the ring's own ground --
      -- the compact plan holds, so the pole lane is never paid for.
      local one = planner.plan(force(), choices_with({ beacon = "beacon" }))
      local four = planner.plan(force(), choices_with({ beacon = "beacon", beacon_count = 4 }))
      assert(four.width == one.width,
        "width " .. four.width .. " vs " .. one.width .. " -- stacking must cost no width")
      assert(count_by_name(four, "beacon") == 12,
        "beacon count " .. count_by_name(four, "beacon") .. ", expected four per tier")
      assert(four.unpowered == nil, "unpowered " .. tostring(four.unpowered))
    end)

    test("an over-asked count snaps to the geometric max", function()
      local plan = planner.plan(force(), choices_with({ beacon = "beacon", beacon_count = 99 }))
      assert(count_by_name(plan, "beacon") == 12,
        "beacon count " .. count_by_name(plan, "beacon") .. ", expected the max of four per tier")
    end)

    test("a non-positive count reads as one", function()
      local one = planner.plan(force(), choices_with({ beacon = "beacon" }))
      local zero = planner.plan(force(), choices_with({ beacon = "beacon", beacon_count = 0 }))
      assert(count_by_name(zero, "beacon") == 3,
        "beacon count " .. count_by_name(zero, "beacon") .. ", expected one per tier")
      assert(zero.width == one.width, "a floored count changed the width")
    end)

    test("substation with a full stack: the pole lane opens beside the beacons", function()
      -- The shape the pole lane exists for: a full stack starves the compact attempt of
      -- standing room, so the ladder pays for columns -- and pole_gap now sums the pole's
      -- width onto the beacon's, giving the substation its own lane west of the stack
      -- instead of a column it cannot stand in. Coverage is the assertion; the width is
      -- pinned so a lane regression shows as a shape change.
      local plan = planner.plan(force(), choices_with({
        quality = "legendary", pole = "substation", beacon = "beacon", beacon_count = 4,
      }))
      assert(count_by_name(plan, "beacon") == 20,
        "beacon count " .. count_by_name(plan, "beacon") .. ", expected four per tier over five")
      assert(plan.unpowered == nil, "unpowered " .. tostring(plan.unpowered))
      -- Measured 2026-08-22: the compact beaconed plan is 32 (2 + 5*3 + 4*3 + 3) and three of
      -- the five columns keep a 2-wide substation lane beside their stack, +2 each.
      assert(plan.width == 38, "width " .. plan.width .. ", expected 32 + three 2-wide lanes")
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
      -- The pipe run is what holds these columns open, not the pole: every tier is clamped to
      -- 1 and none widens to 2, because the compact plan already powers everything.
      -- 2 + 3*1 + 2*3 + 3 = 14, and the height stays the ring's own 15 -- the fluid network
      -- reaches outside only as underground stubs.
      local plan = planner.plan(force(), battery_choices())
      assert(plan, "battery plan failed")
      assert(plan.width == 14, "width " .. plan.width .. ", expected 14")
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

  describe("the top machine's module is a pick", function()
    test("a picked module reaches the terminal machine at its own quality", function()
      local plan = planner.plan(force(), choices_with({
        terminal_module = "speed-module-3", terminal_module_quality = "epic",
      }))
      local terminal = terminal_machine(plan)
      assert(terminal.modules.name == "speed-module-3",
        "terminal module " .. tostring(terminal.modules.name))
      assert(terminal.modules.quality == "epic",
        "terminal module quality " .. tostring(terminal.modules.quality))
      -- The quality modules below keep their own quality: the two pickers are independent now.
      for _, e in pairs(plan.entities) do
        if e.name == "recycler" then
          assert(e.modules.name == "quality-module-3" and e.modules.quality == "normal",
            "the recyclers followed the terminal module's quality")
        end
      end
    end)

    test("clearing the picker leaves the top machine empty", function()
      local plan = planner.plan(force(), choices_with({ no_terminal_module = true }))
      local terminal = terminal_machine(plan)
      assert(terminal.modules.name == nil,
        "cleared, yet the terminal machine holds " .. tostring(terminal.modules.name))
    end)
  end)

  describe("modules on the terminal machine", function()
    test("gears allow productivity: the last machine crafts for yield", function()
      local plan = planner.plan(force(), choices_with())
      local terminal = terminal_machine(plan)
      assert(terminal.modules.name == "productivity-module-3",
        "terminal module " .. tostring(terminal.modules.name))
    end)

    test("wooden chests refuse productivity: the last machine is left empty", function()
      -- The H8 regression (allow_productivity defaults to FALSE): the fallthrough idiom
      -- would quietly hand the terminal machine a quality module instead of nothing.
      local plan = planner.plan(force(), choices_with({ recipe = "wooden-chest" }))
      assert(plan, "wooden chest plan failed")
      -- The terminal machine, and every tier below it: this test is about the difference.
      local terminal = terminal_machine(plan)
      local lower = {}
      for _, e in pairs(plan.entities) do
        if e.name == "assembling-machine-3" and e ~= terminal then lower[#lower + 1] = e end
      end
      assert(terminal.modules.name == nil,
        "terminal must stay empty, holds " .. tostring(terminal.modules.name))
      for _, e in pairs(lower) do
        assert(e.modules.name == "quality-module-3", "lower tier lost its quality module")
      end
    end)
  end)

  describe("the picked inserter and chests reach the plan", function()
    test("a pick, at its own quality, replaces the default everywhere it appears", function()
      local plan = planner.plan(force(), choices_with({
        inserter = "fast-inserter", inserter_quality = "rare",
        requester = "buffer-chest", requester_quality = "uncommon",
        container = "iron-chest",
        provider = "storage-chest", provider_quality = "epic",
      }))
      assert(plan, "plan failed")
      -- Only the requester and the provider are role-checked against the pick: buffer-chest and
      -- storage-chest are the wrong logistic mode, so both fall back rather than being built.
      assert(count_by_name(plan, "fast-inserter") > 0, "the picked inserter was not planned")
      assert(count_by_name(plan, "bulk-inserter") == 0, "the default inserter survived the pick")
      assert(count_by_name(plan, "iron-chest") > 0, "the picked buffer chest was not planned")
      assert(count_by_name(plan, "steel-chest") == 0, "the default buffer survived the pick")
      assert(count_by_name(plan, "buffer-chest") == 0, "a buffer chest is not a requester")
      assert(count_by_name(plan, "requester-chest") > 0, "the requester role fell back wrongly")
      assert(count_by_name(plan, "storage-chest") == 0, "a storage chest is not a provider")

      for _, e in pairs(plan.entities) do
        if e.name == "fast-inserter" then
          assert(e.quality == "rare", "inserter quality " .. tostring(e.quality))
        elseif e.name == "iron-chest" then
          assert(e.quality == "normal", "an unset chest quality must read as normal")
        end
      end
    end)

    test("the defaults are the best researched, at normal", function()
      local plan = planner.plan(force(), choices_with())
      assert(count_by_name(plan, "bulk-inserter") > 0, "default inserter missing")
      assert(count_by_name(plan, "steel-chest") > 0, "default buffer chest missing")
      for _, e in pairs(plan.entities) do
        if e.name == "bulk-inserter" or e.name == "steel-chest" then
          assert(e.quality == "normal", e.name .. " defaulted to " .. tostring(e.quality))
        end
      end
    end)

    test("a stale pick falls back rather than erroring", function()
      -- The belt's rule, one role at a time: a name that is no longer a candidate of that role
      -- is not a signal to place nothing, it is a signal to use the default.
      local plan = planner.plan(force(), choices_with({
        inserter = "stack-inserter", requester = "steel-chest", provider = "iron-chest",
      }))
      assert(plan, "a stale pick must not break the plan")
      assert(count_by_name(plan, "stack-inserter") == 0, "a belt-stacker reached the plan")
      assert(count_by_name(plan, "bulk-inserter") > 0, "the inserter did not fall back")
      assert(count_by_name(plan, "requester-chest") > 0, "the requester did not fall back")
      assert(count_by_name(plan, "passive-provider-chest") == 1, "the provider did not fall back")
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
