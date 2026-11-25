-- Placeholder art for the shortcut: an assembling machine with a requester chest in its
-- corner, layered from vanilla icons so nothing of Wube's is copied into the zip.
--
-- Both files are mipmapped strips (120x64: the smaller mips sit beside the base image), hence
-- icon_size 64. `scale` and `shift` are measured against the prototype's EXPECTED icon size --
-- 32 for a shortcut's `icons`, 24 for its `small_icons` -- not against the file, so the
-- composition is written once as fractions and resolved per consumer. A negative shift clips
-- against the composed canvas instead of growing it, so the machine sits at 0 and the chest
-- carries the whole offset.

local MACHINE = "__base__/graphics/icons/assembling-machine-3.png"
local CHEST = "__base__/graphics/icons/requester-chest.png"

-- Fractions of one icon: size, then offset from its centre.
local MACHINE_SCALE, MACHINE_SHIFT = 0.85, 0.0
local CHEST_SCALE, CHEST_SHIFT = 0.55, 0.38

local function layers(expected)
  local unit = expected / 2          -- one whole icon, in shift units
  local base = unit / 64             -- what a 64px file's scale defaults to here
  return {
    {
      icon = MACHINE,
      icon_size = 64,
      scale = base * MACHINE_SCALE,
      shift = { unit * MACHINE_SHIFT, unit * MACHINE_SHIFT },
    },
    {
      icon = CHEST,
      icon_size = 64,
      scale = base * CHEST_SCALE,
      shift = { unit * CHEST_SHIFT, unit * CHEST_SHIFT },
    },
  }
end

return {
  shortcut = layers(32),
  shortcut_small = layers(24),
}
