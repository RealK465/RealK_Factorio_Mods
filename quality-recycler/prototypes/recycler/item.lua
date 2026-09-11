-- Item, recipe and technology.
--
-- The recipe eats a whole vanilla recycler, which is the design's lore made
-- mechanical: this machine is not new, it is a recycler that came back with
-- half of it replaced. Two quality module 3s are the "quality built in". The
-- rest of the bill of materials depends on the game:
--
--   Space Age  one material from each of the first three planets -- tungsten
--              from Vulcanus, supercapacitors from Fulgora, carbon fibre from
--              Gleba -- so the ingredients say where the machine has been, and
--              the technology sits after those three planets' sciences.
--   without    low-density structure and electric engines (the rotor's drive)
--              on top of the processing units, and the technology sits after
--              the rocket: space science plus utility science.
--
-- `mods["space-age"]`, not a feature flag: the branch exists because the
-- planet ITEMS and science packs only exist with the expansion loaded, which
-- is what `mods` says. The reasoning and the numbers are in
-- `.ai-support/decisions.md`.

local item_sounds = require("__base__.prototypes.item_sounds")

local space_age = mods["space-age"] ~= nil

local ingredients, prerequisites, unit
if space_age then
  ingredients =
  {
    {type = "item", name = "recycler", amount = 1},
    {type = "item", name = "quality-module-3", amount = 2},
    {type = "item", name = "tungsten-plate", amount = 30},
    {type = "item", name = "supercapacitor", amount = 20},
    {type = "item", name = "carbon-fiber", amount = 30},
    {type = "item", name = "processing-unit", amount = 30}
  }
  -- The three science-pack technologies, and no cryogenic one. That is a
  -- real rung rather than a vague late-game: verified against
  -- `data/space-age/prototypes/technology.lua`, exactly one vanilla
  -- technology sits at those three sciences without cryogenic
  -- (`planet-discovery-aquilo`), so this unlocks at the moment the player
  -- has all three mid-game planets' industries and nothing from Aquilo yet.
  prerequisites =
  {
    "recycling",
    "quality-module-3",
    "metallurgic-science-pack",
    "electromagnetic-science-pack",
    "agricultural-science-pack"
  }
  unit =
  {
    count = 500,
    ingredients =
    {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"production-science-pack", 1},
      {"metallurgic-science-pack", 1},
      {"electromagnetic-science-pack", 1},
      {"agricultural-science-pack", 1}
    },
    time = 60
  }
else
  ingredients =
  {
    {type = "item", name = "recycler", amount = 1},
    {type = "item", name = "quality-module-3", amount = 2},
    {type = "item", name = "low-density-structure", amount = 20},
    {type = "item", name = "electric-engine-unit", amount = 10},
    {type = "item", name = "processing-unit", amount = 30}
  }
  -- After the rocket: `space-science-pack` is a technology in base as well
  -- as in Space Age (the expansion only changes its trigger), so it is a
  -- safe gate either way, and it is the base game's own "after the planets".
  prerequisites =
  {
    "recycling",
    "quality-module-3",
    "utility-science-pack",
    "space-science-pack"
  }
  unit =
  {
    count = 500,
    ingredients =
    {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"production-science-pack", 1},
      {"utility-science-pack", 1},
      {"space-science-pack", 1}
    },
    time = 60
  }
end

data:extend({
  {
    type = "item",
    name = "quality-recycler",
    icon = "__quality-recycler__/graphics/icons/quality-recycler.png",
    icon_size = 64,
    subgroup = "smelting-machine",
    order = "d[recycler]-b[quality-recycler]",
    place_result = "quality-recycler",
    stack_size = 20,
    weight = 100 * kg,
    inventory_move_sound = item_sounds.metal_large_inventory_move,
    pick_sound = item_sounds.metal_large_inventory_pickup,
    drop_sound = item_sounds.metal_large_inventory_move
  },

  {
    type = "recipe",
    name = "quality-recycler",
    ingredients = ingredients,
    results = {{type = "item", name = "quality-recycler", amount = 1}},
    energy_required = 10,                  -- the electromagnetic plant's
    enabled = false
  },

  {
    type = "technology",
    name = "quality-recycling",
    icon = "__quality-recycler__/graphics/technology/quality-recycling.png",
    icon_size = 256,
    effects =
    {
      { type = "unlock-recipe", recipe = "quality-recycler" }
    },
    prerequisites = prerequisites,
    unit = unit
  }
})
