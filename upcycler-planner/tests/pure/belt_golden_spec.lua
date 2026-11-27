-- The belt ring, frozen. Every digest below was captured from the tree BEFORE the bot layout
-- moved shared code out of layout.build (2026-11-27), so a hoist that reorders an entity,
-- renames a field or drops a tag fails here even when every self-comparing determinism spec
-- still passes -- those compare two builds of the same code, which proves nothing about a
-- refactor. A digest that moves for a reason is re-captured from the failure message, and
-- the reason goes in the commit.
--
-- Pure: hand-built params through layout.build, and circuits.decorate on top for the cases
-- whose wiring the ring-less spine path must leave alone.

local layout = require("scripts.layout")
local circuits = require("scripts.circuits")
local layout_params = require("tests.support.layout_params")
local circuit_stack = require("tests.support.circuit_stack")
local fingerprint = require("tests.support.fingerprint")

local params_with = layout_params.vanilla

local FLUID = { pipe = "pipe", pipe_to_ground = "pipe-to-ground" }

-- Its own beacon and recycler fixtures, not layout_params' copies. The rest still build on
-- layout_params and circuit_stack, so an edit to either moves these digests too: change a
-- shared fixture in a commit of its own, never beside a change to the code these pin.
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

-- A built layout decorated the way planner.plan decorates one: the stack stood first from the
-- same numbers, then the conditions and wires.
local function decorated(overrides, opts)
  local params = params_with(overrides)
  local capped = opts.maximum ~= nil
  params.circuit = circuit_stack.params(capped)
  local built = layout.build(params)
  built.unlinked = circuits.decorate(built.entities, {
    tiers = params.tiers, minimums = opts.minimums or {}, maximum = opts.maximum,
    paused = opts.paused, network = opts.network, hand = opts.hand or 4,
    product = "iron-gear-wheel", reach = opts.reach or 9, feed_reach = opts.reach or 9,
  })
  return built
end

local CASES = {
  vanilla = function() return layout.build(params_with()) end,
  salvager = function()
    return layout.build(params_with({
      recycler = {
        name = "aop-salvager", quality = "normal", width = 4, height = 4, module_slots = 2,
        direction = defines.direction.west,
      },
    }))
  end,
  uneven_gaps = function() return layout.build(params_with({ column_gaps = { 0, 2, 0 } })) end,
  fluid = function()
    return layout.build(params_with({ column_gaps = { 2, 2, 2 }, fluid = FLUID }))
  end,
  beacons_fluid = function()
    return layout.build(beacon_params({
      fluid = FLUID, beacon_count = 3, column_gaps = { 4, 5, 0 },
    }))
  end,
  stack_capped = function()
    return layout.build(params_with({ circuit = circuit_stack.params(true) }))
  end,
  stack_reserves = function()
    return layout.build(params_with({ circuit = circuit_stack.params(false) }))
  end,
  flat_recycler_stack = function()
    return layout.build(params_with({
      recycler = {
        name = "flat-recycler", quality = "normal", width = 2, height = 1, module_slots = 1,
        direction = defines.direction.north,
      },
      circuit = circuit_stack.params(true),
    }))
  end,
  two_stacks = function() return layout.build(layout_params.big(7)) end,
  repeated_split = function()
    local params = params_with({ tiers = { "normal", "normal", "uncommon", "rare" } })
    params.modules.productivity_module = { name = "productivity-module", quality = "normal" }
    params.modules.split = { 1, 1, 2 }
    return layout.build(params)
  end,
  plain_terminal_feed = function()
    return layout.build(params_with({
      terminal_feed = { name = "wooden-chest", quality = "uncommon" },
    }))
  end,
  no_tap = function()
    return layout.build(params_with({
      tiers = { "normal", "uncommon", "rare", "epic", "legendary" }, overflow_tap = false,
    }))
  end,
  no_product_buffer = function()
    local params = params_with()
    params.product_buffer = nil
    return layout.build(params)
  end,
  decorated_wire = function()
    return decorated(nil, { minimums = { normal = 50, uncommon = 25 }, maximum = 100 })
  end,
  decorated_network_paused = function()
    return decorated(nil, { minimums = { normal = 50 }, maximum = 100, network = true,
      paused = true })
  end,
  decorated_reserves_only = function()
    return decorated(nil, { minimums = { uncommon = 25 } })
  end,
  decorated_relay = function()
    return decorated({ column_gaps = { 0, 4, 4 } }, { maximum = 100, reach = 6 })
  end,
  decorated_two_stacks = function()
    local params = layout_params.big(7)
    params.circuit = circuit_stack.params(true)
    local built = layout.build(params)
    built.unlinked = circuits.decorate(built.entities, {
      tiers = params.tiers, minimums = { normal = 10 }, maximum = 100, hand = 12,
      product = "big-product", reach = 9, feed_reach = 9,
    })
    return built
  end,
}

-- Captured from the pristine tree on 2026-11-27. Empty means "not captured yet": the test then
-- fails naming the digest to paste here.
local PINNED = {
  beacons_fluid = "15816:258327243:618505206",
  decorated_network_paused = "14862:1601885153:123925345",
  decorated_relay = "16432:1749163475:434484267",
  decorated_reserves_only = "10681:1200791131:546398178",
  decorated_two_stacks = "18127:1462923510:195131933",
  decorated_wire = "15188:1998962700:253713334",
  flat_recycler_stack = "9541:1998302313:934313838",
  fluid = "13028:1803649051:116142224",
  no_product_buffer = "9626:1293473902:179215241",
  no_tap = "14589:334353714:20520452",
  plain_terminal_feed = "9668:1070946473:147086258",
  repeated_split = "12443:238188606:357657617",
  salvager = "10165:2125244275:2071302",
  stack_capped = "10101:2099913011:138680608",
  stack_reserves = "9861:734892487:344584496",
  two_stacks = "12321:1302999368:408617628",
  uneven_gaps = "10206:1631472195:508135311",
  vanilla = "9776:1675048085:639212562",
}

describe("the belt ring is frozen", function()
  local names = {}
  for name in pairs(CASES) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    test(name, function()
      local digest = fingerprint.of(CASES[name]())
      assert(PINNED[name] == digest,
        "belt golden '" .. name .. "' is " .. digest .. ", pinned " .. tostring(PINNED[name]))
    end)
  end
end)
