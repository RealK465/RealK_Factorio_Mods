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
local deep_equal = require("tests.support.deep_equal")
local circuit_stack = require("tests.support.circuit_stack")

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

local function count_by_name(plan, name, recipe_quality)
  local n = 0
  for _, e in pairs(plan.entities) do
    if e.name == name and (recipe_quality == nil or e.recipe_quality == recipe_quality) then
      n = n + 1
    end
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

  describe("the pace", function()
    test("reported, slower toward legendary, and beacons price both their sides", function()
      -- Directions, not pinned numbers: the seconds move with every module retune. The
      -- beacon cases pin the requirement the first draft got wrong: a beacon transmits its
      -- module's quality malus as well as its speed (api.md §25), so a speed beacon must
      -- never flatter a loop it in truth slows or kills.
      local rare = planner.plan(force(), choices_with())
      assert(rare.seconds and rare.seconds > 0, "no pace on the vanilla plan")
      local legendary = planner.plan(force(), choices_with({ quality = "legendary" }))
      assert(legendary.seconds and legendary.seconds > rare.seconds,
        "legendary reads no slower than rare: "
        .. tostring(legendary.seconds) .. " vs " .. tostring(rare.seconds))

      -- The default efficiency beacon transmits nothing the loop's maths care about: the
      -- pace and the yield hold perfectly still.
      local eff = planner.plan(force(), choices_with({ beacon = "beacon" }))
      assert(eff.seconds == rare.seconds and eff.yield.per_item == rare.yield.per_item,
        "an efficiency beacon moved the numbers: " .. tostring(eff.seconds)
        .. " vs " .. tostring(rare.seconds))

      -- Two speed-module beacons transmit a quality malus that cancels the normal quality
      -- modules entirely: the honest answer is a dead loop -- no flow, no pace -- not a
      -- shorter time.
      local dead = planner.plan(force(), choices_with({
        beacon = "beacon", beacon_module = "speed-module-3", beacon_count = 2,
      }))
      assert(dead.seconds == nil,
        "a quality-killing beacon still promises a pace: " .. tostring(dead.seconds))
      assert(dead.yield and dead.yield.machine_sets == nil, "the dead loop still reports flow")

      -- With legendary quality modules outweighing one beacon's malus the loop lives: the
      -- speed shows up as a shorter pace, and the malus as an honestly worse yield.
      local plain = planner.plan(force(), choices_with({ quality_module_quality = "legendary" }))
      local hasted = planner.plan(force(), choices_with({
        quality_module_quality = "legendary",
        beacon = "beacon", beacon_module = "speed-module-3",
      }))
      assert(hasted.yield.per_item < plain.yield.per_item,
        "the beacon's quality malus vanished from the yield")
      assert(hasted.seconds and plain.seconds and hasted.seconds < plain.seconds,
        "the beacon's speed never reached the pace: "
        .. tostring(hasted.seconds) .. " vs " .. tostring(plain.seconds))
    end)
  end)

  describe("the per-tier split reaches the plan", function()
    test("legendary modules mix in every lower tier; recyclers and terminal stay flat", function()
      local plan = planner.plan(force(), {
        recipe = "electronic-circuit", quality = "legendary",
        machine = "electromagnetic-plant", recycler = "recycler",
        quality_module = "quality-module-3", quality_module_quality = "legendary",
        productivity_module = "productivity-module-3", productivity_module_quality = "legendary",
        terminal_module = "productivity-module-3", terminal_module_quality = "legendary",
      })
      assert(plan, "EM plan failed")
      local lower, terminal = {}, nil
      for _, e in pairs(plan.entities) do
        if e.name == "electromagnetic-plant" then
          if e.recipe_quality == "legendary" then terminal = e else lower[#lower + 1] = e end
        end
      end
      assert(terminal and #lower == 4, "machine census wrong")
      for _, e in pairs(lower) do
        local m = e.modules
        assert(m[1] and m[2], "a lower tier is not mixed: " .. serpent.line(m))
        assert(m[1].name == "quality-module-3" and m[1].quality == "legendary" and m[1].count == 1,
          "quality half " .. serpent.line(m[1]))
        assert(m[2].name == "productivity-module-3" and m[2].quality == "legendary"
          and m[2].count == 4, "productivity half " .. serpent.line(m[2]))
      end
      assert(terminal.modules.name == "productivity-module-3" and terminal.modules.count == 5,
        "terminal " .. serpent.line(terminal.modules))
      for _, e in pairs(plan.entities) do
        if e.name == "recycler" then
          assert(e.modules.name == "quality-module-3", "a recycler consulted the split")
        end
      end
      assert(plan.yield and plan.yield.per_item > 0, "the plan lost its yield")
    end)

    test("an override reaches its machine; the vanilla default plan stays flat", function()
      local plan = planner.plan(force(), choices_with({ split_prod_uncommon = 2 }))
      local uncommon
      for _, e in pairs(plan.entities) do
        if e.name == "assembling-machine-3" and e.recipe_quality == "uncommon" then uncommon = e end
      end
      assert(uncommon, "no uncommon machine")
      assert(uncommon.modules[1] and uncommon.modules[1].name == "quality-module-3"
        and uncommon.modules[1].count == 2
        and uncommon.modules[2].name == "productivity-module-3" and uncommon.modules[2].count == 2,
        "override did not land: " .. serpent.line(uncommon.modules))

      -- The untouched vanilla plan must stay the flat single-spec shape at every lower tier:
      -- the search reproduces the old rule at normal module quality, and the shape with it.
      local flat = planner.plan(force(), choices_with())
      for _, e in pairs(flat.entities) do
        if e.name == "assembling-machine-3" and e.recipe_quality ~= "rare" then
          assert(e.modules.name == "quality-module-3" and e.modules.count == 4,
            "the untouched vanilla plan grew an array: " .. serpent.line(e.modules))
        end
      end
      assert(flat.yield, "the flat plan lost its yield")

      -- And the pace rides the folded flavour: the override changes the expected crafts,
      -- so the wizard's typing genuinely reaches the seconds the status line shows.
      assert(plan.seconds and flat.seconds and plan.seconds ~= flat.seconds,
        "the pace ignored the folded override")

      -- Unticking the mix checkbox forces the flat shape even past a stored override.
      local off = planner.plan(force(),
        choices_with({ split_enabled = false, split_prod_uncommon = 2 }))
      for _, e in pairs(off.entities) do
        if e.name == "assembling-machine-3" and e.recipe_quality ~= "rare" then
          assert(e.modules.name == "quality-module-3" and e.modules.count == 4,
            "an unticked mix still split: " .. serpent.line(e.modules))
        end
      end
    end)
  end)

  describe("the picked inserter and chests reach the plan", function()
    test("a pick, at its own quality, replaces the default everywhere it appears", function()
      -- buffer_stock off so the plan carries no buffer chests of its own: this test needs
      -- "a buffer chest in the plan" to mean exactly one thing -- the bad requester pick.
      local plan = planner.plan(force(), choices_with({
        inserter = "fast-inserter", inserter_quality = "rare",
        requester = "buffer-chest", requester_quality = "uncommon",
        container = "iron-chest",
        provider = "storage-chest", provider_quality = "epic",
        buffer_stock = false,
      }))
      assert(plan, "plan failed")
      -- Only the requester and the provider are role-checked against the pick: buffer-chest and
      -- storage-chest are the wrong logistic mode, so both fall back rather than being built.
      assert(count_by_name(plan, "fast-inserter") > 0, "the picked inserter was not planned")
      assert(count_by_name(plan, "bulk-inserter") == 0, "the default inserter survived the pick")
      assert(count_by_name(plan, "iron-chest") > 0, "the picked plain chest was not planned")
      assert(count_by_name(plan, "steel-chest") == 0, "the default plain chest survived the pick")
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
      assert(count_by_name(plan, "steel-chest") > 0, "default plain chest missing")
      -- The stock role's default kind: buffer chests, one per lower tier.
      assert(count_by_name(plan, "buffer-chest") == 2,
        "stock chests " .. count_by_name(plan, "buffer-chest"))
      for _, e in pairs(plan.entities) do
        if e.name == "bulk-inserter" or e.name == "steel-chest" or e.name == "buffer-chest" then
          assert(e.quality == "normal", e.name .. " defaulted to " .. tostring(e.quality))
        end
      end
    end)

    test("unticking buffer chests plans the stock chests as requesters", function()
      local plan = planner.plan(force(), choices_with({ buffer_stock = false }))
      assert(count_by_name(plan, "buffer-chest") == 0, "a buffer chest survived the untick")
      -- The stock chests fold into the requester kind: 3 feed chests + 2 product chests.
      local product_chests = 0
      for _, e in pairs(plan.entities) do
        if e.name == "requester-chest" and e.requests and e.requests[1]
          and e.requests[1].name == "iron-gear-wheel" then
          product_chests = product_chests + 1
        end
      end
      assert(product_chests == 2, "requester-kind stock chests " .. product_chests)
    end)

    test("a stale pick falls back rather than erroring", function()
      -- The belt's rule, one role at a time: a name that is no longer a candidate of that role
      -- is not a signal to place nothing, it is a signal to use the default.
      local plan = planner.plan(force(), choices_with({
        inserter = "stack-inserter", requester = "steel-chest", provider = "iron-chest",
        -- A requester in the stock role is the wrong KIND while the checkbox is on, the
        -- same staleness as the rest -- the flip heals a save whose pick predates a toggle.
        stock = "requester-chest",
      }))
      assert(plan, "a stale pick must not break the plan")
      assert(count_by_name(plan, "stack-inserter") == 0, "a belt-stacker reached the plan")
      assert(count_by_name(plan, "bulk-inserter") > 0, "the inserter did not fall back")
      assert(count_by_name(plan, "requester-chest") == 3, "the requester did not fall back")
      assert(count_by_name(plan, "buffer-chest") == 2, "the stock role did not fall back")
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

  test("an ingredient-amount override replaces the formula; junk falls back", function()
    local function plate_request(plan)
      for _, e in pairs(plan.entities) do
        if e.name == "requester-chest" and e.requests and e.requests[1]
          and e.requests[1].name == "iron-plate" then
          return e.requests[1].count
        end
      end
    end
    local plan = planner.plan(force(), choices_with({ ["request_iron-plate"] = 42 }))
    assert(plate_request(plan) == 42, "the override did not reach the feed chest")
    -- A zero or a non-number cannot come from the panel -- only from a stale save -- and
    -- either reads as "no override" rather than as a request of nothing.
    plan = planner.plan(force(), choices_with({ ["request_iron-plate"] = 0 }))
    assert(plate_request(plan) == 100, "a zero override did not fall back to the formula")
    plan = planner.plan(force(), choices_with({ ["request_iron-plate"] = "junk" }))
    assert(plate_request(plan) == 100, "a non-number override did not fall back to the formula")
  end)

  describe("circuit limits", function()
    local function stack_of(plan)
      return (circuit_stack.of(plan.entities))
    end

    test("off by default: no condition, no circuit wire, anywhere", function()
      local plan = planner.plan(force(), choices_with())
      for _, e in pairs(plan.entities) do
        assert(e.control_behavior == nil, e.name .. " carries a condition with circuits off")
        assert(e.circuit_wire_to == nil, e.name .. " carries a circuit wire with circuits off")
      end
      assert(plan.circuit_unlinked == nil, "an undecorated plan reports a shortfall")
    end)

    test("on: one cap gates every machine and recycler; reserves follow their minimums", function()
      local plain = planner.plan(force(), choices_with())
      local plan = planner.plan(force(), choices_with({
        circuit_enabled = true, circuit_max_rare = 123, circuit_min_uncommon = 25,
      }))
      assert(plan.width == plain.width and plan.height == plain.height,
        "circuits changed the footprint: " .. plan.width .. "x" .. plan.height)
      assert(plan.circuit_unlinked == nil,
        "unlinked " .. tostring(plan.circuit_unlinked) .. " on a vanilla plan")

      -- Every machine and recycler carries the SAME stop: the output chest's count of the
      -- product at the target quality against the cap -- read off the combinator's
      -- signal-C, never a baked number.
      for _, e in pairs(plan.entities) do
        if e.circuit_role == "machine" or e.circuit_role == "recycler" then
          local c = e.control_behavior and e.control_behavior.circuit_condition
          assert(c, e.circuit_role .. " tier " .. e.circuit_tier .. " carries no gate")
          assert(c.first_signal.name == "iron-gear-wheel"
            and c.first_signal.quality == "rare" and c.constant == nil
            and c.second_signal.name == "signal-C" and c.second_signal.quality == "rare",
            e.circuit_role .. " gates on " .. serpent.line(c))
        end
      end

      -- The named minimum reaches its tier's inserter, raised by the hand it is pinned to
      -- -- 12, the bulk inserter's at full research (api.md S33); the unset one (normal,
      -- default 0) keeps nothing back and is left ungated, unwired and unpinned.
      for _, e in pairs(plan.entities) do
        if e.circuit_role == "reserve" and e.circuit_tier == 2 then
          local c = e.control_behavior.circuit_condition
          assert(c.comparator == ">=" and c.first_signal.quality == "uncommon"
            and c.second_signal.name == "signal-M" and c.second_signal.quality == "uncommon",
            "the uncommon reserve gates on " .. serpent.line(c))
          assert(e.override_stack_size == 12,
            "the uncommon reserve is pinned to " .. tostring(e.override_stack_size))
        end
        if e.circuit_role == "reserve" and e.circuit_tier == 1 then
          assert(e.control_behavior == nil and e.circuit_wire_to == nil
            and e.override_stack_size == nil, "a zero-minimum reserve was gated, wired or pinned")
        end
        -- The threshold rides the census chest's request too, or trash-unrequested bots
        -- would hold the count below it forever: gears buffer one stack of 100, plus the
        -- floor, plus the hand.
        if e.circuit_role == "census" and e.circuit_tier == 2 then
          assert(e.requests[1].count == 137,
            "the floored census requests " .. e.requests[1].count)
        end
        if e.circuit_role == "census" and e.circuit_tier == 1 then
          assert(e.requests[1].count == 100,
            "the unfloored census requests " .. e.requests[1].count)
        end
      end

      -- The stack the numbers live on: one combinator carrying exactly the two thresholds
      -- set, its lamps and panel beside it, every one of them on the wire, and switched on
      -- since nothing asked for a pause.
      local stack = stack_of(plan)
      assert(stack.limits and stack.lamp_done and stack.lamp_running and stack.panel,
        "the plan is missing part of its circuit stack")
      for role, e in pairs(stack) do
        assert(e.circuit_wire_to, role .. " is not on the wire")
      end
      local rows = stack.limits.control_behavior.sections.sections[1].filters
      assert(#rows == 2 and rows[1].name == "signal-M" and rows[1].quality == "uncommon"
        and rows[1].count == 37 and rows[2].name == "signal-C" and rows[2].quality == "rare"
        and rows[2].count == 123, "the combinator rows read " .. serpent.line(rows))
      assert(stack.limits.control_behavior.is_on == nil, "an unpaused plan switched the combinator off")
    end)

    test("the hand: the chosen inserter's researched hand by default, the wizard's number when typed", function()
      local function reserve_and_row(overrides)
        local choices = choices_with({
          circuit_enabled = true, circuit_max_rare = 0, circuit_min_uncommon = 25,
        })
        for key, value in pairs(overrides or {}) do choices[key] = value end
        local plan = planner.plan(force(), choices)
        local reserve
        for _, e in pairs(plan.entities) do
          if e.circuit_role == "reserve" and e.circuit_tier == 2 then reserve = e end
        end
        local row = stack_of(plan).limits.control_behavior.sections.sections[1].filters[1]
        return reserve.override_stack_size, row.count
      end
      -- Full research: the planner's own pick is the bulk inserter, 1 + 11 researched; a
      -- picked fast inserter reads 1 + 3 -- the two research families, told apart by `bulk`.
      local pin, row = reserve_and_row()
      assert(pin == 12 and row == 37, "bulk default: pin " .. pin .. ", row " .. row)
      pin, row = reserve_and_row({ inserter = "fast-inserter" })
      assert(pin == 4 and row == 29, "fast default: pin " .. pin .. ", row " .. row)
      -- A typed hand wins, whatever the inserter; junk and zero fall back; the blueprint
      -- field's uint8 caps a wild one.
      pin, row = reserve_and_row({ circuit_hand = 3 })
      assert(pin == 3 and row == 28, "typed 3: pin " .. pin .. ", row " .. row)
      pin, row = reserve_and_row({ circuit_hand = "x" })
      assert(pin == 12 and row == 37, "junk hand: pin " .. pin .. ", row " .. row)
      pin, row = reserve_and_row({ circuit_hand = 0 })
      assert(pin == 12 and row == 37, "zero hand: pin " .. pin .. ", row " .. row)
      pin, row = reserve_and_row({ circuit_hand = 900 })
      assert(pin == 255 and row == 280, "wild hand: pin " .. pin .. ", row " .. row)
    end)

    test("a zero cap through the choices means no cap at all, and no indicators", function()
      -- The planner is the one owner of "zero means off": decorate never sees the zero,
      -- only the absence it becomes. A reserve alone still needs the combinator; the lamps
      -- and the panel would have no cap to read, so they are not stood at all.
      local plan = planner.plan(force(), choices_with({
        circuit_enabled = true, circuit_max_rare = 0, circuit_min_uncommon = 25,
      }))
      for _, e in pairs(plan.entities) do
        if e.circuit_role == "machine" or e.circuit_role == "recycler" then
          assert(e.control_behavior == nil, e.circuit_role .. " gated under a zero cap")
        end
        if e.circuit_role == "reserve" and e.circuit_tier == 2 then
          assert(e.control_behavior, "the reserve must survive a zero cap")
        end
      end
      local stack = stack_of(plan)
      assert(stack.limits and not (stack.lamp_done or stack.lamp_running or stack.panel),
        "a zero cap stood the wrong stack: " .. serpent.line(stack))
      local rows = stack.limits.control_behavior.sections.sections[1].filters
      assert(#rows == 1 and rows[1].name == "signal-M", "an uncapped combinator wrote a cap row")
    end)

    test("every threshold zero stands no combinator: the plan is the circuits-off one", function()
      local plan = planner.plan(force(), choices_with({
        circuit_enabled = true, circuit_max_rare = 0,
      }))
      assert(next(stack_of(plan)) == nil, "an all-zero plan stood a circuit stack")
      for _, e in pairs(plan.entities) do
        assert(e.control_behavior == nil and e.circuit_wire_to == nil,
          e.name .. " carries circuitry with every threshold at zero")
      end
    end)

    test("Start paused ships the combinator switched off, and only through the cap", function()
      local paused = planner.plan(force(), choices_with({
        circuit_enabled = true, circuit_max_rare = 50, circuit_paused = true,
      }))
      assert(stack_of(paused).limits.control_behavior.is_on == false,
        "Start paused left the combinator on")
      -- No cap, nothing the switch could pause: the flag is inert rather than half-honoured.
      local uncapped = planner.plan(force(), choices_with({
        circuit_enabled = true, circuit_max_rare = 0, circuit_min_uncommon = 25,
        circuit_paused = true,
      }))
      assert(stack_of(uncapped).limits.control_behavior.is_on == nil,
        "Start paused switched off a combinator that carries no cap")
    end)
  end)

  describe("columns per tier", function()
    test("untouched choices and explicit ones build the same plan, field for field", function()
      -- The feature's determinism promise: a player who never opens the wizard gets exactly
      -- the plan the mod always built, and a stored 1 means the same as no key at all.
      assert(deep_equal(planner.plan(force(), choices_with()),
          planner.plan(force(), choices_with({
            column_count_normal = 1, column_count_uncommon = 1,
          }))),
        "explicit ones diverged from the untouched plan")
    end)

    test("a repeated lower tier is that many full columns", function()
      local plan = planner.plan(force(),
        choices_with({ column_count_normal = 3, no_poles = true }))
      assert(plan.width == 17, "width " .. plan.width .. ", expected 11 + two more pitches")
      assert(plan.machines == 5, "machines " .. plan.machines)
      assert(plan.recyclers == 4, "recyclers " .. plan.recyclers)
      assert(count_by_name(plan, "assembling-machine-3") == 5, "machine entities")
      assert(count_by_name(plan, "recycler") == 4, "recycler entities")
      assert(count_by_name(plan, "requester-chest") == 5, "one feed chest per column")
      -- One way out however many columns: the target stays a single column.
      assert(count_by_name(plan, "passive-provider-chest") == 1, "output chests")
      assert(count_by_name(plan, "assembling-machine-3", "normal") == 3,
        "normal-tier machines")
    end)

    test("the pole pass still covers a widened plan", function()
      local plan = planner.plan(force(), choices_with({
        column_count_normal = 3, pole = "medium-electric-pole",
      }))
      assert(plan, "plan failed")
      assert(plan.unpowered == nil, "unpowered " .. tostring(plan.unpowered))
    end)

    test("a stray count for the target tier is structurally ignored", function()
      -- The expansion never visits the target's own index, so a column_count_<target> key
      -- left by an earlier, different target changes nothing at all. Junk and zero values
      -- fall back the same way -- pinned at the unit level in planner_spec's tier_columns
      -- coverage, so only the plan-level target contract is re-proven here.
      assert(deep_equal(planner.plan(force(), choices_with()),
          planner.plan(force(), choices_with({ column_count_rare = 5 }))),
        "a target-tier count reached the plan")
    end)

    test("fractions floor and the ceiling clamps, all the way into the plan", function()
      local floored = planner.plan(force(),
        choices_with({ column_count_normal = 2.7, no_poles = true }))
      assert(floored.machines == 4, "a fractional count did not floor: " .. floored.machines)
      local clamped = planner.plan(force(),
        choices_with({ column_count_normal = 9999, no_poles = true }))
      assert(clamped.machines == planner.MAX_COLUMNS_PER_TIER + 2,
        "the ceiling did not clamp: " .. clamped.machines)
    end)

    test("more columns on the slow tier quicken the pace; the yield never moves", function()
      local one = planner.plan(force(), choices_with())
      local three = planner.plan(force(), choices_with({ column_count_normal = 3 }))
      assert(one.seconds and three.seconds, "the pace line went missing")
      assert(three.seconds < one.seconds,
        "three normal columns should beat one: " .. three.seconds .. " vs " .. one.seconds)
      assert(one.yield.per_item == three.yield.per_item,
        "columns changed the per-item yield, which they must never do")
    end)

    test("columns on a tier that is not the bottleneck leave the pace alone", function()
      -- The pace is the slowest station's; gears' normal tier carries the bulk of the
      -- expected crafts, so repeating uncommon divides a time that was not binding.
      local one = planner.plan(force(), choices_with())
      local wide = planner.plan(force(), choices_with({ column_count_uncommon = 3 }))
      assert(wide.seconds == one.seconds,
        "a non-bottleneck tier moved the pace: " .. wide.seconds .. " vs " .. one.seconds)
    end)

    test("circuits gate every repeated column independently", function()
      local plan = planner.plan(force(), choices_with({
        column_count_normal = 2, circuit_enabled = true,
        circuit_max_rare = 100, circuit_min_normal = 10,
      }))
      assert(plan.circuit_unlinked == nil,
        "unlinked " .. tostring(plan.circuit_unlinked))
      local normal_reserves, seen_tiers = 0, {}
      for _, e in pairs(plan.entities) do
        if e.circuit_role then
          assert(not (e.circuit_role == "machine" and seen_tiers[e.circuit_tier]),
            "circuit_tier " .. tostring(e.circuit_tier) .. " repeats on machines")
          if e.circuit_role == "machine" then seen_tiers[e.circuit_tier] = true end
        end
        if e.circuit_role == "reserve" then
          local c = e.control_behavior and e.control_behavior.circuit_condition
          if c and c.first_signal.quality == "normal" then
            assert(c.second_signal.name == "signal-M" and c.second_signal.quality == "normal",
              "a normal reserve gates on " .. serpent.line(c.second_signal))
            normal_reserves = normal_reserves + 1
          end
        end
      end
      assert(normal_reserves == 2,
        "gated normal reserves " .. normal_reserves .. ", expected one per column")
      -- Both read one summed count and can grab on the same reading, so the one M row
      -- carries the minimum plus a bulk hand (12 at full research) per column.
      local rows = circuit_stack.of(plan.entities).limits.control_behavior.sections.sections[1].filters
      assert(rows[1].name == "signal-M" and rows[1].quality == "normal" and rows[1].count == 10 + 2 * 12,
        "the two-column normal row reads " .. serpent.line(rows[1]))
    end)
  end)
end)
