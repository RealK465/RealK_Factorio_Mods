-- circuits.decorate as pure data: hand-built params through layout.build, no prototypes, no
-- force. Runs identically inside the game and on the host interpreter, like layout_spec --
-- the decorator touches nothing but plain fields, which is the design being pinned.
--
-- The wiring assertions are connectivity, not wire_to values -- the pole suite's own stated
-- discipline: a rewired tree that still connects everything is a valid answer, and pinning
-- edges would fail it for no defect. The one exception is the circuit stack's chain, whose
-- one-tile hops ARE the design (a wide machine must never put the combinator out of reach).

local layout = require("scripts.layout")
local circuits = require("scripts.circuits")

local params_with = require("tests.support.layout_params").vanilla
local deep_equal = require("tests.support.deep_equal")
local component = require("tests.support.component")
local STACK_ROLES = require("tests.support.circuit_stack").ROLES

-- The fixture's numbers: distinct reserves per lower tier, so a condition naming the wrong
-- tier cannot accidentally carry the right constant, and a cap for the rare target.
local MINIMUMS = { normal = 50, uncommon = 25 }
local MAXIMUM = 100
local TIERS = { "normal", "uncommon", "rare" }

local CAP = { type = "virtual", name = "signal-C", quality = "rare" }

-- The stack the layout stands, derived the way planner.plan derives layout_params.circuit
-- from its circuit table: a combinator whenever anything is gated, the lamps and the panel
-- only under a cap, nothing at all when every threshold is off.
local function stack_for(minimums, maximum)
  if maximum == nil and next(minimums) == nil then return nil end
  return {
    capped = maximum ~= nil,
    combinator = "constant-combinator", lamp = "small-lamp", panel = "display-panel",
  }
end

-- opts: reach, minimums, maximum, paused, tiers -- maximum false stands in for "no cap"
-- (the planner passes nil there, which an opts table cannot carry past the fixture default).
local function decorated(overrides, opts)
  opts = opts or {}
  local maximum = opts.maximum
  if maximum == nil then maximum = MAXIMUM end
  if maximum == false then maximum = nil end
  local minimums = opts.minimums or MINIMUMS
  local params = {}
  for key, value in pairs(overrides or {}) do params[key] = value end
  params.circuit = stack_for(minimums, maximum)
  local built = layout.build(params_with(params))
  local unlinked = circuits.decorate(built.entities, {
    tiers = opts.tiers or TIERS,
    minimums = minimums,
    maximum = maximum,
    paused = opts.paused,
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

local function one(built, role)
  local found = by_role(built, role)
  assert(#found == 1, role .. " count " .. #found)
  return found[1]
end

local function rows_of(built)
  return one(built, "limits").entity.control_behavior.sections.sections[1].filters
end

local function same_signal(a, b)
  return a and b and a.type == b.type and a.name == b.name and a.quality == b.quality
end

-- Every index reachable over circuit_wire_to, walked undirected by the shared support
-- walker -- the links are parent pointers, but a wire joins both ends.
local function component_of(entities, start)
  return component(entities, start, "circuit_wire_to")
end

describe("circuits.decorate conditions", function()
  test("every machine and recycler stops at the one cap, read off the combinator at the target quality", function()
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
      -- The number lives on the combinator now: nothing baked into the condition itself.
      assert(condition.constant == nil, g.entity.circuit_role .. " still carries a constant")
      assert(same_signal(condition.second_signal, CAP),
        g.entity.circuit_role .. " compares against the wrong signal")
    end
  end)

  test("each reserve inserter holds its own tier's floor, strictly above", function()
    local built = decorated()
    local reserves = by_role(built, "reserve")
    assert(#reserves == 2, "reserve inserters " .. #reserves)
    for _, r in pairs(reserves) do
      local tier = TIERS[r.entity.circuit_tier]
      local condition = r.entity.control_behavior.circuit_condition
      assert(condition.comparator == ">",
        "reserve tier " .. r.entity.circuit_tier .. " comparator " .. condition.comparator)
      assert(condition.first_signal.quality == tier,
        "reserve tier " .. r.entity.circuit_tier .. " counts " .. condition.first_signal.quality)
      assert(condition.constant == nil, "a reserve still carries a constant")
      assert(same_signal(condition.second_signal,
          { type = "virtual", name = "signal-M", quality = tier }),
        "reserve tier " .. r.entity.circuit_tier .. " compares against the wrong signal")
    end
  end)

  test("the combinator carries one row per threshold, minimums first, then the cap", function()
    local built = decorated()
    local rows = rows_of(built)
    assert(#rows == 3, "rows " .. #rows)
    local expected = {
      { name = "signal-M", quality = "normal", count = 50 },
      { name = "signal-M", quality = "uncommon", count = 25 },
      { name = "signal-C", quality = "rare", count = 100 },
    }
    for i, want in ipairs(expected) do
      local row = rows[i]
      assert(row.index == i, "row " .. i .. " indexed " .. tostring(row.index))
      assert(row.type == "virtual" and row.comparator == "=",
        "row " .. i .. " is not a plain virtual signal row")
      assert(row.name == want.name and row.quality == want.quality and row.count == want.count,
        "row " .. i .. " reads " .. row.name .. "@" .. row.quality .. " = " .. row.count)
    end
    local combinator = one(built, "limits").entity
    assert(combinator.control_behavior.is_on == nil, "an unpaused combinator wrote is_on")
    assert(type(combinator.player_description) == "string"
      and #combinator.player_description > 0, "the combinator carries no description")
  end)

  test("paused ships the combinator switched off", function()
    local built = decorated(nil, { paused = true })
    assert(one(built, "limits").entity.control_behavior.is_on == false,
      "paused did not switch the combinator off")
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

  test("an absent minimum leaves that tier's inserter ungated and unwired, and writes no row", function()
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
    local rows = rows_of(built)
    assert(#rows == 2 and rows[1].quality == "uncommon" and rows[2].name == "signal-C",
      "the combinator wrote a row for the absent tier")
  end)

  test("the lamps and the panel read the cap: green done, blue running, paused asked first", function()
    local built = decorated()
    local done = one(built, "lamp_done").entity
    assert(done.color and done.color.g == 1 and done.color.r == 0, "the done lamp is not green")
    assert(done.always_on == true, "the done lamp would only show at night")
    assert(done.control_behavior.circuit_enabled == true
      and done.control_behavior.circuit_condition.comparator == ">="
      and same_signal(done.control_behavior.circuit_condition.second_signal, CAP),
      "the done lamp does not light at the cap")

    local running = one(built, "lamp_running").entity
    assert(running.color and running.color.b == 1 and running.color.g < 1,
      "the running lamp is not blue")
    assert(running.always_on == true, "the running lamp would only show at night")
    assert(running.control_behavior.circuit_condition.comparator == "<"
      and same_signal(running.control_behavior.circuit_condition.second_signal, CAP),
      "the running lamp does not light below the cap")

    local panel = one(built, "panel").entity
    assert(panel.show_in_chart == true and panel.always_show == true,
      "the panel is not shown on the map and in the world")
    assert(same_signal(panel.icon, { type = "item", name = "iron-gear-wheel", quality = "rare" }),
      "the panel's own icon is not the product at the target")
    assert(panel.text == "Running", "the panel's own words are " .. tostring(panel.text))
    local rows = panel.control_behavior.parameters
    assert(#rows == 2, "panel rows " .. #rows)
    assert(same_signal(rows[1].condition.first_signal, CAP) and rows[1].condition.comparator == "="
      and rows[1].condition.constant == 0 and rows[1].icon.name == "signal-deny"
      and rows[1].text == "Paused", "the first panel row is not the paused test")
    assert(rows[2].condition.comparator == ">=" and rows[2].condition.first_signal.name == "iron-gear-wheel"
      and same_signal(rows[2].condition.second_signal, CAP) and rows[2].icon.name == "signal-check"
      and rows[2].text == "Done", "the second panel row is not the done test")
  end)

  test("no cap: the combinator stands alone, carrying the minimums; machines stay ungated", function()
    local built = decorated(nil, { maximum = false })
    for _, role in pairs({ "lamp_done", "lamp_running", "panel" }) do
      assert(#by_role(built, role) == 0, "an uncapped plan stood a " .. role)
    end
    local rows = rows_of(built)
    assert(#rows == 2 and rows[1].name == "signal-M" and rows[2].name == "signal-M",
      "an uncapped combinator wrote a cap row")
    for _, e in pairs(built.entities) do
      if e.circuit_role == "machine" or e.circuit_role == "recycler" then
        assert(e.control_behavior == nil, e.circuit_role .. " gated under a zero cap")
      end
      if e.circuit_role == "reserve" then
        assert(e.control_behavior, "a reserve lost its floor under a zero cap")
      end
    end
  end)

  test("census chests, the ring and everything untagged stay ungated", function()
    local built = decorated()
    for _, e in pairs(built.entities) do
      if e.circuit_role ~= "machine" and e.circuit_role ~= "recycler"
        and e.circuit_role ~= "reserve" and not STACK_ROLES[e.circuit_role] then
        assert(e.control_behavior == nil,
          (e.circuit_role or e.name) .. " grew a control_behavior it must not have")
      end
    end
  end)
end)

describe("circuits.decorate wiring", function()
  test("direct mode: one component spans the gated set, the censuses and the stack; the ring stays unwired", function()
    local built, unlinked = decorated()
    assert(unlinked == 0, "unlinked " .. unlinked .. " on a vanilla-sized plan")

    local expected = {}
    local start
    for index, e in pairs(built.entities) do
      if e.circuit_role == "machine" or e.circuit_role == "recycler"
        or e.circuit_role == "census" or e.circuit_role == "reserve"
        or STACK_ROLES[e.circuit_role] then
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

  test("the stack chains off the terminal machine a tile a hop", function()
    -- Pinned as edges, unlike the rest of the tree: the one-tile hops are the point, so a
    -- modded machine of any width keeps the combinator in reach.
    local built = decorated()
    local terminal
    for _, m in pairs(by_role(built, "machine")) do
      if m.entity.circuit_tier == #TIERS then terminal = m.index end
    end
    local chain = { "lamp_done", "lamp_running", "panel", "limits" }
    local parent = terminal
    for _, role in ipairs(chain) do
      local entry = one(built, role)
      assert(entry.entity.circuit_wire_to == parent,
        role .. " links to " .. tostring(entry.entity.circuit_wire_to) .. ", not its neighbour")
      if parent ~= terminal then
        local above = built.entities[parent]
        assert(entry.entity.dx == above.dx and entry.entity.dy == above.dy + 1,
          role .. " does not stand directly under its neighbour")
      end
      parent = entry.index
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
    assert(reached[one(built, "limits").index], "the combinator is off the relayed network")
  end)

  test("a reach too short for anything counts unlinked instead of erroring", function()
    -- At reach 1 the half-tile safety margin leaves 0.5 usable, under even the one-tile
    -- reserve hops: every link fails -- two reserves, the census, recycler and terminal
    -- hops, the three belt taps and the stack's four -- but the plan still decorates, the
    -- conditions still land, and the count says what the wire could not do.
    local built, unlinked = decorated(nil, { reach = 1 })
    assert(unlinked == 14, "unlinked " .. unlinked .. ", expected all 14 out-of-reach links")
    for _, m in pairs(by_role(built, "machine")) do
      assert(m.entity.control_behavior, "an unwired machine lost its condition too")
    end
  end)

  test("no cap: the reserves are gated, and one network still carries the combinator to them", function()
    -- The reserves used to be two-entity islands over their own chests; a shared combinator
    -- needs the spine, so the machines carry the wire ungated, as the relay belts do.
    local built, unlinked = decorated(nil, { maximum = false })
    assert(unlinked == 0, "unlinked " .. unlinked)
    local reached = component_of(built.entities, one(built, "limits").index)
    for _, r in pairs(by_role(built, "reserve")) do
      assert(reached[r.index], "reserve tier " .. r.entity.circuit_tier .. " cannot hear the combinator")
    end
    for _, e in pairs(built.entities) do
      if e.circuit_role == "machine" or e.circuit_role == "recycler" then
        assert(e.control_behavior == nil, e.circuit_role .. " gated under a zero cap")
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
  -- share the signal while each enforces it on its own chest.
  local repeated = { "normal", "normal", "normal", "uncommon", "rare" }

  local function decorated_repeated()
    return decorated({ tiers = repeated }, { tiers = repeated })
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
      assert(condition.second_signal.name == "signal-M" and condition.second_signal.quality == tier,
        "reserve tier " .. r.entity.circuit_tier .. " reads the wrong signal")
      assert(r.entity.circuit_wire_to, "a repeated column's reserve went unwired")
      if tier == "normal" then at_normal = at_normal + 1 end
    end
    assert(at_normal == 3, "normal-tier reserves " .. at_normal .. ", expected one per column")
  end)

  test("a repeated quality is written once: the combinator still holds one row per threshold", function()
    local built = decorated_repeated()
    local rows = rows_of(built)
    assert(#rows == 3, "rows " .. #rows)
    assert(rows[1].quality == "normal" and rows[2].quality == "uncommon"
      and rows[3].name == "signal-C", "the rows repeat or reorder with the columns")
  end)

  test("the cap gates every column's machine and recycler, and one component spans them", function()
    local built = decorated_repeated()
    local gated = 0
    local start
    for index, e in pairs(built.entities) do
      if e.circuit_role == "machine" or e.circuit_role == "recycler" then
        gated = gated + 1
        start = start or index
        assert(e.control_behavior
          and same_signal(e.control_behavior.circuit_condition.second_signal, CAP),
          e.circuit_role .. " tier " .. tostring(e.circuit_tier) .. " missed the cap")
      end
    end
    assert(gated == 9, "gated machines+recyclers " .. gated)
    local reached = component_of(built.entities, start)
    for index, e in pairs(built.entities) do
      if e.circuit_role == "machine" or e.circuit_role == "recycler"
        or e.circuit_role == "census" or e.circuit_role == "reserve"
        or STACK_ROLES[e.circuit_role] then
        assert(reached[index], tostring(e.circuit_role) .. " tier "
          .. tostring(e.circuit_tier) .. " is off the network")
      end
    end
  end)
end)
