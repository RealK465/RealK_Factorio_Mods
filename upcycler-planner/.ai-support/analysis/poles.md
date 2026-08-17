---
verified_against: 2.1.14
verified: 2026-08-17
---
# Pole placement — the coverage pass

How `scripts/poles.lua` turns a finished belt-ring plan into pole positions. Written
2026-08-16 when the pass shipped; reworked 2026-08-17 when the dedicated utility columns
arrived and the growth retry left with them. The engine rules it stands on are measured, not
assumed — they live in `api.md` §10; the utility columns are described in
`layout-belt-ring.md` §"Utility columns"; the decisions and their reasons in `../decisions.md`,
and the sessions that produced them in `../journal.md` (2026-08-16 and -17).

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
  (`{x, width}` each) — is the one piece of layout knowledge the pass accepts. Everything
  else stays discovered: occupancy is read off the entity list itself, so pipes in a fluid
  plan's columns exclude their own tiles without this module knowing pipes exist.
- Returns `{entities, unpowered}`: pole entity dicts tagged `pole = true`, each with
  `wire_to` (the index, in their own order, of the pole it wires back to), and how many
  consumers no pole of the main network reaches.

## The pass, in order

1. **Occupancy** — every tile covered by a plan entity, read off the entity list itself.
2. **Candidates** — every position where the pole's footprint fits on free tiles, enumerated
   in row-major order. That order is load-bearing: every later tie-break is "first found
   wins", which makes the pass deterministic with no tie-break tables.
3. **Column attempt** — cover, bridge and tally (steps 5–7) restricted to candidates lying
   wholly inside a utility column. The layout sized the columns to the pole, so the tidy
   vertical line is the common case.
4. **Free-tile fallback** — if anything stayed unpowered, the same attempt over ALL
   candidates, kept only when it powers strictly more. A tie stays with the columns; a plan
   without utility columns (hand-built test tables, `G = 0` plans carrying no poles anyway)
   goes straight here.
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
   (Prim, per component). The builder executes the list on the ghosts (`pole_copper`
   connectors, `connect_to`, reach_check on — and note `connect_to` returns false for ghost
   wires while creating them, `api.md` §10.4).

**The growth retry is gone**, deliberately: it existed to widen a layout whose free tiles
could not fit enough poles, and the utility columns are sized to the pole before the layout
is ever built, so "no room" stopped being a failure mode. What remains is "supply too small"
(the big electric pole), which width never fixed — the free-tile fallback and the honest
count are the answer to that.

## Best effort is a warning, not an error

Repo owner's call: a pole that cannot cover everything still places what it can, and the
shortfall surfaces as an orange count in the modal status and in the placement print.
Structural impossibility of the loop stays an error; missing power is recoverable by hand.
Same reasoning gives `no-pole-researched` a warning rather than a refusal — the loop is
fine, it just arrives dark.

## Measured shapes (suite, 2.1.14, full research, iron gear wheel unless said)

| Choice | Result |
|---|---|
| medium pole, rare target | width 14 (1-wide columns), **3 poles** lining them, fully powered |
| medium pole at legendary quality, rare | **1 pole** — its 17x17 supply covers the whole loop |
| substation, legendary target | width 27 on its 2-wide columns, 2 substations, fully powered |
| big electric pole, rare | width 17, best effort: **3 of 25 consumers unpowered**, warned (the old free-tile growth left 7) |
| picker cleared | no poles, no columns (width 11), no warning |
| battery in a chemical plant, rare (fluid) | G = 2: pipes on the columns' east edge, poles beside them, fully powered |

## Performance

Bounded by candidates x consumers x rounds — a few hundred candidates, ≤ ~45 consumers,
≤ ~12 rounds, run at most twice (the fallback) — well under a millisecond, synchronous inside
`gui.refresh` exactly as `layout.build` already is. No spatial indexing; at this size it
would be the MPP-style machinery `reference-mods.md` already argues against.
