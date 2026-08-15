# Upcycler Architect — design record

Decisions and their reasons, recorded as they are made. Never ships (leading dot).

## 2026-08-15 — feasibility investigation

The question was whether a mod can compute an upcycling layout and place it in the world the
way Mining Patch Planner and P.U.M.P. place theirs. **It can.** Both reference mods were
extracted from the local `*.zip` copies and read; every API call below was verified against
`doc-html/runtime-api.json` from the installed 2.1.14, not from memory.

### Placement: ghosts, not blueprint strings

Neither reference mod uses a blueprint string. Both walk their computed layout and call
`surface.create_entity{name = "entity-ghost", inner_name = ...}` one entity at a time:

- `pump_2.2.2/constructor.lua:208` — `create_entity{name = "entity-ghost", ...}`
- `mining-patch-planner/layouts/*.lua` — the same, behind a `builder.create_entity_builder`
  wrapper; `layouts/simple.lua:1968` does tile ghosts the same way.

This is the route to use, and **the blueprint-string route is a dead end**:
`LuaSurface.create_entities_from_blueprint_string` is documented *"This method only works when
used in simulations"* — it exists for menu-background sims, not for mods.
`LuaRecord.build_blueprint` is real and usable, but it needs an actual blueprint record to
exist first, which buys nothing over emitting ghosts directly. Computing ghosts also means the
layout can respond to the player's choices instead of being a stored string.

### Every piece an upcycler specifically needs exists

Verified present in 2.1.14:

| Need | API |
|---|---|
| Place a ghost of any entity | `create_entity` `entity-ghost` group: `inner_name` (req), `tags` |
| Machines that are themselves quality | `create_entity` param `quality`, defaults to `normal` |
| Set the recipe on a planned machine | **`ghost.set_recipe(recipe, quality)` after creation** — see correction below |
| Request quality modules into the ghosts | **`ghost.insert_plan`** — see correction below |
| Read back what was planned | `LuaEntity.ghost_name` / `ghost_prototype` / `ghost_type` / `item_requests` / `quality` |
| The P.U.M.P. interaction model | `SelectionToolPrototype` + `on_player_selected_area` / `_alt_` / `_reverse_` |

Pinning the recipe's quality is exactly the axis an upcycler is built around — one machine per
tier, each pinned to that tier.

**Two rows above were wrong when first written, and were corrected on 2026-08-15** after
checking `runtime-api.json` directly. Both are load-bearing, so the detail is in
`analysis/api.md` §3 and only summarised here:

- **`create_entity` cannot set a ghost's recipe.** Its variant groups are keyed by the `name`
  argument, so with `name = "entity-ghost"` only `inner_name` and `tags` apply —
  `recipe`/`recipe_quality` belong to the `assembling-machine` group and never take effect.
  Create the ghost, then call `set_recipe(recipe, quality)` (positional, recipe first).
- **Modules go through `insert_plan`, not an `item-request-proxy`.** `LuaEntity.insert_plan` is
  read *and* write with `EntityGhost` among its subclasses; `LuaEntity.item_requests` is
  read-only in 2.1. Both reference planner mods use `insert_plan`, and the proxy would need the
  ghost to exist first anyway.

### Prior art: the niche is open

No mod generates these layouts. Checked on the portal:

- [`upcycler`](https://mods.factorio.com/mod/upcycler) — unrelated. A machine that converts N
  items into 1 of the next tier. Shares the word only.
- [`quality-cycler`](https://mods.factorio.com/mod/quality-cycler) — shifts quality up/down
  *inside* an existing blueprint. Does not design anything.

Everything else is hand-shared blueprint books — [FactorioBin](https://factoriobin.com/post/8wj94j/6),
[the forums](https://forums.factorio.com/viewtopic.php?t=121438), Factorio Prints. That is the
gap: players answer the same layout questions by hand every time.

## 2026-08-15 — architecture

Second session the same day. Two real upcycler blueprints were decoded (the repo owner's own,
and a 12-blueprint book found online), ~14 more designs were read, both reference planner mods
were cloned and studied, and the quality maths was checked against the wiki and FFF-375. The
condensed record is in **`analysis/`** — start at `analysis/README.md`. Everything below is a
decision; the evidence for it is there.

**The mechanism that explains the whole reference design** — and the thing most worth not
re-deriving: the recycler is a 2x4 furnace with `vector_to_place_result = {-0.35, -2.3}`
(`data/recycler/data.lua:109`), so it **throws its output out of its north face like a mining
drill**. Every reference build stands the recycler directly under its machine, tangent, so
recycled ingredients reach the crafter with *zero inserters*. The machine is pinned to
`recipe_quality = q_k` and quality ingredients match **exactly**, so an ingredient the recycler
rolled up a tier would jam the eject — which is what the blacklist-filtered inserter beneath the
recycler is for. Keep the tangency; it is the constraint everything else hangs off.

**The layout is parametric in more than tier count.** The online book solves the same design at
four target qualities across three machine types, which pins the scaling law: machines `t+1` at
pitch = the machine's tile width (3 for an assembling machine, 4 for an electromagnetic plant
with its 5 module slots, 5 for a foundry), recyclers `t`, only the terminal column different.
That is the argument for a layout *engine* rather than a stored blueprint — and the "with
fluids" variants in that book are actually **unbuildable as captured**, because a parameterised
blueprint loses the machine rotations that fluid connections need. A mod that knows the real
recipe at plan time can fix exactly that.

## Decided

- **Name: Upcycler Architect**, portal name `upcycler-architect`. Chosen 2026-08-15 over
  *Upcycler Planner*, *Upcycler Generator*, *Quality Loop Planner* and *Quality Casino*.
  "Upcycler" is the word players search for. "Architect" was preferred over the genre's usual
  "Planner" because it avoids two collisions at once: `generator` is Factorio's own prototype
  type for power entities, and the plain `Upcycler` mod already exists and does something else.
  The accepted cost is that "Architect" is not the genre's word, so the mod is a little less
  instantly legible than *… Planner* would have been.
- **Portal name is free.** `GET /api/mods/upcycler-architect` returned 404 on 2026-08-15;
  the method was sanity-checked against `pump`, `mining-patch-planner`, `upcycler` and
  `quality-cycler`, all 200. Worth having done — `pure-modules` was lost to a squat by a
  deleted account, and portal names stay taken after the account goes.
- **Hard dependency on `quality >= 2.1.0`**, not a `quality_required` feature flag. In 2.1
  `recycler` is its own expansion mod and `quality` declares `["base >= 2.1.0",
  "recycler >= 2.1.0"]`, so depending on `quality` pulls the recycler in for free. A hard
  dependency is right because the mod is worthless without quality tiers, and unlike the
  feature flag it also fixes load order. No `*_required` flag is declared.
- **Factorio 2.1 only.** No `legacy/2.0` build. `recycler` is 2.1-only on this machine, and
  there is nothing shipped worth backporting.
- **Version starts at `0.1.0`**, open section, `Date: ????`.

Decided 2026-08-15 in the architecture session (reasons in `analysis/`):

- **Interaction: shortcut -> GUI -> Confirm -> one-shot selection tool -> click.** This answers
  the long-standing first question below: **the player selects nothing in the world but ground.**
  The GUI's choices define the footprint; the tool only answers *where*. The tool item carries
  `only-in-cursor` so Q discards it.
- **Three GUI inputs**, as asked: recipe, target quality, and the crafting machine — plus the
  recycler, which is a fourth picker only because a modded game may have more than one (vanilla
  pre-fills it and it is a non-choice). A belt picker and a trash checkbox joined the modal
  later the same day — see the "modal grows" section below.
- **Belt ring first.** The faithful generalisation of the reference design, specified in
  `analysis/layout-belt-ring.md`. Chosen over the smaller bot loop because product circulation
  stays on its own belts, so it behaves identically in an isolated pocket and in a base-wide
  logistic network — the right default for a mod strangers install into arbitrary bases.
- **The bot loop is deferred, not dropped** — it is a planned GUI toggle and is fully specified
  in `analysis/layout-bot-loop.md`. Two things must be fixed before it ships: the tier-0 return
  chest would drain the base's normal-quality production, and bot flight distance is unbounded
  in a large shared network.
- **Shortcut gated on the `recycling` technology** (plus `unavailable_until_unlocked = true`).
  The loop is unbuildable without a recycler, so gating on quality alone would offer the player
  a button that cannot yet produce anything.
- **Modules are planned, not just requested**: quality below the target tier, **productivity at
  it** (nothing left to roll into), quality in the recyclers (their `allowed_effects` excludes
  productivity anyway). Best unlocked tier, normal quality. Correct for normal-quality modules;
  the optimal split shifts once the player's own modules are high quality, which is a later
  refinement best driven by `LuaQualityPrototype.get_roll_chances()` rather than a hardcoded
  table.
- **One machine per tier.** The compact "casino" every shared blueprint ships. Honest framing:
  it is a convenience build, not a throughput build — sustained ratios taper about tenfold per
  tier. If scaling is ever added, repeat *columns per tier* rather than inventing new geometry.
- **Fluid recipes are refused in milestone 1**, with a message. Placing unconnected pipe stubs
  would reproduce the reference book's own defect.
- **Self-recycling items (steel and friends) are refused** for now — a recycler-only loop needs
  thousands of inputs per legendary, and no shared design anywhere uses one.
- **No flib dependency.** Its save/load-safe GUI handler registry is ~43 lines and worth
  reproducing by hand for one small frame; flib has nothing for shortcuts, and 0.17.0 was a
  breaking release. Copy the pattern, not the dependency.
- **Prototype prefix is `ua-`** (`ua-open`, `ua-planner`). Chosen to match the house style in
  `pure-modules-realk`, which tags prototypes short (`pure-beacon`) while giving settings and
  locale mod-level keys the full mod name. `upcycler-` was rejected because the portal already
  carries a different mod named `upcycler`, which likely owns that name and its derivatives.
  The rule is written up in the mod's `CLAUDE.md` under Naming — renaming later costs a
  migration and a major bump, so it is settled before the first prototype exists.

## Open questions

Parked and open work has one owner, **`deferred.md`**, so the two lists cannot drift apart.
The standing questions at the time of writing: modded quality tiers (walked from
`prototypes.quality["normal"].next`, untested against a tier-adding mod), whether the GUI
should show expected output via `get_roll_chances()`, `thumbnail.png` before release, and a
time-boxed cursor-blueprint placement spike. Detail and pick-up context for each live there.

## 2026-08-15 — first implementation

Built the same day: shortcut, modal, planner derivations, the pure layout function and the
ghost builder. The mod is functional end to end and the data stage validates clean.

Two things learned the hard way, both worth not repeating:

- **`RecipePrototypeFilter` has no `name` filter**, though `EntityPrototypeFilter` and
  `ItemPrototypeFilter` both do. A `choose-elem-button` with `elem_type = "recipe"` and a
  computed name list is a hard error: *"Unknown filter type: name"*. This is why the first
  input is an **item** picker with the recipe derived from it — which is how the mod was
  described anyway. Verify a filter against the *specific* concept, never by analogy to
  another one.
- **Recycling recipes pass a naive upcyclability test.** A self-recycling recipe takes an item
  and returns that same item, so it trivially "closes the loop" while producing nothing. They
  have to be excluded by category — the recycler mod excludes the same category when
  generating recipes. Before the fix the picker offered 276 items; after, 185.

Also settled during implementation: the ring is a plain rectangle with a dedicated return
column rather than the shared blueprints' underground-threaded loop, because at this height the
span beneath a machine exceeds even a turbo belt's reach. And the extract chests inside the
loop are **plain containers** — but the product buffer in front of each recycler ended up a
**requester chest** after all, so bots can top it up when the ring runs slow; the engine's
quality-exact request rule keeps every tier above normal sealed from the base regardless. The
full set of network contacts and their counts is in `analysis/layout-belt-ring.md` §Request
counts.

## 2026-08-15 — building materials are gated by real research

First in-game feedback (a save with Editor Extensions installed) surfaced two bugs with one
root: `is_unlocked` counted *any* enabled recipe that produces an item, and **researching
`recycling` enables every generated `*-recycling` recipe at once** (`analysis/api.md` §8).
Reversal recipes produce the ingredients of what they grind, so `quality-module-3-recycling`
made unresearched quality-module-2 read as unlocked; and EE's infinity chests — whose only real
recipes are disabled cheat recipes, and which never opt out of recycling — got self-recycling
recipes, so the requester picker returned `ee-infinity-chest-requester` by iteration order.
Reproduction showed it worse than reported: `ee-super-productivity-module` (+250%) won the
productivity pick the same way, and would have kept winning at full research.

Three guards, all in `planner.lua`:

- **Recycling recipes never count as producers.** They consume the item class; counting them as
  a source inverts causality ("could grind one down" is not "can build one").
- **Factoriopedia-hidden recipes never count either.** That is how cheat tools ship free
  recipes, and EE force-enables its `ee-testing-tool` recipes whenever a player turns its
  editor helpers on — so an enabled-recipe test alone would regress during exactly the editor
  sessions this mod gets tested in. `hidden_in_factoriopedia` sits on `LuaPrototypeBase`
  (parent-key trap, `analysis/api.md` §6).
- **The chest picker takes only real `logistic-container`s, largest inventory first.** Infinity
  containers report a `logistic_mode` too, and a chest that conjures items out of nothing is
  never a correct buffer in a loop whose job is to conserve one population of items. Best-by
  also replaces first-iterated, so the pick is deterministic. This layer holds even in cheat
  mode, independently of the producer guards.

Verified with a scratch harness (real game via `--create`, EE and flib loaded, assertions
appended to a scratch copy's `control.lua`): 17/17 pass across fresh, recycling-only,
cheat-mode, per-recipe-unlock and full-research states, ending in a full rare-tier plan with
five `requester-chest` ghosts and zero `ee-` entities. As a negative control the producer guard
was reverted and the harness reproduced the original bugs (quality-module-2 and
ee-super-productivity-module picked with only recycling researched) — the test detects what it
claims to.

## 2026-08-15 — the modal grows a belt picker and a trash checkbox

Both at the repo owner's ask, the same session as the research gating.

- **Belt picker**, defaulting to the fastest researched belt — the previous automatic choice.
  A slower ring is a legitimate call (the fast belts are expensive and the ring is short), so
  the belt is the one building material with a player override. An emptied button snaps back
  to the researched best and shows it, so the row always displays the belt that will actually
  be placed; a stale or wrong-type name falls back the same way at plan time.
- **"Trash unrequested items" checkbox, checked by default.** Only the trash half of the
  requester flags is exposed: request-from-buffers is purely additive and stays always-on,
  while trashing has a real downside — bots hauling surplus off to storage — that some players
  will want off. The flag rides on the *plan*, not through the layout: which chests exist is
  geometry, what they do with surplus is the player's call at Confirm. A pending snapshot from
  before the checkbox existed reads as checked (`~= false`).
- One dispatcher quirk: a checkbox click fires both `on_gui_click` and
  `on_gui_checked_state_changed`, and both are routed, so the handler runs twice per click. It
  reads the element's current state, which makes the repeat harmless — cheaper than teaching
  the dispatcher to filter by event.

Verified in the same live-harness style: 28/28, including the belt override, the wrong-name
fallback, and all three trash-flag states riding the plan.

## 2026-08-15 — three GUI traps from the first session with the new inputs

All three found by the repo owner in game, all three silent.

- **`elem_value` is not an `add()` parameter.** It is a runtime attribute; `add()` ignores
  unknown fields without a word, so a picker "pre-filled" inline opens empty. Verified against
  `runtime-api.json`: `add` accepts `elem_filters` but has no `elem_value`. This is why the
  belt picker showed blank while the machine picker *looked* fine — the machine value was
  being assigned at runtime by the recipe-change handler, never by `add()`. Every picker now
  assigns `elem_value` after creation.
- **`elem_filters = nil` means NO filter, not "nothing yet".** Clicking the machine picker
  before choosing an item offered every entity in the game, belts and chests included. The
  fallback is `planner.machine_candidates()` — every machine the mod could ever plan with
  (the static `is_upcycling_machine` checks, no recipe-category match).
- **Padding on a checkbox displaces the check mark.** `style.top_padding = 4` shifted the
  widget's content — the mark — down while the box graphic stayed put, leaving a half-clipped
  tick hanging out the bottom of the square; measured on the owner's screenshot, displacement
  equals the padding. Diagnosed against core's own sprites (`gui-new.png`: box {56,132},
  checkmark {112,132}, both 28x28 — the real mark fills the box and overshoots top-right).
  Spacing on a leaf widget with custom drawing is a margin's job: `top_margin` displaces
  nothing.

## 2026-08-15 — chests are hard-constrained to one tile

AAI Containers & Warehouses made the largest-inventory rule pick its **4x4 requester
storehouse**, and the placed rows overlapped into a solid wall of warehouse ghosts — every
chest position in the layout is exactly one tile, so footprint is a geometric constraint of
the row plan, not a preference. `container()` and `logistic_container()` now require
`tile_width == 1 and tile_height == 1` before scoring by inventory. A modded 1x1 chest with
more slots still wins legitimately; anything bigger is out regardless of research.

Worth remembering from the same screenshot: the overlapping ghosts **placed successfully** —
the all-or-nothing `can_place_entity` pass checks each position against the *current* world,
so N ghosts that each fit alone but collide with each other all pass, and `create_entity`
does not refuse the collision either. With every real entity at most one tile per layout
cell the layout cannot self-collide, so this stays a latent fact rather than a bug — but any
future change that lets a planned entity outgrow its cell has to revisit it.

Verified live with AAI + EE + all research: picks return to `requester-chest` /
`passive-provider-chest` / `steel-chest`, a rare plan carries zero chests bigger than 1x1.
A chest-type picker in the modal was floated by the repo owner as a maybe — parked in
`deferred.md`; the hard 1x1 filter is the default behaviour either way.

## 2026-08-15 — modded recyclers: rotation computed, any width fits

Age of Production's salvager (`aop-salvager`) broke the layout twice at once: 4x4 against the
3-tile column pitch (recyclers overlapped into a train), and an eject vector out its EAST
flank (`{2.35, -0.5}`) where the layout hardcoded vanilla's north throw — "not properly
rotated" was literal. The general facts, all verified live:

- `vector_to_place_result` is per-prototype and rotates with direction, and the game hands it
  over in ARRAY form (`[1]`,`[2]` — documented "will always provide the array format").
- The layout's real requirement was never "faces north": it is "the eject tile lands in the
  row directly above the footprint", the machine's bottom row under tangency.
  `planner.recycler_orientation()` tries the four rotations and returns direction, rotated
  footprint and eject column, or nil. Vanilla → north 2x4 col 0; salvager → WEST 4x4 col 1.
- **Width is not a constraint.** The first fix refused `Wr >= Wm`; the repo owner pushed back
  and re-deriving against the *implemented* layout showed the strict-width rule came from the
  reference design's down-the-side product channel, which was never built — the real product
  path runs up to the top ring, so the recycler band is empty beside the recycler. Column
  pitch is now `max(Wm, Wr)` (terminal column stays at `Wm`), and the only remaining limit is
  that the throw lands inside the machine: `eject_col < Wm`, refused with the minimum width
  named (`recycler-needs-wider-machine`). Lesson: check a constraint against the code, not
  against the doc that described the design before it was built.
- `best_recycler` prefers the narrowest oriented buildable recycler, so vanilla's stays the
  default over the salvager.

Verified live with PlanetsLib + AoP: salvager + AM3 plans 2 west-facing salvagers at width 13
(`2 + 2*4 + 3`), salvager + the 5-wide `aop-advanced-assembling-machine` at width 17, vanilla
byte-identical at width 11 — with a generic no-overlapping-tiles check and an
eject-tile-is-a-machine-tile check green on all three. The harness's overlap and eject
invariants are the ones to re-run after any row-plan change.

## 2026-08-15 — researched-only pickers, the first setting, and the inserter fuel rule

- **Every picker offers only what the force has researched** — items (canonical recipe
  enabled), machines, recyclers, belts (buildable), qualities (`is_quality_unlocked`). The
  game's own "Show all items in selection lists" option is **not exposed to the runtime API**
  (searched 2.1.14's `runtime-api.json`), so a per-player bool setting,
  `upcycler-architect-show-all`, stands in for it — the mod's first `settings.lua`. An empty
  researched subset falls back to the full list so the modal never dead-ends; the frame
  rebuilds on `on_runtime_mod_setting_changed`.
- **The quality dropdown's offered list rides in the element's tags.** Research can finish
  while the modal is open; an index into a re-derived list would then name the wrong quality.
  The default target is the highest *offered* tier, and a remembered choice that is no longer
  offered snaps back to it.
- **Fuelled inserters are never used** (`burner_prototype` / `fluid_energy_source_prototype`)
  — an unattended loop cannot keep them fed. `planner.any_inserter` ignores the rule so
  validate can tell "everything researched needs fuel" (its own message,
  `only-fuelled-inserters`) from "not enough filter slots". **A fresh Space Age force
  genuinely starts burner-only**, so that message is the correct day-one state, vanilla
  included; the electric inserter takes over the moment electronics lands.
- **Status colours by severity**: red when Place is disabled, orange for warnings — which
  refresh used to compute and then silently drop; they render now.
- Two traps for the record: the inserter speed is the METHOD
  `get_inserter_rotation_speed(quality)` — the `rotation_speed` ATTRIBUTE exists but belongs
  to cars and turrets and reads nil on an inserter (the arithmetic crash lived on disk for
  minutes and the repo owner's live game caught it before the harness report landed); and
  per-player settings read through `player.mod_settings`, not `settings.global`.

Verified live, vanilla modset: 19/19 across fresh/electronics/full-research states, including
the fuel-only refusal message and the researched-subset lists at both extremes.

## 2026-08-15 — first structured code review, and what it fixed

Three parallel reviewer agents read the whole codebase against these notes. Everything below
was fixed the same session and verified with a fresh live harness (35/35, SA modset,
`--create` with assertions appended to a scratch copy — including builder placement on real
ground). The two worth remembering:

- **The long-handed inserter won the inserter pick for the whole early game.** The pick scored
  bulk + rotation speed and never checked reach; long-handed is electric, filterable, faster
  than the plain inserter, and unlocked by `automation` — the first technology — so from
  automation until fast-inserter every planned inserter grabbed from the wrong row and the loop
  placed cleanly and did nothing. The earlier 19/19 matrix tested fresh/electronics/full and
  skipped exactly that window. Fix: the memoised inserter candidate table admits only one-tile
  reach (`reaches_adjacent_tiles`, reading `inserter_pickup_position` /
  `inserter_drop_position`, api.md §6), so `any_inserter` inherits the rule and the
  fuel-message split stays truthful. The automation-only state is now in the harness matrix.
- **Confirm could destroy what the player held.** `clear_cursor()` returns false when the
  cursor cannot be emptied (full inventory), and `set_stack` on top of that overwrites the
  stack. Now gated, with a `cursor-full` message; the pending snapshot is armed only after the
  tool is actually in the cursor.

The rest of the round:

- `state.prune` drops choices by **membership** in the planner's candidate lists rather than
  bare prototype existence — a mod update can keep a name while changing the prototype under
  it, and prototypes only ever change on configuration change, which is exactly when prune
  runs.
- `validate` re-runs the full machine gate plus a machine-can-craft-recipe check, and requires
  the recycler to still recycle and carry module slots; `builder.apply_modules` tolerates a
  nil slot count.
- A click on an armed tool whose snapshot was pruned clears the cursor and says so, instead of
  silently doing nothing.
- A **blocked placement cancels the deconstruction orders it just placed** — only its own,
  pre-existing marks survive — keeping the "leaves the world untouched" contract honest.
- Ghosts land on `event.surface`, not `player.surface`, via a context argument to
  `builder.place`.
- The **terminal catcher whitelists the product at the target quality and every quality above
  it** (clamped to filter slots, nearest first), closing the product half of the
  above-target-roll leak; the ingredient half stays in `deferred.md`, now with a warning about
  the fix that does not work.
- The placed-count message reports ghosts actually created; the quality-chain walk is bounded
  by iterations so an all-hidden malformed cycle cannot hang it; and `validate` takes
  `(force, choices)` like `plan`, so the two central entry points cannot be called with
  swapped arguments unnoticed.

A simplify pass the same session (four review agents: reuse, simplification, efficiency,
altitude) settled three structural invariants, each now documented at its site in the code:
**candidate scans are memoised, force checks never are** — the pickers' pure prototype
predicates live in `candidates()` tables beside `machine_candidates()`, while buildability
and research run fresh per call, which cut a GUI refresh from ~15 full prototype scans to
force-filtering a handful of short lists (`validate` also hands its gathered resources to
`plan` so one refresh pays once); **layout owns its geometric minima** — `MIN_MACHINE_WIDTH`
and `MIN_RECYCLER_WIDTH` are exported constants the planner consumes, so the gates cannot
drift from the column arithmetic they derive from; and **prune tests membership through
planner-exported predicates** (`is_belt`, `is_quality`) rather than restating the rules. The
Confirm snapshot moved into `state.arm()` as a whole-table copy so a new choice field cannot
be silently left out of it. Verified by the same harness, extended to 36/36.
