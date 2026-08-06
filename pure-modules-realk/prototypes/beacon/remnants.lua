-- The wreck a destroyed Pure beacon leaves behind. Numbers are the measured
-- output of assets/pure-modules-realk/entity/beacon/make_remnant.py
-- (remnant_numbers.txt beside it) -- re-check them after a re-render.
--
-- Fields follow cryogenic-plant-remnants, which is the 2.0-era shape for a 5x5
-- building corpse. Note what is deliberately absent: no shadow layer. No
-- vanilla remnant uses draw_as_shadow -- the ground shadow is painted into the
-- colour sprite, and make_remnant.py composites it there.
--
-- No locale key either: vanilla defines none for its own remnants, and the
-- corpse is both selectable_in_game = false and hidden from Factoriopedia, so
-- the name is never rendered.
local sheet = "__pure-modules-realk__/graphics/entity/beacon/remnants/pure-beacon-remnants.png"
local WIDTH, HEIGHT = 438, 432

-- Two variations stacked in one file, picked at random per corpse. `y` indexes
-- into the sheet, which is exactly what base's own
-- make_rotated_animation_variations_from_sheet does -- written out here rather
-- than calling that global, so this does not depend on a helper another mod
-- happens to leave lying around.
local function variation(index)
  return {
    filename = sheet,
    width = WIDTH,
    height = HEIGHT,
    y = HEIGHT * index,
    line_length = 1,
    direction_count = 1,
    shift = util.by_pixel(3.0, -9.5),
    scale = 0.5,
  }
end

data:extend({
  {
    type = "corpse",
    name = "pure-beacon-remnants",
    icon = "__pure-modules-realk__/graphics/icons/pure-beacon.png",
    flags = { "placeable-neutral", "not-on-map" },
    hidden_in_factoriopedia = true,
    subgroup = "energy-pipe-distribution-remnants",
    order = "a-d-b",
    selection_box = { { -2.5, -2.5 }, { 2.5, 2.5 } },
    tile_width = 5,
    tile_height = 5,
    selectable_in_game = false,
    time_before_removed = 60 * 60 * 15, -- 15 minutes
    expires = false,
    final_render_layer = "remnants",
    remove_on_tile_placement = false,
    animation = { variation(0), variation(1) },
  },
})
