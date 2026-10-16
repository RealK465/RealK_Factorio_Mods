-- Kept local: the data stage is one Lua state shared by every mod, so globals here would
-- clash with any other mod using the same names (the original Robot World code did that).
-- Required as `lib`, not `helpers`, which would hide the engine's own `helpers` global.
local lib = {}

function lib.setting(name)
  return settings.startup["rwcr-" .. name].value
end

-- The early-robots dropdown as a number, so "at least construction" is a comparison.
lib.early = {off = 0, construction = 1, logistic = 2, ["logistic-system"] = 3}

function lib.early_level()
  return lib.early[lib.setting("early-robots")]
end

-- Energy values are strings such as "1.5MJ": scale the number, keep the unit. Parsed with
-- the same grammar as util.parse_energy, and written back as a plain decimal, because Lua
-- writes small results in exponent form ("5e-06kJ").
function lib.multiply_energy(energy, multiplier)
  if type(energy) ~= "string" then return energy end
  local number, unit = energy:match("^(.-)(%a?[JW])$")
  number = tonumber(number)
  if not number then return energy end
  local scaled = string.format("%.10f", number * multiplier):gsub("%.?0+$", "")
  return scaled .. unit
end

function lib.enable_recipe(name)
  local recipe = data.raw.recipe[name]
  if recipe then recipe.enabled = true end
end

function lib.enable_technology_recipes(name)
  local technology = data.raw.technology[name]
  if not (technology and technology.effects) then return end
  for _, effect in pairs(technology.effects) do
    if effect.type == "unlock-recipe" then
      lib.enable_recipe(effect.recipe)
    end
  end
end

-- Replaces the whole ingredient list with {name, amount} item pairs. Builds fresh tables
-- each call, so one template list can serve several recipes.
function lib.set_ingredients(name, ingredients)
  local recipe = data.raw.recipe[name]
  if not recipe then return end
  recipe.ingredients = {}
  for i, ingredient in ipairs(ingredients) do
    recipe.ingredients[i] = {type = "item", name = ingredient[1], amount = ingredient[2]}
  end
end

return lib
