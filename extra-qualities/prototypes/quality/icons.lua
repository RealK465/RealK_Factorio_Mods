-- Redraws vanilla's five quality glyphs and its two quality technology icons.
--
-- The mod's own tiers cannot match Wube's at these sizes: six pips do not fit at vanilla's
-- 11 px radius, so they have to shrink, and a tier drawn to different rules is what a player
-- actually notices in a tooltip list. Redrawing all seven from one generator is cheaper than
-- pretending otherwise. Same for the technology icons - one die, one material, one camera,
-- four tiers.
--
-- Geometry, palette and what is deliberately different: .ai-support/art-direction.md.

local quality = data.raw.quality
for _, name in ipairs({ "normal", "uncommon", "rare", "epic", "legendary" }) do
  quality[name].icon = "__extra-qualities__/graphics/icons/quality-" .. name .. ".png"
  quality[name].icon_size = 64
  quality[name].icons = nil
end

local technology = data.raw.technology
for _, name in ipairs({ "epic-quality", "legendary-quality" }) do
  technology[name].icon = "__extra-qualities__/graphics/technology/" .. name .. ".png"
  technology[name].icon_size = 256
  technology[name].icons = nil
end
