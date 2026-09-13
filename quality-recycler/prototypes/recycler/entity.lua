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

    -- 4x4. collision 3.4 is the vanilla 4x4 convention -- the electromagnetic
    -- plant measures it. The drawing-box extension is what the entity tooltip
    -- and info GUI use to frame a sprite taller than its box; 0.8 covers the
    -- art's 0.77 tiles of north overhang, as the EM plant's 0.7 covers its own.
    collision_box = {{-1.7, -1.7}, {1.7, 1.7}},
    selection_box = {{-2, -2}, {2, 2}},
    drawing_box_vertical_extension = 0.8,
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
    crafting_speed = 1.25,                 -- 2.5x the vanilla recycler's 0.5; assembler 3's
    source_inventory_size = 1,
    -- 25 output slots, not the vanilla recycler's 12: the owner's floor, and
    -- data-final-fixes.lua raises it further to the widest recycling recipe
    -- another mod defines (Krastorio 2 Spaced Out makes scrap 13 results).
    result_inventory_size = 25,

    -- The mechanic. `effect_receiver.base_effect.quality` is a permanent,
    -- module-free bonus -- the same field a quality module writes, carried by
    -- the machine itself. The electromagnetic plant does exactly this with
    -- productivity 0.5. 12.5% is what five normal quality module 3s give.
    -- 1.25, not main's 0.125: quality effect values are ten times larger in
    -- 2.0 prototype definitions. Vanilla's own quality-module-1 is
    -- `quality = 0.1` here against `0.01` on 2.1, and both display 1%. Written
    -- at 0.125 this machine would load clean, dump clean, and hand out 1.25%.
    -- (The owner's call of 2026-09-13, up from 1.2, matched with the assembler.)
    effect_receiver = { base_effect = { quality = 1.25 } },
    module_slots = 5,                      -- the electromagnetic plant's
    -- No productivity, matching the vanilla recycler: recycling returns a
    -- fraction of what went in, and a productivity bonus on that would be
    -- free matter.
    allowed_effects = {"consumption", "speed", "pollution", "quality"},
    fast_transfer_modules_into_module_slots_only = true,

    -- 800kW per unit of crafting speed. The vanilla recycler pays 360, the
    -- foundry 625, the electromagnetic plant 1000 for its free productivity;
    -- a free 12.5% quality sits with the plant. Per item recycled that is 2.2x
    -- the recycler's electricity, against the plant's 3.3x over an
    -- assembler 3. Numbers in `.ai-support/decisions.md`.
    energy_usage = "1000kW",
    energy_source =
    {
      type = "electric",
      usage_priority = "secondary-input",
      emissions_per_minute = { pollution = 7.5 } -- owner's call: recycler 2, cryogenic plant 6
    },

    -- Where the machine places its RESULTS: the tile past the north edge,
    -- exactly like a mining drill's drop position -- this is what the yellow
    -- alt-mode arrow points at, and the art's output port is built on it. A
    -- 4x4's centre is a tile corner, so x 0 would sit on the boundary between
    -- the two centre tiles. -0.35 is the vanilla recycler's own offset for the
    -- same problem: inside the west tile (mirrored, the east one), and far
    -- enough off the seam that the arrow reads on one tile. -0.15 was tried
    -- and a player with a chest on each tile could not tell which one.
    vector_to_place_result = {-0.35, -2.3},

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
      sound = {filename = "__quality__/sound/recycler/recycler-loop.ogg", volume = 0.75},
      max_sounds_per_prototype = 2,
      fade_in_ticks = 4,
      fade_out_ticks = 20
    },
    open_sound = sounds.metal_large_open,
    close_sound = sounds.metal_large_close,

    resistances = {{ type = "fire", percent = 80 }}
  }
})
