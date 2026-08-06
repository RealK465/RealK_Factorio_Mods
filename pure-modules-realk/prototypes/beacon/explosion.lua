-- The blast a Pure beacon makes when it dies. Vanilla's beacon-explosion is
-- tuned for a 3x3: a medium_explosion animation and particle offsets inside
-- half a tile, which on a 5x5 leaves most of the machine unaccounted for.
--
-- Sized against the cryogenic plant, which is this beacon's stated family and
-- also 5x5: big_explosion() and large_explosion(0.7, 1.0), exactly. Deliberately
-- a step below the nuclear reactor's massive_explosion -- a beacon is a large
-- machine, not a reactor.
--
-- Requiring base's own helper modules is fine, and the repo rule that used to
-- forbid it was wrong. Verified on 2.1.14 with a throwaway mod: the __base__
-- path resolves, relative requires *inside* those base files resolve against
-- base rather than against us, and a base file that has already been loaded
-- comes back from cache instead of re-running (requiring the data-extending
-- prototypes/entity/explosions.lua duplicated nothing). base does this to
-- itself too -- see cargo-hatch.lua.
--
-- The cost is coupling to base's internal file layout, which is not a public
-- API: if Wube moves the file this breaks, though loudly and at load. Prototype
-- names in data.raw are the stabler coupling, so anything that HAS a prototype
-- should still come from table.deepcopy(data.raw[...]) -- as the explosion and
-- the particle below do. These two helpers have no prototype to copy from.
local explosion_animations = require("__base__.prototypes.entity.explosion-animations")
local sounds = require("__base__.prototypes.entity.sounds")

local explosion = table.deepcopy(data.raw["explosion"]["beacon-explosion"])
explosion.name = "pure-beacon-explosion"
explosion.icon = "__pure-modules-realk__/graphics/icons/pure-beacon.png"
explosion.order = "e-a-b"
explosion.animations = explosion_animations.big_explosion()
explosion.sound = sounds.large_explosion(0.7, 1.0)
explosion.smoke_count = 5 -- 2 on the 3x3

-- Scale vanilla's own particle tuning up to the bigger body rather than
-- restating five emitters. 2.75x the tile area, so roughly that many more
-- pieces, thrown from a box that actually covers the machine.
local BODY = 2.6 -- 0.50-0.59 tile deviation -> 1.29-1.54, inside the 2.2 collision box
for _, effect in pairs(explosion.created_effect.action_delivery.target_effects) do
  if effect.type == "create-particle" then
    effect.repeat_count = math.ceil(effect.repeat_count * 2.2)
    local d = effect.offset_deviation
    d.left_top = { d.left_top[1] * BODY, d.left_top[2] * BODY }
    d.right_bottom = { d.right_bottom[1] * BODY, d.right_bottom[2] * BODY }
    effect.speed_from_center = effect.speed_from_center * 1.35
  end
end

-- Shards of the core. The remnant that follows has the shattered crystal lying
-- in its crater, so the blast that made it should be throwing crystal too --
-- and it is the one thing in the explosion that says which beacon just died.
--
-- Vanilla's glass particle is a greyscale sprite, so a tint multiplies straight
-- onto it and no new art is needed. Only `pictures` is tinted: `shadows` is
-- already shadow-tinted and re-tinting it would turn the shadows blue.
local CRYSTAL_TINT = { 0.52, 0.76, 0.95, 1 }

local function tint_sprites(node, tint)
  if type(node) ~= "table" then
    return
  end
  if node.filename then
    node.tint = tint
  end
  for _, child in pairs(node) do
    tint_sprites(child, tint)
  end
end

local shard = table.deepcopy(
  data.raw["optimized-particle"]["damaged-assembling-machine-glass-particle-small"])
shard.name = "pure-beacon-crystal-particle"
tint_sprites(shard.pictures, CRYSTAL_TINT)

local effects = explosion.created_effect.action_delivery.target_effects
effects[#effects + 1] = {
  type = "create-particle",
  repeat_count = 26,
  repeat_count_deviation = 0,
  probability = 1,
  affects_target = false,
  show_in_tooltip = false,
  particle_name = "pure-beacon-crystal-particle",
  offsets = { { 0, 0 } },
  -- tighter than the hull debris: the core sat in the middle, not in the skirt
  offset_deviation = {
    left_top = { -0.7, -0.7 },
    right_bottom = { 0.7, 0.7 },
  },
  -- thrown higher and harder than the plating -- the containment let go first
  initial_height = 1.4,
  initial_height_deviation = 0.6,
  initial_vertical_speed = 0.13,
  initial_vertical_speed_deviation = 0.045,
  speed_from_center = 0.075,
  speed_from_center_deviation = 0.015,
  frame_speed = 1,
  frame_speed_deviation = 0,
  rotate_offsets = false,
}

data:extend({ shard, explosion })
