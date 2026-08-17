-- poles.plan as pure geometry: hand-built consumers, hand-built pole stats, no prototypes.
-- Runs both in-game and on the host runner. The measured in-game scenarios live in
-- tests/plan_spec.lua where the planner supplies real margins; this file pins the
-- algorithm's own contracts: greedy determinism, the utility-column preference, spanning
-- wires, collisions.
--
-- The honesty rule (a covered consumer on an unwired island counts as unpowered) is NOT
-- tested here, on purpose: reaching unpowered > 0 takes a real planner-built plan, so it is
-- pinned by the in-game big-pole scenario instead.

local layout = require("scripts.layout")
local poles = require("scripts.poles")

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
end)
