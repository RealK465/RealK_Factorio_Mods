-- Stamped cells running with real power and real ticks: the requester feeds the machine, the
-- outputs split by quality, the cap stops the chest, the pipe row feeds the machine and joins
-- the next cell's, and every beacon reaches its own machine and no other.

local plan = require("scripts.plan")
local research = require("tests.support.research")
local stamp = require("tests.support.stamp")

local function force() return game.forces.player end

-- A lab-tile surface, so no stamp ever meets water or trees. Named nauvis() so the body reads
-- like the other specs; it is not nauvis.
local lab
local function nauvis()
  if not (lab and lab.valid) then lab = stamp.lab() end
  return lab
end

local ORIGIN = { x = 0, y = 0 }
local AREA = { { -20, -20 }, { 60, 40 } }

local function find(name)
  return nauvis().find_entities_filtered({ name = name, area = AREA })
end

local function by_x(list)
  table.sort(list, function(a, b) return a.position.x < b.position.x end)
  return list
end

-- Stamps and revives one cell. Returns the plan and the plan-to-world offset: plan tile x sits
-- at world x + dx.
local function live(choices, origin)
  origin = origin or ORIGIN
  local p = assert(plan.build(force(), nauvis(), choices))
  local ghosts, dx, dy = stamp.place(p, nauvis(), force(), origin)
  assert(#ghosts == #p.entities, "stamped " .. #ghosts .. " of " .. #p.entities)
  stamp.revive_all(nauvis(), AREA)
  return p, dx, dy
end

-- A second cell stamped flush to the right of the first, checked to have landed there: the
-- engine snaps a blueprint to the grid by its own rule, and a cell one tile off would make the
-- join tests prove nothing.
local function neighbour(choices, p, dx, dy)
  local _, dx2, dy2 = live(choices, { x = dx + p.width, y = dy })
  assert(dx2 == dx + p.width and dy2 == dy,
    "the second cell landed at offset " .. tostring(dx2) .. "," .. tostring(dy2) .. ", not flush")
end

local GEARS = { item = "iron-gear-wheel", machine = "assembling-machine-3", inserter = "fast-inserter" }

describe("a live cell", function()
  before_all(function() research.full(force()) end)
  after_each(function() stamp.wipe(nauvis(), AREA) end)

  test("crafts from its requester into its output chest", function()
    live(GEARS)
    stamp.power(nauvis(), force(), ORIGIN.x - 4, ORIGIN.y + 2)
    find("requester-chest")[1].insert({ name = "iron-plate", count = 40 })
    after_ticks(600, function()
      local made = find("passive-provider-chest")[1].get_item_count("iron-gear-wheel")
      assert(made > 0, "no gears reached the output chest")
    end)
  end)

  test("splits the outputs by quality", function()
    live({ item = "iron-gear-wheel", machine = "assembling-machine-3", inserter = "fast-inserter", split = true })
    stamp.power(nauvis(), force(), ORIGIN.x - 4, ORIGIN.y + 2)
    local machine = find("assembling-machine-3")[1]
    local out = machine.get_inventory(defines.inventory.crafter_output)
    out.insert({ name = "iron-gear-wheel", count = 10, quality = "uncommon" })
    after_ticks(240, function()
      out.insert({ name = "iron-gear-wheel", count = 10, quality = "normal" })
      after_ticks(240, function()
        local chests = by_x(find("passive-provider-chest"))
        local capped, better = chests[1], chests[2]
        assert(capped.get_item_count({ name = "iron-gear-wheel", quality = "normal" }) == 10,
          "normal gears did not reach the capped chest")
        assert(capped.get_item_count({ name = "iron-gear-wheel", quality = "uncommon" }) == 0,
          "uncommon gears leaked into the capped chest")
        assert(better.get_item_count({ name = "iron-gear-wheel", quality = "uncommon" }) == 10,
          "uncommon gears did not reach the quality chest")
      end)
    end)
  end)

  test("stops filling the output chest at its slot cap", function()
    live({ item = "iron-gear-wheel", machine = "assembling-machine-3", inserter = "fast-inserter", cap_slots = 1 })
    stamp.power(nauvis(), force(), ORIGIN.x - 4, ORIGIN.y + 2)
    local out = find("assembling-machine-3")[1].get_inventory(defines.inventory.crafter_output)
    out.insert({ name = "iron-gear-wheel", count = 100 })
    after_ticks(300, function()
      out.insert({ name = "iron-gear-wheel", count = 50 })
      after_ticks(300, function()
        local held = find("passive-provider-chest")[1].get_item_count("iron-gear-wheel")
        assert(held == 100, "a one-slot cap holds one stack of 100, the chest holds " .. held)
        assert(out.get_item_count("iron-gear-wheel") == 50, "the surplus should wait in the machine")
      end)
    end)
  end)
end)

describe("live fluid and beacons", function()
  before_all(function() research.full(force()) end)
  after_each(function() stamp.wipe(nauvis(), AREA) end)

  test("two fluid cells side by side share one pipe line", function()
    local choices = { item = "electric-engine-unit", machine = "assembling-machine-3" }
    local p, dx, dy = live(choices)
    neighbour(choices, p, dx, dy)
    -- Feed the first cell's row from its left end -- plan tile (-1, 0) -- so the second cell
    -- gets fluid only through the join.
    local infinity = nauvis().create_entity({ name = "infinity-pipe",
      position = { dx - 0.5, dy + 0.5 }, force = force() })
    infinity.set_infinity_pipe_filter({ name = "lubricant", percentage = 100 })
    after_ticks(300, function()
      local machines = by_x(find("assembling-machine-3"))
      assert(#machines == 2, "expected two machines")
      assert(machines[1].get_fluid_count("lubricant") > 0, "the first cell got no lubricant")
      assert(machines[2].get_fluid_count("lubricant") > 0, "the second cell's row did not join the first")
    end)
  end)

  test("every beacon reaches its own machine and not the neighbour's", function()
    local choices = { item = "iron-gear-wheel", machine = "assembling-machine-3", beacon = "beacon" }
    local p, dx, dy = live(choices)
    neighbour(choices, p, dx, dy)
    local machines = by_x(find("assembling-machine-3"))
    assert(#machines == 2, "expected two machines")
    local per_machine = {}
    for _, beacon in pairs(find("beacon")) do
      local reached = {}
      for _, receiver in pairs(beacon.get_beacon_effect_receivers()) do
        for i, machine in ipairs(machines) do
          if receiver == machine then reached[#reached + 1] = i end
        end
      end
      assert(#reached == 1, "a beacon at " .. serpent.line(beacon.position) .. " reaches " .. #reached .. " machines")
      per_machine[reached[1]] = (per_machine[reached[1]] or 0) + 1
    end
    local expected = #find("beacon") / 2
    assert(per_machine[1] == expected and per_machine[2] == expected, "the beacons are not shared out evenly")
  end)
end)
