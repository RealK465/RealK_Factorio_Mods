-- poles.plan as pure geometry: hand-built consumers, hand-built pole stats, no prototypes.
-- Runs both in-game and on the host runner. The measured in-game scenarios live in
-- tests/plan_spec.lua where the planner supplies real margins; this file pins the
-- algorithm's own contracts: greedy determinism, the utility-column preference, spanning
-- wires, collisions.
--
-- The honesty rule (a covered consumer on an unwired island counts as unpowered) is pinned
-- twice: here, with a hand-built wall that leaves the bridge pass no candidate, and by the
-- in-game big-pole scenario where a real planner-built plan reaches the same state.

local layout = require("scripts.layout")
local poles = require("scripts.poles")
-- Top level, never inside a test body: in-game, require only works while control.lua parses.
local deep_equal = require("tests.support.deep_equal")

-- A 1x1 pole shaped like vanilla's small pole.
local SMALL = { name = "test-pole", quality = "normal", width = 1, height = 1,
  supply_distance = 2.5, wire_distance = 7.5 }

local MARGINS = { machine = 0.3 }

local function machine_at(dx, dy)
  return { name = "machine", dx = dx, dy = dy, w = 3, h = 3 }
end

local function wire_count(result)
  local n = 0
  for _, p in pairs(result.entities) do
    if p.wire_to then n = n + 1 end
  end
  return n
end

describe("poles.plan covering", function()
  test("one consumer, one pole, placed at the first covering position in scan order", function()
    local built = { entities = { machine_at(1, 1) }, width = 5, height = 5 }
    local result = poles.plan(built, SMALL, MARGINS)
    assert(#result.entities == 1, "pole count " .. #result.entities)
    -- Row-major first-found-wins is the determinism contract (poles.lua:102-103): with every
    -- candidate covering at most this one machine, (0,0) is the first and must win.
    assert(result.entities[1].dx == 0 and result.entities[1].dy == 0,
      "pole at " .. result.entities[1].dx .. "," .. result.entities[1].dy .. ", expected 0,0")
    assert(result.unpowered == 0, "unpowered " .. result.unpowered)
    assert(result.entities[1].wire_to == nil, "single pole grew a wire")
  end)

  test("a utility column pulls the pole off the scan-order pick", function()
    -- Same single consumer, but the plan declares a dedicated column at x=4: the pole must
    -- stand there, not at the (0,0) the raw scan order would choose -- the free-tile search
    -- is the fallback, never the first answer.
    local built = {
      entities = { machine_at(1, 1) }, width = 6, height = 5,
      utility_columns = { { x = 4, width = 1 } },
    }
    local result = poles.plan(built, SMALL, MARGINS)
    assert(#result.entities == 1, "pole count " .. #result.entities)
    assert(result.entities[1].dx == 4,
      "pole at x=" .. result.entities[1].dx .. ", expected the utility column at 4")
    assert(result.unpowered == 0, "unpowered " .. result.unpowered)
  end)

  test("a column too far to cover falls back to the free tiles", function()
    -- The column exists but nothing in it reaches the machine: the honest fallback places
    -- from the full candidate set rather than reporting a shortfall it could have avoided.
    local built = {
      entities = { machine_at(1, 1) }, width = 12, height = 5,
      utility_columns = { { x = 11, width = 1 } },
    }
    local result = poles.plan(built, SMALL, MARGINS)
    assert(result.unpowered == 0, "unpowered " .. result.unpowered .. " -- fallback not taken")
    assert(result.entities[1].dx < 11, "pole stayed in the useless column")
  end)

  test("two spread consumers: two poles, one spanning wire", function()
    local built = { entities = { machine_at(1, 1), machine_at(9, 1) }, width = 13, height = 5 }
    local result = poles.plan(built, SMALL, MARGINS)
    assert(#result.entities == 2, "pole count " .. #result.entities)
    assert(result.unpowered == 0, "unpowered " .. result.unpowered)
    -- A spanning tree has exactly n-1 edges; wire_to indexes into the returned array.
    assert(wire_count(result) == 1, "wire count " .. wire_count(result))
    for _, p in pairs(result.entities) do
      if p.wire_to then
        assert(result.entities[p.wire_to], "wire_to points at nothing")
      end
    end
  end)
end)

describe("poles.plan over a real plan", function()
  local vanilla_params = require("tests.support.layout_params").vanilla

  -- Vanilla medium pole numbers, margins shaped like the planner's per-prototype rule.
  local MEDIUM = { name = "medium-electric-pole", quality = "normal", width = 1, height = 1,
    supply_distance = 3.5, wire_distance = 9 }
  local PLAN_MARGINS = { ["assembling-machine-2"] = 0.3, ["recycler"] = 0.3, ["fast-inserter"] = 0.35 }

  test("poles land on free tiles only, and everything gets power", function()
    local built = layout.build(vanilla_params())
    local result = poles.plan(built, MEDIUM, PLAN_MARGINS)

    assert(result.unpowered == 0, "unpowered " .. result.unpowered)

    local occ = {}
    for _, e in pairs(built.entities) do
      for x = e.dx, e.dx + e.w - 1 do
        for y = e.dy, e.dy + e.h - 1 do occ[x .. "," .. y] = e.name end
      end
    end
    for _, p in pairs(result.entities) do
      assert(p.dx >= 0 and p.dy >= 0 and p.dx + p.w <= built.width and p.dy + p.h <= built.height,
        "pole out of bounds at " .. p.dx .. "," .. p.dy)
      local key = p.dx .. "," .. p.dy
      assert(not occ[key], "pole stands on " .. tostring(occ[key]) .. " at " .. key)
    end

    -- Everything wired into one network: a spanning tree over n poles carries n-1 wires.
    assert(wire_count(result) == #result.entities - 1,
      "wires " .. wire_count(result) .. " for " .. #result.entities .. " poles")
  end)

  test("the same plan grows the same poles, twice", function()
    -- The purity contract stated at the top of poles.lua, held to structurally: every field of
    -- every pole, wires included, must come out identical on a second solve of the same plan.
    local function solve()
      return poles.plan(layout.build(vanilla_params()), MEDIUM, PLAN_MARGINS)
    end
    assert(deep_equal(solve(), solve()), "two identical solves disagreed")
  end)
end)

describe("poles.plan connectivity", function()
  -- Every wire_to edge as an undirected adjacency, walked from the first pole: how many of
  -- the placed poles one component actually reaches.
  local function reachable_from_first(result)
    local adjacent = {}
    for i, p in pairs(result.entities) do
      if p.wire_to then
        adjacent[i] = adjacent[i] or {}
        adjacent[p.wire_to] = adjacent[p.wire_to] or {}
        adjacent[i][p.wire_to] = true
        adjacent[p.wire_to][i] = true
      end
    end
    local visited, stack, count = { [1] = true }, { 1 }, 1
    while #stack > 0 do
      local i = stack[#stack]
      stack[#stack] = nil
      for j in pairs(adjacent[i] or {}) do
        if not visited[j] then
          visited[j] = true
          count = count + 1
          stack[#stack + 1] = j
        end
      end
    end
    return count
  end

  test("a bridge pole joins two islands the cover pass left apart", function()
    -- Two machines 14 tiles apart: the cover pass stands a pole at each, out of wire reach of
    -- one another, and the bridge pass must add a third in the middle rather than leave two
    -- covered islands. One network, n-1 spanning wires, nothing unpowered.
    local built = { entities = { machine_at(1, 1), machine_at(15, 1) }, width = 19, height = 5 }
    local result = poles.plan(built, SMALL, MARGINS)
    assert(#result.entities == 3, "pole count " .. #result.entities .. ", expected cover pair plus bridge")
    assert(result.unpowered == 0, "unpowered " .. result.unpowered)
    assert(wire_count(result) == 2, "spanning wires " .. wire_count(result))
    assert(reachable_from_first(result) == 3, "the wires do not join all three poles")
    local bridged = false
    for _, p in pairs(result.entities) do
      if p.dx > 3 and p.dx < 13 then bridged = true end
    end
    assert(bridged, "no pole stands between the two islands")
  end)

  test("an island no bridge can reach is reported unpowered, never claimed", function()
    -- The honesty rule, reached by construction: a full-height wall between the two machines
    -- leaves the bridge pass no candidate, so the far machine is covered by its own pole yet
    -- out of the main network -- and must be counted dark rather than credited.
    local built = {
      entities = {
        machine_at(0, 0), machine_at(20, 0),
        { name = "wall", dx = 3, dy = 0, w = 17, h = 5 },
      },
      width = 23, height = 5,
    }
    local result = poles.plan(built, SMALL, MARGINS)
    assert(#result.entities == 2, "pole count " .. #result.entities .. ", expected one per island")
    assert(result.unpowered == 1,
      "unpowered " .. result.unpowered .. " -- a covered but unwired island must count as dark")
    assert(wire_count(result) == 0, "a wire crossed the unbridgeable gap")
  end)

  test("a 2x2 pole keeps its footprint clear of the plan and the edges", function()
    -- Everything above runs 1x1 poles; the footprint arithmetic (fits, overlap, bounds) only
    -- bites at width 2 -- the substation and big-pole shapes the in-game scenarios plan with.
    local BIG = { name = "big-pole", quality = "normal", width = 2, height = 2,
      supply_distance = 2, wire_distance = 9 }
    local built = { entities = { machine_at(2, 2) }, width = 8, height = 8 }
    local result = poles.plan(built, BIG, MARGINS)
    assert(#result.entities == 1, "pole count " .. #result.entities)
    assert(result.unpowered == 0, "unpowered " .. result.unpowered)
    local p = result.entities[1]
    assert(p.w == 2 and p.h == 2, "the pole lost its footprint: " .. p.w .. "x" .. p.h)
    assert(p.dx >= 0 and p.dy >= 0 and p.dx + p.w <= 8 and p.dy + p.h <= 8, "pole out of bounds")
    assert(p.dx + p.w <= 2 or p.dx >= 5 or p.dy + p.h <= 2 or p.dy >= 5,
      "the pole overlaps the machine at " .. p.dx .. "," .. p.dy)
  end)
end)
