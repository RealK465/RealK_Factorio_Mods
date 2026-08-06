-- Pinning a recipe to Aquilo means matching Aquilo's own pressure exactly,
-- which is how vanilla does it -- cryogenic-science-pack carries the identical
-- condition. There is no "planet" property to test against.
--
-- Without Space Age there is no Aquilo, and settings.lua does not define the
-- setting at all. So the mods check has to come first: indexing a setting that
-- was never defined is an error, not a nil, and this leans on Lua's
-- short-circuit to never reach it.

local conditions
if mods["space-age"] and settings.startup["pure-modules-realk-aquilo-only"].value then
  conditions = { { property = "pressure", min = 300, max = 300 } }
end

return {
  -- Deep-copied per recipe: prototypes that share a table are one edit away
  -- from surprising each other.
  restrict = function(recipe)
    if conditions then
      recipe.surface_conditions = table.deepcopy(conditions)
    end
    return recipe
  end,
}
