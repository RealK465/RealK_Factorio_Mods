local lib = require("prototypes.lib")
local util = require("util")

local level = lib.early_level()

if level >= lib.early.construction then
  for _, name in pairs({"roboport", "construction-robot", "passive-provider-chest", "storage-chest"}) do
    lib.enable_recipe(name)
  end
end

if level >= lib.early.logistic then
  lib.enable_technology_recipes("logistic-robotics")
end

if level >= lib.early["logistic-system"] then
  lib.enable_technology_recipes("logistic-system")
end

-- The first worker robot upgrades now follow the early ones instead of robotics.
local function relink(name, prerequisite)
  local technology = data.raw.technology[name]
  if technology then technology.prerequisites = {prerequisite} end
end

if level >= lib.early.construction then
  relink("worker-robots-storage-1", "rwcr-early-worker-robots-storage")
  relink("worker-robots-speed-1", "rwcr-early-worker-robots-speed")

  data:extend({
    {
      type = "technology",
      name = "rwcr-early-character-logistic-slots",
      icon = "__base__/graphics/technology/logistic-robotics.png",
      icon_size = 256,
      effects = {{type = "character-logistic-requests", modifier = true}},
      prerequisites = {"logistics"},
      unit = {count = 20, ingredients = {{"automation-science-pack", 1}}, time = 15},
      order = "c-k-d",
    },
    {
      type = "technology",
      name = "rwcr-early-character-logistic-trash-slots",
      icon = "__base__/graphics/technology/logistic-robotics.png",
      icon_size = 256,
      effects = {{type = "character-logistic-trash-slots", modifier = 6}},
      prerequisites = {"logistics"},
      unit = {count = 20, ingredients = {{"automation-science-pack", 1}}, time = 15},
      order = "c-k-d",
    },
    {
      type = "technology",
      name = "rwcr-early-worker-robots-speed",
      icons = util.technology_icon_constant_movement_speed("__base__/graphics/technology/worker-robots-speed.png"),
      effects = {{type = "worker-robot-speed", modifier = 0.3}},
      prerequisites = {"logistics"},
      unit = {
        count = 100,
        ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}},
        time = 30,
      },
      order = "c-k-d",
    },
    {
      type = "technology",
      name = "rwcr-early-worker-robots-storage",
      icons = util.technology_icon_constant_capacity("__base__/graphics/technology/worker-robots-storage.png"),
      effects = {{type = "worker-robot-storage", modifier = 1}},
      prerequisites = {"logistics"},
      unit = {
        count = 100,
        ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}},
        time = 30,
      },
      order = "c-k-d",
    },
  })
end
