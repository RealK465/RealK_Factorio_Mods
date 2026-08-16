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
| Lives in | the 2.1 install's `mods/` | the 2.0 install's `mods/` |
| `factorio_version` | `"2.1"` | `"2.0"` |
| `base` dependency | `base >= 2.1.0` | `base >= 2.0.0` |
| Version band | `<major>.1.x` | `<major>.0.x` |
| Validated against | a 2.1 install | a 2.0 install |

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

**The worktree lives in the 2.0 dev install's own `mods/`** — the exact mirror of what `main` is
in the 2.1 install, so the 2.0 build is *live* and can be launched and played, not merely
validated. The path is in `CLAUDE.local.md`.

That makes the worktree a live mod folder too, so the game writes `mod-list.json` and
`mod-settings.dat` into it. Both are already in `.gitignore`, which is shared across branches —
don't "fix" a `git status` that shows them.

```bash
git worktree add <legacy-path> legacy/2.0     # first time; add -b to create the branch
cd <legacy-path>
git cherry-pick <commit-from-main>            # expect conflicts in info.json / changelog.txt
```

`git worktree add` wants the target either absent or an empty directory. A game install's fresh
`mods/` already contains a `mod-list.json`, so move that aside first and let the game rewrite it.

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

Install paths are in `CLAUDE.local.md`. This machine has four standalone installs — 2.1 and 2.0,
each in a Space Age and a vanilla flavour — which between them cover every configuration our
mods support. Use the matching vanilla install, or `-Disable space-age quality`, for the
no-expansion path; the vanilla install is the stronger of the two, since `-Disable` only
switches expansion data off rather than removing it.

**Which `validate.ps1` you invoke decides the game — not which mod you point it at.** The script
resolves the install four levels above *itself*, so:

```powershell
# From inside the legacy worktree: self-locates to the 2.0 install. No flag needed.
cd <legacy-worktree>
.\.claude\skills\factorio-validate\validate.ps1 -ModPath .\<mod>

# From the main repo, pointed at a legacy mod: self-locates to the 2.1 install.
# WRONG GAME - and it exits 0, so it reads as a pass.
.\.claude\skills\factorio-validate\validate.ps1 -ModPath <legacy-worktree>\<mod>   # no
```

Each worktree carries its own copy of the skill, sitting in its own install, so **using the
script next to the mod is the whole discipline** — `-FactorioPath` is then only for reaching a
*third* install, such as the vanilla one. Verified 2026-08-15: run from the 2.0 worktree with no
flag, exit 0 against `base 2.0.77` with `Checksum of pure-modules-realk` present.

Whichever way it is invoked, read the `Install:` line it prints and confirm the `base` version
before believing the result.

A standalone (zip) install keeps its write-data in its own folder rather than a system directory;
the script detects that and switches itself to scratch-folder mode, so the 2.0 run never writes
into the install and never collides with a running game.

Exit 0 proves the data stage loads. It says nothing about classes 2 and 3.

## Diffing the dumps

`scripts/compare-dumps.py` compares one mod's prototypes across two `--dump-data` runs and
prints every property that differs, appears or vanishes. It is how class 2 gets caught.

Run each side with **its own** worktree's script, so each self-locates to its own install. Both
runs write `%TEMP%\data-raw-dump-<mod>.json`, so the `Move-Item` between them is not optional —
skip it and the second run overwrites the first, and the diff comes out empty and looks like
"nothing changed".

```powershell
<main-repo>\.claude\skills\factorio-validate\validate.ps1     -ModPath <main-repo>\<mod> -KeepDump
Move-Item "$env:TEMP\data-raw-dump-<mod>.json" dump-2.1.json
<legacy-worktree>\.claude\skills\factorio-validate\validate.ps1 -ModPath <legacy-worktree>\<mod> -KeepDump
Move-Item "$env:TEMP\data-raw-dump-<mod>.json" dump-2.0.json
python scripts\compare-dumps.py dump-2.0.json dump-2.1.json --prefix <mod-prefix>
```

Read the output with the engine in mind — not every difference is yours. Pure Modules' diff is
entirely recycling recipes that the *quality* mod generated from our recipes: `category` became
`categories` in 2.1 and the returned amounts round differently. Nothing to port. What matters is
a property present on one side and `<absent>` on the other **inside a prototype the mod itself
authors**.

## Changelog across two tracks

**One changelog serves both tracks, kept identical on `main` and `legacy/2.0`.** It lists every
released version of the mod, newest first, whichever game each targeted, and every section names
its game.

That is forced by the portal rather than chosen for tidiness. `GET /api/mods/<name>/full`
returns a **single** top-level `changelog` field and no per-release one, so the website's
changelog page is one release's file — the newest uploaded. Anything written only into the other
track's copy reaches nobody but the players already running that build. Verified 2026-08-07:
after Pure Modules shipped 1.0.4 (Factorio 2.0) and 1.0.5 (Factorio 2.1), the public page listed
1.0.5, 1.0.3, 1.0.1 and 1.0.0 — both 2.0-track sections absent, and with them the only
description of what 1.0.4 changed.

So `changelog.txt` belongs with `CLAUDE.md` and `README.md` in the set kept identical across the
branches, not with the files a port legitimately forks. When a release ships on one track, write
its section into **both** branches in the same change.

### Shipping one change to both games

The usual case: work that is not version-specific goes out on both tracks, as **two releases and
two sections — both of which live in the one shared file.**

1. **Release the 2.0 build first, on the lower number.** Its section describes the work — the
   full entries, in the usual categories.
2. **Then bump and release the 2.1 build.** Its section does not repeat those entries; it
   records what that release is and leans on the section below it, which is in the same file:

   ```
   ---------------------------------------------------------------------------------------------------
   Version: 1.0.5
   Date: 2026-08-07
     Changes:
       - Version 1.0.4, ported to Factorio 2.1.
   ---------------------------------------------------------------------------------------------------
   Version: 1.0.4
   Date: 2026-08-07
     Balancing:
       - <the actual work, in the usual categories>
   ```

**Two ways this goes wrong, and this repo has now shipped both.**

- **Copying the entry list into both sections.** Pure Modules 1.0.2 / 1.0.3, 2026-08-07 — four
  identical `Graphics:` entries, differing only in the trailing line. The duplicate reads as
  though the work were done twice, and the two copies drift the moment either is edited.
- **Keeping each section only in its own track's file.** Pure Modules 1.0.4 / 1.0.5, the same
  day. The pointer shipped in the file the portal renders and the detail shipped in the file it
  does not, so the public changelog announced a release that appeared to change nothing. This is
  the worse of the two: the first repeats information, this one loses it.

Both pairs are published and cannot be corrected. The shape above is what avoids each — one
file, two sections, exactly one of them carrying the entries.

**Anything genuinely exclusive to one track still earns a real entry there**, alongside the
pointer. Pure Modules 1.0.1 is the worked example: it points back at 1.0.0 for Factorio 2.1
*and* records the flat-quality-penalty feature, which only the 2.1 build has.

### A fix that reaches the tracks separately

Different case, opposite rule. A fix released on 2.1 and **backported weeks later** is two
unrelated events, and both sections carry the entry, worded the same, under each track's own
version number. The test is whether the two releases are a pair going out together or two
separate pieces of news.

Format rules are unchanged: see `factorio-changelog`.

## Sharing code between the tracks

**This repo forks; it never gates.** The repo owner's standing call (2026-08-16, from the
upcycler-planner port): `main` carries no 2.0 code — no base-version branches, no `mods[...]`
presence probes, no compat shims, however small a helper. The 2.0 track is temporary, and gated
code would sit in `main` confusing readers long after 2.1 goes stable and the track stops. A
backport is therefore forked copies of the affected files on `legacy/2.0`, with the
divergent-file list declared in `CLAUDE.md` → *Git* — Pure Modules and Upcycler Planner are the
worked examples — and a cherry-pick that touches a forked file is rewritten by hand, never
merged blind.

For recognising the gating pattern in *other people's* mods (never for adding it here): the
data stage branches on `mods["base"]`, matching major/minor out of the version string; at
runtime the same fact is `script.active_mods["base"]`; and `feature_flags` doubles as a version
probe, since flags accumulate — `feature_flags["expansion"]` is 2.1-only and reads as `nil` on
2.0.

## Deciding not to backport

Say so plainly and move on. A backport is not worth it when the mod leans on 2.1-only prototype
properties for its core behaviour, when the port would change balance rather than plumbing, or
when nothing available can validate it. Ship 2.1, record the decision in the mod's `CLAUDE.md`
under Decided, and revisit when 2.1 goes stable — at which point the question disappears.

## Reference

- `references/2.1-breaking-changes.md` — every removal, rename, move and behaviour change from
  2.0 to 2.1, extracted from the game's own changelog. Read it before backporting anything.
