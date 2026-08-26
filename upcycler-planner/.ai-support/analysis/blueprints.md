---
verified_against: 2.1.16
verified: 2026-08-26
---
# Decoded blueprints — the mechanism, the scaling law, the conventions

Sources: `blueprints/owner-upcycler.txt` (ours, untested), `blueprints/reference-book.txt`
(found online, 12 blueprints), plus ~14 further designs read from FactorioBin, factorioprints
and the forums. All were authored on 2.0.x; the mechanics they use are unchanged in 2.1.

## 1. The mechanism the whole design stands on

The recycler is a **`furnace`, 2 wide x 4 tall**, with
**`vector_to_place_result = {-0.35, -2.3}`** (`data/recycler/data.lua:109`;
`collision_box = {{-0.7,-1.7},{0.7,1.7}}` :138). That vector means it **throws its output out of
its front face like a mining drill**, 2.3 tiles from centre — 0.3 tiles past its own edge.

In every reference design each recycler stands **directly under its paired crafting machine,
top edge tangent to the machine's bottom edge, facing north**. The eject point therefore lands
inside the machine's bottom row. Consequences:

- **Recycled ingredients reach the crafter with zero inserters.** That is why the two are always
  tangent, and it is the single most important thing to preserve when generalising the layout.
- The paired machine is pinned to `recipe_quality = q_k`, and **quality ingredients match
  exactly, not as a minimum** — so an ingredient the recycler rolled *up* a tier is rejected by
  that machine and would stall the eject.
- **That is what the blacklist inserter is for.** Below the recycler sits an inserter with
  `use_filters = true`, `filter_mode = "blacklist"`, filters = the ingredients at `q_k`. It
  drains from the recycler's output everything the eject cannot deliver, and only that — the
  blacklist stops it racing the eject for same-tier ingredients.
- This is also how the design dodges the well-documented direct-insertion quality deadlock
  (quality output with nowhere to go jams the machine).

Verified in game data. The **runtime stall-and-resume behaviour** of the eject when the target
machine rejects the front item is assumed from drill behaviour and is on the UNVERIFIED list —
it is the one thing to eyeball in the first in-game test, because the whole family leans on it.

Every recycler in the reference book carries `mirror = true`, which only flips the eject
x-offset (-0.35 to +0.35); both land inside the machine. We can emit unmirrored.

## 2. Inserter direction convention

Vanilla inserter prototype: `pickup_position = {0,-1}`, `insert_position = {0,1.2}`
(`data/base/prototypes/entity/entities.lua:2385-2386`; long-handed `{0,-2}`/`{0,2.2}`
:2526-2527). Negative y is north, so:

**An inserter's `direction` is the side it picks up from; it drops on the opposite side.**

Cross-checked against unambiguous cases in the decoded dumps (an inserter between a chest and an
assembler can only be running one way).

## 3. The scaling law

Family 0-3 of the reference book is the same design at four target qualities. With `t` = target
quality index (uncommon = 1 ... legendary = 4):

- **machines: `t+1`**, at `x = 2 + 3k` for `k = 0..t`, each with `recipe_quality = q_k`
  - `k < t` -> 4x quality module 3
  - `k = t` -> 4x **productivity** module 3 — the terminal machine has nothing left to roll into
- **recyclers: `t`**, at `x = 1.5 + 3k` for `k = 0..t-1`, all 4x quality module 3
- height 13; **pitch = the machine's tile width** (tangent packing)

Confirmed across the whole book and reproduced in the wider sample:

| Machine | Footprint | Module slots | Pitch |
|---|---|---|---|
| `assembling-machine-3` | 3x3 | 4 | 3 |
| `electromagnetic-plant` | 4x4 | **5** | 4 |
| `foundry` | 5x5 | 4 | 5 |

So the layout is parametric in **(machine footprint, module slot count, fluid-ness, target
tier)** — not merely in tier count. That is the argument for a layout *engine* rather than a
stored blueprint.

**Do not code from the book's stated sizes.** "9x13" is the snap-grid label; true occupied width
of family 0-3 is `1 + (t+1)*3`, because the terminal machine's right column pokes past the last
1x1 entity and the right-hand ring is an underground threaded *beneath* it.

## 4. The reference belt-ring flow (the family the implemented layout derives from)

(The implemented ring departs from this in three recorded ways — no circuits, a buffer chest
in front of each recycler, a plain rectangular ring — see `layout-belt-ring.md` §Departures.
This section stays as the decoded record.)

Grid normalised, tile centres at integers, +x east, +y south. Rows: 0 top ring; 1 harvest
inserters; 2 feed chests; 3 feed/out inserters; 4-6 machines (3x3, centre y=5); 7-10 recyclers
(2x4, centre y=8.5); 11 bottom inserters; 12 bottom ring. Machine column k spans
`x = 3k+1 .. 3k+3`; `x=0` is the left ring column.

- **Perimeter ring**, one loop: top row flows W, left column flows S, bottom row flows E, and
  the right side is an underground pair running from `(last,10)` up to `(last,1)` threaded under
  the terminal machine's middle column. It carries recycled ingredients of every tier and
  product of every sub-target tier.
- **Feed sub-column per tier** at `x = 3k+1`: harvest inserter (row 1, dir N) filtered to the
  ingredients at `q_k` lifts them off the top ring into a requester chest (row 2) which requests
  the same items at count 5 as a **top-up from the logistic network**, with
  `trash_not_requested`; feed inserter (row 3, dir N) moves chest -> machine.
- **Machine k** at `(3k+2, 5)`: recipe pinned, `recipe_quality = q_k`, modules per §3.
- **Product channel for `k < t`** at `x = 3k+3`: out inserter (row 3, dir S) machine -> under-
  ground exit (row 2) -> belt (row 1) -> top ring. Below: underground entry (row 7) fed by a
  circuit-gated belt (row 8) with `circuit_enabled`, condition `product@q_k < 20`,
  `circuit_read_hand_contents`, read mode `entire_belt_hold`; a logistic-condition inserter
  (row 9, dir S, `connect_to_logistic_network`, `product@q_k > 1`) pulls from a buffer requester
  chest (row 10, product at `q_k` x200, `request_from_buffers`) back onto the channel; a skim
  inserter (row 11, dir S, whitelist product@`q_k`, circuit `>= 20`) pulls belt overflow into
  that buffer chest.
- **Recycler k (`k < t`)** at `(3k+1.5, 8.5)`: feed inserter `(3k+2, 11, dir S)` whitelist
  product@`q_k` from the bottom ring into the recycler; extract inserter `(3k+1, 11, dir N)`
  blacklist ingredients@`q_k` from the recycler onto the bottom ring; eject north into machine k
  per §1.
- **Terminal column t**: no recycler, no product channel. Tap-out inserter `(3t+2, 7, dir N)`
  machine -> passive provider `(3t+2, 8)`; plus a catcher inserter `(3t+2, 9, dir S)` filtering
  product at the target quality off the right-hand underground into the same provider — that
  catches target-quality product which entered the ring from lower tiers' unfiltered out
  inserters.
- **Wires** (green, connector id 1 in the raw arrays): per non-terminal tier the reading belt on
  the bottom row links to the recycler-feed inserter and to the circuit-gated belt.

The circuit garnish throttles the loop. The loop functions without it but can flood the ring.

Growth rule, verified between the uncommon and rare blueprints: columns `k = 0..t-1` repeat
identically at x-offset `3k` with the quality names shifted; **only the terminal column is
unique**.

## 5. The electromagnetic-plant family — same skeleton, repacked

4x4 machines at pitch 4, 5 module slots, height 12. Differences worth knowing because they show
which parts of the design are essential and which are incidental:

- feed chests and inserters sit **below** the machines instead of above;
- machines are fed straight off the top ring by **unfiltered** inserters — the machine itself
  accepts only its own recipe and quality, so machine-side self-filtering replaces the filter
  lists entirely;
- two-chest "elevators" (provider under requester) appear wherever a span exceeds inserter
  reach;
- the ring is a spiral rather than a rectangle.

## 6. The "with fluids" variants in the book are unbuildable as captured

All their assemblers are `direction = None`. With a *parameter* recipe and
`fluid_boxes_off_when_no_fluid_recipe = true` there are no fluid boxes at capture time, so the
authors' rotations were normalised away. Vanilla `assembling-machine-3` has exactly one fluid
input, north-centre (`entities.lua:5427-5434`), so a north-facing machine cannot reach the side
pipes those blueprints place.

**A parameterised blueprint cannot fix this. A mod that knows the real recipe at plan time can**
— rotate the machines toward a shared pipe run, reading
`fluidbox_prototypes[..].pipe_connections.positions`. This is a concrete argument for the mod
existing, and the reason fluids deserve doing properly rather than early.

Fluids carry no quality and are never returned by recycling, so **one shared normal-quality
fluid header serves every tier**; the fluid is a flat per-cycle cost.

## 7. Raw entity shapes worth keeping

```jsonc
// machine: per-slot insert plan; inventory 4 = defines.inventory.crafter_modules; stacks 0-based
{"name":"assembling-machine-3","position":{},"recipe":"parameter-0","recipe_quality":"normal",
 "items":[{"id":{"name":"quality-module-3"},
           "items":{"in_inventory":[{"inventory":4,"stack":0},{"inventory":4,"stack":1}]}}]}

// requester chest
"request_filters":{"sections":[{"index":1,"filters":[
   {"index":1,"name":"...","quality":"...","comparator":"=","count":200}]}],
 "trash_not_requested":true,"request_from_buffers":true}

// inserter
"filters":[{"index":1,"name":"...","quality":"...","comparator":"="}],
"use_filters":true,"filter_mode":"blacklist"

// throttled belt
"control_behavior":{"circuit_enabled":true,
  "circuit_condition":{"first_signal":{"name":"..."},"constant":20,"comparator":"<"},
  "circuit_read_hand_contents":true,"circuit_contents_read_mode":2}
```

Book-level wires are `wires = [[entity_a, connector_a, entity_b, connector_b], ...]`.

## 8. The wider sample — three real architectures

Beyond the reference lineage, ~14 further designs were decoded. Three genuinely different
approaches exist in the wild:

1. **Per-tier columns** — the reference lineage and most large builds. The dominant pattern, and
   the only one whose per-entity configuration is entirely *static* and therefore computable at
   plan time. Variants share one recycler with circuit sorting, or repeat 3 machines per column
   for throughput.
2. **Single-machine circuit-driven** — one crafter plus one recycler, 12 entities, zero belts,
   with the crafter's `control_behavior {set_recipe = true}` driven by a 3-15 combinator program
   that live-selects the highest tier with stock. Smallest footprint in the wild, worst
   throughput (one machine shared across all tiers), and its own author documents an
   ingredient-waste bug when the quality target switches mid-buffer.
3. **Bot-sorted storage bins** — machines write into per-quality filtered storage chests and
   bots segregate; no passive provider at all, the legendary bin *is* the tap.

**Negative finding: no pure recycler-only design (no crafting stage) was found anywhere.** Every
attested design pairs crafting with recycling. That supports refusing self-recycling items for
now.

Divergences worth remembering: terminal-machine modules are productivity in the parameterised
books but bare or quality in several hand builds (the maths says productivity, see
`quality-math.md`); bulk variants scale by repeating machines *within* a column, which is the
shape any future "scale" input should take rather than inventing new geometry.

## 9. The reference lineage since — web survey, 2026-08-17

Community claims, read from the pages named — not decoded; no strings were re-pulled.

- **kvdveer's thread accumulated exactly the failure modes a generator prevents.** Reported
  against the book: a stack inserter filtering *legendary* on the rare/epic stamps where it
  should filter that stamp's own tier (gr0mpel, 2024-11, fixed by a third party 2025-02);
  requesters asking 1000 of every ingredient on the uncommon/rare EM variants (Magrath,
  2025-10); missing undergrounds in the legendary EM variant, repaired in a separate repost
  (factorioprints `-OHyv1-dMNiDqGbQmexO`). Every one is a hand-parameterisation slip. The
  author never updated the OP; fixes arrived as forks.
- **The reference book silts its own belt up below legendary, and this mod inherited it.**
  Decoded 2026-08-20, entity data not prose: kvdveer's ladder is truncated at the target, its
  pickup inserters carry one `comparator = "="` filter per tier *up to* the target, and nothing
  filters above it — while the recyclers still carry quality modules and still roll past. In the
  Rare build, epic and legendary ingredients have no consumer and lap the ring forever. The
  overflow tap (`../decisions.md`) is this mod's answer; the reference has none, and the second
  bug above (the legendary-filtered stamp) is a separate slip in the same builds.
- **Nobody in the shared corpus uses a quality COMPARATOR.** Across 25 decoded published
  blueprints, all 769 quality-bearing filters are `comparator = "="`; not one is `">"` or `"≥"`,
  and every non-`=` comparator found was a circuit *count* condition. The capability is real —
  posila confirmed `<`/`>` quality conditions on inserters and splitters and fixed their
  blueprint-preview rendering in 2.0.22 (forum t=121828) — and nothing anywhere claims it is
  broken, so the likeliest reading is an obscure GUI affordance. The community's equality-only
  equivalent is the **residual-branch cascade**: split each quality onto its own belt and the
  unsplit remainder *is* "everything above". That needs a splitter chain, and a splitter carries
  exactly **one** filter, so it does not generalise to a multi-ingredient recipe — which is why
  this mod uses the comparator it measured (`api.md` §24) rather than the idiom it found.
- **The maintained successor is Kane99's expanded book** (factoriobin `whtgdo`, ~2025-11,
  ~1.2k downloads): kvdveer's stamps repaired, plus foundry, EM-plant and multi-machine "bulk"
  assembler variants, fluid variants, and combinator automation — the widest machine coverage
  in the lineage.
- **Popularity landscape**: the most-favorited upcycler artifact on Factorio Prints is a
  *single-machine circuit cycler* ("Quality Grinder Parametrized", 273 favourites) — the
  smallest and slowest of the §8 families; kvdveer's thread stands at ~48k views, konage's
  video-guide thread (forum t=124772) at ~97k.
- **The §8 negative finding softens.** Recycler-only artifacts do exist for self-recycling
  items: "Anything Upcycler" (factorio-blueprints.com) states outright it works *only* on
  items that recycle into themselves, and a radar recycler wall was shared on factoriobin
  (`yjaf28`). They are recycler walls with no crafting stage, so `quality-math.md` §3's
  economics apply unchanged — the refusal of self-recyclers now rests on those economics, not
  on absence of prior art.
- **The tangent eject is engine-documented but rarely advertised.** The wiki's Recycler page
  states the eject works "much like a mining drill" with no inserter needed, and the decoded
  book (§1) is built on the tangent arrangement — it is where this mod learned it. But the
  surveyed pages mostly run recycler output onto belts or into chests, and none of the read
  pages presents the inserter-free machine feed as a feature. The zero-circuit claim is
  cleaner: no surveyed book or stamp runs without combinators or logistic conditions.
