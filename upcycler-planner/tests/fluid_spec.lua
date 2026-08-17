-- The fluid machinery on trial with real entities and real ticks, the loop_spec tradition:
-- the measured facts the geometry stands on (analysis/api.md §14), each pinned so a change in
-- engine behaviour is a release-visible event rather than a silently disconnected pipe.
--
-- Three layers: the prototype premises (the positions orbit and connection directions the
-- orientation arithmetic reads), the stub mechanism live (a player's underground pipe outside
-- the ring tapping the run through the belt), and the whole pipeline -- planner, layout,
-- builder -- revived into real entities that must actually craft.

local planner = require("scripts.planner")
local builder = require("scripts.builder")
local research = require("tests.support.research")

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

local function powered(s, f, x, y)
  s.create_entity({ name = "electric-energy-interface", position = { x, y }, force = f })
  s.create_entity({ name = "substation", position = { x, y + 3 }, force = f })
end

describe("the fluid engine premises", function()
  test("positions[] is the N,E,S,W rotation orbit, and directions rotate with the entity", function()
    -- The whole orientation rule reads pipe connection DIRECTIONS and rotates them by
    -- direction arithmetic; this is the measured foundation (2026-08-17). If either half
    -- ever drifts, machine_fluid_orientation is wrong everywhere at once -- fail loudly
    -- here rather than as disconnected pipes in someone's save.
    local connection = prototypes.entity["assembling-machine-2"]
      .fluidbox_prototypes[1].pipe_connections[1]
    assert(connection.direction == defines.direction.north,
      "AM2 input authored " .. tostring(connection.direction) .. ", expected north")
    local p = connection.positions
    assert(p[1].x == 0 and p[1].y == -1, "positions[1] is not the authored north point")
    assert(p[2].x == 1 and p[2].y == 0, "positions[2] is not the east rotation")
    assert(p[3].x == 0 and p[3].y == 1, "positions[3] is not the south rotation")
    assert(p[4].x == -1 and p[4].y == 0, "positions[4] is not the west rotation")

    -- Foundry inputs are authored on the SOUTH face -- the case that breaks any "just face
    -- everything west" shortcut.
    local foundry_input = prototypes.entity["foundry"].fluidbox_prototypes[1]
    assert(foundry_input.production_type == "input", "foundry box 1 stopped being an input")
    assert(foundry_input.pipe_connections[1].direction == defines.direction.south,
      "foundry input no longer authored south -- re-derive the orientation table")
  end)
end)

describe("the fluid mechanisms live", function()
  before_all(function() research.full(force()) end)
  after_each(wipe)

  test("a player's underground tap outside the ring feeds the run and its rotated machine", function()
    -- The exact relative geometry layout.build emits, stood as real entities with the
    -- planner's own picks: the plan's north stub at the harvest row (opening south into the
    -- run, underground reaching out beneath the ring belt), and the PLAYER's side -- their
    -- own pipe-to-ground one tile outside, opening away toward an infinity pipe standing in
    -- for their supply. The two undergrounds meet beneath the belt; nothing of the plan
    -- crosses the ring.
    local s, f = nauvis(), force()
    local pipe = planner.pipe(f)
    local ptg = planner.pipe_to_ground_for(f, pipe)
    local orientation = planner.machine_fluid_orientation(prototypes.entity["chemical-plant"])
    assert(pipe and ptg and orientation, "planner picks missing at full research")

    -- The player's side, outside the ring.
    local infinity = s.create_entity({ name = "infinity-pipe", position = { 0.5, -1.5 }, force = f })
    infinity.set_infinity_pipe_filter({ name = "sulfuric-acid", percentage = 100 })
    s.create_entity({ name = "pipe-to-ground", position = { 0.5, -0.5 },
      direction = defines.direction.north, force = f })
    -- The plan's side: ring belt, then the stub and its run.
    s.create_entity({ name = "transport-belt", position = { 0.5, 0.5 }, force = f })
    s.create_entity({ name = ptg, position = { 0.5, 1.5 },
      direction = defines.direction.south, force = f })
    for y = 2, 7 do
      s.create_entity({ name = pipe, position = { 0.5, y + 0.5 }, force = f })
    end
    local plant = s.create_entity({ name = "chemical-plant", position = { 2.5, 6.5 },
      direction = orientation.direction, force = f })
    plant.set_recipe("battery", "normal")
    powered(s, f, 6.5, 1.5)
    local inv = plant.get_inventory(defines.inventory.crafter_input)
    inv.insert({ name = "iron-plate", count = 10 })
    inv.insert({ name = "copper-plate", count = 10 })

    after_ticks(600, function()
      assert(plant.products_finished > 0,
        "fluid never reached the rotated plant through the outside tap (acid in plant: "
        .. plant.get_fluid_count("sulfuric-acid") .. ")")
    end)
  end)

  test("the west run feeds an unrotated electromagnetic plant", function()
    -- The EM plant's two inputs sit on OPPOSITE flanks, so no rotation lands both -- the
    -- design leans on the measured merge rule instead: a 1-fluid recipe materialises one
    -- box exposing every input connection, and the west one alone feeds it. If this ever
    -- regresses, the planner must start refusing the EM plant rather than piping it wrong.
    local s, f = nauvis(), force()
    local infinity = s.create_entity({ name = "infinity-pipe", position = { 0.5, 0.5 }, force = f })
    infinity.set_infinity_pipe_filter({ name = "electrolyte", percentage = 100 })
    for y = 1, 8 do
      s.create_entity({ name = "pipe", position = { 0.5, y + 0.5 }, force = f })
    end
    local emp = s.create_entity({ name = "electromagnetic-plant", position = { 3, 7 }, force = f })
    emp.set_recipe("supercapacitor", "normal")
    powered(s, f, 8.5, 1.5)
    local inv = emp.get_inventory(defines.inventory.crafter_input)
    inv.insert({ name = "holmium-plate", count = 10 })
    inv.insert({ name = "superconductor", count = 10 })
    inv.insert({ name = "electronic-circuit", count = 20 })
    inv.insert({ name = "battery", count = 10 })

    after_ticks(600, function()
      assert(emp.products_finished > 0,
        "the west run stopped feeding an unrotated EM plant (electrolyte in plant: "
        .. emp.get_fluid_count("electrolyte") .. ") -- the planner must refuse it now")
    end)
  end)

  test("a placed battery plan, revived whole, crafts from an outside tap", function()
    -- The chain that matters: planner computes the rotation, layout places the pipes,
    -- builder ghosts them, and the revived result must actually deliver fluid. A hand rig
    -- can only assume the computed geometry is right; this one fails if any link drifts.
    local s, f = nauvis(), force()
    local plan = planner.plan(f, {
      recipe = "battery", quality = "uncommon",
      machine = "chemical-plant", recycler = "recycler",
      pole = "medium-electric-pole",
    })
    assert(plan, "battery plan failed in test setup")
    local placed = builder.place(plan, { x = 0, y = 0 }, { surface = s, force = f })
    assert(placed == #plan.entities, "test setup: placement incomplete")

    for _, ghost in pairs(s.find_entities_filtered({ name = "entity-ghost" })) do
      local _, revived = ghost.revive()
      assert(revived, "a ghost refused to revive on clear ground")
    end

    -- Tap tier 0's SOUTH stub from outside, the way a player would: their own underground
    -- pipe one tile beyond the bottom ring, fed by an infinity pipe. Each column is an
    -- independent network on purpose -- only the seeded tier needs fluid here. Power stands
    -- beside the loop; its substation reaches the revived poles' own wires.
    local stub_x
    for _, e in pairs(plan.entities) do
      if e.name == "pipe-to-ground" and e.dy == plan.height - 2
        and (not stub_x or e.dx < stub_x) then
        stub_x = e.dx
      end
    end
    assert(stub_x, "no south stub found in the plan")
    s.create_entity({ name = "pipe-to-ground", position = { stub_x + 0.5, plan.height + 0.5 },
      direction = defines.direction.south, force = f })
    local infinity = s.create_entity({
      name = "infinity-pipe", position = { stub_x + 0.5, plan.height + 1.5 }, force = f,
    })
    infinity.set_infinity_pipe_filter({ name = "sulfuric-acid", percentage = 100 })
    powered(s, f, plan.width + 2.5, 4.5)

    local tier_zero
    for _, plant in pairs(s.find_entities_filtered({ name = "chemical-plant" })) do
      local _, quality = plant.get_recipe()
      if quality and quality.name == "normal" then tier_zero = plant end
    end
    assert(tier_zero, "no tier-0 plant among the revived entities")
    local inv = tier_zero.get_inventory(defines.inventory.crafter_input)
    inv.insert({ name = "iron-plate", count = 10 })
    inv.insert({ name = "copper-plate", count = 10 })

    after_ticks(900, function()
      assert(tier_zero.get_fluid_count("sulfuric-acid") > 0,
        "no acid reached the tier-0 plant: the planned pipe geometry does not connect")
      assert(tier_zero.products_finished > 0,
        "the revived loop's tier-0 plant never crafted")
    end)
  end)
end)
