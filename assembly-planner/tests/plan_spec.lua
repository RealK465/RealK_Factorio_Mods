-- plan.build against the real prototypes, at full research, on nauvis: the owner's example
-- cells reproduced, then each option, refusal and warning.

local plan = require("scripts.plan")
local proto = require("scripts.proto")
local research = require("tests.support.research")

local function force() return game.forces.player end
local function nauvis() return game.surfaces["nauvis"] end

local function build(choices)
  return plan.build(force(), nauvis(), choices)
end

local function named(p, name)
  local out = {}
  for _, e in ipairs(p.entities) do
    if e.name == name then out[#out + 1] = e end
  end
  return out
end

-- The chests and inserters in the slot row, left to right.
local function slot_row(p, name)
  local list = named(p, name)
  table.sort(list, function(a, b) return a.dx < b.dx end)
  return list
end

local function has_warning(p, key)
  for _, warning in ipairs(p.warnings) do
    if warning[1] == "apl-message." .. key then return true end
  end
  return false
end

describe("plan.build", function()
  before_all(function() research.full(force()) end)

  test("nothing picked is a hint, not a refusal", function()
    local p, message = build({})
    assert(p == nil and message == nil, "an empty choice set planned or refused")
  end)

  test("the owner's AM3 quality cell: split, a two-slot cap, every ingredient requested", function()
    local p = assert(build({
      item = "personal-roboport-mk2-equipment", machine = "assembling-machine-3",
      module = "quality-module-3", inserter = "fast-inserter",
    }))
    assert(p.split, "quality modules must split the outputs")
    assert(p.width == 3 and p.height == 5, "footprint " .. p.width .. "x" .. p.height)
    local machine = named(p, "assembling-machine-3")[1]
    assert(machine.recipe == "personal-roboport-mk2-equipment" and machine.modules.count == 4,
      "machine recipe or modules wrong")
    local inserters = slot_row(p, "fast-inserter")
    assert(#inserters == 3, "expected three inserters")
    assert(inserters[2].filters[1].quality == "normal" and inserters[2].filters[1].comparator == "=",
      "the capped output must take the recipe's quality only")
    assert(inserters[3].filters[1].quality == "normal" and inserters[3].filters[1].comparator == ">",
      "the quality output must take everything better")
    local outputs = slot_row(p, "passive-provider-chest")
    assert(#outputs == 2 and outputs[1].bar == plan.DEFAULT_CAP_SLOTS and outputs[2].bar == nil,
      "the capped chest is the first output, and only it")
    local requester = named(p, "requester-chest")[1]
    local ingredients = prototypes.recipe["personal-roboport-mk2-equipment"].ingredients
    assert(#requester.requests == #ingredients, "not every ingredient is requested")
    for _, request in ipairs(requester.requests) do
      local amount
      for _, ingredient in pairs(ingredients) do
        if ingredient.name == request.name then amount = ingredient.amount end
      end
      assert(request.count == amount * plan.DEFAULT_CRAFTS and request.quality == "normal",
        request.name .. " requested " .. request.count)
    end
  end)

  test("speed modules: one output chest, capped", function()
    local p = assert(build({ item = "iron-gear-wheel", machine = "assembling-machine-3", module = "speed-module-3" }))
    assert(not p.split, "speed modules must not split")
    local outputs = named(p, "passive-provider-chest")
    assert(#outputs == 1 and outputs[1].bar == plan.DEFAULT_CAP_SLOTS, "the single output must carry the cap")
  end)

  test("the split checkbox overrides the automatic answer", function()
    local p = assert(build({ item = "iron-gear-wheel", machine = "assembling-machine-3", split = true }))
    assert(p.split and not p.split_auto, "a forced split did not take")
    assert(has_warning(p, "split-nothing-above"), "a forced split with nothing above should say so")
    local q = assert(build({ item = "iron-gear-wheel", machine = "assembling-machine-3",
      module = "quality-module-3", split = false }))
    assert(not q.split, "an unticked split still split")
  end)

  test("a fluid recipe gets a pipe row along the back", function()
    local p = assert(build({ item = "electric-engine-unit", machine = "assembling-machine-3" }))
    local pipes = named(p, "pipe")
    assert(#pipes == p.width, "the pipe row does not span the cell")
    assert(named(p, "assembling-machine-3")[1].direction == defines.direction.north, "AM3 needs no turn")
  end)

  test("the owner's foundry: turned south, and warned off nauvis", function()
    local p = assert(build({ item = "big-mining-drill", machine = "foundry" }))
    assert(named(p, "foundry")[1].direction == defines.direction.south, "the foundry must face south")
    assert(has_warning(p, "recipe-wrong-surface"), "big mining drills only craft at Vulcanus pressure")
  end)

  test("the owner's EM plant: beacons on both sides and above, as many as fit", function()
    local p = assert(build({ item = "accumulator", machine = "electromagnetic-plant", beacon = "beacon" }))
    assert(#named(p, "beacon") == 2 * 2 + 3, "expected 7 beacons, got " .. #named(p, "beacon"))
    assert(p.width == 10 and p.height == 9, "footprint " .. p.width .. "x" .. p.height)
    assert(named(p, "beacon")[1].modules.name == "speed-module-3", "beacons default to speed modules")
    local fewer = assert(build({ item = "accumulator", machine = "electromagnetic-plant", beacon = "beacon",
      beacons_side = 1, beacons_above = 0 }))
    assert(#named(fewer, "beacon") == 2, "the counts were not honoured")
    local empty = assert(build({ item = "accumulator", machine = "electromagnetic-plant", beacon = "beacon",
      no_beacon_module = true }))
    assert(named(empty, "beacon")[1].modules == nil, "a cleared beacon module still filled the beacons")
  end)

  test("network count puts the cap on the output inserter", function()
    local p = assert(build({ item = "iron-gear-wheel", machine = "assembling-machine-3", cap_mode = "network",
      cap_count = 300, inserter = "fast-inserter" }))
    local inserters = slot_row(p, "fast-inserter")
    local behavior = inserters[2].control_behavior
    assert(behavior and behavior.connect_to_logistic_network, "no logistic connection on the output")
    local condition = behavior.logistic_condition
    assert(condition.first_signal.name == "iron-gear-wheel" and condition.comparator == "<"
      and condition.constant == 300, "the condition is not product < 300")
    assert(named(p, "passive-provider-chest")[1].bar == nil, "network mode must not cap the chest too")
    assert(has_warning(p, "network-cap"), "network mode should say it needs the network")
  end)

  test("no limit: neither a cap nor a condition", function()
    local p = assert(build({ item = "iron-gear-wheel", machine = "assembling-machine-3", cap_mode = "none" }))
    for _, e in ipairs(p.entities) do
      assert(e.bar == nil and e.control_behavior == nil, e.name .. " carries a limit")
    end
  end)

  test("minutes mode sizes at the machine's real pace", function()
    -- AM3 at 1.25 makes 150 gears a minute; two minutes of 2 plates each is 600.
    local p = assert(build({ item = "iron-gear-wheel", machine = "assembling-machine-3", size_mode = "minutes" }))
    local request = named(p, "requester-chest")[1].requests[1]
    assert(request.count == 600, "two minutes of plates requested " .. request.count)
  end)

  test("a per-ingredient amount wins over the rule", function()
    local p = assert(build({ item = "iron-gear-wheel", machine = "assembling-machine-3", ["request_iron-plate"] = 77 }))
    assert(named(p, "requester-chest")[1].requests[1].count == 77, "the override was ignored")
  end)

  test("a module the recipe refuses is refused with a reason", function()
    local p, message = build({ item = "personal-roboport-mk2-equipment", machine = "assembling-machine-3",
      module = "productivity-module-3" })
    assert(p == nil and message[1] == "apl-message.module-not-accepted-by-recipe",
      "a productivity module on equipment was not refused")
  end)

  test("a pole powers a full cell from a column of its own", function()
    local p = assert(build({ item = "personal-roboport-mk2-equipment", machine = "assembling-machine-3",
      module = "quality-module-3", pole = "medium-electric-pole" }))
    assert(p.width == 4, "a full AM3 cell needs the pole column, width " .. p.width)
    assert(#named(p, "medium-electric-pole") >= 1, "no pole placed")
    assert(not has_warning(p, "consumers-unpowered"), "something was left unpowered")
  end)

  test("a medium pole powers a beaconed cell through a pole row above the beacons", function()
    -- A full row of beacons above the machine sits out of a medium pole's reach from every free
    -- tile below it, and a column on the right reaches only its right end. A slow recipe, so the
    -- cell gains no extra inserters and keeps the one free bottom tile this pins.
    local p = assert(build({ item = "personal-roboport-mk2-equipment", machine = "assembling-machine-3",
      module = "quality-module-3", beacon = "beacon", beacons_side = 1, beacons_above = 3,
      pole = "medium-electric-pole" }))
    assert(not has_warning(p, "consumers-unpowered"), "a beaconed cell was left partly dark")
    assert(p.height == 9, "the pole row did not open: height " .. p.height)
    local top = false
    for _, e in ipairs(named(p, "medium-electric-pole")) do
      if e.dy == 0 then top = true end
    end
    assert(top, "no pole stands in the row above the beacons")
  end)

  test("amounts the chest cannot hold are warned about", function()
    local p = assert(build({ item = "personal-roboport-mk2-equipment", machine = "assembling-machine-3",
      size_crafts = 1000 }))
    assert(has_warning(p, "request-too-big"), "a thousand crafts' worth fits no requester")
  end)

  test("a machine too narrow for its row lies on its side", function()
    -- Space Age's crusher is 2x3: standing up it fits two inserters, lying down three.
    local crusher = prototypes.entity["crusher"]
    assert(crusher and crusher.tile_width == 2 and crusher.tile_height == 3, "the crusher changed shape")
    local item
    for _, name in pairs({ "iron-ore", "carbon", "copper-ore" }) do
      local recipes = proto.recipes_for_item(name)
      for _, recipe in pairs(recipes) do
        if crusher.crafting_categories[prototypes.recipe[recipe].categories[1]] then item = item or name end
      end
    end
    assert(item, "no crushed item to plan")
    local p = assert(build({ item = item, machine = "crusher" }))
    local machine = named(p, "crusher")[1]
    assert(machine.direction == defines.direction.east and machine.w == 3, "the crusher did not lie down")
  end)
end)

describe("plan.build before research", function()
  before_all(function() research.fresh(force()) end)
  after_all(function() research.full(force()) end)

  test("a build quality not researched is warned about, with or without modules", function()
    local p = assert(build({
      item = "iron-gear-wheel", machine = "assembling-machine-1", inserter = "fast-inserter",
      requester = "requester-chest", output = "passive-provider-chest", inserter_quality = "legendary",
    }))
    assert(has_warning(p, "build-quality-not-researched"),
      "a legendary inserter on a fresh force should warn even with no machine module")
  end)
end)

describe("plan.build throughput", function()
  local saved
  before_all(function() research.full(force()) end)
  after_each(function()
    if saved then
      force().bulk_inserter_capacity_bonus = saved
      saved = nil
    end
  end)
  local function set_bulk_bonus(value)
    saved = saved or force().bulk_inserter_capacity_bonus
    force().bulk_inserter_capacity_bonus = value
  end

  -- AM3, four speed module 3 and five vanilla beacons of speed module 3: about 15.9 crafts a
  -- second of a half-second recipe.
  local SPEED_GEARS = { item = "iron-gear-wheel", machine = "assembling-machine-3", module = "speed-module-3",
    beacon = "beacon", inserter = "bulk-inserter" }
  local function with(base, extra)
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    for k, v in pairs(extra or {}) do out[k] = v end
    return out
  end

  test("a beaconed gear cell gains a second input with the request copied in", function()
    local p = assert(build(SPEED_GEARS))
    local requesters = slot_row(p, "requester-chest")
    assert(#requesters == 2, "expected two ingredient chests, got " .. #requesters)
    for _, chest in ipairs(requesters) do
      assert(chest.requests[1].count == 2 * plan.DEFAULT_CRAFTS,
        "a request below a load must be copied whole, got " .. chest.requests[1].count)
    end
    local output = named(p, "passive-provider-chest")[1]
    assert(requesters[1].dy == output.dy and requesters[2].dx < output.dx, "the bottom row is not input, input, output")
    assert(p.width == 9 and p.height == 8, "the extra fit the bottom edge, yet the footprint is " .. p.width .. "x" .. p.height)
    assert(not has_warning(p, "inserters-limit"), "two inputs keep up, yet the plan warns")
    assert(math.abs(p.stats.crafts_per_minute - p.stats.pace_per_minute) < 1e-6, "the real rate fell short of the pace")
  end)

  test("a Minutes request is shared between the input chests", function()
    local p = assert(build(with(SPEED_GEARS, { size_mode = "minutes" })))
    local requesters = named(p, "requester-chest")
    assert(#requesters == 2, "expected two ingredient chests, got " .. #requesters)
    local total = p.request_rows[1].default
    for _, chest in ipairs(requesters) do
      assert(chest.requests[1].count == math.ceil(total / 2),
        "each chest should ask for half of " .. total .. ", got " .. chest.requests[1].count)
    end
  end)

  test("copper cable gains a second output, the slot cap shared", function()
    local cable = { item = "copper-cable", machine = "assembling-machine-3", module = "speed-module-3",
      beacon = "beacon", inserter = "bulk-inserter", size_mode = "minutes" }
    local p = assert(build(cable))
    assert(#named(p, "requester-chest") == 1, "one plate a craft needs one input")
    local outputs = named(p, "passive-provider-chest")
    assert(#outputs == 2, "two cables a craft need two outputs, got " .. #outputs)
    for _, chest in ipairs(outputs) do assert(chest.bar == 1, "the two-slot cap is not shared out") end
    local tight = assert(build(with(cable, { cap_slots = 1 })))
    for _, chest in ipairs(named(tight, "passive-provider-chest")) do
      assert(chest.bar == 1, "a one-slot cap left a chest with no slot")
    end
    local network = assert(build(with(cable, { cap_mode = "network", cap_count = 400 })))
    local capped = 0
    for _, e in ipairs(named(network, "bulk-inserter")) do
      if e.control_behavior then capped = capped + 1 end
    end
    assert(capped == 2, "the network count must hold both outputs, held " .. capped)
  end)

  test("a full quality cell takes its extras up the left side", function()
    set_bulk_bonus(2)
    local p = assert(build(with(SPEED_GEARS, { module = "quality-module-3", module_quality = "legendary" })))
    assert(p.split, "legendary quality modules beat the beacons' malus and split")
    assert(#named(p, "requester-chest") == 3, "a hand of three needs three inputs")
    assert(#named(p, "passive-provider-chest") == 3, "two outputs and a quality chest")
    assert(p.width == 11, "the left side should open two tiles, width " .. p.width)
    local side = 0
    for _, e in ipairs(named(p, "bulk-inserter")) do
      if e.dx == 4 then side = side + 1 end
    end
    assert(side == 3, "three inserters should stand up the left side, found " .. side)
    assert(not has_warning(p, "inserters-limit"), "the side made room, yet the plan warns")
  end)

  test("no room left: the rate drops and the plan says so", function()
    set_bulk_bonus(0)
    local p = assert(build(with(SPEED_GEARS, { module = "quality-module-3", module_quality = "legendary" })))
    assert(has_warning(p, "inserters-limit"), "one plate a swing cannot feed this cell, and it should say so")
    assert(p.stats.crafts_per_minute < p.stats.pace_per_minute, "the rate did not drop")
    assert(not has_warning(p, "requests-below-load"), "eight plates fill a hand of one; the request is not to blame")
  end)

  test("a request below a load is named when the room runs out", function()
    -- A hand of 12 against a one-plate request: every swing carries one plate.
    local p = assert(build(with(SPEED_GEARS, { module = "quality-module-3", module_quality = "legendary",
      ["request_iron-plate"] = 1 })))
    assert(has_warning(p, "inserters-limit"), "one plate a swing cannot feed this cell")
    assert(has_warning(p, "requests-below-load"), "the small request should be named")
  end)

  test("an arm with no swing keeps one pair of each and warns nothing", function()
    -- A modded inserter whose arm reads no rotation: no rate to model, so the 0.1.0 cell.
    local swing = proto.inserter_swing
    proto.inserter_swing = function() return nil end
    local ok, p = pcall(build, SPEED_GEARS)
    proto.inserter_swing = swing
    assert(ok, "a missing swing made the plan throw: " .. tostring(p))
    p = assert(p)
    assert(#named(p, "requester-chest") == 1, "no rate to model, yet the cell grew")
    assert(p.stats.crafts_per_minute == p.stats.pace_per_minute, "no rate to model, yet the rate dropped")
    assert(not has_warning(p, "inserters-limit"), "no rate to model, yet a warning")
  end)

  test("a fluid-only recipe grows no requester", function()
    local p = assert(build({ item = "solid-fuel", machine = "chemical-plant", module = "speed-module-3",
      beacon = "beacon", inserter = "bulk-inserter" }))
    assert(#named(p, "requester-chest") == 0, "a recipe with no item ingredient got an ingredient chest")
  end)
end)
