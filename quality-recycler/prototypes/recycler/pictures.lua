-- Sprite wiring for the Quality Recycler.
--
-- Deliberately carries no pixel numbers: every width/height/shift lives in the
-- `.lua` sidecar beside its PNG, written by the generator's make_sheets.py and
-- re-written on every render. Vanilla does the same for every entity sprite,
-- and it is what lets the art be re-rendered without touching this file.
--
-- Six layers per direction where vanilla's recycler ships two. It animates its
-- whole body (recycler-N.png is 1360x2432 for ONE direction, 13 MB of VRAM),
-- so a picture and a shadow are all it needs. This splits the static body from
-- overlays of only the parts that move, which is far cheaper and is what the
-- layer convention exists for:
--
--   -<D>          the body, one frame, repeat_count 64 to stay in step
--   -<D>-anim     rotor, drive wheel, rollers, fan, feeder ram   (64 frames)
--   -<D>-shadow   one frame, draw_as_shadow
--   -<D>-fx       the fragments in flight                        (64 frames)
--   -<D>-light    every emissive: field, arcs, scan, lenses      (64 frames)
--   -<D>-lamp     the green status lamp alone, one frame
--
-- WHY fx AND anim ARE NOT THE SAME SHEET. `anim` is a LAYER of `animation`, so
-- the engine draws it always and merely stops advancing it when the machine
-- idles -- which is right for a rotor, whose parked pose is part of the idle
-- design. The fragments must vanish instead: a chip frozen in mid-air over a
-- stopped machine is a bug you cannot un-see. So they are a
-- working_visualisation, which is drawn only while the machine is working.
--
-- WHY THE LAMP IS ITS OWN SHEET. `always_draw` keeps it lit in both states, so
-- the idle machine still reads as powered at night. It is one frame of a few
-- dozen pixels -- the cheapest layer on the entity.

local PATH = "__quality-recycler__/graphics/entity/quality-recycler/quality-recycler-"

-- 2, where the vanilla recycler uses 4. A crafting machine's animation is
-- scaled by its crafting speed unless `constant_speed` is set, and this machine
-- runs at 1.0 against the recycler's 0.5. At 4 it would play at twice the
-- recycler's apparent tempo standing next to one; at 2 they read alike.
-- Per-frame rotor rotation is then 0.80 degrees against a 25.7-degree pole
-- pitch, so it cannot wagon-wheel backwards.
local animation_speed = 2

local function direction(key)
  return
  {
    layers =
    {
      -- The body is one frame; repeat_count keeps it on screen for all 64 of
      -- the animation's, which is what makes a static base legal in a layered
      -- animation rather than a one-frame flash.
      util.sprite_load(PATH .. key,
      {
        priority = "high",
        repeat_count = 64,
        scale = 0.5
      }),
      -- frame_count goes in the OPTIONS, not the sidecar: `util.sprite_load`
      -- takes width/height/shift/line_length from the file and everything else
      -- from here, so a frame_count in the sidecar is ignored and the layer
      -- loads as a single frame. Vanilla's recycler-pictures.lua does the same.
      util.sprite_load(PATH .. key .. "-anim",
      {
        priority = "high",
        frame_count = 64,
        animation_speed = animation_speed,
        scale = 0.5
      }),
      util.sprite_load(PATH .. key .. "-shadow",
      {
        draw_as_shadow = true,
        priority = "high",
        repeat_count = 64,
        scale = 0.5
      })
    }
  }
end

local function fx(key)
  return util.sprite_load(PATH .. key .. "-fx",
  {
    priority = "high",
    frame_count = 64,
    animation_speed = animation_speed,
    scale = 0.5
  })
end

-- Additive and drawn as glow so it survives nightfall, which is the convention
-- every vanilla glow sheet follows -- the recycler, the electromagnetic plant,
-- the cryogenic plant and the fusion reactor are all `draw_as_glow` plus
-- `blend_mode = "additive"` with the colour baked into the PNG and no tint.
-- `scale = 1.0` because the sheet is packed at half resolution: it covers the
-- same display pixels for a quarter of the atlas, and the layer is a 5 px
-- gaussian either way, so there is no detail to lose.
local function lights(key)
  return util.sprite_load(PATH .. key .. "-light",
  {
    draw_as_glow = true,
    blend_mode = "additive",
    priority = "high",
    frame_count = 64,
    animation_speed = animation_speed,
    scale = 1.0
  })
end

local function lamp(key)
  return util.sprite_load(PATH .. key .. "-lamp",
  {
    draw_as_glow = true,
    blend_mode = "additive",
    priority = "high",
    repeat_count = 64,
    scale = 0.5
  })
end

local function graphics_set(prefix)
  return
  {
    animation =
    {
      north = direction(prefix .. "N"),
      east  = direction(prefix .. "E"),
      south = direction(prefix .. "S"),
      west  = direction(prefix .. "W")
    },
    working_visualisations =
    {
      {
        -- The chips the rotor throws. No `always_draw`, so they are gone the
        -- moment the machine stops rather than hanging in the air.
        name = "fragments",
        north_animation = fx(prefix .. "N"),
        east_animation  = fx(prefix .. "E"),
        south_animation = fx(prefix .. "S"),
        west_animation  = fx(prefix .. "W")
      },
      {
        -- The field, the arcs, the scan sweep and the five quality lenses.
        -- `fadeout` is what makes the light EASE off when the machine stops
        -- instead of cutting; vanilla uses it on every glow that has to ramp.
        name = "field",
        fadeout = true,
        north_animation = lights(prefix .. "N"),
        east_animation  = lights(prefix .. "E"),
        south_animation = lights(prefix .. "S"),
        west_animation  = lights(prefix .. "W")
      },
      {
        -- The status lamp, lit in both states. This is what makes idle read as
        -- idle rather than as broken.
        name = "status-lamp",
        always_draw = true,
        north_animation = lamp(prefix .. "N"),
        east_animation  = lamp(prefix .. "E"),
        south_animation = lamp(prefix .. "S"),
        west_animation  = lamp(prefix .. "W")
      }
    }
  }
end

return
{
  graphics_set = graphics_set(""),
  graphics_set_flipped = graphics_set("flipped-")
}
