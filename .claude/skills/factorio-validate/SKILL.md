---
name: factorio-validate
description: Use to verify a Factorio mod's data stage actually loads — after editing prototypes or data.lua, before packaging a release, or when a mod fails to load, doesn't appear in game, or logs an error in factorio-current.log. Runs the game headless against an isolated mod directory using a bundled script, and can dump the resulting prototypes to confirm their final values. Prefer running it over reasoning about whether a prototype change is valid.
---

# Headless data-stage validation

Validate the data stage without launching the game and without touching the real `mod-list.json`.

```
<factorio-install>/bin/x64/factorio --dump-data --mod-directory <isolated-dir>
```

(`factorio.exe` on Windows. The install path for this machine is in `CLAUDE.local.md`.)

The isolated dir needs a copy of the mod under test plus a `mod-list.json`. **Exit code 0 = data stage loaded clean.**

**Never point `--mod-directory` at this repo.** The game rewrites `mod-list.json` in whatever directory it is given, and that file is off-limits here. Always stage into a scratch directory.

## Script

`validate.ps1` in this skill folder does the staging, the run and the cleanup:

```powershell
.\validate.ps1 -ModPath <path-to-mod-folder>
```

Options: `-FactorioPath <install root>` (defaults to the Steam location; override per machine), `-Disable <names>` to turn an expansion off for a compatibility check, `-KeepDump` to leave `data-raw-dump.json` in place for inspection, and **`-Live` to run with the game open** (see below).

It reads `name` and `version` out of `info.json`, checks the folder name matches, copies the folder into a scratch dir under `%TEMP%`, writes a `mod-list.json`, runs the game, extracts the error lines on failure, and cleans up. Takes about 5 seconds.

Three things the script exists to get right, all found by testing it:

- **`mod-list.json` must be BOM-free.** `Out-File -Encoding utf8` in PowerShell 5.1 writes a BOM; Factorio then rejects the file and silently loads its own defaults instead — so the mod under test never loads and the run passes for the wrong reason.
- **`factorio.exe` is a GUI-subsystem binary.** The PowerShell call operator neither waits for it nor sets `$LASTEXITCODE`. Use `Start-Process -Wait -PassThru` and read `.ExitCode`.
- **Exit 0 does not mean the mod loaded.** A folder name that doesn't match `info.json`, or a mod-list the game rejected, both produce a clean exit with the mod skipped entirely. Confirm `Checksum of <name>:` appears in the log — the script does this and turns a silent skip into a failure.

Expansions load from the game install whether or not `mod-list.json` names them, so they only need listing to turn one **off**.

## Close the game first

A running Factorio holds `%APPDATA%\Factorio\.lock`, and the headless run then dies with:

```
Error Util.cpp:81: Couldn't create lock file ...\.lock: 32.
Is another instance already running?
```

Exit code 1, so the script reports a failed data stage — but **this is an environment failure,
not a mod error**, and the mod was never loaded at all. Check for a running `factorio` process
before believing a failure that mentions the lock file.

### Or move the lock: validating with the game open

The lock lives in the **write-data** folder, not the mod folder, and a config
file can move it. This validates while Factorio is running (verified
2026-08-06, exit 0 with `Checksum of pure-modules-realk:` in the log):

```ini
; scratch config.ini
[path]
read-data=C:\Program Files (x86)\Steam\steamapps\common\Factorio\data
write-data=<scratch dir>
```

```
factorio.exe --config <scratch>\config.ini --mod-directory <scratch>\mods --dump-data
```

`--mod-directory` still needs its own staged copy plus a BOM-free
`mod-list.json`, exactly as the script builds.

**`validate.ps1 -Live` does all of this for you** — it writes the scratch
`config.ini`, points `write-data` at a temp folder, and reads the log and the
dump from there. Verified 2026-08-06 with Factorio open: exit 0 and
`Checksum of pure-modules-realk:` present, on both the full-expansion and the
base-only run.

Two reasons to reach for it even when the game is closed: nothing is written to
the real user-data folder, so `data-raw-dump.json` never has to be cleaned up
there (with `-KeepDump` it is moved to `%TEMP%\data-raw-dump-<name>.json`
before the scratch folder is removed), and the run cannot disturb the live
install at all. The default path is unchanged and still writes to
`%APPDATA%\Factorio`.

When the default path fails on the lock, the script now says so explicitly and
points at `-Live` rather than leaving it to be diagnosed.

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

## Validating against another game version

`-FactorioPath` points the run at any install, which is how a 2.0 backport gets validated while
this machine's Steam install is on 2.1. The 2.0 installs on this machine are listed in
`CLAUDE.local.md`; the workflow around them is the `factorio-multiversion` skill.

Standalone (zip) installs keep their write-data in the install folder rather than
`%APPDATA%\Factorio`, so the log this script reads would be the *Steam* install's stale one —
a failed run reported as a pass. The script detects those (`config-path.cfg` →
`use-system-read-write-data-directories=false`) and switches itself to `-Live` scratch mode,
which also keeps the run from writing anything into that install. Verified 2026-08-06 against
both 2.0.77 standalone installs, exit 0 with the checksum line present.

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

`--dump-data` also writes `data-raw-dump.json` (28 MB, measured) into the user-data folder's `script-output/`. Parse it to confirm the *resulting* prototype values rather than trusting the source — useful when a prototype is assembled by `table.deepcopy` plus edits, or when another mod's `data-final-fixes` may have changed it. Grep or query for the specific prototype; don't read it whole.

Delete the dump afterwards. It matches `.gitignore`, so it will not be committed, but it is 28 MB of churn in the user-data folder.

## What this does and does not prove

A clean data stage means the prototypes are structurally valid and every **prototype reference** resolves — a recipe naming an item that doesn't exist fails loudly, with the exact `ROOT.recipe.<name>.ingredients[0].name` path.

It says **nothing** about:

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

Errors surface in `factorio-current.log`, in the same user-data folder as `mods/`. The script prints the last error lines; read the log for the full context. Common causes: a folder name that doesn't match `info.json`, a dependency floor no installed mod satisfies, a `require` path that resolves against the wrong mod, or a prototype naming something that doesn't exist.
