-- cell.lua as pure geometry: plain tables in, no game. The vanilla footprints (AM3 3x3, EM
-- plant 4x4, foundry 5x5, the 3x3 beacon at supply 3 and margin 0.3) stand in as numbers, so
-- the host interpreter runs this too.

local cell = require("scripts.cell")

local NORTH, SOUTH = defines.direction.north, defines.direction.south
local EAST, WEST = defines.direction.east, defines.direction.west

local function machine(w, h)
  return { name = "m", quality = "normal", w = w, h = h or w, margin = 0.3, direction = NORTH,
    recipe = "r", recipe_quality = "normal" }
end

local function beacon(side, above)
  return { name = "b", quality = "normal", w = 3, h = 3, margin = 0.3, supply = 3,
    side = side, above = above }
end

-- Roles in order; a leading "+" marks an extra, the second or later of its role.
local function slots(...)
  local out = {}
  for i, spec in ipairs({ ... }) do
    local extra = spec:sub(1, 1) == "+"
    local role = extra and spec:sub(2) or spec
    out[i] = { role = role, extra = extra or nil, inserter = { name = "i" },
      chest = { name = role == "input" and "req" or "out" } }
  end
  return out
end

local function at(built, name, dx, dy)
  for _, e in ipairs(built.entities) do
    if e.name == name and e.dx == dx and e.dy == dy then return e end
  end
  return nil
end

local function named(built, name)
  local out = {}
  for _, e in ipairs(built.entities) do
    if e.name == name then out[#out + 1] = e end
  end
  return out
end

local function no_overlaps_and_inside(built)
  local seen = {}
  for _, e in ipairs(built.entities) do
    assert(e.dx >= 0 and e.dy >= 0 and e.dx + e.w <= built.width and e.dy + e.h <= built.height,
      e.name .. " at " .. e.dx .. "," .. e.dy .. " leaves the " .. built.width .. "x" .. built.height .. " footprint")
    for x = e.dx, e.dx + e.w - 1 do
      for y = e.dy, e.dy + e.h - 1 do
        local key = x .. "," .. y
        assert(not seen[key], e.name .. " overlaps " .. tostring(seen[key]) .. " at " .. key)
        seen[key] = e.name
      end
    end
  end
end

describe("cell.build", function()
  test("a plain cell: the machine on top, its slots under it", function()
    local built = cell.build({ machine = machine(3), slots = slots("input", "output", "quality") })
    assert(built.width == 3 and built.height == 5, "footprint " .. built.width .. "x" .. built.height)
    local m = named(built, "m")[1]
    assert(m.dx == 0 and m.dy == 0, "machine not at the corner")
    local inserters = named(built, "i")
    assert(#inserters == 3, "expected three inserters")
    for c, ins in ipairs(inserters) do
      assert(ins.dx == c - 1 and ins.dy == 3, "inserter " .. c .. " misplaced")
    end
    assert(inserters[1].direction == SOUTH, "the input must pick from its chest")
    assert(inserters[2].direction == NORTH and inserters[3].direction == NORTH,
      "the outputs must pick from the machine")
    assert(#named(built, "req") == 1 and #named(built, "out") == 2, "chest roles wrong")
    assert(named(built, "req")[1].dy == 4, "chests are not in the row under the inserters")
    no_overlaps_and_inside(built)
  end)

  test("an unsplit cell has two slots, a fluid-only recipe one", function()
    local two = cell.build({ machine = machine(3), slots = slots("input", "output") })
    assert(#named(two, "i") == 2, "expected two inserters")
    local one = cell.build({ machine = machine(3), slots = slots("output") })
    assert(#named(one, "i") == 1 and #named(one, "req") == 0, "a fluid-only recipe needs no requester")
  end)

  test("a fluid recipe puts a full-width pipe row behind the machine", function()
    local built = cell.build({ machine = machine(3), slots = slots("input", "output"), pipe = "p" })
    assert(built.height == 6, "height " .. built.height)
    local pipes = named(built, "p")
    assert(#pipes == built.width, "the pipe row does not span the cell")
    for _, pipe in ipairs(pipes) do assert(pipe.dy == 0, "a pipe left the back row") end
    assert(named(built, "m")[1].dy == 1, "the machine does not stand right behind the pipe row")
    no_overlaps_and_inside(built)
  end)
end)

describe("cell.capacity", function()
  test("vanilla beacons around the three common footprints", function()
    local am3 = cell.capacity(machine(3), beacon(), false)
    assert(am3.side == 1 and am3.above_sided == 3 and am3.above_alone == 1,
      "AM3: " .. am3.side .. "/" .. am3.above_sided .. "/" .. am3.above_alone)
    local emp = cell.capacity(machine(4), beacon(), false)
    assert(emp.side == 2 and emp.above_sided == 3 and emp.above_alone == 1,
      "EM plant: " .. emp.side .. "/" .. emp.above_sided .. "/" .. emp.above_alone)
    local foundry = cell.capacity(machine(5), beacon(), true)
    assert(foundry.side == 2 and foundry.above_sided == 3 and foundry.above_alone == 1,
      "foundry: " .. foundry.side .. "/" .. foundry.above_sided .. "/" .. foundry.above_alone)
  end)

  test("a beacon that cannot reach the machine is never offered", function()
    local weak = beacon()
    weak.supply = 0
    local capacity = cell.capacity(machine(3), weak, false)
    assert(capacity.side == 0 and capacity.above_sided == 0 and capacity.above_alone == 0,
      "a zero-supply beacon was offered a position")
  end)
end)

describe("cell.build with beacons", function()
  test("sides and above around an AM3 with a pipe row", function()
    local built = cell.build({ machine = machine(3), slots = slots("input", "output", "quality"),
      pipe = "p", beacon = beacon(1, 3) })
    assert(built.width == 9 and built.height == 9, "footprint " .. built.width .. "x" .. built.height)
    local m = named(built, "m")[1]
    assert(m.dx == 3 and m.dy == 4, "machine at " .. m.dx .. "," .. m.dy)
    local beacons = named(built, "b")
    assert(#beacons == 5, "expected 5 beacons, got " .. #beacons)
    local above = 0
    for _, b in ipairs(beacons) do
      if b.dy == 0 then above = above + 1 end
    end
    assert(above == 3, "expected three beacons above")
    for _, pipe in ipairs(named(built, "p")) do assert(pipe.dy == 3, "pipe row not between beacons and machine") end
    no_overlaps_and_inside(built)
  end)

  test("an EM plant flanked by two beacons a side, as in the owner's blueprint", function()
    local built = cell.build({ machine = machine(4), slots = slots("input", "output"), beacon = beacon(2, 0) })
    assert(built.width == 10 and built.height == 6, "footprint " .. built.width .. "x" .. built.height)
    assert(#named(built, "b") == 4, "expected four beacons")
    no_overlaps_and_inside(built)
  end)

  test("counts are clamped to what fits", function()
    local built = cell.build({ machine = machine(3), slots = slots("input", "output"), beacon = beacon(9, 9) })
    assert(#named(built, "b") == 2 + 3, "the clamp let extra beacons through")
  end)

  test("fewer beacons above stand nearest the middle", function()
    local one = cell.build({ machine = machine(3), slots = slots("output"), beacon = beacon(1, 1) })
    local top = {}
    for _, b in ipairs(named(one, "b")) do if b.dy == 0 then top[#top + 1] = b end end
    assert(#top == 1 and top[1].dx == 3, "a single beacon above should stand over the machine")
    local two = cell.build({ machine = machine(3), slots = slots("output"), beacon = beacon(1, 2) })
    local xs = {}
    for _, b in ipairs(named(two, "b")) do if b.dy == 0 then xs[#xs + 1] = b.dx end end
    table.sort(xs)
    assert(#xs == 2 and xs[1] == 0 and xs[2] == 3, "two above should be left and middle")
  end)

  test("no side beacons: the row above narrows to the machine", function()
    local built = cell.build({ machine = machine(3), slots = slots("output"), beacon = beacon(0, 3) })
    assert(built.width == 3, "the row above widened a cell with no side columns")
    assert(#named(built, "b") == 1, "only one beacon fits above a lone AM3")
  end)
end)

describe("cell extras", function()
  test("side room: a beacon that reaches from two tiles out leaves the side open", function()
    assert(cell.side_room(machine(3), beacon(1, 3)) == 3, "a vanilla side beacon closed the side")
    assert(cell.side_room(machine(3), beacon(0, 3)) == 3, "a side with no beacon is not open")
    assert(cell.side_room(machine(3), nil) == 3, "a cell with no beacon is not open")
    local short = beacon(1, 0)
    short.supply = 2
    assert(cell.side_room(machine(3), short) == 0, "a beacon out of reach two tiles out left the side open")
    assert(cell.side_room(machine(3, 2), nil) == 2, "a machine on its side has two tiles of side")
  end)

  test("extra inputs fill the bottom, then the left side", function()
    local built = cell.build({ machine = machine(3), beacon = beacon(1, 3),
      slots = slots("input", "output", "quality", "+input", "+input") })
    assert(built.width == 11 and built.height == 8, "footprint " .. built.width .. "x" .. built.height)
    local m = named(built, "m")[1]
    assert(m.dx == 5 and m.dy == 3, "machine at " .. m.dx .. "," .. m.dy)
    for k = 0, 1 do
      local ins = at(built, "i", 4, 3 + k)
      assert(ins and ins.direction == WEST, "left input " .. k .. " missing or not picking from its chest")
      assert(at(built, "req", 3, 3 + k), "left requester " .. k .. " missing")
    end
    assert(at(built, "b", 0, 3) and at(built, "b", 8, 3), "the side beacons did not step out and stay")
    for _, x in ipairs({ 2, 5, 8 }) do
      assert(at(built, "b", x, 0), "a beacon above moved off its machine-relative spot at " .. x)
    end
    local bottom = { SOUTH, NORTH, NORTH }
    for c, direction in ipairs(bottom) do
      local ins = at(built, "i", 4 + c, 6)
      assert(ins and ins.direction == direction, "bottom slot " .. c .. " wrong")
    end
    no_overlaps_and_inside(built)
  end)

  test("an extra output on the side faces the machine, mirrored on the right", function()
    local built = cell.build({ machine = machine(3),
      slots = slots("input", "output", "quality", "+output", "+output", "+output", "+output") })
    assert(built.width == 7, "width " .. built.width)
    assert(at(built, "i", 1, 0).direction == EAST, "a left output must pick from the machine")
    assert(at(built, "i", 5, 0).direction == WEST, "a right output must pick from the machine")
    assert(at(built, "out", 0, 0) and at(built, "out", 6, 0), "side output chests misplaced")
    local inputs = cell.build({ machine = machine(3),
      slots = slots("input", "output", "quality", "+input", "+input", "+input", "+input") })
    assert(at(inputs, "i", 5, 0).direction == EAST, "a right input must pick from its chest")
    no_overlaps_and_inside(built)
    no_overlaps_and_inside(inputs)
  end)

  test("overflow past the left side goes right", function()
    local built = cell.build({ machine = machine(3),
      slots = slots("input", "output", "+input", "+input", "+input", "+input", "+input") })
    assert(built.width == 7 and built.height == 5, "footprint " .. built.width .. "x" .. built.height)
    local bottom = { SOUTH, SOUTH, NORTH }
    for c, direction in ipairs(bottom) do
      assert(at(built, "i", 1 + c, 3).direction == direction, "bottom slot " .. c .. " wrong")
    end
    for k = 0, 2 do assert(at(built, "i", 1, k), "left slot " .. k .. " missing") end
    assert(at(built, "i", 5, 0) and not at(built, "i", 5, 1), "the right side should hold exactly one")
    no_overlaps_and_inside(built)
  end)

  test("a bottom row reads inputs, outputs, quality", function()
    local built = cell.build({ machine = machine(4), slots = slots("input", "output", "quality", "+input") })
    assert(built.width == 4, "an extra that fits the bottom widened the cell")
    local want = { { "req", SOUTH }, { "req", SOUTH }, { "out", NORTH }, { "out", NORTH } }
    for c, pair in ipairs(want) do
      assert(at(built, pair[1], c - 1, 5), "bottom chest " .. c .. " is not a " .. pair[1])
      assert(at(built, "i", c - 1, 4).direction == pair[2], "bottom inserter " .. c .. " faces the wrong way")
    end
  end)
end)

describe("cell footprint", function()
  test("the bounding box is the footprint, so side-by-side cells abut", function()
    local configurations = {
      { machine = machine(3), slots = slots("input", "output", "quality") },
      { machine = machine(4), slots = slots("input", "output"), pipe = "p", beacon = beacon(2, 3) },
      { machine = machine(5), slots = slots("input", "output", "quality"), pipe = "p", beacon = beacon(2, 1) },
    }
    for index, params in ipairs(configurations) do
      local built = cell.build(params)
      local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
      for _, e in ipairs(built.entities) do
        x0, y0 = math.min(x0, e.dx), math.min(y0, e.dy)
        x1, y1 = math.max(x1, e.dx + e.w), math.max(y1, e.dy + e.h)
      end
      assert(x0 == 0 and x1 == built.width, "configuration " .. index .. ": width is not the entities' span")
      assert(y0 == 0 and y1 == built.height, "configuration " .. index .. ": height is not the entities' span")
      no_overlaps_and_inside(built)
    end
  end)

  test("a pole row lowers the whole cell by its height and leaves the top open", function()
    local flat = cell.build({ machine = machine(3), slots = slots("input", "output"), pipe = "p", beacon = beacon(1, 3) })
    local tall = cell.build({ machine = machine(3), slots = slots("input", "output"), pipe = "p", beacon = beacon(1, 3),
      pole_row = 1 })
    assert(tall.height == flat.height + 1 and tall.width == flat.width, "the row did not add exactly one row")
    for i, e in ipairs(tall.entities) do
      assert(e.dy == flat.entities[i].dy + 1, e.name .. " did not move down with the row")
      assert(e.dy >= 1, e.name .. " stands in the pole row")
    end
    no_overlaps_and_inside(tall)
  end)

  test("a pole column widens the cell, and the pipe row runs through it", function()
    local built = cell.build({ machine = machine(3), slots = slots("input", "output"), pipe = "p", pole_column = 1 })
    assert(built.width == 4, "width " .. built.width)
    assert(#named(built, "p") == 4, "the pipe row does not run through the pole column")
    for _, e in ipairs(built.entities) do
      if e.name ~= "p" then assert(e.dx < 3, e.name .. " stands in the pole column") end
    end
  end)
end)
