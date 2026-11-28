-- row.lua as pure geometry: real cells from cell.build, stood side by side. The vanilla
-- numbers stand in as in cell_spec: AM3 3x3, EM plant 4x4, the 3x3 beacon at supply 3 and
-- margin 0.3.

local cell = require("scripts.cell")
local row = require("scripts.row")

local NORTH = defines.direction.north

local function machine(w, h)
  return { name = "m", quality = "normal", w = w, h = h or w, margin = 0.3, direction = NORTH,
    recipe = "r", recipe_quality = "normal" }
end

local function beacon(side, above, supply)
  return { name = "b", quality = "normal", w = 3, h = 3, margin = 0.3, supply = supply or 3,
    side = side, above = above }
end

local SLOTS = {
  { role = "input", inserter = { name = "i" }, chest = { name = "req" } },
  { role = "output", inserter = { name = "i" }, chest = { name = "out" } },
}

-- One row entry: the built cell, its beacon params and its fluid.
local function entry(opts)
  local params = { machine = machine(opts.w or 3, opts.h), slots = SLOTS, beacon = opts.beacon,
    pipe = opts.fluid and "pipe" or nil }
  return { built = cell.build(params), beacon = opts.beacon, fluid = opts.fluid }
end

local function xs(placed)
  local out = {}
  for i, o in ipairs(placed.offsets) do out[i] = o.x end
  return table.concat(out, ",")
end

describe("row.place", function()
  test("plain cells abut, left to right", function()
    local placed = row.place({ entry({}), entry({}), entry({}) })
    assert(xs(placed) == "0,3,6", "offsets " .. xs(placed))
    assert(placed.width == 9 and placed.height == 5, "footprint " .. placed.width .. "x" .. placed.height)
    assert(not placed.shared, "nothing to share")
  end)

  test("cells are bottom-aligned, so the chest rows make one line", function()
    local placed = row.place({ entry({}), entry({ w = 4 }) })
    assert(placed.height == 6, "the EM plant cell is the tallest, 6, got " .. placed.height)
    assert(placed.offsets[1].y == 1 and placed.offsets[2].y == 0,
      "y offsets " .. placed.offsets[1].y .. "," .. placed.offsets[2].y)
  end)

  test("a pipe row keeps a free tile from its neighbour", function()
    local placed = row.place({ entry({ fluid = "water" }), entry({}) })
    assert(xs(placed) == "0,4", "offsets " .. xs(placed))
    placed = row.place({ entry({}), entry({ fluid = "water" }) })
    assert(xs(placed) == "0,4", "offsets " .. xs(placed))
  end)

  test("two pipe rows of one fluid at one height join; any other pair stands apart", function()
    local placed = row.place({ entry({ fluid = "water" }), entry({ fluid = "water" }) })
    assert(xs(placed) == "0,3", "the same fluid at the same height should join, offsets " .. xs(placed))
    placed = row.place({ entry({ fluid = "water" }), entry({ fluid = "lubricant" }) })
    assert(xs(placed) == "0,4", "two fluids should never touch, offsets " .. xs(placed))
    placed = row.place({ entry({ fluid = "water" }), entry({ fluid = "water", w = 4 }) })
    assert(xs(placed) == "0,4", "the same fluid at two heights cannot join, offsets " .. xs(placed))
  end)

  test("cells with side beacons abut: no beacon reaches the next machine", function()
    local placed = row.place({ entry({ beacon = beacon(1, 1) }), entry({ beacon = beacon(1, 1) }) })
    assert(xs(placed) == "0,9", "offsets " .. xs(placed))
    assert(not placed.shared, "no beacon should reach across")
  end)

  test("above-only cells stand three apart, either way round", function()
    local placed = row.place({ entry({ beacon = beacon(0, 1) }), entry({ beacon = beacon(0, 1) }) })
    assert(xs(placed) == "0,6", "offsets " .. xs(placed))
    placed = row.place({ entry({}), entry({ beacon = beacon(0, 1) }) })
    assert(xs(placed) == "0,6", "the later cell's beacon reaches back too, offsets " .. xs(placed))
    placed = row.place({ entry({ beacon = beacon(0, 1) }), entry({}) })
    assert(xs(placed) == "0,6", "offsets " .. xs(placed))
  end)

  test("a longer reach takes a wider gap", function()
    -- Supply 5: the beacon's area ends 7.7 tiles from the row's left edge.
    local placed = row.place({ entry({ beacon = beacon(0, 1, 5) }), entry({}) })
    assert(xs(placed) == "0,8", "offsets " .. xs(placed))
  end)

  test("a beacon reaching further than the cap abuts and says so", function()
    local placed = row.place({ entry({ beacon = beacon(0, 1, 12) }), entry({}) })
    assert(xs(placed) == "0,3", "past the cap the cells should abut, offsets " .. xs(placed))
    assert(placed.shared, "the overlap should be reported")
  end)
end)
