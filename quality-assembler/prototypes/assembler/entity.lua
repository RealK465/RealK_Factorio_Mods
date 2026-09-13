-- The Quality Assembler entity.
--
-- Built from scratch rather than deep-copied from `assembling-machine-3`: a
-- deepcopy carries a working sound, a status light and a circuit connector
-- positioned for a different machine, and nothing warns when one of them
-- lands in the wrong place. Everything vanilla-shaped here is required by
-- file instead.
--
-- The numbers are in `.ai-support/decisions.md`; the ones chosen here for
-- the first time (health, pollution) are marked.

-- `sounds` and `hit_effects` are globals inside base's own data stage, not for
-- mods; requiring the files gives the same tables back.
local sounds = require("__base__.prototypes.entity.sounds")
local hit_effects = require("__base__.prototypes.entity.hit-effects")
local assembler_pictures = require("__base__.prototypes.entity.assembler-pictures")
local pictures = require("prototypes.assembler.pictures")

local function fluid_box(kind, direction, position)
  return
  {
    production_type = kind,
    pipe_picture = pictures.pipe_picture,
    pipe_covers = pipecoverspictures(),
    volume = 1000,
    pipe_connections =
    {
      { flow_direction = kind, direction = direction, position = position }
    },
    -- the stub on the north side is drawn behind the body, as vanilla's
    -- assembling machines draw theirs
    secondary_draw_orders = { north = -1 }
  }
end

data:extend({
  {
    type = "assembling-machine",
    name = "quality-assembler",
    icon = "__quality-assembler__/graphics/icons/quality-assembler.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.2, result = "quality-assembler"},
    max_health = 400,                      -- chosen: assembling machine 3's 400
    corpse = "big-remnants",
    dying_explosion = "big-explosion",
    icon_draw_specification = {shift = {0, -0.3}},
    alert_icon_shift = util.by_pixel(0, -12),
    impact_category = "metal",
    -- The vanilla assembler's connector: same 3x3, and the design puts
    -- nothing on its south-east corner but the condenser skid's top.
    circuit_wire_max_distance = assembling_machine_circuit_wire_max_distance,
    circuit_connector = assembler_pictures.circuit_connector,
    resistances =
    {
      { type = "fire", percent = 70 }
    },

    -- 3x3, the assembling machine 3's boxes exactly, and fast-replaceable
    -- with the vanilla assemblers: an upgrade planner swaps one in over an
    -- assembling machine 3 and keeps the recipe, the modules and the inserters.
    collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    -- 0.7 covers the art's 0.68 tiles of north overhang, the way the
    -- assembling machine 3's 0.2 covers its own.
    drawing_box_vertical_extension = 0.7,
    damaged_trigger_effect = hit_effects.entity(),
    fast_replaceable_group = "assembling-machine",

    graphics_set = pictures.graphics_set,
    water_reflection = assembler_pictures.water_reflection,

    -- The assembling machine 3's three categories exactly. Not the expansion
    -- machines' -- each of those belongs to one machine whose identity is
    -- being the only thing that runs it.
    crafting_categories = {"crafting", "advanced-crafting", "crafting-with-fluid"},
    crafting_speed = 2,                    -- the electromagnetic plant's; 1.6x an AM3
    -- Required by crafting-with-fluid: the vanilla shape, input north and
    -- output south, both gone on a dry recipe. These two tiles are pipe
    -- attachment points in every rotation, which is why the art keeps the
    -- north and south mid-edges low.
    fluid_boxes =
    {
      fluid_box("input", defines.direction.north, {0, -1}),
      fluid_box("output", defines.direction.south, {0, 1})
    },
    fluid_boxes_off_when_no_fluid_recipe = true,

    -- The mechanic. `effect_receiver.base_effect.quality` is a permanent,
    -- module-free bonus -- the same field a quality module writes, carried by
    -- the machine itself. The electromagnetic plant does exactly this with
    -- productivity 0.5. 12% is what five normal quality module 3s give, and
    -- it is the number the sibling quality-recycler carries.
    effect_receiver = { base_effect = { quality = 0.12 } },
    module_slots = 5,                      -- the electromagnetic plant's
    -- The assembling machine 3's effects exactly, productivity included:
    -- assembling returns nothing for free, so there is nothing to exploit.
    allowed_effects = {"consumption", "speed", "productivity", "pollution", "quality"},

    -- 800kW per unit of crafting speed. The assembling machine 3 pays 300,
    -- the electromagnetic plant 1000 for its free productivity; a free 12%
    -- quality sits with the recycler at 800. Per item crafted that is 2.7x
    -- an assembling machine 3's electricity.
    energy_usage = "1600kW",
    energy_source =
    {
      type = "electric",
      usage_priority = "secondary-input",
      emissions_per_minute = { pollution = 3 }   -- chosen: AM3 2, EM plant 4
    },

    -- The assembling machine 3's own loop, at the volume it ships with.
    -- Accents synced to this machine's own animation are open work.
    working_sound =
    {
      sound = {filename = "__base__/sound/assembling-machine-t3-1.ogg", volume = 0.45, audible_distance_modifier = 0.5},
      fade_in_ticks = 4,
      fade_out_ticks = 20
    },
    open_sound = sounds.machine_open,
    close_sound = sounds.machine_close
  }
})
