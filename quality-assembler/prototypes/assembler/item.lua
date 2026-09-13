-- Item, recipe and technology.
--
-- The recipe eats a whole assembling machine 3, which is the design's lore
-- made mechanical: this machine is not new, it is an assembler that came back
-- from Aquilo with half of it replaced. Two quality module 3s are the "quality
-- built in". The rest of the bill of materials depends on the game:
--
--   Space Age  the cryogenic hardware's own materials -- lithium plate from
--              Aquilo and superconductors for the cold cell's drive -- on top
--              of the processing units, and the technology sits after Aquilo
--              at the same cost as the quantum processor.
--   without    low-density structure and electric engines (the compressor's
--              drive) on top of the processing units, and the technology sits
--              after the rocket: space science plus utility science.
--
-- `mods["space-age"]`, not a feature flag: the branch exists because the
-- planet ITEMS and science packs only exist with the expansion loaded, which
-- is what `mods` says. The reasoning is in `.ai-support/decisions.md`.

local item_sounds = require("__base__.prototypes.item_sounds")

local space_age = mods["space-age"] ~= nil

local ingredients, prerequisites, unit
if space_age then
  ingredients =
  {
    {type = "item", name = "assembling-machine-3", amount = 1},
    {type = "item", name = "quality-module-3", amount = 2},
    {type = "item", name = "lithium-plate", amount = 20},
    {type = "item", name = "superconductor", amount = 10},
    {type = "item", name = "processing-unit", amount = 20}
  }
  -- After Aquilo. `cryogenic-science-pack` is the technology that marks
  -- Aquilo done; this puts the machine on the shelf with the quantum
  -- processor, the fusion reactor and the railgun, at the quantum
  -- processor's own cost.
  prerequisites =
  {
    "cryogenic-science-pack",
    "quality-module-3"
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
      {"space-science-pack", 1},
      {"metallurgic-science-pack", 1},
      {"agricultural-science-pack", 1},
      {"electromagnetic-science-pack", 1},
      {"cryogenic-science-pack", 1}
    },
    time = 60
  }
else
  ingredients =
  {
    {type = "item", name = "assembling-machine-3", amount = 1},
    {type = "item", name = "quality-module-3", amount = 2},
    {type = "item", name = "low-density-structure", amount = 20},
    {type = "item", name = "electric-engine-unit", amount = 10},
    {type = "item", name = "processing-unit", amount = 20}
  }
  -- After the rocket: `space-science-pack` is a technology in base as well
  -- as in Space Age (the expansion only changes its trigger), and it is the
  -- deepest real rung the base game has. The two branches sit at different
  -- relative depths on purpose -- see decisions.md.
  prerequisites =
  {
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
    name = "quality-assembler",
    icon = "__quality-assembler__/graphics/icons/quality-assembler.png",
    icon_size = 64,
    subgroup = "production-machine",
    order = "c[assembling-machine-3]-d[quality-assembler]",
    place_result = "quality-assembler",
    stack_size = 50,
    weight = 40 * kg,                      -- the assembling machine 3's
    inventory_move_sound = item_sounds.mechanical_inventory_move,
    pick_sound = item_sounds.mechanical_inventory_pickup,
    drop_sound = item_sounds.mechanical_inventory_move
  },

  {
    type = "recipe",
    name = "quality-assembler",
    ingredients = ingredients,
    results = {{type = "item", name = "quality-assembler", amount = 1}},
    energy_required = 10,                  -- the electromagnetic plant's
    enabled = false
  },

  {
    type = "technology",
    name = "quality-assembly",
    icon = "__quality-assembler__/graphics/technology/quality-assembly.png",
    icon_size = 256,
    effects =
    {
      { type = "unlock-recipe", recipe = "quality-assembler" }
    },
    prerequisites = prerequisites,
    unit = unit
  }
})
