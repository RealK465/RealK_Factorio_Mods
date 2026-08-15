# CLAUDE.md — Upcycler Architect

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

A planner in the tradition of Mining Patch Planner and P.U.M.P.: the player picks an item and a
target quality, and the mod designs a complete upcycling loop and drops it as ghosts.

**Nothing is implemented yet** — this folder is scaffolding: `info.json`, locale, changelog,
licence and the docs. There is no `data.lua` and no `control.lua`, so the mod loads and does
nothing. That is intentional; scope is still open.

**Unpublished.** No `upcycler-architect_*` git tag exists, so version `0.1.0` is the open
section in `changelog.txt` (`Date: ????`) and stays open until the first authorised release.
New work joins that section rather than opening a second one — the `factorio-changelog`
skill's rules and the `factorio-release` skill's "Published or open?" check govern.

## The one technical fact worth not re-deriving

**Place ghosts, never a blueprint string.**
`LuaSurface.create_entities_from_blueprint_string` is documented *"only works when used in
simulations"* — it is for menu backgrounds and will not work here. Both reference mods emit
`surface.create_entity{name = "entity-ghost", inner_name = ...}` per entity, and so should
this one. The full verified API inventory — quality on ghosts, `recipe_quality`,
`item-request-proxy` for module delivery, the selection-tool events — is in
`.ai-support/design.md` rather than repeated here.

**Neither reference mod is in this workspace.** They were read from downloaded zips before the
repo moved into its own install, and what that reading produced is written down in
`.ai-support/design.md` — that file is the reference now. If a detail there ever needs
re-checking, download a copy into a scratch directory and read it there. Other authors' work:
reference only, never edited, never redistributed.

## Dependencies

`["base >= 2.1.0", "quality >= 2.1.0"]`.

The hard dependency on `quality` is deliberate and does double duty: the mod is meaningless
without quality tiers, and in 2.1 `quality` itself declares `"recycler >= 2.1.0"`, so this one
line pulls in the recycler too. **No `quality_required` feature flag is declared** — the flag
would make Space Age ownership mandatory without fixing load order, which is the wrong half of
what is needed. Reach for `feature_flags[...]` only if some behaviour should light up
optionally.

## Layout

Nothing below the docs exists yet. This is the shape to grow into — it follows the community
convention in the `factorio-mod-setup` skill: grouped by **content**, not by prototype kind.

```
data.lua                            entry point; selection tool, shortcut, custom input
control.lua                         GUI, selection handling, the layout engine
settings.lua                        added when the first setting lands
prototypes/
  <group>/                          one folder per content area, one file per thing
scripts/                            one file per runtime feature, required by control.lua
graphics/                           tool and GUI icons
locale/en/upcycler-architect.cfg    every player-visible string
migrations/                         added the first time a prototype is renamed
.ai-support/design.md               the running design record — decisions and their reasons
```

**`require` paths use dots, mod-wide** — a readability convention, not a correctness one.
Factorio caches by resolved file, so dots and slashes are equivalent (verified on 2.1.14); one
spelling just makes a shared module grep-able.

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

## Open questions

Listed in full in `.ai-support/design.md`. The first one — *what does the player actually
select, given an upcycler has no world feature to point at* — gates most of the rest.
