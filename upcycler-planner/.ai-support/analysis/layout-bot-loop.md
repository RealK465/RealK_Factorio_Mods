---
verified_against: 2.1.23
verified: 2026-11-27
---
# The bot loop — the second layout family

**Built on 2026-11-27** (2.0.0, open), beside the belt ring: the player picks it from the
modal's **Layout** row (*Belts* / *Bots*), stored as `choices.layout = "bot"`, and nil — every
save from before — stays on belts. `scripts/layout_bot.lua` is the builder, with the belt
builder's contract (`build(params)` → `{ entities, width, height, machines, recyclers,
utility_columns }`), so the planner, the pole pass, the circuit pass and the serialiser take
either family without knowing which. Kept matching what the mod builds, like
`layout-belt-ring.md`; `../decisions.md` owns why each part is as it is.

Same skeleton as the belt ring — a column per tier, the machine pinned to `recipe_quality =
q_k`, the recycler tangent under it throwing recycled ingredients straight in — but **every hop
between tiers is the player's logistic network**: no belts, no undergrounds, no relay chests.

## What it costs and saves

Read off the built plans (`tests/pure/layout_bot_spec.lua`, `tests/bot_plan_spec.lua`):

| Gears, assembling machine 3 | Belt ring | Bot loop |
|---|---|---|
| to rare, 3 tiers | 11 x 15, 85 entities before poles | **9 x 11, 25 before poles** |
| to legendary, 5 tiers | 17 x 15 | **15 x 11** |

A third of the entities, mostly because the belt ring's perimeter alone is 48 belts. Width is
`offsets[#tiers] + Wm` from `layout.column_plan` at a first column of 0 (no ring belt), height
`4 + Hm + Hr`. Yield and pace are the belt plan's to the digit — both are priced from the
machines and recyclers alone, and **neither counts robot travel**.

## Rows and placements

```
row 0             feed chest           | output chest
    1             feed inserter        | out inserter
    2 .. 1+Hm     the crafting machine, pinned to this tier's quality
2+Hm .. 1+Hm+Hr   the recycler, tangent under the machine (lower tiers only)
  2+Hm+Hr         extract inserter     | return inserter
  3+Hm+Hr         extract chest        | return chest
```

Per tier column at `col` (pitch `max(Wm, Wr)`, utility columns before each tier exactly as the
belt ring opens them), `col_out = col + Wm - 1`:

| What | Where | Config |
|---|---|---|
| Feed chest | `(col, 0)` | the **requester** pick; requests every item ingredient at the tier, `request_count` each — one chest whatever the recipe |
| Feed inserter | `(col, 1)`, picks north | unfiltered; tagged `relay_in` |
| Machine | `(col, 2)` | the belt ring's own modules (`layout.machine_modules`) |
| Out inserter | `(col_out, 1)`, picks south | unfiltered; tagged `relay_out` |
| Output chest, lower tiers | `(col_out, 0)` | the **overflow** pick — an active provider; never a circuit census |
| Recycler | `(col, 2+Hm)` | pre-rotated by `planner.recycler_orientation`, quality modules |
| Extract inserter | `(col, 2+Hm+Hr)`, picks north | the belt ring's one nameless `{quality = tier, comparator = ">"}` whitelist — the relief that keeps a rolled-up ingredient from wedging the recycler |
| Extract chest | `(col, 3+Hm+Hr)` | the **overflow** pick |
| Return chest | `(col+1, 3+Hm+Hr)` | the **stock** pick (buffer by default); requests the product at the tier, one stack; the tier's census |
| Return inserter | `(col+1, 2+Hm+Hr)`, picks south | unfiltered — the chest only ever holds what it requested; the tier's reserve |

The **terminal column** stands the machine, its feed chest and inserters, and the **provider**
pick as its output chest (the target's census); the `Hr + 2` rows under it hold the circuit
stack when one is asked for, combinator first under the machine, wrapping one tile west when a
short recycler leaves fewer than four rows.

**The eject is the belt ring's**: recycler and machine stand left-aligned and tangent, so
`planner.recycler_orientation`'s `eject_col < Wm` rule holds unchanged.

## Where the items go

- A tier's machine hands everything it makes to its output chest. Its own product goes to its
  return chest, which requests it; a lucky roll goes to the return chest of the tier it rolled
  into; a finished item or anything above the target is requested by nothing and goes to the
  network's **storage chests** (`api.md` §37: an active provider fills an open request first
  and stores the rest).
- A recycler's same-tier ingredients go straight into its machine. Anything it rolls higher is
  extracted into the extract chest and goes to the feed chest of the tier it rolled into, or to
  storage above the target.
- The final machine's output stays in the player's passive output chest.
- **Without any storage chest** an active provider keeps what nobody requests (`api.md` §37),
  so items rolled early pile up in the lower output and extract chests until something asks
  for them, and a full chest stops its tier. The README asks for a storage chest.

Measured live (`tests/bot_loop_spec.lua`, full research, no module delivered so nothing rolls):
tier 0 crafted 96 times and recycled 92 in 2400 ticks with its own product travelling machine →
output chest → robot → return chest → recycler; seeded items reached the tier that requests
them and the rare gears went to storage.

## The network — what bots cannot avoid

Every hop is a request, so **the bot loop always draws on the network**: each feed chest asks
for ingredients at its tier, each return chest for the product at its tier — tier 0's for the
normal product the player's base makes. The belt ring's two opt-outs (*Upcycle items from the
network*, *Final machine requests ingredients*) are its only transport here, so with bots they
are forced on and hidden (`planner.requests_forced`). No layout trick removes the pull without
belts: a tier's own product exits the top of its machine and enters its recycler at the bottom,
and any local hop between the two costs columns of width. The honest answer, given in the
Layout tooltip and the FAQ, is a logistic network of its own when the player wants their stock
kept out. Higher tiers trade with the base only while the base holds that quality.

**Robot travel is unbounded in a shared network**: a return chest's request can be filled from
anywhere in the base that holds the item. Which source the engine serves first — the loop's own
chest, the nearest, or by provider priority — is **not verified**: `api.md` §37 measured the
outcome on 2.1.23, not which of distance and priority decided it. Nothing in the layout fixes
that; a roboport of the loop's own would only shorten the robots' trips (`../deferred.md`).

## Utility columns, poles, beacons, fluids

- **Poles** run through the same ladder (`plan_with_poles`, the builder passed in), over the
  bot loop's own free ground: beside a recycler narrower than its machine, the middle of the
  top two rows, and the terminal column's lower block. A vanilla rare loop covers with medium
  poles and opens no column (9 wide).
- **Beacons** stand the belt ring's `beacon_offsets` stacks, clamped to rows `0 .. H-1` —
  every row is ground here, no ring to keep clear — so `layout_bot.max_beacon_count` is
  `floor(H / beacon height)`: three vanilla beacons on an assembling machine 3, where the belt
  ring takes four.
- **Fluid**: the pipe run down the utility column's east edge spans every row, a
  pipe-to-ground stub at row 0 and at row `H-1` whose undergrounds reach out of the plan's top
  and bottom edges — the player's tap, as on the belt ring (`layout.stand_pipe_run`).

## Circuit limits with bots

The same decorator (`circuits.decorate`), the same tags. Two differences, both forced:

- **The maximum always counts the whole logistic network** (`planner.circuit_network`): a
  lower tier's finished items go to storage, so the output chest's own count would undercount.
  The modal shows that box ticked and greyed.
- **No ring to relay the spine along.** A machine-to-machine hop that outruns the wire goes
  through the two inserters at the top of the columns either side —
  machine → out inserter → next feed inserter → next machine, the middle hop the gap plus a
  tile (more under a recycler wider than its machine) — held to its own `relay_reach`
  (machine and inserter). An unconfigured wired inserter keeps working and reads nothing
  (`api.md` §37; pinned live on 2.1.25 by `tests/bot_loop_spec.lua`, a foundry loop with
  beacons that relays every hop). A hop even that cannot bridge is counted in the unlinked
  warning, never refused.

Reserves work as on belts: each lower tier's return chest is its census, its return inserter
the reserve, the combinator's M rows unchanged.

## What it does not need

One filter slot in all (the extract inserter's), so `planner.filters_needed` answers 1 with bots
and every plan stands one feed chest per tier — the two-stack feed and its ten-ingredient
ceiling are the belt ring's alone. No relay chest, no overflow tap, no belt.
