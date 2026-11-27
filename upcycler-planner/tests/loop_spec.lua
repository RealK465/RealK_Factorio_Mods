-- The loop's two live mechanisms for material that rolled above the tier it belongs to, both
-- measured rather than reasoned about: real entities, real power, real ticks.
--
-- The overflow tap is what keeps the RING from silting up -- one nameless quality filter
-- draining everything above the target into an active provider (analysis/api.md S24).
--
-- The standing caution, put on trial: what the recycler's eject actually does when the
-- machine above refuses a rolled-up ingredient (analysis/api.md S9.6 -- assumed from
-- mining-drill behaviour, never proven).
--
-- The assertions here are the SAFE invariants: nothing is lost, nothing wrong-quality reaches
-- the pinned machine, and the relief inserter drains what the eject cannot deliver. The parts
-- that were genuinely unknown -- does the eject wedge the whole recycler or skip past the
-- stuck item -- are LOGGED (grep factorio-current.log for UPL-LOOP-FINDING), because whichever
-- way they land is a finding for .ai-support, not a pass/fail.

local planner = require("scripts.planner")
local circuits = require("scripts.circuits")
local research = require("tests.support.research")
local stamping = require("tests.support.stamp")

local UNCOMMON_PLATE = { name = "iron-plate", quality = "uncommon" }

local function force()
  return game.forces.player
end

local function nauvis()
  return game.surfaces["nauvis"]
end

local function wipe()
  stamping.wipe(nauvis())
end

-- One machine-recycler pair exactly as the layout stands them: tangent, eject north into the
-- machine's bottom row, powered by an energy interface through a substation. The relief
-- inserter below the recycler whitelists anything above the tier's quality and names no
-- item, mirroring layout.lua -- one slot whatever the recipe, where the per-ingredient
-- blacklist it replaced cost one per ingredient.
local function build_rig(opts)
  opts = opts or {}
  local s = nauvis()
  local f = force()

  local machine = s.create_entity({
    name = "assembling-machine-2", position = { 1.5, 1.5 }, force = f,
  })
  machine.set_recipe("iron-gear-wheel", "normal")

  local recycler = s.create_entity({
    name = "recycler", position = { 1, 5 }, direction = defines.direction.north, force = f,
  })

  s.create_entity({ name = "electric-energy-interface", position = { 5, 1 }, force = f })
  s.create_entity({ name = "substation", position = { 5, 4 }, force = f })

  local rig = { machine = machine, recycler = recycler }
  if opts.relief then
    -- The planner's own pick for the position, not a hand-chosen inserter: the wedge-relief
    -- measurement must cover what layout.lua will actually stand there.
    local relief_name = planner.inserter(f, 1)
    assert(relief_name, "planner offered no relief inserter at full research")
    local inserter = s.create_entity({
      name = relief_name, position = { 0.5, 7.5 },
      direction = defines.direction.north, force = f,
    })
    inserter.use_filters = true
    inserter.inserter_filter_mode = "whitelist"
    inserter.set_filter(1, { quality = "normal", comparator = ">" })
    rig.inserter = inserter
    rig.chest = s.create_entity({ name = "steel-chest", position = { 0.5, 8.5 }, force = f })
  end
  return rig
end

local function feed_gears(recycler, count)
  local inserted = recycler.get_inventory(defines.inventory.crafter_input)
    .insert({ name = "iron-gear-wheel", count = count, quality = "normal" })
  assert(inserted == count, "test setup: only " .. inserted .. " gears went in")
end

local function seed_stuck_plate(recycler)
  -- The deterministic stand-in for a lucky quality roll: a rolled-up ingredient sitting in
  -- the output, exactly what a moduled recycler produces a fraction of the time. If script
  -- insertion into the output inventory ever stops working, this whole file needs a new
  -- seeding strategy -- hence the loud assert.
  local inserted = recycler.get_inventory(defines.inventory.crafter_output)
    .insert({ name = "iron-plate", count = 1, quality = "uncommon" })
  assert(inserted == 1, "cannot seed the recycler output by script -- seeding strategy broken")
end

local function contents_line(entity, inventory)
  local parts = {}
  for _, item in pairs(entity.get_inventory(inventory).get_contents()) do
    parts[#parts + 1] = item.count .. "x " .. item.name .. "@" .. (item.quality or "normal")
  end
  return table.concat(parts, ", ")
end

-- The mod's own ring in miniature: top flows west, left south, bottom east, right north, each
-- corner facing where the items go next. Small enough to lap in seconds, which is the point --
-- a straight run cannot tell "the tap missed it" from "it settled past the pickup tile".
local function build_ring(size)
  local s, f = nauvis(), force()
  local belts, last = {}, size - 1
  local function belt(x, y, dir)
    belts[#belts + 1] = s.create_entity({
      name = "transport-belt", position = { x + 0.5, y + 0.5 }, direction = dir, force = f,
    })
  end
  belt(0, 0, defines.direction.south)
  for x = 1, last do belt(x, 0, defines.direction.west) end
  for y = 1, last - 1 do belt(0, y, defines.direction.south) end
  belt(0, last, defines.direction.east)
  for x = 1, last - 1 do belt(x, last, defines.direction.east) end
  belt(last, last, defines.direction.north)
  for y = 1, last - 1 do belt(last, y, defines.direction.north) end
  return belts
end

describe("the overflow tap on a circulating ring", function()
  before_all(function() research.full(force()) end)
  after_each(wipe)

  test("one nameless filter drains everything above the target, out of both lanes", function()
    -- The layout's whole answer to above-target rolls, live. A single filter naming a quality
    -- and no item has to clear every ingredient AND the product from a ring that keeps handing
    -- them back, without ever touching the target tier the terminal machine still needs.
    --
    -- Both belt lanes matter: an inserter reaches a belt's far lane first, so a far lane full of
    -- items the filter refuses could in principle starve the near one forever.
    local s, f = nauvis(), force()
    -- The substation has to cover the tap itself, or it never swings and the run reads as a
    -- filter failure rather than a rig failure.
    s.create_entity({ name = "substation", position = { 4, 12 }, force = f })
    s.create_entity({ name = "electric-energy-interface", position = { 8, 12 }, force = f })

    local belts = build_ring(8)

    -- The planner's own pick, not a hand-chosen inserter: the tap must be measured on the thing
    -- layout.lua will actually stand there.
    local tap_name = planner.inserter(f, 1)
    assert(tap_name, "planner offered no inserter at full research")
    local tap = s.create_entity({
      name = tap_name, position = { 3.5, 8.5 }, direction = defines.direction.north, force = f,
    })
    tap.use_filters = true
    tap.inserter_filter_mode = "whitelist"
    -- No item name at all: the engine reads that as "anything, at a quality above this one".
    tap.set_filter(1, { quality = "rare", comparator = ">" })
    local chest = s.create_entity({ name = "active-provider-chest", position = { 3.5, 9.5 }, force = f })

    -- One item per lane per tile: two insert_at_back calls on the same line back to back are
    -- refused for want of room, which silently seeds nothing.
    local seeded = 0
    for i, quality in ipairs({ "normal", "uncommon", "rare", "epic", "legendary" }) do
      for lane = 1, 2 do
        for offset, name in ipairs({ "iron-plate", "iron-gear-wheel" }) do
          local line = belts[i * 2 + (offset - 1) * 10].get_transport_line(lane)
          if line.insert_at_back({ name = name, quality = quality }) then seeded = seeded + 1 end
        end
      end
    end
    assert(seeded == 20, "test setup: only " .. seeded .. " of 20 items reached the ring")

    after_ticks(3600, function()
      -- Above the target: gone from the ring, all of it, both items and both lanes.
      for _, quality in ipairs({ "epic", "legendary" }) do
        for _, name in ipairs({ "iron-plate", "iron-gear-wheel" }) do
          local held = chest.get_item_count({ name = name, quality = quality })
          assert(held == 2, name .. "@" .. quality .. " in the chest: " .. held .. ", wanted 2")
        end
      end
      -- At or below it: untouched. The terminal machine still needs its own tier off this ring,
      -- so a tap that reached one tier too low would starve the loop it is meant to unclog.
      for _, quality in ipairs({ "normal", "uncommon", "rare" }) do
        for _, name in ipairs({ "iron-plate", "iron-gear-wheel" }) do
          local stolen = chest.get_item_count({ name = name, quality = quality })
          assert(stolen == 0, "the tap took " .. stolen .. "x " .. name .. "@" .. quality)
        end
      end
    end)
  end)
end)

describe("the recycler eject under a rolled-up ingredient", function()
  before_all(function() research.full(force()) end)
  after_each(wipe)

  test("baseline: the eject alone feeds the machine, zero inserters", function()
    -- Fact 3 live: vector_to_place_result delivers recycled ingredients straight into the
    -- tangent machine, which is the constraint the whole layout hangs off.
    local rig = build_rig()
    feed_gears(rig.recycler, 40)
    after_ticks(600, function()
      assert(rig.recycler.products_finished > 0, "recycler never recycled anything")
      assert(rig.machine.products_finished > 0,
        "machine never crafted -- the eject did not deliver with zero inserters")
    end)
  end)

  test("the relief inserter drains what the eject cannot deliver, and the loop keeps moving", function()
    local rig = build_rig({ relief = true })
    seed_stuck_plate(rig.recycler)
    feed_gears(rig.recycler, 40)
    after_ticks(900, function()
      -- The rolled-up plate must end in the chest: it is above this tier's quality, so the
      -- nameless filter takes it while leaving the eject's own flow alone.
      assert(rig.chest.get_item_count(UNCOMMON_PLATE) == 1,
        "the relief inserter did not extract the rolled-up plate")
      assert(rig.recycler.get_item_count(UNCOMMON_PLATE) == 0,
        "the rolled-up plate is still inside the recycler")
      -- Quality matching is exact: the pinned machine must never have received it.
      assert(rig.machine.get_item_count(UNCOMMON_PLATE) == 0,
        "an above-tier ingredient reached the pinned machine")
      -- And the stall, if there was one, resolved: the loop went on to craft.
      assert(rig.machine.products_finished > 0,
        "the loop never resumed after the rolled-up ingredient")
      log("UPL-LOOP-FINDING relief: machine crafted " .. rig.machine.products_finished
        .. ", recycler finished " .. rig.recycler.products_finished
        .. ", recycler output now: " .. contents_line(rig.recycler, defines.inventory.crafter_output))
    end)
  end)

  test("the relief inserter leaves the tier's own ingredient to the eject", function()
    -- The other half of the equivalence with the blacklist it replaced: a plate AT the
    -- tier's quality is the eject's to deliver, and the relief must never poach it. Seeded
    -- into the output beside the rolled-up one, it has to reach the machine or stay in the
    -- recycler -- never the chest -- while the loop crafts on.
    local NORMAL_PLATE = { name = "iron-plate", quality = "normal" }
    local rig = build_rig({ relief = true })
    local seeded = rig.recycler.get_inventory(defines.inventory.crafter_output)
      .insert({ name = "iron-plate", count = 1, quality = "normal" })
    assert(seeded == 1, "cannot seed a normal plate into the recycler output")
    seed_stuck_plate(rig.recycler)
    feed_gears(rig.recycler, 40)
    after_ticks(900, function()
      assert(rig.chest.get_item_count(NORMAL_PLATE) == 0,
        "the relief inserter took a same-quality plate meant for the eject")
      assert(rig.chest.get_item_count(UNCOMMON_PLATE) == 1,
        "the relief inserter did not extract the rolled-up plate beside it")
      assert(rig.machine.get_item_count(UNCOMMON_PLATE) == 0,
        "an above-tier ingredient reached the pinned machine")
      assert(rig.machine.products_finished > 0,
        "the loop never resumed with both plates seeded")
    end)
  end)

  test("without relief the plate stays put, is never delivered, and nothing is lost", function()
    -- deferred.md's accepted limitation, measured. Whether the eject skips past the stuck
    -- item or wedges the recycler entirely was the genuinely unknown half -- logged, not
    -- asserted, because either answer is a finding.
    local rig = build_rig()
    seed_stuck_plate(rig.recycler)
    feed_gears(rig.recycler, 40)
    after_ticks(900, function()
      assert(rig.machine.get_item_count(UNCOMMON_PLATE) == 0,
        "an above-tier ingredient reached the pinned machine")
      assert(rig.recycler.get_item_count(UNCOMMON_PLATE) == 1,
        "the stuck plate left the recycler with nothing there to take it")
      log("UPL-LOOP-FINDING no-relief: machine crafted " .. rig.machine.products_finished
        .. " (>0 means the eject skips past a stuck item; 0 means it wedges)"
        .. ", recycler finished " .. rig.recycler.products_finished
        .. ", recycler output now: " .. contents_line(rig.recycler, defines.inventory.crafter_output))
    end)
  end)
end)

describe("a circuit limit on a live machine", function()
  before_all(function() research.full(force()) end)
  after_each(wipe)

  -- The cascade's one genuinely emergent claim, measured: a machine gated on a wired chest's
  -- count stops when the stock is met, resumes when it drains, and a machine whose condition
  -- has NO connected wire just runs -- the graceful degradation plan.circuit_unlinked leans
  -- on. Runtime names here, not blueprint ones: circuit_enable_disable, the S21 rename trap.
  test("pauses at the threshold, resumes on drain; unwired runs free", function()
    local s, f = nauvis(), force()
    s.create_entity({ name = "electric-energy-interface", position = { 12, 4 }, force = f })
    s.create_entity({ name = "substation", position = { 8, 4 }, force = f })

    local function gated_machine(position)
      local machine = s.create_entity({
        name = "assembling-machine-2", position = position, force = f,
      })
      machine.set_recipe("iron-gear-wheel", "normal")
      machine.get_inventory(defines.inventory.crafter_input)
        .insert({ name = "iron-plate", count = 40, quality = "normal" })
      local cb = machine.get_or_create_control_behavior()
      cb.circuit_enable_disable = true
      cb.circuit_condition = {
        comparator = "<", constant = 5,
        first_signal = { type = "item", name = "iron-gear-wheel", quality = "normal" },
      }
      return machine
    end

    local wired = gated_machine({ 1.5, 1.5 })
    local free = gated_machine({ 1.5, 8.5 })

    local chest = s.create_entity({ name = "steel-chest", position = { 4.5, 1.5 }, force = f })
    chest.get_inventory(defines.inventory.chest)
      .insert({ name = "iron-gear-wheel", count = 5, quality = "normal" })
    wired.get_wire_connector(defines.wire_connector_id.circuit_green, true)
      .connect_to(chest.get_wire_connector(defines.wire_connector_id.circuit_green, true))

    after_ticks(300, function()
      assert(wired.products_finished == 0,
        "the wired machine crafted " .. wired.products_finished .. " past its met limit")
      assert(free.products_finished > 0,
        "the unwired machine idled -- a condition with no network must gate nothing")

      chest.get_inventory(defines.inventory.chest).clear()
      after_ticks(300, function()
        assert(wired.products_finished > 0,
          "the wired machine never resumed after its chest drained")
      end)
    end)
  end)

  -- The reserve rule live, in the shipped shape: an inserter pinned to a hand and gated
  -- "count >= floor + hand" on its source chest stops with the floor still inside. The
  -- inserter checks its condition at pickup and then takes a whole hand, which is why a
  -- bare "count > floor" dipped by up to a hand (measured: a 12-hand against 20 left 8,
  -- api.md S33); raising the threshold by the hand puts a full grab exactly on the floor,
  -- and the pin is what makes that arithmetic hold -- research gives this bulk inserter 12,
  -- the pin says 5, and 5 is what it takes. 30 in, floor 15, threshold 20: three grabs of
  -- five, then 15 < 20 holds it with the floor intact.
  test("a pinned, gated inserter leaves the floor in the chest", function()
    local s, f = nauvis(), force()
    s.create_entity({ name = "electric-energy-interface", position = { 8, 2 }, force = f })
    s.create_entity({ name = "substation", position = { 5, 2 }, force = f })

    local source = s.create_entity({ name = "steel-chest", position = { 0.5, 2.5 }, force = f })
    local sink = s.create_entity({ name = "steel-chest", position = { 0.5, 0.5 }, force = f })
    -- Direction is the PICKUP side: south is the source chest, the drop lands north in the
    -- sink -- the tap and relief rigs above follow the same rule.
    local hand = s.create_entity({
      name = "bulk-inserter", position = { 0.5, 1.5 },
      direction = defines.direction.south, force = f,
    })
    hand.inserter_stack_size_override = 5

    source.get_inventory(defines.inventory.chest)
      .insert({ name = "iron-gear-wheel", count = 30, quality = "normal" })
    hand.get_wire_connector(defines.wire_connector_id.circuit_green, true)
      .connect_to(source.get_wire_connector(defines.wire_connector_id.circuit_green, true))
    local cb = hand.get_or_create_control_behavior()
    cb.circuit_enable_disable = true
    cb.circuit_condition = {
      comparator = ">=", constant = 20,
      first_signal = { type = "item", name = "iron-gear-wheel", quality = "normal" },
    }

    after_ticks(300, function()
      local kept = source.get_item_count({ name = "iron-gear-wheel", quality = "normal" })
      local moved = sink.get_item_count({ name = "iron-gear-wheel", quality = "normal" })
      assert(kept == 15, "the reserve held " .. kept .. " gears, expected the floor of 15")
      assert(moved == 15, "the inserter moved " .. moved .. " gears, expected the 15 surplus")
      assert(hand.inserter_target_pickup_count == 5,
        "the pin did not hold: the hand reads " .. hand.inserter_target_pickup_count)
    end)
  end)

  -- The combinator-carried cap, live (api.md S32): the machine compares its chest's count
  -- against the combinator's signal-C row -- a quality-tagged virtual signal -- resumes when
  -- the row is raised, and stops when the combinator is switched off, since C then reads 0
  -- and no count is below 0. The lamps' always_on lifts the night-only rule WITHOUT lifting
  -- the condition: at frozen noon a lit lamp reads "working" and an unlit one
  -- "disabled_by_control_behavior". Runtime names throughout, the combinator's switch
  -- included: `enabled` here, `is_on` in the blueprint.
  test("a combinator-carried cap pauses, resumes, stops when switched off; the lamps follow", function()
    local s, f = nauvis(), force()
    s.create_entity({ name = "electric-energy-interface", position = { 12, 4 }, force = f })
    s.create_entity({ name = "substation", position = { 8, 4 }, force = f })
    s.daytime = 0
    s.freeze_daytime = true

    local gear = { type = "item", name = "iron-gear-wheel", quality = "normal" }
    local cap = { type = "virtual", name = "signal-C", quality = "rare" }

    local machine = s.create_entity({
      name = "assembling-machine-2", position = { 1.5, 1.5 }, force = f,
    })
    machine.set_recipe("iron-gear-wheel", "normal")
    machine.get_inventory(defines.inventory.crafter_input)
      .insert({ name = "iron-plate", count = 100, quality = "normal" })
    local mcb = machine.get_or_create_control_behavior()
    mcb.circuit_enable_disable = true
    mcb.circuit_condition = { comparator = "<", first_signal = gear, second_signal = cap }

    local chest = s.create_entity({ name = "steel-chest", position = { 4.5, 1.5 }, force = f })
    chest.get_inventory(defines.inventory.chest)
      .insert({ name = "iron-gear-wheel", count = 5, quality = "normal" })

    local combinator = s.create_entity({
      name = "constant-combinator", position = { 4.5, 3.5 }, force = f,
    })
    local section = combinator.get_or_create_control_behavior().get_section(1)
    section.set_slot(1, { value = cap, min = 5 })

    local function lamp(position, comparator)
      local entity = s.create_entity({ name = "small-lamp", position = position, force = f })
      entity.always_on = true
      local cb = entity.get_or_create_control_behavior()
      cb.circuit_enable_disable = true
      cb.circuit_condition = { comparator = comparator, first_signal = gear, second_signal = cap }
      return entity
    end
    local done = lamp({ 6.5, 1.5 }, ">=")
    local running = lamp({ 6.5, 2.5 }, "<")

    local function green(e) return e.get_wire_connector(defines.wire_connector_id.circuit_green, true) end
    for _, e in pairs({ machine, combinator, done, running }) do
      green(e).connect_to(green(chest))
    end

    local working = defines.entity_status.working
    local gated = defines.entity_status.disabled_by_control_behavior
    after_ticks(240, function()
      assert(machine.products_finished == 0, "the machine crafted past a cap the combinator carries")
      assert(machine.status == gated, "the capped machine reads status " .. tostring(machine.status))
      assert(done.status == working and running.status == gated,
        "at the cap the lamps read done " .. tostring(done.status) .. ", running " .. tostring(running.status))

      section.set_slot(1, { value = cap, min = 10 })
      after_ticks(240, function()
        assert(machine.products_finished > 0, "the machine never resumed after the row was raised")
        assert(done.status == gated and running.status == working,
          "below the cap the lamps read done " .. tostring(done.status) .. ", running " .. tostring(running.status))

        local before = machine.products_finished
        combinator.get_control_behavior().enabled = false
        after_ticks(240, function()
          -- One craft may have been in flight when the signal dropped; no further one starts.
          assert(machine.products_finished - before <= 1,
            "the machine crafted " .. (machine.products_finished - before) .. " with the combinator off")
          assert(machine.status == gated, "switched off, the machine reads " .. tostring(machine.status))
          assert(done.status == working, "switched off, the done lamp reads " .. tostring(done.status))
        end)
      end)
    end)
  end)
end)

describe("a logistic-network cap on a live machine", function()
  before_all(function() research.full(force()) end)
  after_each(wipe)

  -- Network mode's three engine facts, measured through a throwaway probe (analysis/api.md
  -- S34) and pinned here: a crafter's logistic condition stops it once the network holds the
  -- count, the wire's pause ANDs with it, and a crafter outside any network is stopped
  -- outright whatever its numbers -- the fact behind the roboport-range warning.
  test("stops at the network's count, pauses on the wire, and stands dead outside any network", function()
    local s, f = nauvis(), force()
    s.create_entity({ name = "electric-energy-interface", position = { 12, 4 }, force = f })
    s.create_entity({ name = "substation", position = { 8, 4 }, force = f })

    local gear = { type = "item", name = "iron-gear-wheel", quality = "normal" }
    local cap = { type = "virtual", name = "signal-C", quality = "rare" }

    -- A network holding 100 gears: a roboport under the substation and a provider beside it.
    local roboport = s.create_entity({ name = "roboport", position = { 14, 10 }, force = f })
    local provider = s.create_entity({
      name = "passive-provider-chest", position = { 4.5, 6.5 }, force = f,
    })
    provider.insert({ name = "iron-gear-wheel", count = 100, quality = "normal" })

    local combinator = s.create_entity({
      name = "constant-combinator", position = { 4.5, 3.5 }, force = f,
    })
    local section = combinator.get_or_create_control_behavior().get_section(1)
    section.set_slot(1, { value = cap, min = 50 })

    -- The shape circuits.lua writes in network mode: the cap as the logistic condition, the
    -- pause as the wire condition, here through the runtime names.
    local function gated_machine(position, wired)
      local machine = s.create_entity({
        name = "assembling-machine-2", position = position, force = f,
      })
      machine.set_recipe("iron-gear-wheel", "normal")
      machine.get_inventory(defines.inventory.crafter_input)
        .insert({ name = "iron-plate", count = 100, quality = "normal" })
      local cb = machine.get_or_create_control_behavior()
      cb.connect_to_logistic_network = true
      cb.logistic_condition = { comparator = "<", first_signal = gear, constant = 50 }
      if wired then
        cb.circuit_enable_disable = true
        cb.circuit_condition = { comparator = ">", first_signal = cap, constant = 0 }
        machine.get_wire_connector(defines.wire_connector_id.circuit_green, true)
          .connect_to(combinator.get_wire_connector(defines.wire_connector_id.circuit_green, true))
      end
      return machine
    end
    local inside = gated_machine({ 1.5, 1.5 }, true)
    -- Far past the roboport's logistic range, on a power island of its own.
    s.create_entity({ name = "electric-energy-interface", position = { 212, 204 }, force = f })
    s.create_entity({ name = "substation", position = { 208, 204 }, force = f })
    local outside = gated_machine({ 201.5, 201.5 }, false)

    local gated = defines.entity_status.disabled_by_control_behavior
    after_ticks(240, function()
      assert(roboport.logistic_network and inside.logistic_network,
        "the rig stood no logistic network")
      assert(inside.products_finished == 0 and inside.status == gated,
        "the machine crafted " .. inside.products_finished .. " with the network at the cap")
      assert(outside.logistic_network == nil, "the far machine found a network")
      assert(outside.products_finished == 0 and outside.status == gated,
        "outside any network the machine crafted " .. outside.products_finished
        .. " -- the roboport-range warning would be a lie")

      -- Draw the network under the cap: the machine resumes.
      provider.get_inventory(defines.inventory.chest).clear()
      after_ticks(240, function()
        assert(inside.products_finished > 0, "the machine never resumed once the network drained")
        -- The wire still pauses it: switched off, C reads 0 and the AND fails.
        local before = inside.products_finished
        combinator.get_control_behavior().enabled = false
        after_ticks(240, function()
          assert(inside.products_finished - before <= 1,
            "the machine crafted " .. (inside.products_finished - before) .. " with the combinator off")
          assert(inside.status == gated, "switched off, the machine reads " .. tostring(inside.status))
        end)
      end)
    end)
  end)
end)

describe("retuning network mode from the combinator", function()
  before_all(function() research.full(force()) end)
  after_each(wipe)

  -- The portal report behind scripts/retune.lua: C raised after the loop had stopped at the
  -- cap changed nothing, because network mode's maximum is a constant on each machine
  -- (analysis/api.md S34). Driven through the real event: set_slot raises
  -- on_entity_logistic_slot_changed synchronously (S35); a player's GUI edit is the one path
  -- no spec can drive.
  local CAP = { type = "virtual", name = "signal-C", quality = "rare" }

  local function network_plan()
    return assert(planner.plan(force(), {
      recipe = "iron-gear-wheel", quality = "rare",
      machine = "assembling-machine-3", recycler = "recycler",
      pole = "medium-electric-pole",
      circuit_enabled = true, circuit_max_rare = 77, circuit_network = true,
    }), "plan failed in test setup")
  end

  -- With no minimum set, C is the plan's only row, so slot 1 -- as on the rig below.
  local function set_cap(combinator, count)
    combinator.get_control_behavior().get_section(1).set_slot(1, { value = CAP, min = count })
  end

  -- The constant on every network-gated entity on the surface, ghosts included.
  local function caps()
    local out = {}
    for _, e in pairs(nauvis().find_entities_filtered({})) do
      local kind = e.type == "entity-ghost" and e.ghost_type or e.type
      if kind == "assembling-machine" or kind == "furnace" or kind == "lamp" then
        local cb = e.get_control_behavior()
        if cb and cb.connect_to_logistic_network then
          out[#out + 1] = cb.logistic_condition.constant
        end
      end
    end
    return out
  end

  test("an edited C reaches every machine, recycler and lamp, ghosts included, and a 0 pauses without it", function()
    stamping.place(network_plan(), nauvis(), force())
    -- Only the combinator built: a loop retuned while the bots are still building it.
    local ghost = nauvis().find_entities_filtered({ ghost_name = "constant-combinator" })[1]
    local _, combinator = ghost.revive()
    set_cap(combinator, 500)
    local seen = caps()
    assert(#seen == 7, #seen .. " network-gated entities, expected three machines, two recyclers, two lamps")
    for _, cap in pairs(seen) do assert(cap == 500, "a ghost kept the cap " .. cap) end

    stamping.revive_all(nauvis())
    for _, cap in pairs(caps()) do assert(cap == 500, "a revived entity came back at " .. cap) end

    -- The wire's C > 0 holds a paused loop; the constants keep the last real maximum.
    set_cap(combinator, 0)
    for _, cap in pairs(caps()) do assert(cap == 500, "the pause rewrote a cap to " .. cap) end
  end)

  test("a combinator without the planner's description retunes nothing", function()
    stamping.place(network_plan(), nauvis(), force())
    stamping.revive_all(nauvis())
    local combinator = nauvis().find_entities_filtered({ name = "constant-combinator" })[1]
    combinator.combinator_description = "my own notes"
    set_cap(combinator, 500)
    for _, cap in pairs(caps()) do assert(cap == 77, "a stranger's combinator rewrote a cap to " .. cap) end
  end)

  test("a machine stopped at the cap runs again once C is raised past the network's count", function()
    local s, f = nauvis(), force()
    s.create_entity({ name = "electric-energy-interface", position = { 12, 4 }, force = f })
    s.create_entity({ name = "substation", position = { 8, 4 }, force = f })
    s.create_entity({ name = "roboport", position = { 14, 10 }, force = f })
    s.create_entity({ name = "passive-provider-chest", position = { 4.5, 6.5 }, force = f })
      .insert({ name = "iron-gear-wheel", count = 100, quality = "rare" })

    local combinator = s.create_entity({ name = "constant-combinator", position = { 4.5, 3.5 }, force = f })
    combinator.combinator_description = circuits.DESCRIPTION_PREFIX .. "test rig"
    combinator.get_or_create_control_behavior().get_section(1).set_slot(1, { value = CAP, min = 50 })

    -- circuits.lua's network-mode shape, through the runtime names.
    local machine = s.create_entity({ name = "assembling-machine-2", position = { 1.5, 1.5 }, force = f })
    machine.set_recipe("iron-gear-wheel", "normal")
    machine.get_inventory(defines.inventory.crafter_input)
      .insert({ name = "iron-plate", count = 100, quality = "normal" })
    local cb = machine.get_or_create_control_behavior()
    cb.connect_to_logistic_network = true
    cb.logistic_condition = {
      comparator = "<", first_signal = { type = "item", name = "iron-gear-wheel", quality = "rare" },
      constant = 50,
    }
    cb.circuit_enable_disable = true
    cb.circuit_condition = { comparator = ">", first_signal = CAP, constant = 0 }
    machine.get_wire_connector(defines.wire_connector_id.circuit_green, true)
      .connect_to(combinator.get_wire_connector(defines.wire_connector_id.circuit_green, true))

    after_ticks(240, function()
      assert(machine.products_finished == 0
        and machine.status == defines.entity_status.disabled_by_control_behavior,
        "the network holds 100 against a cap of 50, yet the machine crafted " .. machine.products_finished)
      set_cap(combinator, 150)
      after_ticks(240, function()
        assert(machine.products_finished > 0, "C raised to 150 over a count of 100, and the machine stayed stopped")
      end)
    end)
  end)
end)

-- The chests stop asking with the loop (circuits.lua's header). Three engine facts carry
-- that design, measured through a throwaway probe (analysis/api.md S36) and pinned here,
-- and above them the whole thing end to end on a stamped plan.
describe("the chests stop asking with the loop", function()
  before_all(function() research.full(force()) end)
  after_each(wipe)

  local CAP = { type = "virtual", name = "signal-C", quality = "rare" }

  local function request(chest, slot, name, count)
    local point = chest.get_requester_point()
    local section = point.get_section(1) or point.add_section()
    section.set_slot(slot, { value = { type = "item", name = name, quality = "normal" }, min = count })
    return point
  end

  local function green(entity)
    return entity.get_wire_connector(defines.wire_connector_id.circuit_green, true)
  end

  -- The network-mode shape circuits.lua writes on a chest -- the pause alone, C > 0 --
  -- through the runtime names, which for this one flag are the blueprint's own.
  local function gate(chest, combinator)
    local cb = chest.get_or_create_control_behavior()
    cb.circuit_condition_enabled = true
    cb.circuit_condition = { comparator = ">", first_signal = CAP, constant = 0 }
    green(chest).connect_to(green(combinator))
  end

  local function switched_off_combinator(position)
    local combinator = nauvis().create_entity({
      name = "constant-combinator", position = position, force = force(),
    })
    local behaviour = combinator.get_or_create_control_behavior()
    behaviour.get_section(1).set_slot(1, { value = CAP, min = 50 })
    behaviour.enabled = false
    return combinator
  end

  -- A capped rare gear loop, stamped and revived but left dark on purpose: these specs read
  -- chests, and a running inserter would move what they count.
  local function stand_loop(overrides)
    local choices = {
      recipe = "iron-gear-wheel", quality = "rare",
      machine = "assembling-machine-3", recycler = "recycler",
      pole = "medium-electric-pole",
      circuit_enabled = true, circuit_max_rare = 50,
    }
    for key, value in pairs(overrides or {}) do choices[key] = value end
    local plan = assert(planner.plan(force(), choices), "plan failed in test setup")
    stamping.place(plan, nauvis(), force())
    stamping.revive_all(nauvis())
  end

  -- A network that reaches the loop from a power island of its own, and a base holding
  -- normal plates and normal gears -- what the first tier's feed and stock chests ask for.
  local function stand_base()
    local s, f = nauvis(), force()
    s.create_entity({ name = "electric-energy-interface", position = { 28, 8 }, force = f })
    s.create_entity({ name = "medium-electric-pole", position = { 25.5, 8.5 }, force = f })
    local roboport = s.create_entity({ name = "roboport", position = { 22, 8 }, force = f })
    roboport.insert({ name = "logistic-robot", count = 50 })
    local base = s.create_entity({ name = "passive-provider-chest", position = { 22.5, 12.5 }, force = f })
    base.insert({ name = "iron-plate", count = 2000 })
    base.insert({ name = "iron-gear-wheel", count = 200 })
    return roboport
  end

  local function held(name, item)
    local total = 0
    for _, chest in pairs(nauvis().find_entities_filtered({ name = name })) do
      total = total + chest.get_item_count(item)
    end
    return total
  end

  test("a paused loop asks the network for nothing, and asks again once switched on", function()
    local s = nauvis()
    stand_loop({ circuit_paused = true })
    local roboport = stand_base()

    after_ticks(600, function()
      assert(roboport.logistic_network
        and #s.find_entities_filtered({ name = "requester-chest" }) == 3, "the rig did not stand")
      assert(held("requester-chest", "iron-plate") == 0,
        "paused, the feed chests were still delivered " .. held("requester-chest", "iron-plate") .. " plates")
      assert(held("buffer-chest", "iron-gear-wheel") == 0,
        "paused, the stock chests were still delivered " .. held("buffer-chest", "iron-gear-wheel") .. " gears")

      local combinator = s.find_entities_filtered({ name = "constant-combinator" })[1]
      combinator.get_control_behavior().enabled = true
      after_ticks(900, function()
        assert(held("requester-chest", "iron-plate") > 0, "switched on, the feed chests ask for nothing")
        assert(held("buffer-chest", "iron-gear-wheel") > 0, "switched on, the stock chests ask for nothing")
      end)
    end)
  end)

  test("at its maximum the loop asks for nothing, and asks again once the output chest is drawn down", function()
    local s = nauvis()
    stand_loop()
    -- The maximum is in the output chest before any network exists, so the wire has settled
    -- on the count by the time a robot could be sent.
    local output = s.find_entities_filtered({ name = "passive-provider-chest" })[1]
    output.insert({ name = "iron-gear-wheel", count = 50, quality = "rare" })

    after_ticks(10, function()
      stand_base()
      after_ticks(600, function()
        for _, chest in pairs(s.find_entities_filtered({ name = { "requester-chest", "buffer-chest" } })) do
          assert(chest.status == defines.entity_status.disabled_by_control_behavior,
            "at the maximum a " .. chest.name .. " reads status " .. tostring(chest.status))
        end
        assert(held("requester-chest", "iron-plate") == 0,
          "at the maximum the feed chests were delivered " .. held("requester-chest", "iron-plate") .. " plates")
        assert(held("buffer-chest", "iron-gear-wheel") == 0,
          "at the maximum the stock chests were delivered " .. held("buffer-chest", "iron-gear-wheel") .. " gears")

        output.remove_item({ name = "iron-gear-wheel", count = 10, quality = "rare" })
        after_ticks(900, function()
          assert(held("requester-chest", "iron-plate") > 0, "below the maximum the feed chests ask for nothing")
          assert(held("buffer-chest", "iron-gear-wheel") > 0, "below the maximum the stock chests ask for nothing")
        end)
      end)
    end)
  end)

  -- Why the stock chests can follow the pause at no cost to the player, why the output chest
  -- must never be gated, and why a gated chest can stay in the loop's own path: disabled, a
  -- BUFFER chest stops asking and keeps handing its items out, a PROVIDER stops providing,
  -- and either still takes and gives to inserters and still reads on the wire.
  test("engine: disabled, a buffer chest stops asking and keeps sharing; a provider stops providing", function()
    local s, f = nauvis(), force()
    s.create_entity({ name = "electric-energy-interface", position = { 12, 4 }, force = f })
    s.create_entity({ name = "substation", position = { 8, 4 }, force = f })
    s.create_entity({ name = "roboport", position = { 14, 10 }, force = f })
      .insert({ name = "logistic-robot", count = 50 })
    local combinator = switched_off_combinator({ 2.5, 8.5 })

    -- The network's only copper sits in a gated buffer chest, its only steel in a gated
    -- provider, and a third gated chest just holds plastic for the wire to read.
    local buffer = s.create_entity({ name = "buffer-chest", position = { 4.5, 6.5 }, force = f })
    buffer.insert({ name = "copper-plate", count = 40 })
    gate(buffer, combinator)
    local provider = s.create_entity({ name = "passive-provider-chest", position = { 8.5, 6.5 }, force = f })
    provider.insert({ name = "steel-plate", count = 40 })
    gate(provider, combinator)
    local census = s.create_entity({ name = "buffer-chest", position = { 8.5, 8.5 }, force = f })
    census.insert({ name = "plastic-bar", count = 7 })
    gate(census, combinator)
    s.create_entity({ name = "passive-provider-chest", position = { 6.5, 6.5 }, force = f })
      .insert({ name = "iron-plate", count = 400 })
    local requester = s.create_entity({ name = "requester-chest", position = { 2.5, 6.5 }, force = f })
    requester.request_from_buffers = true

    -- The same condition with NO wire at all: what a stamped chest is until its wire is
    -- built, and after a player cuts it. It must keep asking, or a missing wire would stall
    -- a loop -- the machines' own rule (api.md S26), here for a chest.
    local unwired = s.create_entity({ name = "requester-chest", position = { 10.5, 6.5 }, force = f })
    local loose = unwired.get_or_create_control_behavior()
    loose.circuit_condition_enabled = true
    loose.circuit_condition = { comparator = ">", first_signal = CAP, constant = 0 }

    -- A gated buffer between two inserters: one filling it, one emptying it.
    local source = s.create_entity({ name = "steel-chest", position = { 2.5, 10.5 }, force = f })
    source.insert({ name = "iron-stick", count = 10 })
    s.create_entity({ name = "fast-inserter", position = { 3.5, 10.5 },
      direction = defines.direction.west, force = f })
    local middle = s.create_entity({ name = "buffer-chest", position = { 4.5, 10.5 }, force = f })
    middle.insert({ name = "iron-gear-wheel", count = 10 })
    gate(middle, combinator)
    s.create_entity({ name = "fast-inserter", position = { 5.5, 10.5 },
      direction = defines.direction.west, force = f })
    local sink = s.create_entity({ name = "steel-chest", position = { 6.5, 10.5 }, force = f })

    -- The requests go in only once the disabled state has settled. Written in the same tick
    -- as the condition on a LIVE chest, one robot is dispatched before the condition is read
    -- (measured: 4 plates); a stamped chest has no such window, the test above shows.
    after_ticks(10, function()
      request(buffer, 1, "iron-plate", 40)
      request(requester, 1, "copper-plate", 40)
      request(requester, 2, "steel-plate", 40)
      request(unwired, 1, "iron-plate", 40)
      after_ticks(600, function()
        assert(unwired.get_item_count("iron-plate") == 40,
          "a condition with no wire stopped the chest asking: it holds "
          .. unwired.get_item_count("iron-plate"))
        assert(buffer.status == defines.entity_status.disabled_by_control_behavior,
          "the gated buffer chest reads status " .. tostring(buffer.status))
        assert(buffer.get_item_count("iron-plate") == 0,
          "disabled, the buffer chest was still delivered " .. buffer.get_item_count("iron-plate"))
        assert(requester.get_item_count("copper-plate") == 40,
          "disabled, the buffer chest stopped sharing: " .. requester.get_item_count("copper-plate"))
        assert(requester.get_item_count("steel-plate") == 0,
          "disabled, the provider still provided " .. requester.get_item_count("steel-plate"))
        local wire = combinator.get_circuit_network(defines.wire_connector_id.circuit_green)
        assert(wire and wire.get_signal({ type = "item", name = "plastic-bar" }) == 7,
          "a disabled chest stopped reading its contents onto the wire")
        assert(source.get_item_count("iron-stick") == 0 and sink.get_item_count("iron-gear-wheel") == 10,
          "an inserter could not fill or empty a disabled chest")

        combinator.get_control_behavior().enabled = true
        after_ticks(900, function()
          assert(buffer.get_item_count("iron-plate") >= 40, "enabled, the buffer chest never asked")
          assert(requester.get_item_count("steel-plate") == 40, "enabled, the provider never provided")
        end)
      end)
    end)
  end)

  -- Why a stock chest planned without its request carries no trash flag at all, why the
  -- reserve raises a request rather than exempting the chest (decisions.md), and why the
  -- chests can be stopped at every pause with trash-unrequested on: the skim is real, down
  -- to the request and to nothing where there is none, and it PAUSES with the chest. Were
  -- that last half ever to change, bots would empty the loop's chests at every pause.
  test("engine: bots skim a trash-flagged chest down to its request, and leave a disabled one alone", function()
    local s, f = nauvis(), force()
    s.create_entity({ name = "electric-energy-interface", position = { 12, 4 }, force = f })
    s.create_entity({ name = "substation", position = { 8, 4 }, force = f })
    s.create_entity({ name = "roboport", position = { 14, 10 }, force = f })
      .insert({ name = "logistic-robot", count = 50 })
    local storage_chest = s.create_entity({ name = "storage-chest", position = { 6.5, 6.5 }, force = f })
    local combinator = switched_off_combinator({ 2.5, 8.5 })

    -- Sixty plates over the request, and twenty of an item never asked for.
    local function overfill(chest)
      request(chest, 1, "iron-plate", 40).trash_not_requested = true
      chest.insert({ name = "iron-plate", count = 100 })
      chest.insert({ name = "copper-plate", count = 20 })
    end
    local open = s.create_entity({ name = "requester-chest", position = { 2.5, 6.5 }, force = f })
    overfill(open)
    local shut = {}
    for i, name in ipairs({ "requester-chest", "buffer-chest" }) do
      shut[i] = s.create_entity({ name = name, position = { 2.5 + 2 * i, 10.5 }, force = f })
      gate(shut[i], combinator)
    end

    -- Overfilled only once the disabled state has settled, for the live-only window's reason.
    after_ticks(10, function()
      for _, chest in pairs(shut) do overfill(chest) end
      after_ticks(1200, function()
        assert(open.get_item_count("iron-plate") == 40,
          "the chest holds " .. open.get_item_count("iron-plate") .. " plates against a request of 40")
        assert(open.get_item_count("copper-plate") == 0,
          "the chest kept " .. open.get_item_count("copper-plate") .. " plates it never asked for")
        assert(storage_chest.get_item_count("iron-plate") == 60
          and storage_chest.get_item_count("copper-plate") == 20, "the skim did not reach storage")
        for _, chest in pairs(shut) do
          assert(chest.status == defines.entity_status.disabled_by_control_behavior,
            "the gated " .. chest.name .. " reads status " .. tostring(chest.status))
          assert(chest.get_item_count("iron-plate") == 100 and chest.get_item_count("copper-plate") == 20,
            "disabled, the " .. chest.name .. " was skimmed to " .. chest.get_item_count("iron-plate")
            .. " plates and " .. chest.get_item_count("copper-plate") .. " copper")
        end

        -- Switched on, the same two chests are skimmed like the open one: the rig could
        -- skim them all along, so the wait above proved something.
        combinator.get_control_behavior().enabled = true
        after_ticks(1500, function()
          for _, chest in pairs(shut) do
            assert(chest.get_item_count("iron-plate") == 40 and chest.get_item_count("copper-plate") == 0,
              "enabled, the " .. chest.name .. " still holds " .. chest.get_item_count("iron-plate")
              .. " plates and " .. chest.get_item_count("copper-plate") .. " copper")
          end
        end)
      end)
    end)
  end)
end)
