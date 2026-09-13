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
--   -anim     the CRAFT loop: the old gear train and its crank slider, the
--             indexing turntable and its lock pin, the transfer arm, the
--             valves, the reacting gauges, the condenser louvres. Plays
--             while the machine crafts and freezes where it stops, like
--             every vanilla assembler                             (64 frames)
--   -run      the REFRIGERATION, slow: condenser fan, compressor flywheel
--             and its motor pulley, the cabinet fan, the compressor's own
--             pressure needle. `always_draw` + `constant_speed`, which the
--             engine plays in EVERY state -- measured 2026-09-13 with a tick
--             sequence: an unpowered machine's constant-speed visualisation
--             moved every tick while its animation and its plain
--             always_draw visualisation stood still. A refrigerator holds
--             temperature whether or not you are using it            (64 frames)
--   -fast-comp, -fast-fan  the same wheels and fan keyed fast, as OPAQUE
--             discs (the base sprite under the parts, cut to the disc they
--             sweep) drawn over the slow ones while the machine works, and
--             faded off when it stops. That is how "slow when idle, fast
--             when working" is done without an idle loop: `idle_animation`
--             does not play, it is drawn at the stopped frame     (64 frames)
--   -shadow   one frame, draw_as_shadow
--   -glow     what the cold cell throws when the machine works: the window's
--             light, the sight glasses, the receiver screen, the relief
--             valve's vent puff. Working only, additive, drawn as glow
--                                                                   (64 frames)
--   -lamp     the three always-on points: the cyan status lamp breathing,
--             the amber running lamp flashing, the violet module-rack point
--             steady. `always_draw` + `constant_speed`, so they pulse while
--             idle too                                              (64 frames)
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
-- craft loop plays at about one frame a tick -- 64 ticks a loop, one index
-- a second -- while the constant-speed layers take 128 ticks a loop
-- (measured: a constant-speed layer returned to its frame after exactly 128
-- ticks). The two rhythms are deliberate: the refrigeration runs at its own
-- pace and the craft at the machine's.
local animation_speed = 0.5

local function sheet(key, opts)
  local t =
  {
    priority = "high",
    frame_count = 64,
    animation_speed = animation_speed,
    scale = 0.5
  }
  for k, v in pairs(opts or {}) do t[k] = v end
  return util.sprite_load(PATH .. key, t)
end

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
  return sheet("lamp", { draw_as_glow = true, blend_mode = "additive" })
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
        -- The refrigeration, always turning: what makes an idle machine read
        -- as cold and waiting rather than as dead. Listed FIRST so the
        -- working-only load layers below draw over it.
        name = "refrigeration",
        always_draw = true,
        constant_speed = true,
        animation = sheet("run")
      },
      {
        -- Under load the wheels and the fan run faster: opaque discs over
        -- the slow layer, faded off when the craft stops so the fan reads as
        -- running down rather than as jumping to its idle angle.
        name = "load-compressor",
        fadeout = true,
        animation = sheet("fast-comp")
      },
      {
        name = "load-condenser",
        fadeout = true,
        animation = sheet("fast-fan")
      },
      {
        -- The cold cell's light. `fadeout` eases it off when the machine
        -- stops instead of cutting; vanilla uses it on every glow that ramps.
        name = "cell-light",
        fadeout = true,
        animation = glow()
      },
      {
        -- The three status points, pulsing in both states: what makes an
        -- idle machine read as powered, and as powered at night.
        name = "status-lamps",
        always_draw = true,
        constant_speed = true,
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
