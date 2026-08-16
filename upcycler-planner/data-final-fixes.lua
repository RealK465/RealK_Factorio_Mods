-- 2.0 fork, and a file only this branch carries: 2.0 has no runtime mirror of a recipe's
-- data-stage `allow_quality` (2.1 reads it as LuaRecipePrototype.can_set_quality), so the
-- flag is recorded into mod-data here for scripts/planner.lua. Final-fixes so restrictions
-- other mods add are seen too; a mod loading after this one could still be missed, which is
-- accepted (.ai-support/analysis/factorio-2.0.md).

local blocked = {}
for name, recipe in pairs(data.raw.recipe) do
  if recipe.allow_quality == false then blocked[name] = true end
end

data:extend({
  {
    type = "mod-data",
    name = "upl-no-quality-recipes",
    data_type = "upl-no-quality-recipes",
    data = blocked,
  },
})
