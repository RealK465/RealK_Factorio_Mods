# The belt-ring layout, generalised

**This is the chosen family, and this file describes what the mod actually builds** — updated
2026-08-15 after implementation. The reference design (`blueprints.md` §4) is specific to a 3x3
assembling machine and leans on circuit control; this is the same idea written as a formula
over any machine footprint, with three deliberate departures recorded in §"Departures" below.

The bot-loop alternative is recorded in `layout-bot-loop.md` — a future toggle, not a discarded
idea.

## Departures from the reference design

1. **No circuits and no wires.** The reference throttles the loop with `< 20` belt gates,
   `>= 20` skim inserters and logistic conditions. The loop runs without them; they are parked
   in `../deferred.md`.
2. **A buffer chest in front of each recycler**, which the reference does not have — it feeds
   its recyclers straight off the ring. The chest decouples the recycler from ring traffic, and
   it is the only thing a chest can usefully do here without circuit control (a buffer on the
   *output* side would pass items straight through, since nothing would stop the outflow).
   This costs **two extra rows**.
3. **A plain rectangular ring with its own return column**, instead of an underground belt
   threaded beneath the terminal machine. At this height that span exceeds even a turbo belt's
   reach, and a dedicated column costs one tile of width and removes undergrounds entirely.

## Symbols

```
R              chosen recipe: item ingredients ING = {i1..in}, one item product P
q0..qt         quality chain, normal..target, from prototypes.quality (t >= 1)
Wm, Hm         machine tile_width, tile_height        Sm = module_inventory_size
Wr, Hr         recycler footprint AFTER rotation      Sr = its module slots   (vanilla 2 x 4, 4)
Qmod, Pmod     best unlocked quality / productivity module
```

Coordinates are **tile centres**, origin at the layout's top-left tile, +x east, +y south. An
even-width entity has a half-integer centre. **An inserter's `direction` is the side it picks up
from** (`blueprints.md` §2).

## Row and column plan

| Row | Contents |
|---|---|
| `0` | top ring belt (flows W) |
| `1` | harvest inserters |
| `2` | feed requester chests |
| `3` | feed inserters / out inserters |
| `4 .. 3+Hm` | machines |
| `4+Hm .. 3+Hm+Hr` | recyclers |
| `4+Hm+Hr` | extract inserter (left) / recycler-feed inserter (middle) |
| `5+Hm+Hr` | extract chest (left) / product buffer chest (middle) |
| `6+Hm+Hr` | unload inserter (left) / product-fill inserter (middle) |
| `7+Hm+Hr` | bottom ring belt (flows E) |

**`H = 8 + Hm + Hr`**  (AM3: 15)
**`W = 2 + t*P + Wm`** with pitch `P = max(Wm, Wr)` — for `Wr <= Wm` this is the original
`2 + (t+1)*Wm` (AM3 + vanilla recycler, uncommon: 8; rare: 11; legendary: 17); the 4-wide
salvager under AM3 gives `P = 4` (rare: 13).

Two rows more than the reference, because a buffer chest between the ring and the recycler
needs an inserter on each side of it, and one column more, for the return run.

Column `x = 0` is the left ring (flows S), `x = W-1` the right ring (flows N). Tier column `k`
starts at `x0 = k*P + 1`; the machine occupies its first `Wm` columns and the recycler its
first `Wr`, both left-aligned. Three sub-columns matter:

- **feed sub-column** at `xf = x0` (leftmost tile) — also the extract stack below
- **buffer sub-column** at `x0 + 1` — the product stack below the recycler
- **product sub-column** at `xp = x0 + Wm - 1` (the machine's rightmost tile) — product rising
  to the top ring

## Per-tier placements

Offsets below are within tier column `k`, which starts at `x0 = k*P + 1`. Every non-machine
entity is 1x1, so its centre is its tile. Sub-columns: feed `xf = x0`, buffer `x0 + 1`,
product `xp = x0 + Wm - 1`.

Every tier:

| What | Tile | Config |
|---|---|---|
| Machine `k` | cols `x0 .. x0+Wm-1`, rows `4 .. 3+Hm` | dir N; `set_recipe(R, q_k)`; `insert_plan` = `Sm` x (`k<t` -> Qmod, `k=t` -> Pmod) |
| Harvest inserter | `(xf, 1)` dir **N** | top ring -> feed chest; `use_filters`, whitelist `ING @ q_k` |
| Feed chest (`requester-chest`) | `(xf, 2)` | a slot per ingredient at `q_k`, about a minute of crafting capped at a stack; `request_from_buffers`; trash per the modal checkbox |
| Feed inserter | `(xf, 3)` dir **N** | feed chest -> machine |
| Out inserter | `(xp, 3)` dir **S** | machine -> `(xp, 2)`: the product belt on non-terminal tiers, the provider on the terminal one; unfiltered, so a lucky above-tier roll leaves too |

Non-terminal tiers (`k < t`) additionally:

| What | Tile | Config |
|---|---|---|
| Recycler `k` | cols `x0 .. x0+Wr-1`, rows `4+Hm .. 3+Hm+Hr` | direction from `planner.recycler_orientation()` (vanilla: N; AoP salvager: W); `insert_plan` = `Sr` x Qmod (a recycler's `allowed_effects` has quality but **not** productivity) |
| Product belt | `(xp, 2)` and `(xp, 1)`, both dir **N** | the machine's output riding up to the top ring |
| Product-fill inserter | `(x0+1, 6+Hm+Hr)` dir **S** | bottom ring -> product buffer; whitelist `P @ q_k` |
| Product buffer chest (`requester-chest`) | `(x0+1, 5+Hm+Hr)` | one stack of `P @ q_k`; `request_from_buffers`; trash per the modal checkbox |
| Recycler-feed inserter | `(x0+1, 4+Hm+Hr)` dir **S** | product buffer -> recycler |
| Extract inserter | `(xf, 4+Hm+Hr)` dir **N** | recycler -> extract chest; `use_filters`, **`filter_mode = "blacklist"`**, filters `ING @ q_k` — drains only what the eject cannot deliver |
| Extract chest (plain container) | `(xf, 5+Hm+Hr)` | rolled-up ingredients on their way back to the ring |
| Unload inserter | `(xf, 6+Hm+Hr)` dir **N** | extract chest -> bottom ring |

Terminal column `t` has no recycler, no product belt and no lower stacks. Instead:

| What | Tile | Config |
|---|---|---|
| Output chest (`passive-provider-chest`) | `(xp, 2)` | the product accumulates here; the out inserter above drops straight in |
| Catcher inserter | `(xp, 1)` dir **N** | top ring -> provider; whitelist `P @ q_t` **and every quality above it** (nearest tiers first, clamped to the inserter's filter slots) — collects product lower tiers rolled by luck. The above-target filters exist because nothing else in the loop consumes an above-target roll: every machine is pinned and matches exactly, so without them that product would circulate on the ring forever |

## The eject check — the constraint that must never be broken

The recycler must stay tangent under its machine or the whole design stops working
(`blueprints.md` §1) — and since 2026-08-15 the check is computed **per prototype** rather
than assumed from vanilla's numbers, because the eject vector is per-prototype: vanilla
throws out its north face (`{-0.35, -2.3}`), Age of Production's salvager out its EAST flank
(`{2.35, -0.5}`).

`planner.recycler_orientation()` rotates the authored vector through the four cardinals and
keeps the rotation whose eject tile lands in the row **directly above** the rotated footprint
— the machine's bottom row under tangency — with the eject column inside the footprint and a
width of at least 2 (the feed inserter drops into the recycler's second column). Vanilla comes
out facing north, 2x4; the salvager facing WEST, 4x4. `Wr` and `Hr` everywhere in this file
are the **rotated** dimensions.

**Any recycler width fits.** The column pitch is `P = max(Wm, Wr)` — a recycler wider than
its machine just leaves dead columns beside the machine, and the terminal column (no
recycler) stays at `Wm`. So `W = 2 + t*P + Wm` for target tier `t`. This works because the
implemented product path runs UP to the top ring (rows 1–2 at the machine's right column),
so nothing occupies the recycler band beyond the recycler itself — the reference design's
down-the-side product channel would have collided, but it was never built.

Two constraints validate() enforces with messages instead of drawing a broken layout:

- a recycler with no working rotation is refused (`recycler-no-eject`);
- the throw must land inside the machine: both stand left-aligned at the column start, so
  `eject_col < Wm` (`recycler-needs-wider-machine`, naming the minimum width). Vanilla
  (eject col 0) and the salvager (eject col 1) pass with every eligible machine.

**Any change to the row plan must re-run this reasoning.**

## The ring

A plain rectangle, all surface belts, **no undergrounds at all**: top row flows W, left column
S, bottom row E, right column N. The corner tile faces where the items go next.

The reference threads the return beneath the terminal machine as an underground pair. That does
not survive the two extra rows the buffer chests cost — the span would be about 14 tiles, past
even a turbo belt's `max_underground_distance` of 10. A dedicated return column costs one tile
of width, removes the underground entirely, and removes the belt-tier dependency with it.

Belt tier: the fastest belt whose recipe is enabled for the force (P.U.M.P.'s "best researched"
pattern, `reference-mods.md`) — as the **default**. The modal has a belt picker that overrides
it; a name that stops being a transport belt falls back to the researched best at plan time.

## Growth rule

Columns `k = 0 .. t-1` are identical up to the quality names and the x-offset `k*P`. **Only the
terminal column differs.** So the emitter is one loop plus one special case, and adding a target
tier adds exactly one column.

## Request counts

The reference book computes ingredient request counts with the parameter formula
`min(stack_size, ingredient_amount / craft_time * 60)`. We have the real numbers at plan time,
so compute it directly:

```lua
count = math.max(1, math.min(stack_size(i), math.ceil(amount_of_i / R.energy * 60)))
```

The buffer in front of each recycler is a **requester chest** asking for one stack of the
product at that tier. It catches product off the belt *and* requests it, so bots top it up when
the ring is slow — and on the first tier that means the player's own production of the item
feeds the loop, which is how an upcycler is normally fed. Higher tiers cannot pull from the base
at all, because the engine forces every request with a non-zero minimum to name an exact
quality.

**Every requester chest gets `request_from_buffers`, and by default `trash_not_requested`**
(both verified settable on a ghost and to survive being built, 2.1.14). Trash-unrequested keeps
a wrong-quality roll from occupying a slot forever, but makes bots haul surplus off to storage,
so it is a checkbox in the modal — on by default, carried on the plan; request-from-buffers is
purely additive and stays always-on.

The extract chest on the other side stays a **plain container** — it is an output on its way to
the belt, not something to request.

## Modules

`k < t` -> quality; `k = t` -> productivity; recyclers -> quality; all at the best unlocked
*tier*, at normal *quality*. Before productivity modules are researched the terminal machine
falls back to quality modules — a small yield loss, not a broken loop. Correct for normal-quality modules and matches every decoded
blueprint. See `quality-math.md` §2 for why this stops being optimal once the player's modules
are themselves high quality — a later refinement, ideally driven by
`LuaQualityPrototype.get_roll_chances()` rather than a hardcoded table.

## Circuit garnish

The throttles (`< 20` belt gate, `>= 20` skim inserter, `> 1` logistic condition) keep the loop
from flooding the ring. The loop runs without them, so they can land in a second pass if the
first cut is easier to debug without wires — but they are part of the reference design and
should not be dropped permanently.

## How much it leans on the logistic network

Product circulation is on the belts, so the loop runs without a network at all. The requests are
top-ups rather than the transport: ingredients into the feed chests, product into the buffer in
front of each recycler, and a passive provider handing out the result.

That still touches the player's base at **normal quality**, deliberately — the first tier's
requests are how an upcycler gets fed from existing production. Everything above normal is
sealed off by the engine's quality-exact request rule, so no higher tier can drain the base or
be drained by it.
