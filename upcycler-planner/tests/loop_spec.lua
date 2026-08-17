-- The standing caution, put on trial: what the recycler's eject actually does when the
-- machine above refuses a rolled-up ingredient (analysis/api.md S9.6 -- assumed from
-- mining-drill behaviour, never proven). Real revived entities, real power, real ticks.
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
