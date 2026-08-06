-- Graphics for the Pure beacon. Structure mirrors vanilla's
-- beacon-animations.lua; numbers are the measured output of
-- assets/pure-modules-realk/entity/beacon/make_sheets.py and make_slots.py
-- (sheet_numbers.txt / slot_numbers.txt beside them).
--
-- Layer semantics, verified against the 2.1 prototype API: always_draw=false
-- layers exist only while the beacon works; apply_tint layers take the
-- inserted module's beacon_tint.
--
-- These sockets ask for **tertiary/quaternary**, not primary/secondary. A
-- Pure module's primary pair is deliberately unlike its tier-3 parent so the
-- two can be told apart in a vanilla beacon, which has no spare sprite
-- variation to distinguish them; that trick is not needed here, where the
-- socket art is ours and a module should just look like its own icon. Every
-- module is guaranteed all four slots by shared/beacon-tints.lua's
-- complete(), applied in data-final-fixes -- without it a vanilla module,
-- which names only two, would be invisible in this beacon.
local g = "__pure-modules-realk__/graphics/entity/beacon/"

-- The ports themselves live in the base sprite; these layers draw only the
-- cartridge that appears when a module is inserted. An empty-slot layer here
-- would redraw the port over the front lip. Sockets sit one tile apart,
-- which is 32 display px of x shift.
local function socket(shift)
  return {
    {
      apply_module_tint = "tertiary",
      render_layer = "lower-object",
      pictures = {
        filename = g .. "beacon-module-mask-box.png",
        width = 42, height = 40, scale = 0.5, shift = shift,
      },
    },
    {
      apply_module_tint = "quaternary",
      render_layer = "lower-object-above-shadow",
      pictures = {
        filename = g .. "beacon-module-mask-lights.png",
        width = 42, height = 40, scale = 0.5, shift = shift,
      },
    },
    {
      apply_module_tint = "quaternary",
      render_layer = "lower-object-above-shadow",
      pictures = {
        filename = g .. "beacon-module-lights.png",
        width = 42, height = 40, scale = 0.5, shift = shift,
        draw_as_light = true,
      },
    },
  }
end

local anim_frames = {
  width = 220, height = 230,
  frame_count = 64, line_length = 8,
  animation_speed = 0.5,
  scale = 0.5,
  shift = util.by_pixel(0.0, -87.5),
}

local function arcs_layer(extra)
  local a = table.deepcopy(anim_frames)
  a.filename = g .. "beacon-arcs.png"
  a.blend_mode = "additive"
  for k, v in pairs(extra or {}) do a[k] = v end
  return a
end

local set = {
  module_icons_suppressed = true,
  module_tint_mode = "mix",
  apply_module_tint = "quaternary",
  no_modules_tint = { 1, 1, 1 },
  random_animation_offset = true,
  draw_animation_when_idle = false,

  light = { shift = { 0, 0 }, color = { 0.55, 0.85, 1.0 }, intensity = 0.4, size = 8 },

  animation_list = {
    -- static plinth + its shadow
    {
      render_layer = "floor-mechanics",
      always_draw = true,
      animation = {
        layers = {
          {
            filename = g .. "beacon-base.png",
            width = 308, height = 450, scale = 0.5,
            shift = util.by_pixel(0.0, -35.0),
          },
          {
            filename = g .. "beacon-shadow.png",
            width = 412, height = 326, scale = 0.5,
            shift = util.by_pixel(25.5, 1.5),
            draw_as_shadow = true,
          },
        },
      },
    },
    -- rings + crystal, frozen while idle
    {
      render_layer = "object",
      always_draw = true,
      animation = {
        filename = g .. "beacon-anim.png",
        width = 220, height = 230,
        frame_count = 64, line_length = 8,
        animation_speed = 0.5,
        scale = 0.5,
        shift = util.by_pixel(0.0, -87.5),
      },
    },
    -- electric arcs, only while working, tinted by the module
    {
      render_layer = "object",
      always_draw = false,
      apply_tint = true,
      animation = arcs_layer(),
    },
    -- the same arcs as light, untinted (light doesn't take module tint)
    {
      render_layer = "object",
      always_draw = false,
      apply_tint = false,
      animation = arcs_layer({ draw_as_light = true }),
    },
  },

  module_visualisations = {
    {
      art_style = "vanilla",
      use_for_empty_slots = true,
      tier_offset = 0,
      slots = {
        socket(util.by_pixel(-48.0, 66.0)),
        socket(util.by_pixel(-16.0, 66.0)),
        socket(util.by_pixel(16.0, 66.0)),
        socket(util.by_pixel(48.0, 66.0)),
      },
    },
  },
}

-- Aquilo frost. Freezing is a Space Age feature, and `feature_flags` is the
-- right test rather than mods["space-age"]: the flag is exactly what gates
-- EntityPrototype::heating_energy, which beacon.lua sets on the same
-- condition, and any mod declaring freezing_required turns it on too.
--
-- Numbers are the measured output of make_frozen.py (frozen_numbers.txt).
-- The patch is a plain overlay drawn on top of the sprite while the beacon is
-- frozen, so it carries its own crop box and shift; both come off the same
-- canvas centre as beacon-base.png, which is what keeps them registered.
if feature_flags["freezing"] then
  set.frozen_patch = {
    filename = g .. "beacon-frozen.png",
    width = 308, height = 442, scale = 0.5,
    shift = util.by_pixel(0.0, -36.5),
  }
  -- The rings and crystal are in the patch too, and the ice on them was
  -- rendered against animation frame 0. Pinning the animation there while
  -- frozen is what makes it land on the rings instead of beside them --
  -- vanilla's centrifuge does the same for its drums. It also stops a frozen
  -- machine spinning, which random_animation_offset would otherwise leave it
  -- doing from an arbitrary pose.
  set.reset_animation_when_frozen = true
end

return set
