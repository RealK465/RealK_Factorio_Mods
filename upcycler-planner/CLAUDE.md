# CLAUDE.md — Upcycler Planner

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

A planner in the tradition of Mining Patch Planner and P.U.M.P.: the player picks an item and a
target quality, and the mod designs a complete upcycling loop and hands it over as a blueprint.

**It has worked end to end since 2026-08-15**, when a shortcut opened a modal whose Confirm
handed over a one-shot selection tool and the mod placed the ghosts itself. **Since 2026-08-18
Confirm hands over an ordinary blueprint instead**, so preview, rotation, flipping, snapping,
undo and every build mode are the engine's own and the mod handles no placement event at all. The modal is in two
blocks since 2026-08-16 — what the loop MAKES (item, target quality, crafting machine and
recycler, the last two with a quality of their own) above a
**Build options** block for what it
is built OUT OF: belt, inserter, ingredient chest, stock chest, relay chest, output chest,
overflow chest, quality module, the mix checkbox with its Ratios wizard — the productivity
module and its per-tier counts live inside it (since
2026-08-28) — final machine module, electric pole, pipe, beacon, beacon module,
a beacons-per-tier count, an Ingredient amounts row whose Edit... button opens the third side
panel (since 2026-08-27) and a Columns per tier row whose Edit... opens the fifth (since
2026-08-28 — per-tier column counts with a balanced-columns hint; both rows moved down from
the MAKES block the same day), the circuit-limits checkbox with its per-tier Limits wizard (since
2026-08-26), the buffer-chests checkbox (since 2026-08-26), and the trash-unrequested checkbox.
Everything in that strip but the belt, the pipe and the count carries a quality of its own — and
a picker with only one option is hidden, as is the whole beacon group whatever the count
(until show-all or an actual pick), and the five chests, so a vanilla game
sees five of the fourteen — laid out as **six captioned concept groups** (Transport, Chests,
Modules, Beacons, Power, Circuits), each a row of icon pickers under a small caption; a fully
hidden group takes its caption with it. A **settings panel** opens beside the pickers — a sibling column
inside the planner's own screen element, styled as a window of its own — from a captioned
**Settings** button in the titlebar, holding the two per-player settings: show unresearched
items, and show every picker whatever the count.
What it emits is the belt-ring family — see
`.ai-support/analysis/layout-belt-ring.md` for the geometry and `.ai-support/deferred.md` for
what was deliberately left out (a second fluid network, fluid products, bot transport).

**Tested by a permanent suite since 2026-08-16.** The throwaway scratch harnesses became a
suite under `tests/` (333 tests on both tracks as of 2026-08-28) — planner, layout, poles, circuits, the
quality maths, blueprint,
state, the eject loop, the fluid mechanisms, the beacons and the GUI — run via the repo's `factorio-testing`
skill (headless, graphics, pure host-Lua and static tiers). The old standing question is answered by measurement: a rolled-up ingredient
**wedges** the recycler, and the blacklist relief inserter is what keeps the loop alive
(`.ai-support/analysis/api.md` §9.6). What suite-green still does not prove is endurance in a
long played session, where rolls arrive by probability rather than scripted seeding.

**Published, on two tracks** — Factorio 2.1 from `main`, Factorio 2.0 from `legacy/2.0`,
since the 0.1.0 / 0.1.1 pair of 2026-08-16. Run the `factorio-release` skill's "Published or
open?" check rather than trusting a number written here: `git tag -l 'upcycler-planner_*'` is
what has shipped, and a changelog section still stamped `Date: ????` is what has not. Both
tracks draw from one shared version sequence — `factorio-multiversion` → Version numbering.

## The five technical facts worth not re-deriving

**1. The plan is serialised into a blueprint; the engine builds it.** `scripts/blueprint.lua`
turns the plan into an array of `BlueprintEntity` and Confirm puts it in the player's cursor.
The mod handles **no placement event at all** — obstacles, tree clearing and force-building are
the engine's, reached by the ordinary click / shift-click / ctrl-shift-click every player already
knows.
The simulation-only restriction applies to `LuaSurface.create_entities_from_blueprint_string`
**and to nothing else** — `set_blueprint_entities`, `import_stack`, `build_blueprint` and
`create_blueprint` carry no such note. This fact used to read "never a blueprint string", which
generalised one restriction past its evidence. The thirteen fields a plan needs were read out of
the engine, not the docs: `analysis/api.md` §21.

**2. A blueprint entity's per-prototype fields are NOT in the documented concept.**
`BlueprintEntity` lists ten common fields; `recipe`, `recipe_quality`, `filters`, `use_filters`,
`filter_mode` and `request_filters` live in its 62 `variant_parameter_groups`, keyed by entity
type. Two consequences bite. The recycler is a **`furnace`**, whose group carries
`control_behavior` and nothing else — a recycler can never be given a recipe. And a blueprint's
logistic filter is a **flatter table** than the runtime one: `{index, name, quality, comparator,
count}`, where `LuaLogisticSection.set_slot` takes `{value = {...}, min = count}`. Translating
that wrongly yields an empty section rather than an error. Both in `analysis/api.md` §21.

**3. The recycler ejects like a mining drill.** `vector_to_place_result = {-0.35, -2.3}`
(`data/recycler/data.lua:109`) on a 2x4 furnace: it throws output out of its north face. Stand
it tangent under its machine and recycled ingredients arrive with **zero inserters** — which is
what every reference design does, and the constraint the whole layout hangs off. The vector is
**per-prototype** (Age of Production's salvager throws out its east flank), so
`planner.recycler_orientation()` computes the rotation that lands the throw in the machine
above, and any recycler width fits — the columns widen to it. The paired
machine is pinned to one quality tier and quality matching is *exact*, so a rolled-up
ingredient does not merely jam the eject — measured 2026-08-16, it **wedges the recycler
completely** (the next result cannot merge with the differently-qualitied output stack, so no
craft ever starts). The blacklist inserter beneath the recycler is load-bearing for that
reason, and `tests/loop_spec.lua` fails if it stops working.

**4. A recycling recipe is never evidence an item is buildable.** Researching `recycling`
unlocks every generated `*-recycling` recipe at once — grinding a tier-3 module *produces*
tier-2 modules, and cheat items with no real recipe (Editor Extensions) self-recycle — so
"some enabled recipe produces it" reads unresearched modules and infinity chests as unlocked.
The producer map in `planner.lua` excludes the recycling category and Factoriopedia-hidden
recipes, and the chest picker takes only real `logistic-container`s. Story and evidence:
`.ai-support/journal.md` (2026-08-15, research gating) and `analysis/api.md` §8.

**5. Fluid geometry is direction arithmetic on measured facts.** A pipe connection authored
pointing `dir` points `(dir + rotation) % 16` once the entity rotates, `positions[]` is the
[N,E,S,W] rotation orbit, and the engine merges every input box a recipe needs into ONE live
box that ANY touching pipe feeds — so `planner.machine_fluid_orientation()` only has to land
one input connection facing west, onto the utility column's pipe run. Foundry and cryo plant
author inputs on their SOUTH face (they stand facing east); the EM plant needs no rotation at
all. All measured, all guarded by `tests/fluid_spec.lua`; evidence in
`.ai-support/analysis/api.md` §14.

**`.ai-support/` is this mod's local context — start at its `index.md`.** `decisions.md` holds
what is settled and why, `deferred.md` the parked work, `journal.md` what happened, and
`analysis/` the evidence: decoded blueprints and the scaling law, the chosen belt-ring layout as
a formula, the deferred bot-loop layout, the verified API (including what is *not* verified),
the quality maths, and the reference-mod patterns.

**Neither reference mod is in this workspace**, and both are open source — clone into a scratch
directory if a detail needs re-checking: P.U.M.P. at `github.com/Xcone/factorio_pump` (mod in
`mod/`) and Mining Patch Planner at `github.com/rimbas/mining-patch-planner`. Other authors'
work: reference only, never edited, never redistributed.

## Dependencies

`["base >= 2.1.0", "quality >= 2.1.0"]` on `main`; the `legacy/2.0` build floors both at
`2.0.0`.

The hard dependency on `quality` is deliberate and does double duty: the mod is meaningless
without quality tiers, and it delivers the recycler on both tracks — in 2.1 `quality` itself
declares `"recycler >= 2.1.0"`, and in 2.0 the recycler entity ships inside `quality`. The
dependency is also the only half of this that fixes load order; the flags below do not.

**Space Age feature flags are declared, and the set forks by game version** — `quality_required`
on both tracks, `expansion_required` on `main` **only**. Do not add `expansion_required` to
`legacy/2.0`: the flag does not exist in Factorio 2.0, so it is silently ignored there and gates
nothing. Do not add `space_travel_required` to either. Reasons in `.ai-support/decisions.md`; the
measurements, including the flag set each version actually enumerates, in `analysis/api.md` §13.

## The 2.0 build

**`main` carries no 2.0 code — never version-gate 2.0 compatibility into it.** The repo
owner's explicit call; the reason is in `.ai-support/decisions.md`. The port lives entirely on
`legacy/2.0` as forked copies of the divergent files declared in the repo `CLAUDE.md` → *Git*,
plus `data-final-fixes.lua`, which exists only on that branch. A cherry-pick from `main` that
touches a forked file is rewritten by hand, never merged blind. When working on the legacy
branch, keep `.ai-support/analysis/factorio-2.0.md` open — it is the verified 2.0 API surface,
including the reads that are hard errors on the wrong version.

## Layout

The shape follows the community convention in the `factorio-mod-setup` skill: grouped by
**content**, not by prototype kind.

```
data.lua                            entry point; requires the prototype files
data-final-fixes.lua                legacy/2.0 branch ONLY: records allow_quality into mod-data
control.lua                         lifecycle and event wiring only — the work lives in scripts/
settings.lua                        the two per-player settings the modal's window edits
prototypes/planner/                 the shortcut, the icon layers it is built from, and the two
                                    custom-inputs: the CTRL+U toggle and the linked one
                                    that points the Confirm key at Place
scripts/                            one file per runtime concern, required by control.lua
  gui.lua      the modal            planner.lua   derivations and validation
  layout.lua   pure geometry        blueprint.lua plan -> BlueprintEntity, and the cursor
  poles.lua    pole coverage and connectivity, utility columns first -- pure like layout.lua
  circuits.lua the opt-in circuit-limit conditions and green wires, decorating a finished
               plan -- pure like layout.lua, and strictly after the pole pass
  quality_math.lua the per-tier quality/productivity mix and the loop's expected yield --
               pure like layout.lua, the engine's roll chances injected by planner.lua
  state.lua    persistent choices   dispatch.lua  tag-based GUI handler registry
tests/                              the permanent suite (factorio-test); registered in
                                    control.lua behind the active_mods guard, excluded from
                                    the zip by package.ignore. Run via `factorio-testing`.
  *_spec.lua                        in-game specs: planner, plan, blueprint, beacon, state,
                                    loop, fluid, gui
  pure/                             layout + poles + circuits geometry and the quality maths,
                                    runs on host Lua too
  support/research.lua              the five research states as helpers
  support/stamp.lua                 stamps a plan and reports the plan-to-world offset
  support/layout_params.lua         the canonical vanilla layout fixture the pure specs share
  support/deep_equal.lua            structural equality for the determinism specs
locale/en/upcycler-planner.cfg    every player-visible string
migrations/                         still none: the 2026-08-16 `ua-` -> `upl-` rename needed no
                                    migration, because neither prototype persists into a save
images/                             portal page material, never shipped: gallery shots numbered
                                    in upload order, and description/ for the readme's demo gifs
.ai-support/index.md                the map — read it first
.ai-support/decisions.md            what is settled, and why
.ai-support/deferred.md             parked work, each entry with enough context to pick up cold
.ai-support/journal.md              dated sessions, newest first — what was built and what broke
.ai-support/analysis/               the evidence: decoded blueprints, verified API, layout specs
```

No `graphics/` yet — the shortcut uses layered vanilla icons until real art lands
(`.ai-support/deferred.md`).

**`require` paths use dots, mod-wide** — a readability convention, not a correctness one.
Factorio caches by resolved file, so dots and slashes are equivalent (verified on 2.1.14); one
spelling just makes a shared module grep-able.

## Naming

**Every prototype this mod defines is prefixed `upl-`.** Three of them: the shortcut `upl-open`,
the keybound `upl-open` custom-input (deliberately the same name — the Krastorio 2 pairing shape,
see `decisions.md`) and the `upl-confirm` custom-input; anything new follows them. Prototype
names are one flat global
namespace shared with every other
mod, so the prefix is what stops a collision — and a collision here is silent, which is the
whole reason for the rule.

This mirrors the house style in `pure-modules-realk`, which names prototypes with a short tag
(`pure-speed-module`, `pure-beacon`) rather than the full mod name. Two things follow it and one
does not:

- **Prototypes** use the short tag: `upl-`.
- **GUI element names and tag keys** use it too, so a stray element is traceable to this mod.
- **Settings and locale mod-level keys** use the **full** `upcycler-planner` — that is how
  `pure-modules-realk` does it (`pure-modules-realk-beacon-allow-quality`), and mod settings are
  listed to players next to other mods' settings where a three-letter tag would be meaningless.

**The tag is settled**, because renaming a prototype costs a migration file and a major version
bump from the first release onward. Which tags were rejected and why is in
`.ai-support/decisions.md`; the `ua-` → `upl-` rename is in `.ai-support/journal.md`
(2026-08-16).

## Working here

- Commit scope is `upcycler-planner`. Repo-wide changes use `repo`.
- **Never commit, push or publish unprompted** — repo `CLAUDE.md`, and approval is per request.
- **`README.md` is the portal description** and **`faq.md` the portal FAQ tab**, uploaded
  verbatim by `fmtk details --readme` / `--faq`; `images/` is the gallery in filename order.
  All are player-facing and settled; what each image is, and where the readme's demo gifs are
  hosted, is in `.ai-support/decisions.md` → *Portal presentation*. Gathering them is not a release — publishing still needs the owner's
  approval for that specific upload.
- `LICENSE` at the mod root is the repo root's GPLv3 text, copied verbatim. Keep the two in
  sync if the root copy is ever refreshed.
- **Design decisions go in `.ai-support/decisions.md` as they are made, with the reason, and the
  session that produced them in `.ai-support/journal.md`.** Both, not either — the repo
  `CLAUDE.md` → *AI support folders* has the rules. Anything that generalises beyond this mod
  belongs in a skill under `.claude/` instead.
- **Run the headless suite at checkpoints, not after every edit** — before wrapping up a
  session that changed `scripts/` or `control.lua`, and before asking for a commit (~15 s via
  the `factorio-testing` skill); the graphics pass belongs to releases. Testing is a gate,
  never the development loop's tax. New behaviour still gets its spec in the same session,
  the way `changelog.txt` is handled — the suite exists because the alternative was
  re-deriving a scratch harness every session.
- **Always pass `--check-unused-prototype-data` when validating.** It is the only thing that
  catches a misspelled prototype property, which the loader ignores rather than rejecting, and
  the exit code stays 0 either way — so the log has to be read. See the `factorio-validate`
  skill.
- A GUI mod carries desync risk that a data-only mod does not. Read the `factorio-mod-development`
  skill on `storage` and save/load before the first line of `control.lua`, and note that
  `flib`'s save/load-safe GUI handler registry (`exemples/flib_0.17.2/gui.lua`) is the
  reference pattern — read it for prior art before hand-rolling one.

## Decided

The rules, in short. **Every reason lives once, in `.ai-support/decisions.md`** — read it before
re-opening any of these, and don't restate a reason here.

- Name `upcycler-planner`; prototype prefix `upl-`; settings and locale keys use the full name.
- Both tracks: Factorio 2.1 from `main`, 2.0 from `legacy/2.0`. No 2.0 code on `main` — the
  port is forked files on the legacy branch, declared in the repo `CLAUDE.md` → *Git*. Version
  starts at `0.1.0`.
- Hard `quality >= 2.1.0` dependency. Space Age flags declared, forking by version:
  `quality_required` both tracks, `expansion_required` on `main` only. No flib dependency.
- **The plan becomes a blueprint; the engine builds it.** See fact 1 above.
- Shortcut → modal → Confirm → a blueprint in the cursor, gated on the `recycling` technology.
  A rebindable hotkey (CTRL+U default) toggles the modal too, honouring the same gate
  through `is_shortcut_available` — pairing shape and reasons in `decisions.md`.
  The mod handles no placement event: a normal click refuses over obstacles, shift-click builds
  through them and clears trees, ctrl-shift-click clears buildings. Rotation, flipping, snapping
  and undo come with the blueprint, and flipping is measured safe for the recycler eject.
- **Confirm is reachable by the game's own "Confirm window" key** (E by default) as well as the
  button, through a `custom-input` linked to `confirm-gui`. `consuming` must stay `"none"`, so
  the engine's close runs after the handler — which is why a refused hand-over closes the modal
  on the key where the button keeps it open. The key swallows one press while an element
  picker's chooser is presumed open, so E selects in the chooser instead of placing — the
  presumption, its staleness and the accepted cost are in `decisions.md`.
- The stack is a plain vanilla `blueprint` with `cursor_stack_temporary` set, wearing the product
  at the target quality as its `preview_icons` — so Q discards it like the old tool, and dragging
  it into the inventory keeps the design. It is **not** one-shot the way the tool was: it stays in
  hand, so the same loop can be stamped repeatedly.
- The modal is two blocks: what the loop **makes** (item, target quality, machine, recycler),
  then a **Build options** block for what it is built **out of**, sorted into six captioned
  concept groups — Transport (belt, inserter, pipe), Chests (the five roles), Modules (quality
  and final machine), Beacons (beacon, its module, the per-tier count), Power (pole), Circuits
  (the circuit-limits checkbox and its Limits wizard button) — with the buffer-chests and
  trash-unrequested checkboxes below them. A fully hidden group hides its caption with it. Every picker carries its
  own quality except the belt and the pipe, which the engine gives no quality bonus.
- Ingredient request amounts are editable in a side panel — an *Edit...* button beside the item
  picker, dead until an item is picked. Only edits are stored (`request_<item>` flat numbers);
  they reset on an item change, and the floor is one. Reasons in `decisions.md`.
- A build material with a quality travels as a `{ name, quality }` pair from `resources()`
  through the layout params to the ghost; a bare string means it has no quality dimension at
  all. That is the *plan* pipeline — `storage` still holds the two halves as flat strings, per
  the rule below.
- Pickers offer only what is researched, unless the per-player `upcycler-planner-show-all` is on.
- **The two settings are edited in a panel beside the pickers** — a sibling column inside the
  planner's own screen element (an invisible container frame), never a second window, so the
  pair cannot separate however the planner is moved. They are mod *settings* rather than a
  private copy in `storage`; a change from the panel or the game's settings menu rebuilds the
  modal, panel included, through one `on_runtime_mod_setting_changed` handler. The container
  keeps `player.opened` throughout; `control.lua` turns a close request into "panel first".
  Reasons: `decisions.md`; measurements: `analysis/api.md` §17 and §19.
- **A picker with fewer than two options is hidden** — the recycler and the pipe in a vanilla
  game — and the pipe is also hidden until the recipe takes a fluid. Exempt: item, target,
  machine, belt, quality module, and the two whose *clear* is the second option (pole, final machine
  module). **The five chests go the other way and are hidden whatever their count.** A hidden
  picker still holds its default, and hides its row label with it. What that costs — a hidden
  picker takes its quality box with it — is what *Show all build options* exists to undo, the
  chests and the pipe's fluid condition included.
- Shortcut button style `green`. Icon layer `scale`/`shift` are written in item space and
  rescaled per prototype — they scale against the prototype's expected icon size, not the
  file's (`analysis/api.md` §11).
- **`storage` holds flat strings only** — never a `{name, quality}` table.
- Belt ring is the layout (`.ai-support/analysis/layout-belt-ring.md`); the bot loop is a
  deferred toggle, not a dead idea (`analysis/layout-bot-loop.md`).
- Modules are planned rather than requested. The final machine's module is its own picker,
  defaulting to the best researched **productivity** module and to **nothing** when the recipe or
  the machine refuses productivity — never to a quality module. Clearing it means "leave that
  machine empty".
- **Each lower tier's machine carries the computed best quality/productivity mix by default**
  (both tracks: 2.1 through the engine's `get_roll_chances`, 2.0 through the legacy roll
  shim — `analysis/factorio-2.0.md`). A *Mix productivity modules*
  checkbox, ticked by default, is the opt-out; unticking forces quality-only and parks the
  per-tier overrides; the whole line shows only when some productivity module fits the
  machine-and-recipe pair (show-all overrides, the pipe's rule). Solved per tier from engine data
  in `scripts/quality_math.lua`; the *Ratios...* wizard (fourth side panel, only-on-edit
  `split_prod_<quality>` keys) holds the productivity picker and the per-tier counts; the
  picker is belt-shaped
  with no clear-flag, and a productivity-refusing recipe forces all-quality with no refusal.
  The status line shows the loop's expected items-in per item-out from the same solve, and
  its pace — steady-state seconds per item, gated by the slowest station, from the solve's
  flow pass plus real rates (build quality, module speed penalties, beacons; api.md §31).
  Recyclers never split. Reasons and mechanics: `.ai-support/decisions.md`, engine facts
  `analysis/api.md` §30.
- **Each lower tier can repeat its whole column** (2026-08-28): a *Columns per tier* row in
  Build options opens the fifth side panel — per-tier counts under only-on-edit
  `column_count_<quality>` keys, floor one, cap `planner.MAX_COLUMNS_PER_TIER` (32, a
  performance ceiling named in the field tooltip; it opened at 250 and came down the same
  day after big-layout crashes), the
  target pinned at one column. The expansion lives in `planner.plan` alone (`tier_columns` /
  `expand_columns`); layout, circuits, poles, blueprint and quality_math are untouched, and the
  solve keeps the distinct chain. The wizard shows the balanced column counts from
  `station_times` — the pace formula's single owner — as a hint to type in; its one-click
  Apply button was removed the day it landed, for the same crashes ("balanced columns" in
  every player string; "ratio" stays the module mix's word).
  The counts and pace follow every keystroke; the yield line never moves with
  columns. Reasons: `.ai-support/decisions.md`.
- **The status area is one label per line** (2026-08-28): stats always plain white
  (the machine/recycler counts — the footprint in their tooltip since the owner's same-day
  call — then yield), a separator, then one line per message — orange with a
  warning icon, red with an error icon on refusals — and a grey hint before an item is
  picked; the wizards' placeholder sentences wear the same grey. Shape and reasons:
  `.ai-support/decisions.md`.
- A picker offers only modules the machine **and** the recipe accept, by the measured rule that
  only a module's *positive* effects must be allowed (`analysis/api.md` §16); both are
  re-resolved when either half of the pair changes.
- Modded recyclers work by rotation, not convention — see fact 3.
- **Everything the loop rolls above the target leaves through one tap** — an inserter and an
  active-provider chest in the terminal column's two spare tiles, whitelisting `{target, ">"}`
  with **no item name**, so one slot covers any recipe. Footprint unchanged; it costs one extra
  pole. The terminal catcher is a single `">="` for the same reason. Why each part is as it is:
  `decisions.md`; the measurements: `analysis/api.md` §24.
- **Circuit limits are opt-in and combinator-free: reserve and cap** (2026-08-26). Every
  machine and recycler stops at one shared cap — the output chest's count of the product at
  the target quality — and each lower tier's buffer-to-recycler inserter holds that tier's
  floor, never drawing the chest below the player's minimum (0 by default, meaning no
  reserve and no wire for that tier). Plain enable conditions on existing entities, one
  green network, no new entities, no footprint change. `scripts/circuits.lua` decorates the
  finished plan (pure, strictly after the pole pass); the numbers live in `storage` as flat
  `circuit_min_<quality>` / `circuit_max_<quality>` values, edited in a wizard panel whose
  rows are labelled Min/Max, following the settings panel's sibling-column mechanics.
  Out-of-reach wires warn (`circuit_unlinked`), never refuse — an unwired condition gates
  nothing, measured. Reasons and the rejected shapes (the first-built demand cascade
  included): `decisions.md`; the verified engine surface: `analysis/api.md` §26.
- Chests are 1x1, and each of the five roles offers only its own kind — the role is fixed, the
  chest is the player's. Only the overflow chest's role is forced to a specific logistic mode
  (active provider): it is the loop's one sink that empties itself.
- **The stock chests are buffer chests by default** (2026-08-26): the stock role's kind follows
  the "Use buffer chests" checkbox — buffer chests share each tier's items with personal
  logistics and construction bots, requester chests keep them in the loop. Toggling refills the
  stock picker with the new kind's best and keeps its quality; the ingredient, output and
  overflow chests never change kind. Trade-offs and the rejected always/never shapes:
  `decisions.md`. Inserters reach one tile, are never fuelled and never belt-stacking, and
  a chosen one that is short of filter slots is named in the refusal **only when a better one
  exists** — otherwise the recipe is blamed, which is every vanilla case. Both
  picker lists also gate on `items_to_place_this`, or show-all offers base's unplaceable 1x1
  scenery chests.
- **Beacons are opt-in: off by default, a vertical stack per tier in the utility column when
  picked**, the machine-only terminal tier included. The player chooses the count from a
  drop-down offering exactly 1..`layout.max_beacon_count` (vanilla: 4); stacking costs rows,
  never width, and an outgrown count clamps, never refuses. **The whole beacon group is hidden
  by default, researched or not** — *Show all build options* reveals it, and a chosen beacon
  keeps it visible. The beacon-module picker defaults to the best researched **efficiency**
  module, never speed (why: `decisions.md`). Its clear means "place the beacon empty"
  (`no_beacon_module`); the beacon itself needs no clear-flag, since nil already means off.
  Short reach warns per receiver (some beacon reaches the machine, some the recycler); a
  beacon taller than the interior refuses. Measured facts: `analysis/api.md` §25; geometry:
  `analysis/layout-belt-ring.md` §Beacons.
- Poles default to the best researched 1x1 and are clearable to none. **A plan is as narrow as
  full coverage allows**: the planner solves for its utility columns rather than opening one at
  every machine, keeping only a column a pole turned out to need — so most plans open none and
  the poles stand in the ring's own free ground. Where a column does open it is sized to the
  pole and shared with the pipe run; a fluid recipe holds every column at 1 whatever the poles
  do (`analysis/poles.md` §"Choosing the columns", `analysis/api.md` §10).
- Fluid recipes are planned as per-column pipe runs ending in underground stubs beneath the
  ring belts; machines rotate per prototype to meet the run (fact 5 above). **Nothing is ever
  built outside the ring** — the player taps the stubs from outside and wires the columns as
  they like.
- Refused, each with a message: recipes with two or more fluids, machines no rotation can
  pipe, self-recycling items, and recipes that refuse quality modules.
- **Spoiling items warn, never refuse** (`item-spoils`), and the warning is placed first among
  the warnings. Ten of the 210 upcyclable items are affected. The runtime read is
  `LuaItemPrototype.get_spoil_ticks(quality)` — a **method**; there is no `spoil_ticks`
  attribute, and the wrong spelling reads nil, so every item looks safe. Reasons in
  `decisions.md`; the table and the measurement in `analysis/api.md` §29.

## Open questions

**`.ai-support/deferred.md` is the single owner** of parked and open work, so the two lists
cannot drift apart. The two questions that used to gate everything are both answered above —
*what does the player actually select* (nothing: they hold a blueprint) and *can a runtime-written
blueprint carry the loop faithfully* (yes, measured). **Modded quality tiers are no longer one
of them either** — the chain walk carries no ceiling and the pole solve was rebuilt for long
chains on 2026-08-20; what is left there is solve *cost* at the extreme, which `deferred.md`
owns. So the rest is mostly scope: whether the GUI should show expected output, and
`thumbnail.png`.
