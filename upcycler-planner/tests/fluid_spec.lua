-- The fluid machinery on trial with real entities and real ticks, the loop_spec tradition:
-- the measured facts the geometry stands on (analysis/api.md §14), each pinned so a change in
-- engine behaviour is a release-visible event rather than a silently disconnected pipe.
--
-- Four layers: the prototype premises (the positions orbit and connection directions the
-- orientation arithmetic reads), the stub mechanism live (a player's underground pipe outside
-- the ring tapping the run through the belt), the whole pipeline -- planner, layout,
-- blueprint -- revived into real entities that must actually craft, and a modded data port
-- beside the input (the connection-category rule, at the foot of the file).

local planner = require("scripts.planner")
local research = require("tests.support.research")
local stamping = require("tests.support.stamp")

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
    -- The chain that matters: planner computes the rotation, layout places the pipes, the
    -- blueprint carries them, and the revived result must actually deliver fluid. A hand rig
    -- can only assume the computed geometry is right; this one fails if any link drifts.
    local s, f = nauvis(), force()
    local plan = planner.plan(f, {
      recipe = "battery", quality = "uncommon",
      machine = "chemical-plant", recycler = "recycler",
      pole = "medium-electric-pole",
    })
    assert(plan, "battery plan failed in test setup")
    -- The engine centres a stamped blueprint on the position it is given, so plan coordinates
    -- reach the world through the offset the stamp reports -- never assumed to be zero.
    local ghosts, ox, oy = stamping.place(plan, s, f)
    assert(#ghosts == #plan.entities, "test setup: placement incomplete")

    stamping.revive_all(s)

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
    s.create_entity({ name = "pipe-to-ground",
      position = { stub_x + 0.5 + ox, plan.height + 0.5 + oy },
      direction = defines.direction.south, force = f })
    local infinity = s.create_entity({
      name = "infinity-pipe", position = { stub_x + 0.5 + ox, plan.height + 1.5 + oy }, force = f,
    })
    infinity.set_infinity_pipe_filter({ name = "sulfuric-acid", percentage = 100 })
    powered(s, f, plan.width + 2.5 + ox, 4.5 + oy)

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

-- Muluna's data port, stood as a test-only clone of the assembling machine 3
-- (tests/fixtures/data-port-assembler.lua): a copy of the fluid input on the EAST face in
-- connection category "data", which the engine never joins to a plain pipe. The rotation rule
-- read it as a fluid input and stood the machine facing south -- lubricant port at the bottom,
-- nothing at the pipe run (portal thread 6aa5301e3f44270ff33f555a, 2026-09-12).
local DATA_PORT = "upl-test-data-port-assembler"

describe("a modded data port beside the fluid input", function()
  before_all(function() research.full(force()) end)
  after_each(wipe)

  local function normal_inputs(machine)
    local inputs = {}
    for _, box in pairs(machine.fluidbox_prototypes) do
      if box.production_type == "input" then
        for _, connection in pairs(box.pipe_connections) do
          if connection.connection_type == "normal" then inputs[#inputs + 1] = connection end
        end
      end
    end
    return inputs
  end

  test("connection categories read back as arrays, and the fixture carries the port", function()
    -- The premises the category test reads: a connection authored with no category reads
    -- back {"default"}, and the fixture's east copy reads back {"data"}.
    local pipe = prototypes.entity["pipe"].fluidbox_prototypes[1].pipe_connections[1]
    assert(type(pipe.connection_category) == "table" and #pipe.connection_category == 1
      and pipe.connection_category[1] == "default",
      "pipe category read back as " .. serpent.line(pipe.connection_category))
    local inputs = normal_inputs(prototypes.entity[DATA_PORT])
    assert(#inputs == 2, "expected the vanilla input plus one copy, got " .. #inputs)
    local category = {}
    for _, connection in pairs(inputs) do
      category[connection.direction] = connection.connection_category[1]
    end
    assert(category[defines.direction.north] == "default", "north input lost its default category")
    assert(category[defines.direction.east] == "data", "east copy is not in the data category")
  end)

  test("the rotation rule ignores a port the pipe cannot join", function()
    local orientation = planner.machine_fluid_orientation(prototypes.entity[DATA_PORT], "pipe")
    assert(orientation, "no orientation for the data-port assembler")
    assert(orientation.direction == defines.direction.west,
      "data-port assembler stood facing " .. orientation.direction .. ", expected west (12)")
    -- The vanilla machine answers the same with and without a pipe named.
    local am3 = prototypes.entity["assembling-machine-3"]
    assert(planner.machine_fluid_orientation(am3).direction == defines.direction.west)
    assert(planner.machine_fluid_orientation(am3, "pipe").direction == defines.direction.west)
  end)

  test("a plain pipe at the data port carries nothing; at the real input it fills the machine", function()
    -- The engine fact the fix rests on, measured with the reporter's geometry: a pipe run on
    -- the west face. Facing south -- the old answer -- puts the data copy against the run and
    -- the lubricant input at the bottom; facing west puts the real input against it.
    local s, f = nauvis(), force()
    local function rig(x0, direction)
      local infinity = s.create_entity({ name = "infinity-pipe", position = { x0 + 0.5, 0.5 }, force = f })
      infinity.set_infinity_pipe_filter({ name = "lubricant", percentage = 100 })
      for y = 1, 5 do
        s.create_entity({ name = "pipe", position = { x0 + 0.5, y + 0.5 }, force = f })
      end
      -- The recipe rides on create_entity: a machine whose fluid boxes only exist under a
      -- fluid recipe has nothing to rotate when created bare, and reads back facing north
      -- whatever direction was asked for (measured 2.1.17). Blueprints set both at once.
      local machine = s.create_entity({ name = DATA_PORT, position = { x0 + 2.5, 3.5 },
        direction = direction, recipe = "electric-engine-unit", force = f })
      assert(machine.direction == direction, "rig " .. x0 .. " stood facing " .. machine.direction)
      return machine
    end
    local south = rig(0, defines.direction.south)
    local west = rig(10, defines.direction.west)
    after_ticks(120, function()
      assert(south.get_fluid_count("lubricant") == 0,
        "a plain pipe joined the data port: the category rule is not what keeps them apart")
      assert(west.get_fluid_count("lubricant") > 0,
        "no lubricant reached the west-facing data-port assembler through its real input")
    end)
  end)
end)
