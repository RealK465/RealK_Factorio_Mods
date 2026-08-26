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
local research = require("tests.support.research")

local UNCOMMON_PLATE = { name = "iron-plate", quality = "uncommon" }

local function force()
  return game.forces.player
end

local function nauvis()
  return game.surfaces["nauvis"]
end

local function wipe()
  for _, entity in pairs(nauvis().find_entities_filtered({})) do
    entity.destroy()
  end
end

-- One machine-recycler pair exactly as the layout stands them: tangent, eject north into the
-- machine's bottom row, powered by an energy interface through a substation. The relief
-- inserter below the recycler blacklists the tier's own ingredient, mirroring layout.lua.
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
    inserter.set_filter(1, { name = "iron-plate", quality = "normal", comparator = "=" })
    inserter.inserter_filter_mode = "blacklist"
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
      -- The rolled-up plate must end in the chest: it is not this tier's normal ingredient,
      -- so the blacklist lets it through while leaving the eject's own flow alone.
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

  -- The reserve rule live: an inserter gated "count > floor" on its source chest stops with
  -- the floor still inside. Hand size forced to one, because a multi-item grab checked at
  -- swing start could otherwise dip below the floor -- the plan does not force it, so the
  -- shipped reserve is approximate to the inserter's hand; this pins the mechanism itself.
  test("a gated inserter leaves the floor in the chest", function()
    local s, f = nauvis(), force()
    s.create_entity({ name = "electric-energy-interface", position = { 8, 2 }, force = f })
    s.create_entity({ name = "substation", position = { 5, 2 }, force = f })

    local source = s.create_entity({ name = "steel-chest", position = { 0.5, 2.5 }, force = f })
    local sink = s.create_entity({ name = "steel-chest", position = { 0.5, 0.5 }, force = f })
    -- Direction is the PICKUP side: south is the source chest, the drop lands north in the
    -- sink -- the tap and relief rigs above follow the same rule.
    local hand = s.create_entity({
      name = "fast-inserter", position = { 0.5, 1.5 },
      direction = defines.direction.south, force = f,
    })
    hand.inserter_stack_size_override = 1

    source.get_inventory(defines.inventory.chest)
      .insert({ name = "iron-gear-wheel", count = 8, quality = "normal" })
    hand.get_wire_connector(defines.wire_connector_id.circuit_green, true)
      .connect_to(source.get_wire_connector(defines.wire_connector_id.circuit_green, true))
    local cb = hand.get_or_create_control_behavior()
    cb.circuit_enable_disable = true
    cb.circuit_condition = {
      comparator = ">", constant = 5,
      first_signal = { type = "item", name = "iron-gear-wheel", quality = "normal" },
    }

    after_ticks(300, function()
      local kept = source.get_item_count({ name = "iron-gear-wheel", quality = "normal" })
      local moved = sink.get_item_count({ name = "iron-gear-wheel", quality = "normal" })
      assert(kept == 5, "the reserve held " .. kept .. " gears, expected the floor of 5")
      assert(moved == 3, "the inserter moved " .. moved .. " gears, expected the 3 surplus")
    end)
  end)
end)
