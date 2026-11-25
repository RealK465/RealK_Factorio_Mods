-- poles.lua as pure data: a cell's entities as plain rects, a pole as plain numbers.

local poles = require("scripts.poles")

local MEDIUM = { name = "pole", quality = "normal", width = 1, height = 1, supply_distance = 3.5, wire_distance = 9 }
local SMALL = { name = "pole", quality = "normal", width = 1, height = 1, supply_distance = 2.5, wire_distance = 7.5 }
local MARGINS = { m = 0.3, i = 0.35 }

-- An AM3 cell with two slots and a spare column under the machine's right edge.
local function am3_cell()
  return {
    width = 3, height = 5,
    entities = {
      { name = "m", dx = 0, dy = 0, w = 3, h = 3 },
      { name = "i", dx = 0, dy = 3, w = 1, h = 1 }, { name = "c", dx = 0, dy = 4, w = 1, h = 1 },
      { name = "i", dx = 1, dy = 3, w = 1, h = 1 }, { name = "c", dx = 1, dy = 4, w = 1, h = 1 },
    },
  }
end

describe("poles.plan", function()
  test("one pole in a spare tile powers the whole cell", function()
    local result = poles.plan(am3_cell(), MEDIUM, MARGINS)
    assert(result.unpowered == 0, result.unpowered .. " consumers left dark")
    assert(#result.entities == 1, "expected one pole, got " .. #result.entities)
    local p = result.entities[1]
    assert(p.dx == 2 and (p.dy == 3 or p.dy == 4), "the pole is not in the spare column")
  end)

  test("no free tile, no pole, every consumer counted", function()
    local full = am3_cell()
    full.entities[#full.entities + 1] = { name = "c", dx = 2, dy = 3, w = 1, h = 1 }
    full.entities[#full.entities + 1] = { name = "c", dx = 2, dy = 4, w = 1, h = 1 }
    local result = poles.plan(full, MEDIUM, MARGINS)
    assert(#result.entities == 0 and result.unpowered == 3, "a pole was placed on occupied ground")
  end)

  test("several poles stay wired into one network", function()
    -- A long strip: consumers at both ends, free ground between.
    local strip = { width = 20, height = 1, entities = {
      { name = "i", dx = 0, dy = 0, w = 1, h = 1 }, { name = "i", dx = 19, dy = 0, w = 1, h = 1 },
      { name = "i", dx = 10, dy = 0, w = 1, h = 1 },
    } }
    local result = poles.plan(strip, SMALL, MARGINS)
    assert(result.unpowered == 0, result.unpowered .. " consumers left dark")
    for index, p in ipairs(result.entities) do
      if index > 1 then
        assert(p.wire_to and p.wire_to < index, "pole " .. index .. " is not wired back to an earlier one")
        local q = result.entities[p.wire_to]
        local d = math.sqrt((p.dx - q.dx) ^ 2 + (p.dy - q.dy) ^ 2)
        assert(d <= SMALL.wire_distance, "pole " .. index .. " wired past its reach")
      end
    end
  end)

  test("the same cell grows the same poles", function()
    local a, b = poles.plan(am3_cell(), SMALL, MARGINS), poles.plan(am3_cell(), SMALL, MARGINS)
    assert(#a.entities == #b.entities and a.unpowered == b.unpowered, "two runs disagree")
    for i, p in ipairs(a.entities) do
      assert(p.dx == b.entities[i].dx and p.dy == b.entities[i].dy, "pole " .. i .. " moved between runs")
    end
  end)
end)
