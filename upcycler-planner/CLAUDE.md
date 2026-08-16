# CLAUDE.md — Upcycler Planner

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

A planner in the tradition of Mining Patch Planner and P.U.M.P.: the player picks an item and a
target quality, and the mod designs a complete upcycling loop and drops it as ghosts.

**The first version works end to end**, as of 2026-08-15: a shortcut opens a modal and Confirm
hands over a placement tool whose click drops the whole loop as ghosts. The modal is in two
blocks since 2026-08-16 — what the loop MAKES (item, target quality, crafting machine and
recycler, the last two with a quality of their own) above a **Build options** block for what it
is built OUT OF (belt, quality module and its quality, electric pole and its quality, and the
trash-unrequested checkbox).
What it emits is the belt-ring family — see
`.ai-support/analysis/layout-belt-ring.md` for the geometry and `.ai-support/deferred.md` for
what was deliberately left out (circuits and wires, fluid recipes, bot transport).

**Played with in game, not yet proven.** The data stage validates, several rounds of live
feedback have been folded back in (research gating, modded chests and recyclers, GUI fixes),
and the planner and layout are exercised by a headless harness — but the loop's long-run
*behaviour*, above all whether the recycler's eject stalls politely when its machine rejects a
rolled-up ingredient, is still unproven. That is the standing thing to watch in game.

**Unpublished.** No `upcycler-planner_*` git tag exists, so version `0.1.0` is the open
section in `changelog.txt` (`Date: ????`) and stays open until the first authorised release.
New work joins that section rather than opening a second one — the `factorio-changelog`
skill's rules and the `factorio-release` skill's "Published or open?" check govern.

## The four technical facts worth not re-deriving

**1. Place ghosts, never a blueprint string.**
`LuaSurface.create_entities_from_blueprint_string` is documented *"only works when used in
simulations"* — it is for menu backgrounds and will not work here. Both reference mods emit
`surface.create_entity{name = "entity-ghost", inner_name = ...}` per entity, and so should
this one.

**2. Two things about ghosts that the obvious API does not do.** `create_entity` **cannot** set
a ghost's recipe — its variant groups are keyed by `name`, so with `name = "entity-ghost"` only
`inner_name` and `tags` apply. Create the ghost, then `set_recipe(recipe, quality)`. Modules go
through `ghost.insert_plan` (read/write, `EntityGhost` in its subclasses), **not** an
`item-request-proxy` — `item_requests` is read-only in 2.1. Both of these were written down
wrongly the first time; the corrected detail is in `.ai-support/analysis/api.md` §3.

The variant-group trap cuts only one way, which is easy to over-learn: `quality` is a **common**
`create_entity` parameter rather than a member of another group, so
`create_entity{name = "entity-ghost", inner_name = ..., quality = "legendary"}` does produce a
legendary ghost. Verified live on 2026-08-16. What the group keying excludes is parameters
belonging to a *different* group, `recipe` among them — not everything outside `entity-ghost`.

**3. The recycler ejects like a mining drill.** `vector_to_place_result = {-0.35, -2.3}`
(`data/recycler/data.lua:109`) on a 2x4 furnace: it throws output out of its north face. Stand
it tangent under its machine and recycled ingredients arrive with **zero inserters** — which is
what every reference design does, and the constraint the whole layout hangs off. The vector is
**per-prototype** (Age of Production's salvager throws out its east flank), so
`planner.recycler_orientation()` computes the rotation that lands the throw in the machine
above, and any recycler width fits — the columns widen to it. The paired
machine is pinned to one quality tier and quality matching is *exact*, so a rolled-up ingredient
jams the eject; that is what the blacklist inserter beneath the recycler is for.

**4. A recycling recipe is never evidence an item is buildable.** Researching `recycling`
unlocks every generated `*-recycling` recipe at once — grinding a tier-3 module *produces*
tier-2 modules, and cheat items with no real recipe (Editor Extensions) self-recycle — so
"some enabled recipe produces it" reads unresearched modules and infinity chests as unlocked.
The producer map in `planner.lua` excludes the recycling category and Factoriopedia-hidden
recipes, and the chest picker takes only real `logistic-container`s. Story and evidence:
`.ai-support/journal.md` (2026-08-15, research gating) and `analysis/api.md` §8.

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

`["base >= 2.1.0", "quality >= 2.1.0"]`.

The hard dependency on `quality` is deliberate and does double duty: the mod is meaningless
without quality tiers, and in 2.1 `quality` itself declares `"recycler >= 2.1.0"`, so this one
line pulls in the recycler too. **No `quality_required` feature flag is declared** — the flag
would make Space Age ownership mandatory without fixing load order, which is the wrong half of
what is needed. Reach for `feature_flags[...]` only if some behaviour should light up
optionally.

## Layout

The shape follows the community convention in the `factorio-mod-setup` skill: grouped by
**content**, not by prototype kind.

```
data.lua                            entry point; requires the prototype files
control.lua                         lifecycle and event wiring only — the work lives in scripts/
settings.lua                        one per-player setting: show unresearched options
prototypes/planner/                 shortcut, selection tool, and the icon layers they share
scripts/                            one file per runtime concern, required by control.lua
  gui.lua      the modal            planner.lua   derivations and validation
  layout.lua   pure geometry        builder.lua   ghosts on the ground
  poles.lua    pole coverage, connectivity and growth -- pure like layout.lua
  state.lua    persistent choices   dispatch.lua  tag-based GUI handler registry
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

No `graphics/` yet — the shortcut and tool share layered vanilla icons until real art lands
(`.ai-support/deferred.md`).

**`require` paths use dots, mod-wide** — a readability convention, not a correctness one.
Factorio caches by resolved file, so dots and slashes are equivalent (verified on 2.1.14); one
spelling just makes a shared module grep-able.

## Naming

**Every prototype this mod defines is prefixed `upl-`.** Shortcut `upl-open`, selection tool
`upl-planner`, and so on. Prototype names are one flat global namespace shared with every other
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
- **`README.md` is the portal description**, uploaded verbatim by `fmtk details --readme`, and
  `images/` is the gallery in filename order. Both are player-facing and settled; what each
  image is, and where the readme's demo gifs are hosted, is in `.ai-support/decisions.md` →
  *Portal presentation*. Gathering them is not a release — publishing still needs the owner's
  approval for that specific upload.
- `LICENSE` at the mod root is the repo root's GPLv3 text, copied verbatim. Keep the two in
  sync if the root copy is ever refreshed.
- **Design decisions go in `.ai-support/decisions.md` as they are made, with the reason, and the
  session that produced them in `.ai-support/journal.md`.** Both, not either — the repo
  `CLAUDE.md` → *AI support folders* has the rules. Anything that generalises beyond this mod
  belongs in a skill under `.claude/` instead.
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
- Factorio 2.1 only, no `legacy/2.0` build. Version starts at `0.1.0`.
- Hard `quality >= 2.1.0` dependency, no feature flag. No flib dependency.
- **Ghosts, one at a time — never a blueprint string.** The API forces this; see fact 1 above.
- Shortcut → modal → Confirm → selection tool → click, gated on the `recycling` technology. The
  player selects nothing in the world but ground.
- The modal is two blocks: what the loop **makes** (item, target quality, machine, recycler),
  then a **Build options** block for what it is built **out of** (belt, quality module, pole,
  trash-unrequested checkbox). Machine, recycler, module and pole each carry their own quality;
  the belt does not.
- Pickers offer only what is researched, unless the per-player `upcycler-planner-show-all` is on.
- **`storage` holds flat strings only** — never a `{name, quality}` table.
- Belt ring is the layout (`.ai-support/analysis/layout-belt-ring.md`); the bot loop is a
  deferred toggle, not a dead idea (`analysis/layout-bot-loop.md`).
- Modules are planned rather than requested, and the terminal machine is left **empty** when the
  recipe or the machine refuses productivity.
- Modded recyclers work by rotation, not convention — see fact 3.
- Chests are 1x1. Inserters reach one tile and are never fuelled. Poles default to the best
  researched 1x1 and are clearable to none (`analysis/poles.md`, `analysis/api.md` §10).
- Refused, each with a message: fluid recipes, self-recycling items, and recipes that refuse
  quality modules.

## Open questions

**`.ai-support/deferred.md` is the single owner** of parked and open work, so the two lists
cannot drift apart. The question that used to gate everything — *what does the player actually
select* — is answered above. What is left is mostly scope: modded quality tiers, whether the GUI
should show expected output, `thumbnail.png`, and a possible cursor-blueprint placement route.
