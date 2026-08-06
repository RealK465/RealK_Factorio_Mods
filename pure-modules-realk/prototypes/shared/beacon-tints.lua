-- The colours a module is drawn with inside a beacon.
--
-- `primary` tints the cartridge body, `secondary` its lamps. Getting that
-- round the wrong way is the easy mistake: the lamps are the most saturated
-- pixels in a module icon, so sampling for "the module's colour" finds them
-- and not the chassis. Productivity is a RED module with gold lamps; quality
-- is a SILVER module with red lamps.
--
-- speed and efficiency are vanilla's own values, lifted from
-- base/prototypes/item.lua. Vanilla defines nothing for productivity or
-- quality -- its beacon cannot take them -- so those two are derived from the
-- body/glow pair measured off the tier-3 icons in
-- assets/pure-modules-realk/icons/pure_module_icon.py: convert linear to sRGB
-- (Color literals here are 8-bit/255, not linear), take glow as secondary,
-- and scale body up until one channel hits 1.0 for primary. Speed is the
-- proof that derivation is sound -- it lands on (0.368, 0.737, 1.000) /
-- (0.353, 0.980, 0.980) where Wube wrote (0.441, 0.714, 1.000) / (0.388,
-- 0.976, 1.000). Productivity and quality are then nudged to match the icon
-- by eye: the raw red came out orange and quality's warm silver came out
-- cream.
--
-- FOUR SLOTS, TWO AUDIENCES. A beacon shows a module's tier by picking a
-- sprite variation, and vanilla's sheets hold three -- indexed by
-- ModulePrototype::tier, one lamp lit per tier, all three sharing one tint.
-- A Pure module is tier 4, past the end of that strip, so it clamps to the
-- tier-3 sprite and is pixel-identical to a tier-3 module in any vanilla
-- beacon. Nothing can be added to someone else's sprite sheet, so the only
-- thing left to tell them apart there is the tint.
--
-- But the Pure beacon has no such problem: its socket art is ours and only
-- ever draws one cartridge, so there a Pure module should simply look like
-- its own icon. Hence the split, using the two tint slots vanilla leaves
-- empty:
--
--   primary / secondary    -- every other beacon. Pure reads as a distinct
--                             kind: dark anodised chassis, lamps toward
--                             white, family hue kept.
--   tertiary / quaternary  -- the Pure beacon, which asks for these by name.
--                             True to the module's own icon.
--
-- Every module therefore needs all four, or the Pure beacon draws nothing for
-- a vanilla module. `complete()` is what guarantees that.
local M = {}

M.by_category = {
  speed = {
    primary = {0.441, 0.714, 1.000, 1.000},
    secondary = {0.388, 0.976, 1.000, 1.000},
  },
  efficiency = {
    primary = {0.000, 1.000, 0.000, 1.000},
    secondary = {0.370, 1.000, 0.370, 1.000},
  },
  productivity = {
    primary = {0.900, 0.260, 0.160, 1.000},
    secondary = {0.980, 0.980, 0.431, 1.000},
  },
  quality = {
    primary = {0.880, 0.870, 0.850, 1.000},
    secondary = {0.881, 0.221, 0.152, 1.000},
  },

  -- Pure: dark chassis and white-hot lamps abroad, its own icon at home.
  ["pure-speed"] = {
    primary = {0.090, 0.170, 0.320, 1.000},
    secondary = {0.780, 1.000, 1.000, 1.000},
    tertiary = {0.441, 0.714, 1.000, 1.000},
    quaternary = {0.388, 0.976, 1.000, 1.000},
  },
  ["pure-productivity"] = {
    primary = {0.300, 0.070, 0.040, 1.000},
    secondary = {1.000, 0.960, 0.720, 1.000},
    tertiary = {0.900, 0.260, 0.160, 1.000},
    quaternary = {0.980, 0.980, 0.431, 1.000},
  },
  ["pure-quality"] = {
    primary = {0.210, 0.215, 0.235, 1.000},
    secondary = {1.000, 0.700, 0.660, 1.000},
    tertiary = {0.880, 0.870, 0.850, 1.000},
    quaternary = {0.881, 0.221, 0.152, 1.000},
  },
}

-- A modded category we know nothing about. Pale rather than absent: a generic
-- colour reads as art, no colour reads as a broken beacon.
M.fallback = {
  primary = {0.700, 0.720, 0.760, 1.000},
  secondary = {0.900, 0.930, 0.960, 1.000},
}

-- Returns a copy with all four slots filled, so a module that names only the
-- vanilla two still draws in a beacon asking for tertiary or quaternary.
-- Never overwrites a slot that is already set.
function M.complete(tint)
  local t = table.deepcopy(tint)
  t.secondary = t.secondary or table.deepcopy(t.primary)
  t.tertiary = t.tertiary or table.deepcopy(t.primary)
  t.quaternary = t.quaternary or table.deepcopy(t.secondary)
  return t
end

return M
