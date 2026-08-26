-- planner.lua derivations and validate(), against real prototypes and a real force.
-- This is the H1/H3/H4 harness matrix made permanent: producer guards across research states,
-- picker gating, the inserter rules, and every refusal message reachable without a fixture mod.
-- Assertion values assume the SA modset (base + quality + recycler + space-age + elevated-rails),
-- which is what the factorio-testing skill's runner loads and what the dev install carries.

local util = require("util")
local planner = require("scripts.planner")
local research = require("tests.support.research")

local function force()
  return game.forces.player
end

describe("upcyclability -- prototype-level, research-free", function()
  test("iron gear wheel and battery loop; steel plate, two-fluid and recycling recipes do not", function()
    assert(planner.is_upcyclable(prototypes.recipe["iron-gear-wheel"]), "gears must loop")
    -- One fluid ingredient rides the pipe header since 0.2.0.
    assert(planner.is_upcyclable(prototypes.recipe["battery"]), "battery must loop now")
    -- Steel's recycling is the lossy self-recycling fallback, not a reversal.
    assert(not planner.is_upcyclable(prototypes.recipe["steel-plate"]), "steel must not loop")
    -- Sulfur takes TWO fluids (water + petroleum gas) and has no item ingredients at all --
    -- refused twice over, and the multi-fluid gate answers first.
    assert(not planner.is_upcyclable(prototypes.recipe["sulfur"]), "two-fluid recipe must not loop")
    -- A recycling recipe trivially "closes the loop" while producing nothing (fact 4).
    assert(not planner.is_upcyclable(prototypes.recipe["iron-gear-wheel-recycling"]),
      "recycling recipes must never count as upcyclable")
  end)

  test("the offered item list holds exactly the known 212", function()
    -- FORKED on legacy/2.0, declared in the repo CLAUDE.md divergent-files list: the 2.0
    -- track's base list was 187 where 2.1's was 185 (measured 2026-08-16), and the 0.2.0
    -- fluid support admits 25 single-fluid items on top -- 212, measured on this branch
    -- (2026-08-17), never derived from the 2.1 number. A drift in either direction still
    -- means an eligibility rule changed by accident.
    local count = #planner.upcyclable_items()
    assert(count == 212, "upcyclable item count " .. count .. ", expected 212 on the 2.0 track")
  end)

  test("recipe_for_item derives the canonical recipe", function()
    assert(planner.recipe_for_item("iron-gear-wheel") == "iron-gear-wheel")
    assert(planner.recipe_for_item("not-an-item") == nil)
  end)

  test("the quality chain runs normal to legendary; targets skip normal", function()
    local chain = planner.quality_chain()
    assert(#chain == 5, "chain length " .. #chain)
    assert(chain[1] == "normal" and chain[5] == "legendary", "chain order wrong")
    local targets = planner.target_qualities()
    assert(#targets == 4 and targets[1] == "uncommon", "targets wrong")
    local tiers = planner.tiers_up_to("rare")
    assert(#tiers == 3 and tiers[3] == "rare", "tiers_up_to rare wrong")
    assert(planner.tiers_up_to("not-a-quality") == nil, "unknown target must yield nil")
    assert(planner.build_quality("rare") == "rare")
    assert(planner.build_quality("not-a-quality") == "normal",
      "a stale build quality must read as normal")
  end)

  test("the chain walk has no tier ceiling, and a circular chain terminates", function()
    -- The walk used to be bounded by a fixed iteration count, which capped the chain at 32 and
    -- silently dropped every tier a big quality mod adds above it -- infinite-quality-tiers-plus
    -- stops dead at its 32nd. Stub nodes carry the three fields the walk reads, the way the
    -- modded recycler below is stubbed rather than fixtured.
    local nodes = {}
    for i = 1, 100 do nodes[i] = { name = "q-" .. i, hidden = i % 10 == 0 } end
    for i = 1, 99 do nodes[i].next = nodes[i + 1] end

    local long = planner.walk_quality_chain(nodes[1])
    assert(#long == 90, "long chain length " .. #long .. ", expected 90")
    assert(long[1] == "q-1" and long[90] == "q-99", "long chain ends at " .. tostring(long[90]))

    -- A malformed mod could close the list into a loop; the walk must stop at the first name it
    -- has already seen rather than hang the game.
    nodes[100].next = nodes[1]
    assert(#planner.walk_quality_chain(nodes[1]) == 90, "cycle guard failed")

    -- The case the count bound was really buying: a cycle of entirely HIDDEN tiers grows the
    -- chain by nothing, so a bound on chain LENGTH would never trip and the walk would spin.
    local a = { name = "hidden-a", hidden = true }
    local b = { name = "hidden-b", hidden = true, next = a }
    a.next = b
    assert(#planner.walk_quality_chain(a) == 0, "an all-hidden cycle must terminate empty")
  end)

  test("an east-flank thrower is stood facing west, any width fits", function()
    -- Age of Production's salvager, as a stub -- recycler_orientation reads only these three
    -- fields, so the historic modded-recycler scenario needs no fixture mod. Authored throwing
    -- east out of a 4x4; the rotation that lands the throw in the row above is west.
    local salvager = { vector_to_place_result = { 2.35, -0.5 }, tile_width = 4, tile_height = 4 }
    local o = planner.recycler_orientation(salvager)
    assert(o, "no orientation found for the east thrower")
    assert(o.direction == defines.direction.west, "direction " .. tostring(o.direction))
    assert(o.width == 4 and o.height == 4, "footprint " .. o.width .. "x" .. o.height)
    assert(o.eject_col == 1, "eject column " .. o.eject_col)

    -- No eject vector, or a footprint below the layout's floor: no orientation at all.
    assert(planner.recycler_orientation({ tile_width = 2, tile_height = 4 }) == nil,
      "an entity with no eject vector cannot serve")
    assert(planner.recycler_orientation({
      vector_to_place_result = { -0.35, -2.3 }, tile_width = 1, tile_height = 4,
    }) == nil, "a 1-wide recycler is below the layout's floor")
  end)

  test("the vanilla recycler ejects north out of a 2x4 footprint", function()
    -- Fact 3: vector_to_place_result {-0.35, -2.3} lands the throw in the row above at
    -- column 0 with no rotation. This is the geometry the whole layout hangs off.
    local o = planner.recycler_orientation(prototypes.entity["recycler"])
    assert(o, "vanilla recycler has no working orientation")
    assert(o.direction == defines.direction.north, "direction " .. tostring(o.direction))
    assert(o.width == 2 and o.height == 4, "footprint " .. o.width .. "x" .. o.height)
    assert(o.eject_col == 0, "eject column " .. o.eject_col)
  end)

  test("machine fluid orientations: the measured rotation per vanilla prototype", function()
    -- The measured rule (api.md §14): a connection authored pointing `dir` points
    -- `(dir + rotation) % 16` once rotated, and one west-pointing input is enough because
    -- the engine merges every input box the recipe needs and any connection feeds it.
    local function facing(name)
      local o = planner.machine_fluid_orientation(prototypes.entity[name])
      return o and o.direction
    end
    assert(facing("assembling-machine-3") == defines.direction.west, "AM3 must face west")
    assert(facing("chemical-plant") == defines.direction.west, "chemical plant must face west")
    assert(facing("biochamber") == defines.direction.west, "biochamber must face west")
    -- Foundry and cryo plant author their inputs on the SOUTH face; east swings them west.
    assert(facing("foundry") == defines.direction.east, "foundry must face east")
    assert(facing("cryogenic-plant") == defines.direction.east, "cryo plant must face east")
    -- The EM plant already has a west input; north-first means it is never rotated.
    assert(facing("electromagnetic-plant") == defines.direction.north, "EM plant must stay north")
    -- No fluid boxes at all: nothing to orient.
    assert(planner.machine_fluid_orientation(prototypes.entity["assembling-machine-1"]) == nil,
      "a machine without fluid boxes cannot orient")
  end)
end)

describe("producer guards across research states", function()
  after_all(function() research.full(force()) end)

  test("recycling research alone unlocks nothing buildable", function()
    -- The H1 regression: quality-module-3-recycling PRODUCES quality-module-2, so a naive
    -- "some enabled recipe makes it" test reads unresearched modules as unlocked the moment
    -- recycling is researched.
    research.only(force(), { "recycling" })
    assert(not planner.is_unlocked(force(), "quality-module-2"),
      "recycling-only research must not unlock quality-module-2")
    local offered = planner.unlocked_upcyclable_items(force())
    for _, item in pairs(offered) do
      assert(item ~= "quality-module-2", "quality-module-2 offered from recycling alone")
    end
  end)

  test("a single enabled real recipe is enough", function()
    research.fresh(force())
    assert(not planner.is_unlocked(force(), "quality-module-2"), "fresh force has module 2?")
    research.enable_recipe(force(), "quality-module-2")
    assert(planner.is_unlocked(force(), "quality-module-2"),
      "per-recipe unlock not seen by the producer map")
  end)

  test("cheat mode unlocks through real recipes", function()
    research.cheat(force())
    assert(planner.is_unlocked(force(), "quality-module-2"), "cheat mode missed a real recipe")
  end)

  test("full research offers the whole list", function()
    research.full(force())
    assert(#planner.unlocked_upcyclable_items(force()) == #planner.upcyclable_items(),
      "full research must offer every upcyclable item")
  end)
end)

describe("the inserter rules", function()
  after_all(function() research.full(force()) end)

  test("fresh force: everything with power needs fuel", function()
    research.fresh(force())
    assert(planner.inserter(force(), 1) == nil, "fresh force found an electric inserter")
    assert(planner.any_inserter(force(), 1) ~= nil,
      "the burner inserter should qualify once fuel is ignored")
  end)

  test("automation only: the long-handed inserter must not win", function()
    -- The H4 defect: reach 2, electric, faster-rotating, unlocked by the very first
    -- technology -- and useless in a layout whose rows are adjacent. The candidate table
    -- admits one-tile reach only, and any_inserter inherits the rule so the fuel message
    -- stays truthful in exactly this window.
    research.only(force(), { "automation" })
    assert(planner.inserter(force(), 1) == nil, "long-handed inserter won the pick")
    assert(planner.any_inserter(force(), 1) ~= nil, "burner fallback lost the reach rule")
  end)

  test("electronics unlocks the plain electric inserter", function()
    research.only(force(), { "electronics" })
    assert(planner.inserter(force(), 1) == "inserter",
      "expected the plain inserter, got " .. tostring(planner.inserter(force(), 1)))
  end)

  test("full research picks a bulk inserter; impossible filter demands stay nil", function()
    research.full(force())
    local best = planner.inserter(force(), 1)
    assert(best, "no inserter at full research")
    assert(prototypes.entity[best].bulk, best .. " is not a bulk inserter")
    assert(planner.inserter(force(), 99) == nil, "no inserter can filter 99 ingredients")
    assert(planner.any_inserter(force(), 99) == nil, "any_inserter ignored the filter demand")
  end)

  test("the picker list is the electric, one-tile, non-stacking set", function()
    research.full(force())
    local offered = util.list_to_map(planner.inserters())

    -- The three exclusions, each with its premise asserted loudly: if a prototype's shape ever
    -- changes, revisit the rule rather than letting this spec pass hollow.
    assert(offered["fast-inserter"] and offered["bulk-inserter"],
      "the ordinary electric inserters must be offered")
    assert(prototypes.entity["long-handed-inserter"], "SA modset should carry the long-handed one")
    assert(not offered["long-handed-inserter"], "a reach-2 inserter cannot serve adjacent rows")
    assert((prototypes.entity["stack-inserter"].inserter_max_belt_stack_size or 1) > 1,
      "stack-inserter stopped belt-stacking -- revisit the exclusion and this spec")
    assert(not offered["stack-inserter"], "a belt-stacking inserter must never be offered")
    assert(prototypes.entity["burner-inserter"].burner_prototype, "the burner inserter burns fuel")
    assert(not offered["burner-inserter"],
      "a fuelled inserter must never be offered -- nothing in the plan refuels it")

    -- Membership is the same set, which is what state.prune tests a remembered pick against.
    assert(planner.is_inserter("fast-inserter"), "is_inserter missed a real candidate")
    assert(not planner.is_inserter("stack-inserter"), "is_inserter admitted a stacker")
    assert(not planner.is_inserter("burner-inserter"), "is_inserter admitted a burner")
    assert(not planner.is_inserter("iron-chest"), "is_inserter admitted a chest")

    -- Filter slots: five on every vanilla inserter, and nil for anything not offered, which is
    -- what makes "nothing chosen" and "a chosen inserter that cannot filter" different answers.
    assert(planner.inserter_filter_count("fast-inserter") == 5, "vanilla filter slots")
    assert(planner.inserter_filter_count("burner-inserter") == nil, "a non-candidate has no count")
    assert(planner.inserter_filter_count(nil) == nil, "nothing chosen has no count")
  end)

  test("belt-stacking inserters are never candidates", function()
    research.full(force())
    -- Guard the premise loudly: the stack inserter is bulk and electric, so the belt-stack
    -- rule is the only thing keeping it out of the pick. If its shape ever changes, revisit
    -- the exclusion instead of letting this spec pass hollow.
    local stack = prototypes.entity["stack-inserter"]
    assert(stack and stack.bulk, "SA modset should carry the bulk stack-inserter")
    assert((stack.inserter_max_belt_stack_size or 1) > 1,
      "stack-inserter stopped belt-stacking -- revisit the exclusion and this spec")
    local best = planner.inserter(force(), 1)
    assert(best, "no inserter at full research")
    assert((prototypes.entity[best].inserter_max_belt_stack_size or 1) <= 1,
      best .. " builds belt stacks and must never be planned")
  end)
end)

describe("modules the machine and recipe accept", function()
  before_all(function() research.full(force()) end)

  -- The measured rule (api.md S16): only the effects a module applies POSITIVELY have to be
  -- allowed. Both halves are asserted against real prototypes whose allowed_effects differ, so a
  -- vanilla retune of either shows up here rather than as a module nothing can fill.
  test("a positive effect must be allowed; a negative side effect need not be", function()
    local refinery = prototypes.entity["oil-refinery"]
    local recycler = prototypes.entity["recycler"]
    assert(not refinery.allowed_effects["quality"], "test premise: refinery must refuse quality")
    assert(not recycler.allowed_effects["productivity"],
      "test premise: recycler must refuse productivity")

    -- The speed module carries quality -0.025, and the refinery still takes it (measured).
    assert(planner.accepts_module(refinery, prototypes.item["speed-module-3"]),
      "a negative quality component must not exclude a speed module")
    assert(not planner.accepts_module(refinery, prototypes.item["quality-module-3"]),
      "a quality module cannot go where quality is refused")
    assert(not planner.accepts_module(recycler, prototypes.item["productivity-module-3"]),
      "a productivity module cannot go where productivity is refused")
    -- The efficiency module's only effect is negative, so nothing can exclude it.
    assert(planner.accepts_module(refinery, prototypes.item["efficiency-module-3"]),
      "an all-negative module must be accepted anywhere")
  end)

  test("the offered list is what the pair accepts, and nothing else", function()
    -- Gears allow productivity; wooden chests do not (allow_productivity defaults to false), so
    -- the same machine offers a different list per recipe -- which is the whole point of the pair.
    local machine = prototypes.entity["assembling-machine-3"]
    local function offered(recipe_name)
      return util.list_to_map(planner.modules_for(machine, prototypes.recipe[recipe_name]))
    end

    local gears = offered("iron-gear-wheel")
    assert(gears["productivity-module-3"], "gears allow productivity: it must be offered")
    assert(gears["quality-module-3"] and gears["speed-module-3"] and gears["efficiency-module-3"],
      "the other three categories must be offered too")

    local chests = offered("wooden-chest")
    assert(not chests["productivity-module-3"],
      "a recipe that refuses productivity must not offer productivity modules")
    assert(chests["speed-module-3"], "a refused productivity does not refuse speed")

    -- module_fits is the same question by name, which is what the modal re-picks on.
    assert(planner.module_fits("productivity-module-3", machine, prototypes.recipe["iron-gear-wheel"]))
    assert(not planner.module_fits("productivity-module-3", machine, prototypes.recipe["wooden-chest"]))
    assert(not planner.module_fits("iron-plate", machine, prototypes.recipe["iron-gear-wheel"]),
      "a plain item is not a module")
    assert(not planner.module_fits(nil, machine, prototypes.recipe["iron-gear-wheel"]),
      "nothing chosen fits nothing")
  end)

  test("the terminal default is a productivity module, or nothing at all", function()
    local machine = prototypes.entity["assembling-machine-3"]
    assert(planner.terminal_module(force(), machine, prototypes.recipe["iron-gear-wheel"])
      == "productivity-module-3", "the strongest researched productivity module must win")
    -- The rule the picker exists to make visible: no productivity allowed means no module, NOT a
    -- quality module -- which is what the first version quietly fell back to.
    assert(planner.terminal_module(force(), machine, prototypes.recipe["wooden-chest"]) == nil,
      "a recipe refusing productivity must default to nothing")
  end)

  test("is_module is membership in every module, not in a role", function()
    assert(planner.is_module("productivity-module-3") and planner.is_module("efficiency-module"),
      "real modules must be members")
    assert(not planner.is_module("iron-plate"), "a plate is not a module")
    assert(#planner.modules() == 12,
    "the SA modset ships twelve modules -- four families of three; got " .. #planner.modules())
  end)
end)

describe("the beacon and its module", function()
  before_all(function() research.full(force()) end)

  test("membership and the offered list", function()
    assert(planner.is_beacon("beacon"), "the vanilla beacon must be a candidate")
    assert(not planner.is_beacon("medium-electric-pole"), "a pole is not a beacon")
    assert(util.list_to_map(planner.beacons())["beacon"], "the picker list must offer the beacon")
  end)

  test("the beacon takes speed and efficiency, refuses quality and productivity", function()
    -- The S16 rule with the beacon as the holder and a nil recipe -- modules_for and
    -- module_fits serve the beacon through the same nil-recipe convention module_refusal
    -- established, so there is no beacon-only copy to drift. The premise is asserted so a
    -- vanilla retune of allowed_effects fails loudly here.
    local beacon = prototypes.entity["beacon"]
    assert(not beacon.allowed_effects["quality"], "test premise: the beacon must refuse quality")
    local offered = util.list_to_map(planner.modules_for(beacon))
    assert(offered["speed-module-3"] and offered["efficiency-module-3"],
      "speed and efficiency must be offered")
    assert(not offered["quality-module-3"], "a quality module can never enter a vanilla beacon")
    assert(not offered["productivity-module-3"], "nor can a productivity module")
    assert(planner.module_fits("speed-module", beacon), "fits must agree with the list")
    assert(not planner.module_fits("quality-module", beacon), "fits let quality through")
    assert(not planner.module_fits("iron-plate", beacon), "a plain item is not a module")
    assert(not planner.module_fits(nil, beacon), "nothing chosen fits nothing")
  end)

  test("the beacon module default is the strongest researched efficiency module", function()
    -- Never speed: its negative quality side effect transmits to everything the beacon
    -- reaches, and this loop exists to roll quality. Scored by effect, not category name.
    assert(planner.beacon_module(force(), prototypes.entity["beacon"]) == "efficiency-module-3",
      "the default must be the strongest efficiency module")
  end)

  test("beacon_reach: the measured edge rule as pure maths", function()
    -- Vanilla numbers: margins 0.3, the beacon flush against its tier column. The measured
    -- rule (tests/beacon_spec.lua) is collision box grown by the supply distance, overlap
    -- counts -- so vanilla's supply of 3 covers the pair easily, and the failure cases need
    -- either a tiny supply or a modded-tall recycler.
    local machine = { width = 3, height = 3, margin = 0.3 }
    local recycler = { width = 2, height = 4, margin = 0.3 }
    local function beacon(supply)
      return { width = 3, height = 3, margin = 0.3, supply = supply }
    end
    assert(planner.beacon_reach(beacon(3), machine, recycler, false),
      "vanilla reach must cover the vanilla pair")
    assert(planner.beacon_reach(beacon(3), machine, recycler, true),
      "the pipe's one-tile shift must not break vanilla reach")
    assert(planner.beacon_reach(beacon(3), machine, nil, false),
      "the terminal band is the easier case and must pass")
    assert(not planner.beacon_reach(beacon(0.5), machine, recycler, false),
      "a supply shorter than the gap to the machine cannot reach")
    -- A modded-tall recycler pushes the band's centre far from both ends: covering the middle
    -- of the band is not covering the pair, which is why the check tests both boxes.
    assert(not planner.beacon_reach(beacon(3), machine,
      { width = 2, height = 20, margin = 0.3 }, false),
      "a 20-tall recycler must put the pair out of a vanilla beacon's reach")
  end)

  test("beacon_reach over a stack: some beacon reaches each end", function()
    -- The 20-tall recycler that defeats one centred beacon (above) is exactly what a stack
    -- fixes: the block spreads along the band until its top beacon overlaps the machine and
    -- its bottom one the recycler -- different beacons satisfying the two halves is the
    -- point. Counts one and three still centre too far from the machine; four is the first
    -- stack tall enough. Pure maths, the fixtures above.
    local machine = { width = 3, height = 3, margin = 0.3 }
    local tall = { width = 2, height = 20, margin = 0.3 }
    local beacon = { width = 3, height = 3, margin = 0.3, supply = 3 }
    assert(not planner.beacon_reach(beacon, machine, tall, false, 1), "one beacon cannot span")
    assert(not planner.beacon_reach(beacon, machine, tall, false, 3), "three still centre short")
    assert(planner.beacon_reach(beacon, machine, tall, false, 4),
      "a four-stack must reach both ends of the tall band")
  end)

  test("planner.max_beacon_count answers the modal from real prototypes", function()
    local choices = {
      recipe = "iron-gear-wheel", machine = "assembling-machine-2", recycler = "recycler",
    }
    local max = planner.max_beacon_count(choices, prototypes.entity["beacon"])
    assert(max == 4, "vanilla max " .. max .. ", expected floor(13 / 3) = 4")
    assert(planner.max_beacon_count({}, prototypes.entity["beacon"]) == 0,
      "nothing picked yet must answer zero")
  end)
end)

describe("the chest roles", function()
  before_all(function() research.full(force()) end)

  test("each role offers only 1x1 chests in its own logistic mode", function()
    for _, role in pairs(planner.CHEST_ROLES) do
      -- Buffered, so the stock role lists its own kind here; its unbuffered kind is the
      -- requester list by construction, pinned in the membership test below.
      local names = planner.chests(role, true)
      assert(#names > 0, "no chests offered for role " .. role)
      for _, name in pairs(names) do
        local entity = prototypes.entity[name]
        assert(entity.tile_width == 1 and entity.tile_height == 1,
          name .. " is not 1x1 -- the layout's chest positions are one tile")
        if role == "container" then
          assert(entity.type == "container" and not entity.logistic_mode,
            name .. " talks to the logistic network and must not be a plain chest")
        else
          -- One logistic mode per role, named rather than derived: the overflow chest has to be
          -- an ACTIVE provider, because it is the only sink in the loop that empties itself.
          local modes = {
            requester = "requester",
            stock = "buffer",
            provider = "passive-provider",
            overflow = "active-provider",
          }
          local mode = modes[role]
          assert(mode, "role " .. role .. " has no expected logistic mode")
          assert(entity.type == "logistic-container" and entity.logistic_mode == mode,
            name .. " is not a " .. mode .. " chest")
        end
      end
    end
  end)

  test("membership is per role: a requester chest is not a buffer, and vice versa", function()
    assert(planner.is_chest("requester-chest", "requester"), "requester membership")
    assert(not planner.is_chest("requester-chest", "container"),
      "a logistic chest must never pass as the plain chest")
    assert(not planner.is_chest("steel-chest", "requester"), "a plain chest is no requester")
    assert(not planner.is_chest("passive-provider-chest", "requester"), "roles must not blur")
    -- The stock role's membership follows the buffered flag: each kind admits only itself.
    assert(planner.is_chest("buffer-chest", "stock", true), "buffered stock membership")
    assert(not planner.is_chest("requester-chest", "stock", true),
      "a requester passed the buffered stock role")
    assert(planner.is_chest("requester-chest", "stock", false), "unbuffered stock membership")
    assert(not planner.is_chest("buffer-chest", "stock", false),
      "a buffer chest passed the unbuffered stock role")
    -- An infinity chest reports a logistic_mode too, and a chest that conjures items out of
    -- nothing is never a correct buffer in a loop whose job is to conserve one population.
    assert(not planner.is_chest("infinity-chest", "provider"), "infinity chest admitted")
  end)
end)

describe("the building-material picks at full research", function()
  before_all(function() research.full(force()) end)

  test("machine, recycler, belt, pole, chests, module", function()
    local f = force()
    assert(planner.best_machine(f, prototypes.recipe["iron-gear-wheel"]) == "assembling-machine-3",
      "best machine for gears")
    assert(planner.best_recycler(f) == "recycler", "best recycler")
    assert(planner.belt(f) == "turbo-transport-belt", "fastest researched belt (SA modset)")
    -- 1x1 with the largest supply area; the substation is pickable but never the default.
    assert(planner.pole(f) == "medium-electric-pole", "default pole")
    assert(planner.chest(f, "container") == "steel-chest", "plain chest pick")
    assert(planner.chest(f, "requester") == "requester-chest", "requester pick")
    assert(planner.chest(f, "stock", true) == "buffer-chest", "buffered stock pick")
    assert(planner.chest(f, "stock", false) == "requester-chest", "unbuffered stock pick")
    assert(planner.chest(f, "provider") == "passive-provider-chest", "provider pick")
    assert(planner.quality_module(f) == "quality-module-3", "strongest quality module")
    assert(planner.pipe(f) == "pipe", "pipe pick")
    -- Wube's own pair follows the <pipe>-to-ground convention, so the guess lands first.
    assert(planner.pipe_to_ground_for(f, "pipe") == "pipe-to-ground", "underground pipe pick")
    assert(planner.pipe_to_ground_for(f, nil) == "pipe-to-ground",
      "the fallback search must still find vanilla's underground pipe")
    assert(planner.is_pipe("pipe") and not planner.is_pipe("transport-belt"), "is_pipe membership")
  end)

  test("unlocked targets are the four above normal", function()
    assert(#planner.unlocked_targets(force()) == 4, "target qualities at full research")
  end)
end)

describe("validate", function()
  before_all(function() research.full(force()) end)

  -- `{ machine = nil }` is an empty table in Lua, so removing a default takes a sentinel.
  local NONE = "<none>"

  local function choices_with(overrides)
    local choices = {
      recipe = "iron-gear-wheel", quality = "rare",
      machine = "assembling-machine-2", recycler = "recycler",
    }
    for key, value in pairs(overrides or {}) do
      if value == NONE then choices[key] = nil else choices[key] = value end
    end
    return choices
  end

  local function refusal(overrides)
    local ok, message, gathered = planner.validate(force(), choices_with(overrides))
    assert(not ok, "expected a refusal")
    assert(message, "refusal carried no message")
    assert(gathered == nil, "a refusal must not return gathered resources")
    return message[1]
  end

  test("a valid set of choices passes with no message and gathered resources", function()
    local ok, message, gathered = planner.validate(force(), choices_with())
    assert(ok == true, "validate refused a valid set")
    assert(message == nil, "unexpected warning: " .. tostring(message and message[1]))
    assert(gathered and gathered.inserter and gathered.belt and gathered.requester,
      "ok without the gathered resources plan() reuses")
  end)

  test("each refusal names its reason", function()
    assert(refusal({ recipe = NONE }) == "upl-gui.pick-a-recipe", "missing recipe")
    assert(refusal({ recipe = "sulfur" }) == "upl-message.too-many-fluids", "two-fluid recipe")
    assert(refusal({ recipe = "steel-plate" }) == "upl-message.recycling-mismatch",
      "self-recycling item")
    assert(refusal({ machine = NONE }) == "upl-message.no-machine-available", "missing machine")
    assert(refusal({ machine = "steel-furnace" }) == "upl-message.no-module-slots",
      "machine without module slots")
    assert(refusal({ machine = "electromagnetic-plant" }) == "upl-message.no-machine-available",
      "machine that cannot craft the recipe")
    assert(refusal({ recycler = NONE }) == "upl-message.no-recycler", "missing recycler")
    assert(refusal({ recycler = "assembling-machine-1" }) == "upl-message.no-recycler",
      "non-recycler in the recycler slot")
  end)

  test("a beacon pick validates clean; a refused module names the beacon; stale reads as off", function()
    local ok, message = planner.validate(force(), choices_with({ beacon = "beacon" }))
    assert(ok == true, "a plain beacon pick must validate")
    assert(message == nil, "unexpected warning: " .. tostring(message and message[1]))
    -- The module answers to the beacon alone -- and a vanilla beacon refuses quality modules
    -- outright, so a remembered pick from a departed modded beacon must be named, not planned.
    assert(refusal({ beacon = "beacon", beacon_module = "quality-module-3" })
      == "upl-message.module-not-accepted", "the beacon must refuse a quality module by name")
    -- A stale or wrong-kind beacon name means off, never a substitute or a refusal.
    local stale_ok, stale_message = planner.validate(force(),
      choices_with({ beacon = "stone-wall" }))
    assert(stale_ok == true and stale_message == nil, "a stale beacon must read as off")
  end)

  test("a beacon count validates clean at the max, over it, and below one", function()
    -- The count clamps, never refuses: over-asked snaps to the geometric max, non-positive
    -- reads as one. All three must pass without so much as a warning.
    for _, count in pairs({ 4, 99, 0 }) do
      local ok, message = planner.validate(force(),
        choices_with({ beacon = "beacon", beacon_count = count }))
      assert(ok == true, "count " .. count .. " refused")
      assert(message == nil,
        "count " .. count .. " warned: " .. tostring(message and message[1]))
    end
  end)

  test("a recipe no inserter can filter blames the recipe, picked or not", function()
    -- Filter slots are needed one per ingredient, and there is exactly one vanilla upcyclable
    -- recipe that needs more than the five every vanilla inserter carries: fusion reactor
    -- equipment, at six (measured against the data dump, 2026-08-17). Since NOTHING available can
    -- serve it, the message must blame the recipe whether or not an inserter was picked -- naming
    -- the pick would advise a fix that does not exist here.
    --
    -- The by-name refusal on the other side of that gate needs a modded inserter with more slots
    -- to reach, so it is deliberately not covered by a spec; it is the branch below in
    -- validate(), reached only when any_inserter finds something the pick is worse than.
    local ingredients = #planner.item_ingredients(prototypes.recipe["fusion-reactor-equipment"])
    assert(ingredients == 6, "test premise: expected six ingredients, got " .. ingredients)
    assert(planner.any_inserter(force(), ingredients) == nil,
      "test premise: no vanilla inserter should have six filter slots")

    local base = { recipe = "fusion-reactor-equipment", machine = "assembling-machine-3" }
    assert(refusal(base) == "upl-message.too-many-ingredients", "unpicked shortfall")
    local picked = { recipe = base.recipe, machine = base.machine, inserter = "fast-inserter" }
    assert(refusal(picked) == "upl-message.too-many-ingredients",
      "a pick must not turn an impossible recipe into advice about the pick")
  end)

  test("a fresh force fails on inserters first, with the fuel message", function()
    research.fresh(force())
    local ok, message = planner.validate(force(), choices_with())
    research.full(force())
    assert(not ok, "fresh force validated")
    assert(message[1] == "upl-message.only-fuelled-inserters",
      "expected the fuel message, got " .. tostring(message[1]))
  end)

  test("an unresearched target quality warns but does not refuse", function()
    -- Warnings exist because planning ahead of research is legitimate: the result is ghosts.
    -- Un-researching the quality technologies at an otherwise full force reaches the state.
    local f = force()
    research.full(f)
    f.technologies["epic-quality"].researched = false
    f.technologies["legendary-quality"].researched = false
    local ok, message, gathered = planner.validate(f, choices_with({ quality = "legendary" }))
    research.full(f)
    assert(ok == true, "unresearched target must not refuse")
    assert(message and message[1] == "upl-message.quality-not-researched",
      "expected the quality warning, got " .. tostring(message and message[1]))
    assert(gathered, "warning path must still return gathered resources")
  end)

  test("an unresearched build quality warns but does not refuse", function()
    -- The other quality warning: the TARGET is researched, but the tier a building is placed
    -- AT is not. Ghosts of an unresearched tier are legal to place, so this must build through.
    local f = force()
    research.full(f)
    f.technologies["epic-quality"].researched = false
    f.technologies["legendary-quality"].researched = false
    local ok, message, gathered = planner.validate(f, choices_with({ machine_quality = "epic" }))
    research.full(f)
    assert(ok == true, "an unresearched build quality must not refuse")
    assert(message and message[1] == "upl-message.build-quality-not-researched",
      "expected the build-quality warning, got " .. tostring(message and message[1]))
    assert(gathered, "warning path must still return gathered resources")
  end)

  test("a circuit floor larger than the buffer chest warns but does not refuse", function()
    -- The count tops out at the chest's capacity and the reserve inserter only draws above
    -- the floor, so an oversized floor would stop that tier's recycling silently -- the loop
    -- still runs, which is what keeps this a warning. A requester chest holds 48 stacks of
    -- gears at normal, so a million is comfortably past any vanilla chest.
    local f = force()
    research.full(f)
    local ok, message, gathered = planner.validate(f, choices_with({
      circuit_enabled = true, circuit_min_uncommon = 1000000,
    }))
    assert(ok == true, "an oversized floor must not refuse")
    assert(message and message[1] == "upl-message.circuit-min-too-big",
      "expected the floor warning, got " .. tostring(message and message[1]))
    assert(gathered, "warning path must still return gathered resources")

    -- A floor that fits stays silent.
    local ok2, message2 = planner.validate(f, choices_with({
      circuit_enabled = true, circuit_min_uncommon = 200,
    }))
    assert(ok2 == true and message2 == nil,
      "a fitting floor warned: " .. tostring(message2 and message2[1]))
  end)
end)

describe("recipe-shape helpers", function()
  test("filters_needed counts item ingredients; 1 stands in before a recipe exists", function()
    assert(planner.filters_needed(nil) == 1, "nothing picked must still size one slot")
    assert(planner.filters_needed(prototypes.recipe["iron-gear-wheel"]) == 1, "gears take one slot")
    -- Sulfur's ingredients are two fluids and no items at all: zero, not `and ... or 1`-coerced.
    assert(planner.filters_needed(prototypes.recipe["sulfur"]) == 0,
      "a fluid-only recipe needs no filter slots")
  end)

  test("needs_pipe is exactly one fluid", function()
    assert(not planner.needs_pipe(nil), "nothing picked plumbs nothing")
    assert(not planner.needs_pipe(prototypes.recipe["iron-gear-wheel"]), "gears take no fluid")
    assert(planner.needs_pipe(prototypes.recipe["battery"]), "battery takes exactly one fluid")
    -- Two fluids is refused outright, so it must not read as "needs a pipe" either.
    assert(not planner.needs_pipe(prototypes.recipe["sulfur"]), "two fluids is not one")
  end)

  test("product_of names the single item product, or nothing", function()
    assert(planner.product_of(prototypes.recipe["iron-gear-wheel"]) == "iron-gear-wheel")
    -- All-fluid products: nothing to recycle back, so nothing to name.
    assert(planner.product_of(prototypes.recipe["advanced-oil-processing"]) == nil,
      "a fluid-producing recipe has no single item product")
  end)

  test("recycling_recipe is the name-derived lookup", function()
    assert(planner.recycling_recipe("iron-gear-wheel"), "gears lost their recycling recipe")
    assert(planner.recycling_recipe("not-an-item") == nil, "a bogus name found a recipe")
  end)

  test("request_count is a minute of crafting, capped at a stack", function()
    -- request_count reads only amount, energy and the item's stack size, so the recipe half
    -- can be a plain table and the arithmetic is pinned without depending on recipe retunes.
    assert(prototypes.item["iron-plate"].stack_size == 100, "premise: the plate stack moved")
    assert(planner.request_count({ name = "iron-plate", amount = 2 }, { energy = 0.5 }) == 100,
      "240 a minute must cap at the stack of 100")
    assert(planner.request_count({ name = "iron-plate", amount = 1 }, { energy = 20 }) == 3,
      "a slow craft requests just what a minute needs")
    assert(planner.request_count({ name = "iron-plate", amount = 1 }, { energy = 120 }) == 1,
      "a very slow craft still requests one")
  end)

  test("with_quality builds the pair and normalises a stale tier", function()
    assert(planner.with_quality(nil, "rare") == nil, "no name must mean no pair")
    local pair = planner.with_quality("fast-inserter", "rare")
    assert(pair.name == "fast-inserter" and pair.quality == "rare", "the pair lost a half")
    assert(planner.with_quality("fast-inserter", nil).quality == "normal",
      "an unset quality must read as normal")
    assert(planner.with_quality("fast-inserter", "not-a-quality").quality == "normal",
      "a stale tier must fall back to normal rather than reach a ghost")
  end)

  test("hidden quality tiers stay out of the chain", function()
    -- The quality mod ships quality-unknown as a hidden tier; the chain must skip it or the
    -- dropdown would offer a tier no loop can craft at.
    local unknown = prototypes.quality["quality-unknown"]
    assert(unknown and unknown.hidden, "premise: quality-unknown moved or unhid -- revisit")
    assert(not planner.is_quality("quality-unknown"), "a hidden tier leaked into the chain")
    assert(planner.is_quality("normal") and planner.is_quality("legendary"),
      "the real tiers must be members")
    assert(not planner.is_quality("iron-plate"), "an item name is not a quality")
  end)
end)

describe("machine candidates", function()
  test("moduleless, quality-refusing and furnace-type machines are all out", function()
    local candidates = util.list_to_map(planner.machine_candidates())
    assert(candidates["assembling-machine-2"] and candidates["assembling-machine-3"],
      "the ordinary assemblers must be candidates")
    -- Each exclusion with its premise asserted loudly, the inserter list's pattern: if a
    -- prototype's shape changes, revisit the rule rather than letting this pass hollow.
    local am1 = prototypes.entity["assembling-machine-1"]
    assert((am1.module_inventory_size or 0) == 0, "premise: AM1 grew module slots -- revisit")
    assert(not candidates["assembling-machine-1"],
      "a machine without module slots cannot roll quality and must not be offered")
    assert(not prototypes.entity["oil-refinery"].allowed_effects["quality"],
      "premise: the refinery accepts quality now -- revisit")
    assert(not candidates["oil-refinery"], "a machine that refuses quality modules is no use here")
    assert(not candidates["steel-furnace"], "a furnace picks its own recipe and cannot be pinned")
    assert(not candidates["recycler"], "the recycler is a furnace type, never the crafting half")
  end)

  test("pipe_to_ground_for falls back when the name convention misses", function()
    -- Wube's own pairs follow <pipe>-to-ground; a modded pipe without a matching underground
    -- must still get the longest-reaching researched one rather than nothing.
    research.full(force())
    assert(planner.pipe_to_ground_for(force(), "no-such-pipe") == "pipe-to-ground",
      "the fallback search must find vanilla's underground pipe for a conventionless name")
  end)

  test("unlocked targets follow the quality technologies", function()
    local f = force()
    research.full(f)
    f.technologies["epic-quality"].researched = false
    f.technologies["legendary-quality"].researched = false
    local targets = planner.unlocked_targets(f)
    research.full(f)
    assert(#targets == 2, "targets " .. #targets .. ", expected uncommon and rare alone")
    assert(targets[1] == "uncommon" and targets[2] == "rare",
      "the unresearched tiers must drop off the top, in chain order")
  end)
end)
