-- Sprite wiring for the Quality Assembler.
--
-- Deliberately carries no pixel numbers: every width/height/shift lives in the
-- `.lua` sidecar beside its PNG, written by the generator's make_sheets.py and
-- re-written on every render. Vanilla does the same for every entity sprite,
-- and it is what lets the art be re-rendered without touching this file.
--
-- One elevation. An assembling machine's art is not directional -- the engine
-- rotates only the fluid pipe pictures -- so there is one set of sheets:
--
--   -base     the body, one frame, repeat_count 64 to stay in step
--   -anim     the WORKING loop: condenser fan, compressor flywheel, the old
--             gear train and its crank slider, the indexing turntable and
--             the transfer arm                                     (64 frames)
--             (There is deliberately no idle loop. The design wanted the fan
--             turning slowly while idle; measured in the engine 2026-09-13,
--             `idle_animation` does not play -- a machine that is not working
--             is frozen, and the idle sheet is only drawn at the frame the
--             working one stopped on. A second sheet with different fan
--             angles would JUMP the moment the machine stopped.)
--   -shadow   one frame, draw_as_shadow
--   -glow     what the cold cell throws when the machine works: the window's
--             light, the sight glasses, the receiver screen. Working only,
--             additive, drawn as glow                                (64 frames)
--   -lamp     the three always-on points: the cyan status lamp, the amber
--             running lamp and the violet module-rack point. One frame.
--   -pipe-N/S/E/W  the fluid connection stubs the engine draws when a fluid
--             recipe is set. See `pipe_picture` below.
--
-- WHY THE BRIGHT CYAN IS NOT IN THE BASE. `animation` is drawn in every state
-- and only `working_visualisations` are working-only, so an emissive lit in
-- the base lights the IDLE machine. The base carries the dim "cold and
-- waiting" glass; the glow sheet carries the rest. `quality-recycler` shipped
-- that fault once.

local PATH = "__quality-assembler__/graphics/entity/quality-assembler/quality-assembler-"

-- 0.5 frames a tick. A crafting machine's animation is scaled by its crafting
-- speed unless `constant_speed` is set, and this machine runs at 2, so the
-- working loop plays at one frame a tick: 64 ticks a loop, the fan at about
-- five turns a second, the turntable stepping once a second.
local animation_speed = 0.5

local function body(anim_key, anim_speed)
  return
  {
    layers =
    {
      -- The body is one frame; repeat_count keeps it on screen for all 64 of
      -- the animation's, which is what makes a static base legal in a layered
      -- animation rather than a one-frame flash.
      util.sprite_load(PATH .. "base",
      {
        priority = "high",
        repeat_count = 64,
        scale = 0.5
      }),
      -- frame_count goes in the OPTIONS, not the sidecar: util.sprite_load
      -- takes width/height/shift/line_length from the file and everything
      -- else from here, so a frame_count in the sidecar is silently ignored
      -- and the layer loads as a single frame.
      util.sprite_load(PATH .. anim_key,
      {
        priority = "high",
        frame_count = 64,
        animation_speed = anim_speed,
        scale = 0.5
      }),
      util.sprite_load(PATH .. "shadow",
      {
        draw_as_shadow = true,
        priority = "high",
        repeat_count = 64,
        scale = 0.5
      })
    }
  }
end

-- Additive and drawn as glow so it survives nightfall, which is the convention
-- every vanilla glow sheet follows. `scale = 1.0` because the sheet is packed
-- at half resolution: the same display pixels for a quarter of the atlas, and
-- the layer is a 5 px gaussian either way, so there is no detail to lose.
local function glow()
  return util.sprite_load(PATH .. "glow",
  {
    draw_as_glow = true,
    blend_mode = "additive",
    priority = "high",
    frame_count = 64,
    animation_speed = animation_speed,
    scale = 1.0
  })
end

local function lamp()
  return util.sprite_load(PATH .. "lamp",
  {
    draw_as_glow = true,
    blend_mode = "additive",
    priority = "high",
    repeat_count = 64,
    scale = 0.5
  })
end

local function stub(key)
  return util.sprite_load(PATH .. "pipe-" .. key,
  {
    priority = "extra-high",
    scale = 0.5
  })
end

return
{
  graphics_set =
  {
    animation = body("anim", animation_speed),
    working_visualisations =
    {
      {
        -- The cold cell's light. `fadeout` eases it off when the machine
        -- stops instead of cutting; vanilla uses it on every glow that ramps.
        name = "cell-light",
        fadeout = true,
        animation = glow()
      },
      {
        -- The three status points, lit in both states: what makes an idle
        -- machine read as idle rather than as broken, and as powered at night.
        name = "status-lamps",
        always_draw = true,
        animation = lamp()
      }
    }
  },
  -- The fluid connection stubs, keyed by the direction the connection faces
  -- after the entity is rotated. The north one is declared to draw BEHIND the
  -- body (secondary_draw_orders north = -1 in entity.lua), as vanilla's own
  -- assembling machines do, so the part of it under the hull is covered.
  pipe_picture =
  {
    north = stub("N"),
    east = stub("E"),
    south = stub("S"),
    west = stub("W")
  }
}
