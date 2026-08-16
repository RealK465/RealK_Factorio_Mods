# Deferred work — parked deliberately, not forgotten

A running list of things left out of the current build **on purpose**, each with enough context
to pick up cold. `decisions.md` holds what is settled; `analysis/` holds the evidence;
`journal.md` holds what happened; this holds the "not yet".

Add to this list whenever something is cut for scope. Remove an entry when it ships, and say so
in `changelog.txt` if a player would notice.

## Layout features

### Circuit control and wires
**Status:** cut from the first build, at the repo owner's call — keep it simple to start.

The reference belt design garnishes the loop with circuit conditions and green wires: a belt
gated on `product@q_k < 20` reading its own contents in `entire_belt_hold` mode, a skim inserter
at `>= 20` diverting overflow into a buffer chest, and a `connect_to_logistic_network` inserter
at `> 1` feeding it back. Their job is to stop the ring flooding with product; **the loop runs
without them**, it just circulates more junk.

Everything needed is already verified (`analysis/api.md` §4): control behaviour applies to
script-created ghosts since 2.1.7; `circuit_condition` / `logistic_condition` /
`connect_to_logistic_network` are inherited from `LuaGenericOnOffControlBehavior`, which is easy
to miss because they are only visible via the JSON's `parent` key; wires go through
`get_wire_connector(defines.wire_connector_id.circuit_green, true).connect_to(other)`; and
ghost-to-ghost wiring is first-class. **Use the default `wire_origin.player`** — `script`-origin
wires are invisible to players.

Add when: the plain loop is proven and someone wants throughput or a tidier ring.

### Fluid recipes (pipes)
**Status:** refused with a message in the first build.

Fluids carry no quality and are never returned by recycling, so **one shared normal-quality fluid
header serves every tier** — the fluid is a flat per-cycle cost, not a per-tier one. The work is
geometric: machines must be rotated so their fluid input faces the pipe run, and the column pitch
opens up by one to make room for it.

`LuaFluidBoxPrototype.pipe_connections[].positions` gives the four cardinal connection points
pre-computed per direction, so no rotation maths needs hand-rolling — but the index-to-direction
mapping is on the UNVERIFIED list (`analysis/api.md` §9.4).

Worth doing properly rather than early, because **the reference blueprints get this wrong**: their
"with fluids" variants ship with the machine rotations normalised away and pipes that cannot
connect (`analysis/blueprints.md` §6). A mod that knows the real recipe at plan time can fix
exactly that, so this is a feature where we beat the shared blueprints rather than match them.

### Bot transport as an alternative layout
**Status:** fully specified in `analysis/layout-bot-loop.md`, intended as a GUI toggle.

Same skeleton, no belts — the logistic network does the transport. About a third of the entities
and no circuits at all. Two things must be fixed before it ships:

1. the tier-0 return chest requests the product at *normal* quality, which in a connected base
   will drain the player's own production of that item;
2. bot flight distance is unbounded in a large shared network.

Higher tiers are safe either way — the engine forces every real logistic request to be
quality-exact, so nothing above normal can leak or be stolen.

### Ingredients that roll above the target tier
**Status:** known limitation of the first build, found while writing the layout. **The product
half was fixed on 2026-08-15**; the ingredient half below still stands.

Each recycler carries quality modules, so it can roll an ingredient *above* the tier the loop is
aiming at. The extract inserter blacklists this tier's ingredients, so anything rolled up goes
onto the ring for a higher tier to harvest — but when the target is below legendary there is no
higher tier to harvest it, and those ingredients circulate on the ring forever, slowly taking up
belt space.

The same held for the **product** — machines roll above target too, out inserters are
unfiltered, and the catcher used to take only `P @ q_t` — until the catcher's whitelist was
extended to every quality at or above the target (nearest first, clamped to the inserter's
filter slots), so above-target product now lands in the provider with the rest.

**Targeting legendary avoids the ingredient case entirely**, because the top tier consumes
everything.

Fixes to weigh later: an overflow catcher inserter near the terminal column filtered to
quality above the target (costs filter slots, of which there are only so many); or capping the
recyclers' quality modules on the tier just below the target so they cannot overshoot; or simply
letting the player tap it out deliberately. Worth measuring in a real game before choosing —
the accumulation may be slow enough not to matter. **One route that does NOT work**, worked out
during the 2026-08-15 review: routing above-target ingredients into a trash-flagged feed chest —
the feed inserter is unfiltered, so it would lift them out of the chest and jam against the
pinned machine before the bots ever saw them.

### Scaling beyond one machine per tier
**Status:** not planned, but the shape is known.

Sustained-throughput ratios taper about tenfold per tier, so the compact one-per-tier column is a
convenience build. If a "scale" input is ever added, **repeat columns per tier** — the wild "bulk"
variants do exactly that and keep the skeleton — rather than inventing new geometry.

### Layout rotation
Mining Patch Planner's `coord_convert` / `coord_revert` (`mpp_util.lua:22-47`) is the pattern:
write the layout once, rotate on output.

### Chest picker in the modal
Floated by the repo owner on 2026-08-15 when AAI Containers made the automatic chest choice
pick a 4x4 warehouse. The default (and current behaviour) is a hard filter: chests must be
1x1, largest researched inventory wins — the layout's chest positions are one tile, so bigger
is geometrically impossible without reworking the row plan. A picker would therefore only
choose *among* 1x1 chests (vanilla vs a modded 1x1), which is a thin choice; add it only if
someone actually wants a specific modded chest.

### Roboports
**Poles shipped on 2026-08-16** — a Build options picker with its own quality, free tiles
first, pole columns only when needed, best effort plus a warning when even that falls short
(`analysis/poles.md`). Roboports still are not placed: bot coverage stays the player's
problem, as in the reference blueprints. The loop's requester chests do want a network
though, so a roboport option is the natural next candidate — it would ride the same
free-tile/growth machinery with a 4x4 footprint and the logistic/construction radii in place
of a supply area. Revisit if it turns out to be a common ask.

## Planner intelligence

### Expected-output display
2.1.13 added `LuaQualityPrototype.get_roll_chances()`, so the GUI could show a real "items in per
target item out" estimate from the engine rather than a hardcoded table. Some of the demand for
this mod is a discoverability gap, so showing the maths may be worth more than it looks.

### Optimal module split
The current rule — quality below target, productivity at target — is correct **for
normal-quality modules**. Once the player's own modules are high quality the optimal split shifts
productivity-ward even on lower tiers. Drive this from `get_roll_chances()` when it lands, not
from a copied wiki table.

**Sharper since 2026-08-16**, when the module and its quality became the player's pick: one
quality now covers every module the loop plans, and the terminal machine is left empty when the
recipe or the machine refuses productivity. So the question is no longer only "which split" but
"which split at the quality the player chose" — and a second picker for the productivity module
was deliberately not added: guessing at the split with two widgets is worse than computing it
from one.

### Self-recycling items
Steel and friends have no ingredient-reversal recipe, only the lossy 25%-of-itself fallback. A
recycler-only loop needs thousands of inputs per legendary and **no shared design anywhere uses
one**, so these are refused. Revisit only if the niche turns out to matter.

### Modded quality tiers
The quality chain is walked via `prototypes.quality["normal"].next` rather than hard-coded, so it
should work — but it is untested against a mod that adds tiers.

## Placement and UX

### Cursor-blueprint placement
Handing the player a script-filled blueprint would give preview, rotation, snapping and undo for
free. The blocker is unverified engine fidelity: whether a runtime-written blueprint faithfully
carries insert plans and logistic sections. Worth a time-boxed spike — it would replace only the
placement step, not the layout engine.

### Undo
`create_entity` takes `player` and `undo_index`; whether a multi-entity placement collapses into
one undo step is unchecked.

## Housekeeping

- **The one-line description still says "blueprint".** `info.json`'s `description` and the
  locale `[mod-description]` both read "designs the entire upcycling loop blueprint and places it
  as ghosts". The readme dropped the word on 2026-08-16 — the mod places ghosts and never makes a
  blueprint — so the blurb the in-game mod list shows is now the odd one out. Align before the
  first release.
- **Real shortcut art** — layered vanilla icons until then, so no art gates the build.
- **`settings.lua` exists since 2026-08-15**, carrying one per-player setting:
  `upcycler-planner-show-all` (offer unresearched options in the pickers — the game's own
  selection-list option is not mod-readable). Remaining candidates, in rough order:
  - **request-from-buffers on the requester chests.** Always on today. Trash-unrequested got
    its own checkbox in the modal on 2026-08-15 (repo owner's call, checked by default);
    request-from-buffers stayed fixed because it is purely additive. A per-player setting
    could expose it, and could also set the checkbox's default.
  - product buffer size (currently one stack of the item).
  - whether to place obstacle-clearing deconstruction orders at all.
- **Locale beyond `en`** — the cfg is structured for it; no other translations exist.
