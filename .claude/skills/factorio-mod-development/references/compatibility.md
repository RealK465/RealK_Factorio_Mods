# Compatibility — other mods, expansions, and old saves

A mod is never alone. Players run dozens, expansions are optional, and saves outlive versions.
Most of the work is defensive and cheap; the expensive part is finding out later.

## Contents

- [Optional dependencies and the `mods` guard](#optional-dependencies-and-the-mods-guard)
- [Conditional settings — the asymmetry that bites](#conditional-settings--the-asymmetry-that-bites)
- [Expansions: `feature_flags`, not `mods`](#expansions-feature_flags-not-mods)
- [Patching another mod's prototypes](#patching-another-mods-prototypes)
- [Runtime compatibility](#runtime-compatibility)
- [Shipping an API other mods can call](#shipping-an-api-other-mods-can-call)
- [Not breaking saves](#not-breaking-saves)
- [Being a good citizen](#being-a-good-citizen)

## Optional dependencies and the `mods` guard

Two separate things, both needed:

1. **`info.json` dependency prefix** decides *load order*. `?` or `(?)` means "if this mod is
   present, load it before me". It does **not** make anything conditional in your code, and it
   does not enable the other mod. Full prefix table in `factorio-mod-setup`.
2. **`if mods["other-mod"] then`** decides *whether your code runs*. `mods` maps enabled mod name
   → version string and is available in both the settings and the data stage.

Getting only the first gives you a load-order guarantee and a nil-index crash. Getting only the
second gives you correct guards that sometimes run before the thing they guard exists.

Note a version on an optional dependency is still enforced: `"? some-mod >= 2.0"` **disables your
mod** when `some-mod` is present at 1.9. Omit the version unless you mean that.

**Guard once at the entry point, not twenty times inside.** SE's postprocess mod is the canonical
shape — a whole mod whose `data-final-fixes.lua` opens with:

```lua
if not mods["space-exploration"] then return end
```

and then unconditionally requires twenty patch files. Each patch file still checks the specific
prototypes it touches, because "the mod is installed" and "this particular item exists" are
different questions — a settings-driven mod may not have created it.

## Conditional settings — the asymmetry that bites

`mods` being available in `settings.lua` means a setting that would be meaningless under the
current mod set can simply not be defined, instead of sitting in the options GUI doing nothing:

```lua
-- settings.lua
if mods["space-age"] then
  data:extend({{ type = "bool-setting", name = "pm-freeze-immune", ... }})
end
```

The catch is the read side. **Indexing a startup setting that was never defined is an error, not
`nil`.** So every read must short-circuit on the same condition that created it:

```lua
-- data.lua — the mods[...] check is not redundant
if mods["space-age"] and settings.startup["pm-freeze-immune"].value then
```

Write the condition once in a local if it is used more than twice; a copy that drifts is the
failure mode.

## Expansions: `feature_flags`, not `mods`

Expansion-only *prototype properties* are gated by a data-stage global called `feature_flags`,
keyed with underscores: `feature_flags["freezing"]`, `["quality"]`, `["rail_bridges"]`,
`["space_travel"]`, `["spoiling"]`, `["segmented_units"]`, `["expansion_shaders"]`, `["expansion"]`.

Test the **flag**, not `mods["space-age"]`. The flag is what the property is actually tied to, and
another mod declaring the matching `*_required` turns it on without Space Age being present.

```lua
if feature_flags["freezing"] then
  beacon.heating_energy = "600kW"   -- illegal to set without the flag
end
```

**Reading a flag that is off is safe** — it is `false`, not an error, unlike an undefined startup
setting. The trap runs the other way: declaring `*_required` in your own `info.json` to unlock a
property makes your whole mod require the expansion, with no partial mode. Declare it only when the
mod is worthless without the expansion. Which flag unlocks which properties is in
`factorio-mod-setup`.

**Validate both branches.** A mod that reads a flag or a `mods[...]` is really several mods, and
one validation run exercises one of them. `factorio-validate`'s `-Disable` flag is for exactly
this.

## Patching another mod's prototypes

In `data-updates.lua` (preferred) or `data-final-fixes.lua` (last resort — see
`references/data-stage.md`).

Layer the guards, because each answers a different question:

```lua
if mods["Krastorio2"] then                       -- is the mod loaded at all?
  if data.raw.item["kr-imersite-plate"] then     -- did it actually create this?
    ...
  end
end
```

Some mods expose a shared library table (`bobmods.lib.recipe`) — check the whole chain
(`if bobmods and bobmods.lib and bobmods.lib.recipe then`) before calling into it, since the
library may exist in a different shape in a different version.

Two conventions worth adopting from the mods that do this at scale:

- **A `data_util.lua` of small safe operations** — `tech_add_prerequisites`,
  `replace_or_add_ingredient`, `tech_add_ingredients` — each checking existence and avoiding
  duplicates. Written once, used across every patch file.
- **Comment out superseded patches rather than deleting them** when the other mod is still moving.
  SE's postprocess does this deliberately.

And the judgement call: rebalancing prototypes you do not own, especially resources and recipe
costs, can quietly destroy another mod's design. Patch for *compatibility* — making the two work
together — not for taste.

## Runtime compatibility

- **`remote.interfaces`** before `remote.call`:
  ```lua
  if remote.interfaces["other-mod"] and remote.interfaces["other-mod"]["get_thing"] then
    local x = remote.call("other-mod", "get_thing", arg)
  end
  ```
- **`prototypes.entity[name]`** before assuming a prototype exists at runtime — the player may
  have removed the mod that supplied it. `on_configuration_changed` is where to re-check and
  disable your dependent logic gracefully.
- **`script.raise_script_built` / `raise_script_destroy`** when you create or destroy entities
  other mods might track, and `raise_built = true` / `raise_destroy = true` on
  `create_entity` / `destroy`. Not raising them is how your mod silently breaks someone else's.
  Conversely, subscribe to `script_raised_built` and `script_raised_destroy` so mods that *do*
  raise them work with yours.
- **Never assume you are the only one handling an event.** Other mods see the same
  `on_gui_click`; check that the element is yours before acting.

## Shipping an API other mods can call

```lua
remote.add_interface("my-mod", {
  get_tier = function(name) return storage.tiers[name] end,
  on_thing_happened = function() return storage.event_id end,
})
```

Register at `control.lua` root scope (or via `event_handler`'s `add_remote_interface`, which
handles the `on_init`/`on_load` double-call). For a custom event, `script.generate_event_name()`
at root, store the id in `storage`, and hand it out through the interface — that is how a
consumer subscribes.

`require` cannot be called inside a `remote.call`. Keep interface functions thin and give them
stable signatures: an interface is a public contract, and changing it breaks the mods that adopted
it exactly like renaming a prototype breaks saves.

For data-stage sharing, a **`mod-data` prototype** (see SKILL.md) is the modern equivalent —
another mod can read *and modify* it in `data-updates` without either side needing a remote
interface, and `data_type` is the agreed tag they filter on.

## Not breaking saves

The rules that decide whether a player's 200-hour save survives your update:

- **Renaming or removing a prototype needs a migration**, or every placed instance vanishes.
  JSON migrations for renames, Lua for `storage` fixups. `factorio-mod-setup` has the file rules.
- **Renaming a `register_metatable` name** breaks the linkage the same way, silently — the table
  loads as a plain table.
- **Changing a prototype's `type`** does not preserve `unit_number` even with a migration, and
  invalidates anything holding a reference. Renaming within the same type does preserve it.
- **Never edit or rename a shipped migration file.** Saves record which ones have run by filename;
  changing one either re-runs the wrong thing or skips the fix. Add a new file.
- **Prototype names stored in `storage`** cannot be migrated automatically — the migration system
  only knows about the world, not your table. If you store names, write the Lua migration that
  rewrites them.
- Recipes and technologies are reset automatically on any prototype change, so migrations no
  longer need to do that themselves.

Version bump policy for all of this is in `factorio-release`.

## Being a good citizen

Cheap things that avoid other people's bug reports:

- Prefix every prototype name, setting name, custom-input name and remote interface name with your
  mod tag. All of these are flat global namespaces.
- Prefer `data-updates` to `data-final-fixes` so others can still react to you.
- Declare `!` incompatibility rather than shipping code that half-works alongside something.
- Don't modify another mod's prototypes without an optional dependency on it — without one, load
  order is not guaranteed and your patch is a coin flip.
- Don't consume from `math.random` in a hot path; it is the shared map RNG and you are changing
  everyone else's draws. `LuaRandomGenerator` gives you a private stream.
- Keep player-facing strings in `locale/*.cfg`, never hardcoded — it is what lets translators work
  without touching code.
