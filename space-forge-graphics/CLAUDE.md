# CLAUDE.md — Space Forge Graphics

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

The art half of **Space Forge** — sprites, icons and sounds, and nothing else. It is a **pure
asset container**: no `data.lua`, no `control.lua`, no Lua of any kind. Enabling it alone
changes nothing in game, which is exactly what it is for.

**Nothing is in it yet.** `info.json`, locale, changelog and licence only.

**Unpublished.** No `space-forge-graphics_*` git tag exists, so version `0.1.0` is the open
changelog section (`Date: ????`) until the first authorised release.

## The one rule

**Never add Lua here.** A mod with no data stage cannot break another mod's load, cannot
conflict, and can be updated without touching anything that runs. The moment it defines a
prototype it stops being safely separable and the whole point of the split is gone. Prototypes
belong in `space-forge`; this mod only supplies the files those prototypes name.

Verified against both mods that do this at scale: `space-exploration-graphics` (parts 1–5) and
`Krastorio2Assets` in `exemples/` — neither ships a single `.lua`.

Consequences worth having written down:

- **`space-forge` references everything as `__space-forge-graphics__/graphics/...`.** Moving or
  renaming a file here silently breaks that mod at load. Grep the other mod before either.
- **This mod never depends on `space-forge`** — that would be circular. Its only dependency is
  `base`.
- **Version independently.** `space-forge-graphics` has its own sequence and its own
  `changelog.txt`; art-only work is recorded here, not in the other mod. When new art lands,
  bump this version *and* raise the `"space-forge-graphics >= x.y.z"` floor in `space-forge`'s
  `info.json` — that floor is what turns a missing-file crash into "please update".
- A release is **two uploads**, one per mod.

## Layout

Nothing exists yet. This is the shape to grow into, mirroring the game's own
`data/base/graphics/` split so a path is guessable from what it holds:

```
graphics/
  entity/<thing>/       entity sheets, shadows, working visualisations, remnants
  icons/                item, entity, fluid and recipe icons
  technology/           technology icons
  equipment/            equipment-grid art
  particle/             explosion and impact particles
  terrain/              tiles, decoratives
  gui/                  custom GUI art, if any
sounds/                 .ogg, if any
thumbnail.png           144x144 — this mod's own, at its own root
locale/en/space-forge-graphics.cfg
```

**Art sources do not live here.** `.blend` scenes, textures, generator scripts and reference
go in `assets/space-forge-graphics/` at the repo root, mirroring the `graphics/` subpath the
renders land in. That is structural, not a `package.ignore` rule — a root folder with no
`info.json` is not a mod, so nothing can sweep a 200 MB `.blend` into the zip. See the repo
`CLAUDE.md` → Asset sources.

## Working here

- Commit scope is `space-forge-graphics`.
- **Never commit, push or publish unprompted** — approval is per request, per release.
- Invoke the `factorio-graphics` skill before any sprite, icon, thumbnail or Blender work,
  including the *design* step, which happens before modelling.
- `LICENSE` at the mod root is the repo root's GPLv3 text, copied verbatim.
- **There is nothing here to validate, and headless validation would not catch it anyway.** A
  run with both mods staged (2026-08-08, exit 0) reports `Checksum of space-forge-graphics: 0`
  — the checksum is computed over what the *data stage* reads, and this mod gives it nothing.
  Headless mode never loads sprites either, so a missing or misspelled `filename` in
  `space-forge` exits clean. **The only test for art is the running game.**
- **`thumbnail.png` does not exist yet.** Needed before release; deliberately not stubbed.
