-- The Pure beacon: a 5x5 wide-area beacon. It takes every *tier* of speed and
-- efficiency module, vanilla and Pure alike; productivity and quality are two
-- settings, off by default, and while they are off those modules are refused
-- admission rather than let in to do nothing. The visual and lore design
-- lives in .ai-support/pure-beacon-design.md.
local units = require("prototypes.shared.science-units")
local aquilo = require("prototypes.shared.aquilo")
local space_age = mods["space-age"] ~= nil

local carries = require("prototypes.shared.beacon-effects")

local beacon = table.deepcopy(data.raw["beacon"]["beacon"])
beacon.name = "pure-beacon"
beacon.icon = "__pure-modules-realk__/graphics/icons/pure-beacon.png"
beacon.minable = { mining_time = 0.5, result = "pure-beacon" }
beacon.fast_replaceable_group = nil -- not swappable with the 3x3 vanilla beacon
beacon.max_health = 600
beacon.collision_box = { { -2.2, -2.2 }, { 2.2, 2.2 } }
beacon.selection_box = { { -2.5, -2.5 }, { 2.5, 2.5 } }
-- sprite top is ~4.9 tiles above the entity centre (pylon tips)
beacon.drawing_box_vertical_extension = 2.4

-- Reach is what this beacon sells, because its strength is capped at three of
-- them. 8 covers 21x21 tiles against the vanilla beacon's 9x9: one ring of
-- beacons over a whole bank of machines, instead of a pair of beacons per
-- machine repeated across the factory.
beacon.supply_area_distance = 8
beacon.module_slots = 4 -- one per socket in the base sprite; the art fixes this

-- Transmission. The engine multiplies the modules a receiver sees by this
-- beacon's distribution_effectivity and by profile[N], N being how many
-- beacons reach that receiver -- so N of them together transmit
-- N * distribution_effectivity * profile[N]:
--
--   1 beacon 1.00x    2 beacons 1.25x    3 beacons 1.50x    4 or more 1.50x
--
-- Three is the whole ladder. profile[N] = 1.5/N from there on holds the total
-- exactly flat, so a fourth beacon draws its full power and adds nothing at
-- all -- the cap is arithmetic rather than a special case, which is how
-- vanilla's own 1/sqrt(N) curve works too. The array runs to 100 like
-- vanilla's; past the end the last entry repeats, and no 5x5 footprint can put
-- 100 beacons in range of one machine anyway.
beacon.distribution_effectivity = 1.0
beacon.profile = { 1, 0.625, 0.5 }
for n = 4, 100 do
  beacon.profile[n] = 1.5 / n
end

-- Vanilla adds 0.2 per quality level onto a base of 1.5, so a legendary beacon
-- transmits 1.67x what a normal one does. 0.1 onto a base of 1.0 keeps that
-- shape at this beacon's scale: legendary reaches 1.5, and three legendary
-- Pure beacons transmit 2.25x. Quality is a separate axis from the beacon
-- count, and the cap above deliberately does not close it.
beacon.distribution_effectivity_bonus_per_quality_level = 0.1

-- beacon_counter stays "same_type", inherited. Pure beacons count only each
-- other, and vanilla beacons -- "same_type" as well -- go on ignoring them.
-- "total" would be one-sided, since nothing can make the vanilla beacon count
-- ours back. So a factory that wants more than 1.5x can still ring a machine
-- with ordinary beacons too, and pays for it in floor space and beacon power.
-- Not in quality: a vanilla beacon's allowed_effects has no "quality" in it,
-- and EffectTypeLimitation restricts "both effects from modules and from
-- surrounding beacons", so speed module 3's -2.5% never leaves the beacon it
-- sits in. Beaconed speed has never cost quality; only in-machine speed does.

-- Power. The foundry, at 2.5 MW, is the heaviest draw in the game; this asks
-- more than that before it has transmitted anything, which is the standing
-- cost of the reach. It then climbs with what the beacon is allowed to carry,
-- because each setting widens what a single beacon is worth -- productivity
-- most of all, and productivity is the one no beacon does in the base game.
--
-- This is the normal-quality figure and only that. QualityPrototype carries
-- beacon_power_usage_multiplier, which quality/prototypes/quality.lua sets to
-- 1/6 at legendary, so a legendary Pure beacon costs 667 kW while transmitting
-- 1.5x. The vanilla beacon gets the same discount, so this is the engine's
-- balance rather than ours -- but "the reach has a standing cost" is an
-- argument about normal beacons, and the tier's players will be past that.
local megawatts = 4
if carries.productivity then
  megawatts = megawatts + 2
end
if carries.quality then
  megawatts = megawatts + 1
end
beacon.energy_usage = megawatts .. "MW"

-- Beacons cannot transmit productivity or quality in vanilla; both are large
-- enough swings to be opt-in. allowed_effects decides what is transmitted,
-- allowed_module_categories decides who gets in -- and that whitelist is built
-- in data-final-fixes, where every module category finally exists.
beacon.allowed_effects = { "consumption", "speed", "pollution" }
if carries.productivity then
  beacon.allowed_effects[#beacon.allowed_effects + 1] = "productivity"
end
if carries.quality then
  beacon.allowed_effects[#beacon.allowed_effects + 1] = "quality"
end
beacon.allowed_module_categories = nil -- every tier, vanilla and Pure alike

beacon.graphics_set = require("prototypes.beacon.graphics")
beacon.corpse = "pure-beacon-remnants"
beacon.dying_explosion = "pure-beacon-explosion"

-- Alt-mode module icons: four across, matching the four sockets on the base.
-- The inherited entry is a 2x2 block sized for the vanilla beacon's two slots.
-- Clearing the height modifier restores the prototype default rather than
-- removing the field, which is fine -- it only means anything to a second row,
-- and four across never has one.
beacon.icons_positioning[1].max_icons_per_row = 4
beacon.icons_positioning[1].multi_row_initial_height_modifier = nil

-- The inherited reflection is drawn for a 3x3 beacon. Scaling it by the
-- footprint ratio at least gets the size right; it is the one piece of this
-- entity's art still borrowed from vanilla, and it only ever shows on a
-- shoreline.
beacon.water_reflection.pictures.scale = 8
beacon.water_reflection.pictures.shift = util.by_pixel(0, 88)

-- What actually makes the beacon freeze on Aquilo: "This entity can freeze if
-- heating_energy is larger than zero." Without it the frost overlay in
-- graphics.lua would be dead weight, because the frozen state it draws in
-- could never happen. The property is gated behind the freezing feature flag,
-- so the flag -- not mods["space-age"] -- is the thing to test; declaring
-- freezing_required in info.json would enable it here too, at the cost of
-- making the whole mod require the expansion, which it deliberately does not.
--
-- 600kW because vanilla's 3x3 beacon asks 400kW, the highest heating figure in
-- the game -- Space Age's own 5x5 machines ask between 100 and 300. A beacon
-- radiating over a wider area asks more than the small one, not less.
if feature_flags["freezing"] then
  beacon.heating_energy = "600kW"
end

local item = {
  type = "item",
  name = "pure-beacon",
  icon = "__pure-modules-realk__/graphics/icons/pure-beacon.png",
  subgroup = "module",
  order = "a[beacon]-b[pure-beacon]",
  inventory_move_sound = data.raw["item"]["beacon"].inventory_move_sound,
  pick_sound = data.raw["item"]["beacon"].pick_sound,
  drop_sound = data.raw["item"]["beacon"].drop_sound,
  place_result = "pure-beacon",
  -- Space Age's own big machines -- foundry, cryogenic plant, electromagnetic
  -- plant -- all stack to 20 at 200 kg, five to a rocket. This is one of them.
  stack_size = 20,
  weight = 200 * kg,
}

-- The beacon is the gate the module technologies sit behind, so it cannot be
-- built out of Pure modules the way the first draft was. Under Space Age it
-- asks for one thing off every planet instead -- tungsten from Vulcanus,
-- carbon fibre from Gleba, a supercapacitor from Fulgora, a quantum processor
-- from Aquilo -- which states the tier's place in the game in ingredients
-- rather than only in a research cost. Without the expansion there are no
-- planets to ask for and it stays at the end of the base-game tree.
local ingredients = {
  { type = "item", name = "beacon", amount = 4 }, -- one per pylon
  { type = "item", name = "processing-unit", amount = 20 },
  { type = "item", name = "refined-concrete", amount = 20 },
}
if space_age then
  ingredients[#ingredients + 1] = { type = "item", name = "tungsten-plate", amount = 20 }
  ingredients[#ingredients + 1] = { type = "item", name = "carbon-fiber", amount = 20 }
  ingredients[#ingredients + 1] = { type = "item", name = "supercapacitor", amount = 10 }
  ingredients[#ingredients + 1] = { type = "item", name = "quantum-processor", amount = 5 }
else
  ingredients[#ingredients + 1] = { type = "item", name = "low-density-structure", amount = 10 }
end

local recipe = aquilo.restrict({
  type = "recipe",
  name = "pure-beacon",
  enabled = false,
  -- Space Age moves the vanilla beacon into "electronics", a category both the
  -- assemblers and the electromagnetic plant carry.
  category = space_age and "electronics" or nil,
  energy_required = 30,
  ingredients = ingredients,
  results = { { type = "item", name = "pure-beacon", amount = 1 } },
})

local technology = {
  type = "technology",
  name = "pure-beacon",
  icon = "__pure-modules-realk__/graphics/technology/pure-beacon.png",
  icon_size = 256,
  effects = { { type = "unlock-recipe", recipe = "pure-beacon" } },
  prerequisites = space_age and { "effect-transmission", "quantum-processor" }
    or { "effect-transmission", "space-science-pack" },
  unit = units.beacon(),
  order = "a[beacon]-b[pure-beacon]",
}

data:extend({ beacon, item, recipe, technology })
