# CLAUDE.md — Space Forge

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

A large overhaul, expected to take months. **Nothing is implemented yet** — this folder is
scaffolding: `info.json`, locale, changelog, licence and an empty `data.lua`. It loads and
does nothing.

**Unpublished.** No `space-forge_*` git tag exists, so version `0.1.0` is the open section in
`changelog.txt` (`Date: ????`) and stays open until the first authorised release. New work
joins that section rather than opening a second one — the `factorio-changelog` skill's rules
and the `factorio-release` skill's "Published or open?" check govern.

## Two mods, on purpose

| Mod | Holds | Changes |
|---|---|---|
| `space-forge` | prototypes, recipes, technologies, `control.lua` | often |
| `space-forge-graphics` | every sprite, icon and sound | rarely |

Art is the heavy half of an overhaul and the half that changes least, so a balance patch
should not make every player re-download it. This is the pattern Space Exploration
(`space-exploration-graphics`, parts 1–5) and Krastorio 2 (`Krastorio2Assets`) both use, and
both were read before choosing it.

**Three rules keep the split working:**

- **Every graphic is named `__space-forge-graphics__/graphics/...`.** This mod's own folder
  holds no art at all — the one exception is `thumbnail.png`, which the game only reads from a
  mod's own root.
- **The two versions are independent sequences.** `space-forge` 0.4.2 alongside
  `space-forge-graphics` 0.2.0 is normal and correct. Do not sync them; do not read one number
  as saying anything about the other. (This is *not* the shared sequence the repo's two release
  *branches* use — that rule is about `main` vs `legacy/2.0`, a different thing entirely.)
- **Adding art means bumping the floor.** When this mod starts naming a file that only exists
  from `space-forge-graphics` 0.3.0 onward, raise the dependency in `info.json` to
  `"space-forge-graphics >= 0.3.0"` in the same change. Without it a player on the old graphics
  mod gets a file-not-found load failure instead of the mod manager telling them to update.
- **The graphics mod never depends on this one.** It is a pure asset container with no Lua —
  that is why the dependency can only run one way.

Releases are two uploads, not one, and each mod carries its own `changelog.txt`. Art-only work
gets an entry in the graphics mod's changelog, not this one.

## Layout

Nothing below `data.lua` exists yet. This is the shape to grow into — it follows the community
convention in the `factorio-mod-setup` skill: grouped by **content**, not by prototype kind,
and a folder named after a data stage holds exactly what that stage requires.

```
data.lua                     entry point; one require per content group
data-updates.lua             added when vanilla prototypes first need patching
data-final-fixes.lua         added when something must run after every other mod
control.lua                  added when the first runtime feature lands
settings.lua                 added when the first setting lands
prototypes/
  <group>/                   one folder per content area, one file per thing
  shared/                    plain Lua modules — no data:extend in here
  final-fixes/               exactly what data-final-fixes.lua requires
scripts/                     one file per runtime feature, required by control.lua
migrations/                  added the first time a prototype is renamed
locale/en/space-forge.cfg    every player-visible string
.ai-support/index.md         the map — read it first
.ai-support/decisions.md     what is settled, and why
```

**`require` paths use dots, mod-wide** — a readability convention, not a correctness one.
Factorio caches by resolved file, so dots and slashes are equivalent (verified on 2.1.14); one
spelling just makes a shared module grep-able.

## Working here

- Commit scope is `space-forge` for this mod, `space-forge-graphics` for the other. Repo-wide
  changes use `repo`.
- **Never commit, push or publish unprompted** — repo `CLAUDE.md`, and approval is per request.
- `README.md` and the `info.json` / locale descriptions are player-facing and become the portal
  description verbatim via `fmtk details --readme`. Both currently describe an unfinished mod
  on purpose; rewrite them before the first release rather than after.
- `LICENSE` at the mod root is the repo root's GPLv3 text, copied verbatim. Keep the two in
  sync if the root copy is ever refreshed.
- **`.ai-support/` is this mod's local context — start at its `index.md`.** Design decisions go
  in `.ai-support/decisions.md` as they are made, with the reason; it covers the graphics mod
  too, which carries no `.ai-support/` of its own. The repo `CLAUDE.md` → *AI support folders*
  has the rules, including which further files to add and when. Anything that generalises beyond
  this mod belongs in a skill under `.claude/` instead.
- **Validating needs both mods staged.** `validate.ps1` takes one `-ModPath`, so a run against
  `space-forge` alone dies on the unresolved `space-forge-graphics` dependency. Stage both into
  a scratch `mods/` with a BOM-free `mod-list.json` naming all three (`base` included), then run
  `factorio.exe --config <scratch>/config.ini --mod-directory <scratch>/mods --dump-data
  --check-unused-prototype-data` — the `-Live` recipe from the `factorio-validate` skill, done
  by hand. Confirm `Checksum of space-forge:` appears in the log; exit 0 alone can mean the mod
  was skipped. Baseline established 2026-08-08: exit 0, both mods loaded, no errors.
- **Always pass `--check-unused-prototype-data`.** It costs 0.03 s and is the only thing that
  catches a misspelled prototype property, which the loader ignores rather than rejecting.
  Vanilla and the expansions emit nothing, so every warning belongs to this mod — but the exit
  code stays 0, so the log has to be read. Details and the measured evidence are in the
  `factorio-validate` skill. At overhaul scale this is the highest-value check available.

## Decided

- **Two mods, `space-forge` + `space-forge-graphics`.** Reasons and rules above.
- **Portal names are free.** Both were checked against the read-only portal API on 2026-08-08
  and returned `Mod not found`. Worth having done: `pure-modules` was lost to a squat by a
  deleted account, and portal names stay taken even after the account goes.
- **Factorio 2.1 only, for now.** `factorio_version` is `"2.1"` and there is no `legacy/2.0`
  build. An overhaul is a large thing to keep on two tracks and there is nothing shipped to
  keep compatible yet; revisit only if the mod reaches a release worth backporting.
- **No Space Age `*_required` flag, and none by default.** Declaring one makes the expansion
  mandatory. Read `feature_flags[...]` to light up expansion-only behaviour instead — unless
  the overhaul is eventually designed *around* Space Age, which is an open question below.
- **Version starts at `0.1.0`** on both mods, and the two sequences run independently.

## Open questions

The design is deliberately undecided. **`.ai-support/decisions.md` is the single owner** of the
open list and the reasons behind it — record answers there as they are made, rather than letting
them exist only in the code, and keep the summaries below to one line each.

- **What does the overhaul actually change?** Scope is undefined: production chains,
  progression, planets, combat — none of it is chosen.
- **Base game, Space Age, or built on Space Age?** This decides `dependencies`, whether any
  feature flag is declared, and how large the art bill is. It is the first question worth
  answering — most other decisions hang off it.
- **Compatibility stance.** Overhauls usually carry a long `!` incompatibility list (Space
  Exploration's is worth reading). Nothing is declared yet.
- **Art direction.** Undecided — read the `factorio-graphics` skill before the first sprite;
  the design work happens before any Blender step.
- **`thumbnail.png` does not exist** on either mod. 144x144, at each mod's own root, and both
  need one before release. Deliberately not stubbed: a placeholder is the kind of thing that
  ships by accident.
- **Whether the graphics mod ever needs splitting further.** Space Exploration is at five
  parts, driven by portal upload size limits. Not a problem to solve until it is one.
