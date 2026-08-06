local defs = require("prototypes.modules.definitions")
local aquilo = require("prototypes.shared.aquilo")

-- Space Age puts every vanilla module recipe into the electromagnetic plant's
-- category alongside the assembler's, and does the same for the beacon. A Pure
-- module that could only be made in an assembler would be the odd one out.
local categories = mods["space-age"] and { "crafting", "electromagnetics" } or nil

-- Merge rather than append: a recipe must not list the same ingredient twice,
-- and without the quality expansion the speed module's substitute is an
-- efficiency module 3, which is also the shared ingredient below. Those two
-- entries have to collapse into one.
local function add(ingredients, name, amount)
  for _, ingredient in ipairs(ingredients) do
    if ingredient.name == name then
      ingredient.amount = ingredient.amount + amount
      return
    end
  end
  ingredients[#ingredients + 1] = { type = "item", name = name, amount = amount }
end

local recipes = {}
for _, def in pairs(defs) do
  local ingredients = {}

  -- the tier 3 modules this one is built from, which differ per module
  for _, pair in ipairs(def.module_ingredients) do
    add(ingredients, pair[1], pair[2])
  end

  add(ingredients, "efficiency-module-3", 1)
  add(ingredients, "processing-unit", 10)
  add(ingredients, "low-density-structure", 5)

  -- Space Age gates these behind the quantum processor, so spending them here
  -- costs nothing extra in progression. Without the expansion the recipe
  -- stays entirely base-game.
  if mods["space-age"] then
    add(ingredients, "quantum-processor", 5)
  end

  recipes[#recipes + 1] = aquilo.restrict({
    type = "recipe",
    name = def.name,
    enabled = false,
    categories = categories and table.deepcopy(categories) or nil,
    energy_required = 90,
    ingredients = ingredients,
    results = { { type = "item", name = def.name, amount = 1 } },
  })
end

data:extend(recipes)
