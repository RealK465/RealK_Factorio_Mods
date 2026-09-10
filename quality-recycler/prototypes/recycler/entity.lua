-- The Quality Recycler entity.
--
-- Built from scratch rather than deep-copied from `data.raw["furnace"]["recycler"]`.
-- A deepcopy would have carried the vanilla recycler's 2x4 collision box, its
-- circuit connector definitions, its frame-synced working sound and its
-- `vector_to_place_result`, every one of which is positioned for a machine
-- this one is not the shape of -- and a status light or connector left over
-- from a deepcopy lands in the wrong place with nothing to warn you.
--
-- The numbers are in `.ai-support/decisions.md`; the ones chosen here for the
-- first time are marked.

-- `sounds` and `hit_effects` are globals inside base's own data stage, not for
-- mods; requiring the files gives the same tables back and is what every
-- vanilla-derived mod does.
local sounds = require("__base__.prototypes.entity.sounds")
local hit_effects = require("__base__.prototypes.entity.hit-effects")
local pictures = require("prototypes.recycler.pictures")

data:extend({
  {
    type = "furnace",
    name = "quality-recycler",
    icon = "__quality-recycler__/graphics/icons/quality-recycler.png",
    icon_size = 64,
    flags = {"placeable-neutral", "placeable-player", "player-creation"},
    minable = {mining_time = 0.4, result = "quality-recycler"},
    max_health = 400,                      -- chosen: recycler 300, EM plant 350
    corpse = "big-remnants",
    dying_explosion = "big-explosion",
    impact_category = "metal",
    fast_replaceable_group = "quality-recycler",

    -- 3x3. collision 2.4 is the vanilla 3x3 convention -- chemical plant and
    -- biochamber both measure it.
    collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    damaged_trigger_effect = hit_effects.entity(),

    -- Rotatable, four directions plus mirrored: the full vanilla recycler
    -- treatment, and the reason the art is massed as a cone.
    --
    -- No `use_mirroring` here, unlike main: the property is 2.1-only (2.0 has
    -- `forced_symmetry`, a different `Mirroring` enum) and vanilla 2.0's own
    -- recycler drives its mirrored art from `graphics_set_flipped` alone. The
    -- data stage IGNORES properties it does not recognise, so leaving it in
    -- would load clean and silently do nothing.
    graphics_set = pictures.graphics_set,
    graphics_set_flipped = pictures.graphics_set_flipped,

    crafting_categories = {"recycling"},
    crafting_speed = 1.0,                  -- 2x the vanilla recycler's 0.5
    source_inventory_size = 1,
    result_inventory_size = 12,

    -- The mechanic. `effect_receiver.base_effect.quality` is a permanent,
    -- module-free bonus -- the same field a quality module writes, carried by
    -- the machine itself. The electromagnetic plant does exactly this with
    -- productivity 0.5.
    -- 1.2, not main's 0.12: quality effect values are ten times larger in 2.0
    -- prototype definitions. Vanilla's own quality-module-1 is `quality = 0.1`
    -- here against `0.01` on 2.1, and both display 1%. Written at 0.12 this
    -- machine would load clean, dump clean, and hand out 1.2%.
    effect_receiver = { base_effect = { quality = 1.2 } },
    module_slots = 4,
    -- No productivity, matching the vanilla recycler: recycling returns a
    -- fraction of what went in, and a productivity bonus on that would be
    -- free matter.
    allowed_effects = {"consumption", "speed", "pollution", "quality"},
    fast_transfer_modules_into_module_slots_only = true,

    energy_usage = "600kW",                -- chosen: recycler 180kW at half the speed
    energy_source =
    {
      type = "electric",
      usage_priority = "secondary-input",
      emissions_per_minute = { pollution = 4 }   -- chosen: recycler 2, EM plant 4
    },

    -- Where the shredded output lands when a player mines the machine. The
    -- vanilla recycler's {-0.35, -2.3} is measured against its own 2x4 body
    -- and would drop items outside a 3x3.
    vector_to_place_result = {0, -1.8},

    custom_input_slot_tooltip_key = "recycler-input-slot-tooltip",
    cant_insert_at_source_message_key = "inventory-restriction.cant-be-recycled",
    icon_draw_specification = {shift = {0, -0.4}},
    icons_positioning =
    {
      {inventory_index = defines.inventory.crafter_modules, shift = {0, 0.35}}
    },
    perceived_performance = {maximum = 4},

    -- The vanilla recycler's loop, which this machine has earned the right to
    -- by being one. Its sound_accents are deliberately NOT copied: they are
    -- frame-synced to a jaw that bites on frames 14/20/45/60-63, and this
    -- entity's jaw is three counter-rotating rollers with no bite at all.
    -- Sounds are open work -- see `.ai-support/deferred.md`.
    working_sound =
    {
      sound = {filename = "__recycler__/sound/recycler/recycler-loop.ogg", volume = 0.75},
      max_sounds_per_prototype = 2,
      fade_in_ticks = 4,
      fade_out_ticks = 20
    },
    open_sound = sounds.metal_large_open,
    close_sound = sounds.metal_large_close,

    resistances = {{ type = "fire", percent = 80 }}
  }
})
