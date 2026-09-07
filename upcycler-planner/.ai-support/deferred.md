# Deferred work — parked deliberately, not forgotten

A running list of things left out of the current build **on purpose**, each with enough context
to pick up cold. `decisions.md` holds what is settled; `analysis/` holds the evidence;
`journal.md` holds what happened; this holds the "not yet".

Add to this list whenever something is cut for scope. Remove an entry when it ships, and say so
in `changelog.txt` if a player would notice.

## Layout features

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
and no circuits at all. **The genre already settled the shape of that toggle**: Mining Patch
Planner ships *Simple*, *Compact*, *Super Compact*, *Sparse* and a chest-instead-of-belts
"logistics" family as named layouts in one picker (portal description, read 2026-08-27), so a
second layout here is a named choice beside the belt ring rather than a checkbox. Two things
must be fixed before it ships:

1. the tier-0 return chest requests the product at *normal* quality, which in a connected base
   will drain the player's own production of that item;
2. bot flight distance is unbounded in a large shared network.

Higher tiers are safe either way — the engine forces every real logistic request to be
quality-exact, so nothing above normal can leak or be stolen.

### The full-height ladder, as an alternative to the overflow tap
**Status:** not built, and recorded so it is not rediscovered from scratch. **The problem it
solves is already solved** — the overflow tap, `decisions.md` — so this is a
different *architecture* for the same defect, not parked work.

The community's own answer, decoded from Vulteran's *Quality Casino Cycler* (2026-08-20 survey):
**never truncate the ladder.** Build a machine for every quality tier whatever the target, and let
the target decide only which column's output is tapped to the provider. Above-target material is
then not orphaned at all — it climbs until it reaches the top tier and exits there. It works
because of two engine facts worth keeping: **quality can never go down** (it needs both
`EffectReceiver::quality_limits.low < 0` and a `QualityPrototype::previous_probability > 0`, and
neither exists in base, quality or space-age), and **the recycler destroys 75% of material per
pass**, so the surplus bleeds away as it climbs.

Rejected for this mod on three counts, none of them about correctness:

- **Cost.** At a rare target it roughly doubles the build — five machines and four recyclers where
  the tap needs three and two — and the width grows with it. That fights the *one machine per
  tier, a convenience build not a throughput build* framing in `decisions.md`.
- **It stops being what the player asked for.** Someone who picks rare would be handed a full
  legendary loop that happens to tap rare.
- **It breaks on modded quality chains.** Quality++ adds four tiers *above* legendary, which
  destroys the absorbing-state property the whole idea rests on, and would have the planner build
  nine columns. A `"> target"` tap is indifferent to chain length.

Revisit only if the tap turns out to be insufficient in a long played game.

**Two routes that do NOT work**, both worked out rather than guessed. Routing above-target
ingredients into a trash-flagged feed chest (2026-08-15 review): the feed inserter is unfiltered,
so it would lift them out of the chest and jam against the pinned machine before the bots ever saw
them. And capping the recyclers' quality modules so they cannot overshoot (an idea this file
carried until 2026-08-20): the *only* route to target-tier ingredients is a recycler rolling them
up, so removing those modules starves the terminal machine outright. The overshoot and the
mechanism are the same event.

### Scaling beyond one machine per tier — SHIPPED in 1.0.0 (2026-08-28)
Shipped along this entry's own recorded shape: **repeat columns per tier**, the target pinned
at one. The balanced-counts hint the wizard first carried was removed before release
(owner's ask, 2026-08-29) — the pace line already reports the bottleneck, and the wizard
now shows nothing it does not store. `decisions.md` → the columns-per-tier bullet owns the
contract; the recyclers
still ride 1:1 per column as deliberate over-provision, preserving the eject-and-relief
mechanism. What stays parked here: the ring is the eventual ceiling (one belt of shared
circulation), and the wild's builds past that point are bot farms — which is what the
bot-loop toggle above becomes at scale.

### Circuit reserves under repeated columns: summed, or per chest? — needs the owner's call
**Status:** surfaced by the 2026-08-29 full review; behaviour shipped as-is in the columns
feature, left standing because either resolution changes decided semantics.

With any threshold set, every column's census chest joins the one green network
(`decisions.md` → circuit limits: reserve → census → recycler → machine, spine across
machines — since 2026-09-07 whenever anything is gated, because the reserves have to hear
the limits combinator; before, only a cap did this and an uncapped reserve was its own
two-entity island), so with N repeated columns of a tier each reserve inserter reads the
tier's product SUMMED across all N chests — the floor holds ~min/N per chest, and one chest
can drain to zero while another holds the min. The combinator move removed the second
reading (an uncapped plan used to keep N×min per chest): the number now means one thing,
summed, capped or not. The Min tooltip says "in its chest", which reads per-chest. With one
column per tier (everything shipped before 1.0.0) the two readings coincide, so nothing
already released behaves differently either way.

Two coherent resolutions: (a) per-chest floors — no longer a matter of islanding, since
every reserve must still hear the combinator; it would take the combinator on the RED wire
to every gated entity and each lower census alone on a green wire with its reserve (an
enable condition sums both networks by default), which rewires a decided topology and
supersedes the "one green network" sentence and the census-connectivity pins in
`tests/pure/circuits_spec.lua`; or (b) keep the summed reading and re-word the Min tooltip
to say the floor is per tier, not per chest. The review chose neither — (a) rewires a
decided topology, (b) re-words the owner's text.

### Roboports
**Poles shipped on 2026-08-16** — a Build options picker with its own quality, free tiles
first, pole columns only when needed, best effort plus a warning when even that falls short
(`analysis/poles.md`). Roboports still are not placed: bot coverage stays the player's
problem, as in the reference blueprints. The loop's requester chests do want a network
though, so a roboport option is the natural next candidate — it would ride the same
utility-column/free-tile machinery with a 4x4 footprint and the logistic/construction radii
in place of a supply area. Revisit if it turns out to be a common ask.

## Planner intelligence

Two entries used to live here and **shipped together in 1.0.0 (2026-08-28; opened as 0.7.0,
re-graded by the owner)**: the optimal
module split (computed per tier from `get_roll_chances()`, overridable in the Ratios...
wizard) and the expected-output display (the status line's yield figure, from the same
solve). `decisions.md` → the module-mix bullets own what is settled; `analysis/api.md` §30
the engine facts.

### Self-recycling items
Steel and friends have no ingredient-reversal recipe, only the lossy 25%-of-itself fallback. A
recycler-only loop needs thousands of inputs per legendary, so these are refused. The
2026-08-17 web survey softened the old "no shared design anywhere uses one": a few
recycler-only artifacts do exist for exactly this niche (`analysis/blueprints.md` §9), but
they are a different architecture — recycler walls with no crafting stage — with the same dire
economics (`analysis/quality-math.md` §3). Revisit only if the niche turns out to matter.

### Modded quality tiers
The chain is walked via `prototypes.quality["normal"].next` rather than hard-coded, and since
2026-08-20 the walk carries no tier ceiling: it stops at the first name it has already seen. It
was `MAX_QUALITY_TIERS = 32` until then, which truncated the chain silently —
infinite-quality-tiers-plus stopped dead at its 32nd tier (`uncommon-III`), reported from a
played 2.0 game. `planner.walk_quality_chain(first)` is the walk, taking the head so a synthetic
chain can exercise it; `planner_spec` feeds it 100 stub nodes and two kinds of cycle.

**The cost half is paid** (2026-08-28, second pass — `analysis/poles.md` → *Near-linear at
physical-column scale* carries the measurements, the structures and the falsified parity
sweeps). Every super-linear term in the pole pass was replaced by an exact equal-output
structure: cached candidate centres, a dead set over a `dx` bucket index in place of the
per-placement array rebuild, exact gains under a lazy max-heap in the greedy cover,
memoised incremental reach lists in `bridge`, bucketed component walks, a windowed heap Prim
in `spanning_wires`, and binary search for the two column-membership scans. The full
254 x 32 ceiling went **754 s to under 5 s** per solve on the host; in game, a 35-tier chain
at 32 columns went **46.7 s to under 2 s** where the old build tripped the test runner's
stuck-process watchdog — the owner's crash, reproduced and closed. Guarding the nine picker
handlers that only refresh had already halved the number of solves a pick costs — one click
raises two events into a tag-routed dispatcher, so each was planning the loop twice.

What is left is the honest linear work — candidate enumeration over the plan area, round-1
coverage lists, `layout.build`'s entity tables, each paid per ladder attempt — a few seconds
in game at the extreme ceiling. The owner spent the new margin the next day:
`MAX_COLUMNS_PER_TIER` doubled to **64** on 2026-08-29 (measured first — 254 tiers x 64 is
~4.5 s host, a 35-tier mod at full 64 columns ~0.6 s host — the near-linear solve makes the
doubling cost proportional where the old code squared it). The cap stays a real ceiling; the
blueprint the engine is handed still grows with it either way.

### Which item is worth upcycling — the picker ranks nothing
The item picker offers every upcyclable item and says nothing about which of them is a good
idea, while the community's heuristics are settled and public (surveyed 2026-08-27):

- **Single-ingredient recipes win**, because crafting doubles the upgrade opportunities per pass
  at the cost of electricity alone — sparr's whole design rests on it (forum t=122116, community
  claim), and the recommended-item lists in the field are the same shape: things that recycle
  back into the intermediates you wanted anyway (t=128693).
- **Machine choice dominates the yield** — ~1.25% / ~7.6% / ~14.5% input-to-legendary for AM3,
  EM plant and cryo plant (`quality-math.md` §3). The mod already makes that a player choice; it
  just never says which way is up.

**Half of this shipped in 1.0.0** (2026-08-28): the expected-output display now sits on the
status line, from `planner.split`'s solve — so the computation this entry needs already
exists and is memoised. What stays parked is the *ranking* half: a per-item figure in the
picker's tooltip, which would mean one solve per offered item rather than one per
configuration. Cheapest useful version is still a figure in the tooltip, not a sorted list:
a re-ordered picker fights the engine's own item ordering and the *Show unresearched items*
setting at once.

### Spoilage: does it outrun a tier's dwell time?
**The warning shipped 2026-08-27** — `item-spoils`, first among the warnings, on the 10 of 210
upcyclable items that carry a spoiling product or ingredient (`decisions.md` → the spoilage
bullet; the table and the `get_spoil_ticks` correction in `analysis/api.md` §29). Half the
original question is answered: Gleba and Nauvis intermediates genuinely qualify, and one of them
is productivity module 3.

**The other half was never measured** and is what is parked here: does spoilage actually outrun a
tier's dwell time at one machine per tier? The warning is deliberately indifferent — it reports
the property, not a predicted outcome — and the spread argues something finer is possible.
`stack-inserter` takes jelly at **4 minutes**, which cannot survive any realistic loop; `spidertron`
takes raw fish at **2.1 hours**, which almost certainly can. A dwell-time model would let the short
end refuse and the long end stay silent, instead of one warning covering both. The raw material
arrived with the pace line (2026-08-28): `quality_math.solve`'s flow pass reports expected crafts
per tier (`yield.machine_sets`/`recycled`) and `planner.loop_seconds` already prices each
station's craft time — what is still unbuilt is turning those into a per-tier dwell and comparing
it against `get_spoil_ticks`.

### Multiple recipes for one item — declined in public, recorded so it is not re-litigated
Asked for by pacak on the portal (discussion `6a831b6195e6fa72706517ef`, 2026-08-18): *"When
something can be crafted using multiple different recipes - would be great to be able to choose
which recipe to use"*, their example being `pipe-to-ground` as a route to efficient iron plates.
**The repo owner declined it for the 1.0 feature set**, with the reason: the loop's recipe is
chosen so that *recycling closes it*, and an alternative crafting recipe returns ingredients the
loop does not consume — byproducts with nowhere to go, worst in a modded game.

What the code does today, worth knowing before this is ever reopened: `upcyclable()` maps an item
to the **first** recipe that passes `is_upcyclable`, and the comment there names the only case
where two can pass — the same ingredient *names* in different amounts — so the pick is
deterministic (`pairs()` order over prototypes) but arbitrary between those two. If the ask
returns, the smallest honest version is a picker offering only the recipes whose ingredient set
the generated recycling recipe actually returns, which is the gate `is_upcyclable` already
computes; it would not have satisfied pacak's example, which is exactly why the owner said no.

### A beacon count the beacon gains nothing from
The count drop-down offers 1..`layout.max_beacon_count` and says nothing about what each count
transmits. Transmission is `N * distribution_effectivity * profile[N]`, and **`profile` is per
prototype**: vanilla's beacon is 1/sqrt(N) (`data/base/prototypes/entity/entities.lua:7703`, read
2026-08-27), so 1-4 vanilla beacons transmit 1.5x, 2.12x, 2.60x, 3.0x — sublinear, but every one
still buys something. **A beacon whose profile flattens buys nothing past its own cap**, and the
sibling mod in this repo ships exactly that: Pure Modules' beacon reaches 2.8125x at three
beacons and stays there forever — *"a fourth beacon costs its full power and adds nothing"*
(`pure-modules-realk/.ai-support/balance.md`). With that beacon picked, this mod's own drop-down
offers a 4 that costs 7.5 MW, four modules and a stack's worth of rows for zero effect.
`beacon_counter = "same_type"` is what makes a stack of identical beacons count together, so this
is the ordinary case for a stack rather than an exotic one.

Cheapest fix: read `profile` and stop offering counts past the last one that raises transmission.
Fuller fix: name the multiplier beside each count — which since 1.0.0 has its machinery half
built: the yield display exists, though the split's model deliberately prices beacons as
invisible (`decisions.md`), so a per-count multiplier stays its own read of `profile`.

## The blueprint the player is handed

Three small things about the *stack*, none of them layout. `blueprint.give` currently sets the
entities, `preview_icons` and `cursor_stack_temporary`, and nothing else.

- **A snap grid, so a second stamp lines up.** The blueprint is deliberately not one-shot and a
  second column of the same loop is a thing players want (`decisions.md`), but two stamps line up
  only by eye today. `blueprint_snap_to_grid` at the plan's own width x height would tile them.
  The trap is already recorded and already respected in the file: **`set_blueprint_entities`
  clears the snap grid**, so it must be written after — `analysis/api.md` §21, which notes in as
  many words that the mod sets none, so this only matters if one is wanted. Open: relative or
  absolute snapping, and whether forced alignment helps or annoys for a loop usually stamped
  once.
- **A label.** A blueprint dragged into the inventory to keep the design arrives unnamed;
  `LuaItemCommon.label` (and `label_color`) would make it *"Legendary iron gear wheel upcycler"*
  in the library. One line and one locale key, and it composes with the `preview_icons` already
  set. `allow_manual_label_change` is the neighbouring field to leave alone — the player's
  blueprint, the player's name for it.
- **A logistic group name on the request sections.** 2.0 logistic groups let one *named* section
  be edited in one place and followed by every chest carrying it. Naming each tier's section
  would make the whole loop's requests retunable **after** the build — precisely what the
  Ingredient amounts panel cannot do, since it only writes into the plan. The catch is that a
  group is force-wide: two loops for different items must not collide, and two loops for the same
  item at the same tier arguably *should* share, which is a design decision rather than a naming
  detail. Verify the blueprint-side shape before costing it — a blueprint's logistic filter is
  already a flatter table than the runtime one (`analysis/api.md` §21), so where `group` sits is
  not guessable.

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
- **The ingredient request default is a minute of crafting; the game's own convention is 30
  seconds** (noted 2026-08-27). Shift-right-click on a machine and shift-left-click on a
  requester chest fills it with *"enough ingredients for 30 seconds of continuous crafting"* —
  the vanilla behaviour a player's hands already know, and half what `planner.request_count`
  asks for. Not a defect: the loop is unattended and a fuller chest rides out belt lulls, and
  the number is now the player's anyway (Ingredient amounts, 2026-08-27). Worth knowing before
  anyone "fixes" the formula to match the game, and worth saying in the panel's tooltip if the
  divergence ever surprises someone.
- **Per-option hiding in a picker**, the genre's other answer to clutter (noted 2026-08-27).
  Mining Patch Planner lets a player shift+right-click an entity choice to hide it, permanently
  and per player. This mod's answer is the count rule plus *Show all build options*, which is a
  blunter instrument in the other direction: it hides by arithmetic rather than by taste, and a
  player with four modded belts cannot narrow them. Cheap only if it rides `state.prune`'s
  existing key shape; the interaction itself has no precedent in this modal, where every click
  on a picker already means "open the chooser".
- **Locale beyond `en`** — the cfg is structured for it; no other translations exist. Mining
  Patch Planner carries `uk`, `ru`, `pl` and `fr`, so shipping one is normal for the genre; the
  first candidate is **Spanish**, on the only evidence there is — a player who thanked the
  author in Spanish on the portal (discussion `6a8f5bb2eaca06c38cc3cc94`, 2026-08-27).
- **Choice reconciliation is written twice, once per layer — three pickers deep since
  2026-08-28** (found in review, 2026-08-17). `planner`'s `chosen_*` family answers "the pick
  if it is still valid, else the default" purely; `gui.apply_defaults` and the recipe and
  machine handlers answer the same question destructively, in a different idiom. They have
  already drifted once: `resolve_terminal_module` corrects on `module_fits` (machine **and**
  recipe), `chosen_terminal_module` only on `is_module` — which is why validate's
  terminal-module refusal branch is currently unreachable through the modal. The predicted
  third instance arrived with the productivity picker — `chosen_productivity_module` +
  `resolve_productivity_module` — accepted deliberately to keep the split release's blast
  radius off shipped terminal/beacon behaviour; both delegate their default to
  `planner.terminal_module`, and both check `module_fits`, so this pair at least cannot
  drift the way the terminal one did. The payoff shape is known (the 1.0.0 architecture
  review's alternative): delete the `resolve_*` pair, export `chosen_*`, and have the
  widgets compute `elem_value` inline — `resources()` never depended on the pre-write. Still
  parked for the **roboport picker** below or the next one after it.
- **`build_qualities` is a hand-list where `state.prune` derives** (found in review, 2026-08-17).
  `planner.validate` names the eight build materials whose quality it checks (the overflow chest
  joined them on 2026-08-20, and had to be added by hand exactly as this note predicts); a picker added later
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
