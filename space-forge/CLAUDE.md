# CLAUDE.md — Space Forge

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

**An overhaul of Space Age**, expected to take months — what Krastorio 2 is to base Factorio,
Space Forge is to Space Age. The game opens below vanilla's tier with steam-era machines and
ends well above it. `.ai-support/identity.md` is the register; the summary here owns none of it.

**How many tiers there are and what unlocks them is not decided.** `art-direction.md` treats the
opening-to-endgame span purely as a *visual* gradient and commits to no progression.

**Nothing is implemented yet** — this folder is scaffolding: `info.json`, locale, changelog,
licence and an empty `data.lua`. It loads and does nothing. **The design is ahead of the code
on the art side and behind it on the mechanics side**: the art direction is settled and buildable
today, while the tiers, the chains and the science are all still open.

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
.ai-support/index.md         the map, and the one-file-per-concept rule — read it first
.ai-support/identity.md      what the mod is
.ai-support/art-direction.md how it looks
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
- **`.ai-support/` is this mod's local context — start at its `index.md`.** Registers here are
  named for the **concept** they own: `identity.md` for what the mod is, `art-direction.md` for
  how it looks, and a new file per concept rather than a catch-all. `index.md` has the map of
  concepts not yet opened; `.claude/references/ai-support.md` has the naming rule and why. The
  folder covers the graphics mod too, which carries no `.ai-support/` of its own.
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
- **Factorio 2.1 only.** `factorio_version` is `"2.1"` and there is no `legacy/2.0` build.
  Space Age is required regardless, and an overhaul is a large thing to keep on two tracks with
  nothing shipped to stay compatible with.
- **Space Age is required, not optional.** It is the substrate the mod overhauls, so
  `feature_flags[...]` probing is *not* the technique here — this mod does not work without it.
  This reverses the 2026-08-08 position; `.ai-support/identity.md` carries the reversal.
  **`info.json` has not been updated yet** and still declares only `base` and
  `space-forge-graphics`. Fix it through the `factorio-mod-setup` skill, not from memory.
- **Version starts at `0.1.0`** on both mods, and the two sequences run independently.

## Art — the rules

Every rule below has its reason, its measured numbers and its worked-out form in
**`.ai-support/art-direction.md`**. Read that before any sprite, icon, palette or Blender
decision, including the design step — these one-liners exist so nothing is missed, not so the
register can be skipped. All of them fail quietly rather than loudly.

- **Place the entity on the crude/industrial/exotic gradient first.** It decides paint, glow and
  silhouette. Anchors on a continuum, not a tier list.
- **Paint goes down and glow goes up along it**, against targets the register states and
  `.claude/skills/factorio-entity-design/scripts/counterpart.py` measures.
- **Violet is the mod's own colour and is saved for the top.** Cyan and magenta are vanilla's —
  the register names which entity owns each.
- **Nothing rusts in vacuum, and nothing is clean either.** Wear is keyed to environment.
- **Custom art only for a new tier or family, never a re-skin**, and a machine that gets it gets
  the whole set — base, shadow, animation, status light, icon, remnants.
- **Build art in the order the player meets it**, starting with the miner line at the crude end.
- **Design each entity through `factorio-entity-design` before modelling.**

## Open questions

**`.ai-support/identity.md` → *Open* is the single owner** of the open list, and its table names
the concept file each answer will become — **progression.md**, **chains.md**, **science.md** and the
rest. Record answers in the file for that concept rather than letting them exist only in the
code, and keep any summary here to one line.

Everything mechanical is still open: the tiers and what unlocks them, the production chains, the
science, the compatibility list, and which part ships first as something playable. Two items that
are not design questions and are easy to lose:

- **`thumbnail.png` does not exist** on either mod. 144x144, at each mod's own root, and both
  need one before release. Deliberately not stubbed: a placeholder is the kind of thing that
  ships by accident.
- **Whether the graphics mod ever needs splitting further.** Space Exploration is at five
  parts, driven by portal upload size limits. Not a problem to solve until it is one.
