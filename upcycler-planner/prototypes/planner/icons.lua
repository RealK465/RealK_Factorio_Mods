-- Placeholder art, shared by the shortcut and the tool so the two cannot drift apart while it
-- is being tuned: the recycler's own icon and a legendary quality pip side by side. Two symbols
-- rather than one -- the mod turns recycling INTO quality, and a small pip in the corner reads
-- as "a legendary recycler" instead. Layered from vanilla icons so no drawing gates the mod
-- working, and nothing of Wube's is copied into the shipped zip. Real art replaces this later.
--
-- The recycler icon is a mipmapped strip (120x64 -- the smaller mip levels sit beside the base
-- image, which is why icon_size is 64 and not the file width); the quality pip is a plain
-- 64x64 with no mips, which is legal at icon_size 64 too.
--
-- `scale` and `shift` are measured against the prototype's EXPECTED icon size, not against the
-- layer's own icon_size: 64 for an item, but 32 for a shortcut's `icons` and 24 for its
-- `small_icons` (prototype-api, IconData::scale). One table therefore cannot serve both -- at
-- item-sized numbers the shortcut's pip renders wider than the whole button, which is what it
-- did until 2026-08-16. So the composition is written once as fractions of the icon and
-- resolved per consumer.

-- 2.0 fork: the recycler entity and its icon live in the `quality` mod here (there is no
-- `recycler` mod before 2.1); main reads the same 120x64 strip from `__recycler__` instead.
local RECYCLER = "__quality__/graphics/icons/recycler.png"
local PIP = "__quality__/graphics/icons/quality-legendary.png"

-- Fractions of one icon: size, then offset from its centre.
--
-- Shifts are asymmetric and it cost a round to find: a POSITIVE shift grows the composed
-- bounding box, a NEGATIVE one pushes the layer off it and the overhang is CLIPPED. So the
-- recycler sits at 0 and the pip carries the whole separation, rather than the two leaning
-- away from each other by half as much each -- which looked balanced in the numbers and cut
-- the recycler down to a sliver in game. The box still wants to stay small: the engine fits
-- it to the button, so every pixel of empty margin shrinks both symbols.
local RECYCLER_SCALE, RECYCLER_SHIFT = 0.85, 0.0
local PIP_SCALE, PIP_SHIFT = 0.80, 0.38

local function layers(expected)
  local unit = expected / 2          -- one whole icon, in shift units
  local base = unit / 64             -- what a 64px file's scale defaults to here
  return {
    {
      icon = RECYCLER,
      icon_size = 64,
      scale = base * RECYCLER_SCALE,
      shift = { unit * RECYCLER_SHIFT, unit * RECYCLER_SHIFT },
    },
    {
      icon = PIP,
      icon_size = 64,
      scale = base * PIP_SCALE,
      shift = { unit * PIP_SHIFT, unit * PIP_SHIFT },
    },
  }
end

return {
  item = layers(64),
  shortcut = layers(32),
  shortcut_small = layers(24),
}
