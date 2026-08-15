---
name: factorio-mod-development
description: Use when writing or changing the actual code of a Factorio mod — any Lua in data.lua / data-updates.lua / data-final-fixes.lua / control.lua or the files they require, authoring or deriving prototypes (entities, items, recipes, technologies), runtime scripting with storage, events and LuaEntity, mod settings read at either stage, GUIs, remote interfaces, commands, or cross-mod and expansion compatibility. Also use when a mod desyncs in multiplayer, breaks an existing save, costs UPS, misbehaves after a mod update, or needs debugging or profiling. Covers the Factorio-specific Lua environment and the runtime contract, both of which fail silently when broken, so read it before writing mod code rather than reasoning from general Lua knowledge.
---

# Factorio mod development — writing the Lua

Target is Factorio **2.1**. Everything here was checked against the installed version's own
`doc-html/` and `data/` (2.1.14 at time of writing; `CLAUDE.local.md` has the paths). Where a
claim comes from the community rather than Wube, it says so.

The theme of this file is the same as the rest of the skills in this repo: **Factorio's failure
mode is silence.** A desync, a duplicate event registration, a mod that stops working on a space
platform, a save that loads with everything gone — none of these raise an error at the point of
the mistake. They surface hours later as "it just doesn't work". Knowing the contract up front is
the only cheap way to avoid them.

## Where this skill sits

This one owns the **code**. The others own the wrapper around it:

| Skill | Owns |
|---|---|
| `factorio-mod-setup` | `info.json`, folder anatomy, `locale/*.cfg`, declaring settings, `migrations/` files |
| **`factorio-mod-development`** | **the Lua in `data*.lua` and `control.lua`, and everything they require** |
| `factorio-validate` | proving the data stage loads; running throwaway experiments |
| `factorio-changelog` | `changelog.txt` |
| `factorio-release` | version bumps, `fmtk`, the portal |
| `factorio-graphics` | sprites, icons, Blender |

Overlaps in practice: renaming a prototype is this skill (the code) **and** `factorio-mod-setup`
(the migration file) **and** `factorio-release` (the major bump). Adding a setting is
`factorio-mod-setup` (declaring it) and this skill (reading it safely).

## References

Read the one that matches the work — SKILL.md is the contract, these are the craft.

| File | Read when |
|---|---|
| `references/data-stage.md` | Authoring or deriving any prototype; naming, ordering, recipes, technologies, quality maths, `data.raw` surgery |
| `references/control-stage.md` | Anything in `control.lua`: lifecycle handlers, `storage`, events, tracking entities, GUIs, commands, remote interfaces |
| `references/performance.md` | A mod that costs UPS, anything running per-tick, or before writing a loop over entities |
| `references/compatibility.md` | Optional dependencies, patching another mod, expansion gating, or shipping an API other mods call |

## The two stages

Factorio runs mod code at two completely separate times, in two Lua states that never meet.

|  | **Data stage** (startup) | **Control stage** (a running save) |
|---|---|---|
| Files | `settings*.lua`, then `data.lua` → `data-updates.lua` → `data-final-fixes.lua` | `control.lua` and what it requires |
| Builds | Prototypes — the *definitions* of things | Behaviour — reactions to a live world |
| Globals | `data`, `mods`, `settings` (startup only), `feature_flags` | `game`, `script`, `storage`, `prototypes`, `helpers`, `remote`, `commands`, `rendering`, `settings`, `rcon` |
| Can see | Every mod's prototypes, in load order | The map, forces, players, surfaces |
| Cannot see | Anything about a save. There is no game yet | Prototype *definitions* are read-only (`prototypes.*`); `data` does not exist |
| Reload | Full game restart | `/c game.reload_script()`, or just reload the save |

The three data-stage rounds exist so mods can react to each other without depending on each
other: **every** mod's `data.lua` runs before **any** mod's `data-updates.lua`. That is the whole
mechanism, and it is why touching another mod's prototypes belongs in `data-updates` at the
earliest — in `data.lua` the thing you want to patch may not exist yet.

The data-stage Lua state is **discarded** at the end. Nothing carries over to runtime: not a
variable, not a function, not a computed table. When the control stage needs a value the data
stage computed, the sanctioned route since 2.0.58 is a **`mod-data` prototype**:

```lua
-- data stage
data:extend({{ type = "mod-data", name = "my-mod-tiers", data_type = "my-mod-tiers",
               data = { ["my-mod-smelter"] = { tier = 2, drain = 40 } } }})

-- control stage
local tiers = prototypes.mod_data["my-mod-tiers"].data
```

`prototypes.mod_data` is a flat dictionary keyed by prototype name, like every other
`prototypes.*` table. `data_type` is a free-form string other mods can filter on — it is a
compatibility hook, not part of the lookup. Before this existed people smuggled values through
unused prototype fields or duplicated a constants file into both stages; a shared constants file
still works and is fine for literals, but `mod-data` is the one that survives another mod
changing the values.

## The Lua is not quite the Lua you know

Factorio ships a modified Lua 5.2.1. The differences below are from
`doc-html/auxiliary/libraries.html` (2.1.14), and several invert advice that is correct in
ordinary Lua.

- **`pairs()` is deterministic.** Iteration follows insertion order, and the first 1024 numeric
  keys always come out 1..1024 regardless of insertion. So the usual "sort your keys before
  iterating or you'll desync" ritual is unnecessary here — `pairs()` is safe, including in
  multiplayer, and has no ordering drawback versus `ipairs()` for normal use.
- **`#` lies on tables with holes.** Use the engine's `table_size(t)` — a C++ implementation, so
  also faster than counting in Lua. It does *not* work on a `LuaCustomTable`; those have
  `length_operator`.
- **`io`, `os`, `coroutine`, `dofile` and `loadfile` do not exist**, for determinism. Writing a
  file is `helpers.write_file`. `debug` is cut down to `getinfo` and `traceback`.
- **`math.random()` draws from the map's global RNG**, shared with the core game and every other
  mod — so consuming from it changes what everyone else gets. `math.randomseed()` is a no-op. For
  a private, reproducible stream use `LuaRandomGenerator` (`game.create_random_generator`).
  In the data stage `math.random` is seeded with a constant, which is what makes startup
  deterministic.
- **`require()` starts at the mod root** for absolute paths, `..` is forbidden, and
  `require("__other-mod__.file")` reaches into another mod. `require("util")` resolves to
  `core/lualib/util.lua` because that directory is on the path. `require` cannot be called from
  the console, an event handler, or inside a `remote.call()`.
- **`require()` caches by resolved file, not by the string.** `require("scripts.foo")`,
  `require("scripts/foo")` and `require("__my-mod__.scripts.foo")` all return the *same* table
  and run the file *once* — tested on 2.1.14. Mixing separators is untidy, not dangerous. Pick
  dots and stay consistent for readability.
- **`serpent` and `log()` are provided.** `log(serpent.block(data.raw.item["sulfur"]))` is the
  fastest way to see what a prototype actually looks like, and works in the data stage where
  there is nothing else. `print()` goes to stdout, which you will not see; `log()` goes to
  `factorio-current.log`.
- Trigonometric, exponential and logarithmic functions are Wube's own implementations, so they
  give bit-identical results across platforms.

## The globals, and the 2.0 renames

Runtime globals, verified against 2.1.14: `game`, `script`, `storage`, `prototypes`, `helpers`,
`remote`, `commands`, `rendering`, `settings`, `rcon`. Global functions: `log`,
`localised_print`, `table_size`.

Three renames from 1.1 account for most stale code and most wrong recollection:

| Pre-2.0 | 2.0+ |
|---|---|
| `global` (persistent state) | **`storage`** |
| `game.entity_prototypes`, `game.item_prototypes`, … | **`prototypes.entity`, `prototypes.item`, …** |
| assorted `game.*` utilities (`table_to_json`, `write_file`, `is_valid_sprite_path`, …) | **`helpers.*`** |

Anything you find using `global` for mod state, or `game.recipe_prototypes`, is pre-2.0 and needs
porting, not copying. `on_entity_destroyed` likewise became `on_object_destroyed`.

## What silently breaks

These are the ones worth memorising because nothing tells you.

**1. `script.on_event` overwrites — one handler per event per mod.** Registering a second time
replaces the first, including when the two registrations use different filters. Two files that
both do `script.on_event(defines.events.on_built_entity, ...)` means the second one wins and the
first silently never runs. Use `__core__.lualib.event_handler` (details in
`references/control-stage.md`) or route everything through one dispatcher.

**2. Missing a build or mine variant.** An entity can arrive six ways and leave five, and only
handling `on_built_entity` covers exactly one of them. The full 2.1 set:

```
built:  on_built_entity  on_robot_built_entity  on_space_platform_built_entity
        script_raised_built  script_raised_revive  on_entity_cloned
gone:   on_player_mined_entity  on_robot_mined_entity  on_space_platform_mined_entity
        on_entity_died  script_raised_destroy
```

`on_space_platform_built_entity` / `on_space_platform_mined_entity` are new in 2.0 and are the
ones ported mods miss — the mod then works on Nauvis and quietly does nothing in orbit.

**3. Writing to `storage` during `on_load`.** That is an error at best and a desync at worst;
`on_load` exists only to rebuild *local* state. The three legitimate uses are re-attaching
unregistered metatables, re-registering conditional event handlers, and taking local references
into `storage`. Anything else belongs in `on_init`, `on_configuration_changed`, or a migration.

**4. Holding a `LuaEntity` across ticks without checking `.valid`.** There is no
"entity destroyed" event for arbitrary entities precisely because a reference to a destroyed one
is already meaningless. Guard every stored reference before use, or track by `unit_number` and
re-resolve. `script.register_on_object_destroyed` gives you an event for a *specific* object you
opted in.

**5. Storing anything unserialisable in `storage`.** Allowed: nil, strings, numbers, booleans,
plain tables (cycles are fine), and `LuaObject` references. A function throws on save.
A metatable is *dropped* unless registered with `script.register_metatable` — the table survives
as a plain table, and the methods you were relying on are gone with no error.

**6. Renaming or removing a prototype without a migration.** Every placed entity of that name
vanishes from existing saves. This is the change that pairs with a major version bump — see
`factorio-mod-setup` for the migration file and `factorio-release` for the bump.

**7. Prototype name collisions.** Names are one flat global namespace across every mod. Prefix
everything with a short mod tag (`kr-`, `se-`, `pm-`) — community convention, and the reason
`data.raw` surgery on a well-behaved mod is predictable. Names accept alphanumerics, dashes and
underscores only.

**8. Noise expressions are never checked by `--dump-data`.** They compile when *map generation
settings* change, which headless data-stage validation never does. A malformed
`probability_expression` therefore passes validation clean and fails at world creation.
`factorio.exe --create <save> --map-gen-seed <n>` is what actually exercises one; adding a
throwaway mod that counts tiles in `on_init` turns it into a measurement. See
`factorio-validate`.

**9. An autoplace control set to "none" is still evaluated, with size 0.** It is not skipped, so
the expression runs and whatever it returns is placed. Any term the coverage slider does not
multiply survives — `4 * control:x:size + 3 * noise` still yields positive widths at size 0.
Verified on 2.1.14: an additive wobble left 4007 tiles on a 1280×1280 map at coverage none, and
making the slider multiply the whole term (`size * (4 + 3 * noise)`) took it to zero while leaving
the default-settings output byte-identical. Multiply, don't add — and generate a map at "none" to
prove it, because nothing else will.

**10. A `noise-function`'s `x` / `y` parameters do not reach a nested *named* expression.** They
are ordinary parameters, so they only affect sub-expressions that consume them **as arguments**.
`basis_noise{x = x, y = y, ...}` inside the function shifts correctly; a bare reference to
`elevation`, `cliff_elevation` or any other named expression reads the **ambient** coordinates and
returns the same value no matter what the function was called with. Verified on 2.1.14: a function
whose whole body was `cliff_elevation`, called at `(x + 1000, y)`, came back byte-identical to
`cliff_elevation` sampled at `(x, y)`, while the same test on `basis_noise` matched the shifted
field exactly.

This is what makes **finite differences on a vanilla field impossible** — every offset sample
returns the same number, so the gradient comes out as exactly zero and whatever divides by it
silently produces garbage rather than an error. Only a field you build yourself, out of primitives
taking `x` and `y` as arguments, can be differentiated. Anything a contour or distance estimate
depends on has to live inside that same function for the same reason: a term added to the result
afterwards is invisible to the gradient.

**11. Reading a field's value is not the same as reading where the engine acts on it.** Several
map-gen decisions are evaluated per *cell* rather than per tile, so a per-tile read of the
governing field disagrees with what actually gets placed. Measured on 2.1.14: cliffs are gated on
a four-tile grid, and cliff entities routinely stand on tiles where `cliffiness` reads 0 — a mod
that treated "cliffiness is 0 here" as "no cliff can be here" put tiles through 13 real cliffs in a
1024-tile square. The general form: **a veto must not depend on the scale, or on the resolution, of
a field it does not own.** The only way to find this class of bug is to generate the world twice,
with the feature on and off, and diff the entities — see `factorio-validate`.

**12. Base shares one sub-table between several prototypes.** `data.raw` surgery that appends to
a table found inside a vanilla prototype may be appending to a table *other prototypes hold by
reference* — base hands all four grasses the same `transitions_between_transitions` table, one
`sand_transitions` to every sand, and the pattern is general. A loop that patches each tile
therefore hits the shared table once per holder; the engine then rejects the duplicate
("Transition between transition groups 0 and 4 already exists") or, worse, applies the patch
twice without a word. Guard every append with a has-it-already check — idempotent patching is
the only shape that survives shared tables, and it costs two lines.

## Working method

1. **Look at how vanilla or `exemples/` does it before inventing.** `data/base/` is Wube's own
   source and the best answer to "how is this prototype actually written". `exemples/` has three
   real mods and the vanilla tree; `exemples/CLAUDE.md` is the index. This is not politeness —
   deriving from a shipped prototype gets you fluid boxes, circuit connectors, sounds, remnants
   and explosions for free and keeps working when Wube retunes them.
2. **Grep the local API JSON for the exact field**, don't recall it.
   `doc-html/prototype-api.json` and `doc-html/runtime-api.json` are the installed version's own
   truth. They are large — query them, never read them whole.
3. **Validate the data stage after prototype edits** — `factorio-validate`, about five seconds.
   Validate *each branch* if the mod is conditional on `mods[...]`, `feature_flags` or a startup
   setting; one run only proves one configuration.
4. **When the question is "how does the loader behave?", test it instead of reasoning.** A
   five-line throwaway mod plus `validate.ps1 -Live` settles it in a minute. Two long-standing
   rules in this repo turned out to be wrong when finally tested that way. `factorio-validate`
   has the recipe.
5. **Put it on a real map before calling it done.** A clean data stage says nothing about
   graphics paths, runtime behaviour, migrations, or whether the recipe tree makes sense.

## Debugging

- **`factorio-current.log`**, in the same user-data folder as `mods/`, is where load failures and
  `log()` output land. Several failure modes appear *only* there — a missing locale key logs
  `Unknown key`, a malformed `changelog.txt` logs a parse error and simply doesn't render.
  For a standalone install that folder is the **install root**, one level above this repo; read
  the wrong install's log and a stale error looks like a live one.
- **`log(serpent.block(x))`** works in both stages and is usually enough. At runtime `game.print`
  and `player.print` are more immediate; neither exists during `control.lua` top level or
  `on_load`.
- **`helpers.is_valid_sprite_path` / `is_valid_sound_path`** let the control stage check a path
  headless validation cannot — useful because a bad `icon` or `filename` passes `--dump-data`
  clean and only breaks in the real game.
- **`helpers.create_profiler`** returns a `LuaProfiler` you can `stop()` and pass straight into a
  `LocalisedString`. It deliberately refuses to expose raw numbers to Lua, because timings are
  non-deterministic and reading them would desync.
- **fmtk is a debugger, not just a packager.** `factoriomod-debug` (already installed here, see
  `CLAUDE.local.md`) ships a Debug Adapter with breakpoints, stepping and profiling, driven from
  VS Code or any DAP editor, via `--instrument-mod debugadapter`. Instrument mode injects code
  into every mod's Lua state before its own files run, and **disables multiplayer** while active
  because it is not desync-safe.
- The `check-unused-prototype-data` debug setting logs prototype properties the game ignored —
  the way to catch a field you spelled wrong or that was deprecated in 2.0.

## Code style

Match `CLAUDE.md` → Code style: write it the way a Factorio modder would. Comments earn their
place by explaining *why* or flagging a gotcha; 2-space indent and `snake_case` like vanilla;
prefer the plain solution over configuration nothing asked for. Player-facing strings never go in
Lua — they go in `locale/*.cfg` and the code references the key, which is also what makes
translation possible.
