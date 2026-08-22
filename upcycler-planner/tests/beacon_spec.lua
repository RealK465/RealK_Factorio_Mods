-- Beacon mechanics, measured before they are leaned on -- the same discipline as api.md §21
-- (blueprint fields) and §10 (pole coverage). Two engine facts the beacon feature rests on:
--
--   1. A beacon's module insert plan targets defines.inventory.beacon_modules, not the
--      crafter_modules constant blueprint.lua writes for machines and recyclers, and the
--      engine round-trips it through create_blueprint / get_blueprint_entities.
--   2. The supply area is the beacon's COLLISION BOX expanded by supply_area_distance on every
--      side -- measured from the edge, NOT a radius from the centre the way a pole's is
--      (api.md §10). Coverage is collision-box overlap with that square.
--
-- The sweep below distinguishes the two rules: a vanilla beacon (3x3, distance 3) reaches a
-- 3x3 machine whose top-left is 5 tiles over under the edge rule, and does not under the
-- centre rule.

local planner = require("scripts.planner")
local research = require("tests.support.research")
local stamping = require("tests.support.stamp")

local function force()
  return game.forces.player
end

local function nauvis()
  return game.surfaces["nauvis"]
end

-- The rig stands away from spawn so nothing collides with the player's character. Entities
-- are tracked and destroyed per test rather than wiping the surface: this spec creates real
-- entities, not ghosts, and only its own.
local RIG = { x = 40, y = 40 }
local created = {}

local function build(spec)
  local entity = nauvis().create_entity(spec)
  assert(entity, "test rig failed to place " .. spec.name .. " at " .. serpent.line(spec.position))
  created[#created + 1] = entity
  return entity
end

local function clear_rig()
  for _, entity in pairs(created) do
    if entity.valid then entity.destroy() end
  end
  created = {}
end

-- Trees and rocks in the rig area would block create_entity; clear them once up front.
local function clear_ground()
  local area = {
    left_top = { x = RIG.x - 5, y = RIG.y - 5 },
    right_bottom = { x = RIG.x + 20, y = RIG.y + 20 },
  }
  for _, entity in pairs(nauvis().find_entities_filtered({ area = area })) do
    if entity.valid and entity.type ~= "character" then entity.destroy() end
  end
end

describe("beacon module inventory in blueprints", function()
  before_all(function()
    research.full(force())
    clear_ground()
  end)
  after_each(clear_rig)

  test("create_blueprint reports a beacon module under defines.inventory.beacon_modules", function()
    local beacon = build({
      name = "beacon", position = { RIG.x + 1.5, RIG.y + 1.5 }, force = force(),
    })
    local inventory = beacon.get_inventory(defines.inventory.beacon_modules)
    assert(inventory, "no inventory at defines.inventory.beacon_modules ("
      .. tostring(defines.inventory.beacon_modules) .. ")")
    assert(inventory.insert({ name = "speed-module-3", count = 2 }) == 2,
      "could not insert two speed modules into the beacon")

    local stash = game.create_inventory(1)
    stash.insert({ name = "blueprint", count = 1 })
    local stack = stash[1]
    stack.create_blueprint({
      surface = nauvis(), force = force(),
      area = {
        left_top = { x = RIG.x - 1, y = RIG.y - 1 },
        right_bottom = { x = RIG.x + 4, y = RIG.y + 4 },
      },
    })
    local entities = stack.get_blueprint_entities()
    stash.destroy()

    assert(entities and #entities == 1, "captured " .. tostring(entities and #entities)
      .. " entities, expected the beacon alone")
    local captured = entities[1]
    assert(captured.name == "beacon", "captured " .. captured.name)
    assert(captured.items and captured.items[1],
      "the beacon's modules did not survive into the blueprint's items field")
    local id = captured.items[1].id
    assert(id.name == "speed-module-3", "items carries " .. tostring(id.name))
    local positions = captured.items[1].items.in_inventory
    assert(#positions == 2, "insert plan covers " .. #positions .. " stacks, expected 2")
    for _, entry in pairs(positions) do
      assert(entry.inventory == defines.inventory.beacon_modules,
        "engine wrote inventory " .. tostring(entry.inventory)
        .. ", expected beacon_modules (" .. tostring(defines.inventory.beacon_modules)
        .. "), crafter_modules is " .. tostring(defines.inventory.crafter_modules))
    end
  end)

  test("a blueprint written with beacon_modules stamps a ghost carrying the insert plan", function()
    -- A hand-built entity list on purpose -- this measures the engine, not blueprint.lua --
    -- through stamp's own stash mechanics rather than a second copy of them.
    local ghosts = stamping.place_entities({ {
      entity_number = 1, name = "beacon", position = { x = 1.5, y = 1.5 },
      items = { {
        id = { name = "speed-module-3" },
        items = { in_inventory = {
          { inventory = defines.inventory.beacon_modules, stack = 0 },
          { inventory = defines.inventory.beacon_modules, stack = 1 },
        } },
      } },
    } }, {
      surface = nauvis(), force = force(),
      position = { x = RIG.x + 10, y = RIG.y + 10 },
      build_mode = defines.build_mode.forced,
    })
    assert(#ghosts == 1, "stamped " .. #ghosts .. " ghosts, expected the beacon alone")
    created[#created + 1] = ghosts[1]

    local plan = ghosts[1].insert_plan
    assert(#plan == 1, "ghost insert plan entries " .. #plan)
    assert(plan[1].id.name == "speed-module-3", "ghost insert plan carries "
      .. tostring(plan[1].id.name))
    local slots = plan[1].items.in_inventory
    assert(#slots == 2, "ghost insert plan covers " .. #slots .. " stacks")
  end)
end)

describe("beacon supply area", function()
  before_all(function()
    research.full(force())
    clear_ground()
  end)
  after_each(clear_rig)

  -- Whether a machine whose TOP-LEFT tile sits at the offset receives the beacon's effects.
  -- The beacon's own top-left is the rig origin; both are 3x3, so the geometry is exact.
  local function receives_at(beacon, dx, dy)
    local machine = build({
      name = "assembling-machine-2", force = force(),
      position = { RIG.x + dx + 1.5, RIG.y + dy + 1.5 },
    })
    local received = false
    for _, receiver in pairs(beacon.get_beacon_effect_receivers()) do
      if receiver.unit_number == machine.unit_number then received = true end
    end
    machine.destroy()
    return received
  end

  test("reach is the collision box expanded by supply_area_distance, not a centre radius", function()
    local beacon = build({
      name = "beacon", position = { RIG.x + 1.5, RIG.y + 1.5 }, force = force(),
    })
    assert(beacon.get_inventory(defines.inventory.beacon_modules)
      .insert({ name = "speed-module", count = 1 }) == 1, "module insert failed")

    -- Vanilla: beacon collision [0.3, 2.7] in rig tiles, distance 3, so the supply square runs
    -- to 5.7. A 3x3 machine at dx has its collision from dx+0.3: covered while dx+0.3 < 5.7,
    -- so dx=5 is the last covered column. A centre-radius rule (pole-style) would stop at
    -- 1.5+3 = 4.5 and dx=5 would read uncovered -- that is the distinguishing case.
    for dx = 3, 5 do
      assert(receives_at(beacon, dx, 0), "machine at dx=" .. dx .. " should receive "
        .. "(edge rule reaches 5.7; centre rule would already have failed at dx=5)")
    end
    assert(not receives_at(beacon, 6, 0), "machine at dx=6 should NOT receive "
      .. "(its collision starts at 6.3, past the edge-rule reach of 5.7)")

    -- Same boundary vertically -- the supply area is a square, not an x-only band.
    assert(receives_at(beacon, 0, 5), "machine at dy=5 should receive")
    assert(not receives_at(beacon, 0, 6), "machine at dy=6 should not receive")

    -- Corner overlap counts: at (5,5) only the machine's top-left corner clips the square.
    assert(receives_at(beacon, 5, 5), "machine at (5,5) should receive by corner overlap")
    assert(not receives_at(beacon, 6, 6), "machine at (6,6) should not receive")
  end)

  test("supply distance getter answers per quality, and vanilla starts at 3", function()
    local beacon = prototypes.entity["beacon"]
    assert(beacon.get_supply_area_distance("normal") == 3,
      "vanilla beacon supply at normal reads " .. beacon.get_supply_area_distance("normal"))
    -- Not pinned to a value: whether quality grows a beacon's reach is the engine's call, and
    -- the planner reads the getter at the chosen quality either way. This only pins that the
    -- getter answers and never shrinks.
    local legendary = beacon.get_supply_area_distance("legendary")
    assert(legendary >= 3, "legendary supply reads " .. tostring(legendary))
  end)
end)

-- The feature end to end: a planned loop with a beacon picked, from choices through the
-- blueprint to real revived entities, closing with the engine's own answer to "does every
-- machine and recycler actually receive?".
describe("a planned loop with a beacon", function()
  before_all(function() research.full(force()) end)

  -- The blueprint_spec wipe: a revived loop leaves belts, chests and poles behind, and a
  -- selective sweep would miss whichever one the layout gains next.
  after_each(function()
    for _, entity in pairs(nauvis().find_entities_filtered({})) do
      entity.destroy()
    end
  end)

  local function gear_choices(overrides)
    local choices = {
      recipe = "iron-gear-wheel", quality = "rare",
      machine = "assembling-machine-3", recycler = "recycler",
      pole = "medium-electric-pole",
    }
    for key, value in pairs(overrides or {}) do choices[key] = value end
    return choices
  end

  test("one moduled beacon per tier, fully powered, nine tiles of width", function()
    local without = planner.plan(force(), gear_choices())
    local plan = planner.plan(force(), gear_choices({ beacon = "beacon" }))
    assert(plan, "the beacon plan failed")
    assert(plan.width == without.width + 9,
      "width " .. plan.width .. ", expected the beaconless " .. without.width .. " plus 3*3")

    local beacons = {}
    for _, e in pairs(plan.entities) do
      if e.name == "beacon" then beacons[#beacons + 1] = e end
    end
    assert(#beacons == 3, "beacon count " .. #beacons .. ", expected one per tier")
    for _, b in pairs(beacons) do
      assert(b.modules.name == "efficiency-module-3",
        "beacon module " .. tostring(b.modules.name))
      assert(b.modules.count == 2, "beacon module count " .. tostring(b.modules.count))
      assert(b.module_inventory == defines.inventory.beacon_modules,
        "beacon entity carries inventory " .. tostring(b.module_inventory))
    end
    -- The beacons are consumers, and the pole pass must still cover everything.
    assert(plan.unpowered == nil, tostring(plan.unpowered) .. " consumers left unpowered")
  end)

  test("stamped: beacon ghosts carry the insert plan in the beacon inventory", function()
    local plan = planner.plan(force(), gear_choices({ beacon = "beacon" }))
    local ghosts = stamping.place(plan, nauvis(), force())
    assert(#ghosts == #plan.entities, "built " .. #ghosts .. " of " .. #plan.entities)

    local beacon_ghosts = nauvis().find_entities_filtered({ ghost_name = "beacon" })
    assert(#beacon_ghosts == 3, "beacon ghost count " .. #beacon_ghosts)
    for _, ghost in pairs(beacon_ghosts) do
      local entries = ghost.insert_plan
      assert(#entries == 1, "beacon ghost insert plan entries " .. #entries)
      assert(entries[1].id.name == "efficiency-module-3",
        "beacon ghost plans " .. tostring(entries[1].id.name))
      for _, slot in pairs(entries[1].items.in_inventory) do
        assert(slot.inventory == defines.inventory.beacon_modules,
          "ghost insert plan targets inventory " .. tostring(slot.inventory))
      end
    end
  end)

  test("revived: every machine and recycler is inside some beacon's reach", function()
    -- The engine's own answer, not the planner's arithmetic: revive the loop and ask each
    -- beacon who it reaches. The union must hold every machine and every recycler -- the
    -- geometry promise the whole feature makes.
    local plan = planner.plan(force(), gear_choices({ beacon = "beacon" }))
    stamping.place(plan, nauvis(), force())
    stamping.revive_all(nauvis())

    local reached = {}
    local beacons = nauvis().find_entities_filtered({ name = "beacon" })
    assert(#beacons == 3, "revived beacon count " .. #beacons)
    for _, beacon in pairs(beacons) do
      for _, receiver in pairs(beacon.get_beacon_effect_receivers()) do
        reached[receiver.unit_number] = true
      end
    end

    local machines = nauvis().find_entities_filtered({ name = "assembling-machine-3" })
    local recyclers = nauvis().find_entities_filtered({ name = "recycler" })
    assert(#machines == 3 and #recyclers == 2,
      "revived " .. #machines .. " machines and " .. #recyclers .. " recyclers")
    for _, entity in pairs(machines) do
      assert(reached[entity.unit_number], "a machine at " .. serpent.line(entity.position)
        .. " receives no beacon")
    end
    for _, entity in pairs(recyclers) do
      assert(reached[entity.unit_number], "a recycler at " .. serpent.line(entity.position)
        .. " receives no beacon")
    end
  end)
end)
