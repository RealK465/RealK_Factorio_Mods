-- Fills in the fields a beacon needs to draw an inserted module, for every
-- module that lacks them -- which is most of them.
--
-- A beacon picks its visualisation by matching ModulePrototype::art_style
-- against BeaconModuleVisualizations::art_style, so a nil art_style matches
-- none and the socket draws nothing. The tint then multiplies the mask
-- sprites, and its default is "no color" -- transparent -- so a matched
-- visualisation with no beacon_tint renders as nothing either.
--
-- Vanilla sets both on speed and efficiency modules and on nothing else,
-- because its beacon does not accept productivity or quality modules. This
-- one can, so the art it needs has to come from somewhere.
--
-- The tint is completed even when the module already has one: vanilla names
-- only primary and secondary, and the Pure beacon's sockets ask for tertiary
-- and quaternary. Without the backfill every vanilla module would go
-- invisible in it -- the same failure, one slot along.
--
-- Final fixes rather than updates, so a module registered by another mod's
-- own final-fixes is still caught. Nothing already set is overwritten.
local bt = require("prototypes.shared.beacon-tints")

for _, module in pairs(data.raw["module"]) do
  if not module.art_style then
    module.art_style = "vanilla"
    -- Vanilla's two beacon-art modules both set this false. Left at its
    -- default of true the cartridge only appears while alt mode is on, which
    -- looks like the same bug again to anyone playing without it.
    module.requires_beacon_alt_mode = false
  end
  module.beacon_tint = bt.complete(
    module.beacon_tint or bt.by_category[module.category] or bt.fallback)
end
