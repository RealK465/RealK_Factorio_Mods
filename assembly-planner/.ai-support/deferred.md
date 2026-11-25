# Deferred — Assembly Planner

Parked work, each entry with enough context to pick up cold.

## Still open

- **A played session.** Every behaviour is suite-tested, but nothing has been built by bots in a
  real save: request fulfilment, trash, and the network cap against a real roboport network.

## Scope cut from 0.1.0

- **A row of cells in one blueprint** — several items picked, their cells side by side. Cells
  already abut exactly, so this is a GUI and plan-list question, not a geometry one.
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
- **Copies side by side may not share power.** A cell's poles are placed for that cell alone, so
  a copy one cell-width over joins only if two poles happen to land within wire reach. With a
  medium pole (reach 9), two beaconed electromagnetic plant cells, 10 wide, get poles 10 apart
  and stay two networks; the showcase bridges them with one pole in the free top row. Plain
  cells (3 or 4 wide) and substations connect. A fix would prefer pole spots that a copy can
  reach, or warn when none is chosen.
