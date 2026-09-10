# Balance — Extra Qualities

The ladder's numbers and the rule they serve. Edited in place. The engine mechanics these rest
on are in `analysis/quality-roll-mechanics.md`; the model that produced the costs is described
at the bottom.

## The design rule

**Each tier should cost roughly what the tier below it costs in vanilla, at the point the
player unlocks it.**

Two extra tiers bolted onto the end of the ladder would put the top of it far past anything
vanilla asks for, because every step costs about 3.5x the one below. The owner's answer was to
make the older tiers easier by the amount the new ones add, and that rule is what "easier by
how much" resolves to. It lands mythic-on-Aquilo at what legendary-on-Aquilo costs today.

## Strength: one constant ratio

**The anchor is the owner's: an assembling machine 3 must reach crafting speed 5 on
celestial.** The rule that gets there is **one constant ratio of about 1.26 across all seven
tiers**, set as a table in `prototypes/quality/ladder.lua`.

| Quality | level | multiplier | asm-3 speed | step | quality module 3 | vs vanilla |
|---|---|---|---|---|---|---|
| normal | 0 | 1.0 | 1.25 | — | 2.5% | unchanged |
| uncommon | 1 | 1.28 | 1.6 | +28% | 3.2% | was 1.3 |
| rare | 2 | 1.6 | 2 | +25% | 4% | unchanged |
| epic | 3 | 2.0 | 2.5 | +25% | 5% | was 1.9 |
| legendary | 5 | 2.5 | 3.125 | +25% | 6.25% | unchanged |
| mythic | 6 | 3.2 | 4 | +28% | 8% | — |
| celestial | 8 | 4.0 | 5 | +25% | 10% | — |

No step is smaller than an earlier one, proportionally or absolutely (+0.35, +0.4, +0.5,
+0.625, +0.875, +1.0). The ladder reads as one rule — **quality doubles every three tiers** —
and every assembling machine 3 speed lands on a round number.

### Why the vanilla tiers had to move

**Vanilla is not a constant ratio.** It is a flat +0.3 of multiplier per level, and legendary
sits *two* levels above epic, so that step is +32% where rare → epic is +19%. Extending that
rule past legendary inherits the unevenness and puts it where it shows most.

With celestial pinned at 4.0 and vanilla's epic → legendary left at +32%, **no arrangement of
the two new tiers alone can keep the steps from shrinking**: there is only 1.6x of headroom
from legendary to celestial to spend over two steps, and `1.32² = 1.74 > 1.6`. That is
arithmetic, not tuning, and it is why two earlier attempts — mythic at 3.2, then at 3.0 — each
fixed one end of the ladder and broke the other.

Setting the whole ladder instead costs **two changed vanilla values**, both small: uncommon
1.3 → 1.28 and epic 1.9 → 2.0. Rare and legendary keep vanilla's numbers exactly.

### The two fields do different jobs

- **`default_multiplier` is everything that is multiplied** — crafting speed, inserter speed,
  inventory size, lab speed, spoil time, and every module's strength. That is the table above.
- **`level` is everything that is counted** — equipment grid width and height, pole supply
  area and wire reach, accumulator capacity, flying robot energy, tool durability, weapon
  range. Left at vanilla's values plus 6 and 8, so a celestial substation reaches 34x34 rather
  than the 38x38 that level 10 would have brought.

## The retuned odds

`next_probability` is the per-step difficulty knob — the chance of an upgrade is the machine's
quality effect times this value, and values above 1 are legal and behave linearly (measured;
see the analysis file). `chain_probability` stays at vanilla's 0.1 everywhere.

| Step | next_probability | upgrade chance at a 10% quality effect | |
|---|---|---|---|
| normal → uncommon | 1.4 | 14% | retuned |
| uncommon → rare | 1.3 | 13% | retuned |
| rare → epic | 1.1 | 11% | retuned |
| epic → legendary | 1.0 | 10% | vanilla odds |
| legendary → mythic | 1.0 | 10% | vanilla odds |
| mythic → celestial | 1.0 | 10% | vanilla odds |

**Only the first three steps are retuned, and the taper is what caps the discount.** Boosts
compound: reaching legendary passes through every step below it, so a boost on each of four
steps made legendary 2.06x cheaper than vanilla. The owner capped that at 1.62x. Tapering to
nothing by epic holds it to 1.58x while still helping the bottom of the ladder, where the climb
is longest.

The two new steps are deliberately **not** gated. Recycling discards 75% of the material on
every pass, which is gate enough on its own; a second one on top of it produces a grind rather
than a goal. What the retune buys is measured below — the ladder runs about 1.6x to 1.9x per
step where vanilla's runs 2.9x to 3.5x.

## Measured cost per tier

Normal items consumed per one finished item, in the usual upcycling loop: an assembler with
quality modules crafts the item, a recycler with quality modules breaks it back down at 25%,
anything below the target goes round again. Each row uses the module quality the player
realistically owns **at the moment that tier unlocks** — you cannot farm legendary with
legendary modules before legendary exists.

| Tier unlocked at | modules in hand | vanilla | this mod |
|---|---|---|---|
| epic (Fulgora) | rare quality-3, 16% / 20% | 73 – 96 | 47 – 61 |
| legendary (3 planets) | epic quality-3, 20% / 25% | 208 – 288 | 118 – 163 |
| mythic (Aquilo) | legendary quality-3, 25% / 31% | — | 238 – 348 |
| celestial (promethium) | mythic quality-3, 32% / 40% | — | 357 – 549 |

Each range is electromagnetic plant (5 module slots) to assembling machine 3 (4 slots).

**How much the retune actually buys, like for like.** Same modules on both ladders, so only
the odds differ. **No tier is more than 1.58x cheaper**, which is the cap the owner set after an
earlier version reached 2.06x at legendary:

| Tier | vanilla | this mod | cheaper by |
|---|---|---|---|
| uncommon | 4 | 3 | 1.33x |
| rare | 17 | 11 | 1.49x |
| epic | 70 | 45 | 1.57x |
| legendary | 288 | 183 | **1.58x** |

Read the two columns against each other: **mythic on Aquilo costs 182–265, and vanilla
legendary on Aquilo costs 208–288.** The player's experience at each planet is preserved.
And the best item in the game costs more than vanilla's best does — 275–421 against 208–288 —
while being 60% stronger.

**`default_multiplier` moves this table, and not in the direction you would guess.** A stronger
tier means stronger quality modules of that tier, which farm the tier above it faster: mythic
at 3.0 put celestial at 338–520, and raising it to 3.2 brought it back to 275–421. Quality
strength feeds back into quality production, so any change to a multiplier has to be re-run
through `assets/extra-qualities/balance/qsim.py` rather than reasoned about.

The retuned ladder runs about 1.5x to 1.9x per step, against vanilla's 2.9x to 3.5x — that is
the retune doing its job, and it is why the two new steps are not gated on top of it. Gating
mythic→celestial was measured and rejected; `deferred.md` keeps it as a play question.

Without the retune the same ladder gives legendary 208–288, mythic 369–542 and celestial
848–1322 — not broken, but every tier lands harder than the vanilla tier it replaces, and the
whole ladder drifts later than the planets it is pinned to.

## Technology costs

5000 → 5000 → 7500 → 10000, at 60 s, for epic, legendary, mythic and celestial. The two
vanilla counts are untouched; only their gates moved. The real escalation is the pack list —
mythic adds cryogenic science and celestial adds promethium, which is an expedition rather than
a production line. For scale, the most expensive named Space Age technology is
`captive-biter-spawner` at 3000, and vanilla's own `legendary-quality` at 5000 already exceeds
it.

**These four counts are a guess.** Nothing here has been played.

## How the costs were computed

A Markov model of the loop, in `assets/extra-qualities/balance/qsim.py`: mass starts at normal,
each cycle applies the assembler's quality roll, extracts whatever reached the target tier,
multiplies the remainder by 0.25 for the recycler's return, and applies the recycler's roll.
Its per-roll distribution was checked against the engine's own `get_roll_chances` and matches
to six decimal places — see `analysis/quality-roll-mechanics.md`.

Two things the model does not capture, both of which make the real numbers slightly better than
the table: productivity modules and the electromagnetic plant's built-in 50% productivity, and
the fact that ingredients reaching the target quality one step early can be crafted directly
rather than recycled again.
