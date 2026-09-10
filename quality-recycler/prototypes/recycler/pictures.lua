-- Sprite wiring for the Quality Recycler.
--
-- Deliberately carries no pixel numbers: every width/height/shift lives in the
-- `.lua` sidecar beside its PNG, written by the generator's make_sheets.py and
-- re-written on every render. Vanilla does the same for every entity sprite,
-- and it is what lets the art be re-rendered without touching this file.
--
-- Four layers per direction rather than vanilla's two. The vanilla recycler
-- animates its whole body (recycler-N.png is 1360x2432 for one direction), so
-- it needs only a picture and a shadow; this splits the static body from a
-- 64-frame overlay of the parts that actually move, which is far smaller and
-- is what the sprite-layer convention is for.

local PATH = "__quality-recycler__/graphics/entity/quality-recycler/quality-recycler-"

-- The rotor turns once per loop and the jaw rollers three times. 4 is what the
-- vanilla recycler runs its own 64-frame loop at, so the two machines read at
-- the same tempo standing side by side.
local animation_speed = 4

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
      -- takes width/height/shift/line_length from the file and everything
      -- else from here, so a frame_count in the sidecar is ignored and the
      -- layer loads as a single frame. Vanilla's recycler-pictures.lua does
      -- exactly this.
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

-- Additive, and drawn as glow so it survives nightfall: the violet field slots,
-- the green status lamps and the amber beacon. Each of those sits on more than
-- one face -- south, north and the housing roof -- because a south-facing
-- emissive points away from the camera once the machine faces south and renders
-- as a one-pixel line east and west. `scale = 1.0` because the sheet is packed at half
-- resolution -- it is a 5 px gaussian either way, so there is no detail to
-- lose and it costs a quarter of the atlas.
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
        -- Only while it is running: idle shows the green status lamp in the
        -- base sprite and nothing else, which is the vanilla convention and
        -- the whole reason idle and working read apart without zooming.
        north_animation = lights(prefix .. "N"),
        east_animation  = lights(prefix .. "E"),
        south_animation = lights(prefix .. "S"),
        west_animation  = lights(prefix .. "W")
      }
    }
  }
end

return
{
  graphics_set = graphics_set(""),
  graphics_set_flipped = graphics_set("flipped-")
}
