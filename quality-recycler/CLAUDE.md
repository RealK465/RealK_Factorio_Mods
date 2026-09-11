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
directions at **six** layers each, plus the item and technology icons. No `thumbnail.png` yet.

**The hero rotor turns about Z, and that is not a style choice.** This rig scales world Y and
world Z to the same 64 px in the row direction, so a ring about Z *or* Y projects as a true circle
-- but `set_direction()` rotates the model about Z, which turns a Y-axis ring into an X-axis one in
east and west, and an X-axis circle projects to a LINE. A horizontal drum is round in two rotations
and flat in two. **On a rotatable entity a Z-axis rotor is the only radial form that reads in all
four**, and the first build's missing east and west hero is what that costs. Reasoning in
`.ai-support/quality-recycler-design.md` -> *The rotor axis*.

**A recess has to be built as a recess.** A dark box laid over an opening in a solid hull is still
a solid box: the shredder maw shipped that way and all three rollers and all three tooth rings drew
exactly zero pixels in every rotation. Build the hull as spans AROUND the opening, and size the
opening against the depth -- at 45 degrees a ray entering at the lintel drops one tile of z per
tile of y, so a 0.12-deep recess shows only the top 0.12 tiles of its back wall.

**Tune the palette on rendered swatches, never on hex codes.** `swatch.py` renders every material
as a lit stepped block through the entity's own rig and `measure_swatch.py` prints what it became.
That is how `bronze` was caught rendering (113, 115, 78) -- green-dominant grey, because `patina`
(`#39685B`) stayed at 0.52 after zone 2 stopped being verdigris -- and how the olive was caught at
hue 48, red-dominant khaki, where the vanilla recycler's own measures hue ~78.

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
edge the cone still allows a 0.97-tile wall. Keep the **hull** inside ±1.32 and spend the height
there; a wall hanging past its own tiles buys nothing and costs the front elevation.

**LOW hardware past the footprint is a different matter, and vanilla spends it.** The cone bounds
height, not reach: at ground level it allows a part out to ±2.25. The chemical plant's sprite is
145 screen px tall against a 96 px footprint and gets nearly all the excess from pipe stubs at
z ≈ 0. This entity's loading apron, scrap chute and output chute hang to ±2.05 below z 0.35, which
is what took the sprite from 86×112 screen px to 102×134.

**Two things the numeric gates cannot see, both of which shipped once.** They read the output
PNG, so a sprite can be green on luminance, contrast, saturation and silhouette and still be
the wrong machine — that is exactly what happened here. And `ragged` is alpha perimeter over
bbox perimeter, so raggedness is bought with **holes** (open railings, ladders, cables in clear
air) and *lost* by adding solid parts.

**Never steer the paint-over by luminance sd — split it into form and grain.** Contrast above
12 px against contrast below 3 px: vanilla carries its at ratio 0.61 (recycler) to 1.08 (chem
plant), and raising `form_amount` to hit an sd target buys the number by *smoothing* the
machine. This entity sat inside the sd band through two rejected builds at ratio 1.25.
Settled: `form_amount` 0.30 with `contrast_amount` 1.35 and `crevice_amount` 1.30. Reasoning in
`.ai-support/quality-recycler-design.md` → *Built*.

**This entity rotates, so it has four front elevations.** "A side wall renders as a one-pixel
line" is a fixed-entity rule. The west wall is the front in east, the north wall in south, the
east apron in west — every one of them needs stiles, rails and a focal point, or three
rotations read as blank painted plates.

**Nothing may stand on a deck that is already at the cone limit; spend the detail downward.**
The rear deck tops out at 1.06 where `cone_z` allows 1.07, so a cooler on it measured 2.48 and
`fit_cone()` refused rather than shrink the machine 9% to hide it. A recessed louvre bank reads
the same at 30 px and costs no height.

**Check the glow sheet separately — it hides faults the base sheet cannot show.** Three shipped
at once here: a beacon clipped to pure white (keep colour x strength near 1.0), and a violet
pair buried inside the rear deck so the south view had no field at all. Measure lit pixels and
per-channel maxima per direction, not by eye.

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
graphics/entity/quality-recycler/  base, anim (64f), shadow, fx (64f),
                            light (64f) and lamp per direction, for N/E/S/W and
                            the mirrored set, each with the `.lua` sidecar
                            util.sprite_load reads
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

`assets/quality-recycler/entity/quality-recycler/` at the repo root holds the Blender sources.
Since the 2026-09-11 rebuild they are split by job, and all of them import the first:

| file | what it is |
|---|---|
| `quality_recycler_gen.py` | materials, geometry helpers, the cone rule, the direction transform, `audit()`, `fit_cone()` |
| `qr_rebuild.py` | the curved primitives the above could not make -- `ring()`, `torus()`, `radial_bars()`, `barrel()`, `hood()`, `wall_chevrons()` -- plus the Phase 1 look-dev variants |
| `qr_layout.py` | **the machine**: masses, hero, junction, grading unit, tertiary hardware |
| `qr_anim.py` | the eight working systems and the idle |
| `render_entity.py` | headless bake, six layers x eight directions |
| `lookdev.py` | one-frame look-dev at sprite density and 4x |
| `swatch.py` / `measure_swatch.py` | every material as a lit block, and what it measures |
| `show.py` | paint over a look-dev frame, composite on Nauvis, print the four numbers that move this sprite |
| `make_sheets.py` | paint-over per frame, pack, write the sidecars and `sheet_numbers.txt` |
| `make_look.py` | the settled paint-over `POST` dict -- every other tool imports it from here |
| `preview_game.py` | composite the packed sheets the way the engine draws them, on real terrain, beside real vanilla machines, with night and looping GIFs |
| `check_sheets.py` / `check_wear.py` / `check_visibility.py` | the gates, the edge-wear mask, the object-ID pass |
| `versions/` | the untouched pre-rebuild `.blend` and generator |

Only exported PNGs land in `graphics/`. See the repo `CLAUDE.md` → *Asset sources*.

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
- **Run the object-ID pass before judging any change to the model** —
  `blender -b -P check_visibility.py -- <dir> --dirs N,E,S,W` in the entity's asset folder.
  Every part gets a flat colour off a value lattice and a pixel count. It has caught, twice
  over, faults nothing else can see: the ring gear buried in a wall, the radiator inside the
  rear deck, the whole capacitor bank embedded in a 0.14-tile apron, and a fan "ring" built
  with `cyl()` lidding the hub it was meant to surround. **60 of 213 objects once drew nothing
  at all.** The design's *Built* section says what it found and the two ways the tool lies.
- **`cyl()` makes a solid disc, not a ring** -- which is why `qr_rebuild.py` exists. It carries
  `ring()` (a true annulus or arc on any axis), `torus()`, `radial_bars()`, `barrel()`, `hood()`
  and `wall_chevrons()`. Reach for those rather than stacking `cyl()`s; the old failure mode was
  invisible in a render and obvious only in the object-ID pass.
- **A part the pass calls dead is not always a part to move.** Three here were deleted instead:
  in north the drum occludes them and in south the rear deck does, so no wall could be opened
  to reveal them. Check what the occluder actually is before rebuilding around it.
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
