# Quality Recycler — art log

Working log for the 2026-09-11 rebuild: decisions with a one-line reason, render settings, frame
counts, budgets, current status. A fresh session should be able to continue from here.

Sources live in `assets/quality-recycler/entity/quality-recycler/`; shipped sheets in
`quality-recycler/graphics/entity/quality-recycler/`. The mod's own registers
(`quality-recycler/.ai-support/`) remain the source of truth for settled design — this file is the
working record of the rebuild.

---

## Status

**Complete.** Direction B approved by the repo owner 2026-09-11 and built through Phase 7. All
48 sheets are packed into `quality-recycler/graphics/entity/quality-recycler/`, the data stage
loads clean, and every gate passes.

**Nothing has been photographed in the engine.** The renderer is the only place render-layer
order, `draw_as_glow` blending, `fadeout` and the `always_draw` status lamp actually resolve, and
a rotation-specific fault is invisible to an offline check. `scripts/screenshot/shoot.ps1` is the
harness; this is the first thing the next session should do.

Deliverables: previews in `docs/art/quality-recycler/previews/`, the Phase 1 brief in
`phase1-brief.md`, sources in `assets/quality-recycler/entity/quality-recycler/` with the
untouched pre-rebuild scene in its `versions/`.

Safety copies taken before any edit, never overwritten:
`assets/quality-recycler/entity/quality-recycler/versions/quality-recycler-v0-original.blend`,
`versions/quality_recycler_gen-v0-original.py`.

---

## Phase 0 — Audit

### What was read

`quality-recycler/.ai-support/quality-recycler-design.md` (621 lines, the source of truth),
`decisions.md`, `index.md`, the mod's `CLAUDE.md`, `info.json` (factorio_version 2.1),
`prototype.png` (the owner's concept sheet), and the whole render pipeline —
`quality_recycler_gen.py` (131 KB), `render_entity.py`, `make_sheets.py`, `make_look.py`,
`check_sheets.py`, `check_wear.py`, `check_visibility.py`, `preview_sheets.py`.

No in-game screenshot was supplied: the brief's `<setup>` block was left as placeholder paths and
nothing named `ingame-current.png` exists under the development folder. The baseline was therefore
rebuilt from the shipped sprite sheets with the repo's own compositor, `preview_sheets.py`, which
draws them the way the engine does.

### The pipeline works and is kept

- Four layers per direction (`base`, `anim` 64f, `shadow`, `light` 64f) across eight directions.
  The anim layer renders with the body as a Cycles holdout, so the overlay carries correct
  occlusion. Right structure; the rebuild keeps it.
- `check_visibility.py` (object-ID pass to scene-linear EXR) and `check_wear.py` (the only check
  that measures the model rather than an output PNG) both work.
- The cone rule `max(|x|,|y|) + z <= APEX`, `APEX = 2.25`, is correct and non-negotiable for a
  rotatable 3x3. Every rebuilt part must satisfy it.

### Every numeric gate is green and the sprite is still wrong

`check_sheets.py` on the shipped art, all eight directions: contrast sd 49.9–53.4 (band 43–56),
clipping 0.00%, full-width rows 0% everywhere, fill 0.83–0.87, ragged 0.98–1.30, shadow 100% pure
black, worst north overhang 0.77 tiles against vanilla's 0.77 ceiling. **FAILURES: none.**

That is the finding, not a footnote. The gates read the output PNG, so they cannot see that the
machine is the wrong machine.

### Measured: the sprite is grey where vanilla is chromatic

Colour-family census over opaque pixels (alpha >= 200); hue bands in degrees; `grey` is the
fraction below saturation 0.18.

| sprite | lum mean | p50 | dark <70 | light >=130 | olive 40–95 | copper 10–40 | violet 250–320 | grey |
|---|---|---|---|---|---|---|---|---|
| vanilla recycler N | 67.0 | 63 | 55.0% | 9.4% | 12.0% | 35.2% | 0.9% | **31.4%** |
| vanilla chemical plant N | 63.0 | 47 | 68.2% | 11.3% | 25.7% | 61.3% | 0.0% | **12.3%** |
| vanilla EM plant (base) | 30.9 | 25 | 88.1% | 0.6% | 1.2% | 48.9% | 0.0% | 42.2% |
| **ours N** | 60.2 | 45 | 62.6% | 12.4% | **14.1%** | 20.3% | **4.6%** | **41.2%** |
| ours E | 60.0 | 41 | 65.9% | 12.8% | 19.0% | 23.0% | 2.4% | 37.4% |
| ours S | 58.1 | 40 | 65.7% | 10.6% | 18.2% | 25.2% | 1.7% | 36.0% |
| ours W | 62.2 | 47 | 61.5% | 12.7% | 18.9% | 23.4% | 3.6% | 40.0% |

Three things fall out of it:

1. **41% of the sprite is neutral grey**, against the vanilla recycler's 31% and the chemical
   plant's 12%. The low-contrast read is a *chroma* failure, not a value failure — the value split
   is already close to vanilla. A machine made of grey with accents dropped on top reads flat
   however well its luminance histogram behaves.
2. **The olive half is 14–19% of pixels and the violet half 1.7–4.6%.** "Two technologies joined"
   cannot survive that. What is left is a grey machine with a copper tinge; copper is the largest
   chromatic family at 20–25%.
3. Median luminance 40–47 against the vanilla recycler's 63. The mid-tones that separate top faces
   from walls are missing.

### Measured: what the sprite actually looks like

Composited on Nauvis dirt at sprite scale and at 2x, all eight directions. Each of these is in
addition to the owner's own critique, which the audit confirms in full.

- **The hero rotor reads as a standing barrel, not a rotor.** The drum is on Y so it survives the
  projection (the design doc's reasoning is correct and stays), but at 1.46 long and mounted high
  it presents its *curved flank* with vertical ribs on it — barrel staves. The copper end flange
  and bolt circle, the parts that would say "rotor", are turned mostly away. It occupies roughly a
  third of the sprite saying the wrong thing.
- **A large smooth pale hood arcs over the drum and is the brightest large form in the sprite.**
  Featureless, and the first thing the eye lands on; it reads as moulded plastic. The value
  hierarchy is inverted — the calm surface is lightest and the hero is darker than it.
- **The shadow is a detached hard-edged slab to the right.** 100% pure black, passes the gate, but
  its outline does not follow the machine's, so it reads as a separate object.
- **The emissives are two large saturated blobs** — a magenta bar across the middle, an amber
  beacon — plus scattered dots. Neither says what the machine is doing, and the magenta bar sits
  exactly where the sorting gap should read.
- **No hazard chevrons are visible in the north view at all**, barely in south. The concept
  sheet's most recognisable feature is absent from the sprite.
- **The front elevation is a letterbox**, which the design doc already records as the price of the
  rotation cone. It is real: the machine reads closer to plan view than vanilla's 3x3s do.
- **Detail is uniform in size** — 186 distinct kinds over 241 objects against an audited vanilla
  band of 8–15 kinds. The count is not itself the problem; the problem is that nothing is *large*,
  so the eye has nowhere to land.

### Conflicts between the brief and the design doc

- **Drum axis.** The concept sheet draws an east–west barrel; the design doc proves east–west is
  flat at this projection (every circular cross-section is edge-on) and built it about Y. The doc
  is right, the axis stays on Y, and what changes is the *presentation*.
- **"Keep the render rig."** Kept: camera, ortho scale 5.0, 64 px/tile, sun Y −39.3, Standard view
  transform, film transparent. The key/fill/ambient deviation (5.4 / 1.05 / 0.18 against the rig's
  validated 5.2 / 1.2 / 0.22) is part of what currently ships and is measured in the design doc, so
  it stays unless a side-by-side forces a change.
- **Module slots.** The brief says undecided; `decisions.md` settles them at 4. Gameplay is out of
  scope either way.

---

## Decisions

| # | Decision | Reason |
|---|---|---|
| D1 | Keep the four-layer split, eight directions, the cone rule and every existing check script | Correct, measured, and the failure is upstream of all of them |
| D2 | Keep the render rig unchanged | The owner asked for it and the sprites already sit correctly in game |
| D3 | ~~Rotor drum stays on the Y axis~~ — superseded by D5 | An east–west drum is geometrically flat at this projection, which is why the doc chose Y; a Z-axis rotor is flat in none |
| D4 | Treat the rebuild as a chroma problem first, not a value problem | Measured: 41% grey vs vanilla's 12–31%, with the value split already near vanilla |
| D5 | **The hero rotor moves to the Z axis** (a vertical poled disc) | A Z-axis ring is the only radial form that stays a circle in all four rotations; a Y-axis one is edge-on in east and west |
| D6 | Five quality lenses on a grading pod replace the four output bins | The brief asks for five indicators, and it retires the FFF-339 risk the design doc itself flagged against four bins |
| D7 | No frozen patch | It needs `heating_energy`, which is a gameplay change and out of scope. Follow-up. |
| D8 | `animation_speed = 2`, not the vanilla recycler's 4 | Crafting-machine animations scale with crafting speed, and ours is 1.0 against the recycler's 0.5 |
| D9 | Six sheets per direction: base / anim / fx / light / lamp / shadow | Fragments and glow must vanish when idle; the lamp must not. One `anim` layer cannot do all three. |

---

## Phase 1 — direction

Three blockouts built and rendered (`renders/review/01-direction/`): **A** horizontal drum under an
open cage, **B** vertical poled rotor disc, **C** horizontal drum inside a flat toroidal coil.
Rendered north and east at sprite density and at 4x, paint-over applied, composited on Nauvis dirt
at 1x and 3x.

**B wins on the projection arithmetic and on the image.** At 1x, A and C collapse into a pale ring
round a dark hole; B stays a spoked wheel. B also has the most cone headroom (worst
`max(|x|,|y|)+z` = 2.25 against APEX 2.25, with 0 objects over, north overhang 0.57 tiles).

B was then developed into direction **D** (`qr_layout.py`): rotor at (0.62, 0.44) radius 0.70,
14 copper poles, four guard arcs, a toroidal field coil above the hub; olive shredder in the
south-west with a swept intake hood and a 0.66 x 0.46-tile maw; grading pod with five up-facing
lenses in the south-east; coupling collar and a 0.26-tile slot between the halves; the north-west
kept low so the diagonal reads. 90 objects, 54 distinct kinds.

### Critique round 1 — findings, verified

An independent art-director pass returned five findings. Four checked out against measurement and
one did not:

| finding | verdict |
|---|---|
| The sprite is undersized | **Confirmed.** D is 86 x 112 screen px; the chemical plant (the true 3x3 peer) is 100 x 145. 23% short. |
| The olive is the wrong hue and far too dark | **Confirmed.** Vanilla recycler's olive-green measures (96, 106, 57) at luminance 101, saturation 0.47 — green-dominant by 10. D measures (53, 54, 35) at luminance 52 with no green bias at all. |
| The bottom band is solid across the full width, fusing the two masses | **Confirmed.** D's bottom 10% of rows is 0.91 solid; chemical plant 0.61, vanilla recycler 0.71. |
| The quality lenses render the wrong colours | **Confirmed by inspection.** They are emissive materials, so the emission washes the hue — rare renders cyan rather than navy. Fix: take the emission off the base and let the glow layer carry it. |
| "You are 17–21 points blockier than vanilla; vanilla fill is 58–65%" | **Wrong.** Measured fill: chemical plant 0.75, vanilla recycler 0.79, EM plant 0.88. D at 0.83 is inside the band. |

### Three defects fixed during Phase 1

- **Two tori were rendering with no material at all** (`rotor-flange`, `cage-boss`), so Blender's
  default grey — brighter than anything in the palette — put four white bullseyes round the rotor.
  `_emit()` in the generator now prints `[mat] <name> has NO MATERIAL` so it cannot recur silently.
- **The intake hood was a hollow arc**, showing its concave inside as a grey trough whenever an end
  faced the camera. `hood()` now closes both ends with a full plate across the chord.
- **The skirt stood in front of the maw and hid it completely.** Invisible in the model, fatal in
  the sprite; the skirt is three spans now, not one box.

### New tooling this phase

- `qr_rebuild.py` — the curved primitives the old generator could not make: `ring()` (a true
  annulus or arc, any axis), `torus()`, `radial_bars()`, `barrel()` (with a cosine bulge),
  `hood()`, `yz_prism()` and `wall_chevrons()` for hazard bands on any of the four walls. Plus the
  three Phase 1 variants and the five quality-lens materials.
- `qr_layout.py` — the rebuilt machine.
- `lookdev.py` — headless driver, sprite density and 4x, absolute output path.

### Budget

Measured on the shipped files: **58.7 MB VRAM** (anim 48.0, light 7.8, base 1.5, shadow 1.4) over
32 PNGs, 13.6 MB on disk. Vanilla peers, measured the same way: recycler **253 MB**, foundry 152,
EM plant 149, cryogenic plant 37, chemical plant 17. The six-sheet plan estimates **~115 MB**, which
is 45% of the machine we are replacing.

Render cost: 1,560 Cycles frames at 96 samples, GPU (HIP), persistent data — about 75 minutes.

### The preview compositor, and the measurement it produced

`preview_game.py` composites sheets the way the engine draws them — ground, then shadow, then base,
then the animation cell, then the glow **added** rather than alpha-composited — on real terrain
sheets read out of the game data (`base/graphics/terrain/grass-1.png`,
`space-age/graphics/terrain/fulgoran-dust.png`,
`space-age/graphics/terrain/aquilo/snow-flat.png`), with an approximate night pass and the real
vanilla recycler, electromagnetic plant and chemical plant beside ours at the same pixel density.
Verified end to end; outputs archived in `renders/review/01-direction/preview-shipped/`.

Putting our sprite beside the three real machines on real grass produced the sharpest measurement
of the session. **Vanilla concentrates its chroma into one hue band; ours scatters it.**

| | chromatic pixels (sat >= 0.18) | share of chroma in the single dominant 15-degree band | sat, p75 of chromatic |
|---|---|---|---|
| vanilla recycler | 68.6% | **44.2%** (0–15 deg) | 0.51 |
| vanilla chemical plant | 87.7% | **48.4%** (30–45 deg) | 0.75 |
| vanilla EM plant | 57.8% | **54.3%** (15–30 deg) | 0.52 |
| ours, shipped | 58.8% | **22.1%** | 0.54 |
| ours, direction D | 57.9% | **33.5%** | 0.57 |

Our saturation is already in vanilla's range. What is wrong is that the chroma is spread evenly
across olive, copper, bronze, violet and blue at comparable weights, so no hue owns the machine and
the eye integrates it to grey. Vanilla machines are each *one colour* with accents.

**This changes the Phase 3 target.** Not "more saturation" — **concentration**: get one warm family
(olive through bronze) to carry ~45% of the chromatic pixels, keep violet as a small deliberate
accent rather than a co-equal zone, and cut the incidental blue entirely.

Two other things the A/B shows plainly, both for Phase 2/3:

- **Vanilla shadows are soft and hug the machine**; ours is a hard-edged offset slab. The gate passes
  it (100% pure black, 15% soft edge) because it measures the wrong thing.
- **Vanilla machines break their own footprint box on several sides**; ours sits tidily inside it.

---

## Phases 2–4 — forms, materials, animation

Direction B approved. `qr_layout.py` is the machine, `qr_anim.py` the animation, `qr_rebuild.py`
the curved primitives and the Phase 1 variants. `quality_recycler_gen.py` keeps the materials, the
cone rule, the direction transform, the audit and every geometry helper, and is still what all of
them import.

### The layout

Two masses on a diagonal with a 0.24-tile slot between them.

| | |
|---|---|
| Hero | vertical eddy rotor at (0.60, 0.46), outer radius 0.72 — 46 screen px across in a 102 px sprite. 14 copper poles on a tempered carrier, over an open bore with an 18-slot stator in it, under four guard arcs and a toroidal field coil |
| Seam | a driven 20-tooth wheel in the slot, a copper coupling collar, a bolted strap up the shredder's east face, two swept conduits and two cables |
| Olive half | south-west: stepped hull, a swept intake hood, a 0.68 × 0.52-tile maw with three counter-rotating toothed rollers, hazard chevrons on the south **and** west walls, a loading apron with a feeder ram |
| Grading | south-east: five up-facing lenses in the exact quality colours on a tilted panel, a scan window, one output chute |
| Quiet | north-west kept at ankle height so the diagonal reads |

### The two size rules are not the same rule

`cone_z()` bounds HEIGHT (`max(|x|,|y|) + z <= 2.25`), so at ground level it allows a part to reach
2.25 tiles out — three quarters of a tile outside the footprint. Vanilla spends exactly that: the
chemical plant's sprite is 145 screen px tall against a 96 px footprint and gets the extra from
pipe stubs hanging south at z ≈ 0. The design doc's separate rule, "no hull past ±1.32", is about
the front elevation. Both are kept: the hull stays inside ±1.32 and low hardware (apron, scrap
chute, output chute) hangs to ±2.05 at z < 0.35. That took the sprite from 86 × 112 screen px to
**102 × 134**, against the chemical plant's 93 × 138 measured the same way.

### The silhouette guarantee, worked out rather than discovered

A row is full width only when both extremes fall in it, and which parts own the extremes changes
with the rotation. `audit()` collects every vertex within **0.06** of an extreme into that
extreme's row band — so a 0.07-tile cage boss at y 1.12 pulled in the rotor step, the capacitor
bank and two cable runs, and handed east a 0.96-tile band of full-width rows. One tie bracket
standing 0.12 proud of everything else owns max-y alone. **0% full-width rows in all four rotations
and both mirrorings, worst margin 0.09 tiles.**

### What the object-ID pass found

Run after every structural change, per the mod's own standing rule. First run on the rebuild: **52
of 204 objects drew nothing in any direction.** The worst of them:

- **The shredder maw was a SOLID dark block with the rollers buried inside it.** `maw-cav` was a
  filled box, not a recess, so all three rollers and all three tooth rings drew exactly zero pixels
  — the olive half's entire identity, invisible, with nothing in the render to say so. The hull is
  built from five spans around the opening now, and the maw is a back wall plus a floor with open
  air between.
- **The lintel was cutting off the top roller.** At 45° a ray entering at the lintel drops one tile
  of z per tile of y, so a 0.12-deep recess showed only down to z 0.57 and roller 2 sat at 0.58.
  The opening went to 0.52 tall and the rollers down a notch.
- The radiator, the deck vent and all six of its fins, three cable runs, a conduit's first joint
  and four cage feet were each inside something. All relocated.
- The four arc emitters sat directly under the guard arcs, so the fx layer came back with content
  in 51 frames of 64 and almost nothing in it.

Second run: the only objects drawing nothing are `arc1-3` and `frag1-3`, which are keyed **off** at
frame 0 and are therefore false positives of a one-frame pass.

### The nine animation systems

| # | system | layer | frames | closes on |
|---|---|---|---|---|
| 1 | eddy rotor, 14 poles | anim | 64 | 2 pole pitches, 0.80°/frame (limit 12.9) |
| 2 | drive wheel, 20 teeth, counter-rotating | anim | 64 | 5 tooth pitches, 1.41°/frame (limit 9.0) |
| 3 | three shredder rollers, 9 teeth, counter-rotating | anim | 64 | 4 pitches, 2.50°/frame (limit 20.0) |
| 4 | cooling fan, 5 blades | anim | 64 | 6 pitches, 6.75°/frame (limit 36.0) |
| 5 | feeder ram, one stroke | anim | 64 | returns to zero |
| 6 | four fragments in flight | fx | 64 | one per quarter loop |
| 7 | violet field pulse at the coil | light | 64 | two beats, phase-locked to the rotor |
| 8 | four Fulgoran arcs at the rotor contacts | light | 64 | a fixed irregular pattern, not random |
| 9 | grading scan sweep, five lenses lighting in sequence | light | 64 | two sweeps |
| — | green status lamp, never animates | lamp | 1 | always drawn |

`animation_speed = 2`, not the vanilla recycler's 4: a crafting machine's animation is scaled by
crafting speed unless `constant_speed` is set, and this machine is 1.0 against the recycler's 0.5.

**Loop seam, measured rather than assumed.** For each layer, the wrap step |f63 → f0| against the
distribution of the loop's own 63 other adjacent steps: `anim` wrap 0.135 against a median of 0.129
and a max of 0.202; `fx` wrap 0.045 against a median of 0.067. Both wraps are inside the loop's own
range, which is what seamless means. Comparing the wrap to |f0 − f1| alone gave a false "SEAM!" on
the fx layer, because a flicker's typical step *is* a discontinuity.

### The six sheets, and why

`base` (1f) / `anim` (64f) / `shadow` (1f) / `fx` (64f) / `light` (64f) / `lamp` (1f).

`anim` is a LAYER of `animation`, so the engine draws it always and merely stops advancing it when
the machine idles — right for a rotor, whose parked pose is part of the idle design. `fx` is a
`working_visualisation`, so the fragments vanish instead: a chip frozen in mid-air over a stopped
machine is a bug you cannot un-see. `lamp` is `always_draw`, so an idle machine still glows at
night; it is one frame of a few dozen pixels.

### Measured against vanilla, after the polish pass

| | quarter spread | local 5px sd | busy | luminance sd | grey | size |
|---|---|---|---|---|---|---|
| ours N | 20.3 | 33.2 | 66% | 45.7 | 15.5% | 102 × 134 |
| ours E | 31.7 | 34.4 | 65% | 48.8 | 16.7% | 106 × 111 |
| ours S | 31.8 | 32.6 | 64% | 48.3 | 13.6% | 102 × 109 |
| ours W | 33.3 | 32.6 | 64% | 48.2 | 16.7% | 106 × 128 |
| vanilla recycler | 27.7 | 29.2 | 56% | 44.5 | 31.4% | 70 × 144 |
| vanilla chemical plant | 48.5 | 27.1 | 44% | 50.4 | 12.3% | 93 × 138 |

Grey went 41% → 20% → 14–17%, now between the two vanilla references. Luminance sd is in the 43–56
band. The quarter spread — top-quarter mean minus bottom-quarter mean, which is what "light
direction" measures — went from 18 to 20–33 against the recycler's 27.7, bought by a darker olive
on the skirt (`olived`) and brighter metal at the skyline. Local 5 px sd stays 3–5 points above
vanilla; the sweep below says why.

### Two knobs that lied, and what settled them

- **The paint-over cannot fix model noise.** Sweeping `crevice_amount` from 0.95 to 0.40 moved
  local 5 px sd only 33.9 → 31.3 while luminance sd fell 48.4 → 47.2. The excess high-frequency
  contrast is in the geometry — 205 objects on a 3×3 — not in the post. What actually helped was
  deleting the parts the object-ID pass measured at 1–6 px.
- **`form_amount` improved every number and made the sprite worse.** At 0.55 the statistics were
  best in the sweep and the render came out bleached and milky: `form_contrast` has radius 11, so
  raising it lifts whole faces toward each other. Settled at **0.32 / contrast 1.12 / crevice
  0.75**, chosen by looking at the image with the numbers as a floor rather than a target.

### Critique round 2 (after materials) — what it found and what was done

| finding | verdict | action |
|---|---|---|
| The A/B sheet composites vanilla at double density | **Correct, and it was my bug.** `pg.draw` works at source resolution; our sprite was pre-scaled to 0.5. Any size conclusion drawn from that sheet was wrong. | Fixed; sizes re-measured from the sprites themselves |
| No light direction — the sprite is lit flat | **Confirmed, with different numbers.** Measured top-quarter mean 72.5 against the vanilla recycler's 84.5 and the chemical plant's 95.9 | Darker olive on the skirt, brighter metal at the skyline; spread 18 → 20–33 |
| Noisier than vanilla | **Confirmed.** Local 5 px sd 34.5–36.0 against the recycler's 29.2 and the chem plant's 27.1 | Paint-over eased and the sub-6 px parts deleted; now 32.6–34.4 |
| The olive is 2.5% of pixels | **Wrong.** Measured 8–13% of opaque pixels by the same method that gives the vanilla recycler 7.6% | none |
| The quality lenses render cyan at luminance 175 | **Not in this render.** The brightest saturated pixels measure (199, 138, 98) at luminance 148 — copper on the rotor, which is where the eye should land | none |
| No visible joint between the halves | **Fair.** One 11 px collar is a fitting, not a joint | Collar enlarged, plus a bolted strap up the shredder's east face and a rivet row along it |

---

## Phases 5–6 — render, pack, integrate, validate

**The bake.** 8 directions × 6 layers = 1,560 Cycles frames at 96 samples, GPU (HIP), persistent
data, run headless in the background with logs. About 80 minutes. A second pass of 528 frames
(base, glow, lamp) followed, for the reason in *The emission fix* below.

**Sheets.** 48 PNGs, 8.5 MB on disk, **99.4 MB of VRAM** (`width × height × 4` over every file):

| layer | VRAM |
|---|---|
| anim (64f) | 59.4 MB |
| fx (64f) | 26.9 MB |
| light (64f, half resolution at `scale = 1.0`) | 9.9 MB |
| base | 1.6 MB |
| shadow | 1.5 MB |
| lamp | 0.04 MB |

Against vanilla peers measured the same way: **vanilla recycler 253.2 MB**, foundry 151.8, EM
plant 147.7, cryogenic plant 36.8, chemical plant 16.1. We are at 39% of the machine we replace
and sit between the cryogenic plant and the EM plant.

The `fx` sheet is the least efficient thing here — 26.9 MB for four chips, because its union box
spans the whole flight path. Halving its resolution the way the glow sheet is halved would take it
to ~7 MB; it is a colour layer rather than a blur, so that was not done blind.

**Gates, on the packed sheets, all eight directions:** contrast sd 46.2–48.6 (band 43–56),
clipping 0.00%, **full-width rows 0% everywhere**, fill 0.65–0.76, ragged 0.96–1.31, shadow 100%
pure black, worst north overhang **0.77 tiles** — exactly vanilla's ceiling. `FAILURES: none`.
Edge-wear mask 9.7% bright / 20.0% survive, inside `gates.wear_mask`.

**Validation.** `validate.ps1 -ModPath quality-recycler` → **exit 0**, data stage loaded clean with
the six-layer graphics set, `graphics_set_flipped`, three working_visualisations and
`use_mirroring = true`.

### The emission fix, and why it cost a second pass

The additive glow sheet is drawn *over* the base sheet, and both carried the lens colour. Summed,
they clipped: the five quality lenses rendered as five **white** dots and the green status lamp as
a white one. That is the single feature the machine exists for.

Two changes, and the second is the interesting one:

- Lens emission 0.40 → 0.16, scan-sweep peak 1.70 → 0.80, lamp strength 1.2 → 0.65.
- **The lens base colours are pre-compensated, and are no longer the quality colours.** A 4 px lit
  dielectric under this rig carries a whitening floor of about **+105 per channel** from the key,
  the sky and the paint-over — no base colour undercuts it. Painted the true prototype values the
  row measured `normal (214,212,210)`, `uncommon (133,217,155)`, `rare (90,184,213)` — cyan, not
  navy — `epic (140,95,123)` — mauve, blue gone — `legendary (218,191,77)`. `LENS_BASE` in
  `qr_rebuild.py` is the corrected set, per channel, and the row now renders white / green / blue /
  purple / orange in the right order.

A third artefact surfaced in the same check: the scan bar appeared **twice**, frozen at the left of
the window in the static base sheet and sweeping in the glow. `scan` lives in `QR_Base` although it
moves. It is keyed to scale 0 at frame 0 now, so the base sheet carries no bar and idle means "not
scanning".

### The icon

Re-rendered from the new model. The first cut filled 64 × 51 of its 64 px square at 47% opaque,
against the **vanilla recycler icon's 60 × 62 at 79%** — a small dark lump with a margin round it.
An icon is not on the tile grid, so nothing forces it to show the whole footprint: `ORTHO` went
3.7 → 2.35 and the aim moved from the machine's centre to the **rotor**, which is its identity.
65% opaque now.

Elevation went 34 → 30 → **37**. Lowering it makes the silhouette taller, which is what a square
icon wants — and it also turns the rotor's face away from the light, so at 30 the hero rendered as
a dark ring with a violet centre and no copper in it at all. The height comes from the crop
instead.

---

## Phase 7 — polish and the final review

Previews built with `preview_game.py` from the packed sheets, at true game pixel density, on real
terrain read out of the game data (`base/graphics/terrain/grass-1.png`,
`space-age/graphics/terrain/fulgoran-dust.png`,
`space-age/graphics/terrain/aquilo/snow-flat.png`), with a night pass and eight looping GIFs.

**The GIFs play at the engine's rate.** `animation_speed = 2` is 120 frames a second, so a
64-frame loop takes 32 ticks. A GIF cannot hold 8.3 ms, so `animate()` takes every third frame at
25 ms. At the previous 30 ms per frame the preview ran **3.6× slow**, and a rotor judged there
reads as barely moving when in game it is brisk — a false negative that nearly cost a re-bake.

### Critique round 3 (final) — findings, verified, and what was done

The round returned **"ships"** with one high-impact item and five minor ones. Each was checked
against the light sheets themselves rather than taken on trust; one of its own numbers came from a
composite that included the compositor's white footprint box, and my first attempt to reproduce it
made the same mistake.

**High impact — the glow layer is out of balance and clipping.** Confirmed, with different
numbers. Measured on `quality-recycler-N-light.png` directly: the readout carried **52–79% of the
emitted light** depending on frame (the critique said 55%), several blobs clipped a few core
pixels, and the ladder was inverted — the *lowest* tier was the brightest lamp on the machine
(luma 103) while rare and epic sat at 28–42.

Its proposed fix — equalise the five to luma 165–190 — is not available, and the reason is worth
recording. **A saturated blue or purple cannot emit as much luminance as a green without being
desaturated**, so vanilla's own ladder is uneven for exactly that reason: normal 178, uncommon 129,
rare 95, epic 48, legendary 122. Equalising would have meant abandoning the hues.

What was done instead splits the lens's two jobs:

- **The albedo and the emission are now different colours.** `LENS_BASE` stays the
  pre-compensated albedo that lands the LIT disc on the prototype value; the emission is the
  prototype value itself, because the glow is added over the base and vanilla's ramp is what the
  sum should look like.
- **Strength is per lens, under two caps**: no channel above ~0.95 (Standard clips hard and a
  clipped lens takes its hue with it), and no lens emitting more than 0.55 luminance. The first
  binds rare, epic and legendary; the second binds normal and uncommon, which is what stops the
  lowest tier being the brightest thing on the machine.
- The overall multiplier landed at **0.10**, not the 0.22 first tried — at 0.22 the row came out
  brighter than the flat 0.16 it replaced and the five pips merged into one bar. 0.10 keeps the
  row's total where it was and spends the change on its *shape*.

Result: the five lenses measure luma **33.9 / 41.9 / 34.7 / 38.7 / 34.9** where they were
**28 / 103 / 42 / 46 / 51**, none of them merged, and lens-row clipping is 0–1 pixels per pip. The
status lamp came down from 0.65 to 0.45 for headroom, since it is drawn twice — lit in the base
sheet and added by its own `always_draw` glow layer.

**Minor findings.** Three fixed in the same pass; two recorded rather than fixed:

| finding | verdict | action |
|---|---|---|
| The maw reads as a louvre vent, not teeth — nothing dark for the tooth tips to cut into | Fair | New `pitch` material, darker than `cavity` (luminance 46), on the maw's back wall and jambs |
| The status lamp is a sixth identical bead ~10 screen px from the readout | Fair, and it was reading as a sixth quality tier | Moved up onto the shredder's cap at z 1.16 with a scoured hood and a stem |
| The bronze conduit is the lightest, softest thing in the mid-body — a pale worm at 1x | Fair | `seam-pipe1` bronze → `tempers`, `seam-pipe0` copper → `bronze`, both thinner |
| Surface grunge is single-scale and uniform; noise sits above vanilla's band | Already known and measured | Deferred — it needs fewer parts, not a different knob |
| In south the readout sits outside the 3x3 footprint | True and deliberate | No action: the grading pod hangs south by design, which is a north overhang in south, and it is inside the cone at 0.75 tiles against vanilla's 0.77 ceiling |
