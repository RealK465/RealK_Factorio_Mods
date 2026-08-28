-- circuits.decorate as pure data: hand-built params through layout.build, no prototypes, no
-- force. Runs identically inside the game and on the host interpreter, like layout_spec --
-- the decorator touches nothing but plain fields, which is the design being pinned.
--
-- The wiring assertions are connectivity, not wire_to values -- the pole suite's own stated
-- discipline: a rewired tree that still connects everything is a valid answer, and pinning
-- edges would fail it for no defect.

local layout = require("scripts.layout")
local circuits = require("scripts.circuits")

local params_with = require("tests.support.layout_params").vanilla
local deep_equal = require("tests.support.deep_equal")
local component = require("tests.support.component")

-- The fixture's numbers: distinct reserves per lower tier, so a condition naming the wrong
-- tier cannot accidentally carry the right constant, and a cap for the rare target.
local MINIMUMS = { normal = 50, uncommon = 25 }
local MAXIMUM = 100

-- opts: reach, minimums, maximum -- maximum false stands in for "no cap" (the planner
-- passes nil there, which an opts table cannot carry past the fixture default).
local function decorated(overrides, opts)
  opts = opts or {}
  local maximum = opts.maximum
  if maximum == nil then maximum = MAXIMUM end
  if maximum == false then maximum = nil end
  local built = layout.build(params_with(overrides))
  local unlinked = circuits.decorate(built.entities, {
    tiers = { "normal", "uncommon", "rare" },
    minimums = opts.minimums or MINIMUMS,
    maximum = maximum,
    product = "iron-gear-wheel",
    reach = opts.reach or 9,
  })
  return built, unlinked
end

local function by_role(built, role)
  local out = {}
  for index, e in pairs(built.entities) do
    if e.circuit_role == role then out[#out + 1] = { index = index, entity = e } end
  end
  return out
end

-- Every index reachable over circuit_wire_to, walked undirected by the shared support
-- walker -- the links are parent pointers, but a wire joins both ends.
local function component_of(entities, start)
  return component(entities, start, "circuit_wire_to")
end

describe("circuits.decorate conditions", function()
  test("every machine and recycler stops at the one cap, counted at the target quality", function()
    local built = decorated()
    local gated = {}
    for _, role in pairs({ "machine", "recycler" }) do
      for _, entry in pairs(by_role(built, role)) do gated[#gated + 1] = entry end
    end
    assert(#gated == 5, "gated machines+recyclers " .. #gated)
    for _, g in pairs(gated) do
      local cb = g.entity.control_behavior
      assert(cb and cb.circuit_enabled == true, g.entity.circuit_role .. " tier "
        .. g.entity.circuit_tier .. " carries no enabled gate")
      local condition = cb.circuit_condition
      assert(condition.comparator == "<", "comparator " .. tostring(condition.comparator))
      assert(condition.first_signal.name == "iron-gear-wheel"
        and condition.first_signal.type == "item", "signal names the wrong thing")
      assert(condition.first_signal.quality == "rare",
        g.entity.circuit_role .. " gates on " .. condition.first_signal.quality
        .. ", not the target")
      assert(condition.constant == MAXIMUM,
        g.entity.circuit_role .. " constant " .. condition.constant)
    end
  end)

  test("each reserve inserter holds its own tier's floor, strictly above", function()
    local built = decorated()
    local reserves = by_role(built, "reserve")
    assert(#reserves == 2, "reserve inserters " .. #reserves)
    for _, r in pairs(reserves) do
      local tier = ({ "normal", "uncommon" })[r.entity.circuit_tier]
      local condition = r.entity.control_behavior.circuit_condition
      assert(condition.comparator == ">",
        "reserve tier " .. r.entity.circuit_tier .. " comparator " .. condition.comparator)
      assert(condition.first_signal.quality == tier,
        "reserve tier " .. r.entity.circuit_tier .. " counts " .. condition.first_signal.quality)
      assert(condition.constant == MINIMUMS[tier],
        "reserve tier " .. r.entity.circuit_tier .. " constant " .. condition.constant)
    end
  end)

  test("a floor raises its census chest's request, so trash-unrequested cannot skim it", function()
    -- The fixture's buffer request is 50; the floor must sit inside the request or bots
    -- with trash-unrequested would hold the count below it forever.
    local built = decorated()
    for _, c in pairs(by_role(built, "census")) do
      local tier = ({ "normal", "uncommon" })[c.entity.circuit_tier]
      if tier then
        assert(c.entity.requests[1].count == 50 + MINIMUMS[tier],
          tier .. " census requests " .. c.entity.requests[1].count)
      else
        assert(c.entity.requests == nil, "the output chest grew a request")
      end
    end
  end)

  test("an absent minimum leaves that tier's inserter ungated and unwired", function()
    -- The planner normalises "zero means off" into absence before decorate runs; the
    -- zero-through-choices path is pinned at the planner boundary in plan_spec.
    local built, unlinked = decorated(nil, { minimums = { uncommon = 25 } })
    assert(unlinked == 0, "unlinked " .. unlinked)
    for _, r in pairs(by_role(built, "reserve")) do
      if r.entity.circuit_tier == 1 then
        assert(r.entity.control_behavior == nil, "an absent reserve still grew a gate")
        assert(r.entity.circuit_wire_to == nil, "an absent reserve was still wired")
      else
        assert(r.entity.control_behavior, "the set reserve lost its gate")
      end
    end
    -- And only the floored tier's request grows.
    for _, c in pairs(by_role(built, "census")) do
      if c.entity.circuit_tier == 1 then
        assert(c.entity.requests[1].count == 50, "an absent floor still raised the request")
      elseif c.entity.circuit_tier == 2 then
        assert(c.entity.requests[1].count == 75, "the set floor did not raise the request")
      end
    end
  end)

  test("census chests, the ring and everything untagged stay ungated", function()
    local built = decorated()
    for _, e in pairs(built.entities) do
      if e.circuit_role ~= "machine" and e.circuit_role ~= "recycler"
        and e.circuit_role ~= "reserve" then
        assert(e.control_behavior == nil,
          (e.circuit_role or e.name) .. " grew a control_behavior it must not have")
      end
    end
  end)
end)

describe("circuits.decorate wiring", function()
  test("direct mode: one component spans the gated set and the censuses; the ring stays unwired", function()
    local built, unlinked = decorated()
    assert(unlinked == 0, "unlinked " .. unlinked .. " on a vanilla-sized plan")

    local expected = {}
    local start
    for index, e in pairs(built.entities) do
      if e.circuit_role == "machine" or e.circuit_role == "recycler"
        or e.circuit_role == "census" or e.circuit_role == "reserve" then
        expected[index] = true
        start = start or index
      end
    end
    local reached = component_of(built.entities, start)
    for index in pairs(expected) do
      assert(reached[index], built.entities[index].circuit_role .. " tier "
        .. tostring(built.entities[index].circuit_tier) .. " is off the network")
    end
    for index in pairs(reached) do
      assert(expected[index], built.entities[index].name .. " joined the network uninvited")
    end

    for _, belt in pairs(by_role(built, "ring")) do
      assert(belt.entity.circuit_wire_to == nil,
        "a ring belt was wired although every direct hop fits")
    end
  end)

  test("a hop past reach relays along the top ring, and the network still connects", function()
    -- Utility columns of 4 stretch the machine-row hops to 7; reach 6 forces the relay while
    -- every cluster link (about 3.6 at most) and every belt tap (about 5) still fits.
    local built, unlinked = decorated({ column_gaps = { 0, 4, 4 } }, { reach = 6 })
    assert(unlinked == 0, "unlinked " .. unlinked .. " -- the relay must cover what direct cannot")

    local wired_ring = 0
    for _, belt in pairs(by_role(built, "ring")) do
      if belt.entity.circuit_wire_to then wired_ring = wired_ring + 1 end
    end
    assert(wired_ring > 0, "relay mode wired no ring belt at all")

    local machines = by_role(built, "machine")
    local reached = component_of(built.entities, machines[1].index)
    for _, m in pairs(machines) do
      assert(reached[m.index], "machine tier " .. m.entity.circuit_tier .. " is off the network")
    end
    for _, c in pairs(by_role(built, "census")) do
      assert(reached[c.index], "census tier " .. c.entity.circuit_tier .. " is off the network")
    end
    for _, r in pairs(by_role(built, "reserve")) do
      assert(reached[r.index], "reserve tier " .. r.entity.circuit_tier .. " is off the network")
    end
  end)

  test("a reach too short for anything counts unlinked instead of erroring", function()
    -- At reach 1 the half-tile safety margin leaves 0.5 usable, under even the one-tile
    -- reserve hops: every link fails -- two reserves, the census, recycler and terminal
    -- hops, and the three belt taps -- but the plan still decorates, the conditions still
    -- land, and the count says what the wire could not do.
    local built, unlinked = decorated(nil, { reach = 1 })
    assert(unlinked == 10, "unlinked " .. unlinked .. ", expected all 10 out-of-reach links")
    for _, m in pairs(by_role(built, "machine")) do
      assert(m.entity.control_behavior, "an unwired machine lost its condition too")
    end
  end)

  test("no cap: only the reserves are gated and wired", function()
    local built, unlinked = decorated(nil, { maximum = false })
    assert(unlinked == 0, "unlinked " .. unlinked)
    for _, e in pairs(built.entities) do
      if e.circuit_role == "machine" or e.circuit_role == "recycler" then
        assert(e.control_behavior == nil and e.circuit_wire_to == nil,
          e.circuit_role .. " gated or wired under a zero cap")
      end
      -- Each reserve still reads its own chest: a two-entity island per tier.
      if e.circuit_role == "reserve" then
        assert(e.control_behavior and e.circuit_wire_to,
          "a reserve lost its floor under a zero cap")
      end
    end
  end)

  test("same input, same decoration", function()
    local a = decorated()
    local b = decorated()
    assert(deep_equal(a.entities, b.entities), "two identical decorations differ")
  end)
end)

describe("circuits.decorate repeated tiers", function()
  -- The columns feature hands decorate the same expanded array layout built from: one
  -- entry per physical column, repeats allowed. Every column keys its own map entries
  -- through its unique circuit_tier; the floors are per QUALITY, so repeats of a tier
  -- share the constant while each enforces it on its own chest.
  local repeated = { "normal", "normal", "normal", "uncommon", "rare" }

  local function decorated_repeated()
    local built = layout.build(params_with({ tiers = repeated }))
    local unlinked = circuits.decorate(built.entities, {
      tiers = repeated,
      minimums = MINIMUMS,
      maximum = MAXIMUM,
      product = "iron-gear-wheel",
      reach = 9,
    })
    return built, unlinked
  end

  test("every column of a repeated tier keeps its own gated, wired reserve", function()
    local built, unlinked = decorated_repeated()
    assert(unlinked == 0, "unlinked " .. unlinked)
    local reserves = by_role(built, "reserve")
    assert(#reserves == 4, "reserve inserters " .. #reserves)
    local at_normal = 0
    for _, r in pairs(reserves) do
      local condition = r.entity.control_behavior.circuit_condition
      local tier = repeated[r.entity.circuit_tier]
      assert(condition.first_signal.quality == tier,
        "reserve tier " .. r.entity.circuit_tier .. " counts " .. condition.first_signal.quality)
      assert(condition.constant == MINIMUMS[tier],
        "reserve tier " .. r.entity.circuit_tier .. " constant " .. condition.constant)
      assert(r.entity.circuit_wire_to, "a repeated column's reserve went unwired")
      if tier == "normal" then at_normal = at_normal + 1 end
    end
    assert(at_normal == 3, "normal-tier reserves " .. at_normal .. ", expected one per column")
  end)

  test("the cap gates every column's machine and recycler, and one component spans them", function()
    local built = decorated_repeated()
    local gated = 0
    local start
    for index, e in pairs(built.entities) do
      if e.circuit_role == "machine" or e.circuit_role == "recycler" then
        gated = gated + 1
        start = start or index
        assert(e.control_behavior and e.control_behavior.circuit_condition.constant == MAXIMUM,
          e.circuit_role .. " tier " .. tostring(e.circuit_tier) .. " missed the cap")
      end
    end
    assert(gated == 9, "gated machines+recyclers " .. gated)
    local reached = component_of(built.entities, start)
    for index, e in pairs(built.entities) do
      if e.circuit_role == "machine" or e.circuit_role == "recycler"
        or e.circuit_role == "census" or e.circuit_role == "reserve" then
        assert(reached[index], tostring(e.circuit_role) .. " tier "
          .. tostring(e.circuit_tier) .. " is off the network")
      end
    end
  end)
end)
