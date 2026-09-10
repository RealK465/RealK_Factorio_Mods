-- The two tiers above legendary. Field set mirrors vanilla's qualities: everything not
-- listed here falls back to default_multiplier (1 + 0.3 * level), which is where the
-- crafting speed, module strength, inventory size and lab speed bonuses come from.
--
-- Levels are 6 and 8. The gap at 7 mirrors vanilla's own gap at 4 before legendary.
--
-- **default_multiplier is not set here.** All seven tiers' multipliers live in one table in
-- ladder.lua, because the ladder only makes sense read as a whole - splitting it across two
-- files is what let an uneven step ship twice. Level is still set here, and still drives the
-- bonuses that are counted rather than multiplied: equipment grid, pole supply area,
-- accumulator capacity, robot energy, tool durability.
--
-- **2.0 build.** Three fields the 2.1 file sets do not exist on this engine, and are dropped
-- rather than left in place: an unknown property loads clean and does nothing, which is how a
-- port goes quietly wrong. They are chain_probability, locomotive_power_multiplier and
-- rolling_stock_max_speed_multiplier. So trains gain nothing above legendary here, and a roll
-- can only ever land one tier up - 2.0 has no skip mechanic to configure.

data:extend(
  {
    {
      type = "quality",
      name = "mythic",
      level = 6,
      color = {178, 29, 41},
      order = "f",
      next = "celestial",
      -- 2.0 scale: every vanilla quality is 0.1 here where 2.1 writes 1. See ladder.lua.
      next_probability = 0.1,
      subgroup = "qualities",
      icon = "__extra-qualities__/graphics/icons/quality-mythic.png",
      -- Vanilla's (6 - level)/6 ramp for these two hits zero at level 6, which would mean a
      -- free beacon and free ore, so both continue by hand instead.
      beacon_power_usage_multiplier = 1/8,
      mining_drill_resource_drain_multiplier = 1/8,
      science_pack_drain_multiplier = 94/100
    },
    {
      type = "quality",
      name = "celestial",
      level = 8,
      color = {0, 162, 178},
      order = "g",
      subgroup = "qualities",
      icon = "__extra-qualities__/graphics/icons/quality-celestial.png",
      beacon_power_usage_multiplier = 1/12,
      mining_drill_resource_drain_multiplier = 1/12,
      science_pack_drain_multiplier = 92/100
    }
  }
)
