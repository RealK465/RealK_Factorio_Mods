# Upcycler Planner — decisions

Register: what is settled, and why. **Edited in place** — a decision that changes is rewritten
here rather than annotated, and the story of the change goes in `journal.md`. So this file
always reads as the present tense, and never carries "superseded" or "amended" markers.

Parked and open work has one owner, `deferred.md`. Evidence has one owner, `analysis/`. Never
ships (leading dot).

## Identity and packaging

- **Name `upcycler-planner`, title *Upcycler Planner*.** Renamed 2026-08-16 from *Upcycler
  Architect*: *Planner* is the word the genre uses — Mining Patch Planner and P.U.M.P. are what
  a player searching for a sibling will have found — and the collisions *Architect* was avoiding
  turned out not to exist, since `planner` is not a prototype type and `upcycler-planner` is a
  distinct portal name from the existing `upcycler` mod. Free to do only because nothing had
  shipped; the portal has no rename, so the window closed at the first upload.
- **Portal name is free.** `GET /api/mods/upcycler-planner` returned 404 on 2026-08-16, method
  sanity-checked against `mining-patch-planner` (200). Worth having done — `pure-modules` was
  lost to a squat by a deleted account, and portal names stay taken after the account goes.
- **Prototype prefix `upl-`**, with settings and locale mod-level keys using the full
  `upcycler-planner`. Prototype names share one flat global namespace and a collision there is
  silent, which is the whole reason for a tag; settings are listed to players beside other mods'
  settings, where a three-letter tag would be meaningless. Matches the house style in
  `pure-modules-realk`. `upcycler-` was rejected because the portal already carries a different
  mod named `upcycler`, likely to own that name and its derivatives; `up-` as too generic — "up"
  reads as a direction before it reads as a namespace.
- **Hard dependency on `quality >= 2.1.0`, no `quality_required` feature flag.** The mod is
  worthless without quality tiers, and unlike the flag a hard dependency also fixes load order —
  the flag would only make Space Age ownership mandatory. In 2.1 `quality` itself declares
  `recycler >= 2.1.0`, so this one line pulls the recycler in for free.
- **Factorio 2.1 only.** No `legacy/2.0` build: `recycler` is 2.1-only, and there is nothing
  shipped worth backporting.
- **Version starts at `0.1.0`**, open section, `Date: ????`.
- **No flib dependency.** Its save/load-safe GUI handler registry is ~43 lines and worth
  reproducing by hand for one small frame; flib has nothing for shortcuts, and 0.17.0 was a
  breaking release. Copy the pattern, not the dependency.

## Interaction

- **Shortcut → modal → Confirm → one-shot selection tool → click.** The player selects nothing
  in the world but ground; the GUI's choices define the footprint and the tool answers only
  *where*. The tool item carries `only-in-cursor`, so Q discards it.
- **Gated on the `recycling` technology** (plus `unavailable_until_unlocked = true`), not on
  quality. The loop is unbuildable without a recycler, so gating on quality alone would offer a
  button that cannot yet produce anything.
- **The modal is two blocks.** The top frame is what the loop **makes** — item, target quality,
  crafting machine, recycler. Under a *Build options* caption sits what it is built **out of**:
  belt, quality module, electric pole, and the trash-unrequested checkbox (checked by default).
  The recycler row is always shown — one recycler stopped being a non-choice once its quality
  became pickable. The Build options pickers carry no row labels on purpose: the strip reads by
  icon, the way the game's own tool settings do, so each tooltip opens with its own name in
  `[font=default-bold]`.
- **Quality is pickable on the machine, the recycler, the quality module and the pole — not on
  the belt.** A measured call, not a taste one: `belt_speed` is a plain attribute with no
  quality variant the way `get_crafting_speed(quality)` has one, so a legendary belt carries
  exactly as much as a normal one.
- **Pickers offer only what the force has researched.** The per-player
  `upcycler-planner-show-all` setting shows everything instead, standing in for the game's own
  "show all items in selection lists" option, which is not exposed to the runtime API. An empty
  researched subset falls back to the full list so the modal never dead-ends.
- **Storage holds flat strings.** `machine` / `machine_quality` pairs rather than the
  `{name, quality}` tables the `-with-quality` widgets speak. Two silent failures ride on this:
  `control.lua`'s stated contract is that storage holds nothing but strings, and `state.arm`'s
  snapshot is a **shallow** copy — a nested table would stay shared with the live choices rather
  than frozen at Confirm, so reopening the modal with a tool in hand would change what was about
  to be placed.

## What gets planned

- **Ghosts, one entity at a time — never a blueprint string.**
  `LuaSurface.create_entities_from_blueprint_string` is documented *"only works when used in
  simulations"*. Both reference planner mods emit ghosts the same way. Computing ghosts also
  means the layout can answer the player's choices instead of being a stored string.
- **Belt ring first**, specified in `analysis/layout-belt-ring.md`. Chosen over the smaller bot
  loop because product circulation stays on its own belts, so it behaves identically in an
  isolated pocket and in a base-wide logistic network — the right default for a mod strangers
  install into arbitrary bases. The **bot loop is a deferred toggle, not a dead idea**: fully
  specified in `analysis/layout-bot-loop.md`, with its two blockers in `deferred.md`.
- **One machine per tier.** The compact "casino" every shared blueprint ships. Honest framing:
  a convenience build, not a throughput build — sustained ratios taper about tenfold per tier.
  If scaling is ever added, repeat *columns per tier* rather than inventing new geometry.
- **Modules are planned, not merely requested**: quality below the target tier, productivity at
  it (nothing left to roll into), quality in the recyclers. The terminal machine is left
  **empty** when the recipe or the machine refuses productivity — `allow_productivity` defaults
  to false and only ~43 of base's 193 recipes opt in, so this is the common case rather than the
  exotic one. Research is a separate axis on purpose: *not researched yet* still falls back to
  the quality module, a small loss of yield rather than a gap. Correct for normal-quality
  modules; the optimal split shifts once the player's own modules are high quality, which is a
  later refinement better driven by `get_roll_chances()` than by a hardcoded table.
- **Modded recyclers work by rotation, not by convention.** `vector_to_place_result` is
  per-prototype, so `planner.recycler_orientation()` computes the rotation that lands the throw
  in the machine above. Width is not a constraint — column pitch is `max(Wm, Wr)`. The one hard
  limit is that the throw lands inside the machine (`eject_col < Wm`), refused with the minimum
  width named.
- **Chests are hard-constrained to 1x1.** Every chest position in the layout is exactly one
  tile, so footprint is a geometric constraint of the row plan rather than a preference. A
  modded 1x1 chest with more slots still wins legitimately; anything bigger is out regardless of
  research.
- **Fuelled inserters are never planned in**, and every planned inserter must reach one tile. An
  unattended loop cannot keep a burner fed. When every researched inserter needs fuel — how a
  fresh Space Age game genuinely starts — validation says so instead of planning a loop that
  would starve.
- **Electric poles are planned in.** Researched-best **1x1** pole by default (largest supply
  area; a substation is never sprung on the player, though every size is pickable), clearable to
  "no poles"; free tiles first, added pole columns only when needed; best effort plus an orange
  count when even that cannot cover; one wired network via ghost copper wires. Algorithm in
  `analysis/poles.md`, engine facts in `analysis/api.md` §10. **Coverage counts only the largest
  wired component** — geometric coverage alone would call a consumer powered when its only pole
  sits on an unwired island, a lie that surfaces in game as a mystery, and the honest tally is
  also what lets a connectivity failure drive growth.

## What the planner refuses

- **Fluid recipes**, with a message. Placing unconnected pipe stubs would reproduce the
  reference book's own defect; worth doing properly rather than early — `deferred.md`.
- **Self-recycling items** (steel and friends). A recycler-only loop needs thousands of inputs
  per legendary, and no shared design anywhere uses one.
- **Recipes whose `allowed_effects` excludes quality**, checked on the recycling recipe too
  since the recyclers carry quality modules as well. `can_set_quality` is a different rule with
  a confusingly similar name — craftable *at* a quality, versus quality modules working on it at
  all. A recipe passing one while failing the other would carry an insert plan for a module it
  can never accept while the recyclers kept rolling ingredients up: a loop that limps rather
  than stops, which is the harder kind to diagnose.
- **Anything whose only "producer" is a recycling or Factoriopedia-hidden recipe.** Researching
  `recycling` unlocks every generated `*-recycling` recipe at once, so a naive "some enabled
  recipe produces it" test reads unresearched modules and cheat-mod infinity chests as unlocked.

## Rejected

Written down so they are not re-litigated. A rejected idea that is not recorded comes back.

- **Blueprint strings for placement** — the API forbids it outside simulations. See above.
- **`upcycler-` and `up-` as the prototype tag** — see Identity.
- **A strict `Wr < Wm` recycler width rule.** It came from the reference design's
  down-the-side product channel, which was never built: the real product path runs up to the top
  ring, so the recycler band is empty beside the recycler. The lesson generalises — check a
  constraint against the code, not against the document that described the design before it was
  built.
- **Labelled rows in the Build options strip.** The repo owner's explicit call for the icon
  strip. It is also the standing fallback if a chosen prototype's own tooltip turns out to
  override the custom one — ask before switching.
- **Degrading rather than excluding quality-refusing recipes.** Leaving the non-terminal
  machines' slots empty and letting the recyclers carry the climb alone would keep those items
  in the picker at roughly half the roll rate. Excluding them is simpler and honest — a loop the
  mod cannot build properly is better refused than shipped degraded — but the option is real, so
  it is recorded rather than left to be re-derived.
