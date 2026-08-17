---
name: factorio-mod-setup
description: Use when starting a new Factorio mod or editing any of its wiring — info.json (name, version, factorio_version, dependencies, Space Age feature flags, package.ignore), locale .cfg translations and prototype display names, settings.lua mod options, or migrations for renamed prototypes and old saves. Also use when a mod folder isn't being loaded at all, or its text shows in game as "Unknown key". Most of these fail silently rather than erroring, so check the field rules here instead of recalling them.
---

# Mod setup — anatomy, `info.json`, locale, settings, migrations

Target is Factorio **2.1**. The authoritative field reference for the installed version is `doc-html/auxiliary/mod-structure.html` under the game install (`CLAUDE.local.md` has the path) — check it before the web; the online wiki page is a redirect stub. `data/base/`, `data/space-age/` and anything in `exemples/` show how real mods actually write these.

## Folder naming

An unpacked mod folder must be `<name>` or `<name>_<version>`, and both must match `name` / `version` in its `info.json` **exactly**, or Factorio silently won't load it.

## Anatomy

Only `info.json` is mandatory. Everything else is read automatically **if present, at the mod root** — the game finds these by name, so nothing is registered or wired up:

| File | Purpose |
|---|---|
| `info.json` | Identity, version, dependencies. The only required file. |
| `changelog.txt` | Player-facing history, shown in the in-game mod browser. |
| `thumbnail.png` | Mod portal / browser icon. **144×144**. |
| `settings.lua`, `settings-updates.lua`, `settings-final-fixes.lua` | Mod configuration options. |
| `data.lua`, `data-updates.lua`, `data-final-fixes.lua` | Prototypes. |
| `control.lua` | Runtime scripting. |

Recognised subfolders: `locale/`, `migrations/`, `scenarios/`, `campaigns/`, `tutorials/`. Anything else is yours to organise.

## Organizing prototypes and scripts

Not enforced by the game — file location never matters to the loader. The convention `exemples/` mods and the wider community converge on is in the **`factorio-mod-development`** skill (`references/data-stage.md` → Organising the files, and `references/control-stage.md` for how `scripts/` modules get wired into `control.lua`). In brief: `prototypes/<category>/<name>.lua` one file per thing, subfolder names mirroring which data-stage file requires them, and `scripts/<system>.lua` one file per runtime feature.

`require()` separators are a readability choice, not a correctness one — Factorio caches by resolved file, so `require("scripts.foo")` and `require("scripts/foo")` return the same table and run the file once (tested on 2.1.14). Pick dots and stay consistent.

## `info.json`

Mandatory: `name`, `version`, `title`, `author`. Effectively mandatory: `factorio_version`. Optional: `contact`, `homepage`, `description`, `dependencies`, and the feature flags.

```json
{
  "name": "my-mod",
  "version": "0.1.0",
  "title": "My Mod",
  "author": "<your name or handle>",
  "factorio_version": "2.1",
  "homepage": "<repository or mod page URL>",
  "description": "One or two sentences. This is the only description the in-game browser shows.",
  "dependencies": ["base >= 2.1.0"],
  "package": { "ignore": ["CLAUDE.md", "CLAUDE.local.md"] }
}
```

- **`name`** — the identity for everything: folder name, zip name, `__my-mod__` path prefix, locale keys, dependency strings, and the commit scope. Changing it after release is a new mod, not an update. Portal rules are stricter than the game's: alphanumerics, dashes and underscores only, 4–49 characters.
- **`version`** — `number.number.number`, each 0–65535. **Not semver**, and the game attaches no meaning to the parts. Must be bumped for every portal upload; the portal rejects a re-used version.
- **`factorio_version`** — exactly **two** numbers (`"2.1"`). A third number gets the mod rejected by the portal. Defaults to `"0.12"` if omitted, so always set it. A mod declares exactly one major version and the game enforces it: loading a `"2.0"` mod in 2.1 fails with `Incompatible Factorio version`, and there is no range syntax. Reaching both live versions means two builds — see the `factorio-multiversion` skill.
- **`title`** / **`description`** — overridable per language via the `[mod-name]` / `[mod-description]` locale categories, keyed by the mod's `name`. The game rejects a `title` over 100 characters; the locale entry has no such limit.
- **`author`** — free-form, but the portal ignores it and displays the uploading account instead.
- **`package`** — fmtk config, ignored by the game. **The `ignore` list is not optional** — `CLAUDE.md` is not a dotfile and would otherwise ship to the mod portal. See the `factorio-release` skill.
- **license** — not a field here; there is no `info.json` key for it. Every mod in this repo is GPLv3 (repo `CLAUDE.md` → License). The license travels as a `LICENSE` file at the mod root instead — copy it from the repo root's `LICENSE` — plus the mod portal's own license selector at publish time (`factorio-release` skill).

## Dependencies

Format is `"<prefix> mod-name <operator> <version>"`, e.g. `"? flib >= 0.16.2"`. Operators: `<`, `<=`, `=`, `>=`, `>`.

| Prefix | Meaning |
|---|---|
| *(none)* | Hard requirement. Loads before this mod. |
| `!` | Incompatible — both cannot be enabled. Any version is ignored. |
| `?` | Optional. Loads first if present. |
| `(?)` | Hidden optional — same as `?`, but not advertised in the mod browser. |
| `+` | Recommended. Optional, but **auto-enabled** with this mod in the mod manager. New in 2.1. |
| `~` | Required, but **does not affect load order**. Use to break a dependency cycle. |

Prefixes combine: `"+~ some-mod"` recommends without touching load order.

Gotchas worth knowing:

- `dependencies` defaults to `["base"]`. Declare it explicitly with a version floor — `"base >= 2.1.0"` — rather than relying on the default.
- A **version on an optional dependency is still enforced**. `"? some-mod >= 2.0"` disables this mod when `some-mod` is present at 1.9. Omit the version if a genuinely-any-version optional is what's meant.
- Load order is what makes `data-updates`/`data-final-fixes` predictable. Adding `?` on a mod you patch is how you guarantee its prototypes exist before you touch them.
- Large mods (Krastorio 2, Space Exploration) use all six prefixes at scale, including long `!` incompatibility lists — worth reading if `exemples/` is populated locally.

## Space Age feature flags

Boolean `info.json` fields, all defaulting to `false`. Each unlocks a set of prototypes or properties and **requires the player to own Space Age**. Set only what is actually used — each one narrows the audience:

`quality_required` (quality levels), `rail_bridges_required` (elevated rails), `spoiling_required` (`spoil_result`, `spoil_ticks`), `freezing_required` (`heating_energy`), `segmented_units_required` (`SegmentedUnitPrototype`), `expansion_shaders_required` (space/lava/fog render effects), `expansion_required` (belt stacking), `space_travel_required` (everything else Space Age, and implies `expansion_required`).

Full property lists per flag are in `doc-html/auxiliary/mod-structure.html`. `data/space-age/info.json` shows a real declaration.

**Declaring is not how you use expansion content — reading is.** The same flags are exposed at
the settings and data stages as a global `feature_flags` table, keyed with underscores
(`feature_flags["freezing"]`, `["rail_bridges"]`, `["space_travel"]`). It is true whenever *any*
loaded mod declared the matching `*_required`, which Space Age always does. So an optional-SA
mod tests the flag and sets the gated property inside that branch, declaring nothing itself:

```lua
if feature_flags["freezing"] then
  beacon.heating_energy = "600kW"   -- gated property; illegal without the flag
end
```

Reading a flag that is off is safe — it is `false`, not an error, unlike indexing a startup
setting that was never defined. Declare `*_required` only when the mod is *worthless* without
the expansion; it makes ownership mandatory and there is no partial mode.

## Locale

`locale/<lang>/<anything>.cfg`, INI-style. `en` is the fallback and must always exist. Filenames are arbitrary and all `.cfg` files in the folder are merged; the section headers are what matter.

```ini
[mod-name]
my-mod=My Mod

[mod-description]
my-mod=Shown in the in-game mod browser.

[mod-setting-name]
my-mod-enable-towers=Enable heat exchanger towers

[mod-setting-description]
my-mod-enable-towers=Disable to use towers from another mod.

[entity-name]
heat-exchanger-tower=Heat exchanger tower

[item-name]
heat-exchanger-tower=Heat exchanger tower
```

`[mod-name]` and `[mod-description]` are keyed by the mod's `name` and override `info.json`; the setting categories are keyed by the setting's `name`. Prototype categories follow `[<prototype-kind>-name]` / `[<prototype-kind>-description]`.

A missing key renders in-game as `Unknown key: "…"` rather than failing — grep `factorio-current.log` after adding prototypes.

## Mod settings

`settings.lua` uses `data:extend` like any other prototype stage. Types: `bool-setting`, `int-setting`, `double-setting`, `string-setting`, `color-setting`.

```lua
data:extend({
  {
    type = "bool-setting",
    name = "my-mod-enable-towers",
    setting_type = "startup",
    default_value = true,
    order = "a1",
  },
})
```

- `setting_type` is `"startup"` (read in the data stage, locked once a save exists), `"runtime-global"` (per-save, admin-changeable) or `"runtime-per-user"`.
- Prefix every setting name with a short mod tag (`kr-`, `se-`) — the namespace is global across all mods.
- Read them as `settings.startup["my-mod-enable-towers"].value` in the data stage, `settings.global[...]` at runtime.
- `order` controls GUI position; without it the list is alphabetical and looks arbitrary.

## Migrations

`migrations/` handles saves made with an older version. Each file runs **once per save**, recorded by name — so never edit or rename a shipped migration, add a new one.

- **`.json`** — renames a prototype: `{"entity": [["old-name", "new-name"]], "item": [["old-name", "new-name"]]}`. Renaming an entity preserves its `unit_number` and any stored references; changing its *type* does not, and invalidates them.
- **`.lua`** — fixes up `storage` and game state. The `game` object is available. Recipes and technologies are reset automatically on any prototype change, so migrations no longer need to do that.

All JSON migrations run before any Lua migration; within each kind, order is by mod load order then **lexicographic filename**. Name files after the version that introduced the change (`0.2.0.json`) and be aware that lexicographic sorting puts `0.10.0` before `0.2.0` — zero-pad if a mod ever gets that far.

Renaming or removing a prototype without a migration breaks existing saves — that is the change that pairs with a major version bump and a `BREAKING CHANGE:` commit. See the `factorio-release` skill.

## New-mod checklist

1. Folder named `<name>` or `<name>_<version>`, matching `info.json`.
2. `info.json` with `factorio_version: "2.1"`, an explicit `dependencies` floor, and `package.ignore` covering `CLAUDE.md` / `CLAUDE.local.md`.
3. `locale/en/<name>.cfg` with at minimum `[mod-name]` and `[mod-description]`.
4. `changelog.txt` with an initial section matching `version` — see the `factorio-changelog` skill.
5. `thumbnail.png` at 144×144.
6. `LICENSE` at the mod root — copy of the repo root's GPLv3 text. Don't add it to `package.ignore`; it needs to ship.
7. `README.md` — player-facing mod description. Include an **AI-Assisted Development** section before the License section, with the exact text: "The development of this mod was done with help of AI coding assistants."
8. Add the folder to the **Mods in this repo** list in `CLAUDE.md`, and check `.gitignore` doesn't swallow it.
9. Validate the data stage — see the `factorio-validate` skill.
