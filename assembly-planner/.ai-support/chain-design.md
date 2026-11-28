# Production chains — design

The owner's three calls on 2026-11-28 shape this: the window shows the chain as **extra rows**,
cells pass items **by robots**, and a cell that falls short **warns** rather than multiplying.
Built the same day for 0.4.0, after a fresh-context check (*The check* below). The rules live in
`decisions.md` → Production chains; this file stays the design record.

## Why

The owner (2026-11-28): "I wonder if we could have like chains of production in the mall? For
example if I place electronic circuits it would also propose optionally copper cables etc...
But then we need to find a very beautiful compact and accessible UI to configure nested chains."

Today one item is one cell is one blueprint. A player wanting circuits and the cable for them
plans two blueprints and places them by hand, and their poles may not even join
(`deferred.md`, copies side by side).

## Goals

1. Each ingredient a cell can make is **offered** beside the machine that uses it, off until
   ticked; a ticked one becomes a cell of its own, and its own ingredients are offered in turn.
2. **One blueprint** holds the chain: normal mall cells side by side, the robots carrying each
   intermediate from its cell's output chest to every cell that requests it.
3. **The window shows the whole chain**, every option one click away: one row per extra cell,
   holding its machine, modules and recipe, and its own ingredients to tick.
4. **A single-cell plan is unchanged**, entity for entity — the chain is a layer over
   `plan.build`, never a rewrite of it.
5. **Every cell's numbers stay true** in the row: no beacon reaches another cell's machine, no
   two fluids share a pipe, and the poles form one network.
6. **A warning when an ingredient cell makes less than the chain uses**, with both rates.

## Non-goals

- **Direct insertion** between machines — the owner chose robots.
- **Counts balanced on their own** — the owner first chose the warning over more cells, then
  asked for counts to set and the balance shown and applied on request (*Ratios* below). A row
  stays one cell until the player changes it.
- **Per-cell logistics, beacons, pole or stock settings** — the extra-rows window shares them
  across the chain; only what a cell makes is its own.
- **Unrelated items in one blueprint** (`deferred.md`, a row of cells) — the model below
  makes it a small step later, but it is not this pass.
- Fluid products, two fluids and fuelled machines stay refused, cell by cell.

## Anti-goals — failures even if it technically works

- A cell in the blueprint that nothing in the chain uses.
- A window that shows one chain and a blueprint that holds another.
- Cells changing each other unplanned: a beacon reaching the neighbour's machine (more speed,
  less quality than the plan says), two fluids meeting in one pipe, two power networks.
- A window taller than a 1080p screen, or a keystroke that stalls the game.

## The model

- **A chain is the root item plus a set of ticked items**, counted only while reachable from the
  root through ticked items. An item appears once whatever uses it: one copper cable cell feeds
  the circuit cell and the advanced circuit cell alike, since robots deliver to every requester.
- **What can be ticked**: an item ingredient with a cell recipe — `proto.recipes_for_item`
  non-empty, the item picker's own catalogue — and, unless *Show unresearched items* is on, one
  of those recipes researched. Fluids are never offered; the pipe row brings them.
- **What a cell owns**: its recipe, machine and modules with their qualities, and its
  per-ingredient amounts. Everything else is the chain's, read from the root's choices: the
  quality it crafts at, logistics, beacons and their counts (clamped to each cell's capacity),
  pole, request rule, trash, stock rule and slot count. Two exceptions, because their numbers
  belong to one item: the **network count** of an ingredient cell is its own default (two
  stacks of its item), and its **quality split** is automatic.
- **Storage**: `storage.players[i].cells[item] = { on, recipe, machine, machine_quality, module,
  module_quality, request_<ingredient> }`, each a flat table like `choices`. Unticking keeps the
  entry, so ticking again restores the cell as it was. **A new root item drops every cell**,
  as it drops the hand-set amounts today; a new recipe or quality on the root keeps them; a new
  request rule or number drops every cell's hand-set amounts with the root's. `state.prune`
  prunes each entry as it prunes `choices`, and drops an entry whose item no longer has a cell
  recipe.
- **The walk** (`chain.walk`): depth first from the root through each recipe's item ingredients
  in recipe order; an item's row stands under the first cell that uses it. **At most 8 cells**:
  the window's height, the blueprint's width and the pole pass's cost all grow with the count,
  and Upcycler Planner crashed twice on unbounded growth (its `deferred.md`).

## The plan — `scripts/chain.lua`, `scripts/row.lua`

- `plan.build` splits in two: **`plan.cell`** does everything it does today except power, and
  returns the cell with its params, its pole spec and its warnings so far; **`plan.build`** is
  `plan.cell` plus today's pole ladder and the unpowered warning, so its output does not move.
- **`chain.build(force, surface, choices, cells)`**: with no ticked cell reachable it *is*
  `plan.build`. Otherwise it plans every cell with `plan.cell`, from `chain.derive(choices,
  entry, item)`; one refusal refuses the chain, prefixed with that cell's item icon so the
  message says where.
- **The row — `row.lua`, pure**: cells left to right in walk order, bottom-aligned so the chest
  rows make one line. Between two neighbours:
  - **Fluids**: one free tile whenever either has a pipe row, unless both carry the same fluid at
    the same height — those join, as cells side by side do today. The free tile is also where
    the player feeds a line that would otherwise be shut in.
  - **Beacons**: the smallest gap, up to 6 more tiles, at which no beacon of the new cell reaches
    any earlier cell's machine nor any earlier beacon reaches its machine — the overlap rule
    `cell.lua` measured, on the positions `cell.build` reports. The fluid tile and this gap take
    the larger, never the sum. With vanilla beacons (computed by the check, not measured):
    cells with side columns abut with 0.6 tile of slack (0.4 for the cryogenic plant, margin
    0.1), extra side pairs included; a sided cell beside an unsided one stands 3 apart;
    above-only cells stand 3 apart for a 3- or 4-wide machine and 2 for a 5-wide one. Past 6
    tiles (modded reach) the cells abut and the chain warns.
- **Power**: with a pole picked, the ladder runs over the whole row: free tiles first, then each
  cell given its column on the right, its row on top, both — the single-cell ladder applied to
  every cell at once — one `poles.plan` over the row each time, kept only if it powers strictly
  more. One solve over the row is connected by construction, so the chain is one network. The
  last eight solves are memoised module-locally, keyed by everything a solve reads; callers copy
  the poles they take, so the cache is never written through.
- **Warnings**: the root's as today; each other cell's prefixed with its icon, except the four
  that read the same for every cell (network cap, quality not researched, build quality not
  researched, a slot cap with no effect), which appear once per distinct text; then one line for
  the shortfalls, one when the cap cut a ticked cell, one when beacons had to abut; then
  unpowered, once for the row.
- **The shortfall**: per ingredient cell, the product at the recipe's quality a minute — real
  rate, every product of that name, productivity with research, less the quality share the
  consumers' `=` requests cannot take — against every other cell's real rate times its recipe's
  amount. Short by more than 1%: the row's product turns red with both numbers on hover, and
  the status carries one line for all short cells.
- **The plan returned** has the row's entities, footprint and warnings, the root's product,
  rate and quality, and a `cells` list — item, request rows, and for an ingredient cell made,
  wanted and short — which drives the amounts panel, the red rows and the blueprint's preview
  icons (the root first, up to four).

## The window

- **Machine row**: the machine strip as today, a ◀ (`utility/backward_arrow`) pointing into
  it, then the root's **ingredient strip** when any ingredient can be ticked: one slot per
  ingredient, its icon, its count per craft as the number, the chain's quality as the badge;
  `yellow_slot_button` when in the chain, since `slot_button`'s selected look is its hover
  look. The strip wraps past four so a long recipe grows the row down. Hidden, arrow and all,
  when nothing can be ticked — a wooden chest's window is exactly 0.3.0's. (In Space Age a gear
  cell now shows iron plate: foundries cast it.)
- **A row per extra cell**, in walk order, in a two-column table of its own whose caption column
  is as wide as the form's, so the strips line up: its product in a slot, stepped 12 px in per
  level up to the column's width; then its machine strip, ◀, its ingredient strip and, when
  several recipes make it, its recipe as an icon-only drop-down at the end.
- **Toggles**: an ingredient that is the root itself, met again down a cycle, stays lit and
  cannot be unticked; with the chain full, an unlit one is disabled and says why.
- **The rows scroll past what the screen leaves** — its height over the UI scale, less an
  allowance for the rest of the window — and a rebuild that grows the window lifts it from the
  same estimate. A rebuild started by a row's control scrolls that row back into view.
- **The amounts panel** groups its fields by cell under a small header once there is a chain.
- **The status line** leads with the cell count: "3 cells · 21 × 9 tiles · about 150 crafts a
  minute".
- **Names** stay unique: `apl-cell/<item>`, `apl-cell-caption/<item>`, `apl-cell-row/<item>` for
  a row; `apl-machine/<item>`, `apl-module/<item>`, `apl-recipe/<item>`, `apl-machine-strip/<item>`
  for its controls; `apl-chain-<row>/<ingredient>` for a toggle (one ingredient can stand in
  several rows); `apl-request-<item>/<ingredient>` and `apl-ingredients-head/<item>` in the
  panel. A slash cannot occur in a prototype name, so none collide; `gui_spec` walks a full
  window to prove it.

## Ratios

The owner, after the first build: "It would be nice if user can configure ratios but also see
and get the optimal ratios".

- **A count per row**, ×1 to ×10, the root's included (`choices.count`, `cells[item].count`,
  stored only above one, `count` in `chain.derive`'s owned keys). A row's copies are its cell
  planned once and stood `count` times in the row, each a whole cell; the root's copies make the
  chain's rate, and a root count alone stands copies of a single cell — copies side by side that
  finally share power.
- **Short** is the row's copies against what its user rows take at their counts as set.
- **Balanced** is computed users first: the root at its count, then each row once all its users
  are sized (a queue over the use edges), the fewest copies within the same 1% slack, capped at
  ten. A cycle the queue cannot settle is sized in walk order against what its users have. Each
  row carries `best` and its exact `need`.
- **The window**: a count drop-down after each machine strip, 72 px for "×10"; the balanced
  count green (`[color]` in the item), the exact need in the tooltip, both repainted by every
  refresh since modules and beacons move them. While any count differs, a status line names the
  balanced chain — each item's icon at its count — beside a *Balance* button that sets every
  ingredient row to it.
- **Caps**: ten copies a row, 32 cells a blueprint, past which the chain refuses. The pole
  solver was made linear in its candidates for this — a flag per candidate updated per
  placement, consumers filed by column — with the goldens proving every answer unchanged.
  Measured on 2.1.25 with medium poles and beacons beside and above: 3 cells 38 ms fresh;
  32 AM3 cells 164 ms, 32 EM plant cells 303 ms; every repeat within 20 ms through the memo.
- **By eye**: the harness photographed an unbalanced and a balanced chain; it caught the counts
  clipped to a sliver at 56 px.

## Engine facts this relies on

- `LuaGuiElement.quality` on a sprite-button, added in 2.0.48 (`data/changelog.txt`), so it
  needs nothing past the mod's `base >= 2.1.0`. `opacity` would give the "unfulfilled
  ingredient" look but arrived in 2.1.25 — not used. `toggled` draws the style's selected set;
  `slot_button`'s selected set is its hovered one (`style.lua` 6810).
- The beacon reach rule and the pole cover rule: measured, as `cell.lua` and `poles.lua` say.
- **Not measured**: what the engine does with two different fluids in one blueprint's pipes,
  and which provider a requester draws from first. The first is avoided by construction; the
  second changes nothing here.

## Tests

- **Golden** (`tests/plan_golden_spec.lua`): eight single-cell plans digested whole, captured on
  the tree before `plan.build` split — goal 4, proven rather than argued.
- **Pure** (`tests/pure/row_spec.lua`): offsets and bottom alignment; the fluid tile and the
  same-fluid join; the beacon gap for above-only and side-column cells, both ways round, a
  longer reach; the cap and its flag.
- **In-game** (`tests/chain_spec.lua`): no cells, an unticked entry or an unreachable one is
  `plan.build`; circuits plus cable is two cells, one blueprint; a cell keeps its own machine
  and modules; nesting by depth; advanced circuits share one cable cell; a refusal names its
  cell; the cap; plastic's pipe row kept apart; one pole network; the shortfall numbers; the
  network warning once.
- **GUI** (`tests/gui_spec.lua`): the strip appears only when something can be ticked; ticking
  adds a row whose picker lands in its own entry; unticking keeps the entry; a new root item
  drops the cells; the amounts panel groups and a new craft count resets every cell; every
  name unique; Place hands over the whole chain with its icons.
- **State** (`tests/state_spec.lua`): prune of the cell entries, and an entry from 0.3.0
  gaining its cells.
- **By eye**: a scratch harness modelled on `assets/assembly-planner/showcase/` photographed the
  window in five states on 2.1.25; it moved the shortfall from one line per cell to the red rows,
  added the ◀, and caught an eight-cell window running off a 1080p screen.

## The check

A fresh-context check read this design against the code before the build. What it changed:

- **Already in the build**: old saves without `cells` (made lazy in `state.of`); the root's
  hand-set amounts leaking into cells (derive drops every `request_*` key); `plan.build`
  gaining keys and moving every digest (`plan.result` copies exactly 0.3.0's).
- **Folded in**: the shortfall's quality share; dedupe on the whole text, not the key, since
  build quality and the slot cap differ per cell; the walk's membership, not the entry's flag,
  lighting a toggle, with a warning for a cut; handlers resolving the cell's own table; the pole
  memo; the strip wrapping past four; the height from the screen; unique names everywhere, and a
  test walking for them; the slot style for a lit toggle.
- **Left, with reasons in `deferred.md`**: the free tile next to a cell without fluid, cast
  plates on offer, a split override per cell, the window's estimated height.

## Calls made without the owner

The owner asked for autonomy after the three picks. Made here, each in `decisions.md`: the
eight-cell cap and the six-tile beacon cap; unticking keeps a cell's entry; a new root item drops
the chain; unresearched ingredients hide unless shown; the red rows with one status line instead
of a line per short cell; the ◀ and the yellow lit slot; a filterless inserter refusing a quality
cell rather than a per-cell split.
