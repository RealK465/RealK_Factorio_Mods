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

**The plan is already shaped for it.** Since 2026-08-18 an entity's `wire_to` is a plan index
rather than a position among the poles, so a wire can name any entity — which is what a green
wire between a belt and an inserter needs, and what a per-type ordinal could never express. The
serialiser writes `wires` from that field without knowing what kind of entity either end is; a
second wire kind needs a connector id beside the index, not a new mechanism.

Add when: the plain loop is proven and someone wants throughput or a tidier ring.

### A second fluid network (two-fluid recipes), and fluid products
**Status:** out of scope of the 0.2.0 fluid support, on purpose.

Single-fluid recipes shipped 2026-08-17 (`analysis/layout-belt-ring.md` §Fluid recipes). Two
things stayed out, each refused or excluded with its gate:

- **Two distinct fluid ingredients** would need a second header and a second run per column.
  Vanilla has exactly one such recipe (`ammonia-rocket-fuel`) and its product is covered by
  the one-fluid `rocket-fuel` recipe, so this waits for a modded game that actually needs it.
- **Fluid products** (the quantum processor's hot fluoroketone) fail the single-item-product
  gate as they always did. Supporting them means a DRAIN network — pipes carrying output away,
  or voiding it — which is a design of its own. The recycling side is fine (recycling never
  returns fluids), so only the crafting stage needs the plumbing if this is ever wanted.

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
**Status:** not planned, but the shape is known — numbers verified against the wiki 2026-08-17.

Sustained-throughput ratios taper steeply, so the compact one-per-tier column is a convenience
build. The wiki's upcycling-math tutorial (page edited 2026-01-22, table fetched 2026-08-17)
puts the AM3 loop at 208.5 : 30.4 : 9.8 : 2.9 : 1 crafters plus **52.8 recyclers** per
sustained legendary crafter — about 7x on the first step, about 3x thereafter — and the EM
plant at 61.9 : 17.4 : 7.5 : 3.2 : 1 plus 16.5 recyclers. So recyclers run about one per five
machines, never 1:1; at this mod's one-machine-per-tier scale a single recycler keeps up with
the whole column (kvdveer's thread claims the same — community claim), which makes the
per-column tangent recycler deliberate over-provision — cheap, and it preserves the
eject-and-relief mechanism. If a "scale" input is ever added, **repeat columns per tier** —
the wild "bulk" variants do exactly that and keep the skeleton — rather than inventing new
geometry. The ring is the eventual ceiling (one belt of shared circulation); the wild's builds
past that point are bot farms, which is what the bot-loop toggle above becomes at scale.
Compute the taper from `LuaQualityPrototype.get_roll_chances()` rather than copying the wiki
table, and read recycle times from the generated recipes — the formula moved again in 2.1.13
(`analysis/api.md` §8).

### Roboports
**Poles shipped on 2026-08-16** — a Build options picker with its own quality, free tiles
first, pole columns only when needed, best effort plus a warning when even that falls short
(`analysis/poles.md`). Roboports still are not placed: bot coverage stays the player's
problem, as in the reference blueprints. The loop's requester chests do want a network
though, so a roboport option is the natural next candidate — it would ride the same
utility-column/free-tile machinery with a 4x4 footprint and the logistic/construction radii
in place of a supply area. Revisit if it turns out to be a common ask.

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

**Sharper again on 2026-08-17**, when the top machine's module became its own picker with its own
quality (the repo owner's call). So the
only part left to compute is the *split itself*: which module goes in which tier, at the
qualities the player chose. The mod no longer guesses at anything else — every module it plans is
either picked or defaulted from a rule the player can see and override.

### Self-recycling items
Steel and friends have no ingredient-reversal recipe, only the lossy 25%-of-itself fallback. A
recycler-only loop needs thousands of inputs per legendary, so these are refused. The
2026-08-17 web survey softened the old "no shared design anywhere uses one": a few
recycler-only artifacts do exist for exactly this niche (`analysis/blueprints.md` §9), but
they are a different architecture — recycler walls with no crafting stage — with the same dire
economics (`analysis/quality-math.md` §3). Revisit only if the niche turns out to matter.

### Modded quality tiers
The quality chain is walked via `prototypes.quality["normal"].next` rather than hard-coded, so it
should work — but it is untested against a mod that adds tiers.

## Housekeeping

- **Real shortcut art** — layered vanilla icons until then, so no art gates the build.
- **`settings.lua` exists since 2026-08-15**, carrying two per-player settings as of
  2026-08-17: `upcycler-planner-show-all` (offer unresearched items — the game's own
  selection-list option is not mod-readable) and `upcycler-planner-show-all-build-options` (show
  every picker whatever the count). Both are edited from the modal's own settings panel as
  well as from the settings menu, so **a third setting needs no new GUI** — one line in
  `EDITED_SETTINGS` in `gui.lua` and its two locale keys. Remaining candidates, in rough order:
  - **request-from-buffers on the requester chests.** Always on today. Trash-unrequested got
    its own checkbox in the modal on 2026-08-15 (repo owner's call, checked by default);
    request-from-buffers stayed fixed because it is purely additive. A per-player setting
    could expose it, and could also set the checkbox's default.
  - product buffer size (currently one stack of the item).
  - whether to place obstacle-clearing deconstruction orders at all.
- **Locale beyond `en`** — the cfg is structured for it; no other translations exist.
- **Choice reconciliation is written twice, once per layer** (found in review, 2026-08-17).
  `planner`'s `chosen_*` family answers "the pick if it is still valid, else the default" purely;
  `gui.apply_defaults` and the recipe and machine handlers answer the same question destructively,
  in a different idiom. They have already drifted once: `resolve_terminal_module` corrects on
  `module_fits` (machine **and** recipe), `chosen_terminal_module` only on `is_module` — which is
  why validate's terminal-module refusal branch is currently unreachable through the modal. One
  `planner.reconcile(force, choices)` that runs the family and writes back would leave the GUI
  displaying only. ~50 lines moved and four `gui_spec` cases touched, so it wants a reason: the
  **roboport picker** below is the one that pays for it, since a new picker has to be taught two
  resolvers in two files.
- **`build_qualities` is a hand-list where `state.prune` derives** (found in review, 2026-08-17).
  `planner.validate` names the seven build materials whose quality it checks; a picker added later
  and forgotten here loses its "quality not researched yet" warning silently — exactly the failure
  `state.prune`'s `_quality$` match refuses to accept. Deriving it means walking the resources
  table for anything carrying a `quality`, which would also start checking materials nobody has
  checked before, so it is a behaviour change rather than a refactor. Worth doing with the
  reconcile above, not before it.
- **Two helpers express the show-all rule, and which one a picker uses decides whether it can be
  hidden** (found in review, 2026-08-17). `narrowed` hands back a filter table and throws the
  count away; `offered` hands back names and keeps it, and `worth_showing` needs a count. So the
  hide-exempt set is currently "whichever pickers were written with `narrowed`" — belt and pole —
  rather than a decision. Unifying them means giving belt and pole name lists, which changes what
  show-all offers for them (non-buildable prototypes drop out): the repo owner's call, and no
  planned feature needs it yet.
- **`planner.CHEST_ROLES` carries the modal's display order** — a GUI ordering decision living in
  the planner layer, noted 2026-08-17. Negligible today; it would matter if a second surface ever
  wanted a different order.
- **The pipe's fluid rule has no test that can fail** (found in review, 2026-08-17). The SA modset
  ships one pipe, so `worth_showing` keeps the picker hidden whether or not the recipe takes a
  fluid, and `#fluids == 1` could be deleted without a spec noticing. What the spec does pin is
  that picking a fluid recipe repaints the picker's visibility at all. Closing it needs a fixture
  pipe prototype in the test mod — the same trick would settle the recycler and chest rules, which
  are pinned only in the one-option direction for the same reason.
- **`player.opened` is not re-armed when a player rejoins.** `on_gui_closed` is documented not to
  fire when a GUI closes because the player disconnected, died or became a spectator, so a modal
  left open across a rejoin keeps its frame and loses the focus — Esc stops closing it until it is
  closed by button or shortcut. Predates the settings window; either close the GUI on
  `on_player_left_game` or re-arm on `on_player_joined_game`, both one handler.
