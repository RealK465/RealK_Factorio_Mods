-- Moves the two vanilla quality technologies down a planet each, so the seven tiers land
-- one per milestone: epic on Fulgora, legendary once all three inner planets are running,
-- mythic on Aquilo, celestial on promethium science.
--
-- space-age sets both of these from its own data.lua, which is why this file waits for
-- data-updates. Counts and times are left alone; only the gate moves.

local technology = data.raw.technology

local epic = technology["epic-quality"]
epic.prerequisites = { "electromagnetic-science-pack", "utility-science-pack", "quality-module" }
epic.unit.ingredients =
{
  { "automation-science-pack", 1 },
  { "logistic-science-pack", 1 },
  { "chemical-science-pack", 1 },
  { "utility-science-pack", 1 },
  { "space-science-pack", 1 },
  { "electromagnetic-science-pack", 1 }
}

-- Fulgora is already covered by epic-quality above, so naming the other two planets here
-- is what makes this "all three".
local legendary = technology["legendary-quality"]
legendary.prerequisites = { "metallurgic-science-pack", "agricultural-science-pack", "epic-quality" }
legendary.unit.ingredients =
{
  { "automation-science-pack", 1 },
  { "logistic-science-pack", 1 },
  { "chemical-science-pack", 1 },
  { "production-science-pack", 1 },
  { "utility-science-pack", 1 },
  { "space-science-pack", 1 },
  { "metallurgic-science-pack", 1 },
  { "agricultural-science-pack", 1 },
  { "electromagnetic-science-pack", 1 }
}
