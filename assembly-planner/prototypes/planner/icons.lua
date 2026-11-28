-- The shortcut's art is the cell the planner builds: an assembling machine with a requester
-- chest and a passive provider under it, layered from vanilla icons so nothing of Wube's is
-- copied into the zip.
--
-- All three files are mipmapped strips (120x64: the smaller mips sit beside the base image),
-- hence icon_size 64. `scale` and `shift` are measured against the prototype's EXPECTED icon
-- size -- 32 for a shortcut's `icons`, 24 for its `small_icons` -- not against the file, so the
-- composition is written once as fractions and resolved per consumer. Every layer stays inside
-- the icon's own square: past its right or bottom edge a layer grows the composed box and the
-- engine shrinks everything to fit, past its top or left edge it is clipped.

-- Fractions of one icon: size, then the offset of its centre from the icon's centre.
local LAYERS = {
  { file = "__base__/graphics/icons/assembling-machine-3.png", size = 0.84, x = 0, y = -0.08 },
  { file = "__base__/graphics/icons/requester-chest.png", size = 0.38, x = -0.21, y = 0.31 },
  { file = "__base__/graphics/icons/passive-provider-chest.png", size = 0.38, x = 0.21, y = 0.31 },
}

local function layers(expected)
  local unit = expected / 2          -- one whole icon, in shift units
  local base = unit / 64             -- what a 64px file's scale defaults to here
  local out = {}
  for i, layer in ipairs(LAYERS) do
    out[i] = {
      icon = layer.file,
      icon_size = 64,
      scale = base * layer.size,
      shift = { unit * layer.x, unit * layer.y },
    }
  end
  return out
end

return {
  shortcut = layers(32),
  shortcut_small = layers(24),
}
