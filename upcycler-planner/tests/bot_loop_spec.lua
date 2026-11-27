-- The bot loop live: a planned gear loop to rare, stamped, revived and powered, inside a
-- logistic network of its own -- and robots actually carrying what each tier hands on.
--
-- The stamped machines and recyclers ask for quality modules no chest holds, so nothing ever
-- rolls a quality: what moves up a tier is only what a spec seeds. A recycler's yield is still
-- random -- a gear recycles to a plate half the time -- so an assertion about a tier that
-- recycles a seeded item allows for that plate. The network stands a few ticks AFTER the
-- loop, so no robot is dispatched before the revived chests' requests have settled
-- (analysis/api.md S36). The rig stands away from spawn, clear of the player's character.

local planner = require("scripts.planner")
local research = require("tests.support.research")
local stamping = require("tests.support.stamp")
local component = require("tests.support.component")

local UNCOMMON_PLATE = { name = "iron-plate", quality = "uncommon" }
local UNCOMMON_GEAR = { name = "iron-gear-wheel", quality = "uncommon" }
local RARE_GEAR = { name = "iron-gear-wheel", quality = "rare" }
local RIG = { x = 40, y = 40 }

local function force()
  return game.forces.player
end

local function nauvis()
  return game.surfaces["nauvis"]
end

local function wipe()
  stamping.wipe(nauvis(), true)
end

-- The live entity standing on a plan entity's tile, through the stamp's measured offset.
local function live(plan_entity, ox, oy)
  local x = plan_entity.dx + plan_entity.w / 2 + ox
  local y = plan_entity.dy + plan_entity.h / 2 + oy
  return nauvis().find_entities_filtered({ position = { x, y }, name = plan_entity.name })[1]
end

local function planned(plan, role, tier)
  for _, e in pairs(plan.entities) do
    if e.circuit_role == role and e.circuit_tier == tier then return e end
  end
  assert(false, "no " .. role .. " in tier " .. tier .. " -- the fixture moved")
end

-- The untagged chest at a column's own tile: the out chest top right, the extract chest
-- bottom left, both found from the tier's machine.
local function chest_at(plan, x, y, ox, oy)
  for _, e in pairs(plan.entities) do
    if e.dx == x and e.dy == y then return live(e, ox, oy) end
  end
  assert(false, "nothing planned at " .. x .. "," .. y)
end

-- The loop, revived and powered: an energy interface and a substation beside it, whose wire
-- reaches the revived poles. Gears to rare unless the spec says otherwise.
local function stand_loop(overrides)
  local s, f = nauvis(), force()
  local choices = {
    recipe = "iron-gear-wheel", quality = "rare",
    machine = "assembling-machine-3", recycler = "recycler",
    pole = "medium-electric-pole", layout = "bot",
  }
  for key, value in pairs(overrides or {}) do choices[key] = value end
  local plan = assert(planner.plan(f, choices), "plan failed in test setup")
  local ghosts, ox, oy = stamping.place(plan, s, f, {
    position = { x = RIG.x + plan.width / 2, y = RIG.y + plan.height / 2 },
  })
  assert(#ghosts == #plan.entities and ox, "test setup: placement incomplete")
  stamping.revive_all(s)
  s.create_entity({ name = "electric-energy-interface", position = { plan.width + 2.5 + ox, 4.5 + oy }, force = f })
  s.create_entity({ name = "substation", position = { plan.width + 2.5 + ox, 7.5 + oy }, force = f })
  return plan, ox, oy
end

-- The network over it, on a power island of its own: a roboport with robots, a storage chest
-- for what nobody requests, and a base holding normal plates for the first tier.
local function stand_network(plan, ox, oy)
  local s, f = nauvis(), force()
  local x, y = plan.width + 12 + ox, 4 + oy
  s.create_entity({ name = "electric-energy-interface", position = { x + 6, y }, force = f })
  s.create_entity({ name = "medium-electric-pole", position = { x + 3.5, y + 0.5 }, force = f })
  local port = s.create_entity({ name = "roboport", position = { x, y }, force = f })
  port.insert({ name = "logistic-robot", count = 50 })
  local storage = s.create_entity({ name = "storage-chest", position = { x + 0.5, y + 4.5 }, force = f })
  local base = s.create_entity({ name = "passive-provider-chest", position = { x + 2.5, y + 4.5 }, force = f })
  base.insert({ name = "iron-plate", count = 2000 })
  return port, storage
end

describe("a stamped bot loop", function()
  before_all(function() research.full(force()) end)
  after_each(wipe)

  test("each tier hands on to the tier that asks, its own product comes back, the rest is stored", function()
    local plan, ox, oy = stand_loop()
    local m0 = planned(plan, "machine", 1)
    local out0 = chest_at(plan, m0.dx + m0.w - 1, 0, ox, oy)
    local extract0 = chest_at(plan, m0.dx, plan.height - 1, ox, oy)
    local recycler0 = live(planned(plan, "recycler", 1), ox, oy)
    assert(out0.name == "active-provider-chest" and extract0.name == "active-provider-chest",
      "the fixture moved: tier 0's out and extract chests are not where the layout puts them")
    -- What tier 0 hands on in a real run, seeded instead of rolled: a plate that rolled up
    -- inside its recycler -- loop_spec's stand-in, which the extract inserter must take out --
    -- a lucky gear one tier up, and three gears already at the target.
    local seeded = recycler0.get_inventory(defines.inventory.crafter_output)
      .insert({ name = UNCOMMON_PLATE.name, quality = UNCOMMON_PLATE.quality, count = 1 })
    assert(seeded == 1, "cannot seed the recycler output by script -- seeding strategy broken")
    out0.insert({ name = UNCOMMON_GEAR.name, quality = UNCOMMON_GEAR.quality, count = 1 })
    out0.insert({ name = RARE_GEAR.name, quality = RARE_GEAR.quality, count = 3 })

    after_ticks(10, function()
      local port, storage = stand_network(plan, ox, oy)
      after_ticks(2400, function()
        assert(port.logistic_network, "the rig did not stand: no network")
        assert(recycler0.get_item_count(UNCOMMON_PLATE) == 0 and extract0.get_item_count(UNCOMMON_PLATE) == 0,
          "the rolled-up plate never left tier 0")
        -- The seeded plate, plus the one tier 1's recycler throws in when the lucky gear
        -- yields one: either it still sits in the feed chest or the machine, or it went
        -- into a craft.
        local feed1 = live(planned(plan, "feed", 2), ox, oy)
        local machine1 = live(planned(plan, "machine", 2), ox, oy)
        assert(feed1.get_item_count(UNCOMMON_PLATE) + machine1.get_item_count(UNCOMMON_PLATE) >= 1
          or machine1.products_finished > 0, "the rolled-up plate never reached tier 1's feed chest")

        local return1 = live(planned(plan, "census", 2), ox, oy)
        local recycler1 = live(planned(plan, "recycler", 2), ox, oy)
        assert(return1.get_item_count(UNCOMMON_GEAR) + recycler1.get_item_count(UNCOMMON_GEAR) >= 1
          or recycler1.products_finished > 0, "the lucky gear never reached tier 1's recycler")

        assert(storage.get_item_count(RARE_GEAR) == 3,
          "finished gears from a lower tier must go to storage, found "
          .. storage.get_item_count(RARE_GEAR))
        assert(out0.get_item_count(RARE_GEAR) == 0 and out0.get_item_count(UNCOMMON_GEAR) == 0,
          "tier 0's out chest kept what it handed on")

        -- Tier 0's own product, the whole way round: crafted from the base's plates, handed
        -- to the network, requested back by the return chest and recycled.
        local machine0 = live(m0, ox, oy)
        assert(machine0.products_finished > 0, "tier 0 never crafted from the base's plates")
        assert(recycler0.products_finished > 0,
          "tier 0's recycler never got its own gears back through the network")
      end)
    end)
  end)
end)

describe("a bot loop whose circuit spine relays", function()
  -- The big mining drill is cast on Vulcanus alone -- its recipe asks for 4000 pressure -- and
  -- a machine anywhere else comes out of the ghost with no recipe at all, so nauvis borrows
  -- the pressure for these tests.
  local pressure
  before_all(function()
    research.full(force())
    pressure = nauvis().get_property("pressure")
    nauvis().set_property("pressure", 4000)
  end)
  after_all(function() nauvis().set_property("pressure", pressure) end)
  after_each(wipe)

  test("the relay inserters carry the wire and keep working", function()
    -- A foundry with beacons opens columns too wide for one wire hop, so each machine links
    -- to the next through the inserters at the top of the columns (circuits.lua).
    local plan, ox, oy = stand_loop({
      recipe = "big-mining-drill", machine = "foundry", beacon = "beacon",
      circuit_enabled = true, circuit_max_rare = 10,
    })
    local limits_index
    for index, e in pairs(plan.entities) do
      if e.circuit_role == "limits" then limits_index = index end
    end
    local joined = component(plan.entities, limits_index, "circuit_wire_to")
    local planned_count, relays, feed_relay = 0, 0, nil
    for index in pairs(joined) do
      planned_count = planned_count + 1
      local e = plan.entities[index]
      if e.circuit_role == "relay_out" or e.circuit_role == "relay_in" then
        relays = relays + 1
        -- Wired, but given no behaviour: it must neither wait on a condition nor put its
        -- hand on the wire beside the combinator's signals.
        local behavior = live(e, ox, oy).get_control_behavior()
        assert(not (behavior and behavior.circuit_enable_disable),
          "a relay inserter came out gated by the circuit")
        assert(not (behavior and behavior.circuit_read_hand_contents),
          "a relay inserter came out reading its hand onto the wire")
        if e.circuit_role == "relay_in" then feed_relay = feed_relay or e end
      end
    end
    assert(relays > 0 and feed_relay, "the fixture moved: this plan no longer relays its spine")

    local combinator = live(plan.entities[limits_index], ox, oy)
    local reached = stamping.reachable(combinator, defines.wire_connector_id.circuit_green)
    assert(reached == planned_count, "the built green network holds " .. reached
      .. " of the plan's " .. planned_count)

    -- An ingredient in the feed chest of the tier a relayed hop reaches, at that tier's
    -- quality: the wired feed inserter must still carry it into the machine. (A script cannot
    -- seed an assembler's result slot, so the out inserter's side is not driven here.)
    local tier = feed_relay.circuit_tier
    local m = planned(plan, "machine", tier)
    local part = { name = "electric-mining-drill", quality = m.recipe_quality }
    live(planned(plan, "feed", tier), ox, oy).insert({ name = part.name, quality = part.quality, count = 1 })
    -- Under a cap the machine counts the network, so outside one it stays switched off and
    -- takes nothing in: a roboport over it, on a power island of its own above the plan.
    local s, f = nauvis(), force()
    local x, y = m.dx + ox + 2, oy - 6
    s.create_entity({ name = "electric-energy-interface", position = { x + 6, y }, force = f })
    s.create_entity({ name = "medium-electric-pole", position = { x + 3.5, y + 0.5 }, force = f })
    s.create_entity({ name = "roboport", position = { x, y }, force = f })
    after_ticks(300, function()
      local machine, inserter = live(m, ox, oy), live(feed_relay, ox, oy)
      local function status_name(entity)
        for name, value in pairs(defines.entity_status) do
          if value == entity.status then return name end
        end
        return tostring(entity.status)
      end
      assert(machine.get_item_count(part) == 1, "the wired relay inserter stopped carrying: inserter "
        .. status_name(inserter) .. ", machine " .. status_name(machine) .. ", feed chest holds "
        .. live(planned(plan, "feed", tier), ox, oy).get_item_count(part))
    end)
  end)
end)
