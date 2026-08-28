---
verified_against: 2.1.16
verified: 2026-08-28
---
# Pole placement — the coverage pass

How `scripts/poles.lua` turns a finished belt-ring plan into pole positions. Written
2026-08-16 when the pass shipped; reworked 2026-08-17 when the dedicated utility columns
arrived and the growth retry left with them; reworked again 2026-08-20, when the columns
stopped being unconditional and became something the planner solves for.

The engine rules it stands on are measured, not assumed — they live in `api.md` §10; the
utility columns are described in `layout-belt-ring.md` §"Utility columns"; the decisions and
their reasons in `../decisions.md`, and the sessions that produced them in `../journal.md`
(2026-08-16, -17 and -20).

## Contract

`poles.plan(built, pole, consumer_margins)` — PURE, the same contract as `layout.build`: no
storage, no game state, same inputs same output on every client.

- `pole` carries plain values only — `{name, quality, width, height, supply_distance,
  wire_distance}` — resolved by the planner at the pole's own picked quality, via the
  quality-parameterised getters. Quality genuinely matters: `+level` supply radius,
  `+2*level` wire reach.
- `consumer_margins` maps entity names to the collision-box margin their stand-in is shrunk
  by, false for entities that draw no power (`electric_energy_source_prototype ~= nil` is
  the gate) — computed by the planner from each prototype's real collision box, larger axis,
  so this module never touches prototypes. Belts, chests and pipes drop out on their own; a
  modded burner machine drops out too, correctly — a pole cannot feed it.
- `built.utility_columns` — the dedicated columns the layout sized to this pole
  (`{x, width, tier}` each; only the tiers that opened one appear) — is the one piece of
  layout knowledge the pass accepts. `tier` is read by the planner, never by this module. Everything
  else stays discovered: occupancy is read off the entity list itself, so pipes in a fluid
  plan's columns exclude their own tiles without this module knowing pipes exist.
- Returns `{entities, unpowered}`: pole entity dicts each with `wire_to` (the index, in their
  own order, of the pole it wires back to -- `planner.plan` rebases those onto plan indices as
  it appends them, so nothing downstream has to count poles), and how many
  consumers no pole of the main network reaches.

## The pass, in order

1. **Occupancy** — every tile covered by a plan entity, read off the entity list itself.
2. **Candidates** — every position where the pole's footprint fits on free tiles, enumerated
   in row-major order. That order is load-bearing: every later tie-break is "first found
   wins", which makes the pass deterministic with no tie-break tables.
3. **Column attempt** — cover, bridge and tally (steps 5–7) restricted to candidates lying
   wholly inside a utility column. Any column the layout opened was sized to this pole, so
   where they exist the tidy vertical line is what comes out.
4. **Free-tile fallback** — if anything stayed unpowered, the same attempt over ALL
   candidates, kept only when it powers strictly more. A tie stays with the columns. A plan
   with no utility columns at all goes straight here, and since 2026-08-20 that is the usual
   case rather than an edge one — the compact attempt in §"Choosing the columns" opens none.
5. **Greedy set cover** — repeatedly the candidate whose supply square covers the most
   still-uncovered consumers (strict `>`, so scan order breaks ties). Within ln(n)+1 of the
   NP-hard optimum. The coverage test is the measured engine rule: supply square overlapping
   the consumer's collision box, approximated as its tile rect shrunk by that entity's own
   collision-box inset — a subset of the real box, so a pole is never credited with a machine
   the game would leave dark.
6. **Bridge** — wire-reach connectivity is a different property from coverage. Components
   over centre-to-centre distance ≤ wire reach; while more than one remains, place the
   candidate touching the most components; stop when nothing joins two.
7. **Honest tally** — `unpowered` counts consumers not covered by the LARGEST component. A
   consumer covered only by an unwired island would read as powered by geometry and sit dark
   in game.
8. **Spanning wires** — one copper wire per pole, to its nearest already-wired neighbour
   (Prim, per component, each outside pole carrying its best edge rather than the tree being
   rescanned per edge — see §Performance). `blueprint.lua` writes the list as blueprint `wires`, reciprocally on
   both ends the way `create_blueprint` does (`api.md` §21), and the engine makes the
   connections when the loop is stamped.

## Choosing the columns

`poles.plan` solves **one** layout. Which layout it is asked to solve is `planner.plan`'s
decision, made by `plan_with_poles` (in `planner.lua`) — because where a pole *can* stand is
part of the geometry, so the two cannot honestly be solved in sequence. Three attempts at most:

1. **Compact** — `column_gaps` all zero, so no tier opens a pole column at all and poles take
   the ground the ring already leaves free: the dead columns beside a recycler narrower than
   its machine, and the last tier's empty lower block. On most shapes this covers everything,
   and it is as small as a plan gets.
2. **All columns** — one sized column before every tier. This is exactly the plan 0.2.0 through
   0.4.1 emitted unconditionally.
3. **Shrink** — collapse every column no pole stood in, solve again, repeat. It only ever
   collapses, so the open set strictly shrinks and this terminates; a round that powers
   *less* than the one before is rejected and the wider plan kept.

**Fewest unpowered wins; the narrower plan takes any tie.** Compact is tried first, so it holds
one. Because attempt 2 is always in the running, the result can never be worse than the
unconditional-columns plan it replaced — swept over 768 shapes (machine 3–6 wide, 2–5 tiers,
six pole shapes, fluid on and off): **zero coverage regressions, zero width regressions**.

**The growth retry came back, sized.** 0.2.0 deleted it because the columns were opened
before the layout was ever built, which made "no room" stop being a failure mode — at the
price of paying for a column at every tier whether or not anything stood in it. The ladder
above restores growth without restoring that price: a column now has to earn its width by
holding a pole. What growth still cannot fix is "supply too small" (the big electric pole),
which is what the free-tile fallback and the honest count answer.

## Best effort is a warning, not an error

Repo owner's call: a pole that cannot cover everything still places what it can, and the
shortfall surfaces as an orange count in the modal status and in the placement print.
Structural impossibility of the loop stays an error; missing power is recoverable by hand.
Same reasoning gives `no-pole-researched` a warning rather than a refusal — the loop is
fine, it just arrives dark.

## Measured shapes (suite, 2.1.14, full research, iron gear wheel unless said)

Re-measured 2026-08-20, when the columns stopped being unconditional. The 0.2.0-0.4.1 figures
are in brackets where they moved.

| Choice | Result |
|---|---|
| medium pole, rare target | **no column opens**: width 11 [was 14], 5 poles in free ground [was 3 in columns], fully powered |
| medium pole at legendary quality, rare | **1 pole** — its 17x17 supply covers the whole loop |
| substation, legendary target | **two of the five columns open**: width 21 [was 27], 2 substations, fully powered |
| big electric pole, rare | all three columns open and stay: width 17, best effort, **3 of 25 consumers unpowered**, warned |
| picker cleared | no poles, no columns (width 11), no warning |
| battery in a chemical plant, rare (fluid) | the pipe clamp alone holds the columns at 1: width 14 [was 17], poles in free ground, fully powered |

## Performance

One solve computes each candidate's covered-consumer list **once, lazily on first consult**
(since 2026-08-20 — before that the greedy pass re-ran the overlap arithmetic against every
candidate on every round). A round is then table lookups over lists of ≤ ~45 indices, and a
solve whose utility columns already cover never asks about the free tiles at all. The solve
still runs at most twice (the free-tile fallback); the column ladder runs it **once** in the
common case (compact covers, and it is the smallest plan of the set), and at most four times
on a shape that needs growing and shrinking.

Measured on the host interpreter, with placements proven identical by a 512-shape deep-equal
parity sweep (machine 3–6 wide, 2–5 tiers, four pole shapes, fluid on and off, gaps 0–3):
the recorded worst case — 6-wide machine, five tiers, big electric poles, fluid — went
**24.4 ms to 4.3 ms per solve**; the vanilla compact medium-pole solve 0.95 ms to 0.55 ms;
the substation column case stayed level at ~1.2 ms. An **eager** precompute over all
candidates was tried first and regressed that substation case ~30% — a column solve that
covers never consults the free tiles, so materialising their lists is pure waste — which is
why the lists are lazy. Synchronous inside `gui.refresh` exactly as `layout.build` already
is, so the worst case is well under a frame on a picker click at vanilla lengths.

### Long chains — the index and the tree

That paragraph used to close with "no spatial indexing; at this size it would be the MPP-style
machinery `reference-mods.md` argues against". **The size assumption died with the tier cap,
later the same day.** `planner.quality_chain()` was bounded at 32 tiers, so no plan could ever
be longer than 32 columns however many tiers a mod added. Removing that bound (`../journal.md`,
2026-08-20) let a 254-tier mod ask for a 1018-tile-wide plan, and both of this pass's
quadratic-or-worse terms became the whole cost of a solve.

- **`coverage` files consumers by tile column** and asks only the columns a candidate's supply
  square spans. The plain scan was `#candidates x #consumers`, and a tier column adds to both,
  so it was the tier count squared. Sound because a pole that covers a consumer must overlap it
  in x, and the margin only ever shrinks the consumer *inside* the columns it was filed under —
  the bucket query is a superset of the true answer, never a subset. A consumer wider than one
  tile sits in several buckets, so the walk carries a `seen` set: counting one twice would
  inflate the greedy pass's gain and change which pole it picks.
- **`spanning_wires` carries each outside pole's best edge into the tree** rather than
  rescanning the whole tree per edge, which was cubic in the pole count — and the pole count
  tracks the tier count. Both tie-breaks are reproduced exactly: among equal distances the
  earliest component position wins, at *both* ends of the edge.

| tiers | plan width | before | after |
|---|---|---|---|
| 32 | 130 | 32 ms | 11 ms |
| 64 | 258 | 123 ms | 41 ms |
| 128 | 514 | 544 ms | 117 ms |
| 254 | 1018 | 2604 ms | 441 ms |

**Proven identical over 5280 configurations** — 11 tier counts x 3 machine footprints x 4 gap
patterns x fluid on/off x 2 pole footprints, against 10 supply radii, 7 wire reaches and 3
margins — comparing the live file against the pre-change one recovered from git, every field of
every pole, `wire_to` included.

**The harness was falsified before it was trusted**, because the false pass recorded earlier in
`../journal.md` (2026-08-20) is exactly this trap: a comparison harness that cannot fail is
worse than none, because it is believed. This one was first pointed at two deliberately broken
copies — swapping the candidate scan order gave 2182 mismatches, and dropping *only* the
second-end tie-break in the new spanning tree gave 43. The second number is the one that
mattered: it is the failure mode the suite could not see, since nothing in it pinned a `wire_to`
value. `tests/pure/poles_spec.lua` now pins the whole eight-tier wire tree as a single line, and
solves a 64-tier ring, for precisely that reason.

**A pick now costs one plan, not two.** Every figure above is per `planner.plan`, which
`gui.refresh` calls once — but nine of the eleven picker handlers used to run the whole refresh
*twice* for one click, because `on_gui_click` and `on_gui_elem_changed` reach the same
tag-routed handler and the first carries the value the button already held. Guarded the same
day (`../journal.md`), which halves the whole table again for a player changing a picker, at
every chain length including vanilla.

### The hang, and what the first pass missed

The pass above closed by naming `greedy_cover` as the only thing left and calling it reachable
only past ~128 tiers. **That was wrong, and a played game found it the same day.** The owner
picked a high tier and Factorio 2.0 was killed by Windows as a hung application — `AppHangB1` in
the Application event log, no Lua error and no crash dump, because nothing had faulted: the game
simply stopped pumping messages. Measured afterwards, one solve of a 254-tier chain with a 5x5
machine and a medium pole took **82 seconds**.

The cost was `bridge`, not `greedy_cover`. Profiling put ~97% of the solve in `bridge` and the
`within_wire_reach` / `distance_sq` it drives, because a bridging round scores every candidate
against every placed pole — and the round count, the candidate count and the pole count *all*
grow with the chain. Measured at 128 tiers: 63 rounds x 3702 candidates x 213 poles. Cubic.

- **`bridge` files placed poles by centre column** and scores a candidate from the poles near it,
  against a `component_of` map rebuilt per round. Sound by the coverage index's argument: a
  candidate within wire reach of a pole is within wire reach in x alone. One component still
  counts once however many of its poles are in reach — what the old per-component `break` did —
  and dropping that guard is one of the deliberate breaks the sweep was falsified against.
- **`greedy_cover` skips a candidate whose whole coverage list is no longer than the incumbent's
  score.** `count <= #list` always, so the skip cannot change an outcome; it removes the round's
  inner walk for most candidates.

| 254 tiers, pole / machine | before | after |
|---|---|---|
| medium, 3x3 | 0.44 s | 0.23 s |
| substation, 3x3 | 4.04 s | 0.67 s |
| small, 5x5 | 1.86 s | 1.15 s |
| **medium, 5x5** | **82.02 s** | **2.49 s** |
| big electric, 5x5 | 2.95 s | 2.75 s |

Proven identical over **7040 configurations** — the sweep gained a 5x5 machine, which is what
fragments the wire network into the many components `bridge` then has to join — with two
deliberate breaks tripping 2330 and 4034 of them.

**The lesson worth keeping.** The first pass profiled a *fixture* — a 3x3 machine on the vanilla
ring — and generalised the answer to shapes it had never run. `bridge` never appeared because
that fixture's poles all landed in one component, so there was nothing to bridge. Profile the
shape that is slow, not the shape that is handy.

### Near-linear at physical-column scale — the 2026-08-28 pass

The columns feature multiplied the input: the solve's column count became physical columns, up
to 254 tiers x 32 each, and the owner's big-layout crashes were this file's remaining
super-linear terms hitting that product. Every one of them was replaced by an exact
equal-output structure in one pass:

- **Candidates carry their centre** (`cx`/`cy`, computed once at enumeration) — `centre_of`
  recomputation was ~14% of a long solve, paid inside every distance call.
- **`without_overlapping` became a per-attempt dead set** fed by a candidates-by-`dx` bucket
  index: a placed pole retires only the candidates its footprint can reach, instead of
  rebuilding the whole array per placement (~17%).
- **`greedy_cover` keeps exact gains and picks from a lazy max-heap** ordered (gain, then
  scan position) — the same first-in-scan-order tie rule as the rescanning loop, proven
  identical. Covering a consumer decrements the gain of every candidate that also covers it
  (the coverage lists' transpose); rounds went from a full candidate walk each to a heap pop.
- **`bridge` memoises each candidate's in-reach pole list**, built once through the column
  buckets and extended by one distance check per new pole — each candidate-pole pair is now
  checked once across the whole pass, where the window walk repeated it every round. The
  per-candidate `touched` table became a round-stamped shared table (the per-round allocation
  was itself a measurable cost), materialised only for the accepted winner.
- **`components_of` walks neighbours through centre-column buckets**, collecting, sorting and
  then visiting so the member order — spanning_wires' tie-break vocabulary — is byte-identical
  to the old ascending scan. Was poles squared, three calls per attempt.
- **`spanning_wires` offers only to poles within wire reach** (sound because the pole popped
  each round carries the cut's minimum edge, which is always within reach) **and pops from the
  same lazy heap** keyed (distance, then component position). Both tie-breaks reproduced, the
  second-end one included.
- **`plan_with_poles`' dead-column scan** (planner.lua) binary-searches the one sorted,
  disjoint column that can hold each pole, and `within_columns` does the same per candidate —
  both were candidates-or-poles times columns.

Measured on the host interpreter (Lua 5.5), before and after in the same machine session so
the ratios are honest — the box swings ~2x with thermal state, which is why every pair below
was taken back to back. `tiers x columns` are physical columns:

| shape | columns | before | after | ratio |
|---|---|---|---|---|
| 5 tiers x 32, medium (the vanilla ceiling) | 129 | 0.19 s | 0.06 s | 3x |
| 254 x 1, medium 3x3 | 254 | 0.77 s | 0.14 s | 6x |
| 254 x 1, medium 5x5 (the old 82 s hang shape) | 254 | 6.1 s | 0.34 s | 18x |
| 254 x 1, big electric 5x5 | 254 | 6.8 s | 0.49 s | 14x |
| 64 x 8, medium 5x5, fluid | 505 | 21.5 s | 0.67 s | 32x |
| 254 x 8, medium 3x3 | 2025 | 58 s | 1.3 s | 46x |
| 254 x 32, medium 3x3 (the full ceiling) | 8097 | 754 s | 4.9 s | ~150x |
| 254 x 32, medium 5x5 | 8097 | killed unfinished past 20 min | 11.8 s | >100x |

(The 754 s row's before came from a faster machine state than its after, so ~150x is the
conservative reading.) In game (2.1.16 headless, a 35-tier modded chain via a scratch quality
mod, timed around `validate` + `plan` — one refresh's real cost): 35 tiers x 32 columns went
**46.7 s to 0.7-1.8 s** across machine states; the old build also tripped factorio-test's
15 s stuck-process watchdog on that shape, which is the owner's crash reproduced under
measurement. The 129-column vanilla ceiling went 0.28-0.43 s to 0.08-0.17 s, and vanilla
one-column plans sat at ~10-25 ms before and after — the fast cases did not move.

The margin was spent the next day: `MAX_COLUMNS_PER_TIER` doubled to 64 (owner's call,
2026-08-29), measured first — 254 x 64 = 16,193 columns solves in 4.5 s host (11 s with a
5x5 machine), and in game the 35-tier mod at full 64 columns (2177 columns, 46k entities)
costs 1.67 s per refresh, the exact linear doubling of its x32's 780 ms. The solve now
scales with the input where the old one squared, which is what made the doubling a product
call instead of a hang risk.

**Proven identical** over the 4416-configuration layout grid (six pole shapes, four machine
footprints, four gap patterns, fluid on/off, tiers x columns to 104 physical columns) plus
1200 pseudo-random scattered plans that force heavy bridging and spanning ties — every field
of every pole, `wire_to` included, plus the pinned 8-tier wire tree and the in-game suite
(333). Both harnesses were falsified first: a dropped spanning second-end tie-break trips 10
grid and 17 scattered configurations, a flipped greedy tie trips all of them.

**What is genuinely left.** The remaining cost is the honest linear work — enumerating
candidates over the plan area, round-1 coverage lists, and `layout.build`'s entity tables,
each paid per ladder attempt. At the current ceiling (253 x 64 + 1 = 16,193 physical
columns) that is ~4.5 s per solve on the host (~11 s with a 5x5 machine) and a few seconds
in game: no longer a hang, but not free — `MAX_COLUMNS_PER_TIER` stays a real ceiling, now
with margin under it rather than none.
