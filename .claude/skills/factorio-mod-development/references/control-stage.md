# Control stage — the runtime contract

Everything in `control.lua` and what it requires. The rules here come from
`doc-html/auxiliary/data-lifecycle.html` and `storage.html` (2.1.14) plus the runtime API JSON;
the API surface was verified against 2.1.14 directly.

## Contents

- [The load sequence](#the-load-sequence) — what runs when, and the multiplayer-join special case
- [`storage`](#storage) — what may be stored, metatables, shape
- [Events](#events) — registration, the one-handler rule, `event_handler`, filters
- [Tracking entities](#tracking-entities) — validity, `unit_number`, `on_object_destroyed`
- [Players and forces](#players-and-forces) — per-player state, settings, printing
- [GUIs](#guis) — placement, the closure problem, styling
- [Commands, remote interfaces, custom input](#commands-remote-interfaces-custom-input)
- [Desync sources](#desync-sources)

## The load sequence

Five steps, in this order, each run for **all** mods before the next begins:

1. **`control.lua` top level.** Runs on every save load. `game`, `rendering` and `storage` are all
   unavailable — `storage` is not restored from the save until just before `on_load`. This step
   is for registering: `script.on_event`, `script.on_init`, `remote.add_interface`,
   `commands.add_command`, `script.register_metatable`. Because it re-runs on every load, code
   changes here take effect without restarting the game.
2. **`on_init()`** — only for a mod that is *new to this save* (new game, or the mod was just
   added; adding a `control.lua` to an existing mod counts as new). Full access to `game` and
   `storage`. Set up your initial `storage` shape here, not in step 1.
3. **Migrations** — JSON first, then Lua, each file once per save, recorded by name.
4. **`on_load()`** — for every mod that was already in the save. No `game`. `storage` is readable
   but **writing errors**. Three legitimate uses only (below).
5. **`on_configuration_changed(data)`** — for *all* mods if anything about the configuration
   changed: game version, any mod version, a mod added or removed, a startup setting changed, a
   prototype added or removed, or a migration ran. Full access to everything.

`on_init` and `on_load` are mutually exclusive for a given mod on a given load. `on_init` and
`on_configuration_changed` can both run (new mod added to an existing save).

**The multiplayer-join case decides the whole design.** A player downloading the save to join a
running game runs only steps 1 and 4 — no `on_init`, no migrations, no
`on_configuration_changed`. So the joining player's Lua state must end up identical to everyone
else's after `control.lua` + `on_load` alone. Concretely: **event registrations must be identical
on every client**, which is what makes conditional registration (registering `on_tick` only while
there is work to do) require re-deriving the same condition in `on_load`.

### `on_load`, precisely

The only three things it may do:

- Re-attach metatables that were **not** registered with `script.register_metatable`.
- Re-register conditional event handlers.
- Take local references into `storage`.

Everything else — fixing up data, reacting to a version change, touching the world — belongs in
`on_init`, `on_configuration_changed`, or a migration. Rseding91's own save/load notes put it as:
the entire world must be in a valid state when Lua events fire, so `on_load` may not resize
inventories, delete entities, or otherwise mutate the game.

### `on_configuration_changed` is where updates get repaired

`data.mod_changes[name]` gives `old_version` / `new_version` (`old_version` is nil when the mod
was just added). Use it to migrate `storage` shape, re-scan surfaces for your entities, and — the
one most people forget — **re-check that prototypes you depend on still exist**, because the
player may have removed the mod that supplied them:

```lua
script.on_configuration_changed(function(e)
  if not prototypes.entity["gun-turret"] then
    storage.turret_logic_enabled = false
  end
end)
```

Prefer a `migrations/*.lua` file over version-comparing inside `on_configuration_changed` when the
fix is tied to one specific version — migrations run once per save and are recorded, whereas
`on_configuration_changed` runs on every configuration change forever. See `factorio-mod-setup`
for migration file mechanics.

## `storage`

The one table that survives save/load. Each mod gets its own, so no namespacing needed.

**Allowed:** `nil`, strings, numbers, booleans; tables (circular references handled); references
to `LuaObject`s.

**Not allowed:** functions — these throw when saving.

**Metatables are the trap.** A metatable is not saved. Unless it is registered, the table comes
back as a plain table with its metatable *silently gone* — no error, just methods that no longer
exist and `__index` defaults that no longer fill in. Register it at `control.lua` root scope:

```lua
local Tank = {}
Tank.__index = Tank
script.register_metatable("my-mod-tank", Tank)
```

`register_metatable` cannot be called from the console, an event listener, or a `remote.call()`.
Registration is by name, so the name is part of your save compatibility — renaming it later breaks
old saves the same way renaming a prototype does.

**Shape it once and keep it flat.** Initialise the whole structure in `on_init` rather than
lazily with `storage.x = storage.x or {}` scattered through handlers — a lazy shape means every
call site carries the initialisation and one that forgets it produces a nil index far from the
cause. Keyed lookup tables (`storage.machines[unit_number]`) beat arrays you scan.

`LuaObject` references stored in `storage` do survive, but they can go invalid — see below.

## Events

### One handler per event per mod

`script.on_event(id, handler)` **overwrites** any previous registration for that event by this
mod, including when the registrations use different filters. Passing `nil` as the handler
deregisters. This is the single most common way two files in the same mod silently break each
other.

The standard answer is Wube's own `__core__.lualib.event_handler`, which is what Krastorio 2 and
most modern mods use:

```lua
-- control.lua
local handler = require("__core__.lualib.event_handler")
handler.add_libraries({
  require("__flib__.gui"),
  require("scripts.wind-turbine"),
  require("scripts.roboport"),
})
```

Each module returns a table the library understands:

```lua
-- scripts/wind-turbine.lua
local wind_turbine = {}

local function on_built(e) ... end

function wind_turbine.on_configuration_changed() ... end

wind_turbine.events = {
  [defines.events.on_built_entity] = on_built,
  [defines.events.on_robot_built_entity] = on_built,
  [defines.events.on_space_platform_built_entity] = on_built,
}
wind_turbine.on_nth_tick = { [60] = check_all }

return wind_turbine
```

Reading `event_handler.lua` (it is ~130 lines) is worth it once. It collects every library's
`events` and `on_nth_tick` tables, merges handlers per event id into one registration, and does
the registering inside `on_init` **and** `on_load` — which is exactly what makes it join-safe. It
also recognises `on_init`, `on_load`, `on_configuration_changed`, `add_remote_interface` and
`add_commands` on each library, normalises string / define / custom-event references to the same
id, and logs a warning if one module registers the same event twice.

If you would rather not take the dependency, hand-rolling a dispatcher is fine — Space Exploration
has its own (`scripts/event.lua`) — but register it from `on_init`/`on_load`, not from arbitrary
code.

### Filters

Filterable events take a filter list at registration and the handler simply never fires for
anything else. This is a real engine-side saving, not a Lua `if`:

```lua
script.on_event(defines.events.on_built_entity, on_built,
  {{ filter = "name", name = "my-mod-smelter" },
   { filter = "type", type = "assembling-machine" }})
```

Multiple entries are OR'd. Filters attach to a **single** event id — you cannot pass an array of
events and a filter together, so a shared handler across the build variants means one
`on_event` call per variant.

Events supporting filters in 2.1.14: `on_built_entity`, `on_robot_built_entity`,
`on_space_platform_built_entity`, `on_player_mined_entity`, `on_robot_mined_entity`,
`on_space_platform_mined_entity`, `on_robot_pre_mined`, `on_space_platform_pre_mined`,
`on_pre_player_mined_item`, `on_entity_died`, `on_post_entity_died`, `on_entity_damaged`,
`on_entity_cloned`, `on_marked_for_deconstruction`, `on_cancelled_deconstruction`,
`on_marked_for_upgrade`, `on_cancelled_upgrade`, `on_pre_ghost_deconstructed`,
`on_pre_ghost_upgraded`, `on_player_repaired_entity`, `on_sector_scanned`,
`on_segmented_unit_created`, `on_segmented_unit_damaged`, `on_segmented_unit_died`,
`on_post_segmented_unit_died`, and the `script_raised_*` family.

### The build and destroy sets

An entity appears via `on_built_entity` (player), `on_robot_built_entity`,
`on_space_platform_built_entity`, `script_raised_built`, `script_raised_revive` (a ghost turned
real), and `on_entity_cloned`. It leaves via `on_player_mined_entity`, `on_robot_mined_entity`,
`on_space_platform_mined_entity`, `on_entity_died`, and `script_raised_destroy`.

The space-platform pair is new in 2.0 and is what a 1.1-era mod misses. The `script_raised_*`
pair only fires when the mod that created or destroyed the entity opted in
(`raise_built = true` on `create_entity`, or `script.raise_script_built`) — so another mod placing
your entity silently may not notify you, and conversely **you** should raise them when you create
or destroy entities other mods might care about.

`on_entity_died` has an important sibling: `on_post_entity_died`, which fires after the entity is
gone and carries the ghost/corpse, for when you need to react to the aftermath rather than the
entity.

### `on_tick` and `on_nth_tick`

`script.on_nth_tick(n, handler)` is the engine doing the modulo for you, and multiple `n` values
can be registered independently. Prefer it to `on_tick` + `% n`; prefer neither to an event that
tells you exactly when something happened. See `references/performance.md`.

### Custom and raised events

`script.generate_event_name()` at `control.lua` root gives you an id to `raise_event` on, which
other mods can subscribe to once you expose the id through a remote interface — that is the
standard "my mod emits an event" pattern (flib's dictionary does exactly this). Only
generated events and a specific whitelist of built-ins can be raised.

## Tracking entities

**`.valid` is not optional.** A `LuaEntity` you stored last tick may refer to something destroyed
since, and calling into it then is an error. Mods should check validity whenever the game state
might have changed between obtaining the reference and using it — which across a tick boundary is
always.

```lua
for unit_number, data in pairs(storage.machines) do
  if data.entity.valid then
    work(data.entity)
  else
    storage.machines[unit_number] = nil
  end
end
```

**Index by `unit_number`.** There is no engine-side "find entity by unit_number" and Wube has
declined to add one, because it would be a full scan. Your own dictionary keyed by `unit_number`
is the O(1) lookup, and it is also the key you can safely put in GUI element `tags` or pass
around, unlike an entity reference. Note that not every entity has a `unit_number`.

**`script.register_on_object_destroyed(obj)`** gives you a real destruction event for one specific
object, surviving save/load. Caveats worth knowing:

- Registration is **global across all mods** — if any mod registered an object, every mod
  listening to `on_object_destroyed` gets the event. Do not assume an event is about *your*
  object; check `event.useful_id` against your own table.
- Registering the same object twice returns the same registration number and fires once.
- The event arrives at the end of the current or the *next* tick, so it is not synchronous with
  the destruction.
- Event fields: `registration_number`, `useful_id`, `type` (`defines.target_type`), `tick`. Note
  it is `useful_id`, not `unit_number` — that was the 2.0 rename.

## Players and forces

- **Per-player state goes in `storage.players[player_index]`**, created on
  `on_player_created` and also backfilled in `on_configuration_changed` (players exist in saves
  that predate your mod). `on_player_removed` should clean it up.
- **Per-player settings** are `settings.get_player_settings(player)[name].value`. Startup settings
  are `settings.startup[...]` at either stage; map settings are `settings.global[...]`.
  `on_runtime_mod_setting_changed` tells you when a runtime one moved.
- **`game.print` broadcasts, `player.print` does not.** Both are fine for determinism — printing
  is a game action, not local state — but a message meant for one player should not go to
  everyone.
- Reading a startup setting **that was never defined is an error, not `nil`**. If a setting is
  declared conditionally (only when some mod is present), every read of it must short-circuit on
  the same condition. See `references/compatibility.md`.

## GUIs

Placement decides the rules, per raiguard's GUI style guide (the de-facto community standard,
and what flib's styles are built for):

| Where | Rules |
|---|---|
| `player.gui.screen` | The standard window. Custom titlebar with a drag handle, close button top-right, set `player.opened` so E closes it |
| `mod_gui.get_frame_flow(player)` | Persistent corner panel. `mod_gui.frame_style`, no close button, no dialog row; opened from a `mod_gui` button or a hotkey |
| `player.gui.relative` | Attaches to a vanilla GUI (a machine window, the map). Anchored by `relative_gui_type` |
| `player.gui.left/top` | Legacy. Prefer `mod_gui`, which manages these for you |

`local mod_gui = require("__core__.lualib.mod-gui")`. Content frame padding is 12px, titlebar flow
spacing 8, drag handle `draggable_space_header` at 24px height with `horizontally_stretchable`.
**Ctrl+F6 in game** opens the style inspector and tells you the style of whatever you hover — far
faster than guessing style names.

**The closure problem is the real one.** A Lua function cannot be serialised, so a click handler
cannot be stored on the element or in `storage`. Handlers must be looked up **by name** at event
time. Either put an identifying string in the element's `tags` and switch on it in
`on_gui_click`, or use flib's `gui.lua`, which is exactly this pattern productised: register
named handlers at control-stage top level, build a declarative tree, and flib stores the
handler's registered name in `tags` and dispatches from it. `exemples/flib_0.17.2/CLAUDE.md` has
the full mental model; its `tests/gui-lite.lua` is a working demo.

Other GUI facts that bite:

- **Element names are unique among siblings only**, and a destroyed parent takes its children
  with it. Keep a reference to the elements you need in `storage.players[i].elems` rather than
  walking the tree by name.
- **Every GUI event carries `player_index`** — always act on that player, never on
  "the" player.
- `on_gui_click` fires for every element in every mod; check ownership before reacting.
- GUI element *size* is not game state and cannot be read (except in instrument mode) because
  reading it would desync.

## Commands, remote interfaces, custom input

- **`commands.add_command(name, help, handler)`** at `control.lua` root. The help string should
  be a `LocalisedString`. The handler gets `{player_index, parameter}`; `player_index` is nil for
  the server console.
- **`remote.add_interface(name, {...})`** is how mods talk to each other at runtime. Register at
  root scope. Calling: `if remote.interfaces["other-mod"] then remote.call("other-mod", "fn", x) end`
  — the guard matters, because the mod may not be installed. `require` is not available inside a
  `remote.call`. See `references/compatibility.md` for shipping one.
- **`custom-input` prototypes** (data stage) become `script.on_event("my-mod-hotkey", handler)` at
  runtime — the event name is the prototype name, a string, not a `defines.events` value.
  `shortcut` prototypes give a toolbar button and fire `on_lua_shortcut`.

## Desync sources

A desync is two clients' Lua state diverging. The engine is deterministic; mods are how it stops
being. In practice all of them reduce to *state that isn't in `storage` but affects behaviour*:

- A module-level `local` mutated across ticks. It resets on load, so a joining player starts from
  the declared default while everyone else is at whatever it drifted to. If it changes between
  events, it belongs in `storage`.
- Event registrations that differ between clients — the reason conditional registration must be
  re-derived in `on_load` from data that is in `storage`.
- Doing work in `on_load` beyond the three permitted things.
- Reading something that is not game state: real time, GUI element sizes, whether a specific
  player is looking at something. `game.tick` is state; the wall clock is not.
- Per-player branching in shared logic. A GUI opened for one player is fine; *game state* changed
  only on one client is not.

Instrument mode disables multiplayer for this reason. When chasing one, `--instrument-mod` plus
the fmtk debug adapter, and Factorio's own desync report (which dumps both sides' state for
diffing), are the tools.
