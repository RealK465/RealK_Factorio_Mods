---
name: factorio-testing
description: Use when running, writing, or debugging automated tests for a mod in this repo —
  the factorio-test in-game suite (headless or graphics), the pure host-Lua tier for
  geometry modules, or the static tier (luacheck + emmylua_check against fmtk-generated API
  types); also when adding specs to a mod, wiring a new mod for testing, choosing which tier
  a behaviour belongs in, or anything mentioning "run the tests", spec files, tags, or CI for
  mods. The machinery here was proven the hard way — bundled-save migration dialogs, Windows
  spawn quirks, phantom-connected players — so read this instead of re-deriving the runner
  invocations, and invoke it BEFORE writing test code, because several failure modes are
  silent or cost a stuck game window.
---

# Factorio testing — the three tiers

Upcycler Planner is the reference implementation; its `tests/` folder is the shape to copy.
Everything below was measured on 2.1.14 with factorio-test 3.1.0 and CLI 3.6.0 (2026-08-16).

**Suites are per-mod opt-in** — a mod without `tests/` is not required to gain one. Where one
exists, the cadence is checkpoints, not every edit: headless before wrapping up a session that
changed runtime code and before asking for a commit; the graphics pass at releases
(`factorio-release` step 3). Testing is a gate on the way out, never the loop's tax.

| Tier | Runs | Proves | Speed |
|---|---|---|---|
| **In-game** (factorio-test) | real engine, headless `--benchmark` or graphics | everything: prototypes, force state, ghosts, ticks, GUI handlers | ~15 s |
| **Pure** (host Lua) | plain interpreter, no game | the pure geometry modules only | < 1 s |
| **Static** (luacheck + emmylua_check) | no execution at all | undefined globals, misspelled API members | ~5 s |

The community consensus the research landed on, and this repo's rule: **don't mock what you
can run; extract what you can compute.** Nothing here mocks `game` or `prototypes` — the
engine is fast enough to just run, and every mocking framework in the ecosystem is dead.

## Running

```powershell
# The whole in-game suite, headless. Exit 0 only if every test passed.
.\.claude\skills\factorio-testing\scripts\run-tests.ps1 -ModPath <mod>

# A subset, by Lua pattern (escape - as %-):
.\...\run-tests.ps1 -ModPath <mod> -Filter 'planner'

# The same suite through a real client window -- opens the game, runs, closes itself:
.\...\run-tests.ps1 -ModPath <mod> -Graphics

# Pure tier (sub-second; any lua on PATH -- scoop's 5.5 today):
lua .\.claude\skills\factorio-testing\scripts\pure-runner.lua <mod> <mod>\tests\pure\<spec>.lua ...

# Static tier (luacheck + emmylua_check; -RegenerateTypedefs after a game-version move):
.\.claude\skills\factorio-testing\scripts\check-static.ps1 -ModPath <mod>
```

The runner self-locates the dev install exactly like `validate.ps1` (five hops up from
`scripts/`; `$env:FACTORIO_PATH` overrides; throws rather than hunting). Data lands in
`%LOCALAPPDATA%\factorio-testing\<mod>` — never in the repo, never in any install, and the
portal download that seeds the framework mod authenticates with the **dev install's**
`player-data.json`, never `%APPDATA%\Factorio`.

## Wiring a mod for testing

1. Spec files live in `<mod>/tests/`, pure ones in `<mod>/tests/pure/`, shared helpers in
   `<mod>/tests/support/`. Add **`"tests/**"` to `package.ignore`** — a bare `"tests"` glob
   matches nothing and `fmtk package` would ship the suite to every player, silently.
2. Register the files in `control.lua`, guarded so players never load any of it:

   ```lua
   if script.active_mods["factorio-test"] then
     script.on_init(function()
       state.init()  -- whatever the mod's real on_init does
       -- The graphics tier loads a --create save; freeplay's intro dialog and crash-site
       -- cutscene would otherwise block the first join waiting for a click.
       if remote.interfaces["freeplay"] then
         remote.call("freeplay", "set_skip_intro", true)
         remote.call("freeplay", "set_disable_crashsite", true)
       end
     end)
     require("__factorio-test__/init")({ "tests.my_spec", ... })
   end
   ```

   The guard **replaces** the mod's own `on_init` registration (one handler per event per
   mod), so it must call the real init itself. `factorio-test` never goes in `info.json`
   `dependencies` — the runner stages it.
3. Never leave a registered spec file empty — the framework treats "No tests defined" as an
   error, which is what stops a file from being silently skipped. `test.todo("...")` is the
   placeholder.

## Writing specs

The API is the busted family: `describe`/`test`, `before_all`/`after_each`, `after_ticks(n,
fn)` for behaviour that unfolds over ticks, plain `assert(cond, message)`. Facts that bite:

- **Spec files are required at control.lua load time — `game` does not exist yet.** Anything
  needing runtime state goes inside a test or hook, never at file top level.
- **`tags("x")` marks the NEXT block defined**, so it goes on the line *above* `describe`,
  not inside it. Filter runs with `--tag-whitelist`/`--tag-blacklist` or a name pattern.
- **Research states persist across tests in one run.** Every describe sets its own state
  (`tests/support/research.lua` in the reference mod wraps `force.reset()`,
  `research_all_technologies()`, named-tech sets, `enable_all_recipes()`).
- **A headless run has a connected player.** A singleplayer save's player stays flagged
  connected under `--benchmark`, and the CLI's bundled save is one — cursor, `gui.screen`
  and mod-setting reads all work headless (measured 2.1.14). GUI handlers are driven
  without clicks: mutate the real widget through the API, then call the mod's dispatcher
  with a hand-shaped `{ element = ..., player_index = ... }`. Only the click-to-event wiring
  itself stays untestable (no input faking exists).
- **`{ field = nil }` is an empty table** — an overrides helper needs a remove-sentinel.
- Read-back surprises: `LuaEntity.get_filter()` returns the name as a **string**; ghost
  poles **auto-preview-connect** on top of scripted wires (assert network connectivity, not
  edge counts); `defines.inventory.crafter_input`/`crafter_output` are the 2.1 names for
  furnace-style inventories too.
- Pure specs may use only `describe`, `test`, `defines.direction` and standard Lua — the
  host runner fails loudly on anything else, which is the moment a spec stopped being pure.
  They are registered in the in-game list too, so interpreter drift shows as a split verdict.

## The graphics tier

`-Graphics` exists for real-client verification. Three facts make it work unattended:

- The CLI's bundled save is 2.0-era; a graphics load of it shows the **migration dialog**
  and waits for a click. The runner therefore creates a fresh save at the installed version
  with the exact mod set, every run.
- Freeplay's intro furniture blocks the first join — the `set_skip_intro` /
  `set_disable_crashsite` calls in the wiring above are what disarm it, baked in at save
  creation.
- Graphics mode is interactive by design: the CLI never closes the window. The runner
  watches the log for the framework's `Test run finished:` marker, then closes the game —
  killing only processes whose path is under the dev install, so no other Factorio instance
  can ever be touched. The verdict comes from the marker, not the CLI's exit code, which
  the kill interrupts. `-KeepOpen` skips the close for interactive debugging.

## Static tier

`.luacheckrc` and `.emmyrc.json` live at the repo root (tracked dotfiles, never packaged).
Type definitions are generated from the installed `doc-html` JSONs by `fmtk docs` into this
skill's `typedefs/` (git-ignored — regenerate, never commit), and
`meta/factorio-test.lua` (tracked, hand-written) covers the test framework's globals. The
emmylua config must reach the library at `typedefs/factorio/library` — the bundle root is an
addon wrapper, not the library. emmylua_check **errors** fail the run; its warnings
(nilability pedantry on untyped code) print and pass. luacheck fails on any finding.

## Windows plumbing the runner owns (so nobody re-debugs it)

- The CLI shells out to `npx fmtk` with a bare `spawn("npx")` — unresolvable on Windows
  since npm ships no `npx.exe`. A scoop shim (`node.exe` + `npx-cli.js`) makes one; the
  runner creates it when missing. Worth an upstream report to GlassBricks.
- `--mods` must name the full expansion set explicitly; on 2.1 `quality` hard-requires
  `recycler`, and a mod-list written by a previous run makes half-enabled sets fail loudly.
- npm's `factorio-test` on PATH is a `.ps1` shim; `Start-Process` needs the `.cmd` sibling.
- Native tools writing progress to stderr become terminating errors under
  `$ErrorActionPreference = 'Stop'` plus redirection — relax around native calls and judge
  by `$LASTEXITCODE`.

## The 2.0 track

Untested there so far, but prepared: the runner keys its data dir per install and trims
`recycler` from the default mod set when the install ships no `data\recycler` (2.0, where
the entity lives inside `quality`). The legacy worktree's own copy of this skill self-locates
to the 2.0 install, exactly like `validate.ps1`, and `check-static.ps1` regenerates 2.0.77
typedefs there on first run. The remaining legacy-session checklist, in order:

1. The suite must be committed on `main` first; it reaches `legacy/2.0` by cherry-pick.
2. **Fork `tests/loop_spec.lua` on the legacy branch** — it uses
   `defines.inventory.crafter_input`/`crafter_output`, which are 2.1 names (2.0 has the
   `furnace_*` pair) — and add it to the divergent-files list in the repo `CLAUDE.md` → Git.
   Never version-gate it in `main`'s copy.
3. Run from the worktree and read the first run honestly. Expected discoveries: fmtk should
   seed the 2.0-compatible framework (3.0.x) by itself — verify the CLI accepts it; the
   "185 upcyclable items" count may differ on 2.0 (eligibility flows through the mod-data
   bridge there) — measure, and fork that assertion if so; confirm the bundled save's
   connected player and `tags()` behave the same on framework 3.0.x.
4. `factorio-multiversion` governs the branch mechanics throughout.
