# CLAUDE.md — Quality Recycler

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

A new recycler kind: **12% base quality chance built in (no modules needed), 2x the vanilla
crafting speed, a 3x3 footprint, unlocked after the first three planets.** The verified mechanism
and how that compares to the vanilla recycler are in `.ai-support/decisions.md`. **The entity,
item, recipe and technology exist and the data stage loads clean** (2026-09-10). Nothing has been
played yet, and the balance is a guess rather than a measurement — see `.ai-support/deferred.md`.

The entity's visual design is settled — a salvaged vanilla recycler with planet-tier sorting gear
grafted on, hero an eddy-current sorting rotor. It lives in
`.ai-support/quality-recycler-design.md`, and it also sets the mod's house art style, since there
is no separate art-direction register. **The entity is modelled, animated and rendered** — sources
in `../assets/quality-recycler/entity/quality-recycler/`, sheets in `graphics/entity/`, eight
directions at four layers each, plus the item and technology icons. No `thumbnail.png` yet.

**The massing is a cone, and it has to stay one.** A rotatable entity has four north edges, so
every vertex must satisfy `max(|x|,|y|) + z <= 2.27` or it draws over the machine behind it in
some rotation — 0.77 tiles of overhang, the chemical plant's, which is vanilla's ceiling for a
rotatable machine. `cone_z()` is the rule, `audit()` checks it on every build, and `fit_cone()`
takes up the last couple of percent with one uniform scale. Reasoning in
`.ai-support/quality-recycler-design.md` → *the rotation cone*.

**Measure opaque pixels, never a declared sprite box.** The vanilla recycler's east sheet
declares 0.86 tiles of overhang and fills 0.69; the other 0.17 is the packer's padding. Trusting
the declared number pushed this entity's budget 0.05 past anything Wube ships.

**But the cone is not what flattens a machine — leaving the footprint is.** At the footprint
edge the cone still allows a 0.97-tile wall. Keep the hull inside ±1.32 and spend the height
there; a part hanging past its own tiles buys nothing and costs the front elevation.

**Two things the numeric gates cannot see, both of which shipped once.** They read the output
PNG, so a sprite can be green on luminance, contrast, saturation and silhouette and still be
the wrong machine — that is exactly what happened here. And `ragged` is alpha perimeter over
bbox perimeter, so raggedness is bought with **holes** (open railings, ladders, cables in clear
air) and *lost* by adding solid parts.

## Layout

```
info.json                  base, quality, recycler, space-age
data.lua                   requires the two prototype files, in order
prototypes/recycler/entity.lua    the furnace, built from scratch (see Decided)
prototypes/recycler/item.lua      item, recipe and technology
prototypes/recycler/pictures.lua  graphics_set and graphics_set_flipped
changelog.txt
LICENSE
README.md
locale/en/quality-recycler.cfg
graphics/entity/quality-recycler/  base, anim (64f), shadow and light per
                            direction, for N/E/S/W and the mirrored set, each
                            with the `.lua` sidecar util.sprite_load reads
graphics/icons/            item icon, 120x64 mipmap strip
graphics/technology/       technology icon, 480x256 mipmap strip
.ai-support/index.md       the map -- read it first
.ai-support/decisions.md   what is settled, and why
.ai-support/quality-recycler-design.md   the entity's visual design -- read before any art
.ai-support/deferred.md    open questions and parked work
.ai-support/journal.md     dated sessions, newest first
```

**No sprite numbers live in the Lua.** Every width, height and shift is in the
`.lua` sidecar beside its PNG, written by the generator's `make_sheets.py`, so a
re-render never touches `prototypes/`. Two traps that cost a validate each:
`sounds` and `hit_effects` are globals inside base's own data stage and must be
`require`d by file, and **`frame_count` in a sidecar is ignored** --
`util.sprite_load` reads only width/height/shift/line_length from the file and
takes everything else from its options table.

`assets/quality-recycler/entity/quality-recycler/` at the repo root holds the Blender sources -
`quality_recycler_gen.py` (the model, rebuilt from source on every run), `make_look.py`
(paint-over, gates, vanilla A/B) and `quality-recycler.blend`. Only exported PNGs land in
`graphics/`. See the repo `CLAUDE.md` → *Asset sources*.

No `control.lua` is expected for a data-only entity. If the mechanic turns out to need runtime
scripting, that is itself a decision to record in `decisions.md` before writing it, not something
to fall into.

## Dependencies

`["base >= 2.1.0", "quality >= 2.1.0", "recycler >= 2.1.0", "space-age >= 2.1.0"]`, and
`quality_required: true`. Reasons — why `recycler` is declared explicitly rather than left as
`quality`'s transitive dependency, why `expansion_required` is deliberately not set, and why
`space-age` had to be added rather than moving the technology gate — are in
`.ai-support/decisions.md`.

## Working here

- Commit scope is `quality-recycler`. Repo-wide changes use `repo`.
- **Never commit, push or publish unprompted** — repo `CLAUDE.md`, and approval is per request.
- **`.ai-support/` is this mod's local context — start at its `index.md`.**
- **Validate after any prototype edit** — `factorio-validate`, about five seconds. It has already
  caught two things nothing else would have: `hit_effects` needing a `require`, and a
  `frame_count` written into a sidecar where `util.sprite_load` ignores it.
- **Run the object-ID pass before judging any change to the model.** Every part gets a flat
  unique colour and a pixel count; it has already caught six occlusion faults nothing else could
  see. The design's *Built* section says what it found and the two ways the tool itself lies.
- The next step is to **put it on a real map**. The data stage loads clean, which says nothing
  about whether the machine is worth building, how the animation reads at gameplay zoom, or
  whether any rotation has a fault an offline check cannot see.

## Decided

- Name `quality-recycler`, title "Quality Recycler". `embedded-quality-recycler` and
  `recycler-quality` were the alternatives considered; all three were free on the mod portal.
- Version starts at `0.1.0`, unpublished (`changelog.txt` carries `Date: ????`).
- Dependencies and feature flags as above.
- **The mechanic: `effect_receiver.base_effect.quality = 0.12`, `crafting_speed = 1.0`, a 3x3
  footprint** at `collision_box = {{-1.2,-1.2},{1.2,1.2}}`. Verified mechanism and the
  vanilla-recycler comparison in `.ai-support/decisions.md`.
- **Unlocked after the first three planets** — metallurgic + electromagnetic + agricultural
  science, no cryogenic. Reason and the verification in `.ai-support/decisions.md`.
- **Rotatable: four directions plus mirrored**, the full vanilla recycler treatment. This is the
  mod's largest art cost and it was chosen deliberately over the cheaper non-directional option.
- **Art direction settled** — see `.ai-support/quality-recycler-design.md`.

- **Prototype `quality-recycler`, its own technology `quality-recycling`**, 600kW / 400 health /
  4 module slots / 4 pollution, recipe built on a whole `recycler` plus one material from each of
  the three planets. All chosen 2026-09-10 — reasoning in `.ai-support/decisions.md`.
- **Built from scratch, not deep-copied from the vanilla recycler.** A deepcopy carries its 2x4
  collision box, circuit connectors, `vector_to_place_result` and frame-synced working sound,
  every one of them positioned for a different machine.

Balance is unmeasured, and sounds, `water_reflection`, a circuit connector and a real remnant are
still open. See `.ai-support/deferred.md`.
