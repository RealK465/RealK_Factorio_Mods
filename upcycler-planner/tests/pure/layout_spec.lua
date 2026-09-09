-- layout.build as pure geometry: hand-built params, no prototypes, no force. Runs identically
-- inside the game and on a host interpreter (the factorio-testing skill's pure runner), which
-- is the point -- the only game global this module touches is defines.direction.
--
-- The canonical numbers come from the layout formula (analysis/layout-belt-ring.md) and match
-- what every historical harness measured: vanilla 3 tiers is 11 wide, the 4-wide salvager
-- shape is 13.

local layout = require("scripts.layout")

local params_with = require("tests.support.layout_params").vanilla
local big_params = require("tests.support.layout_params").big
local deep_equal = require("tests.support.deep_equal")
local circuit_stack = require("tests.support.circuit_stack")

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

  test("a uniform column_gaps opens a utility column before every tier, and reports them", function()
    -- One column per tier, the first included -- machines take their fluid on the west side,
    -- so the leftmost machine needs a column too: 2 + 3*2 + 2*3 + 3.
    local built = layout.build(params_with({ column_gaps = { 2, 2, 2 } }))
    assert(built.width == 17, "width " .. built.width .. ", expected 2 + 3*2 + 2*3 + 3 = 17")
    assert(built.utility_columns and #built.utility_columns == 3,
      "utility columns " .. tostring(built.utility_columns and #built.utility_columns))
    for index, col in pairs(built.utility_columns) do
      assert(col.width == 2, "utility column width " .. col.width)
      assert(col.tier == index, "column " .. index .. " reports tier " .. tostring(col.tier))
    end
    assert_no_overlap_and_in_bounds(built)
  end)

  test("gaps are per tier: only the opened ones cost width, and each names its tier", function()
    -- The whole point of the list: a plan pays for the columns something stands in and no
    -- others. Tier 2 alone opens a 2-wide column, so 11 + 2 = 13, and the single reported
    -- column has to name tier 2 or the planner would collapse the wrong one.
    local built = layout.build(params_with({ column_gaps = { 0, 2, 0 } }))
    assert(built.width == 13, "width " .. built.width .. ", expected the gapless 11 plus 2")
    assert(built.utility_columns and #built.utility_columns == 1,
      "utility columns " .. tostring(built.utility_columns and #built.utility_columns))
    assert(built.utility_columns[1].tier == 2,
      "reported tier " .. tostring(built.utility_columns[1].tier))
    assert(built.utility_columns[1].width == 2, "width " .. built.utility_columns[1].width)
    assert_no_overlap_and_in_bounds(built)
  end)

  test("no gaps means no utility columns and the original width", function()
    local built = layout.build(params_with())
    assert(built.utility_columns == nil, "utility columns reported for a gapless plan")
    assert(built.width == 11, "width " .. built.width .. ", expected 11")
  end)
end)

describe("layout.build fluid plans", function()
  local function fluid_params(overrides)
    local params = params_with()
    params.column_gaps = { 2, 2, 2 }
    params.fluid = { pipe = "pipe", pipe_to_ground = "pipe-to-ground" }
    -- The planner rotates a fluid machine so an input connection faces the pipe run; the
    -- vanilla assembler comes out facing west.
    params.machine = {
      name = "assembling-machine-2", quality = "normal", width = 3, height = 3,
      module_slots = 2, direction = defines.direction.west,
    }
    -- Overrides last, or the fluid defaults above would silently win over a caller's own.
    for key, value in pairs(overrides or {}) do params[key] = value end
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

  test("a fluid plan cannot collapse a column: zero is clamped to one, per tier", function()
    -- The clamp lives in layout.build so no caller can take away the ground the pipe run
    -- stands on. The planner asks for zero on every tier a pole did not want, and a fluid
    -- plan still has to come back with a 1-wide column in front of each machine.
    local built = layout.build(fluid_params({ column_gaps = { 0, 0, 0 } }))
    assert(built.width == 14, "width " .. built.width .. ", expected 2 + 3*1 + 2*3 + 3 = 14")
    assert(built.utility_columns and #built.utility_columns == 3,
      "utility columns " .. tostring(built.utility_columns and #built.utility_columns))
    for _, col in pairs(built.utility_columns) do
      assert(col.width == 1, "clamped column width " .. col.width)
    end
    local pipes = 0
    for _, e in pairs(built.entities) do
      if e.name == "pipe" or e.name == "pipe-to-ground" then pipes = pipes + 1 end
    end
    assert(pipes == 3 * 11 + 6, "pipe count " .. pipes .. " -- the runs must survive the clamp")
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

  test("a split tier mixes the two modules; homogeneous tiers keep the flat shape", function()
    -- The split arrives as productivity counts per lower tier. Tier 1 mixes 1q+1p on the
    -- 2-slot machine -- the one case that becomes an ARRAY, quality first so its stacks come
    -- first -- while tier 2, with no entry, stays the flat all-quality table every existing
    -- consumer reads, and the terminal and the recyclers never consult the split at all.
    local built = layout.build(params_with({ modules = {
      quality_module = { name = "quality-module", quality = "normal" },
      productivity_module = { name = "productivity-module", quality = "rare" },
      terminal_module = { name = "productivity-module", quality = "normal" },
      split = { 1 },
    } }))
    local by_tier = {}
    for _, m in pairs(by_name(built, "assembling-machine-2")) do
      by_tier[m.recipe_quality] = m.modules
    end

    local mixed = by_tier["normal"]
    assert(mixed[1] and mixed[2] and not mixed.name, "the split tier is not an array")
    assert(mixed[1].name == "quality-module" and mixed[1].count == 1
      and mixed[1].quality == "normal", "quality half wrong: " .. mixed[1].name)
    assert(mixed[2].name == "productivity-module" and mixed[2].count == 1
      and mixed[2].quality == "rare", "productivity half wrong: " .. mixed[2].name)

    assert(by_tier["uncommon"].name == "quality-module" and by_tier["uncommon"].count == 2,
      "an unsplit lower tier lost the flat all-quality shape")
    assert(by_tier["rare"].name == "productivity-module",
      "the terminal machine must ignore the split")
    for _, r in pairs(by_name(built, "recycler")) do
      assert(r.modules.name == "quality-module" and r.modules.count == 4,
        "a recycler consulted the split")
    end
  end)

  test("a split collapses to the flat shape at its edges, and without a productivity module", function()
    -- All-productivity is still one identity, so it stays a single spec; a split with no
    -- productivity module to price is a guard case that must read all-quality, never crash.
    local all_prod = layout.build(params_with({ modules = {
      quality_module = { name = "quality-module", quality = "normal" },
      productivity_module = { name = "productivity-module", quality = "normal" },
      split = { 2, 2 },
    } }))
    for _, m in pairs(by_name(all_prod, "assembling-machine-2")) do
      if m.recipe_quality ~= "rare" then
        assert(m.modules.name == "productivity-module" and m.modules.count == 2,
          "an all-productivity tier should stay one flat spec")
      end
    end

    local guarded = layout.build(params_with({ modules = {
      quality_module = { name = "quality-module", quality = "normal" },
      split = { 1, 1 },
    } }))
    for _, m in pairs(by_name(guarded, "assembling-machine-2")) do
      if m.recipe_quality ~= "rare" then
        assert(m.modules.name == "quality-module" and m.modules.count == 2,
          "a split with no productivity module must read all-quality")
      end
    end
  end)

  test("each non-terminal tier carries the relief inserter: one nameless filter, above its own tier", function()
    -- The extract inserter under the recycler names no item at all: "anything above this
    -- tier" is exactly what the eject cannot deliver, at one slot whatever the recipe. It
    -- faces north, off the recycler -- the overflow tap carries the same filter shape and
    -- faces south, onto the ring, which is what tells the two apart.
    local built = layout.build(params_with())
    local reliefs = {}
    for _, e in pairs(by_name(built, "fast-inserter")) do
      if e.filters and e.filters[1] and not e.filters[1].name
        and e.direction == defines.direction.north then
        reliefs[#reliefs + 1] = e
      end
    end
    assert(#reliefs == 2, "expected one relief inserter per non-terminal tier, got " .. #reliefs)
    local tiers_seen = {}
    for _, e in pairs(reliefs) do
      assert(#e.filters == 1, "relief filter count " .. #e.filters)
      assert(e.filter_mode == "whitelist", "relief filter mode " .. tostring(e.filter_mode))
      assert(e.filters[1].comparator == ">", "the relief must take strictly above its tier")
      tiers_seen[e.filters[1].quality] = true
    end
    assert(tiers_seen["normal"] and tiers_seen["uncommon"], "reliefs not one per lower tier")
    assert(not tiers_seen["rare"], "the terminal tier has no recycler and needs no relief")
  end)

  test("the terminal catcher takes the product at target quality and above, in one filter", function()
    -- One comparator, not one filter per tier above the target. The old list was clamped to the
    -- inserter's five slots, so a modded quality chain quietly lost its top tiers; ">=" cannot
    -- be outrun by a longer chain.
    local built = layout.build(params_with())
    local catcher
    for _, e in pairs(by_name(built, "fast-inserter")) do
      if e.filter_mode == "whitelist" and e.filters and e.filters[1]
        and e.filters[1].name == "iron-gear-wheel" and e.dy == 1 then
        catcher = e
      end
    end
    assert(catcher, "terminal catcher inserter not found")
    assert(#catcher.filters == 1, "catcher filter count " .. #catcher.filters)
    assert(catcher.filters[1].quality == "rare", "the filter names the target")
    assert(catcher.filters[1].comparator == ">=", "the target and every tier above it")
  end)

  test("the overflow tap drains anything above the target into the active provider", function()
    -- The terminal column has no recycler, so its extract stack's two tiles are free: the tap
    -- is the unload inserter reversed, and the chest sits where the extract chest would.
    local built = layout.build(params_with())
    -- Nameless AND facing the ring: the relief inserters carry the same nameless shape, off
    -- the recyclers, facing north.
    local tap
    for _, e in pairs(by_name(built, "fast-inserter")) do
      if e.filters and e.filters[1] and not e.filters[1].name
        and e.direction == defines.direction.south then
        assert(not tap, "two inserters read as the overflow tap")
        tap = e
      end
    end
    assert(tap, "overflow tap inserter not found")
    assert(#tap.filters == 1, "tap filter count " .. #tap.filters)
    assert(tap.filters[1].quality == "rare" and tap.filters[1].comparator == ">",
      "the tap takes strictly above the target, so the terminal machine keeps its own tier")
    assert(tap.filter_mode == "whitelist", "tap filter mode " .. tostring(tap.filter_mode))
    assert(tap.direction == defines.direction.south, "the tap must face the bottom ring")

    local chests = by_name(built, "active-provider-chest")
    assert(#chests == 1, "active provider count " .. #chests)
    -- Directly above the tap, and both in the terminal column's feed sub-column.
    assert(chests[1].dx == tap.dx, "chest and tap are not in the same sub-column")
    assert(chests[1].dy == tap.dy - 1, "the tap does not drop into the overflow chest")
  end)

  test("a top-tier target builds no tap at all", function()
    -- Nothing can roll past the top of the chain, so there is nothing to catch and the two
    -- entities would be dead weight.
    local built = layout.build(params_with({
      tiers = { "normal", "uncommon", "rare", "epic", "legendary" }, overflow_tap = false,
    }))
    assert(#by_name(built, "active-provider-chest") == 0, "a legendary plan built an overflow chest")
    for _, e in pairs(by_name(built, "fast-inserter")) do
      assert(not (e.filters and e.filters[1] and not e.filters[1].name
        and e.direction == defines.direction.south), "a legendary plan built the overflow tap")
    end
  end)

  test("feed chests request this tier's ingredients, stock chests request the product", function()
    local built = layout.build(params_with())
    -- 3 feed chests (one per tier, params.requester) and 2 stock chests (non-terminal
    -- tiers, params.stock) -- distinct params since the stock kind became the player's
    -- checkbox, so a wrong-param regression shows as a wrong name here.
    local feed = by_name(built, "requester-chest")
    assert(#feed == 3, "feed chest count " .. #feed)
    for _, c in pairs(feed) do
      assert(c.requests and #c.requests == 1, "feed chest with unexpected request shape")
      assert(c.requests[1].name == "iron-plate", "feed chest requests " .. c.requests[1].name)
      assert(c.requests[1].count == 100, "ingredient request count " .. c.requests[1].count)
    end
    local stock = by_name(built, "buffer-chest")
    assert(#stock == 2, "stock chest count " .. #stock)
    for _, c in pairs(stock) do
      assert(c.requests and #c.requests == 1, "stock chest with unexpected request shape")
      assert(c.requests[1].name == "iron-gear-wheel", "stock chest requests " .. c.requests[1].name)
      assert(c.requests[1].count == 50, "product request count " .. c.requests[1].count)
    end
    assert(#by_name(built, "passive-provider-chest") == 1, "exactly one output chest")
  end)
end)

describe("layout.build ring circulation", function()
  -- The presence test above proves the ring is closed; this proves it MOVES. A belt facing
  -- the wrong way is invisible to every counting assertion and stalls the loop in game, so
  -- the full circulation -- edges carry, corners turn -- is pinned tile by tile.
  test("every ring belt carries the flow around: edges carry, corners turn", function()
    local built = layout.build(params_with())
    local w, h = built.width, built.height
    local dir = {}
    for _, e in pairs(by_name(built, "transport-belt")) do
      dir[e.dx .. "," .. e.dy] = e.direction
    end
    -- Corners face where the items go next.
    assert(dir["0,0"] == defines.direction.south, "north-west corner must turn south")
    assert(dir[(w - 1) .. ",0"] == defines.direction.west, "north-east corner must turn west")
    assert(dir["0," .. (h - 1)] == defines.direction.east, "south-west corner must turn east")
    assert(dir[(w - 1) .. "," .. (h - 1)] == defines.direction.north,
      "south-east corner must turn north")
    for x = 1, w - 2 do
      assert(dir[x .. ",0"] == defines.direction.west, "top ring at " .. x .. " must flow west")
      assert(dir[x .. "," .. (h - 1)] == defines.direction.east,
        "bottom ring at " .. x .. " must flow east")
    end
    for y = 1, h - 2 do
      assert(dir["0," .. y] == defines.direction.south, "left ring at " .. y .. " must flow south")
      assert(dir[(w - 1) .. "," .. y] == defines.direction.north,
        "right ring at " .. y .. " must flow north")
    end
  end)
end)

describe("layout.build across footprints and recipes", function()
  test("a two-ingredient recipe filters and requests both, per tier", function()
    local built = layout.build(params_with({
      recipe = {
        name = "electronic-circuit", product = "electronic-circuit",
        ingredients = {
          { name = "iron-plate", amount = 1, type = "item" },
          { name = "copper-cable", amount = 3, type = "item" },
        },
      },
      requests = { ["iron-plate"] = 100, ["copper-cable"] = 200 },
    }))
    -- The harvest inserters carry one slot per ingredient, all at their own tier's quality;
    -- the relief inserters never name an ingredient, so they stay at one slot.
    local harvests, reliefs = 0, 0
    for _, e in pairs(by_name(built, "fast-inserter")) do
      if e.filters and e.filters[1] and e.filters[1].name == "iron-plate" then
        assert(#e.filters == 2, "ingredient filter count " .. #e.filters)
        assert(e.filters[2].name == "copper-cable", "second ingredient missing from the filters")
        assert(e.filters[1].quality == e.filters[2].quality,
          "one inserter carries two different tiers")
        assert(e.filter_mode == "whitelist", "a harvest inserter must whitelist")
        harvests = harvests + 1
      elseif e.filters and e.filters[1] and not e.filters[1].name
        and e.direction == defines.direction.north then
        assert(#e.filters == 1, "relief filter count " .. #e.filters)
        reliefs = reliefs + 1
      end
    end
    assert(harvests == 3, "harvest inserters " .. harvests .. ", expected one per tier")
    assert(reliefs == 2, "relief inserters " .. reliefs .. ", expected one per lower tier")

    local feeds = 0
    for _, e in pairs(by_name(built, "requester-chest")) do
      if e.requests and #e.requests == 2 then
        feeds = feeds + 1
        local count_of = {}
        for _, r in pairs(e.requests) do count_of[r.name] = r.count end
        assert(count_of["iron-plate"] == 100 and count_of["copper-cable"] == 200,
          "feed chest requests carry the wrong counts")
      end
    end
    assert(feeds == 3, "feed chests requesting both ingredients " .. feeds)
    assert_no_overlap_and_in_bounds(built)
  end)

  test("a taller machine pushes the whole lower block down, tangency intact", function()
    -- Height rides the row arithmetic: 4 rows above, machine 4, recycler 4, 4 below = 16.
    local built = layout.build(params_with({
      machine = { name = "tall-machine", quality = "normal", width = 3, height = 4, module_slots = 2 },
    }))
    assert(built.width == 11, "width " .. built.width .. ", expected the vanilla 11")
    assert(built.height == 16, "height " .. built.height .. ", expected 16")
    for _, r in pairs(by_name(built, "recycler")) do
      assert(r.dy == 8, "recycler at row " .. r.dy .. " -- no longer tangent under a 4-tall machine")
    end
    assert_no_overlap_and_in_bounds(built)
  end)

  test("a machine wider than its recycler sets the pitch", function()
    -- The inverse of the salvager case: pitch follows the wider of the pair, here the machine.
    -- Offsets 1, 5, 9; width = 9 + 4 + 1 = 14.
    local built = layout.build(params_with({
      machine = { name = "wide-machine", quality = "normal", width = 4, height = 3, module_slots = 2 },
    }))
    assert(built.width == 14, "width " .. built.width .. ", expected 14")
    assert_no_overlap_and_in_bounds(built)
  end)

  test("a two-tier plan: one recycler, minimal width", function()
    -- The narrowest plan the planner can ask for (targets skip normal, so two tiers is the
    -- floor): offsets 1, 4; width = 4 + 3 + 1 = 8.
    local built = layout.build(params_with({ tiers = { "normal", "uncommon" } }))
    assert(built.width == 8, "width " .. built.width .. ", expected 8")
    assert(built.machines == 2 and built.recyclers == 1,
      "counts " .. built.machines .. "/" .. built.recyclers .. ", expected 2 machines, 1 recycler")
    assert_no_overlap_and_in_bounds(built)
  end)

  test("module insert plans carry each building's own slot count", function()
    local built = layout.build(params_with())
    for _, e in pairs(by_name(built, "assembling-machine-2")) do
      assert(e.modules.count == 2, "machine module count " .. tostring(e.modules.count))
    end
    for _, e in pairs(by_name(built, "recycler")) do
      assert(e.modules.count == 4, "recycler module count " .. tostring(e.modules.count))
    end
  end)
end)

describe("layout.build beacon plans", function()
  -- module_inventory is opaque to the layout -- a number the planner resolved, carried onto
  -- the entity for the serialiser -- so a sentinel proves the carry without touching defines.
  local function beacon_params(overrides)
    local params = params_with()
    params.beacon = {
      name = "beacon", quality = "normal", width = 3, height = 3,
      module_slots = 2, module_inventory = 99,
    }
    params.modules = {
      quality_module = { name = "quality-module", quality = "normal" },
      terminal_module = { name = "productivity-module", quality = "normal" },
      beacon_module = { name = "efficiency-module", quality = "normal" },
    }
    for key, value in pairs(overrides or {}) do params[key] = value end
    return params
  end

  test("one beacon per tier in a floored column: vanilla three tiers grow 11 to 20", function()
    local built = layout.build(beacon_params())
    assert(built.width == 20, "width " .. built.width .. ", expected 11 + 3*3 = 20")
    local beacons = by_name(built, "beacon")
    assert(#beacons == 3, "beacon count " .. #beacons .. ", expected one per tier")
    local at = {}
    for _, b in pairs(beacons) do
      at[b.dx] = b.dy
      assert(b.modules.name == "efficiency-module", "beacon module " .. tostring(b.modules.name))
      assert(b.modules.count == 2, "beacon module count " .. tostring(b.modules.count))
      assert(b.module_inventory == 99, "module_inventory not carried onto the entity")
    end
    -- Non-terminal beacons centre on the machine+recycler band (rows 4..10 -> dy 6); the
    -- terminal tier has no recycler and centres on the machine alone (dy 4). All flush against
    -- their tier column at col - 3.
    assert(at[1] == 6, "tier 1 beacon at dy " .. tostring(at[1]) .. ", expected 6")
    assert(at[7] == 6, "tier 2 beacon at dy " .. tostring(at[7]) .. ", expected 6")
    assert(at[13] == 4, "terminal beacon at dy " .. tostring(at[13]) .. ", expected 4")
    assert(built.utility_columns and #built.utility_columns == 3,
      "beacon columns must be reported for the pole pass")
    assert_no_overlap_and_in_bounds(built)
  end)

  test("requested gaps below the beacon's width are floored, never honoured", function()
    -- The floor lives in layout.build like the fluid clamp, so no pole-ladder attempt can
    -- take away the ground the beacon stands on. Mixed below-floor requests, not {0,0,0} --
    -- absent gaps already compute to zero, so all-zero would be byte-identical input to the
    -- first test and could never fail on its own.
    local built = layout.build(beacon_params({ column_gaps = { 1, 2, 0 } }))
    assert(built.width == 20, "width " .. built.width .. " -- the floor did not hold")
    assert(#by_name(built, "beacon") == 3, "a floored column lost its beacon")
    for _, col in pairs(built.utility_columns) do
      assert(col.width == 3, "column floored to " .. col.width .. ", expected the beacon's 3")
    end
    assert_no_overlap_and_in_bounds(built)
  end)

  test("a wider requested column keeps the beacon flush against its tier", function()
    -- A pole wider than the beacon widens the column; the beacon stays on the east side of it,
    -- against the machines, and the spare ground to its west is the pole's.
    local built = layout.build(beacon_params({ column_gaps = { 5, 5, 5 } }))
    assert(built.width == 26, "width " .. built.width .. ", expected 2 + 3*5 + 2*3 + 3 = 26")
    local at = {}
    for _, b in pairs(by_name(built, "beacon")) do at[b.dx] = true end
    for _, dx in pairs({ 3, 11, 19 }) do
      assert(at[dx], "no beacon flush against its tier column at " .. dx)
    end
    assert_no_overlap_and_in_bounds(built)
  end)

  test("a fluid plan stands the beacon west of the pipe run", function()
    local params = beacon_params({
      fluid = { pipe = "pipe", pipe_to_ground = "pipe-to-ground" },
      machine = {
        name = "assembling-machine-2", quality = "normal", width = 3, height = 3,
        module_slots = 2, direction = defines.direction.west,
      },
    })
    local built = layout.build(params)
    assert(built.width == 23, "width " .. built.width .. ", expected 2 + 3*4 + 2*3 + 3 = 23")
    local beacon_at, pipe_at = {}, {}
    for _, e in pairs(built.entities) do
      if e.name == "beacon" then beacon_at[e.dx] = true end
      if e.name == "pipe" then pipe_at[e.dx] = true end
    end
    -- Machines start at 5, 12, 19; the run keeps the column's east edge (col - 1) and the
    -- beacon stands immediately west of it.
    for _, col in pairs({ 5, 12, 19 }) do
      assert(pipe_at[col - 1], "no pipe run beside the machine at " .. col)
      assert(beacon_at[col - 4], "no beacon west of the pipe for the machine at " .. col)
    end
    assert_no_overlap_and_in_bounds(built)
  end)

  test("a tall beacon clamps inside the interior rows instead of poking the ring", function()
    -- Height 13 fills the whole interior (rows 1..13 with the vanilla band); the centring
    -- formula alone would start it above the ring. The overlap invariant is the real assertion.
    local built = layout.build(beacon_params({
      beacon = { name = "tall-beacon", quality = "normal", width = 3, height = 13,
        module_slots = 2, module_inventory = 99 },
    }))
    for _, b in pairs(by_name(built, "tall-beacon")) do
      assert(b.dy == 1, "tall beacon at dy " .. b.dy .. ", expected clamped to row 1")
    end
    assert_no_overlap_and_in_bounds(built)
  end)

  test("no beacon module plans the beacons empty, slots intact", function()
    local params = beacon_params()
    params.modules.beacon_module = nil
    local built = layout.build(params)
    for _, b in pairs(by_name(built, "beacon")) do
      assert(b.modules.name == nil, "an empty beacon grew a module")
      assert(b.modules.count == 2, "the slot count must survive an empty plan")
    end
  end)

  test("a beacon module without a beacon changes nothing", function()
    -- Built from params_with() directly rather than beacon_params({ beacon = nil }): a nil in
    -- an overrides table is invisible to pairs(), the `{ field = nil }` trap.
    local params = params_with()
    params.modules = {
      quality_module = { name = "quality-module", quality = "normal" },
      terminal_module = { name = "productivity-module", quality = "normal" },
      beacon_module = { name = "efficiency-module", quality = "normal" },
    }
    assert(deep_equal(layout.build(params_with()), layout.build(params)),
      "a stray beacon module changed the beaconless plan")
  end)

  test("layout.max_beacon_count is the interior rows over the beacon's height", function()
    -- Vanilla shapes: interior 6+3+4 = 13, so four 3-tall beacons fit; a 13-tall one exactly
    -- fills it; a 20-tall one is the too-tall refusal's zero.
    assert(layout.max_beacon_count(3, 4, 3) == 4,
      "vanilla max " .. layout.max_beacon_count(3, 4, 3))
    assert(layout.max_beacon_count(3, 4, 13) == 1,
      "exact-fit max " .. layout.max_beacon_count(3, 4, 13))
    assert(layout.max_beacon_count(3, 4, 20) == 0,
      "over-tall max " .. layout.max_beacon_count(3, 4, 20))
    assert(layout.max_beacon_count(3, 3, 3) == 4,
      "zero-remainder max " .. layout.max_beacon_count(3, 3, 3))
  end)

  test("an explicit count of one is byte-identical to the single-beacon plan", function()
    assert(deep_equal(layout.build(beacon_params()),
      layout.build(beacon_params({ beacon_count = 1 }))),
      "beacon_count = 1 changed the plan")
  end)

  test("two beacons stack vertically at zero width cost", function()
    local built = layout.build(beacon_params({ beacon_count = 2 }))
    assert(built.width == 20, "width " .. built.width .. " -- stacking must cost no width")
    local beacons = by_name(built, "beacon")
    assert(#beacons == 6, "beacon count " .. #beacons .. ", expected two per tier")
    local at = {}
    for _, b in pairs(beacons) do
      at[b.dx] = at[b.dx] or {}
      at[b.dx][b.dy] = true
      assert(b.modules.count == 2, "a stacked beacon lost its module plan")
    end
    -- The pair centres as one block: the 7-row band holds a 6-tall stack from dy 4
    -- (floor((7-6)/2) = 0); the terminal band of 3 centres the same block at dy 2.
    for _, dx in pairs({ 1, 7 }) do
      assert(at[dx][4] and at[dx][7], "tier at " .. dx .. " is not stacked at dy 4 and 7")
    end
    assert(at[13][2] and at[13][5], "terminal stack not at dy 2 and 5")
    for _, col in pairs(built.utility_columns) do
      assert(col.width == 3, "a stacked column widened to " .. col.width)
    end
    assert_no_overlap_and_in_bounds(built)
  end)

  test("a full stack exactly fills the interior rows, contiguous, in bounds", function()
    -- Interior 6+3+3 = 12 with a 3-tall recycler, so four beacons fill it with no remainder --
    -- the shape where the beacon column offers the pole pass not a single free row, which is
    -- what the planner's pole lane exists for.
    local built = layout.build(beacon_params({
      recycler = { name = "recycler", quality = "normal", width = 2, height = 3,
        module_slots = 4, direction = defines.direction.north },
      beacon_count = 4,
    }))
    local by_dx = {}
    for _, b in pairs(by_name(built, "beacon")) do
      by_dx[b.dx] = by_dx[b.dx] or {}
      table.insert(by_dx[b.dx], b.dy)
    end
    for dx, dys in pairs(by_dx) do
      table.sort(dys)
      assert(#dys == 4, "tier at " .. dx .. " stacked " .. #dys .. ", expected 4")
      assert(dys[1] == 1, "stack at " .. dx .. " starts at dy " .. dys[1] .. ", expected row 1")
      for i = 2, 4 do
        assert(dys[i] == dys[i - 1] + 3,
          "stack at " .. dx .. " tore between " .. dys[i - 1] .. " and " .. dys[i])
      end
    end
    assert_no_overlap_and_in_bounds(built)
  end)

  test("a stack taller than the band clamps as one block, never torn apart", function()
    -- Three 4-tall beacons: 12 rows in a 13-row interior, far over the 7-row band. The block
    -- shifts to fit; clamping each beacon alone would have piled them onto the same rows.
    local built = layout.build(beacon_params({
      beacon = { name = "tall-beacon", quality = "normal", width = 3, height = 4,
        module_slots = 2, module_inventory = 99 },
      beacon_count = 3,
    }))
    local by_dx = {}
    for _, b in pairs(by_name(built, "tall-beacon")) do
      by_dx[b.dx] = by_dx[b.dx] or {}
      table.insert(by_dx[b.dx], b.dy)
    end
    for dx, dys in pairs(by_dx) do
      table.sort(dys)
      assert(#dys == 3, "tier at " .. dx .. " stacked " .. #dys)
      for i = 2, 3 do
        assert(dys[i] == dys[i - 1] + 4, "the clamp tore the stack at " .. dx)
      end
      assert(dys[1] >= 1 and dys[3] + 4 <= 14, "stack outside the interior rows at " .. dx)
    end
    assert_no_overlap_and_in_bounds(built)
  end)

  test("a fluid plan stacks west of the pipe run at the same dx", function()
    local params = beacon_params({
      fluid = { pipe = "pipe", pipe_to_ground = "pipe-to-ground" },
      machine = {
        name = "assembling-machine-2", quality = "normal", width = 3, height = 3,
        module_slots = 2, direction = defines.direction.west,
      },
      beacon_count = 2,
    })
    local built = layout.build(params)
    assert(built.width == 23, "width " .. built.width .. " -- stacking must not widen a fluid plan")
    local beacon_at = {}
    for _, e in pairs(built.entities) do
      if e.name == "beacon" then beacon_at[e.dx] = (beacon_at[e.dx] or 0) + 1 end
    end
    for _, col in pairs({ 5, 12, 19 }) do
      assert(beacon_at[col - 4] == 2,
        "no pair of beacons west of the pipe for the machine at " .. col)
    end
    assert_no_overlap_and_in_bounds(built)
  end)
end)

describe("layout.build circuit tags", function()
  -- The structural facts the circuit pass finds entities by: written unconditionally, since
  -- they cost nothing when circuits are off and the serialiser reads only fields it names.
  local function tally(built)
    local count = {}
    for _, e in pairs(built.entities) do
      if e.circuit_role then count[e.circuit_role] = (count[e.circuit_role] or 0) + 1 end
    end
    return count
  end

  test("machines, recyclers, censuses, reserves and the perimeter carry tags; nothing else does", function()
    local built = layout.build(params_with())
    local count = tally(built)
    assert(count.machine == 3, "tagged machines " .. tostring(count.machine))
    assert(count.recycler == 2, "tagged recyclers " .. tostring(count.recycler))
    -- One census per tier: the stock chest below, or the output chest on the terminal.
    assert(count.census == 3, "tagged censuses " .. tostring(count.census))
    -- One reserve point per lower tier: the stock-to-recycler inserter, the only hand that
    -- can draw a tier's chest below its floor.
    assert(count.reserve == 2, "tagged reserves " .. tostring(count.reserve))
    -- The perimeter of an 11x15 ring, and NOT the four per-tier product belts: a relay
    -- riding a column's own belt would gate the product path it is meant to bypass.
    assert(count.ring == 48, "tagged ring belts " .. tostring(count.ring))
    local untagged_belts = 0
    for _, e in pairs(built.entities) do
      if e.name == "transport-belt" and not e.circuit_role then
        untagged_belts = untagged_belts + 1
      end
    end
    assert(untagged_belts == 4, "untagged product belts " .. untagged_belts)
  end)

  test("every tagged tier matches the tier the entity is pinned to", function()
    local built = layout.build(params_with())
    local tiers = { "normal", "uncommon", "rare" }
    for _, e in pairs(built.entities) do
      if e.circuit_role == "machine" then
        assert(e.recipe_quality == tiers[e.circuit_tier],
          "machine tagged tier " .. e.circuit_tier .. " crafts at " .. e.recipe_quality)
      end
      if e.circuit_role == "census" and e.circuit_tier < 3 then
        assert(e.requests and e.requests[1].quality == tiers[e.circuit_tier],
          "census tier " .. e.circuit_tier .. " buffers " .. tostring(e.requests
            and e.requests[1].quality))
      end
    end
  end)
end)

describe("layout.build determinism", function()
  test("the same params build the same plan, twice", function()
    -- The desync-safety contract stated at the top of layout.lua, held to structurally: the
    -- params are rebuilt fresh per call so nothing can alias, and every field must match.
    assert(deep_equal(layout.build(params_with()), layout.build(params_with())),
      "two builds from identical params disagreed")
  end)
end)

describe("layout.build repeated tiers", function()
  -- The columns feature's premise: tiers may repeat a quality name -- planner.plan expands
  -- "N columns of this tier" into N consecutive entries -- and this file needs no code of
  -- its own for it, because everything in the per-column loop is positional. The target is
  -- pinned to one column by the expansion, so the last entry is always the sole terminal.
  local repeated = { "normal", "normal", "normal", "uncommon", "rare" }

  test("each repeat is a full column: counts, width and the sole terminal", function()
    local built = layout.build(params_with({ tiers = repeated }))
    assert(built.width == 17, "width " .. built.width .. ", expected 2 + 4*3 + 3 = 17")
    assert(built.height == 15, "height " .. built.height)
    assert(built.machines == 5, "machines " .. built.machines)
    assert(built.recyclers == 4, "recyclers " .. built.recyclers)
    assert(#by_name(built, "requester-chest") == 5, "one feed chest per column")
    -- One way out and one tap, however many columns feed them: the terminal branch runs
    -- for the single target entry alone.
    assert(#by_name(built, "passive-provider-chest") == 1, "output chests")
    assert(#by_name(built, "active-provider-chest") == 1, "overflow taps")
    assert_no_overlap_and_in_bounds(built)
  end)

  test("columns stay in array order and pinned to their own quality", function()
    local built = layout.build(params_with({ tiers = repeated }))
    local machines = by_name(built, "assembling-machine-2")
    table.sort(machines, function(a, b) return a.dx < b.dx end)
    for index, m in pairs(machines) do
      assert(m.recipe_quality == repeated[index],
        "column " .. index .. " crafts at " .. tostring(m.recipe_quality))
    end
  end)

  test("circuit_tier stays unique per column -- the decorator keys maps by it", function()
    -- circuits.lua builds machines[e.circuit_tier] = index and friends; a repeated value
    -- would silently drop every earlier column of the tier from the wiring.
    local built = layout.build(params_with({ tiers = repeated }))
    local seen = {}
    for _, e in pairs(built.entities) do
      if e.circuit_role == "machine" then
        assert(not seen[e.circuit_tier], "circuit_tier " .. e.circuit_tier .. " repeats")
        seen[e.circuit_tier] = true
      end
    end
    for index = 1, 5 do
      assert(seen[index], "no machine tagged circuit_tier " .. index)
    end
  end)

  test("repeats of a tier share its module mix; the positional split follows columns", function()
    -- planner.plan re-keys the per-tier split onto column positions, so layout's read stays
    -- params.modules.split[index]. Three normal columns at one productivity module each,
    -- the uncommon column at two (its whole slots), the terminal untouched.
    local built = layout.build(params_with({
      tiers = repeated,
      modules = {
        quality_module = { name = "quality-module", quality = "normal" },
        productivity_module = { name = "productivity-module", quality = "normal" },
        terminal_module = { name = "productivity-module", quality = "normal" },
        split = { 1, 1, 1, 2 },
      },
    }))
    local machines = by_name(built, "assembling-machine-2")
    table.sort(machines, function(a, b) return a.dx < b.dx end)
    assert(deep_equal(machines[1].modules, machines[2].modules)
      and deep_equal(machines[2].modules, machines[3].modules),
      "repeats of the normal tier disagree on their module mix")
    assert(machines[1].modules[1] and machines[1].modules[2],
      "a mixed lower tier should carry the two-entry insert plan")
    assert(machines[4].modules.name == "productivity-module",
      "the uncommon column's whole slots should hold productivity")
    assert(machines[5].modules.name == "productivity-module",
      "the terminal keeps its own module")
  end)

  test("a beacon plan stands a stack per physical column", function()
    local built = layout.build(params_with({
      tiers = repeated,
      beacon = { name = "beacon", quality = "normal", width = 3, height = 3, module_slots = 2 },
      beacon_count = 2,
    }))
    local beacons = #by_name(built, "beacon")
    assert(beacons == 10, "beacon count " .. beacons .. ", expected two per column")
    assert_no_overlap_and_in_bounds(built)
  end)

  test("a fluid plan opens a run per physical column", function()
    local built = layout.build(params_with({
      tiers = repeated,
      fluid = { pipe = "pipe", pipe_to_ground = "pipe-to-ground" },
      machine = {
        name = "assembling-machine-2", quality = "normal", width = 3, height = 3,
        module_slots = 2, direction = defines.direction.west,
      },
    }))
    local stubs = 0
    for _, e in pairs(built.entities) do
      if e.name == "pipe-to-ground" then stubs = stubs + 1 end
    end
    assert(stubs == 10, "stub count " .. stubs .. ", expected a pair per column")
    assert_no_overlap_and_in_bounds(built)
  end)
end)

describe("layout.build circuit stack", function()
  -- What planner.plan hands over as layout_params.circuit: fixed vanilla names, and whether
  -- the cap's lamps and panel join the combinator.
  local stack = circuit_stack.params

  local function stack_of(built)
    return circuit_stack.of(built.entities)
  end

  test("a capped stack stands under the terminal machine, in its product sub-column, footprint unchanged", function()
    -- Vanilla: the terminal column starts at 7, so col_product is 9, and the band below the
    -- machine starts at r.recycler = 7 -- four rows, the combinator first (its hop to the
    -- machine is the one every condition depends on), the indicators under it.
    local plain = layout.build(params_with())
    local built = layout.build(params_with({ circuit = stack(true) }))
    assert(built.width == plain.width and built.height == plain.height,
      "the stack changed the footprint: " .. built.width .. "x" .. built.height)
    local found, count = stack_of(built)
    assert(count == 4 and #built.entities == #plain.entities + 4,
      "stack entities " .. count .. ", plan grew by " .. (#built.entities - #plain.entities))
    local order = {
      { role = "limits", name = "constant-combinator" },
      { role = "lamp_done", name = "small-lamp" },
      { role = "lamp_running", name = "small-lamp" },
      { role = "panel", name = "display-panel" },
    }
    for i, want in ipairs(order) do
      local e = found[want.role]
      assert(e, want.role .. " was not placed")
      assert(e.name == want.name, want.role .. " is a " .. e.name)
      assert(e.dx == 9 and e.dy == 6 + i and e.w == 1 and e.h == 1,
        want.role .. " stands at " .. e.dx .. "," .. e.dy)
    end
    assert_no_overlap_and_in_bounds(built)
  end)

  test("an uncapped stack is the combinator alone, in the same place", function()
    local plain = layout.build(params_with())
    local built = layout.build(params_with({ circuit = stack(false) }))
    local found, count = stack_of(built)
    assert(count == 1 and found.limits, "an uncapped plan stood " .. count .. " stack entities")
    assert(found.limits.dx == 9 and found.limits.dy == 7,
      "the lone combinator stands at " .. found.limits.dx .. "," .. found.limits.dy)
    assert(#built.entities == #plain.entities + 1, "the plan grew by more than the combinator")
    assert_no_overlap_and_in_bounds(built)
  end)

  test("no circuit param: the plan is byte-identical to the one it always was", function()
    local plain = layout.build(params_with())
    local _, count = stack_of(plain)
    assert(count == 0, "a plan without circuits stood " .. count .. " stack entities")
    assert(deep_equal(plain.entities, layout.build(params_with({ circuit = nil })).entities),
      "an explicit nil differs from an absent circuit param")
  end)

  test("the stack fits the tightest shapes: a 1-tall recycler, and one wider than its machine", function()
    -- Hr + 3 rows is the band; at Hr = 1 the four entities take all of it, two columns over
    -- from the tap. A recycler wider than its machine widens the pitch but not the
    -- terminal column, so col_product is what keeps the stack inside the ring.
    local narrow = layout.build(params_with({
      recycler = {
        name = "flat-recycler", quality = "normal", width = 2, height = 1, module_slots = 1,
        direction = defines.direction.north,
      },
      circuit = stack(true),
    }))
    local _, count = stack_of(narrow)
    assert(count == 4, "the narrow shape lost stack entities: " .. count)
    assert_no_overlap_and_in_bounds(narrow)

    local wide = layout.build(params_with({
      recycler = {
        name = "aop-salvager", quality = "normal", width = 4, height = 4, module_slots = 2,
        direction = defines.direction.west,
      },
      circuit = stack(true),
    }))
    assert(wide.width == 13, "width " .. wide.width .. ", the stack must not widen the plan")
    assert_no_overlap_and_in_bounds(wide)
  end)
end)

describe("layout.build feed stacks", function()
  -- A recipe with more ingredients than one inserter can filter feeds each machine from two
  -- stacks: the second harvest inserter, feed chest and feed inserter stand in the buffer
  -- sub-column above the machine. The planner decides the count (params.feed_stacks); this
  -- file only has to divide the list and stand the stacks. The recipe shape is the shared
  -- fixture's big(n): "ing-1" .. "ing-n", the i-th requesting 10 * i.
  local function names_of(n)
    local names = {}
    for i = 1, n do names[i] = "ing-" .. i end
    return names
  end

  local function concat(chunk)
    return table.concat(chunk, ",")
  end

  test("split_ingredients divides balanced, larger halves first, and one stack is the list itself", function()
    local six = names_of(6)
    local halves = layout.split_ingredients(six, 2)
    assert(#halves == 2 and concat(halves[1]) == "ing-1,ing-2,ing-3"
      and concat(halves[2]) == "ing-4,ing-5,ing-6", "six over two: " .. concat(halves[1])
      .. " / " .. concat(halves[2]))
    local seven = layout.split_ingredients(names_of(7), 2)
    assert(#seven[1] == 4 and #seven[2] == 3, "seven over two must be 4 and 3")
    local ten = layout.split_ingredients(names_of(10), 2)
    assert(#ten[1] == 5 and #ten[2] == 5, "ten over two must be 5 and 5")
    -- One stack, or no count at all, hands back the very same table: the byte-identity of
    -- every plan that fits one inserter rests on that.
    local one = layout.split_ingredients(six, 1)
    assert(#one == 1 and one[1] == six, "one stack must be the list itself")
    local absent = layout.split_ingredients(six)
    assert(#absent == 1 and absent[1] == six, "no count must read as one stack")
    -- Never more stacks than names: a lone ingredient asked for two stacks gets one.
    local lone = layout.split_ingredients(names_of(1), 2)
    assert(#lone == 1 and #lone[1] == 1, "a lone ingredient must not stand an empty stack")
  end)

  test("one stack, asked for or defaulted, builds the plan byte for byte as before", function()
    assert(deep_equal(layout.build(params_with()), layout.build(params_with({ feed_stacks = 1 }))),
      "feed_stacks = 1 differs from the param being absent")
    -- Whether five ingredients fit one inserter is the planner's call, not this file's: sent
    -- one stack, five ingredients stand one chest per tier requesting all five.
    local built = layout.build(big_params(5, { feed_stacks = 1 }))
    assert(#by_name(built, "requester-chest") == 3, "a five-ingredient plan stands one feed chest per tier")
    for _, c in pairs(by_name(built, "requester-chest")) do
      assert(#c.requests == 5, "the one chest requests every ingredient")
    end
  end)

  test("a six-ingredient recipe stands a second stack in the buffer sub-column, every tier", function()
    local built = layout.build(big_params(6))
    assert(built.width == 11 and built.height == 15, "the second stack must cost no footprint")
    assert_no_overlap_and_in_bounds(built)

    -- Tier columns start at 1, 4 and 7; each has a stack at its first two sub-columns.
    local tiers = { { x = 1, quality = "normal" }, { x = 4, quality = "uncommon" },
      { x = 7, quality = "rare" } }
    local inserters, chests = {}, {}
    for _, e in pairs(by_name(built, "fast-inserter")) do inserters[e.dx .. "," .. e.dy] = e end
    for _, e in pairs(by_name(built, "requester-chest")) do chests[e.dx .. "," .. e.dy] = e end
    assert(#by_name(built, "requester-chest") == 6, "two feed chests per tier")

    local halves = { "ing-1,ing-2,ing-3", "ing-4,ing-5,ing-6" }
    for _, tier in pairs(tiers) do
      for i = 1, 2 do
        local x = tier.x + i - 1
        local harvest = inserters[x .. ",1"]
        assert(harvest and harvest.direction == defines.direction.north
          and harvest.filter_mode == "whitelist", "no harvest inserter at " .. x .. ",1")
        local filtered = {}
        for _, f in pairs(harvest.filters) do
          assert(f.quality == tier.quality, "a harvest filter at the wrong tier")
          filtered[#filtered + 1] = f.name
        end
        assert(concat(filtered) == halves[i], "stack " .. i .. " at " .. x .. " filters " .. concat(filtered))

        local chest = chests[x .. ",2"]
        assert(chest, "no feed chest at " .. x .. ",2")
        local requested = {}
        for _, r in pairs(chest.requests) do
          assert(r.quality == tier.quality, "a request at the wrong tier")
          assert(r.count == 10 * tonumber(r.name:match("%d+")), "request count for " .. r.name)
          requested[#requested + 1] = r.name
        end
        assert(concat(requested) == halves[i], "stack " .. i .. " at " .. x .. " requests " .. concat(requested))

        local feed = inserters[x .. ",3"]
        assert(feed and feed.direction == defines.direction.north and not feed.filters,
          "no unfiltered feed inserter at " .. x .. ",3")
      end
    end
  end)

  test("the relief inserter stays one nameless slot whatever the stack count", function()
    local built = layout.build(big_params(10))
    local reliefs = 0
    for _, e in pairs(by_name(built, "fast-inserter")) do
      if e.filters and e.filters[1] and not e.filters[1].name
        and e.direction == defines.direction.north then
        assert(#e.filters == 1, "relief filter count " .. #e.filters)
        reliefs = reliefs + 1
      end
    end
    assert(reliefs == 2, "relief inserters " .. reliefs)
    -- Ten ingredients: five per stack, the vanilla ceiling. The terminal catcher shares the
    -- harvest row with a named filter of its own -- the product -- so match on the ingredients.
    local harvests = 0
    for _, e in pairs(by_name(built, "fast-inserter")) do
      if e.dy == 1 and e.filters and e.filters[1].name and e.filters[1].name:match("^ing%-") then
        assert(#e.filters == 5, "a ten-ingredient harvest stack carries " .. #e.filters)
        harvests = harvests + 1
      end
    end
    assert(harvests == 6, "harvest inserters " .. harvests .. ", expected two per tier")
  end)

  test("two stacks build the same plan twice, and fit a fluid, beaconed, circuit plan", function()
    assert(deep_equal(layout.build(big_params(7)), layout.build(big_params(7))),
      "two builds from identical two-stack params disagreed")
    local loaded = layout.build(big_params(7, {
      column_gaps = { 2, 2, 2 },
      fluid = { pipe = "pipe", pipe_to_ground = "pipe-to-ground" },
      machine = {
        name = "assembling-machine-2", quality = "normal", width = 3, height = 3,
        module_slots = 2, direction = defines.direction.west,
      },
      circuit = circuit_stack.params(true),
    }))
    assert(#by_name(loaded, "requester-chest") == 6, "feed chests on the loaded plan")
    assert_no_overlap_and_in_bounds(loaded)
  end)

  test("repeated columns each stand their own two stacks", function()
    local built = layout.build(big_params(8, {
      tiers = { "normal", "normal", "normal", "uncommon", "rare" },
    }))
    assert(#by_name(built, "requester-chest") == 10, "two feed chests per physical column")
    assert(built.width == 17, "width " .. built.width)
    assert_no_overlap_and_in_bounds(built)
  end)
end)
