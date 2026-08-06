-- Pure modules get their own categories rather than reusing "speed" etc.
-- BeaconPrototype.allowed_module_categories filters by ModuleCategory, so the
-- Pure beacon cannot express "Pure modules only" without them.
--
-- Safe to add: RecipePrototype and CraftingMachinePrototype also carry
-- allowed_module_categories, and any prototype that sets one would reject Pure
-- modules for not being listed -- but nothing in base, quality or Space Age
-- sets it at all.

local defs = require("prototypes.modules.definitions")

local categories = {}
for _, def in pairs(defs) do
  categories[#categories + 1] = { type = "module-category", name = def.category }
end

data:extend(categories)
