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

-- Reach is half of what this beacon sells; the transmission cap below is the
-- other half. 10 covers 25x25 tiles against the vanilla beacon's 9x9 -- 625
-- tiles to its 81 -- so one ring of these stands over a whole bank of machines
-- instead of a pair of beacons per machine repeated across the factory.
beacon.supply_area_distance = 10
beacon.module_slots = 4 -- one per socket in the base sprite; the art fixes this

-- Transmission. The engine multiplies the modules a receiver sees by this
-- beacon's distribution_effectivity and by profile[N], N being how many
-- beacons reach that receiver -- so N of them together transmit
-- N * distribution_effectivity * profile[N]:
--
--   1 beacon 1.25x   2 beacons 1.875x   3 beacons 2.8125x   4 or more 2.8125x
--
-- Three is the whole ladder. profile[N] = 2.25/N from there on holds the total
-- exactly flat -- flat whatever distribution_effectivity is, since that is a
-- constant multiplier on every term -- so a fourth beacon draws its full power
-- and adds nothing at all. The cap is arithmetic rather than a special case,
-- which is how vanilla's own 1/sqrt(N) curve works too. The array runs to 100
-- like vanilla's; past the end the last entry repeats, and no 5x5 footprint
-- can put 100 beacons in range of one machine anyway.
--
-- Where that lands, in module-equivalents on one machine -- slots * N *
-- effectivity * profile[N]. Vanilla's two slots reach 8.49 at eight beacons
-- and 10.39 at twelve, its geometric maximum; three of these reach
-- 4 * 2.8125 = 11.25. So this is the strongest transmission available in the
-- game, past the wall of beacons it replaces rather than merely competitive
-- with it, and the power and pollution below are what it is charged for that.
--
-- For scale on how far it has moved: the cap was 1.5x through 1.0.5, worth
-- 6.00 -- less than four vanilla beacons -- so the tier's beacon lost to the
-- beacon it is built out of, and the strongest play was to keep the wall and
-- add these on top of it. That was the opposite of what the reach is for.
beacon.distribution_effectivity = 1.25
beacon.profile = { 1, 0.75, 0.75 }
for n = 4, 100 do
  beacon.profile[n] = 2.25 / n
end

-- Quality. Factoriopedia calls this figure "Beacon transmission strength" and
-- lists it per quality level. 0.35 onto a base of 1.25 lands legendary on 3.0,
-- against the 2.5 a legendary vanilla beacon reaches. Three legendary Pure
-- beacons transmit 6.75x, or 27 module-equivalents. Quality is a separate axis
-- from the beacon count, and the cap above deliberately does not close it --
-- so quality is where the ceiling keeps going up after three beacons stops
-- paying.
beacon.distribution_effectivity_bonus_per_quality_level = 0.35

-- beacon_counter stays "same_type", inherited. Pure beacons count only each
-- other, and vanilla beacons -- "same_type" as well -- go on ignoring them.
-- "total" would be one-sided, since nothing can make the vanilla beacon count
-- ours back. So a factory that wants more than 2.8125x can still ring a
-- machine with ordinary beacons too -- 7.06x all told, against vanilla's own
-- 5.20x maximum -- and pays for it in floor space, beacon power and quality.
--
-- Quality, because a beacon's own allowed_effects is only a placement filter
-- -- "the types of modules that a player can place inside of the beacon". What
-- governs transmission is the *receiver's* allowed_effects, and every crafting
-- machine, lab and drill lists "quality" in it. So speed module 3's -2.5% does
-- leave the beacon it sits in, multiplied by the whole transmission figure on
-- the way out; this file used to claim the reverse. Which makes the tier's
-- missing quality penalty its real selling point rather than a footnote --
-- a Pure beacon full of Pure speed modules is the only way to run a machine
-- hard and still farm quality on it.

-- Power. The base is the transmission cap's own multiplier: the cap has gone
-- 1.5x -> 2.25x -> 2.8125x since 1.0.5 and the base draw has gone 4 -> 6 ->
-- 7.5 MW with it, so the beacon still costs what it always did per unit of
-- effect transmitted. The two module settings are rounded to whole megawatts
-- rather than tracking that factor exactly, because a 3.75 MW rung reads as
-- arithmetic left in by accident. The foundry, at 2.5 MW, is the heaviest
-- crafting machine in the game; this asks three times that before it has
-- transmitted anything, which is the standing cost of the reach. It then
-- climbs with what the beacon is allowed to carry, because each setting widens
-- what a single beacon is worth -- productivity most of all, and productivity
-- is the one no beacon does in the base game.
--
-- Reach is deliberately *not* in that exchange rate, and it is worth naming
-- what that costs. A beacon's power is a fixed sum divided across every
-- machine it covers, so widening the area quietly makes it cheaper per
-- machine: 6 MW over 21x21 was 13.6 kW per tile, and 7.5 MW over 25x25 is
-- 12.0 -- still about twice vanilla's 5.9, but the direction is downward. Any
-- further widening should move this number, not just the cap.
--
-- Written in kilowatts because the quality rung lands on 9.5 MW, and vanilla
-- writes its own big machines the same way ("2500kW", "1500kW").
--
-- This is the normal-quality figure and only that. QualityPrototype carries
-- beacon_power_usage_multiplier, which quality/prototypes/quality.lua sets to
-- 1/6 at legendary, so a legendary Pure beacon costs 1.25 MW while
-- transmitting 3.0x. The vanilla beacon gets the same discount, so this is the
-- engine's balance rather than ours -- but "the reach has a standing cost" is
-- an argument about normal beacons, and the tier's players will be past that.
local kilowatts = 7500
if carries.productivity then
  kilowatts = kilowatts + 4000
end
if carries.quality then
  kilowatts = kilowatts + 2000
end
beacon.energy_usage = kilowatts .. "kW"

-- Pollution, and there is no precedent to copy: not one beacon in the base
-- game, in either expansion, or in any beacon mod surveyed emits any. 2 per
-- megawatt puts the floor at 15/min, which is two and a half times the foundry
-- and the oil refinery, near twice the biolab, and still well short of the big
-- mining drill's 40 -- the dirtiest thing standing on a factory floor without
-- being in the mining drill's league. A beacon runs whether or not the machines
-- under it do, so it is dirty for as long as it is switched on. That is the
-- point of putting it here: the tier's modules already buy a clean effect with
-- pollution, and the beacon that carries them should say the same thing.
--
-- Only Nauvis has pollutant_type = "pollution". Vulcanus, Fulgora and Aquilo
-- have none and Gleba has spores, so this costs nothing off-world -- exactly
-- how vanilla's own machines behave, the foundry included, rather than a gap
-- worth papering over with a second pollutant.
beacon.energy_source.emissions_per_minute = { pollution = 2 * kilowatts / 1000 }

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
