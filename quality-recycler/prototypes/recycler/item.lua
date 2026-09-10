-- Item, recipe and technology.
--
-- The recipe eats a whole vanilla recycler, which is the design's lore made
-- mechanical: this machine is not new, it is a recycler that came back from
-- three planets with half of it replaced. The other ingredients are one from
-- each of those planets -- tungsten from Vulcanus, supercapacitors from
-- Fulgora, carbon fibre from Gleba -- so the bill of materials says where the
-- machine has been.

local item_sounds = require("__base__.prototypes.item_sounds")

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
    ingredients =
    {
      {type = "item", name = "recycler", amount = 1},
      {type = "item", name = "tungsten-plate", amount = 20},
      {type = "item", name = "supercapacitor", amount = 20},
      {type = "item", name = "carbon-fiber", amount = 20},
      {type = "item", name = "processing-unit", amount = 20}
    },
    results = {{type = "item", name = "quality-recycler", amount = 1}},
    energy_required = 10,
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
    -- The three science-pack technologies, and no cryogenic one. That is a
    -- real rung rather than a vague late-game: verified against
    -- `data/space-age/prototypes/technology.lua`, exactly one vanilla
    -- technology sits at those three sciences without cryogenic
    -- (`planet-discovery-aquilo`), so this unlocks at the moment the player
    -- has all three mid-game planets' industries and nothing from Aquilo yet.
    prerequisites =
    {
      "recycling",
      "metallurgic-science-pack",
      "electromagnetic-science-pack",
      "agricultural-science-pack"
    },
    unit =
    {
      count = 1000,
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
  }
})
