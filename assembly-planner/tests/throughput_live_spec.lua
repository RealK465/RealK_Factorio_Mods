-- Inserters measured on the installed game: the round trip calc.swing_ticks predicts and the
-- hand proto.inserter_hand predicts, into a chest and into a crafting machine, and what a stack
-- inserter does with a chest holding less than its hand.

local plan = require("scripts.plan")
local proto = require("scripts.proto")
local research = require("tests.support.research")
local stamp = require("tests.support.stamp")

local function force() return game.forces.player end

local lab
local function surface()
  if not (lab and lab.valid) then lab = stamp.lab() end
  return lab
end

local AREA = { { -30, -30 }, { 60, 60 } }
local NORTH, SOUTH = defines.direction.north, defines.direction.south

local function create(name, position, quality, direction)
  return surface().create_entity({ name = name, position = position, force = force(),
    quality = quality, direction = direction })
end

-- Every tick for `ticks` ticks, records the ticks at which each rig's hand filled from empty and
-- the largest hand seen, then passes them to `check`.
local function watch(rigs, ticks, check)
  local seen = {}
  for i in ipairs(rigs) do seen[i] = { fills = {}, held = 0, largest = 0 } end
  local elapsed = 0
  on_tick(function()
    elapsed = elapsed + 1
    for i, rig in ipairs(rigs) do
      local stack = rig.inserter.held_stack
      local count = stack.valid_for_read and stack.count or 0
      local s = seen[i]
      if count > 0 and s.held == 0 then s.fills[#s.fills + 1] = elapsed end
      s.held = count
      s.largest = math.max(s.largest, count)
    end
    if elapsed >= ticks then
      check(seen)
      return false
    end
  end)
end

-- Every gap between pickups is one round trip; a new arm starts mid-swing, which only moves the
-- first pickup.
local function gaps_match(rig, record)
  local fills = record.fills
  assert(#fills >= 3, rig.label .. ": only " .. #fills .. " pickups seen")
  for k = 2, #fills do
    local gap = fills[k] - fills[k - 1]
    assert(gap == rig.swing, rig.label .. ": a round trip took " .. gap .. " ticks, calc says " .. tostring(rig.swing))
  end
end

local function rig_for(name, quality, inserter)
  return {
    inserter = inserter, label = name .. "@" .. quality,
    swing = proto.inserter_swing(prototypes.entity[name], quality),
    hand = proto.inserter_hand(prototypes.entity[name], force()),
  }
end

local saved_bonus

describe("inserters, measured", function()
  before_all(function() research.full(force()) end)
  after_each(function()
    stamp.wipe(surface(), AREA)
    if saved_bonus then
      force().bulk_inserter_capacity_bonus = saved_bonus.bulk
      force().inserter_stack_size_bonus = saved_bonus.plain
      saved_bonus = nil
    end
  end)

  test("a round trip into a chest takes what calc says, carrying what proto says", function()
    local rigs, x = {}, 0
    for _, name in ipairs({ "inserter", "fast-inserter", "bulk-inserter", "stack-inserter" }) do
      if prototypes.entity[name] then
        for _, quality in ipairs({ "normal", "legendary" }) do
          create("steel-chest", { x + 0.5, 0.5 }).insert({ name = "iron-plate", count = 2000 })
          local inserter = create(name, { x + 0.5, 1.5 }, quality, NORTH)
          create("steel-chest", { x + 0.5, 2.5 })
          rigs[#rigs + 1] = rig_for(name, quality, inserter)
          x = x + 2
        end
      end
    end
    stamp.power(surface(), force(), x / 2 - 2, 5)
    watch(rigs, 400, function(seen)
      for i, rig in ipairs(rigs) do
        gaps_match(rig, seen[i])
        assert(seen[i].largest == rig.hand,
          rig.label .. ": carried " .. seen[i].largest .. ", proto says " .. rig.hand)
      end
    end)
  end)

  test("into a crafting machine the round trip is the same", function()
    -- One item a swing, so a legendary AM3 on gears always outpaces the arm and never makes it wait.
    saved_bonus = { bulk = force().bulk_inserter_capacity_bonus, plain = force().inserter_stack_size_bonus }
    force().bulk_inserter_capacity_bonus = 0
    force().inserter_stack_size_bonus = 0
    local rigs, x = {}, 0
    for _, name in ipairs({ "inserter", "fast-inserter", "bulk-inserter" }) do
      for _, quality in ipairs({ "normal", "legendary" }) do
        local machine = create("assembling-machine-3", { x + 1.5, 17.5 }, "legendary")
        machine.set_recipe("iron-gear-wheel")
        local inserter = create(name, { x + 1.5, 19.5 }, quality, SOUTH)
        create("steel-chest", { x + 1.5, 20.5 }).insert({ name = "iron-plate", count = 2000 })
        rigs[#rigs + 1] = rig_for(name, quality, inserter)
        x = x + 4
      end
    end
    stamp.power(surface(), force(), 4, 23)
    stamp.power(surface(), force(), 16, 23)
    watch(rigs, 400, function(seen)
      for i, rig in ipairs(rigs) do
        gaps_match(rig, seen[i])
        assert(seen[i].largest == 1, rig.label .. ": carried " .. seen[i].largest .. " with no research")
      end
    end)
  end)

  test("a stack inserter waits, holding what a short chest had", function()
    -- wait_for_full_hand: with 5 plates against a hand of 16 it takes all 5 and never swings.
    -- So a chest requesting less than its hand makes it wait for refills (measured 2.1.25).
    if not prototypes.entity["stack-inserter"] then return end
    create("steel-chest", { 0.5, 30.5 }).insert({ name = "iron-plate", count = 5 })
    local inserter = create("stack-inserter", { 0.5, 31.5 }, "normal", NORTH)
    local target = create("steel-chest", { 0.5, 32.5 })
    stamp.power(surface(), force(), 3, 31)
    after_ticks(300, function()
      local moved = target.get_item_count("iron-plate")
      local held = inserter.held_stack.valid_for_read and inserter.held_stack.count or 0
      assert(moved == 0 and held == 5, "moved " .. moved .. ", holding " .. held)
    end)
  end)
end)

-- Stamped cells crafting against the plan's own rate: the inserters it adds keep the machine at
-- its pace, side ones included, and a cell out of room crafts at the rate it warns about.
describe("live throughput", function()
  local saved
  before_all(function() research.full(force()) end)
  after_each(function()
    stamp.wipe(surface(), AREA)
    if saved then
      force().bulk_inserter_capacity_bonus = saved
      saved = nil
    end
  end)

  local function find(name)
    local list = surface().find_entities_filtered({ name = name, area = AREA })
    table.sort(list, function(a, b) return a.position.x < b.position.x end)
    return list
  end

  local function count(p, name)
    local n = 0
    for _, e in ipairs(p.entities) do
      if e.name == name then n = n + 1 end
    end
    return n
  end

  -- Stamps and powers a cell and fills every requester by hand: no network, so no robots. A
  -- revived ghost leaves its modules as a request for robots too, so they go in by hand as well.
  local function live(choices, bulk_bonus)
    saved = force().bulk_inserter_capacity_bonus
    force().bulk_inserter_capacity_bonus = bulk_bonus
    local p = assert(plan.build(force(), surface(), choices))
    local ghosts, dx, dy = stamp.place(p, surface(), force(), { x = 0, y = 0 })
    assert(#ghosts == #p.entities, "stamped " .. #ghosts .. " of " .. #p.entities)
    stamp.revive_all(surface(), AREA)
    local fitted = {}
    for _, e in ipairs(p.entities) do
      if e.modules and not fitted[e.name] then
        fitted[e.name] = true
        for _, entity in ipairs(find(e.name)) do
          entity.get_inventory(e.module_inventory or defines.inventory.crafter_modules)
            .insert({ name = e.modules.name, quality = e.modules.quality, count = e.modules.count })
        end
      end
    end
    stamp.power(surface(), force(), dx + 3, dy + p.height + 2)
    for _, chest in ipairs(find("requester-chest")) do chest.insert({ name = "iron-plate", count = 1500 }) end
    return p
  end

  -- Crafts in 600 ticks after a warm-up, within a tenth of the plan's rate.
  local function crafts_match(p, label, after)
    local machine = find("assembling-machine-3")[1]
    after_ticks(180, function()
      local start = machine.products_finished
      after_ticks(600, function()
        local made = machine.products_finished - start
        local expected = p.stats.crafts_per_minute * 600 / 3600
        assert(math.abs(made - expected) <= 0.1 * expected,
          label .. ": made " .. made .. " in 600 ticks, the plan says " .. string.format("%.1f", expected))
        if after then after() end
      end)
    end)
  end

  local GEARS = { item = "iron-gear-wheel", machine = "assembling-machine-3", module = "speed-module-3",
    beacon = "beacon", inserter = "bulk-inserter", size_mode = "minutes", cap_mode = "none" }

  test("the planned inserters keep a beaconed gear cell at its pace, the side ones included", function()
    -- A hand of six: three inputs and two outputs, one of each up the left side.
    local p = live(GEARS, 5)
    assert(count(p, "requester-chest") == 3 and count(p, "passive-provider-chest") == 2 and p.width == 11,
      "the plan changed shape: " .. count(p, "requester-chest") .. " in, " .. count(p, "passive-provider-chest")
      .. " out, width " .. p.width)
    local machine = find("assembling-machine-3")[1]
    for _, beacon in ipairs(find("beacon")) do
      local reached = false
      for _, receiver in pairs(beacon.get_beacon_effect_receivers()) do
        if receiver == machine then reached = true end
      end
      assert(reached, "the beacon at " .. serpent.line(beacon.position) .. " lost the machine")
    end
    crafts_match(p, "three inputs", function()
      assert(find("requester-chest")[1].get_item_count("iron-plate") < 1500, "the side input never fed")
      assert(find("passive-provider-chest")[1].get_item_count("iron-gear-wheel") > 0, "the side output never took")
    end)
  end)

  test("a cell out of room crafts at the rate it warns about", function()
    local p = live({ item = "iron-gear-wheel", machine = "assembling-machine-3", module = "quality-module-3",
      module_quality = "legendary", beacon = "beacon", inserter = "bulk-inserter", size_mode = "minutes",
      cap_mode = "none" }, 0)
    assert(p.stats.crafts_per_minute < p.stats.pace_per_minute, "this cell should be held back")
    crafts_match(p, "held back")
  end)
end)
