-- Shared technology unit costs for the Pure tier, so the beacon and the
-- modules cannot drift apart on ingredients or research time.
--
-- Two counts, because the beacon technology is now the gate the three module
-- technologies sit behind. It unlocks something useful on its own -- a wide
-- supply area for the tier-3 modules already in hand -- so it is priced as the
-- way in rather than as a fourth endgame technology.

local packs = {
  { "automation-science-pack", 1 },
  { "logistic-science-pack", 1 },
  { "chemical-science-pack", 1 },
  { "production-science-pack", 1 },
  { "utility-science-pack", 1 },
  { "space-science-pack", 1 },
}

if mods["space-age"] then
  local sa = {
    { "metallurgic-science-pack", 1 },
    { "agricultural-science-pack", 1 },
    { "electromagnetic-science-pack", 1 },
    { "cryogenic-science-pack", 1 },
  }
  for _, pack in ipairs(sa) do
    packs[#packs + 1] = pack
  end
end

-- A fresh table per call: four technologies sharing one nested ingredient list
-- are one edit away from surprising each other.
local function unit(count)
  return { count = count, time = 60, ingredients = table.deepcopy(packs) }
end

return {
  beacon = function() return unit(1000) end,
  module = function() return unit(3000) end,
}
