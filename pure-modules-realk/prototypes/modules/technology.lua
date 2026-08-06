local defs = require("prototypes.modules.definitions")
local units = require("prototypes.shared.science-units")

-- Every Pure module technology sits behind two things: its own tier 3 parent,
-- and the Pure beacon. The beacon carries the tier's placement in the tree --
-- space science in the base game, the quantum processor under Space Age -- so
-- restating either here would only be a prerequisite the tree already draws.
--
-- The beacon first is also the honest reading of the tier: it is the machine
-- that made a module this clean worth building, and it is useful the moment it
-- is researched, holding the tier 3 modules already in hand over a far wider
-- area.

local technologies = {}
for _, def in pairs(defs) do
  technologies[#technologies + 1] = {
    type = "technology",
    name = def.name,
    icon = "__pure-modules-realk__/graphics/technology/" .. def.name .. ".png",
    icon_size = 256,
    effects = { { type = "unlock-recipe", recipe = def.name } },
    prerequisites = { def.parent_tech, "pure-beacon" },
    unit = units.module(),
    order = def.order,
  }
end

data:extend(technologies)
