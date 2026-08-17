-- layout.build as pure geometry: hand-built params, no prototypes, no force. Runs identically
-- inside the game and on a host interpreter (the factorio-testing skill's pure runner), which
-- is the point -- the only game global this module touches is defines.direction.
--
-- The canonical numbers come from the layout formula (analysis/layout-belt-ring.md) and match
-- what every historical harness measured: vanilla 3 tiers is 11 wide, the 4-wide salvager
-- shape is 13.

local layout = require("scripts.layout")

local params_with = require("tests.support.layout_params").vanilla

local function by_name(built, name)
  local out = {}
  for _, e in pairs(built.entities) do
    if e.name == name then out[#out + 1] = e end
  end
  return out
end

-- The two generic invariants every historical harness ran on every plan shape.
local function assert_no_overlap_and_in_bounds(built)
  local occ = {}
  for _, e in pairs(built.entities) do
    assert(e.dx >= 0 and e.dy >= 0 and e.dx + e.w <= built.width and e.dy + e.h <= built.height,
      e.name .. " out of bounds at " .. e.dx .. "," .. e.dy)
    for x = e.dx, e.dx + e.w - 1 do
      for y = e.dy, e.dy + e.h - 1 do
        local key = x .. "," .. y
        assert(not occ[key], "tile " .. key .. " holds both " .. tostring(occ[key]) .. " and " .. e.name)
        occ[key] = e.name
      end
    end
  end
  return occ
end

describe("layout.build dimensions", function()
  test("vanilla three tiers: 11 wide, one machine per tier, a recycler for all but the last", function()
    local built = layout.build(params_with())
    assert(built.width == 11, "width " .. built.width .. ", expected 11")
    assert(built.height == 15, "height " .. built.height .. ", expected 15")
    assert(built.machines == 3, "machines " .. built.machines)
    assert(built.recyclers == 2, "recyclers " .. built.recyclers)
    assert(#by_name(built, "assembling-machine-2") == 3, "machine entity count")
    assert(#by_name(built, "recycler") == 2, "recycler entity count")
  end)

  test("a recycler wider than its machine widens the pitch: the salvager shape is 13", function()
    -- Age of Production's 4x4 salvager, ejecting east as authored, stood facing west by the
    -- planner. The column pitch follows the wider of the pair; the terminal column has no
    -- recycler and stays machine-wide: 2 + 2*4 + 3.
    local built = layout.build(params_with({
      recycler = {
        name = "aop-salvager", quality = "normal", width = 4, height = 4, module_slots = 2,
        direction = defines.direction.west,
      },
    }))
    assert(built.width == 13, "width " .. built.width .. ", expected 13")
    assert_no_overlap_and_in_bounds(built)
  end)

  test("column_gap opens a utility column before every tier, and reports them", function()
    -- One column per tier, the first included -- machines take their fluid on the west side,
    -- so the leftmost machine needs a column too: 2 + 3*2 + 2*3 + 3.
    local built = layout.build(params_with({ column_gap = 2 }))
    assert(built.width == 17, "width " .. built.width .. ", expected 2 + 3*2 + 2*3 + 3 = 17")
    assert(built.utility_columns and #built.utility_columns == 3,
      "utility columns " .. tostring(built.utility_columns and #built.utility_columns))
    for _, col in pairs(built.utility_columns) do
      assert(col.width == 2, "utility column width " .. col.width)
    end
    assert_no_overlap_and_in_bounds(built)
  end)

  test("no gap means no utility columns and the original width", function()
    local built = layout.build(params_with())
    assert(built.utility_columns == nil, "utility columns reported for a gapless plan")
  end)
end)

describe("layout.build fluid plans", function()
  local function fluid_params(overrides)
    local params = params_with(overrides)
    params.column_gap = 2
    params.fluid = { pipe = "pipe", pipe_to_ground = "pipe-to-ground" }
    -- The planner rotates a fluid machine so an input connection faces the pipe run; the
    -- vanilla assembler comes out facing west.
    params.machine = {
      name = "assembling-machine-2", quality = "normal", width = 3, height = 3,
      module_slots = 2, direction = defines.direction.west,
    }
    return params
  end

  test("nothing leaves the ring: fluid adds no rows, and the box stays the ring rectangle", function()
    local built = layout.build(fluid_params())
    assert(built.width == 17, "width " .. built.width .. ", expected 17")
    assert(built.height == 15, "height " .. built.height .. ", expected the ring's own 15")
    -- The bounds half of the invariant is the "nothing outside the loop" rule: with the box
    -- equal to the ring rectangle, an entity beyond it fails here.
    assert_no_overlap_and_in_bounds(built)
  end)

  test("a full-height run per column, ending in outward underground stubs on both sides", function()
    local built = layout.build(fluid_params())
    local stubs, run_tiles = 0, {}
    for _, e in pairs(built.entities) do
      if e.name == "pipe-to-ground" then
        stubs = stubs + 1
        -- Surface openings face INTO the run; the undergrounds reach outward beneath the
        -- ring belts, which is what the player's own pipe-to-ground taps from outside.
        if e.dy == 1 then
          assert(e.direction == defines.direction.south, "north stub faces " .. e.direction)
        else
          assert(e.dy == 13, "stub at row " .. e.dy .. ", expected 1 or 13")
          assert(e.direction == defines.direction.north, "south stub faces " .. e.direction)
        end
      end
      if e.name == "pipe" then run_tiles[e.dx] = (run_tiles[e.dx] or 0) + 1 end
    end
    assert(stubs == 6, "stub count " .. stubs .. ", expected a pair per tier")
    -- The run fills rows 2..12 between the stubs, in the column just west of each machine
    -- (machines start at 3, 8, 13 with gap 2).
    for _, machine_col in pairs({ 3, 8, 13 }) do
      assert(run_tiles[machine_col - 1] == 11,
        "run beside machine at " .. machine_col .. " has " .. tostring(run_tiles[machine_col - 1]))
    end
  end)

  test("machines carry the planner's rotation; the ring and tangency survive the shift", function()
    local built = layout.build(fluid_params())
    local machines = {}
    for _, e in pairs(built.entities) do
      if e.name == "assembling-machine-2" then
        machines[#machines + 1] = e
        assert(e.direction == defines.direction.west, "machine faces " .. tostring(e.direction))
      end
    end
    assert(#machines == 3, "machine count " .. #machines)
    for _, e in pairs(built.entities) do
      if e.name == "recycler" then
        local tangent = false
        for _, m in pairs(machines) do
          if m.dx == e.dx and m.dy + m.h == e.dy then tangent = true end
        end
        assert(tangent, "recycler at " .. e.dx .. "," .. e.dy .. " lost tangency under the shift")
      end
    end
  end)
end)

describe("layout.build invariants", function()
  test("no two entities share a tile, nothing leaves the plan", function()
    assert_no_overlap_and_in_bounds(layout.build(params_with()))
  end)

  test("the ring is closed: a belt on every edge tile", function()
    local built = layout.build(params_with())
    local belts = {}
    for _, e in pairs(by_name(built, "transport-belt")) do
      belts[e.dx .. "," .. e.dy] = true
    end
    for x = 0, built.width - 1 do
      assert(belts[x .. ",0"], "top ring missing belt at " .. x)
      assert(belts[x .. "," .. (built.height - 1)], "bottom ring missing belt at " .. x)
    end
    for y = 0, built.height - 1 do
      assert(belts["0," .. y], "left ring missing belt at " .. y)
      assert(belts[(built.width - 1) .. "," .. y], "right ring missing belt at " .. y)
    end
  end)

  test("every recycler stands tangent under its machine", function()
    -- The whole loop hangs off this: the eject vector delivers into the machine only with no
    -- gap between the footprints (mod CLAUDE.md fact 3). Tidying that inserts a row here is
    -- the regression this exists to catch.
    local built = layout.build(params_with())
    local machines = by_name(built, "assembling-machine-2")
    for _, r in pairs(by_name(built, "recycler")) do
      local tangent = false
      for _, m in pairs(machines) do
        if m.dx == r.dx and m.dy + m.h == r.dy then tangent = true end
      end
      assert(tangent, "recycler at " .. r.dx .. "," .. r.dy .. " not tangent under a machine")
    end
  end)
end)

describe("layout.build per-tier wiring", function()
  test("machines are pinned: own quality, recipe at the tier's quality", function()
    local built = layout.build(params_with({ machine = {
      name = "assembling-machine-2", quality = "uncommon", width = 3, height = 3, module_slots = 2,
    } }))
    local machines = by_name(built, "assembling-machine-2")
    local seen = {}
    for _, m in pairs(machines) do
      assert(m.quality == "uncommon", "machine built at " .. tostring(m.quality))
      assert(m.recipe == "iron-gear-wheel", "machine recipe " .. tostring(m.recipe))
      seen[m.recipe_quality] = true
    end
    for _, tier in pairs({ "normal", "uncommon", "rare" }) do
      assert(seen[tier], "no machine pinned to " .. tier)
    end
  end)

  test("the terminal machine is left empty when productivity is refused", function()
    -- The wooden-chest regression: `is_terminal and terminal or quality` silently falls
    -- through to the quality module on exactly the nil that means "leave it empty".
    local built = layout.build(params_with({
      modules = { quality_module = { name = "quality-module", quality = "normal" } },
    }))
    local with_module, without = 0, 0
    for _, m in pairs(by_name(built, "assembling-machine-2")) do
      if m.modules.name then with_module = with_module + 1 else without = without + 1 end
    end
    assert(without == 1, "expected exactly the terminal machine empty, got " .. without)
    assert(with_module == 2, "lower tiers lost their quality modules")
    for _, r in pairs(by_name(built, "recycler")) do
      assert(r.modules.name == "quality-module", "recycler lost its quality module")
    end
  end)

  test("each non-terminal tier carries the blacklist relief inserter for its own ingredients", function()
    local built = layout.build(params_with())
    local blacklists = {}
    for _, e in pairs(by_name(built, "fast-inserter")) do
      if e.filter_mode == "blacklist" then blacklists[#blacklists + 1] = e end
    end
    assert(#blacklists == 2, "expected one blacklist inserter per non-terminal tier, got " .. #blacklists)
    local tiers_seen = {}
    for _, e in pairs(blacklists) do
      assert(#e.filters == 1, "blacklist filter count " .. #e.filters)
      assert(e.filters[1].name == "iron-plate", "blacklist filters the wrong item")
      tiers_seen[e.filters[1].quality] = true
    end
    assert(tiers_seen["normal"] and tiers_seen["uncommon"], "blacklists not one per lower tier")
  end)

  test("the terminal catcher whitelists the product at target quality and every one above", function()
    local built = layout.build(params_with())
    local catcher
    for _, e in pairs(by_name(built, "fast-inserter")) do
      if e.filter_mode == "whitelist" and e.filters and e.filters[1]
        and e.filters[1].name == "iron-gear-wheel" and e.dy == 1 then
        catcher = e
      end
    end
    assert(catcher, "terminal catcher inserter not found")
    assert(#catcher.filters == 3, "catcher filter count " .. #catcher.filters)
    assert(catcher.filters[1].quality == "rare", "first filter is the target")
    assert(catcher.filters[2].quality == "epic", "then the tier above")
    assert(catcher.filters[3].quality == "legendary", "then the top")
  end)

  test("feed chests request this tier's ingredients, buffers request the product", function()
    local built = layout.build(params_with())
    local feed = by_name(built, "requester-chest")
    -- 3 feed chests (one per tier) + 2 product buffers (non-terminal tiers).
    assert(#feed == 5, "requester chest count " .. #feed)
    local ingredient_requests, product_requests = 0, 0
    for _, c in pairs(feed) do
      assert(c.requests and #c.requests == 1, "chest with unexpected request shape")
      local r = c.requests[1]
      if r.name == "iron-plate" then
        assert(r.count == 100, "ingredient request count " .. r.count)
        ingredient_requests = ingredient_requests + 1
      elseif r.name == "iron-gear-wheel" then
        assert(r.count == 50, "product buffer count " .. r.count)
        product_requests = product_requests + 1
      end
    end
    assert(ingredient_requests == 3, "feed requests " .. ingredient_requests)
    assert(product_requests == 2, "buffer requests " .. product_requests)
    assert(#by_name(built, "passive-provider-chest") == 1, "exactly one output chest")
  end)
end)
