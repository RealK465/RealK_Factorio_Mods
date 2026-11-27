-- layout_bot.build as pure geometry: hand-built params, no prototypes, no force -- layout_spec's
-- shape for the second family. The canonical numbers come from the row plan in the file's
-- header: vanilla three tiers is 9 wide and 11 tall, 25 entities before poles.

local layout = require("scripts.layout")
local layout_bot = require("scripts.layout_bot")

local layout_params = require("tests.support.layout_params")
local deep_equal = require("tests.support.deep_equal")
local circuit_stack = require("tests.support.circuit_stack")
local footprint = require("tests.support.footprint")

local bot = layout_params.bot
local by_name = footprint.by_name
local assert_no_overlap_and_in_bounds = footprint.assert_no_overlap_and_in_bounds

local NORTH = defines.direction.north
local SOUTH = defines.direction.south

-- The vanilla fixture's rows: machine 3 tall from row 2, recycler 4 tall from row 5.
local ROW_RECYCLER, ROW_LOWER_INSERTER, ROW_LOWER_CHEST = 5, 9, 10

local function at(built, x, y)
  for _, e in pairs(built.entities) do
    if x >= e.dx and x < e.dx + e.w and y >= e.dy and y < e.dy + e.h then return e end
  end
  return nil
end

local function by_role(built, role)
  local out = {}
  for _, e in pairs(built.entities) do
    if e.circuit_role == role then out[#out + 1] = e end
  end
  return out
end

local function beacon_params(overrides)
  return layout_params.with_beacon(bot(), overrides)
end

describe("layout_bot.build dimensions", function()
  test("vanilla three tiers: 9 by 11, 25 entities, not a belt or a relay chest among them", function()
    local built = layout_bot.build(bot())
    assert(built.width == 9, "width " .. built.width .. ", expected 3 columns of 3")
    assert(built.height == 11, "height " .. built.height .. ", expected 4 + 3 + 4")
    assert(built.machines == 3 and built.recyclers == 2, "column counts")
    assert(#built.entities == 25, "entity count " .. #built.entities .. ", expected 10 + 10 + 5")
    local expected = {
      ["assembling-machine-2"] = 3, ["recycler"] = 2, ["requester-chest"] = 3,
      ["buffer-chest"] = 2, ["passive-provider-chest"] = 1, ["active-provider-chest"] = 4,
      ["fast-inserter"] = 10, ["transport-belt"] = 0, ["iron-chest"] = 0,
    }
    for name, count in pairs(expected) do
      assert(#by_name(built, name) == count, name .. " count " .. #by_name(built, name)
        .. ", expected " .. count)
    end
    assert(built.utility_columns == nil, "no gap was asked for, so no utility column opened")
    assert_no_overlap_and_in_bounds(built)
  end)

  test("a recycler wider than its machine widens the pitch, the terminal column stays machine-wide", function()
    local built = layout_bot.build(bot({ recycler = layout_params.salvager() }))
    assert(built.width == 11, "width " .. built.width .. ", expected 2*4 + 3")
    assert_no_overlap_and_in_bounds(built)
  end)

  test("five tiers to legendary: 15 by 11", function()
    local built = layout_bot.build(bot({ tiers = { "normal", "uncommon", "rare", "epic", "legendary" } }))
    assert(built.width == 15 and built.height == 11, "footprint " .. built.width .. "x" .. built.height)
    assert(built.machines == 5 and built.recyclers == 4, "column counts")
    assert_no_overlap_and_in_bounds(built)
  end)

  test("utility columns open before the tiers that ask for one, and are reported", function()
    local built = layout_bot.build(bot({ column_gaps = { 2, 0, 2 } }))
    assert(built.width == 13, "width " .. built.width .. ", expected 2 + 3 + 3 + 2 + 3")
    local columns = built.utility_columns
    assert(columns and #columns == 2, "utility columns " .. tostring(columns and #columns))
    assert(columns[1].x == 0 and columns[1].width == 2 and columns[1].tier == 1, "first column")
    assert(columns[2].x == 8 and columns[2].width == 2 and columns[2].tier == 3, "second column")
    for _, column in pairs(columns) do
      for x = column.x, column.x + column.width - 1 do
        for y = 0, built.height - 1 do
          local occupant = at(built, x, y)
          assert(occupant == nil, "the utility column holds " .. tostring(occupant and occupant.name))
        end
      end
    end
  end)
end)

describe("layout_bot.build columns", function()
  test("each recycler stands tangent under its machine, left-aligned, so its throw lands inside", function()
    local built = layout_bot.build(bot())
    local machines = by_role(built, "machine")
    for _, recycler in pairs(by_role(built, "recycler")) do
      local machine = machines[recycler.circuit_tier]
      assert(recycler.dx == machine.dx, "recycler is not left-aligned under its machine")
      assert(recycler.dy == machine.dy + machine.h, "recycler is not tangent under its machine")
    end
  end)

  test("every inserter faces the way it moves, between the chest and the building it serves", function()
    local built = layout_bot.build(bot())
    for index, machine in pairs(by_role(built, "machine")) do
      local col = machine.dx
      local feed = at(built, col, 1)
      assert(feed.direction == NORTH and at(built, col, 0).name == "requester-chest",
        "tier " .. index .. ": the feed inserter must pick from the chest above it")
      local out = at(built, col + 2, 1)
      assert(out.direction == SOUTH, "tier " .. index .. ": the out inserter must pick from the machine")
      if index < 3 then
        local extract = at(built, col, ROW_LOWER_INSERTER)
        assert(extract.direction == NORTH and at(built, col, ROW_RECYCLER).name == "recycler",
          "tier " .. index .. ": the extract inserter must pick from the recycler above it")
        local back = at(built, col + 1, ROW_LOWER_INSERTER)
        assert(back.direction == SOUTH and at(built, col + 1, ROW_LOWER_CHEST).name == "buffer-chest",
          "tier " .. index .. ": the return inserter must pick from the return chest below it")
      end
    end
  end)

  test("only the extract inserter filters, with the nameless above-this-tier whitelist", function()
    local built = layout_bot.build(bot())
    local filtered = 0
    for _, e in pairs(by_name(built, "fast-inserter")) do
      if e.filters then
        filtered = filtered + 1
        assert(e.dy == ROW_LOWER_INSERTER and e.direction == NORTH, "a filter on the wrong inserter")
        assert(e.filter_mode == "whitelist" and #e.filters == 1 and e.filters[1].name == nil
          and e.filters[1].comparator == ">", "the extract filter lost its shape")
        local tier = at(built, e.dx, ROW_RECYCLER).circuit_tier
        assert(e.filters[1].quality == ({ "normal", "uncommon" })[tier], "the extract filter names the wrong tier")
      else
        assert(e.filter_mode == nil, "an unfiltered inserter carries a filter mode")
      end
    end
    assert(filtered == 2, "filtered inserters " .. filtered .. ", expected one per recycler")
  end)

  test("lower outputs and extract chests are the overflow pick, the last output the provider", function()
    local built = layout_bot.build(bot())
    local machines = by_role(built, "machine")
    for index, machine in pairs(machines) do
      local out = at(built, machine.dx + 2, 0)
      if index < #machines then
        assert(out.name == "active-provider-chest", "tier " .. index .. " output is " .. out.name)
        assert(out.circuit_role == nil, "a lower output chest must never be a circuit census")
        local extract = at(built, machine.dx, ROW_LOWER_CHEST)
        assert(extract.name == "active-provider-chest" and extract.circuit_role == nil,
          "tier " .. index .. " extract chest is " .. extract.name)
      else
        assert(out.name == "passive-provider-chest" and out.circuit_role == "census",
          "the terminal output must be the provider pick and the target's census")
      end
    end
  end)

  test("the feed chest requests every ingredient at its tier, the return chest its tier's product", function()
    local params = layout_params.bot_of(layout_params.big(7))
    local built = layout_bot.build(params)
    local feeds = by_role(built, "feed")
    assert(#feeds == 3, "feed chests " .. #feeds .. ": seven ingredients still take one chest a tier")
    for _, feed in pairs(feeds) do
      local quality = params.tiers[feed.circuit_tier]
      assert(#feed.requests == 7, "feed requests " .. #feed.requests)
      for i, request in ipairs(feed.requests) do
        assert(request.name == "ing-" .. i and request.quality == quality and request.count == 10 * i,
          "feed request " .. i .. " is " .. request.name .. "@" .. request.quality)
      end
    end
    for _, census in pairs(by_role(built, "census")) do
      if census.circuit_tier < 3 then
        local quality = params.tiers[census.circuit_tier]
        assert(census.name == "buffer-chest" and #census.requests == 1
          and census.requests[1].name == "big-product" and census.requests[1].quality == quality
          and census.requests[1].count == 50, "the return chest's request is wrong")
      else
        assert(census.requests == nil, "the output chest requests nothing")
      end
    end
  end)

  test("no product_buffer leaves the return chest without a request", function()
    local params = bot()
    params.product_buffer = nil
    for _, census in pairs(by_role(layout_bot.build(params), "census")) do
      assert(census.requests == nil, "a return chest requested with no buffer set")
    end
  end)

  test("machines carry the same modules as the belt ring's, split and terminal module alike", function()
    local params = bot({ tiers = { "normal", "uncommon", "rare" } })
    params.modules.productivity_module = { name = "productivity-module", quality = "normal" }
    params.modules.split = { 1, 2 }
    local belt_params = layout_params.vanilla({ modules = params.modules })
    local bot_machines = by_role(layout_bot.build(params), "machine")
    local belt_machines = by_role(layout.build(belt_params), "machine")
    for i = 1, 3 do
      assert(deep_equal(bot_machines[i].modules, belt_machines[i].modules),
        "tier " .. i .. " modules differ between the two layouts")
    end
    assert(bot_machines[3].modules.name == "productivity-module", "the final machine lost its module")
  end)
end)

describe("layout_bot.build fluid plans", function()
  test("the pipe run fills the utility column's east edge, top to bottom, a stub at each end", function()
    local built = layout_bot.build(bot({
      column_gaps = { 0, 0, 0 }, fluid = { pipe = "pipe", pipe_to_ground = "pipe-to-ground" },
    }))
    assert(built.width == 12, "width " .. built.width .. ": the pipe's tile floors every column at 1")
    for _, machine in pairs(by_role(built, "machine")) do
      local x = machine.dx - 1
      local top, bottom = at(built, x, 0), at(built, x, built.height - 1)
      assert(top.name == "pipe-to-ground" and top.direction == SOUTH, "the top stub must face into the run")
      assert(bottom.name == "pipe-to-ground" and bottom.direction == NORTH, "the bottom stub must face into the run")
      for y = 1, built.height - 2 do
        assert(at(built, x, y).name == "pipe", "row " .. y .. " of the run is " .. tostring(at(built, x, y)))
      end
    end
    assert_no_overlap_and_in_bounds(built)
  end)
end)

describe("layout_bot.build beacon plans", function()
  test("every row is beacon ground: three vanilla beacons stack, four do not fit", function()
    assert(layout_bot.max_beacon_count(3, 4, 1) == 11, "every one of the plan's 11 rows is beacon ground")
    assert(layout_bot.max_beacon_count(3, 4, 3) == 3, "the max is the plan's height over the beacon's")
  end)

  test("a stack stands contiguous in its column, inside the plan, beside its own tier", function()
    local built = layout_bot.build(beacon_params({ beacon_count = 3 }))
    assert(built.width == 18, "width " .. built.width .. ": a beacon floors every column at its width")
    local beacons = by_name(built, "beacon")
    assert(#beacons == 9, "beacons " .. #beacons .. ", expected three per tier")
    for _, machine in pairs(by_role(built, "machine")) do
      local column = {}
      for _, beacon in pairs(beacons) do
        if beacon.dx == machine.dx - 3 then column[#column + 1] = beacon.dy end
      end
      table.sort(column)
      assert(#column == 3 and column[2] == column[1] + 3 and column[3] == column[2] + 3,
        "tier " .. machine.circuit_tier .. "'s stack is not contiguous")
      assert(column[1] >= 0 and column[3] + 3 <= built.height, "a stack left the plan")
    end
    for _, beacon in pairs(beacons) do
      assert(beacon.module_inventory == 99 and beacon.modules.name == "efficiency-module",
        "a beacon lost its insert plan")
    end
    assert_no_overlap_and_in_bounds(built)
  end)
end)

describe("layout_bot.build circuit tags", function()
  test("every per-column role is tagged once a column; lower outputs and extract chests never", function()
    local built = layout_bot.build(bot())
    local expected = {
      machine = 3, recycler = 2, census = 3, reserve = 2, feed = 3, relay_in = 3, relay_out = 3,
    }
    for role, count in pairs(expected) do
      local found, tiers = by_role(built, role), {}
      assert(#found == count, role .. " count " .. #found .. ", expected " .. count)
      for _, e in pairs(found) do
        assert(not tiers[e.circuit_tier], role .. " tagged twice in tier " .. e.circuit_tier)
        tiers[e.circuit_tier] = true
      end
    end
    for _, chest in pairs(by_name(built, "active-provider-chest")) do
      assert(chest.circuit_role == nil, "an active provider carries a circuit role")
    end
  end)

  test("the circuit stack stands under the terminal machine, combinator first", function()
    local built = layout_bot.build(bot({ circuit = circuit_stack.params(true) }))
    local stack, count = circuit_stack.of(built.entities)
    assert(count == 4, "stack entities " .. count)
    local order = { "limits", "lamp_done", "lamp_running", "panel" }
    for i, role in ipairs(order) do
      assert(stack[role].dx == 8 and stack[role].dy == ROW_RECYCLER + i - 1,
        role .. " stands at " .. stack[role].dx .. "," .. stack[role].dy)
    end
    assert(built.width == 9, "the stack must not widen the plan")
    assert_no_overlap_and_in_bounds(built)

    local reserves = layout_bot.build(bot({ circuit = circuit_stack.params(false) }))
    local _, alone = circuit_stack.of(reserves.entities)
    assert(alone == 1, "a reserve-only plan stands the combinator alone")
  end)

  test("a short recycler wraps the stack into the next tile west, never out of the plan", function()
    local built = layout_bot.build(bot({
      recycler = layout_params.flat_recycler(), circuit = circuit_stack.params(true),
    }))
    local stack, count = circuit_stack.of(built.entities)
    assert(count == 4, "the short shape lost stack entities: " .. count)
    assert(stack.limits.dx == 8 and stack.limits.dy == 5, "the combinator left the machine's side")
    assert(stack.panel.dx == 7 and stack.panel.dy == 5, "the fourth entity did not wrap west")
    assert(built.width == 9 and built.height == 8, "the wrap changed the footprint")
    assert_no_overlap_and_in_bounds(built)
  end)
end)

describe("layout_bot.build repeated tiers and determinism", function()
  test("a repeated tier repeats its whole column", function()
    local built = layout_bot.build(bot({ tiers = { "normal", "normal", "uncommon", "rare" } }))
    assert(built.width == 12 and built.machines == 4 and built.recyclers == 3, "repeated columns")
    local tiers = {}
    for _, machine in pairs(by_role(built, "machine")) do
      tiers[machine.circuit_tier] = machine.recipe_quality
    end
    assert(tiers[1] == "normal" and tiers[2] == "normal" and tiers[3] == "uncommon"
      and tiers[4] == "rare", "the columns are out of order")
    assert_no_overlap_and_in_bounds(built)
  end)

  test("the same params build the same plan", function()
    assert(deep_equal(layout_bot.build(bot()), layout_bot.build(bot())), "two builds differ")
  end)

  test("what only the belt ring places is ignored", function()
    local with = bot({
      belt = "transport-belt", container = { name = "iron-chest", quality = "normal" },
      overflow_tap = true, feed_stacks = 2,
      terminal_feed = { name = "wooden-chest", quality = "normal" },
    })
    assert(deep_equal(layout_bot.build(with), layout_bot.build(bot())), "a belt-only param moved the plan")
  end)
end)
