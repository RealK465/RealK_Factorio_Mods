-- The two new quality technologies. Costs step 5000 (legendary) -> 7500 -> 10000; the real
-- gate is the pack list, and promethium science is a whole expedition of its own.

local all_ten_packs =
{
  { "automation-science-pack", 1 },
  { "logistic-science-pack", 1 },
  { "chemical-science-pack", 1 },
  { "production-science-pack", 1 },
  { "utility-science-pack", 1 },
  { "space-science-pack", 1 },
  { "metallurgic-science-pack", 1 },
  { "agricultural-science-pack", 1 },
  { "electromagnetic-science-pack", 1 },
  { "cryogenic-science-pack", 1 }
}

local with_promethium = table.deepcopy(all_ten_packs)
table.insert(with_promethium, { "promethium-science-pack", 1 })

data:extend(
{
  {
    type = "technology",
    name = "mythic-quality",
    icon = "__extra-qualities__/graphics/technology/mythic-quality.png",
    icon_size = 256,
    effects =
    {
      {
        type = "unlock-quality",
        quality = "mythic"
      }
    },
    prerequisites = { "cryogenic-science-pack", "legendary-quality" },
    unit =
    {
      count = 7500,
      ingredients = all_ten_packs,
      time = 60
    }
  },
  {
    type = "technology",
    name = "celestial-quality",
    icon = "__extra-qualities__/graphics/technology/celestial-quality.png",
    icon_size = 256,
    effects =
    {
      {
        type = "unlock-quality",
        quality = "celestial"
      }
    },
    prerequisites = { "promethium-science-pack", "mythic-quality" },
    unit =
    {
      count = 10000,
      ingredients = with_promethium,
      time = 60
    }
  }
})
