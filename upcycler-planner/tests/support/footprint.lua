-- The geometry checks both layout specs run on every plan shape -- the belt ring's and the bot
-- loop's -- in one copy, so a tightened invariant reaches both. Pure: standard Lua only.
local footprint = {}

function footprint.by_name(built, name)
  local out = {}
  for _, e in pairs(built.entities) do
    if e.name == name then out[#out + 1] = e end
  end
  return out
end

-- The two generic invariants every historical harness ran on every plan shape: everything
-- inside the plan's own rectangle, and no tile held twice. Returns the occupancy map.
function footprint.assert_no_overlap_and_in_bounds(built)
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

return footprint
