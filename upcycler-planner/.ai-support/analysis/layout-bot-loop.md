---
verified_against: 2.1.17
verified: 2026-09-07
---
# The bot loop — deferred alternative layout

**Not being built first.** The belt ring (`layout-belt-ring.md`) is milestone 1. This is the
second layout family, intended to arrive later as a **player-facing toggle** in the GUI
("transport: belts / bots"), which is why it is specified now rather than left as a note.

Same skeleton as the belt ring — per-tier columns, machine pinned to `recipe_quality = q_k`,
recycler tangent below ejecting into it, quality modules below target and productivity at
it. The difference is that **all inter-tier transport is the player's logistic network**: no
belts, no undergrounds, no splitters, no circuits, no wires.

## Why it is worth having

- **Roughly a third of the entities.** About 15 at uncommon against the reference belt design's
  48; about 40 at legendary.
- **No circuit logic at all.** Every entity's configuration is a plan-time constant, so there is
  nothing to get wrong and nothing to debug with wires.
- **Smaller footprint**: `W = (t+1)*Wm`, `H = Hm + Hr + 4` (AM3 legendary: 15x11 against the
  implemented belt ring's 17x15).
- Self-seeding, and tap-out is structural rather than plumbed.

## Layout

Rows: `0` chests / `1` inserters / `2 .. 1+Hm` machine / `2+Hm .. 1+Hm+Hr` recycler /
`2+Hm+Hr` inserters / `3+Hm+Hr` chests. Column `k` origin `X_k = k*Wm`.

Every tier `k = 0..t`:

| What | Centre | Config |
|---|---|---|
| Machine | `(X_k + (Wm-1)/2, 2 + (Hm-1)/2)` | dir N; `set_recipe(R, q_k)`; modules `Sm` x (`k<t` quality, `k=t` productivity) |
| Feed chest (`requester-chest`) | `(X_k, 0)` | a slot per ingredient at `q_k`, `count = min(stack, ceil(amount / R.energy * 60))` |
| Feed inserter | `(X_k, 1)` dir **N** | chest -> machine top row; unfiltered — the machine self-filters to its own recipe and quality |
| Out inserter | `(X_k + Wm-1, 1)` dir **S** | machine -> provider; unfiltered, everything leaves |
| Out chest (`passive-provider-chest`) | `(X_k + Wm-1, 0)` | product at `q_k` and every lucky roll above it; the network sorts by quality |

Non-terminal tiers (`k < t`) additionally:

| What | Centre | Config |
|---|---|---|
| Recycler | `(X_k + (Wr-1)/2, 2+Hm + (Hr-1)/2)` | direction from `planner.recycler_orientation()` (vanilla: N); modules `Sr` x quality |
| Extract inserter | `(X_k, 2+Hm+Hr)` dir **N** | recycler -> chest below; `blacklist` on `ING @ q_k` — drains only the rolled-up ingredients the eject cannot deliver |
| Extract chest (`passive-provider-chest`) | `(X_k, 3+Hm+Hr)` | rolled-up ingredients enter the network; tier `k+1`'s feed chest requests them |
| Return chest (`requester-chest`) | `(X_k + 1, 3+Hm+Hr)` | `product @ q_k` x200 |
| Return inserter | `(X_k + 1, 2+Hm+Hr)` dir **S** | return chest -> recycler; whitelist `product @ q_k` (defensive) |

**Eject check** (`Hm=3, Hr=4`): recycler spans rows 5..8, centre y 6.5, eject y `6.5-2.3 = 4.2`
-> tile 4 = the machine's bottom row (machine rows 2..4). Eject x `X_k+0.5-0.35 = X_k+0.15` ->
tile `X_k` = the machine's left column. Passes for `Wm = 3, 4, 5`. (Vanilla's vector; the
belt ring now computes this per prototype with `planner.recycler_orientation()` — reuse it
here when this family is built.)

**When this ships, carry the belt ring's terminal-module rule across** (2026-08-16): the last
machine is left EMPTY when the recipe or the machine refuses productivity, rather than given a
module it cannot accept, and the module quality is the player's pick. The line below predates
that and describes the unconditional version.

The terminal column has no recycler: its machine runs productivity modules and crafts at `q_t`
from `q_t` ingredients, so its whole output is target quality and lands in its provider. **No
requester anywhere asks for the product at `q_t`, so it simply accumulates — the tap-out is
structural.**

## The network question — the reason this is second, not first

It does **not** require an isolated logistic network, and the engine gives a strong guarantee
that makes it safer than it first appears — the `SignalFilter` rule (quoted in full in
`api.md` §4): a request with a non-zero minimum must name an exact quality.

**Every real logistic request is quality-exact, enforced by the engine.** "Request iron gears of
any quality" is not expressible. So tiers 1 and above are hermetically sealed from the rest of
the base: the base's normal-gear requests physically cannot drain the loop's uncommon or rare
stock, and the loop's uncommon-plate request cannot be satisfied by the base's normal plates.
Passive providers only give when asked, so the output does not scatter into storage either.

Two real costs remain, and both are why the belt ring went first:

1. **Normal quality is shared ground with the base.** The tier-0 return chest requests the
   product at normal quality x200, so connected to a base that makes that product, it will pull
   it in and shred it — an uncontrolled drain. Fix before shipping this family: cap that count
   hard, or drop the tier-0 return chest and let the loop seed only from its own tier-0 machine.
   The same applies in reverse — the base's requesters will compete for the normal-quality
   product sitting in the loop's output provider.
2. **Bot flight distance.** In an isolated pocket the machine-to-recycler hop is about ten
   tiles. In one base-wide network the bots are drawn from the whole pool and the items can come
   from anywhere — bot count, latency and UPS, for a loop that cycles constantly. Nothing in the
   design can fix this; it is inherent to using the network as the transport.

The belt ring behaves identically in an isolated pocket and in a base-wide network, which is why
it is the safer default for a mod that strangers install into arbitrary bases.

## Deadlock audit

The eject delivers only what the pinned machine accepts; the blacklist inserter drains the rest;
machine output is drained unfiltered; every buffer is a finite chest with a capped request. The
one stall mode — machine input full while the recycler's output holds only same-tier ingredients
— is throttling, and clears as the machine crafts.

## What the player must supply

Normal-quality ingredients, power, and roboport coverage. The mod places neither poles nor
roboports (same as the belt ring).

## Prior art

Bot-transport upcyclers do exist in the wild — a 20x7 "quality upscaler" cell on the forums, and
the bot-sorted storage-bin family described in `blueprints.md` §8. The 2026-08-17 survey added
scale evidence at both ends: a 508-assembler / 187-recycler EM-plant bot farm (factoriobin
`qu4ky0`) and a parameterised bot cell with a request-sizing formula in its description
(factorioprints `-ODB2KCdbgFzMT1Cf8pW`) — community claims, pages read, strings not decoded.
This layout is a tidier derivation from the verified mechanics rather than a copy of any one of
them, so it is the one part of the design with no directly attested reference build. **Test it
properly before shipping**, rather than trusting the derivation.
