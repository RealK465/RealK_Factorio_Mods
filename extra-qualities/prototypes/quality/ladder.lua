-- The whole seven-tier ladder in one place: how strong each tier is, and how hard it is to
-- reach. Both were split across files once and both went wrong there, which is why they are
-- here together.

local quality = data.raw.quality

-- ---------------------------------------------------------------------------------------
-- Strength: one constant ratio, all the way up
-- ---------------------------------------------------------------------------------------
--
-- Every tier is about 1.26x the one below it, so no step is ever visibly smaller than an
-- earlier one. Vanilla is not built that way: it is a flat +0.3 of multiplier per level, and
-- because legendary sits two levels above epic that step is +32% where rare -> epic is +19%.
-- Extending vanilla's rule past legendary inherits the unevenness and puts it exactly where
-- it shows most, at the top of the ladder.
--
-- The anchor is an assembling machine 3 at crafting speed 5 on celestial. With that fixed and
-- vanilla's epic -> legendary step left at +32%, no arrangement of the two new tiers alone can
-- keep the steps from shrinking - there is only 1.6x of headroom left to spend over two steps,
-- and 1.6 is less than 1.32 squared. So the ladder is set as a whole rather than bolted onto
-- the end of vanilla's.
--
-- It costs two changed vanilla values, both small: uncommon 1.3 -> 1.28 and epic 1.9 -> 2.0.
-- Rare and legendary keep vanilla's numbers exactly. The result reads as one rule - quality
-- doubles every three tiers - and lands every assembling machine 3 speed on a round number.
--
--   normal 1.25   uncommon 1.6   rare 2   epic 2.5   legendary 3.125   mythic 4   celestial 5
--
-- default_multiplier drives everything that is *multiplied*: crafting speed, inserter speed,
-- inventory size, lab speed, spoil time and every module's strength. `level` is left alone and
-- still drives what is *counted* - equipment grid, pole supply area, accumulator capacity.
-- Changing any of these moves the cost table in .ai-support/balance.md, because stronger
-- quality modules farm quality faster; re-run assets/extra-qualities/balance/qsim.py.

local MULTIPLIER = {
  normal = 1.0,
  uncommon = 1.28,   -- vanilla 1.3
  rare = 1.6,        -- vanilla's own
  epic = 2.0,        -- vanilla 1.9
  legendary = 2.5,   -- vanilla's own
  mythic = 3.2,
  celestial = 4.0,
}

for name, multiplier in pairs(MULTIPLIER) do
  quality[name].default_multiplier = multiplier
end

-- ---------------------------------------------------------------------------------------
-- Reach: the chain, and the odds along it
-- ---------------------------------------------------------------------------------------
--
-- Two extra tiers on the end would push the top of the ladder far past anything vanilla asks
-- for, so the early steps get easier. **Only the first three**, tapering off: from epic upward
-- every step runs at vanilla odds.
--
-- The cap is what makes it three rather than four. Boosts compound, because reaching legendary
-- passes through every step below it, so a modest boost on each of four steps made legendary
-- 2.06x cheaper than vanilla - more of a discount than the owner wanted. Tapering to nothing by
-- epic holds it to 1.58x while still helping the bottom of the ladder, where the climb is
-- longest. Per-tier measurements are in .ai-support/balance.md.
--
-- next_probability is the per-step difficulty knob: the chance of an upgrade is the machine's
-- quality effect times this, so 1.4 turns a 10% quality effect into a 14% chance of stepping
-- up. chain_probability is left at vanilla's 0.1 everywhere - every quality sets it
-- explicitly, so raising next_probability does not drag it along.

quality["normal"].next_probability = 1.4
quality["uncommon"].next_probability = 1.3
quality["rare"].next_probability = 1.1
-- epic -> legendary is deliberately absent: from epic upward the odds are vanilla's.

-- Legendary stops being the end of the chain. Its own step up is left at vanilla odds: past
-- here the 75% loss on every recycling pass is gate enough.
quality["legendary"].next = "mythic"
quality["legendary"].next_probability = 1
quality["legendary"].chain_probability = 0.1
