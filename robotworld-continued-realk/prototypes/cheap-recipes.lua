local lib = require("prototypes.lib")

if not lib.setting("cheap-recipes") then return end

local level = lib.early_level()

-- Bob's Electronics makes the electronic circuit a later tier and gives its early recipes
-- this board instead, so the cheap recipes follow it.
local circuit = "electronic-circuit"
if mods["bobelectronics"] and data.raw.item["bob-basic-circuit-board"] then
  circuit = "bob-basic-circuit-board"
end

-- The recycler builds every recycling recipe in its own data-updates, which runs before this
-- file, so rebuild each one changed here or it keeps returning the vanilla ingredients.
local recycling = mods["recycler"] and require("__recycler__.recycling")

local function set_ingredients(name, ingredients)
  lib.set_ingredients(name, ingredients)
  local recipe = data.raw.recipe[name]
  if recycling and recipe then
    recycling.generate_recycling_recipe(recipe)
  end
end

local robot = {{"iron-plate", 1}, {"iron-gear-wheel", 1}, {circuit, 1}}
local chest = {{"iron-plate", 3}, {circuit, 1}}
local roboport = {{"iron-plate", 25}, {"iron-gear-wheel", 10}, {circuit, 10}}

if level >= lib.early.construction then
  set_ingredients("construction-robot", robot)
  set_ingredients("passive-provider-chest", chest)
  set_ingredients("storage-chest", chest)
  set_ingredients("roboport", roboport)
end

if level >= lib.early.logistic then
  set_ingredients("logistic-robot", robot)
end

if level >= lib.early["logistic-system"] then
  set_ingredients("active-provider-chest", chest)
  set_ingredients("requester-chest", chest)
  set_ingredients("buffer-chest", chest)
end
