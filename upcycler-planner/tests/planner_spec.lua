-- planner.lua derivations and validate(), against real prototypes and a real force.
-- This is the H1/H3/H4 harness matrix made permanent: producer guards across research states,
-- picker gating, the inserter rules, and every refusal message reachable without a fixture mod.
-- Assertion values assume the SA modset (base + quality + recycler + space-age + elevated-rails),
-- which is what the factorio-testing skill's runner loads and what the dev install carries.

local planner = require("scripts.planner")
local research = require("tests.support.research")

local function force()
  return game.forces.player
end

describe("upcyclability -- prototype-level, research-free", function()
  test("iron gear wheel loops; steel plate and fluids and recycling recipes do not", function()
    assert(planner.is_upcyclable(prototypes.recipe["iron-gear-wheel"]), "gears must loop")
    -- Steel's recycling is the lossy self-recycling fallback, not a reversal.
    assert(not planner.is_upcyclable(prototypes.recipe["steel-plate"]), "steel must not loop")
    -- Sulfur takes fluids; there is nothing to put on the ring.
    assert(not planner.is_upcyclable(prototypes.recipe["sulfur"]), "fluid recipe must not loop")
    -- A recycling recipe trivially "closes the loop" while producing nothing (fact 4).
    assert(not planner.is_upcyclable(prototypes.recipe["iron-gear-wheel-recycling"]),
      "recycling recipes must never count as upcyclable")
  end)

  test("the offered item list holds exactly the known 187", function()
    -- FORKED on legacy/2.0, declared in the repo CLAUDE.md divergent-files list: the 2.0
    -- track offers 187 upcyclable items where 2.1 offers 185 (measured 2026-08-16, not
    -- itemised). A drift in either direction still means an eligibility rule changed by
    -- accident -- on this branch, against this number.
    local count = #planner.upcyclable_items()
    assert(count == 187, "upcyclable item count " .. count .. ", expected 187 on the 2.0 track")
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
    assert(planner.container(f) == "steel-chest", "plain buffer chest")
    assert(planner.logistic_container(f, "requester") == "requester-chest", "requester pick")
    assert(planner.logistic_container(f, "passive-provider") == "passive-provider-chest",
      "provider pick")
    assert(planner.quality_module(f) == "quality-module-3", "strongest quality module")
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
    assert(refusal({ recipe = "sulfur" }) == "upl-message.fluid-not-supported", "fluid recipe")
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
end)
