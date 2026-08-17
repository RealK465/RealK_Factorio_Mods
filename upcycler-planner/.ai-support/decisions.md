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
- **Portal name `upcycler-planner` is ours.** First published 2026-08-16 under the RealK
  account. Checked free beforehand (`GET /api/mods/upcycler-planner` 404 on 2026-08-16, method
  sanity-checked against `mining-patch-planner`) — worth having done: `pure-modules` was
  lost to a squat by a deleted account, and portal names stay taken after the account goes.
- **Prototype prefix `upl-`**, with settings and locale mod-level keys using the full
  `upcycler-planner`. Prototype names share one flat global namespace and a collision there is
  silent, which is the whole reason for a tag; settings are listed to players beside other mods'
  settings, where a three-letter tag would be meaningless. Matches the house style in
  `pure-modules-realk`. `upcycler-` was rejected because the portal already carries a different
  mod named `upcycler`, likely to own that name and its derivatives; `up-` as too generic — "up"
  reads as a direction before it reads as a namespace.
- **Hard dependency on `quality` (`>= 2.1.0` on `main`, `>= 2.0.0` on `legacy/2.0`).** The mod
  is worthless without quality tiers, and the dependency is the half that fixes load order —
  feature flags do not. The one line delivers the recycler on both tracks: in 2.1 `quality`
  declares `recycler >= 2.1.0`, and in 2.0 the recycler entity ships inside `quality` itself.
- **Space Age feature flags are declared, and the set forks by game version:
  `quality_required` on both tracks, `expansion_required` on `main` only.** Asked for by the
  repo owner on 2026-08-16, reversing the earlier no-flag call — that call was made when the
  only question was enforcement, where a flag is redundant behind the `quality` dependency.
  The deciding reason is the **mod portal**, which tags a mod as Space Age from the expansion
  flags in its uploaded `info.json` and *not* from its dependencies, so without a flag the mod
  never appears in the portal's Space Age section however hard its dependency is.
  `expansion_required` is omitted on `legacy/2.0` because **the flag does not exist in 2.0** —
  measured, it is silently ignored there and gates nothing, which would be a dead field
  pretending to be a gate (`analysis/api.md` §13). This mirrors vanilla `quality` exactly,
  which declares both flags in 2.1 and only `quality_required` in 2.0. `space_travel_required`
  was rejected: it would also earn the portal tag, but it unlocks planet and space-platform
  prototypes this mod never touches, so declaring it would be a false claim about the mod.
  Neither flag narrows the audience in practice — `quality` already ships only with Space Age.
- **Both game tracks, forked — `main` carries no 2.0 code.** Ported to Factorio 2.0 on
  2026-08-16 at the repo owner's ask, reversing the earlier 2.1-only call — that call rested
  on "`recycler` is 2.1-only", and 2.0's `quality` mod ships the recycler entity itself, so
  the mod's whole mechanism exists there; 2.0 is also the stable release most players are on.
  The port was first built as version-gated shared files and **the owner rejected that
  shape**: the 2.0 track is temporary — it stops getting work when 2.1 goes stable — and
  gated compat code in `main` would sit there confusing readers long after it stopped
  mattering. So the adaptations are forked copies on `legacy/2.0`: `scripts/planner.lua`
  (recipe `category` + `additional_categories` in place of 2.1's `categories`, and the
  mod-data bridge standing in for the missing `can_set_quality`),
  `prototypes/planner/icons.lua` (the recycler icon ships in `quality` there),
  `scripts/gui.lua` (local `contains_value`; core's is 2.1-only), and the legacy-only
  `data-final-fixes.lua` that writes the bridge — declared in the repo `CLAUDE.md` → *Git*
  beside Pure Modules' divergent list. A cherry-pick touching a forked file is rewritten by
  hand. The verified 2.0 API surface: `analysis/factorio-2.0.md`.
- **First release pair shipped 2026-08-16: `0.1.0` is the Factorio 2.0 build, `0.1.1` the
  Factorio 2.1 build** — the repo owner assigned the lower number to the 2.0 track in the
  release request, matching the ship-2.0-first pair convention. The two tracks share one
  sequential version line (repo rule, `factorio-multiversion`), so whatever ships next takes
  the next free number, whichever game it targets.
- **No flib dependency.** Its save/load-safe GUI handler registry is ~43 lines and worth
  reproducing by hand for one small frame; flib has nothing for shortcuts, and 0.17.0 was a
  breaking release. Copy the pattern, not the dependency.

## Portal presentation

Material for the mod portal page. Live since the 0.1.0 / 0.1.1 pair of 2026-08-16 — license
`default_gnugplv3`, category `utilities` (Mining Patch Planner's own), the README as the
description, the four gallery shots below in filename order. Every later upload or portal edit
still needs the repo owner's per-release approval.

- **`README.md` is the portal description**, uploaded verbatim by `fmtk details --readme`, so it
  is written for a player skimming the page rather than for a contributor. The portal takes
  GitHub-flavoured markdown, and images only as URLs to somewhere else.
- **`faq.md` is the portal FAQ tab**, synced by `fmtk details --faq` and shipped in the zip
  like `README.md` — deliberately not in `package.ignore`, it is a few hundred bytes of player
  help. One entry so far (added 2026-08-16, the owner's pick): the pickers are research-gated,
  and the *Show unresearched options* per-player setting lifts the gate.
- **`images/` holds the gallery shots, numbered in the order they are uploaded**: the planner
  window first, then the vanilla loops, then the modded one. The gallery has no order but upload
  order — the API's `images/edit` takes an ordered id list — so the number prefix is the only
  place that intent survives until the release that uses it.
  - `01-planner-menu.jpg` — the modal, legendary target, 5 machines and 4 recyclers.
  - `02-legendary-upcycling-assemblers.jpg` — the vanilla loop that menu plans.
  - `03-epic-upcycling-substations.jpg` — a vanilla epic loop, substations as the pole.
  - `04-modded-upcycling.jpg` — the same planner against modded machines and belts.
- **Numbering the files costs nothing, because the portal does not show gallery filenames.**
  `GET /api/mods/<name>/full` returns `assets-mod.factorio.com/assets/<sha1>.png` and no name at
  all — checked against `pure-modules-realk` on 2026-08-16. The repo `CLAUDE.md` says the portal
  displays the filename, which holds for the description's own links but not for the gallery.
- **`images/description/` is not gallery material.** It holds what the README embeds, which the
  portal can only take as URLs, so each file is mirrored on catbox:
  `vanilla-upcycling.gif` → https://files.catbox.moe/thkeot.gif,
  `modded-upcycling.gif` → https://files.catbox.moe/ulihf9.gif,
  `shortcut-button.jpg` → https://files.catbox.moe/08ae4j.jpg (the shortcut button, shown inline
  in the how-to-use steps). The local copies are the masters — catbox is not ours and can drop a
  file, and replacing one is a description edit, so the mapping has to survive.
- **The whole `images/` tree stays out of the zip** via `package.ignore`'s `images/**`. Tracked
  in git so a shot travels with the build it was taken from.

## Interaction

- **Shortcut → modal → Confirm → one-shot selection tool → click.** The player selects nothing
  in the world but ground; the GUI's choices define the footprint and the tool answers only
  *where*. The tool item carries `only-in-cursor`, so Q discards it.
- **Gated on the `recycling` technology** (plus `unavailable_until_unlocked = true`), not on
  quality. The loop is unbuildable without a recycler, so gating on quality alone would offer a
  button that cannot yet produce anything.
- **The modal is two blocks.** The top frame is what the loop **makes** — item, target quality,
  crafting machine, recycler. Under a *Build options* caption sits what it is built **out of**:
  belt, quality module, electric pole, pipe, and the trash-unrequested checkbox (checked by
  default). The pipe (added 2026-08-17 with fluid support, the repo owner's call for a picker
  over an auto-pick) carries no quality — like the belt, nothing about it scales with quality —
  and matters only when the recipe takes a fluid; its underground counterpart is derived, not
  picked, since no prototype links the pair (`<name>-to-ground` convention first, longest
  researched reach as the fallback).
  The recycler row is always shown — one recycler stopped being a non-choice once its quality
  became pickable. The Build options pickers carry no row labels on purpose: the strip reads by
  icon, the way the game's own tool settings do, so each tooltip opens with its own name in
  `[font=default-bold]`.
- **Quality is pickable on the machine, the recycler, the quality module and the pole — not on
  the belt.** A measured call, not a taste one: `belt_speed` is a plain attribute with no
  quality variant the way `get_crafting_speed(quality)` has one, so a legendary belt carries
  exactly as much as a normal one.
- **The shortcut button is `style = "green"`**, the repo owner's call on 2026-08-16 — it sits in
  the same `b[blueprints]` order block as the vanilla planners, and green is the one of the four
  styles (`default|blue|red|green`) not already worn by a neighbour there.
- **The icon is two symbols, not one badged item.** Recycler at 0.85 of the icon on the centre,
  legendary pip at 0.80 shifted 0.38 down-right — the mod turns recycling *into* quality, and a
  small corner pip reads instead as "a legendary recycler", which is the wrong idea. The repo
  owner's call on 2026-08-16, chosen from dispositions rendered at real button size.
- **Neither layer carries a negative shift**, because a negative one clips against the composed
  canvas instead of growing it (`analysis/api.md` §11). The separation therefore all sits on the
  pip rather than being split between the two.
- **`thumbnail.png` is the shortcut button at 144x144** — the game's own green button plate with
  the composed icon inside, so the portal card shows the thing the player will click. Built from
  the `--dump-icon-sprites` output rather than upscaled from a screenshot.
- **Icon layer `scale` and `shift` are written once as fractions of the icon and resolved per
  prototype.** They are measured against the prototype's *expected* icon size — 64 for an item,
  32 for a shortcut's `icons`, 24 for its `small_icons` — so one shared table renders the same
  layer at twice the intended size on a shortcut. A layer hanging outside the icon also inflates
  the composed bounding box, and the engine shrinks everything else to fit the button, which is
  the second half of what went wrong. `icons.lua` exports `item`, `shortcut` and `shortcut_small`
  from one set of fractions; evidence in `analysis/api.md` §11.
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
- **Belt-stacking inserters are never planned in** (the repo owner's call, 2026-08-17). A
  stacking hand holds out for a full belt stack of one item-and-quality, and a quality loop
  trickles dozens of item/quality combinations past every position — community-documented
  freezes in recycler builds (ktz.me, 2026-04-08, *Factorio: Recycler Belt Stacking*; community
  claim, not re-measured locally). The pick could not defend itself: vanilla's bulk-inserter and
  stack-inserter tie the scorer outright — both `bulk`, both rotation 0.04 — so the winner was
  engine iteration order. `inserter_max_belt_stack_size` is what tells them apart;
  `inserter_candidates()` excludes anything above one, a spec guards it, and `loop_spec`'s
  relief rig stands the planner's own pick so the wedge-relief measurement covers the inserter
  the layout actually plans.
- **Electric poles are planned in, standing in a dedicated utility column before every machine
  column.** The repo owner's call, 2026-08-17, superseding the free-tiles-first placement: a
  tidy vertical line of poles, in a column sized to the pole the player picked — and shared
  with the pipe run when the recipe takes a fluid, which is what the column-width rule adapts
  to (pole width, +1 for pipes; both absent collapses the columns and the old compact width).
  Researched-best **1x1** pole by default (largest supply area; a substation is never sprung on
  the player, though every size is pickable), clearable to "no poles"; columns first, any free
  tile as the fallback; best effort plus an orange count when even that cannot cover; one wired
  network via ghost copper wires. Algorithm in `analysis/poles.md`, engine facts in
  `analysis/api.md` §10. **Coverage counts only the largest wired component** — geometric
  coverage alone would call a consumer powered when its only pole sits on an unwired island, a
  lie that surfaces in game as a mystery.
- **Fluid recipes are planned in** (2026-08-17, the promised 0.2.0 feature): a pipe run down
  each utility column's east edge, spanning the full interior height, with every machine
  rotated per prototype so a fluid input connection meets it
  (`planner.machine_fluid_orientation`, the recycler-orientation lesson again; measured rule
  and the merged-fluid-box behaviour in `analysis/api.md` §14). Each run ends in underground
  stubs beneath the top and bottom ring belts; the player taps any column from either side
  with an underground pipe of their own and wires the columns together however they like.
  Nothing requests fluid by bots.
- **Nothing is ever built outside the ring — poles included.** The repo owner's call,
  2026-08-17, replacing the first-built external pipe header the same day: the ring rectangle
  is the plan's entire footprint, so the ground the player reserves is exactly what they see,
  and the plumbing topology outside it is theirs (a shared header, per-column feeds, tanks —
  their base, their call). What made it cheap: an interior header is impossible anyway (every
  interior row is an inserter reach-chain), so the only planned pipes were ever going to be
  vertical, and vertical runs end naturally in outward underground stubs
  (`analysis/layout-belt-ring.md` §Fluid recipes).

## What the planner refuses

- **Recipes with two or more distinct fluid ingredients**, with a message. A second fluid
  means a second, separate network; vanilla has exactly one such recipe (`ammonia-rocket-fuel`,
  measured 2026-08-17) and its product is already covered by the one-fluid `rocket-fuel`
  recipe, so the cost is zero items. Fluid PRODUCTS stay excluded by the single-item-product
  gate — the quantum processor returns hot fluoroketone beside the item and would need a drain
  network, a separate decision.
- **A fluid machine with no rotation that lands an input connection on the pipe run**, refused
  naming the machine. Unreachable in vanilla — the merged-box rule covers even the EM plant's
  opposite-flank inputs — so this is the modded-machine guard, and the alternative was piping
  it wrong: the reference book's own defect.
- **Self-recycling items** (steel and friends). A recycler-only loop needs thousands of inputs
  per legendary; the few shared designs that wash self-recyclers are a different architecture
  (recycler walls with no crafting stage — `analysis/blueprints.md` §9) with the same dire
  economics.
- **Recipes whose `allowed_effects` excludes quality**, checked on the recycling recipe too
  since the recyclers carry quality modules as well. `can_set_quality` is a different rule with
  a confusingly similar name — craftable *at* a quality, versus quality modules working on it at
  all. A recipe passing one while failing the other would carry an insert plan for a module it
  can never accept while the recyclers kept rolling ingredients up: a loop that limps rather
  than stops, which is the harder kind to diagnose.
- **Anything whose only "producer" is a recycling or Factoriopedia-hidden recipe.** Researching
  `recycling` unlocks every generated `*-recycling` recipe at once, so a naive "some enabled
  recipe produces it" test reads unresearched modules and cheat-mod infinity chests as unlocked.

## Testing

- **The mod carries a permanent four-tier test suite; the throwaway `--create` scratch
  harnesses are retired.** Decided 2026-08-16 with the repo owner (framework, installs, GUI
  scope and the eject investigation each approved explicitly). In-game tier: the
  **factorio-test** framework driven by its npm CLI — the only maintained, 2.1-compatible
  option (everything else in the ecosystem is dead) — with specs in `tests/`, registered
  behind `script.active_mods["factorio-test"]` in `control.lua`, `"tests/**"` in
  `package.ignore`, and **never** a `factorio-test` entry in `dependencies`. Pure tier:
  `tests/pure/` runs on host Lua too, sub-second. Static tier: luacheck + emmylua_check
  against fmtk-generated types. Mechanics, runner scripts and the hard-won Windows plumbing
  live in the repo's `factorio-testing` skill, not here.
- **The suite pins the historical harness numbers as regressions** — widths 11/13, the five
  pole scenarios (including big-pole's honest 7 unpowered), the 185 upcyclable items, the
  wooden-chest empty terminal — so a drift in any of them is a release-visible event, not a
  silent reshape.
- **The blacklist relief inserter is load-bearing, by measurement.** The eject investigation
  (journal 2026-08-16, evidence `analysis/api.md` §9.6) showed a rolled-up ingredient in the
  recycler's output wedges the recycler completely; only the relief inserter keeps the loop
  alive. Any future layout change must keep it, and a test now fails if the behaviour
  regresses.
- **GUI specs run in both tiers.** Headless works because a save's player stays connected
  under `--benchmark` (`analysis/api.md` §12); the graphics tier remains the real-client
  check, unattended thanks to a current-version save, freeplay's skip-intro remotes, and the
  runner's close-on-finish watcher.

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
