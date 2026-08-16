# CLAUDE.md — Upcycler Architect

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

A planner in the tradition of Mining Patch Planner and P.U.M.P.: the player picks an item and a
target quality, and the mod designs a complete upcycling loop and drops it as ghosts.

**The first version works end to end**, as of 2026-08-15: a shortcut opens a modal and Confirm
hands over a placement tool whose click drops the whole loop as ghosts. The modal is in two
blocks since 2026-08-16 — what the loop MAKES (item, target quality, crafting machine and
recycler, the last two with a quality of their own) above a **Build options** block for what it
is built OUT OF (belt, quality module and its quality, and the trash-unrequested checkbox).
What it emits is the belt-ring family — see
`.ai-support/analysis/layout-belt-ring.md` for the geometry and `.ai-support/deferred.md` for
what was deliberately left out (circuits and wires, fluid recipes, bot transport).

**Played with in game, not yet proven.** The data stage validates, several rounds of live
feedback have been folded back in (research gating, modded chests and recyclers, GUI fixes),
and the planner and layout are exercised by a headless harness — but the loop's long-run
*behaviour*, above all whether the recycler's eject stalls politely when its machine rejects a
rolled-up ingredient, is still unproven. That is the standing thing to watch in game.

**Unpublished.** No `upcycler-architect_*` git tag exists, so version `0.1.0` is the open
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
`.ai-support/design.md` (2026-08-15, research gating) and `analysis/api.md` §8.

**The research is in `.ai-support/analysis/`** — start at its `README.md`. Decoded blueprints and
the scaling law, the chosen belt-ring layout as a formula, the deferred bot-loop layout, the
verified API (including what is *not* verified), the quality maths, and the reference-mod
patterns. `.ai-support/design.md` holds the decisions; `analysis/` holds the evidence.

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
  state.lua    persistent choices   dispatch.lua  tag-based GUI handler registry
locale/en/upcycler-architect.cfg    every player-visible string
migrations/                         added the first time a prototype is renamed (none yet)
.ai-support/design.md               the running design record — decisions and their reasons
.ai-support/deferred.md             parked work, each entry with enough context to pick up cold
.ai-support/analysis/               the evidence: decoded blueprints, verified API, layout specs
```

No `graphics/` yet — the shortcut and tool share layered vanilla icons until real art lands
(`.ai-support/deferred.md`).

**`require` paths use dots, mod-wide** — a readability convention, not a correctness one.
Factorio caches by resolved file, so dots and slashes are equivalent (verified on 2.1.14); one
spelling just makes a shared module grep-able.

## Naming

**Every prototype this mod defines is prefixed `ua-`.** Shortcut `ua-open`, selection tool
`ua-planner`, and so on. Prototype names are one flat global namespace shared with every other
mod, so the prefix is what stops a collision — and a collision here is silent, which is the
whole reason for the rule.

This mirrors the house style in `pure-modules-realk`, which names prototypes with a short tag
(`pure-speed-module`, `pure-beacon`) rather than the full mod name. Two things follow it and one
does not:

- **Prototypes** use the short tag: `ua-`.
- **GUI element names and tag keys** use it too, so a stray element is traceable to this mod.
- **Settings and locale mod-level keys** use the **full** `upcycler-architect` — that is how
  `pure-modules-realk` does it (`pure-modules-realk-beacon-allow-quality`), and mod settings are
  listed to players next to other mods' settings where a two-letter tag would be meaningless.

`upcycler-` was rejected as the tag: the portal already carries a different mod named
`upcycler` (a machine that converts N items into one of the next tier), which is likely to own
that name and names derived from it.

Renaming a prototype later costs a migration file and a major version bump, so this is settled
before the first one is written rather than after.

## Working here

- Commit scope is `upcycler-architect`. Repo-wide changes use `repo`.
- **Never commit, push or publish unprompted** — repo `CLAUDE.md`, and approval is per request.
- `README.md` and the `info.json` / locale descriptions are player-facing and become the portal
  description verbatim via `fmtk details --readme`. All three currently describe an unfinished
  mod on purpose; rewrite them before the first release rather than after.
- `LICENSE` at the mod root is the repo root's GPLv3 text, copied verbatim. Keep the two in
  sync if the root copy is ever refreshed.
- Design decisions go in `.ai-support/design.md` as they are made, with the reason. Anything
  that generalises beyond this mod belongs in a skill under `.claude/` instead.
- **Always pass `--check-unused-prototype-data` when validating.** It is the only thing that
  catches a misspelled prototype property, which the loader ignores rather than rejecting, and
  the exit code stays 0 either way — so the log has to be read. See the `factorio-validate`
  skill.
- A GUI mod carries desync risk that a data-only mod does not. Read the `factorio-mod-development`
  skill on `storage` and save/load before the first line of `control.lua`, and note that
  `flib`'s save/load-safe GUI handler registry (`exemples/flib_0.17.2/gui.lua`) is the
  reference pattern — read it for prior art before hand-rolling one.

## Decided

Reasons for each are in `.ai-support/design.md`.

- **Name `upcycler-architect`**, chosen 2026-08-15; portal name verified free the same day.
- **Ghosts, not blueprint strings** — the API forces this.
- **Hard `quality` dependency, no feature flag.**
- **Factorio 2.1 only**, no `legacy/2.0` build.
- **Version starts at `0.1.0`.**
- **Shortcut -> GUI -> Confirm -> selection tool -> click.** The player selects nothing in the
  world but ground; the GUI's choices define the footprint.
- **Inputs, in two blocks.** What the loop makes: item, target quality, crafting machine,
  recycler. What it is built from, under a **Build options** caption: belt, quality module, and
  the trash-unrequested checkbox (checked by default). Machine, recycler and module each carry
  their own **quality**; the belt does not, because `belt_speed` has no quality variant. The
  recycler row is always shown — it was a non-choice in vanilla until quality made it one.
- **Pickers offer only what is researched.** The per-player `upcycler-architect-show-all`
  setting shows everything instead, standing in for the game's own selection-list option,
  which mods cannot read.
- **Fuelled inserters are never planned in** — an unattended loop cannot keep them fed. When
  every researched inserter needs fuel (how a fresh Space Age game starts), validation says
  so instead of planning a loop that would starve.
- **Modded recyclers work by rotation, not convention** — see fact 3. The one hard limit is
  that the rotated throw lands inside the machine above.
- **Belt ring first**, specified in `.ai-support/analysis/layout-belt-ring.md`. The **bot loop is
  a deferred toggle**, not a dead idea — spec in `analysis/layout-bot-loop.md`.
- **Gated on the `recycling` technology**, not on quality: without a recycler there is nothing
  to build.
- **Modules planned, not merely requested** — quality below target, productivity at target, and
  the target machine left **empty** when the recipe or the machine refuses productivity
  (`allow_productivity` defaults to false, so this is the common case, not the exotic one).
- **No flib dependency** — copy its handler-registry pattern instead.
- **Prototype names are prefixed `ua-`** — see Naming above.

## Open questions

Listed in full in `.ai-support/deferred.md`. The one that used to gate everything — *what does
the player actually select* — is answered above. What is left is mostly scope: modded quality
tiers, whether the GUI should show expected output, `thumbnail.png`, and a possible
cursor-blueprint placement route.
