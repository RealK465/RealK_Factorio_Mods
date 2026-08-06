---
name: factorio-multiversion
description: Use whenever a mod has to reach more than one Factorio major version — backporting to 2.0 while 2.1 stays the main target, judging whether a change is safe on 2.0, numbering the two release tracks, working on the legacy/2.0 branch, validating a build against a 2.0 install, or answering "does this still work on 2.0 / does it need updating for 2.1". Also use when writing or reading factorio_version, and when a mod is refused with "Incompatible Factorio version". One zip serves exactly one major version and the differences that bite are the silent ones, so check here instead of assuming a build carries over.
---

# Two game versions: 2.1 main, 2.0 backport

## Where this repo stands

**2.1 is the target.** It is what the working tree is, what the live install runs, and what
every mod's `info.json` says. Nothing here changes that.

2.0 is the current *stable* release, so it is what most players are still on — the portal is
full of mods shipping fresh 2.0 builds. A 2.0 build of one of our mods is therefore worth
having and **never worth blocking on**. If a backport turns awkward, ship 2.1 alone and say so.
When 2.1 goes stable the 2.0 track stops getting work, and nothing here needs undoing.

## One zip, one major version

`factorio_version` names exactly one major version and the game enforces it. Verified on this
machine — Pure Modules marked `"2.0"`, loaded by 2.1.14:

```
Error Util.cpp:81: Failed to load mod "pure-modules-realk":
    • Incompatible Factorio version (current: 2.1, required: 2.0)
```

There is no range syntax — `">= 2.0"` in that field is not a thing — and the
`0.18`-loads-in-`1.0` exception was a one-off never repeated. Wube declined multi-version mods
deliberately: *"we definitely want it to be explicit."*

Supporting both therefore means **two uploads of the same mod name**, each with its own
`factorio_version` and its own version number. The portal keeps every release and serves each
game the newest one matching its major version; the in-game browser never shows the other track.

## The two tracks

| | main | legacy/2.0 |
|---|---|---|
| Branch | `main` — the live mod folder | `legacy/2.0`, checked out in a worktree |
| `factorio_version` | `"2.1"` | `"2.0"` |
| `base` dependency | `base >= 2.1.0` | `base >= 2.0.0` |
| Version band | `<major>.1.x` | `<major>.0.x` |
| Validated against | the Steam 2.1 install | a standalone 2.0 install |

### Version numbering

**One sequential version line, shared across both tracks.** A version string is unique per mod
on the portal no matter which game it targets, so both tracks draw from a single sequence:
whatever ships next takes the next free number, whichever game it is for. Pure Modules is the
worked example — `1.0.0` for Factorio 2.0, then `1.0.1` for Factorio 2.1, both on 2026-08-06.

- **major** — a save-breaking prototype rename or removal, as `factorio-release` says. Bumps
  on both tracks.
- **minor / patch** — ordinary semver, graded against the *previous release of this mod*,
  whichever track that happened to be.

**A release number therefore says nothing about which game it is for.** `factorio_version`
inside the zip is the only thing that does, and the portal serves each game only the releases
matching it, so a 2.0 player never sees the 2.1 numbers or vice versa. Say which game a
release targets in its changelog section instead — see `factorio-changelog`.

The cost, worth knowing before picking this scheme: the tracks interleave, so a 2.0 release can
sit numerically above a 2.1 one. That only matters where something compares mod versions across
a game upgrade — our own `mods["<name>"]` checks, or reading the mod version a save recorded.
Migrations are unaffected: they are applied per save **by file name**, never by version
comparison. Keep version comparisons out of cross-track logic and the interleaving is harmless.

The alternative is a **band**, reserving the minor digit for the game generation (`1.1.x` for
2.1, `1.0.x` for 2.0) so the newer game always reads as newer — `planet-muluna` ships `2.2.x`
builds for 2.0 between its `2.6.x` releases for 2.1. **This repo does not use bands.** Do not
"correct" an existing sequence onto one; version numbers are the repo owner's call, and the
published ones can never be changed.

## The legacy branch

`legacy/2.0` diverges from `main` in `info.json` (version, `factorio_version`, `base` floor) and
in whatever code the port needs. Everything else arrives by cherry-pick.

**Check it out outside the mods directory.** This repo *is* the live mods folder; a second copy
of a mod inside it is untracked clutter in the one directory the game scans. The worktree path
for this machine is in `CLAUDE.local.md`.

```bash
git worktree add <legacy-path> legacy/2.0     # first time; add -b to create the branch
cd <legacy-path>
git cherry-pick <commit-from-main>            # expect conflicts in info.json / changelog.txt
```

Conflicts in `info.json` and `changelog.txt` are the normal case, not a mistake — both files
legitimately differ between tracks. Keep the legacy band on both sides of the resolve.

Cherry-pick per change rather than per release: a `main` commit touching 2.1-only API has to be
rewritten instead of picked, and that is far easier to notice one commit at a time.

## Backporting a change

1. **Read the change against `references/2.1-breaking-changes.md`.** Anything on that list has
   to be rewritten for 2.0, not picked.
2. Cherry-pick or rewrite on `legacy/2.0`.
3. Keep `info.json` in the legacy band — `factorio_version` `"2.0"`, `base >= 2.0.0`, version
   `<major>.0.x`.
4. Validate against a 2.0 install (below). A green run is necessary, not sufficient.
5. Diff the dumps (below), then read the silent-behaviour list with the change in mind.
6. Write the changelog entry on the legacy track (below).
7. Stop. A backport release needs the repo owner's approval for that specific release, exactly
   like any other — `factorio-release` applies unchanged.

## What actually differs, in three classes

Only the first class announces itself.

**1. Hard errors.** A removed or renamed prototype property, a `defines` entry that no longer
exists. The data stage refuses to load and names the property.
`references/2.1-breaking-changes.md` is the list; validation catches whatever the list missed.

**2. Silent property drops.** *The data stage ignores properties it does not recognise.* A
2.1-only property in a 2.0 build loads clean and does nothing at all. This is what the dump diff
is for.

**3. Silent behaviour changes** — the dangerous class. Same prototype, same values, different
engine behaviour. Nothing errors, nothing shows in a dump diff, and the mod is quietly wrong.

Pure Modules is the standing example. Its headline promise is that module penalties do not scale
with quality while the bonuses do, and it writes **no property at all** for that — it relies on
2.1's defaults for `consumption_quality_multiplier` / `pollution_quality_multiplier` (0.0 for a
detrimental effect). Those properties do not exist in 2.0, where quality scales the penalties
too. A 2.0 build loads clean, dumps byte-identical module prototypes, and breaks the feature the
mod is named after.

The only defence is reading the changelog for the *behaviour* entries, not just the removals:
quality effect values divided by 10, `next_probability` multiplied by 10, module effects
resolving to 0.01%, selection flags no longer implying `any-entity`, reactors no longer
connecting by touching edges, the recycling category moving from base to the recycler mod.

## Validating a 2.0 build

`factorio-validate`'s `validate.ps1` takes `-FactorioPath`, so it runs against any install:

```powershell
.\validate.ps1 -ModPath <legacy-path>\<mod> -FactorioPath "<2.0 install>"
```

Install paths are in `CLAUDE.local.md`. This machine has two 2.0.77 standalone installs — one
with Space Age, one vanilla — which between them cover both configurations our mods support. Use
the vanilla install, or `-Disable space-age quality`, for the no-expansion path.

A standalone (zip) install keeps its write-data in its own folder rather than
`%APPDATA%\Factorio`; the script detects that and switches itself to scratch-folder mode, so the
2.0 run never writes into the install and never collides with a running 2.1 game.

Exit 0 proves the data stage loads. It says nothing about classes 2 and 3.

## Diffing the dumps

`scripts/compare-dumps.py` compares one mod's prototypes across two `--dump-data` runs and
prints every property that differs, appears or vanishes. It is how class 2 gets caught.

```powershell
.\validate.ps1 -ModPath <mod> -KeepDump                        # 2.1, Steam install
Move-Item "$env:TEMP\data-raw-dump-<mod>.json" dump-2.1.json
.\validate.ps1 -ModPath <legacy>\<mod> -FactorioPath "<2.0 install>" -KeepDump
Move-Item "$env:TEMP\data-raw-dump-<mod>.json" dump-2.0.json
python scripts\compare-dumps.py dump-2.0.json dump-2.1.json --prefix <mod-prefix>
```

Read the output with the engine in mind — not every difference is yours. Pure Modules' diff is
entirely recycling recipes that the *quality* mod generated from our recipes: `category` became
`categories` in 2.1 and the returned amounts round differently. Nothing to port. What matters is
a property present on one side and `<absent>` on the other **inside a prototype the mod itself
authors**.

## Changelog across two tracks

Each zip carries its own `changelog.txt` and a player only ever sees the one they installed, so
the legacy branch's file is the legacy track's history: its own `1.0.x` sections plus the shared
history from before the split. Do not paste `1.1.x` sections into it — a player on 2.0 cannot
install those, and the numbers would read as a downgrade.

A backported fix earns an entry on both tracks, worded the same, under each track's own version
number. Format rules are unchanged: see `factorio-changelog`.

## Sharing code between the tracks

The branch model means most files can simply stay identical. When one file genuinely has to
serve both — a shared prototype table where a single property is version-gated — branch on the
base mod's version instead of forking the file:

```lua
-- data stage: `mods` maps every enabled mod to its version, base included
local major, minor = mods["base"]:match("^(%d+)%.(%d+)")
if tonumber(major) * 100 + tonumber(minor) >= 201 then
  module.consumption_quality_multiplier = 0
end
```

At runtime the same fact is `script.active_mods["base"]`. `feature_flags` works as a version
probe too, since flags accumulate over time — `feature_flags["expansion"]` is 2.1-only and reads
as `nil` on 2.0, which is safe to test.

Reach for this only where a fork would mean duplicating a whole file over one line. Two branches
differing in one guarded block each are easier to cherry-pick between than two branches
differing everywhere.

## Deciding not to backport

Say so plainly and move on. A backport is not worth it when the mod leans on 2.1-only prototype
properties for its core behaviour, when the port would change balance rather than plumbing, or
when nothing available can validate it. Ship 2.1, record the decision in the mod's `CLAUDE.md`
under Decided, and revisit when 2.1 goes stable — at which point the question disappears.

## Reference

- `references/2.1-breaking-changes.md` — every removal, rename, move and behaviour change from
  2.0 to 2.1, extracted from the game's own changelog. Read it before backporting anything.
