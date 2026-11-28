# Inserter throughput — design

Approved by the owner and built on 2026-11-28, shipping in 0.2.0. The rules live in
`decisions.md` (The cell, Requests, The stock cap, Throughput) and the measured constants in
`analysis/api.md` §7–§9; this file stays the design record for the feature.

## Why

The owner (2026-11-27): "Sometimes with beacons the bottleneck is the inserter transferring
items from the request chest to the assembler … check if there is free space and try detect if
the inserter will be a bottleneck, if so maybe split between 2 requester chests." Then: "some
mods may add custom inserters, can't you read inserter speed?" — so nothing about an inserter
may be hard-coded. Asked what to do when there is no free tile, the owner answered "the best
possible".

Today a cell has one input inserter and one requester chest whatever the pace, and the status
line shows the machine's pace whether or not the inserters can feed it. Worked numbers (vanilla
values from `data/base`, arithmetic not measured), **assuming each chest holds at least a full
hand** — Minutes-mode requests do; the default 4 crafts usually do not (see Requests):

| cell | needs | one normal bulk inserter moves | result |
|---|---|---|---|
| AM3, 4 speed module 3, 5 beacons of 2 speed module 3, gears | 15.9 crafts/s, 31.8 plates/s in | 30/s at a hand of 12 (full research); 7.5/s at a hand of 3 | 94%; 24% |
| the same cell, copper cable | 31.8 cables/s **out** | 30/s | output-bound, 94% |
| AM3, 4 legendary quality module 3, the same beacons, gears | about 10.4 crafts/s, 20.8 plates/s in | 30/s; 7.5/s at a hand of 3 | fine; 36% — and the quality split fills the AM3's three edge tiles |

Speed modules carry a quality malus, and five speed beacons transmit about −16.8% quality, so a
speed build has no split and an AM3 keeps one free edge tile. Four *normal* quality module 3s
(+10%) do not beat that malus; legendary ones (+25%) do, and then the edge is full.

## Goals

1. The plan knows each cell's **real rate**: the machine's pace, capped by what its inserters
   can move in and out.
2. When inserters cap the rate, the plan adds inserter-and-chest pairs — inputs or outputs,
   whichever is binding — until they no longer cap it or there is no room.
3. Room comes from the bottom edge's free tiles first, then the machine's sides, where that
   side's beacons step two tiles out to make way, provided they still reach from there.
4. Every number is read from the prototypes and the force: modded inserters, beacons, machines
   and qualities, and the force's capacity research.
5. The status line shows the real rate, and a warning says what still caps it.

## Non-goals

- **Robot delivery.** Network size, robot speed and distance are the player's network, not the
  cell. The model assumes a chest holds what it requests: an upper bound on what the inserters
  allow. It is a wide bound for small requests at a fast pace — 4 crafts of gears last a quarter
  of a second at 15.9 crafts/s, so the robots, not the inserters, empty first; Minutes mode is
  the player's remedy. A warning for it is parked in `deferred.md`.
- **Changing the player's picks.** The inserter, its quality, the beacons, the quality split and
  the request rule stay as picked. The warning may point at them; the plan never swaps them.
- **A control for the extras.** No checkbox or count picker in this pass (`deferred.md` gets it).
- Belts, long-handed inserters, other cell shapes.

## Anti-goals — failures even if it technically works

- A cell that grows or gains inserters without getting faster.
- A beacon moved to where it no longer reaches the machine.
- A stock cap that stops limiting because one output chest was left uncapped.
- A rate the game will not give: every engine constant below is measured on the installed
  version before it ships.

## Constraints

- `plan.build` stays one pass that refuses with a message and never throws (`CLAUDE.md`, fact 4).
- `scripts/calc.lua`, `scripts/cell.lua` and `scripts/poles.lua` stay pure — plain numbers in,
  so the host-Lua tier keeps running them.
- Deterministic: prototypes and force state only, nothing from `storage`.
- **A cell nothing caps is laid out exactly as today.** Its blueprint must not change.
- The footprint stays the bounding box, so cells side by side still abut.
- Factorio 2.1, `base` dependency only.

## Approaches

- **A. Free bottom-edge tiles only, then a warning.** Smallest change; the cell keeps its shape.
  Cannot help a 3-wide machine with the quality split, nor a low-research cell needing several
  inputs.
- **B. A, then the sides — picked.** When the bottom edge is full, extra pairs go up the side of
  the machine and that side's beacons step out two tiles. Keeps every beacon and the split; the
  cell grows 2 tiles per side used, and only when that buys speed. Bends the rule that inserters
  sit on one edge, but only for cells that need it.
- **C. Every layout, keep the fastest** — fewer beacons, no split, beacons dropped for inserter
  room. Beats B only where a beacon cannot reach from two tiles out (no vanilla beacon: supply
  3), and it removes what the player picked.

The owner asked for "the best possible" when shown these; B is the most speed available without
taking anything away.

## Engine facts this relies on

1. **Swing time.** A round trip between two adjacent tiles takes
   `C = 2 * (ceil(0.5 / rotation) - 1)` ticks, `rotation` being
   `LuaEntityPrototype.get_inserter_rotation_speed` at the inserter's quality (turns per tick).
   It matches every row of the wiki's chest-to-chest table — burner, inserter, long-handed and
   fast/bulk/stack, each at all five qualities, measured there on 2.0.26 (fast: 24 ticks, 2.5
   swings/s; legendary fast: 8). **Measured equal on 2.1.25** for the inserter, fast, bulk and
   stack inserters at normal and legendary into a chest, and for the first three into a machine
   (`analysis/api.md` §7).
   Extension adds nothing for vanilla:
   the cell's inserters move their hand 0.2 tiles between pickup (1.0) and drop (1.2), which
   takes about a sixth of the turn's time. For modded inserters, take the slower of the two legs
   (`LuaEntityPrototype.get_inserter_extension_speed`, the distance from
   `LuaEntityPrototype.inserter_pickup_position` and `LuaEntityPrototype.inserter_drop_position`)
   — a hedge, not verified.
2. **Hand size.** `1 + LuaEntityPrototype.inserter_stack_size_bonus`, plus — unless
   `LuaEntityPrototype.uses_inserter_stack_size_bonus` is false —
   `LuaForce.bulk_inserter_capacity_bonus` for a bulk inserter (`LuaEntityPrototype.bulk`) or
   `LuaForce.inserter_stack_size_bonus` for any other. Vanilla: bulk 1 to 12 with research,
   Space Age's stack inserter 4 more built in, the rest 1 to 3 (4 with Space Age). Never more
   than the item's `LuaItemPrototype.stack_size`. Quality changes the swing, not the hand —
   measured at legendary on 2.1.25 (`analysis/api.md` §7).
3. **A hand never carries more than its chest holds.** An inserter picks up to its hand size
   (the wiki, 2.0), so a chest requesting fewer items than a hand caps every swing at the
   request.
4. **The machine never makes a bottlenecked inserter wait.** An inserter inserts while the
   machine holds less than its insertion limit — the crafts finished in 1.166 s, rounded up and
   clamped to 2..100 (`LuaRecipePrototype.overload_multiplier`, default formula; constants in
   `data/core/prototypes/utility-constants.lua:411`). When the inserters are what caps the cell,
   the machine empties faster than they fill it, so it stays under the limit and they never
   wait. Reasoned from the documented rule, **not measured**.
5. **One item type per swing.** A two-ingredient recipe spends swings on each. A hand is one item
   stack (`LuaEntity.held_stack`), so this holds by construction; no live cell exercises a
   two-ingredient recipe.
6. **Beacon reach** is `cell.lua`'s measured rule (`analysis/api.md` §5): a vanilla beacon two
   tiles from the machine still reaches (supply 3, margin 0.3).
7. **Space Age's stack inserter waits for a full hand** (`LuaEntityPrototype.wait_for_full_hand`).
   With a chest share below its hand it waits for refills — fact 3 covers it. Measured on
   2.1.25: given 5 plates it held them and never swung (`analysis/api.md` §8).

## Design

### Rates — `calc.lua`, pure

With `R` the machine's pace in crafts a second (today's arithmetic) and one inserter giving
`60 / C` swings a second:

- **Inputs, `n` of them:** demand is `sum over item ingredients of R * amount / hand`, where
  `hand = min(H, stack_size, share)` and `share` is what one chest requests (Requests, below) —
  fact 3. A share never drops below `min(total, H, stack_size)`, so adding a chest never
  shrinks a hand.
- **Recipe-quality outputs** (all outputs without the split), `n` of them: demand is
  `sum over item products of R * expected * share / min(H, stack_size)`, where `expected` counts
  productivity and the product's probabilities, and `share` is `1 - q` with the split, `1`
  without. **Quality outputs**: the same with `share = q`. `q` is the cell's quality chance as
  `plan.lua` already estimates it.
- A role with `n` inserters **allows** `min(1, n * 60 / C / demand)`.
- **Real rate** `R* = R * min(allowance of every role)`.

### How many inserters — `calc.lua`, pure

Start from today's roles: one input when there are item ingredients, one output, one quality
output with the split. Then spend the room one inserter at a time on the role allowing the
fewest crafts, until every role keeps up with the pace or the room runs out. Finally cut every
role back to what the final rate needs. The cut is what keeps the anti-goal: a gear cell whose
inputs and output cap it equally, with room for only one more inserter, gains nothing from
either alone, so the one added is removed again; with room for two, both roles grow and the
rate rises. (The first draft added to every tied role at once and kept the step only if `R*`
rose; this gives the same counts without stalling on a tie — `calc.allocate`.) Room is the
bottom edge's free tiles, then each side that may take inserters.

The final cut is what stops a pointless pair. Because a chest's share never drops
below a load (Requests), an extra input chest always adds a whole inserter's worth while the
inputs are what binds — including on a default 4-craft cell, whose requests are smaller than a
hand.

### Layout — `cell.lua`, pure

```
B B B B B B B B B           beacons above: positions unchanged, relative to the machine
B B B R i M M M B B B       left side used: beacon column two tiles out,
B B B R i M M M B B B         a requester and its inserter beside the machine
B B B . . M M M B B B
          i o q             bottom edge: today's order, inputs / outputs / quality
          R P Q
```

- **Bottom edge**: today's base roles plus as many extras as fit, grouped inputs, outputs,
  quality, left-aligned — so a cell with one extra input reads `i i o q`.
- **Overflow**: extras that do not fit go up the **left** side, top row first, then the right.
  Inserter beside the machine, chest beyond it. Directions follow the measured rule that an
  inserter faces the side it picks up from: a left input faces west, a left output east; mirrored
  on the right.
- **A side with inserters** moves its beacon column two tiles out and makes the cell two tiles
  wider. It takes inserters only if **every** beacon the plan places on it still reaches from
  there; a side without beacons always may.
- **The row above keeps its positions relative to the machine** and is not re-centred on the
  wider cell. So beacon capacity — and the window's beacon drop-downs — never depend on the
  inserter count, and the pace cannot loop back into the layout.
- The pipe row still spans the full width; the pole solver needs nothing new (it just has more
  consumers to cover).

### Requests and caps — `plan.lua`

- **Each input chest requests every item ingredient: its share, but never less than one load.**
  For an ingredient whose amount is `T` and whose full load is `L = min(H, stack_size)`, each of
  `n` chests requests `max(ceil(T / n), min(T, L))`. A large request (Minutes) is shared evenly,
  so the stock stays what the player set; a request smaller than a load is copied into every
  chest, the way a player copy-pastes a requester; in between, each chest holds one load. The
  same rule covers amounts set by hand. With one chest it is today's request exactly.
- **Decided 2026-11-28, the owner:** "the best one possible" among three — this one, copying the
  full request into every chest (doubles Minutes-mode stock), and an even share with a warning
  (a second chest gains nothing below a load, which the default 4 crafts usually is: 8 plates
  for gears against a bulk hand of 12). This is the one that never shrinks a hand and never
  wastes stock.
- The Ingredient amounts panel keeps showing the amounts the rule produces, and its tooltip says
  several chests share a large amount and each take a small one whole. The too-big warning
  compares one chest's request with its slots.
- **Minutes are priced at the machine's pace `R`, not at `R*`**, as today. Pricing at `R*` would
  tie the request, the hand and the rate into a loop the one-pass plan would have to solve; `R`
  only over-buffers a cell the inserters still cap. `decisions.md`'s "real speed" means the
  machine's own speed with its module and beacon effects — `R`.
- **Slot cap**: each recipe-quality output chest gets `bar = ceil(value / n)`, at least one, so
  the cell stops at about the number of slots the player set. The no-effect warning compares
  that share with one chest.
- **Network cap**: the same logistic condition on each recipe-quality output inserter.
- Quality output chests stay uncapped, as today.

### Status line — `gui.lua` and the locale

- The rate line shows `R*`.
- When `R* < R`, a warning: the real rate against the machine's pace, and that there is no room
  for more inserters; a second one when a request smaller than a hand is part of it.
- Wording: one short sentence each, no "allowance" or "swing". Written directly rather than
  through the `user-facing-text` agent, because the owner asked for no subagents but the review.

### Tests

- **Pure tier**: swing ticks against the wiki's twenty rows and the measured ones; hand sizes;
  demand and allowance; the allocator's stop rules; request and cap shares; side geometry —
  positions, directions, footprint, the beacon step-out, its reach, no overlaps.
- **`plan_spec`**: the three worked examples; a default 4-craft gear cell, whose requests are
  below a load, gaining a second chest with the full request copied in; a Minutes cell whose
  request is shared evenly; and a full cell with no room, which warns.
- **Live**: measure the round trip of the inserter, fast, bulk and — with Space Age — stack
  inserter at normal and legendary, chest to chest and chest to machine, with the hand size read
  back; stamp a beaconed gear cell with one input and with two and check the crafts in a window
  against the model; check a side-overflow cell's inserters face the right way and feed. Research
  bonuses are set directly on the test force (`LuaForce.bulk_inserter_capacity_bonus` is
  writable).

### Docs

`decisions.md` gains a Throughput section and rewrites The cell, Requests and The stock cap;
`analysis/api.md` gains a section of measured swing times and hand sizes; `journal.md` the
session; `deferred.md` the robot-delivery model and a control for the extras; the mod's
`CLAUDE.md` its Decided bullets; `changelog.txt` a new section (0.1.0 is published —
`factorio-release` picks the number); the README one line; the screenshots are rebuilt if a
showcase cell changes.

## Left to the builder

- Expected product counts: `amount` or the min/max range, the independent and shared
  probabilities, `extra_count_fraction`, `ignored_by_productivity`.
- Tie-breaks inside the allocator beyond "bottom before sides, left before right, fewest
  inserters".
- Whether open windows refresh when research finishes — the hand size moves with research.
- Locale wording, test fixtures and timings.

## Calls made without the owner

- B over A and C.
- Every input chest carries every ingredient, rather than one ingredient per chest — it also
  works for one-ingredient recipes, and balances itself. (How much each requests was the
  owner's call — Requests.)
- The slot cap shared across output chests, rather than applied to each.
- The left side first.
- Minutes priced at the machine's pace, not the capped rate.
- The allocator fills the weakest role first, then cuts back — replacing the draft's rule of
  growing tied roles together.
- No new control.
