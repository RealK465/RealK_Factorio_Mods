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
        width = 40, height = 40, scale = 0.5, shift = shift,
      },
    },
    {
      apply_module_tint = "quaternary",
      render_layer = "lower-object-above-shadow",
      pictures = {
        filename = g .. "beacon-module-mask-lights.png",
        width = 40, height = 40, scale = 0.5, shift = shift,
      },
    },
    {
      apply_module_tint = "quaternary",
      render_layer = "lower-object-above-shadow",
      pictures = {
        filename = g .. "beacon-module-lights.png",
        width = 40, height = 40, scale = 0.5, shift = shift,
        draw_as_light = true,
      },
    },
  }
end

-- The arcs sheet carries its own crop box rather than the rings'. The
-- discharge now starts at the induction coil at the foot of each electrode,
-- so it covers most of the machine's height, and packing it to the rings'
-- box would have grown the far larger anim sheet to match.
local arc_frames = {
  width = 276, height = 378,
  frame_count = 64, line_length = 8,
  animation_speed = 0.5,
  scale = 0.5,
  shift = util.by_pixel(0.5, -60.0),
}

local function arcs_layer(extra)
  local a = table.deepcopy(arc_frames)
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

  -- The core is a contained plasma, so it should read as a light source after
  -- dark and not just as a bright sprite. 0.4/8 lit essentially nothing on the
  -- ground; a lamp is 0.9/40, so this is still a machine glow rather than
  -- lighting. Vanilla's own beacon has this commented out and relies purely on
  -- its draw_as_light sheet -- we do both, because the crystal is the hero.
  light = { shift = { 0, 0 }, color = { 0.55, 0.85, 1.0 }, intensity = 0.8, size = 16 },

  animation_list = {
    -- static plinth + its shadow
    {
      render_layer = "floor-mechanics",
      always_draw = true,
      animation = {
        layers = {
          {
            filename = g .. "beacon-base.png",
            width = 306, height = 448, scale = 0.5,
            shift = util.by_pixel(0.0, -35.0),
          },
          {
            filename = g .. "beacon-shadow.png",
            width = 410, height = 324, scale = 0.5,
            shift = util.by_pixel(25.5, 1.5),
            draw_as_shadow = true,
          },
        },
      },
    },
    -- Deck plant: the holographic readout cycling, cryo vapour off the vent
    -- and the charge running out the two front feeder cables. Its own loop,
    -- same 64 frames at the same speed as the rings -- Factorio draws each
    -- animation_list element independently, so this does not have to be
    -- synced to them, but matching the length is what lets the cable pulses
    -- land on the discharge beat instead of drifting against it.
    --
    -- always_draw, like the rings: an idle beacon is powered, not dead, so
    -- the readout and the vent keep running. It freezes on frame 0, where
    -- both cable pulses are at zero scale -- so an idle beacon shows the
    -- hologram and the vapour but no charge in the cables, which is exactly
    -- the idle state.
    --
    -- Plain alpha rather than additive: the vapour has to cover what is
    -- behind it, which an additive layer cannot do.
    {
      render_layer = "object",
      always_draw = true,
      animation = {
        filename = g .. "beacon-deck.png",
        width = 176, height = 88,
        frame_count = 64, line_length = 8,
        animation_speed = 0.5,
        scale = 0.5,
        shift = util.by_pixel(2.5, -7.5),
      },
    },
    -- rings + crystal, frozen while idle
    {
      render_layer = "object",
      always_draw = true,
      animation = {
        filename = g .. "beacon-anim.png",
        width = 218, height = 222,
        frame_count = 64, line_length = 8,
        animation_speed = 0.5,
        scale = 0.5,
        shift = util.by_pixel(0.0, -86.5),
      },
    },
    -- The crystal and the ring seams AS LIGHT. Rendered as an emission-only
    -- pass (the same geometry as beacon-anim with every lamp in the scene
    -- switched off, so what reaches the film is the emission and nothing
    -- else) and drawn additively into the light layer, which is how vanilla's
    -- own beacon does it with beacon-light.png. The core keeps shining after
    -- dark instead of going flat with the rest of the hull.
    --
    -- always_draw, unlike vanilla's: an idle Pure beacon is powered rather
    -- than dead, so its core is lit whether or not modules are in it.
    -- apply_tint = false because light does not take the module tint.
    --
    -- scale = 1.0, not 0.5: the sheet is packed at half the source resolution
    -- the other layers use. It is a wide gaussian with no detail in it, so
    -- half res costs nothing visible and saves three quarters of the atlas.
    {
      render_layer = "object",
      always_draw = true,
      apply_tint = false,
      animation = {
        filename = g .. "beacon-glow.png",
        width = 111, height = 113,
        frame_count = 64, line_length = 8,
        animation_speed = 0.5,
        scale = 1.0,
        shift = util.by_pixel(0.0, -87.5),
        draw_as_light = true,
        blend_mode = "additive",
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
    width = 306, height = 438, scale = 0.5,
    shift = util.by_pixel(0.0, -37.0),
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
