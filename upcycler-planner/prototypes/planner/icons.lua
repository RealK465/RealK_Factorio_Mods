-- Placeholder art, shared by the shortcut and the tool so the two cannot drift apart while it
-- is being tuned: the recycler's own icon with a legendary quality pip over it. Layered from
-- vanilla icons so no drawing gates the mod working. Real art replaces this later.
--
-- The recycler icon is a mipmapped strip (120x64 -- the smaller mip levels sit beside the base
-- image, which is why icon_size is 64 and not the file width); the quality pip is a plain
-- 64x64 with no mips, which is legal at icon_size 64 too.

return {
  { icon = "__recycler__/graphics/icons/recycler.png", icon_size = 64 },
  {
    icon = "__quality__/graphics/icons/quality-legendary.png",
    icon_size = 64,
    scale = 0.28,
    shift = { 8, 8 },
  },
}
