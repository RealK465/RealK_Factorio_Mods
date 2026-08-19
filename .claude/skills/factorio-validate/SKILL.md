---
name: factorio-validate
description: Use to verify a Factorio mod's data stage actually loads — after editing prototypes or data.lua, before packaging a release, or when a mod fails to load, doesn't appear in game, or logs an error in factorio-current.log. Runs the game headless against an isolated mod directory using a bundled script, can dump the resulting prototypes to confirm their final values, and can lint for prototype properties the engine silently ignored. Prefer running it over reasoning about whether a prototype change is valid.
---

# Headless data-stage validation

Validate the data stage without launching the game and without touching the real `mod-list.json`.

```
<factorio-install>/bin/x64/factorio --dump-data --mod-directory <isolated-dir>
```

(`factorio.exe` on Windows. The install path for this machine is in `CLAUDE.local.md`.)

The isolated dir needs a copy of the mod under test plus a `mod-list.json`. **Exit code 0 = data stage loaded clean.**

**Never point `--mod-directory` at a real mods folder — this repo included.** The game rewrites `mod-list.json` in whatever directory it is given, disabling every mod it does not find there. Always stage into a scratch directory.

## Script

`validate.ps1` in this skill folder does the staging, the run and the cleanup:

```powershell
.\validate.ps1 -ModPath <path-to-mod-folder>
```

Options: `-FactorioPath <install root>`, `-Disable <names>` to turn an expansion off for a compatibility check, `-KeepDump` to leave `data-raw-dump.json` in place for inspection, and `-Live` for scratch write-data — which switches itself on here and is described below only so its output makes sense.

**`-FactorioPath` resolves itself and rarely needs passing.** The script takes `$env:FACTORIO_PATH` if set, else **the install this repo lives in** — four levels above the script, since the repo is a dev install's `mods/` folder. If neither has a `bin\x64\factorio.exe` it throws; it deliberately does **not** go hunting for some other install, because the one it would find is the one being played and a wrong-install run exits 0 looking like a pass. It prints the install it chose and that install's `base` version on every run:

```
Install: ...\Factorio 2.1 SA Experimental (base 2.1.14)
```

Read that line. Validating a 2.1 mod against a 2.0 install, or against one with a different expansion set, exits 0 and proves nothing — and nothing else in the output would tell you.

It reads `name` and `version` out of `info.json`, checks the folder name matches, copies the folder into a scratch dir under `%TEMP%`, writes a `mod-list.json`, runs the game, extracts the error lines on failure, and cleans up. Takes about 5 seconds.

Three things the script exists to get right, all found by testing it:

- **`mod-list.json` must be BOM-free.** `Out-File -Encoding utf8` in PowerShell 5.1 writes a BOM; Factorio then rejects the file and silently loads its own defaults instead — so the mod under test never loads and the run passes for the wrong reason.
- **`factorio.exe` is a GUI-subsystem binary.** The PowerShell call operator neither waits for it nor sets `$LASTEXITCODE`. Use `Start-Process -Wait -PassThru` and read `.ExitCode`.
- **Exit 0 does not mean the mod loaded.** A folder name that doesn't match `info.json`, or a mod-list the game rejected, both produce a clean exit with the mod skipped entirely. Confirm `Checksum of <name>:` appears in the log — the script does this and turns a silent skip into a failure.

Expansions load from the game install whether or not `mod-list.json` names them, so they only need listing to turn one **off**.

## The lock, and why it never bites here

A running Factorio holds a `.lock` in its **write-data** folder, and a second run against the
same install dies with:

```
Error Util.cpp:81: Couldn't create lock file ...\.lock: 32.
Is another instance already running?
```

Exit code 1, so the script reports a failed data stage — but **this is an environment failure,
not a mod error**, and the mod was never loaded at all.

**On this setup it cannot happen.** The lock follows write-data, not the mod folder, so a
scratch `config.ini` relocating write-data moves the lock with it:

```ini
; scratch config.ini
[path]
read-data=<factorio-install>\data
write-data=<scratch dir>
```

```
factorio.exe --config <scratch>\config.ini --mod-directory <scratch>\mods --dump-data
```

`validate.ps1 -Live` writes exactly that, points `write-data` at a temp folder, and reads the
log and the dump back from there — and **against a standalone install it switches itself on**,
so the flag never has to be typed. Verified 2026-08-06, exit 0 with
`Checksum of pure-modules-realk:` present on both the full-expansion and the base-only run.

Two things this buys beyond the lock: nothing is written into the install, so `data-raw-dump.json`
never has to be cleaned up there (with `-KeepDump` it lands at `%TEMP%\data-raw-dump-<name>.json`),
and a run cannot disturb the install at all.

`-Live` is therefore vestigial in normal use. It exists for an install that keeps its write-data
in a system directory, which nothing here does — and if a run ever *does* fail on the lock, the
script says so explicitly rather than leaving it to be diagnosed.

## Settling a question with a throwaway mod

When the question is *how the loader behaves* rather than *is this prototype
valid*, do not reason about it and do not trust a note in a CLAUDE.md — write a
five-line mod and run it. It takes about a minute end to end, and two
long-standing rules in this repo turned out to be wrong when finally tested this
way (whether `require("__base__...")` works, and whether `require` caches by
string or by file).

```
<scratch>/reqtest/info.json     name, version, factorio_version, dependencies: ["base"]
<scratch>/reqtest/data.lua      pcall(require, ...) + log(...) the result
```

Then `validate.ps1 -ModPath <scratch>/reqtest -Live` and read the `Script @__reqtest__/data.lua`
lines out of the log. `log()` output appears there in headless runs, `pcall`
turns a failure into a readable value instead of aborting the run, and a global
counter incremented at module scope proves whether a file executed once or
twice. Delete the mod afterwards.

## Map generation: this skill does not cover it at all

**A clean `--dump-data` says nothing about a noise expression.** They compile when *map generation
settings* change, which headless validation never does, so a malformed `probability_expression`
validates clean and fails at world creation. Two harnesses cover the gap, and they answer
different questions — the first was reporting a perfect score on a mod that was deleting cliffs.

**Sampling the fields — `surface.calculate_tile_properties(names, positions)`.** Evaluates *any*
named noise expression at any list of positions, so a probe mod calling it from `on_init` plus
`factorio.exe --create <save> --map-gen-seed <n>` dumps a grid of every intermediate in seconds
(640,000 points across ~12 named expressions, about 12 s measured on 2.1.14). Notes:

- It takes **named expressions**, not just documented tile properties — including a mod's own, and
  including hyphenated ones like `default-iron-ore-patches`. Unrecognised names are silently
  skipped, so count what came back rather than assuming.
- Declaring several *variants* as named expressions in the probe mod turns one run into a whole
  parameter sweep, without touching the mod under test.
- `helpers.write_file` builds the path verbatim, so a name containing `:` (e.g.
  `entity:iron-ore:probability`) fails on Windows with `Invalid argument`. Sanitise the filename.

**Checking the consequences — generate the world twice and diff the entities.** Run map generation
with the feature on and with its autoplace control set to `size = 0`, record every entity of the
types that matter, and compare the sets. This is the only thing that answers *"does this destroy
anything the player would otherwise have had"*, because a tile that blocks placement does not
error — the cliff or the ore patch simply never appears. Measured worth: a field-level check
reported zero overlaps on a map where the diff found 21 cliffs missing. Compare against **unmodded
vanilla** as well as against the feature switched off; the two are not the same claim.

**Seeing the world — automated screenshots need `--benchmark-graphics`.** Plain `--benchmark`
runs headless: a probe mod's `game.take_screenshot` silently writes nothing while its
`helpers.write_file` output appears, which looks exactly like a screenshot bug and is not.
`--benchmark-graphics <save> --benchmark-ticks N` runs the same save with the renderer, ticks
events normally, and exits — a probe mod that generates chunks, finds the feature, screenshots it
and calls `game.set_wait_for_screenshots_to_finish()` turns it into a headless-ish visual
harness. Three Windows facts, each measured the hard way (2.1.14):

- **Graphics modes run fine here, and that is not universal.** A DRM-free standalone install
  launches a graphics mode whatever else is running; a Steam build refuses while its own game is
  open, exiting instantly with *no log written* because the failure precedes logging. The dev
  installs are standalone, so the constraint does not apply — but it is worth knowing that
  "exited immediately and wrote no log" has a cause other than a broken probe mod. Headless
  modes (`--dump-data`, `--create`, `--benchmark`, `--generate-map-preview`) are unaffected
  either way.
- **`factorio.exe` is a GUI-subsystem executable**: PowerShell's `&` returns immediately without
  waiting and `$LASTEXITCODE` stays null. Use `Start-Process -Wait -PassThru`.
- **`--map-preview-scale` no longer exists in 2.1** — an unknown option prints the help text and
  exits 1 without a log. `--generate-map-preview PATH --map-preview-size N` is the surviving
  form, renders the true per-tile map colours in under a second, and is the cheap way to judge a
  tile's `map_color` against real terrain: composite candidate recolours onto one render instead
  of re-running the game per candidate.

## Validating against another game version

`-FactorioPath` points the run at any install, which is how a 2.0 backport gets validated while
the default install is on 2.1, and how a no-expansion build gets checked against an install
that genuinely does not ship the expansions. The installs on this machine — and which one each
question belongs to — are listed in `CLAUDE.local.md`; the 2.0 workflow is the
`factorio-multiversion` skill.

**A vanilla install is a stronger check than `-Disable`.** `-Disable` leaves the expansion data
sitting in the install and merely switches the mods off; a base-only install does not ship it at
all. Use `-Disable` for the quick pass, and a vanilla install to settle a question about what a
player without Space Age actually gets.

Standalone (zip) installs keep their write-data in the install folder rather than a system
directory like `%APPDATA%\Factorio`, so the log this script reads would otherwise be some
*other* install's stale one — a failed run reported as a pass. The script detects those
(`config-path.cfg` → `use-system-read-write-data-directories=false`) and switches itself to
`-Live` scratch mode, which also keeps the run from writing anything into that install.
Verified 2026-08-06 against both 2.0.77 standalone installs, exit 0 with the checksum line
present. **This is also why the default run needs no flags when the repo lives in a standalone
dev install** — the same detection fires on it.

Remember what a green run on the other version does *not* prove: the data stage ignores
properties it does not recognise, so anything version-only loads clean and does nothing.
`factorio-multiversion` covers the dump-diff that catches it.

## Validate every branch, not just the happy one

A mod whose data stage reads `mods["space-age"]`, `mods["quality"]` or a startup setting is
really several mods, and one run only ever exercises one of them. Each branch needs its own
run with `-Disable`, or a whole configuration ships untested — including the case where a
prototype references an item that only exists in an expansion.

```powershell
.\validate.ps1 -ModPath <mod>                                          # everything on
.\validate.ps1 -ModPath <mod> -Disable space-age,quality,elevated-rails,recycler
```

The dump is the way to confirm the branch actually took: prototypes present in one run and
absent in the other, prerequisites and ingredients differing as intended. A clean exit proves
only that whichever branch ran was structurally valid.

## Inspecting the result

`--dump-data` also writes `data-raw-dump.json` (28 MB, measured) into the user-data folder's `script-output/` — which is the install root for a standalone build, and the scratch folder whenever the script is in `-Live` mode (with `-KeepDump` it lands at `%TEMP%\data-raw-dump-<name>.json` instead). Parse it to confirm the *resulting* prototype values rather than trusting the source — useful when a prototype is assembled by `table.deepcopy` plus edits, or when another mod's `data-final-fixes` may have changed it. Grep or query for the specific prototype; don't read it whole.

Delete the dump afterwards. It matches `.gitignore`, so it will not be committed, but it is 28 MB of churn in the user-data folder.

## Catching properties the engine silently ignores

Add **`--check-unused-prototype-data`** to the same run. It prints a warning for every
prototype value the loader never read, which is how a misspelled or misplaced property gets
found — the data stage does not reject an unknown key, it ignores it, so `max_healht = 999`
loads clean and does nothing forever.

```
factorio.exe --config <scratch>\config.ini --mod-directory <scratch>\mods \
  --dump-data --check-unused-prototype-data
```

```
Warning PrototypeLoader.cpp:200: Value ROOT.lamp.my-lamp.max_healht was not used.
Warning PrototypeLoader.cpp:200: Value ROOT.lamp.my-lamp.energy_usag was not used.
Warning PrototypeLoader.cpp:200: Value ROOT.lamp.my-lamp.bogus_field was not used.
   Finished checking unused prototype data in 0.022 seconds. Number of properties that were used: 702689
```

Measured on 2.1.14, 2026-08-08, all four expansions loaded:

- **It costs nothing** — 0.02–0.03 s on top of a run that already takes about 4 s.
- **Vanilla is silent.** base, space-age, quality, elevated-rails and recycler produce zero
  warnings between them, and so does `pure-modules-realk` (704,265 properties read, no
  output). There is no baseline noise to filter, so **any warning is the mod under test**.
- **It really fires**, verified with a throwaway mod carrying two misspellings of real
  properties and one invented field: three warnings, each naming the exact
  `ROOT.<type>.<prototype>.<property>` path.

Two things to know before trusting it:

- **The exit code stays 0.** These are warnings, not errors — a run full of them still
  reports success. Grep the log; do not read the exit code as an all-clear on this.
- **"Not accessed" is not identical to "invalid."** The check reports what the loader did not
  read in *this* configuration, so a property only consumed on some path could in principle
  surface on a `-Disable` run without being a mistake. Every warning seen so far has been a
  real error; treat one as a strong lead and confirm the spelling against
  `prototype-api.json` before changing anything.

**Not wired into `validate.ps1`** — pass the flag on a hand-built run for now. Worth turning
into a switch on the script once a mod is large enough to want it on every validation.

## Stage somewhere SHORT: MAX_PATH silently disables the mod

Windows still caps a path at **260 characters**, and a deep scratch directory
plus a mod's own `graphics/entity/<thing>/<thing>-N.png` goes over it easily.
The failure is loud but misleading — measured 2.1.14, 2026-08-19, at a staged
path of 266 characters:

```
Error AtlasBuilder.cpp:1378: File __my-graphics__/graphics/entity/thing/thing-E.png not found
Failed to load mods: ... Mods to be disabled: my-mod
```

The file is there, valid, and byte-identical to the one that loads fine from a
shorter path. **It only bites a graphics run**, because `--dump-data` never
opens a sprite file — so the same staging passes every headless check and then
disables the mod the moment a renderer starts. Stage to something like
`C:\sfshot` for any `--benchmark-graphics` work and the problem disappears.
The repo's own path (163 chars) is nowhere near the limit; it is the scratch
directory that pushes it over.

## What this does and does not prove

A clean data stage means the prototypes are structurally valid and every **prototype reference** resolves — a recipe naming an item that doesn't exist fails loudly, with the exact `ROOT.recipe.<name>.ingredients[0].name` path.

It says **nothing** about:

- **Whether every property you wrote was understood.** An unknown or misspelled key is
  ignored, not rejected, so the run is clean either way — unless you add
  `--check-unused-prototype-data`, above.
- **Graphics paths.** Sprites are not loaded in headless mode, so a missing or misspelled `icon` / `filename` passes clean. Verified: a non-existent icon path exits 0. Only the real game catches these.
- **The mod checksum, for art changes.** It is computed over what the data
  stage reads, so replacing a PNG leaves `Checksum of <name>:` byte-identical.
  A stable checksum is not evidence the art is unchanged, and the game reads
  sprites at startup — a running instance keeps showing the old ones until it
  restarts. The only test for art is the running game.
- runtime behaviour — `control.lua`, events, `storage` handling
- how anything looks in game
- whether the recipe/tech tree makes sense
- migrations, which only run against a real save

Placing the mod on a real map is still required before calling it done.

## When a load fails

Errors surface in `factorio-current.log`, in the same user-data folder as `mods/` — the install root for a standalone build, and a scratch folder under `%TEMP%` for any run the script put in `-Live` mode, which is all of them here. The script prints the last error lines; read the log for the full context. Common causes: a folder name that doesn't match `info.json`, a dependency floor no installed mod satisfies, a `require` path that resolves against the wrong mod, or a prototype naming something that doesn't exist.
