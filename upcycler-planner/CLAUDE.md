# CLAUDE.md — Upcycler Planner

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

A planner in the tradition of Mining Patch Planner and P.U.M.P.: the player picks an item and a
target quality, and the mod designs a complete upcycling loop and hands it over as a blueprint.

**It has worked end to end since 2026-08-15**, when a shortcut opened a modal whose Confirm
handed over a one-shot selection tool and the mod placed the ghosts itself. **Since 2026-08-18
Confirm hands over an ordinary blueprint instead**, so preview, rotation, flipping, snapping,
undo and every build mode are the engine's own and the mod handles no placement event at all.
The modal is in two blocks — what the loop MAKES (item, target quality, crafting machine and
recycler, the last two with a quality of their own, and since 2026-11-27 the **Layout** row:
Belts or Bots) above what it is built OUT OF in **four tabs of labelled rows** since 2026-11-27,
only the selected tab filled: **Buildings** (belt, inserter, pipe, electric pole, then the
column count per lower tier), **Modules** (quality module, final machine module, beacon with its
module and beacons-per-tier count, then the *Mix productivity modules* checkbox with the
productivity module and the per-tier slot counts under it), **Chests** (the five chest pickers;
the buffer-chests, the two request and the trash-unrequested checkboxes; the ingredient amounts
— Minutes, then a field per ingredient) and **Circuits** (the circuit-limits checkbox and the
limits — Min/Max per tier, Hand size, Count the whole logistic network, Start paused).
Everything but the belt, the pipe and the count carries a quality of its own. Every row is a
label beside its control, and everything the plan builds has its row: a row hides only while the
loop as chosen does not build it — the belt, the relay chest and the two request boxes with
bots, the overflow chest on a belt ring to the highest quality, the pipe without a fluid, the
beacon's module and count without a beacon, the mix where no productivity module fits. A tab
taller than the screen allows scrolls. A **settings panel** opens beside the window — a
sibling column inside the planner's own screen element, styled as a window of its own — from a
captioned **Settings** button in the titlebar, holding the one per-player setting: show
unresearched items. What it
emits is one of **two layout families**: the belt ring by default
(`.ai-support/analysis/layout-belt-ring.md`) or the bot loop
(`.ai-support/analysis/layout-bot-loop.md`, built 2026-11-27), where robots carry everything
between tiers; `.ai-support/deferred.md` keeps what was deliberately left out (a second fluid
network, fluid products, a roboport).

**Tested by a permanent suite since 2026-08-16.** The throwaway scratch harnesses became a
suite under `tests/` (515 tests as of 2026-11-27, 187 of them pure) — planner, layout, poles,
circuits, the quality maths, the shortcut gate, blueprint, state, the eject loop, the fluid
mechanisms, the combinator retune, the chests' circuit stop, the beacons, the bot loop live
and on paper, the belt goldens and the GUI — run via the repo's `factorio-testing` skill (headless, graphics, pure
host-Lua and static tiers). The old standing question is answered by measurement: a rolled-up ingredient
**wedges** the recycler, and the relief inserter under it — one nameless *above this tier*
filter since 2026-09-09 — is what keeps the loop alive
(`.ai-support/analysis/api.md` §9.6). What suite-green still does not prove is endurance in a
long played session, where rolls arrive by probability rather than scripted seeding.

**Published** since the 0.1.0 / 0.1.1 pair of 2026-08-16, for Factorio 2.1 from `main`. The
Factorio 2.0 builds, last 1.2.5, came from `legacy/2.0`, now a frozen backup. Run the
`factorio-release` skill's "Published or open?" check rather than trusting a number written
here: `git tag -l 'upcycler-planner_*'` is what has shipped, and a changelog section still
stamped `Date: ????` is what has not. The 2.0 tags count too: 1.2.6 (2026-10-24) went above
the last of them, 1.2.5, so a new release still goes above the highest tag on either branch
(`factorio-release` → Versioning).

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
craft ever starts). The relief inserter beneath the recycler is load-bearing for that
reason — one nameless `{quality > tier}` whitelist, the overflow tap's shape, since
2026-09-09 — and `tests/loop_spec.lua` fails if it stops working.

**4. A recycling recipe is never evidence an item is buildable.** Researching `recycling`
unlocks every generated `*-recycling` recipe at once — grinding a tier-3 module *produces*
tier-2 modules, and cheat items with no real recipe (Editor Extensions) self-recycle — so
"some enabled recipe produces it" reads unresearched modules and infinity chests as unlocked.
The producer map in `planner.lua` excludes the recycling category and Factoriopedia-hidden
recipes, and the chest picker takes only real `logistic-container`s. Story and evidence:
`.ai-support/journal-archive/2026.md` (2026-08-15, research gating) and `analysis/api.md` §8.

**5. Fluid geometry is direction arithmetic on measured facts.** A pipe connection authored
pointing `dir` points `(dir + rotation) % 16` once the entity rotates, `positions[]` is the
[N,E,S,W] rotation orbit, and the engine merges every input box a recipe needs into ONE live
box that ANY touching pipe in a shared connection category feeds — so
`planner.machine_fluid_orientation()` only has to land one input connection the run's pipe
can join facing west, onto the utility column's pipe run. A port in another category is no
fluid face, however it is authored (Muluna's data port). Foundry and cryo plant author inputs
on their SOUTH face (they stand facing east); the EM plant needs no rotation at all. All
measured, all guarded by `tests/fluid_spec.lua`; evidence in `.ai-support/analysis/api.md`
§14.

**`.ai-support/` is this mod's local context — start at its `index.md`.** `decisions.md` holds
what is settled and why, `deferred.md` the parked work, `journal.md` what happened, and
`analysis/` the evidence: decoded blueprints and the scaling law, the chosen belt-ring layout as
a formula, the bot-loop layout as built, the verified API (including what is *not* verified),
the quality maths, and the reference-mod patterns.

**Neither reference mod is in this workspace**, and both are open source — clone into a scratch
directory if a detail needs re-checking: P.U.M.P. at `github.com/Xcone/factorio_pump` (mod in
`mod/`) and Mining Patch Planner at `github.com/rimbas/mining-patch-planner`. Other authors'
work: reference only, never edited, never redistributed.

## Dependencies

`["base >= 2.1.0", "quality >= 2.1.0"]`.

The hard dependency on `quality` is deliberate and does double duty: the mod is meaningless
without quality tiers, and it delivers the recycler — `quality` itself declares
`"recycler >= 2.1.0"`. The dependency is also the only half of this that fixes load order; the
flags below do not.

**Space Age feature flags are declared** — `quality_required` and `expansion_required`. Do not
add `space_travel_required`. Reasons in `.ai-support/decisions.md`; the measurements, including
the flag set the game actually enumerates, in `analysis/api.md` §13.

## Layout

The shape follows the community convention in the `factorio-mod-setup` skill: grouped by
**content**, not by prototype kind.

```
data.lua                            entry point; requires the prototype files
data-final-fixes.lua                moves the shortcut's gate to the technology gate.lua names
control.lua                         lifecycle and event wiring only — the work lives in scripts/
settings.lua                        the one per-player setting the settings panel edits
prototypes/planner/                 the shortcut, the icon layers it is built from, the two
                                    custom-inputs (the CTRL+U toggle and the linked one that
                                    points the Confirm key at Place), and gate.lua: which
                                    technology delivers a recycler first -- pure over data.raw
scripts/                            one file per runtime concern, required by control.lua
  gui.lua      the modal            planner.lua   derivations and validation
  layout.lua   pure geometry: the belt ring, and the parts both builders share
  layout_bot.lua the bot loop's builder, layout.build's contract -- pure like layout.lua
  blueprint.lua plan -> BlueprintEntity, and the cursor
  poles.lua    pole coverage and connectivity, utility columns first -- pure like layout.lua
  circuits.lua the opt-in circuit-limit conditions, the limits combinator's rows, the status
               lamps and panel, and the green wires, decorating a finished plan -- pure like
               layout.lua, and strictly after the pole pass (layout.lua stands the entities)
  quality_math.lua the per-tier quality/productivity mix and the loop's expected yield --
               pure like layout.lua, the engine's roll chances injected by planner.lua
  retune.lua   network mode's max kept editable: an edited C on a stamped loop's combinator
               copied onto every logistic-gated entity in its green network
  state.lua    persistent choices   dispatch.lua  tag-based GUI handler registry
tests/                              the permanent suite (factorio-test); registered in
                                    control.lua behind the active_mods guard, excluded from
                                    the zip by package.ignore. Run via `factorio-testing`.
  *_spec.lua                        in-game specs: planner, plan, plan_golden, bot_plan,
                                    blueprint, beacon, state, loop, bot_loop, fluid, gui
  pure/                             layout + layout_bot + poles + circuits geometry, the belt
                                    goldens, the quality maths and the shortcut gate's data
                                    scan, runs on host Lua too
  support/fingerprint.lua           the interpreter-neutral digest the goldens pin
  support/footprint.lua             the no-overlap and in-bounds checks both layout specs run
  support/research.lua              the five research states as helpers
  support/stamp.lua                 stamps a plan and reports the plan-to-world offset
  support/layout_params.lua         the canonical vanilla layout fixture the pure specs share,
                                    and the two-stack big-recipe one beside it
  support/circuit_stack.lua         the circuit stack's names, roles and lookup, shared by
                                    the pure and in-game circuit specs
  support/component.lua             the undirected wire walk the pole and circuit specs share
  support/deep_equal.lua            structural equality for the determinism specs
locale/en/upcycler-planner.cfg    every player-visible string
migrations/                         still none: the 2026-08-16 `ua-` -> `upl-` rename needed no
                                    migration, because neither prototype persists into a save
images/                             portal page material, never shipped: gallery shots numbered
                                    in upload order, and description/ for the readme's videos and stills
.ai-support/index.md                the map — read it first
.ai-support/decisions.md            what is settled, and why
.ai-support/deferred.md             parked work, each entry with enough context to pick up cold
.ai-support/journal.md              dated sessions, newest first — what was built and what broke
.ai-support/journal-archive/        the older sessions, one file per year, moved out unedited
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
`.ai-support/decisions.md`; the `ua-` → `upl-` rename is in `.ai-support/journal-archive/2026.md`
(2026-08-16).

## Working here

- Commit scope is `upcycler-planner`. Repo-wide changes use `repo`.
- **Never commit, push or publish unprompted** — repo `CLAUDE.md`, and approval is per request.
- **`README.md` is the portal description** and **`faq.md` the portal FAQ tab**, uploaded
  verbatim by `fmtk details --readme` / `--faq`; `images/` is the gallery in filename order.
  All are player-facing and settled; what each image is, and where the readme's videos and stills are
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
- Factorio 2.1 only. The 2.0 builds stay on the portal, unmaintained; `legacy/2.0` is a frozen
  backup, never worked on. Version starts at `0.1.0`.
- Hard `quality >= 2.1.0` dependency. Space Age flags declared: `quality_required` and
  `expansion_required`. No flib dependency.
- **The plan becomes a blueprint; the engine builds it.** See fact 1 above.
- Shortcut → modal → Confirm → a blueprint in the cursor, gated on the first technology that
  delivers a recycler — `recycling` in vanilla, read off the finished data by
  `data-final-fixes.lua` so a mod that unlocks a recycler sooner moves the gate with it, and
  re-granted by `gui.unlock_shortcut` on every configuration change.
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
- The modal is two blocks: what the loop **makes** (item, target quality, machine, recycler,
  Layout), then the build options in **four tabs of labelled rows** — Buildings (belt, inserter,
  pipe, pole, then Columns per tier), Modules (quality, final machine, beacon with its module
  and count, then the mix and its per-tier counts), Chests (the five pickers; the buffer,
  request and trash checkboxes; the ingredient amounts) and Circuits (the checkbox, then the
  limits). **Only the selected tab is filled** (`fill_tab`, refilled in place on a switch and on
  the `TAB_BUILDERS` entry's `refill_on` reasons) — never build a tab by hand. A tab switch
  plans nothing; it repaints only the Circuits fields. A centred window is re-centred after
  every change of size (`recentre`: each fill, the settings panel opening or closing); a moved
  one keeps its place, rebuilds included. **Moved is tracked, never read off `auto_center`**,
  which a drag leaves on: the window is never left auto-centring, `recentre` jumps it to 0,0
  so each centring lands as an event, `gui.on_location_changed` pins it there, and an event
  that finds the flag off is a drag, kept as `window_moved` until the window closes. A new
  resolution or UI scale re-centres it. Each tab is a scroll-pane capped by `tab_max_height`, so the window fits
  a small screen. The selected tab is `entry.tab` in storage, a name, restored on every
  rebuild. Every row of a tab's table goes through `add_row` and hides through `show_row`,
  label and control together; every count row — per tier, per ingredient, Minutes, Hand size —
  through `count_row` and `count_field`. Every picker carries its own quality except the belt
  and the pipe, which the engine gives no quality bonus. **Every row label shares the
  file-level `LABEL_WIDTH`** — a new row uses the same constant, or its control leaves the
  column.
- **What the chosen layout does not build is hidden** — the belt, the relay chest and the two
  request boxes with bots, the overflow chest on a belt ring to the highest quality — through
  `layout_rules`, the one place those decisions live; never written into choices, so a switch
  back gets the player's own picks and ticks back.
- Ingredient request amounts are editable inline in the Chests tab, the grey pick-an-item
  hint until an item is picked. A **Minutes** field at its top sizes every amount
  (two minutes of crafting by default, 1–100, stored only on edit as the flat `feed_minutes`,
  never a `request_` key; a change replaces every per-ingredient override and survives an
  item change). Per-ingredient edits are stored as `request_<item>` flat numbers; they reset
  on an item change, and the floor is one. No stack cap: a plan whose amounts outgrow the feed
  chest carries `request_overflow`, a status-line warning. Reasons in `decisions.md`.
- A build material with a quality travels as a `{ name, quality }` pair from `resources()`
  through the layout params to the ghost; a bare string means it has no quality dimension at
  all. That is the *plan* pipeline — `storage` still holds the two halves as flat strings, per
  the rule below.
- Pickers offer only what is researched, unless the per-player `upcycler-planner-show-all` is on.
- **The setting is edited in a panel beside the window** — a sibling column inside the planner's
  own screen element (an invisible container frame), never a second window, so the pair cannot
  separate however the planner is moved. It is a mod *setting* rather than a private copy in
  `storage`; a change from the panel or the game's settings menu rebuilds the modal, panel
  included, through one `on_runtime_mod_setting_changed` handler. The container keeps
  `player.opened` throughout; `control.lua` turns a close request into "panel first". Reasons:
  `decisions.md`; measurements: `analysis/api.md` §17 and §19.
- **Everything the plan builds has its row; a row hides only while the loop as chosen does not
  build it** — the layout's rows above, the pipe until the recipe takes a fluid, the beacon
  module and count until a beacon is picked (the count also until a second one fits), the mix
  where no productivity module fits. The recycler, the inserter, the beacon and every chest the
  loop builds always show, so every quality is one click away. No setting reveals anything:
  *Show all build options* went with the hide-by-count rule it undid (2026-11-27). A hidden row
  still holds the default the plan uses.
- Shortcut button style `green`. Icon layer `scale`/`shift` are written in item space and
  rescaled per prototype — they scale against the prototype's expected icon size, not the
  file's (`analysis/api.md` §11).
- **`storage` holds flat strings only** — never a `{name, quality}` table.
- **Two layout families**: the belt ring by default (`analysis/layout-belt-ring.md`), the bot
  loop on `choices.layout = "bot"` (`analysis/layout-bot-loop.md`, `scripts/layout_bot.lua`).
  `planner.layout_kind` is the one reader and `GEOMETRY` the one dispatch to a builder; what
  differs is owned by `planner.uses_chest`, `requests_forced`, `circuit_network` and
  `filters_needed(recipe, choices)`, read by plan and validate alike. A rule both builders
  share lives once, exported from `layout.lua`. **Belt plans are frozen**:
  `tests/pure/belt_golden_spec.lua` and `tests/plan_golden_spec.lua` pin digests from before
  the bot loop existed, so a change that moves one is re-captured on purpose, never quietly.
  With bots: lower output and extract chests are the overflow pick (active providers, never a
  circuit census), the two requests are forced on, the maximum always counts the network, and
  the spine relays through the top-row inserters (`relay_out` / `relay_in`).
- Modules are planned rather than requested. The final machine's module is its own picker,
  defaulting to the best researched **productivity** module and to **nothing** when the recipe or
  the machine refuses productivity — never to a quality module. Clearing it means "leave that
  machine empty".
- **Each lower tier's machine carries the computed best quality/productivity mix by default**
  (through the engine's `get_roll_chances`). A *Mix productivity modules* checkbox, ticked by
  default, is the opt-out; unticking forces quality-only and parks the per-tier overrides; the
  mix shows only when some productivity module fits the machine-and-recipe pair. Solved per tier
  from engine data in `scripts/quality_math.lua`; the productivity picker and the per-tier
  counts (only-on-edit `split_prod_<quality>` keys) stand under the checkbox in the Modules tab
  while it is ticked; the picker is belt-shaped with no clear-flag, and a productivity-refusing
  recipe forces all-quality with no refusal. The status line shows the loop's expected items-in
  per item-out from the same solve, and its pace — steady-state seconds per item, gated by the
  slowest station, from the solve's flow pass plus real rates (build quality, module speed
  penalties, beacons; api.md §31). Recyclers never split. Reasons and mechanics:
  `.ai-support/decisions.md`, engine facts `analysis/api.md` §30.
- **Each lower tier can repeat its whole column** (2026-08-28): the per-tier counts stand at the
  foot of the Buildings tab under *Columns per tier* — only-on-edit `column_count_<quality>`
  keys, floor one, cap `planner.MAX_COLUMNS_PER_TIER` (64, a performance ceiling named in the
  field tooltip; it opened at 250, came down to 32 the same day after big-layout crashes, and
  doubled to 64 on 2026-08-29 once the pole solve went near-linear), the target pinned at one
  column. The expansion lives in `planner.plan` alone (`tier_columns` / `expand_columns`);
  layout, circuits, poles, blueprint and quality_math are untouched, and the solve keeps the
  distinct chain. The counts are rows and nothing else: the balanced-counts hint was removed at
  the owner's ask on 2026-08-29, its one-click Apply having already gone the day the feature
  landed, for the crashes above. The counts and pace follow every keystroke; the yield line
  never moves with columns. Reasons: `.ai-support/decisions.md`.
- **The status area is one label per line** (2026-08-28): stats always plain white (the
  machine/recycler counts — the footprint in their tooltip since the owner's same-day call —
  then yield), a separator, then one line per message — orange with a warning icon, red with an
  error icon on refusals — and a grey hint before an item is picked; the per-tier lists'
  placeholder sentences wear the same grey. Shape and reasons: `.ai-support/decisions.md`.
- A picker offers only modules the machine **and** the recipe accept, by the measured rule that
  only a module's *positive* effects must be allowed (`analysis/api.md` §16); both are
  re-resolved when either half of the pair changes.
- Modded recyclers work by rotation, not convention — see fact 3.
- **Everything the loop rolls above the target leaves through one tap** — an inserter and an
  active-provider chest in the terminal column's two spare tiles, whitelisting `{target, ">"}`
  with **no item name**, so one slot covers any recipe. Footprint unchanged; it costs one extra
  pole. The terminal catcher is a single `">="` for the same reason. Why each part is as it is:
  `decisions.md`; the measurements: `analysis/api.md` §24.
- **Circuit limits are opt-in: reserve and cap, the numbers on one combinator** (2026-08-26,
  revised 2026-09-07). Every machine and recycler stops at one shared cap — the output chest's
  count of the product at the target quality — and each lower tier's buffer-to-recycler inserter
  holds that tier's floor, running at the minimum plus one hand size per column of that quality
  and pinned to that hand so a full grab lands exactly on the floor, never drawing the chest
  below the player's minimum (0 by default, meaning no reserve, no wire, no pin and no row for
  that tier). The hand is the chosen inserter's researched one, or the Circuits tab's Hand size field
  (`circuit_hand`, only-on-edit). Plain enable conditions on existing entities, each comparing
  against a `signal-M@tier` / `signal-C@target` row on one vanilla `constant-combinator` the
  layout stands directly under the terminal machine — so the loop is retuned in place, and
  switching the combinator off pauses a capped loop (and lifts every reserve: the description
  says which, per case); a *Start paused* checkbox at the foot of the limits ships it switched
  off. A cap also stands two lamps (blue running, green done) and a display panel (paused / done
  / running, on the map too) below it, each wired to the combinator alone. **Count the whole
  logistic network** (2026-09-12), a checkbox above Start paused, makes the cap the engine's own
  logistic condition on every machine and recycler — `product@target < max`, a constant baked
  per entity — with the wire keeping only the pause (`C > 0`), and an edit to C on the
  combinator copied onto every one of those constants by `scripts/retune.lua` (2026-10-26), the
  one thing the mod does to a stamped loop; the lamps follow it, the panel keeps its Paused row
  alone, validate refuses a `no-logistic-connection` machine (2.1 only), and the loop then only
  runs inside roboport range. Max only; the reasons and rejected shapes in `decisions.md`, the
  engine facts in `analysis/api.md` §34 and §35. Fixed prototypes, no research gate, one green
  network, footprint unchanged. The planner normalises the thresholds once
  (`planner.circuit_limits`) BEFORE the layout, and the pole memo keys on circuit presence,
  never the numbers — typing a threshold re-solves nothing. `scripts/circuits.lua` decorates the
  finished plan (pure, strictly after the pole pass); the numbers live in `storage` as flat
  `circuit_min_<quality>` / `circuit_max_<quality>` values plus the `circuit_paused` boolean and
  the `circuit_hand` number, edited inline in the Circuits tab, rows labelled Min/Max, greyed by
  `gui.refresh` while the checkbox is off and refilled in place when the target moves.
  Conditions go only onto what can hear the combinator over the wires placed; anything cut off
  is left ungated and warned about (`circuit_unlinked`), never refused. The recycler, like the
  feed chests, is held to its own reach: one that cannot carry the wire is left off it, its
  census joins the machine straight over it, and one with no circuit connection at all is
  named in its own warning (`circuit_wireless`). The combinator's
  description and the panel's words are blueprint strings, English constants in `circuits.lua`.
  Reasons and the rejected shapes (the first-built demand cascade included): `decisions.md`; the
  verified engine surface: `analysis/api.md` §26, §32 and §33.
- **Under a cap the chests stop asking with the loop** (2026-11-13): every feed chest, and
  every stock chest that still requests, carries the machines' own wire condition as a chest
  circuit condition (`circuit_condition_enabled`), so a paused or finished loop requests
  nothing. Network mode gives a chest the pause alone (`C > 0`); a reserve-only plan is
  untouched. **Never gate the output chest.** Feed chests link to their own machine against
  `feed_reach`, kept out of the shared reach, and write `read_contents = false`. Reasons:
  `decisions.md`; the measurements: `analysis/api.md` §36.
- Chests are 1x1, and each of the five roles offers only its own kind — the role is fixed, the
  chest is the player's. Only the overflow chest's role is forced to a specific logistic mode
  (active provider): on belts it is the loop's one sink that empties itself, and with bots it is
  every lower tier's out and extract chest, the way each tier hands its items to the network.
- **The stock chests are buffer chests by default** (2026-08-26): the stock role's kind follows
  the "Use buffer chests" checkbox — buffer chests share each tier's items with personal
  logistics and construction bots, requester chests keep them in the loop. Toggling refills the
  stock picker with the new kind's best and keeps its quality; the ingredient, output and
  overflow chests never change kind. Trade-offs and the rejected always/never shapes:
  `decisions.md`. Inserters reach one tile, are never fuelled and never belt-stacking. Both
  picker lists also gate on `items_to_place_this`, or show-all offers base's unplaceable 1x1
  scenery chests.
- **Two requests are the player's to switch off, both ticked by default** (2026-11-13).
  *Upcycle items from the network* (`stock_requests`): unticked, the stock chests request
  nothing and the loop recycles only what it makes. *Final machine requests ingredients*
  (`terminal_requests`): unticked, the target tier's feed chest is the relay role's plain
  chest. Read only through `planner.stock_requests` / `planner.terminal_requests` (nil means
  ticked), and never named with the `request_` prefix, which is the per-item override
  family. **A chest with no request carries no trash flag.**
  Geometry never moves; the pole memo keys on the final machine's chest. Reasons, costs and
  the rejected combinator row: `decisions.md`; the measurements: `analysis/api.md` §36.
- **A recipe past one inserter's filter slots feeds each machine from two stacks** (2026-09-09):
  a second harvest inserter, feed chest and feed inserter in the buffer sub-column above the
  machine, the ingredients split into balanced halves, never a third stack — the engine caps
  every inserter at five slots, so ten ingredients is the belt ring's cap on every machine
  (`layout.MAX_FEED_STACKS`, `planner.min_filter_slots`); bots filter no ingredient and have
  none, and their refusals name the missing filter slot. Plans that fit one inserter are
  byte-identical to before. A chosen inserter short of the split's larger half is named in the
  refusal **only when a better one exists** — otherwise the recipe is blamed, naming the
  ceiling, which is every vanilla case. The default pick tries an inserter that filters the
  whole list alone before one that only serves the split. The pole memo keys on the stack
  count. The price is power: with a medium pole such a plan opens a utility column about
  every two tiers, none with a substation. Reasons: `decisions.md`; the measurements:
  `analysis/api.md` §15 and `analysis/poles.md` §Performance.
- **The extract inserter under every recycler is one nameless `{quality > tier}` whitelist**
  (2026-09-09), the overflow tap's shape — on every plan, not only the big recipes. Reasons:
  `decisions.md`; the live measurement: `analysis/api.md` §9.6.
- **Beacons are opt-in: off by default, a vertical stack per tier in the utility column when
  picked**, the machine-only terminal tier included. The player chooses the count from a
  drop-down offering exactly 1..`layout.max_beacon_count` (vanilla: 4); stacking costs rows,
  never width, and an outgrown count clamps, never refuses. The beacon row always shows, empty
  meaning none; its module and count rows appear once a beacon is picked. The beacon-module
  picker defaults to the best researched **efficiency** module, never speed (why:
  `decisions.md`). Its clear means "place the beacon empty" (`no_beacon_module`); the beacon
  itself needs no clear-flag, since nil already means off. Short reach warns per receiver (some
  beacon reaches the machine, some the recycler); a beacon taller than the interior refuses.
  Measured facts: `analysis/api.md` §25; geometry: `analysis/layout-belt-ring.md` §Beacons.
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
- Refused, each with a message: recipes with two or more fluids, recipes with more
  ingredients than two inserters can filter on belts (ten in vanilla), machines no rotation
  can pipe, self-recycling items, and recipes that refuse quality modules.
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
owns. What is left beyond that is scope, and `deferred.md` holds it.
