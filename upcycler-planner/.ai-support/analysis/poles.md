# Pole placement — the coverage pass

How `scripts/poles.lua` turns a finished belt-ring plan into pole positions. Written
2026-08-16, when the pass shipped. The engine rules it stands on are measured, not assumed —
they live in `api.md` §10; the layout growth hook is described in `layout-belt-ring.md`
§"Pole columns"; the decisions and their reasons in `../design.md` (2026-08-16, poles).

## Contract

`poles.plan(layout_params, built, pole, is_consumer)` — PURE, the same contract as
`layout.build`: no storage, no game state, same inputs same output on every client.

- `pole` carries plain values only — `{name, quality, width, height, supply_distance,
  wire_distance}` — resolved by the planner at the pole's own picked quality, via the
  quality-parameterised getters. Quality genuinely matters: `+level` supply radius,
  `+2*level` wire reach.
- `consumer_margins` maps entity names to the collision-box margin their stand-in is shrunk
  by, false for entities that draw no power (`electric_energy_source_prototype ~= nil` is
  the gate) — computed by the planner from each prototype's real collision box, larger axis,
  so this module never touches prototypes. Belts and chests drop out on their own; a modded
  burner machine drops out too, correctly — a pole cannot feed it.
- Returns `{entities, layout, unpowered}`: pole entity dicts tagged `pole = true`, each with
  `wire_to` (the index, in their own order, of the pole it wires back to); the widened
  layout when growth was used, nil otherwise; and how many consumers no pole of the main
  network reaches.

## The pass, in order

1. **Occupancy** — every tile covered by a plan entity, read off the entity list itself.
   Nothing asks where the buffer sub-column is; free tiles are discovered, not derived,
   which is what keeps the pass correct for any machine/recycler/pole footprint and across
   any future row-plan change.
2. **Candidates** — every position where the pole's footprint fits on free tiles, enumerated
   in row-major order. That order is load-bearing: every later tie-break is "first found
   wins", which makes the pass deterministic with no tie-break tables (Factorio's `pairs`
   iterates arrays in insertion order).
3. **Greedy set cover** — repeatedly the candidate whose supply square covers the most
   still-uncovered consumers (strict `>`, so scan order breaks ties). Within ln(n)+1 of the
   NP-hard optimum, which is plenty at this size. The coverage test is the measured engine
   rule: supply square (centre ± quality-adjusted radius) overlapping the consumer's
   collision box, approximated as its tile rect shrunk by that entity's own collision-box
   inset (larger axis, from the planner) — a subset of the real box, so a pole is never
   credited with a machine the game would leave dark, and the cost of the approximation is
   only ever an extra pole or an over-honest warning.
4. **Bridge** — wire-reach connectivity is a different property from coverage. Components
   over centre-to-centre distance ≤ wire reach; while more than one remains, place the
   candidate touching the most components; stop when nothing joins two.
5. **Honest tally** — `unpowered` counts consumers not covered by the LARGEST component. A
   consumer covered only by an unwired island would read as powered by geometry and sit dark
   in game; counting it unpowered is also what makes bridging failure drive growth.
6. **Growth, tried once** — if anything is unpowered, rebuild the layout with
   `column_gap = pole.width` (a pole-wide free column at every tier boundary) and re-run
   1-5. Kept only when strictly fewer consumers end up unpowered: a pole whose supply is
   simply too small (vanilla's big electric pole, 4x4) must not pay the width for nothing.
7. **Spanning wires** — one copper wire per pole, to its nearest already-wired neighbour
   (Prim, per component). Every chosen edge is within reach: any cut of a connected
   component has some in-reach edge across it, and the minimum-distance pair can only be
   shorter. The builder executes the list on the ghosts (`pole_copper` connectors,
   `connect_to`, reach_check on — and note `connect_to` returns false for ghost wires while
   creating them, `api.md` §10.4).

## Best effort is a warning, not an error

Repo owner's call: a pole that cannot cover everything still places what it can, and the
shortfall surfaces as an orange count in the modal status and in the placement print.
Structural impossibility of the loop stays an error; missing power is recoverable by hand.
Same reasoning gives `no-pole-researched` a warning rather than a refusal — the loop is
fine, it just arrives dark.

## Measured shapes (harness, 2.1.14, full research, iron gear wheel)

| Choice | Result |
|---|---|
| medium pole, rare target | 5 poles in free tiles, width stays 11, one spanning tree |
| medium pole at legendary quality, rare | **1 pole** — its 17x17 supply covers the whole loop |
| substation, legendary target | growth 17 -> 25 wide, 2 substations, fully powered |
| big electric pole, rare | best effort: growth kept (11 -> 15), 7 of 25 consumers unpowered, warned |
| picker cleared | no poles, no warning |

## Performance

Bounded by candidates x consumers x rounds — a few hundred candidates, ≤ ~45 consumers,
≤ ~12 rounds, run at most twice (growth) — well under a millisecond, synchronous inside
`gui.refresh` exactly as `layout.build` already is. No spatial indexing; at this size it
would be the MPP-style machinery `reference-mods.md` already argues against.
