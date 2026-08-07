-- One table drives the module, its category, its recipe and its technology.
-- Adding a Pure module means adding a row here and rendering its icons.
--
-- Effects: Pure modules drop tier 3's speed and quality penalties and keep a
-- single cost, more power and a little more pollution. Quality modules carry
-- no penalty at all.
--
-- Penalties DO scale with quality on 2.0, and nothing here can stop them:
-- consumption_quality_multiplier and pollution_quality_multiplier are 2.1-only
-- properties. A legendary Pure speed module therefore draws 2.5x the power and
-- makes 2.5x the pollution along with its 2.5x speed. The 2.1 build gets flat
-- penalties for free from those properties' defaults -- which is why the flat
-- penalty is claimed only on that track, in neither this changelog nor the
-- portal description here.
--
-- beacon_tint: the colours live in shared/beacon-tints.lua, keyed by the same
-- category name used here, because data-final-fixes hands the vanilla entries
-- to the tier-1-3 modules that ship without any. The pure-* entries are
-- deliberately unlike their tier-3 parent -- a beacon distinguishes tiers by
-- sprite variation and there is no fourth one, so tint is the only thing left
-- to tell a Pure module apart in a vanilla beacon.

local bt = require("prototypes.shared.beacon-tints")

local PENALTY = { consumption = 0.50, pollution = 0.25 }

-- The speed module is built with quality modules. Without the quality
-- expansion there are none, so it falls back to tier 3 efficiency modules.
local speed_partner = mods["quality"] and "quality-module-3" or "efficiency-module-3"

local defs = {
  {
    name = "pure-speed-module",
    category = "pure-speed",
    parent_item = "speed-module-3",
    parent_tech = "speed-module-3",
    color_hint = "S",
    order = "a[speed]-d[pure-speed-module]",
    effect = { speed = 0.70, consumption = PENALTY.consumption, pollution = PENALTY.pollution },
    module_ingredients = {
      { "speed-module-3", 4 },
      { speed_partner, 1 },
    },
    beacon_tint = bt.complete(bt.by_category["pure-speed"]),
  },
  {
    name = "pure-productivity-module",
    category = "pure-productivity",
    parent_item = "productivity-module-3",
    parent_tech = "productivity-module-3",
    color_hint = "P",
    order = "c[productivity]-d[pure-productivity-module]",
    effect = { productivity = 0.15, consumption = PENALTY.consumption, pollution = PENALTY.pollution },
    module_ingredients = {
      { "productivity-module-3", 4 },
      { "speed-module-3", 1 },
    },
    beacon_tint = bt.complete(bt.by_category["pure-productivity"]),
  },
}

-- Quality modules only exist when the quality expansion is enabled; without
-- it there is no quality-module-3 to build from and no quality effect worth
-- having, so the whole row drops out rather than erroring on a missing item.
if mods["quality"] then
  defs[#defs + 1] = {
    name = "pure-quality-module",
    category = "pure-quality",
    parent_item = "quality-module-3",
    parent_tech = "quality-module-3",
    color_hint = "Q",
    order = "d[quality]-d[pure-quality-module]",
    -- 0.4 so a legendary one reaches exactly 10%. On 2.0 a quality effect is
    -- multiplied by the current quality's next_probability, 0.1, to reach the
    -- actual chance, so every written value is ten times its 2.1 counterpart
    -- -- vanilla's own quality-module-3 is 0.25 here and 0.025 there. Module
    -- quality then scales by default_multiplier, 1 + 0.3 * level, and
    -- legendary is level 5 -- not 4 -- so the factor is 2.5.
    effect = { quality = 0.4 },
    module_ingredients = {
      { "quality-module-3", 4 },
      { "speed-module-3", 1 },
    },
    beacon_tint = bt.complete(bt.by_category["pure-quality"]),
  }
end

return defs
