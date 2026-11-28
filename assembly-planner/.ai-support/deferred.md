# Deferred — Assembly Planner

Parked work, each entry with enough context to pick up cold.

## Still open

- **A played session.** Every behaviour is suite-tested, but nothing has been built by bots in a
  real save: request fulfilment, trash, and the network cap against a real roboport network.
- **A beaconed electromagnetic plant cell with medium poles leaves one inserter dark.** The
  showcase's electronic circuit cell (13×10, beacons beside and above, side inputs since 0.2.0)
  gets four poles and the `consumers-unpowered` warning for one building — the inserter at the
  bottom right, from its blinking icon in a 2026-11-28 screenshot. Not investigated: whether
  the pole ladder (`plan.lua` `power`) could reach it with another spot, or the side pairs took
  the tile it needed.

## Scope cut from production chains (0.4.0)

- **Per-cell logistics, beacons, pole or stock settings.** The extra-rows window shares them
  across the chain; a player wanting beacons on the root alone has no lever. The model already
  merges a cell's entry over the root's choices (`chain.derive`), so this is a window question.
- **Whole-number ratios.** *Balance* rounds every row up against the root's count as set; it
  never looks for a root count at which the rows come out whole (two circuit cells to three of
  cable instead of one to two). The exact needs are already in the plan (`need` per row).
- **A quality split of a cell's own.** A cell with a quality module and a filterless chain
  inserter is refused; an override per cell would let it place without the split.
- **The free tile beside a fluid cell is stronger than needed** next to a cell with no pipe row:
  the fresh-context check found no vanilla machine with an active flank port there. Kept because
  the tile is also where the player feeds a line shut in by beacons.
- **Cast plates are offered in Space Age.** Once foundries are researched, iron and copper plate
  stand beside most machines, offering a foundry cell fed by molten metal. Legal, but noise for
  most malls; hiding fluid-only recipes from the toggles is one answer.
- **The window's height is an estimate** (`WINDOW_WITHOUT_CHAIN`): the rows scroll and a rebuild
  lifts the window from a fixed allowance for the rest of it, not from its laid-out size.
- **A full chain's first plan takes a third of a second** (measured, `decisions.md` → Counts):
  felt as a hitch on the click that changes the layout. Per-cell pole patterns stamped per copy,
  bridged once, would cut it; the memo already keeps every edit after that click fast.

## Scope cut from 0.2.0

- **A robot-delivery warning.** The throughput model assumes a chest holds what it asks for. At a
  fast pace a small request runs dry on robots long before the inserters matter: 4 crafts of
  gears last a quarter of a second at 15.9 crafts a second. A warning when the request covers
  only seconds of crafting would point at Minutes mode; the threshold depends on the network, so
  it was left out (`throughput-design.md`, Non-goals).
- **A control for the extra inserters.** They are automatic. A player wanting the free tile for
  something else, or a uniform width for a row of cells, has no override; the split box is the
  only lever on a full 3-wide edge.
- **Picking the default inserter by load, not arm speed.** `proto.best_inserter` ranks bulk then
  rotation, so on Space Age the bulk and stack inserters tie and the bulk one wins. The stack
  inserter carries 16 but waits for a full hand (`analysis/api.md` §8), so preferring it needs
  requests of at least a hand per chest first.

## Scope cut from 0.1.0

- **Unrelated items in one blueprint** — several items picked, their cells side by side.
  Production chains built the row for an item's ingredients (`row.lua`, `chain.lua`); what is
  left is a list of roots in the window.
- **Two fluid ingredients** — a second pipe row (the front edge is taken by the inserter row, so
  it would have to run beside the first, or underground). **Fluid products** — an output pipe.
- **Fuelled machines** (biochamber, burner assemblers) — the fuel would be one more request, but
  spoiling nutrients need thought.
- **Separate input and output inserter pickers** — the owner's blueprints mix bulk inputs with
  fast outputs.
- **Shared beacon columns** — cells side by side could share one column between them for more
  beacons per beacon; the owner chose beside-and-above for one cell.
- **Snapping the blueprint to its own size** (`blueprint_snap_to_grid`, written after
  `set_blueprint_entities`) so placing cells in a row lines them up by itself.
- **A recipe can't be planned at a quality its recipe refuses** — the item picker offers every
  quality; the plan refuses with a message rather than hiding the tiers.
- **Copies side by side may not share power** — separate blueprints only; a chain's cells are
  powered as one row. A cell's poles are placed for that cell alone, so
  a copy one cell-width over joins only if two poles happen to land within wire reach. With a
  medium pole (reach 9), two beaconed electromagnetic plant cells, 10 wide, get poles 10 apart
  and stay two networks; the showcase bridges them with one pole in the free top row. Plain
  cells (3 or 4 wide) and substations connect. A fix would prefer pole spots that a copy can
  reach, or warn when none is chosen.
