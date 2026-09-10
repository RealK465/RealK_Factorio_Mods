# Balance — Extra Qualities

The ladder's numbers and the rule they serve. Edited in place. The engine mechanics these rest
on are in `analysis/quality-roll-mechanics.md`; the model that produced the costs is described
at the bottom.

## The design rule

**Each tier should cost roughly what the tier below it costs in vanilla, at the point the
player unlocks it.**

Two extra tiers bolted onto the end of the ladder would put the top of it far past anything
vanilla asks for, because every step costs three to four times the one below. The owner's answer was to
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

No step is smaller than an earlier one **in absolute terms** (+0.35, +0.4, +0.5, +0.625,
+0.875, +1.0). Proportionally it is 25% a step with two 28% blips, at uncommon and at mythic,
where landing the assembling machine 3 on a round number was worth more than the last decimal
of evenness. The ladder still reads as one rule — **quality doubles every three tiers**.

The requirement is met on `default_multiplier` and **knowingly not met on `level`**, which runs
0, 1, 2, 3, 5, 6, 8: epic → legendary gains +2 of everything counted where legendary → mythic
gains +1. See the two fields below for what that covers, and `deferred.md` for the open
question.

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
nothing by epic holds the odds retune to 1.57x at legendary while still helping the bottom of
the ladder, where the climb is longest. **The strength change adds to that separately, and the
cap has not been ruled on for the total — see "Two ways to read the cap" below.**

The two new steps are deliberately **not** gated. Recycling discards 75% of the material on
every pass, which is gate enough on its own; a second one on top of it produces a grind rather
than a goal.

**The 2.0 build writes a tenth of these numbers and means the same thing** — 0.14 / 0.13 / 0.11
where this table says 1.4 / 1.3 / 1.1. 2.1.7 rescaled quality effects down by ten and
`next_probability` up by ten together, so every cost in this file holds on both games. It has no
`chain_probability` at all, so its rolls never skip a tier; that makes the top of the ladder
fractionally dearer there than the table says. See `decisions.md`.

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

Each range is electromagnetic plant (5 module slots) to assembling machine 3 (4 slots). The
percentages are this mod's. The vanilla column is run at vanilla's own module strength, which
is identical except on the legendary row, where vanilla's epic quality module 3 gives
19% / 23.75% rather than 20% / 25%.

**How much the retune actually buys, like for like.** Same modules on both ladders, so only the
odds differ:

| Tier | vanilla | this mod | cheaper by |
|---|---|---|---|
| uncommon | 4.3 – 5.1 | 3.2 – 3.8 | 1.35x |
| rare | 17 – 21 | 11 – 14 | 1.49x |
| epic | 73 – 96 | 47 – 61 | 1.57x |
| legendary | 208 – 288 | 133 – 183 | **1.57x** |

### Two ways to read the cap

The owner capped the discount at 1.62x after an earlier version reached 2.06x at legendary.
There are two measurements and they do not agree, so **this is open, not settled**:

- **Odds only, like for like** — the table just above. Legendary is **1.57x** cheaper. This is
  what was measured when the cap was set, and it is under it.
- **End to end**, vanilla as vanilla against this mod as shipped — the headline table.
  208 – 288 against 118 – 163, so **1.77x**. Over it.

The gap is the strength change, not the odds. Epic quality module 3 goes 1.9 → 2.0 here, so a
player farming legendary does it with 20% / 25% modules where vanilla gives 19% / 23.75%. That
change landed before the cap was set, and the capping measurement held modules constant, so it
was never counted against the cap.

Bringing end-to-end legendary under 1.62x would mean trimming the odds to roughly
1.3 / 1.2 / 1.05 — re-run `qsim.py` rather than taking that on trust. Left as it ships until
the owner rules on which measurement the cap means; `deferred.md` carries the question.

### What the table says

**Mythic on Aquilo costs 238 – 348, where vanilla legendary on Aquilo costs 208 – 288.** The
experience at each planet is close to preserved, a little harder at the top. And the best item
in the game costs well more than vanilla's best does — 357 – 549 against 208 – 288 — while
being 60% stronger.

**`default_multiplier` moves this table, and not in the direction you would guess.** A stronger
tier means stronger quality modules of that tier, which farm the tier above it faster: mythic
at 3.0 put celestial at 440 – 679, and raising it to 3.2 brought it down to 357 – 549. Quality
strength feeds back into quality production, so any change to a multiplier has to be re-run
through `assets/extra-qualities/balance/qsim.py` rather than reasoned about.

**Per step**, reading up, this mod's ladder runs 3.5x, 4.1x, 2.5x, 2.0x, 1.5x against vanilla's
3.9x, 4.3x, 2.8x over its three. Each row uses the modules the player owns when that tier
unlocks, which is why the ratios are not monotone: better modules arrive at the same time the
target gets harder. The two new steps are the cheapest on the ladder by design; `deferred.md`
keeps whether mythic → celestial is too cheap as a play question.

Without the retune the same ladder gives legendary 185 – 256, mythic 369 – 542 and celestial
543 – 843 — not broken, but every tier lands harder than the vanilla tier it replaces, and the
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
