---
verified_against: 2.1.17
verified: 2026-09-09
---
# The belt-ring layout, generalised

**This is the chosen family, and this file describes what the mod actually builds** — updated
2026-08-17 for the utility columns and fluid support, and 2026-08-20 when the columns became
per-tier and something the planner solves for rather than opens by default. The reference design (`blueprints.md` §4) is specific to a 3x3
assembling machine and leans on circuit control; this is the same idea written as a formula
over any machine footprint, with three deliberate departures recorded in §"Departures" below.

The bot-loop alternative is recorded in `layout-bot-loop.md` — a future toggle, not a discarded
idea.

## Departures from the reference design

1. **No belt gates.** The reference throttles the loop with `< 20` belt gates, `>= 20` skim
   inserters and logistic conditions. The loop runs without any of them; what the mod offers
   instead, opt-in since 2026-08-26, is enable conditions on the machines, recyclers and
   reserve inserters against one limits combinator (`../decisions.md` → circuit limits) —
   the ring itself carries no gate, and a wired belt appears only as a relay.
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

**The ring rectangle is the plan's entire footprint** — nothing is ever placed outside it, and
a fluid plan adds no rows: the fluid network reaches the outside world only as underground
stubs beneath the ring belts (§Fluid recipes below).

| Row | Contents |
|---|---|
| `0` | top ring belt (flows W) |
| `1` | harvest inserters |
| `2` | feed requester chests |
| `3` | feed inserters / out inserters |
| `4 .. 3+Hm` | machines |
| `4+Hm .. 3+Hm+Hr` | recyclers |
| `4+Hm+Hr` | extract inserter (left) / recycler-feed inserter (middle) |
| `5+Hm+Hr` | extract chest (left) / product buffer chest (middle) — **overflow chest** on the terminal column |
| `6+Hm+Hr` | unload inserter (left) / product-fill inserter (middle) — **overflow inserter** on the terminal column |
| `7+Hm+Hr` | bottom ring belt (flows E) |

**`H = 8 + Hm + Hr`**  (AM3: 15, fluid or not)
**`W = 2 + sum(G_k) + t*P + Wm`** with pitch `P = max(Wm, Wr)`, summed over `k = 0..t`, where
`G_k` is the utility column standing before tier column `k`:

- **`0`** unless something stands there — which is the usual case, because the planner opens a
  pole column only where coverage needs one (`poles.md` §"Choosing the columns").
- **pole width** where a pole column does open.
- **at least 1** whenever the recipe takes a fluid, whatever the poles do — clamped inside
  `layout.build`, since the pipe run has to stand somewhere.
- **at least the beacon's width** (plus the fluid tile) on a beacon plan — the same clamp, one
  floor: `(fluid and 1 or 0) + beacon width`, every tier, because every tier stands a beacon
  (§Beacons below).

All zero collapses to the original `2 + t*P + Wm` (AM3 + vanilla recycler, rare: 11; the
4-wide salvager under AM3: 13). Measured on 2.1.14 with the default medium pole: rare **11**
and legendary **17**, both with no column open at all; battery in a chemical plant at rare
**14** (the pipe clamp alone); substation to legendary **21**, two of the five columns open;
big electric pole at rare **17**, all three open.

Two rows more than the reference, because a buffer chest between the ring and the recycler
needs an inserter on each side of it, and one column more, for the return run.

Column `x = 0` is the left ring (flows S), `x = W-1` the right ring (flows N). A **utility
column** of width `G_k` may sit before any tier column — the first included, because machines
take their fluid on the west side — so tier column `k` starts at

```
x0(k) = 1 + sum(G_j for j = 0..k) + k*P
```

which is the running prefix `layout.build` computes rather than a closed form, precisely
because the widths differ per tier. The machine occupies its first `Wm` columns and the
recycler its first `Wr`, both left-aligned. Three sub-columns matter:

- **feed sub-column** at `xf = x0` (leftmost tile) — also the extract stack below
- **buffer sub-column** at `x0 + 1` — the product stack below the recycler
- **product sub-column** at `xp = x0 + Wm - 1` (the machine's rightmost tile) — product rising
  to the top ring

## Per-tier placements

Offsets below are within tier column `k`, which starts at `x0(k)` above. Every non-machine
entity is 1x1, so its centre is its tile. Sub-columns: feed `xf = x0`, buffer `x0 + 1`,
product `xp = x0 + Wm - 1`.

Every tier:

| What | Tile | Config |
|---|---|---|
| Machine `k` | cols `x0 .. x0+Wm-1`, rows `4 .. 3+Hm` | dir N; `set_recipe(R, q_k)`; `insert_plan` = `Sm` x (`k<t` -> Qmod, `k=t` -> Pmod) |
| Harvest inserter | `(xf, 1)` dir **N** | top ring -> feed chest; `use_filters`, whitelist `ING @ q_k` |
| Feed chest (`requester-chest`) | `(xf, 2)` | a slot per ingredient at `q_k`, about a minute of crafting capped at a stack; `request_from_buffers`; trash per the modal checkbox |
| Feed inserter | `(xf, 3)` dir **N** | feed chest -> machine |
| **Second feed stack** — only when the recipe has more ingredients than the chosen inserter has filter slots | `(x0+1, 1)`, `(x0+1, 2)`, `(x0+1, 3)` | the same three again in the buffer sub-column, empty above the machine on every tier: harvest dir **N** whitelisting its half, feed chest requesting its half, feed inserter dir **N**. The list splits into balanced halves (6 → 3+3, 7 → 4+3); never a third stack, since `xp` carries the product, so `layout.MAX_FEED_STACKS = 2` caps a loop at ten ingredients with the engine's five slots. No footprint cost — but these were the only upper-band tiles a medium pole covered the harvest row from, so the pole ladder opens a column about every two tiers on such plans (`poles.md`); a substation opens none |
| Out inserter | `(xp, 3)` dir **S** | machine -> `(xp, 2)`: the product belt on non-terminal tiers, the provider on the terminal one; unfiltered, so a lucky above-tier roll leaves too |

Non-terminal tiers (`k < t`) additionally:

| What | Tile | Config |
|---|---|---|
| Recycler `k` | cols `x0 .. x0+Wr-1`, rows `4+Hm .. 3+Hm+Hr` | direction from `planner.recycler_orientation()` (vanilla: N; AoP salvager: W); `insert_plan` = `Sr` x Qmod (a recycler's `allowed_effects` has quality but **not** productivity) |
| Product belt | `(xp, 2)` and `(xp, 1)`, both dir **N** | the machine's output riding up to the top ring |
| Product-fill inserter | `(x0+1, 6+Hm+Hr)` dir **S** | bottom ring -> product buffer; whitelist `P @ q_k` |
| Product buffer chest (`requester-chest`) | `(x0+1, 5+Hm+Hr)` | one stack of `P @ q_k`; `request_from_buffers`; trash per the modal checkbox |
| Recycler-feed inserter | `(x0+1, 4+Hm+Hr)` dir **S** | product buffer -> recycler |
| Extract inserter | `(xf, 4+Hm+Hr)` dir **N** | recycler -> extract chest; `use_filters`, whitelist, **one nameless filter `{q_k, ">"}`** — anything above this tier, exactly what the eject cannot deliver, at one slot whatever the recipe (the tap's shape). It was a blacklist of `ING @ q_k`, one slot per ingredient, until 2026-09-09; the recycler only ever holds `ING @ q_k` or rolled-up `ING @ >q_k`, so the two select the same items (`api.md` §9.6) |
| Extract chest (plain container) | `(xf, 5+Hm+Hr)` | rolled-up ingredients on their way back to the ring |
| Unload inserter | `(xf, 6+Hm+Hr)` dir **N** | extract chest -> bottom ring |

Terminal column `t` has no recycler, no product belt and no lower stacks. Instead:

| What | Tile | Config |
|---|---|---|
| Output chest (`passive-provider-chest`) | `(xp, 2)` | the product accumulates here; the out inserter above drops straight in |
| Catcher inserter | `(xp, 1)` dir **N** | top ring -> provider; whitelist **one** filter, `{P, q_t, ">="}` — the target quality and every one above it, collecting product lower tiers rolled by luck. It was a list of one filter per tier above, nearest first and clamped to the inserter's five slots, until the comparator was measured (`api.md` §24); one entry is exact and cannot be outrun by a longer modded chain |
| **Overflow inserter** | `(xf, 6+Hm+Hr)` dir **S** | bottom ring -> overflow chest; whitelist **one** filter, `{q_t, ">"}` — **naming a quality and no item at all**, so it takes anything above the target whatever the recipe. Only placed when the quality chain has a tier above `q_t` |
| **Overflow chest** (`active-provider-chest`) | `(xf, 5+Hm+Hr)` | where everything above the target leaves the loop. Active on purpose: bots empty it, where a plain chest would fill and the ring would silt up again a few hours later |
| **Circuit stack** (`small-lamp` x2, `display-panel`, `constant-combinator`) | `(xp, 4+Hm)` .. `(xp, 7+Hm)` | only with circuit limits on and a threshold set (since 2026-09-07): the done lamp (green, `P@q_t >= C`), the running lamp (blue, `<`), the panel (paused / done / running, its icon on the map too), then the limits combinator carrying the `M`/`C` rows every condition compares against. A reserve-only plan stands the combinator alone at `(xp, 4+Hm)`. Wired a tile a hop off the terminal machine; the band's `Hr+3 >= 4` rows always fit the four, and `xp` keeps it inside the machine-wide terminal column whatever the pitch (`api.md` §32) |

**The overflow tap is the terminal column's answer to overshoot, and it is free in footprint.**
The terminal column has no recycler, so the extract stack's two tiles stand empty — the tap is
exactly that column's unload inserter reversed, same tile, facing the belt instead of away from
it. Both halves of the loop overshoot (a moduled machine rolls the product past `q_t`, a moduled
recycler rolls the ingredients past it) and nothing consumes either, because every machine is
pinned and quality matching is exact.

It sits on the **bottom** ring and the catcher on the **top**, and product from a lower tier
crosses the bottom first — so above-target *product* normally leaves by the tap, with the
catcher's `">="` standing as the backstop for a base with no bots. The one price is **one more
electric pole** (six, not five, on the vanilla rare loop): the tap is a consumer in a corner that
had none, and it occupies two tiles the pole pass could otherwise have stood in. Width is
unchanged.

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
pattern, `reference-mods.md`) — as the **default**. The modal's **Build options** block has a
belt picker that overrides it; a name that stops being a transport belt falls back to the researched best at plan time.

## Growth rule

Columns `k = 0 .. t-1` are identical up to the quality names and the x-offset `k*P`. **Only the
terminal column differs.** So the emitter is one loop plus one special case, and adding a target
tier adds exactly one column.

## Utility columns — poles and pipes share them

`layout.build` takes `column_gaps`: a list of `G_i`, the empty columns standing before tier
column *i*, blind to what goes in them. **Per tier, not one uniform width** — a plan pays only
where something stands. So the footprint is

```
W = 2 + sum(G_k) + t*P + Wm        summed over k = 0..t, P = max(machine width, recycler width)
```

— the same formula as §"Row and column plan" above, and `t` is the target tier INDEX there
too, so the tier count is `t+1`. It reduces to the old `2 + (t+1)*G + t*P + Wm` when every
`G_k` is the same, and to the pre-column `2 + t*P + Wm` when they are all zero. Verified
byte-identical to the uniform `column_gap` it replaced across 144 shapes (2026-08-20).

Three policy owners, and they are different:

- **A fluid plan clamps every `G_i` to at least 1**, inside `layout.build` itself, so no
  caller can collapse a column the pipe run is standing in.
- **A beacon plan clamps every `G_i` to at least the beacon's width** (plus the fluid tile),
  the same clamp generalised to one floor — a beacon stands in every tier's column, so no
  caller can collapse the ground under it either. The ladder's compact attempt therefore never
  truly reaches zero on a beacon plan, exactly as it never does on a fluid one.
- **Which tiers open a pole column is solved, not assumed.** `planner.plan` tries the compact
  plan first and only keeps a column a pole turned out to need — the ladder is in `poles.md`
  § "Choosing the columns". That is why a plan can come back with columns before tiers 3 and 4
  and nothing before 1, 2 and 5. On a beacon plan `pole_gap` is
  `fluid_extra + pole width + beacon width` — the pole's own lane beside the stack's ground,
  not shared with it, because a full-height beacon stack can leave the column without a single
  free row. The sum is only ever paid where it buys coverage: the ladder reads `pole_gap` on
  no attempt before the compact one has left a consumer dark.

The built plan reports the columns that actually opened (`utility_columns`, each naming its
own `tier`), and the pole pass places into them first (`poles.md`). The columns change no row
and sit outside every tier column, so the recycler stays tangent under its machine and the
eject reasoning above is untouched.

## Beacons — a stack per tier, in the column, off by default

Added 2026-08-22 (one per tier), stacking the same day: opt-in from the Build options strip,
no beacon planned unless the player picks one. When one is picked, **every tier's utility
column floors at the beacon's width and stands a vertical stack of `beacon_count` beacons**,
default one, capped at `layout.max_beacon_count = floor(interior_height / Hb)` — vanilla
shapes take four:

- **x**: every beacon flush against the tier column — `x0(k) - Wb`, or `x0(k) - 1 - Wb` on a
  fluid plan, since the pipe run keeps the column's east edge and the stack stands west of it.
  The count never touches x, which is what "stacking costs no width" means structurally.
- **y**: the stack centres as one rigid block on the machine+recycler band —
  `layout.beacon_offsets` returns `ROW_MACHINE + floor((Hm + Hr - n*Hb) / 2) + (i-1)*Hb`; the
  terminal tier has no recycler and centres on the machine alone. The whole block clamps into
  the interior rows (harvest through unload) with one shift, so it stays contiguous — clamping
  each beacon alone would pile them onto one row. A beacon taller than the whole interior is
  refused (`beacon-too-tall`, exactly `max_beacon_count == 0`); an over-asked count clamps to
  the max, never refuses.
- **Why the band's middle**: the supply area is a beacon's collision box expanded by
  `supply_area_distance` on every side — measured, `api.md` §25 — so the centred block's
  squares span both footprints of the vanilla pair with room to spare. The reach check is per
  receiver: some beacon must reach the machine and some the recycler, not every beacon both —
  a stack's ends sit nearer one receiver each. A short-reach stack warns
  (`beacon-out-of-reach`), never refuses: the loop still runs.
- **Modules**: every slot of every beacon filled with the picked beacon module, defaulting to
  the strongest researched efficiency module — speed transmits its negative quality component
  to everything covered (`api.md` §25), the opposite of this loop's purpose — or planned empty
  on an explicit clear. The insert plan targets `defines.inventory.beacon_modules`, carried on
  the entity record as `module_inventory` because this file's Lua also runs on the host
  interpreter; one shared plan table serves the whole stack.
- **Power and obstacles come free**: a beacon has an electric energy source, so
  `electric_consumers` counts it and the pole pass covers and avoids it through the same
  generic scans as a machine — `poles.lua` carries no beacon-aware code (its one change
  exports the shared overlap primitive), and pure specs pin both the claim and the full-column
  fallback. The pole's lane beside the stack is `pole_gap`'s business, one section up.

Width cost: `+Wb` per tier whatever the count — vanilla rare gears go 11 → 20 at any stack
height. `W` formula unchanged; the beacon is just a floor on `G_k`.

## Fluid recipes — per-column runs, tapped from outside

Fluids carry no quality and are never returned by recycling, so every planned pipe carries
the same normal-quality fluid and the fluid is a flat per-cycle cost. **Nothing is built
outside the ring** — the repo owner's call, 2026-08-17: the footprint the player reserves is
exactly the ring rectangle, and the wiring topology outside it is theirs. The geometry,
forced by two facts — every interior row is part of an inserter reach-chain, and a 1-wide
column cannot carry a horizontal trunk plus a T-junction on one tile — is:

- **Run**: plain pipe down the utility column's EAST edge — always adjacent to the machine's
  west face, because machines are left-aligned in their columns — spanning the full interior
  height (harvest row to unload row). Covering the machine's whole height is what makes the
  connection row irrelevant.
- **Stubs**: the run's two end tiles are pipe-to-ground, surface openings facing INTO the run
  (south at the harvest row, north at the unload row), so their undergrounds reach OUTWARD
  beneath the top and bottom ring belts. The player taps any column from either side by
  standing a matching underground pipe of their own outside — the closest tap is one tile
  past the ring, centres 2 apart, and vanilla reach is 10 — and interconnects the columns
  however their base likes; nothing requests fluid by bots.
- **Each column is its own network until the player joins them** — one tap per column, from
  north or south, is the contract. There is no planned header: a horizontal run cannot live
  inside the ring (the two facts above), and outside the ring is the player's ground.
- **Rotation**: `planner.machine_fluid_orientation()` stands each machine so a fluid input
  connection points west, by the measured direction arithmetic in `api.md` §14 (AM2/3, the
  chemical plant and the biochamber face west; the foundry and cryogenic plant face east —
  their inputs are authored on the south face; the EM plant stays north). A machine with no
  working rotation is refused by name (`machine-no-fluid-face`) — piping a machine wrong is
  the reference blueprints' own defect (`blueprints.md` §6), and the thing this feature
  exists to beat.
- **Refused**: recipes with two or more distinct fluid ingredients (`too-many-fluids`). Only
  `ammonia-rocket-fuel` in vanilla, and plain `rocket-fuel` covers the same item. Fluid
  PRODUCTS are already excluded by the single-item-product gate — the quantum processor stays
  out until a drain network is worth designing.
- The **pipe is the fourth Build options picker** (no quality — nothing about a pipe scales
  with it); the pipe-to-ground is derived, `<pipe>-to-ground` by Wube's own name convention
  with a longest-reach fallback, since no prototype links the pair.

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
*tier*, at the **quality the player picked** — one quality covers every module the loop plans,
normal unless they changed it. The module itself is overridable in the Build options block, and
a name that stops being a quality module falls back to the researched best exactly as the belt
does. Before productivity modules are researched the terminal machine falls back to quality
modules — a small yield loss, not a broken loop.

**The terminal machine gets nothing at all when productivity is refused outright**, which is the
common case and not the exotic one: `allow_productivity` defaults to false and only a handful of
vanilla intermediates opt in, and a machine can allow quality without allowing productivity.
Both are checked, as is the module's own `allowed_module_categories` against machine and recipe.
A refused module would sit in the insert plan forever, unfilled and unexplained.

Correct for normal-quality modules and matches every decoded
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
