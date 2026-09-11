# Quality Recycler — art log

Working log for the 2026-09-11 rebuild: decisions with a one-line reason, render settings, frame
counts, budgets, current status. A fresh session should be able to continue from here.

Sources live in `assets/quality-recycler/entity/quality-recycler/`; shipped sheets in
`quality-recycler/graphics/entity/quality-recycler/`. The mod's own registers
(`quality-recycler/.ai-support/`) remain the source of truth for settled design — this file is the
working record of the rebuild.

---

## Status

**v3 complete (2026-09-11, second session).** Built from the engine's real output position:
an ejector port on the back edge with a pusher ram, a sealed magnetic rotor under a vented
cap, a composite panel family. 48 sheets packed, every gate green in all eight directions,
data stage clean, **photographed working in the engine in all eight orientations** with the
arrow on the port — and the icons re-rendered. Not committed: the owner decides that. The v3
log is the last two sections of this file; the v2 log below it is history.

Deliverables: previews in `docs/art/quality-recycler/previews/` (the checkpoint sheet, the
1x/2x sheet, the hero frame, the terrain grids, the vanilla A/Bs, the night composite, two
loop GIFs and the engine study sheets), sources in
`assets/quality-recycler/entity/quality-recycler/`. v2 is commit 57acdf1; `versions/` keeps
the v0 generator and the v2 generators that differ from that commit, no `.blend`.

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

---

# v3 — the ejection pass (2026-09-11, second session)

The owner's brief after seeing v2 in the game: nothing ejects, it is not futuristic yet, and it
is busy without being rich. v3 rebuilds the machine around where the engine actually places
results, replaces the rotor's spoked disc with sealed magnetic hardware, and adds a pale
composite panel family. v2 is commit 57acdf1; the generators that moved on after it are in
`versions/*-v2.py` beside the pre-rebuild v0.

## Phase 0 — what the engine showed

The two screenshots the brief names (`ingame-v2-closeup.png`, `ingame-v2-altmode.png`) were
never on disk, so the rig was photographed here with `scripts/screenshot/shoot.ps1`: four
machines facing outward with a steel chest on each output tile, working (50 processing units
inserted) and idle, on Nauvis dirt, Fulgoran dust and Aquilo snow, at noon and midnight, plain
and alt-mode. 32 shots in `scratchpad/v3/shots/v2/`, crops in `study-*.png`.

**The harness needed three fixes to run at all on this machine today**, all in `shoot.ps1` and
the probe, all kept:

- With the monitor asleep the Direct3D 11 path dies at adapter-output enumeration (`Failed to
  enumerate adapter output`, display index -1) and leaves a modal "DirectX error" dialog holding
  the `.lock`. `-ExtraArgs '--force-opengl'` avoids the DXGI lookup; OpenGL renders the same
  screenshots.
- A fullscreen window on that unresolved display then spins forever after "Logitech LED
  Controller initialized" without loading a sprite — ten minutes of CPU, measured. The harness
  now writes `[graphics] full-screen=false` into its scratch `config.ini`.
- The probe never inserted anything, so every crafting machine it shot was idle. It takes
  `insert` / `insert_count` per entity now, and shoots at tick 60 rather than 20 so a craft has
  started. Recycling runs at a sixteenth of the craft time, so a slow item and plenty of it.

**What the shots say.** Exactly what the brief says, and one thing more:

- The yellow arrow leaves the footprint at the centre of the back edge — north for the north
  machine, east for the east one — straight out of the rotor cowl. `vector_to_place_result =
  {0, -1.8}` is the *direct output* position, the same field a mining drill uses (the
  `MiningDrillPrototype` description says so; the crafting-machine copy of the field carries
  no description). The comment in `entity.lua` calling it the spot items land when the machine
  is mined is wrong and is corrected in this pass.
- The five quality lenses read as a row of indicator lights in every rotation, brightest thing
  on the machine at night.
- On Fulgoran dust the copper carries the sprite; on snow the dark hull reads well; the shadow
  is a hard slab to the right. The idle group landed in a lake (seed 1), which changed nothing.

## Phase 1 — the v3 layout, and the look-dev

Everything is laid out from the port backwards. `qr_layout.py`'s docstring carries the route,
the projection reasoning and the four silhouette mappings; the decisions and their reasons:

| # | Decision | Reason |
|---|---|---|
| D10 | **The port is on the north edge, centred, at the footprint line** — hopper y 1.14..1.72, mouth at 1.70, sill to 1.90 | That is where `vector_to_place_result` puts the result; the art has to agree with the arrow |
| D11 | **A hydraulic pusher ram in a straight trough, not a flap** | The one motion this camera cannot see is a slope descending away from it, which is exactly what a flap dropping out of a north-facing mouth is. A stroke along y is screen-vertical in N/S and screen-horizontal in E/W: visible in all four |
| D12 | The trough is raised to z 0.62..0.92 | In east the rotor stands between the trough and the camera; at deck height the trough vanished behind the cowl. Raised, its top 0.36 tiles clear the cowl's rows |
| D13 | The riser's back step rises to z 1.04 at y 1.14..1.20 with the ejector lamp on top; the front step at 0.92 carries the five grade squares as paint | Up-facing surfaces are the ones every rotation sees; rows 2.18..2.24 clear the cowl's north rim (1.76 at x 0, 2.06 at x 0.44). Colour may name a grade, light never does — the lit lenses are gone |
| D14 | The sill (0.44 wide, 0.06 tall, y 1.75..1.90) is the sprite's max-y extreme, standing 0.12 clear of everything | `audit()` hands an extreme's whole row band to every part within 0.06 of it; a small low part keeps that band tiny, so the apron's rows never share it in east or west |
| D15 | The apron lost its rails and moved 0.06 west | In west its rows had to stay under the sill's |
| D16 | The west scrap chute became a power cabinet with two copper insulators | A second chute confused the route; the cabinet keeps the west extreme with rows disjoint from the rotor's, and gives the machine a power-in flow |
| D17 | The rotor: 12 blocky alternating magnet segments in a copper retaining ring around a machined hub, under an armoured composite cowl with four windows onto copper coils, a violet field gap between them | A ring of blocks around a hub they do not touch is a rotor; tapered blades from a hub are a fan |
| D18 | The bright segments are worn steel (`scoured`), not `polished` | A metal with only a dim world to reflect renders near-black inside a bore; measured on the first render, where the ring came out as a dark annulus |
| D19 | The coils sit at z 0.62..0.85, 0.055 under the cowl rim | At 0.70 they measured 4 px through the windows: at 45 deg a window 0.22 wide shows nothing 0.2 tiles below it |
| D20 | Composite on the cowl, the port hood, the fairing, the collar, the armour plates and the cabinet — **not** on the plinth, the hopper body or the tank | The first render put it on all of them and measured mean luminance 87–98 against vanilla's 63–67: white plastic. Pulled back, the pale ring is the brightest large form and the hero |
| D21 | The stack moved onto the olive crown; the gear, fan, louvres, gauge pods, capacitor bank, gantry and tie bracket are gone | Fewer, larger forms: 160 objects and 127 kinds against v2's 205 |

**Measured on the look-dev (`lookdev5/`), one frame, all four rotations:** silhouette ok in
all four and both mirrorings, worst margin 0.09 tiles; cone worst 2.25 after a 0.7% fit;
north overhang 0.75; object-ID pass: **nothing draws zero in any rotation**; below the 12 px
floor only rivets, the ram rod inside its cylinder, the top shredder roller (2 px — its sight
line clips the lintel; the maw was raised to 0.74 for it) and the stator coils before D19.
Painted with the settled `POST`: luminance 74–80, sd 57–66, grey 31–41%. The sd is above the
43–56 band and the grey above the recycler's 31% — both are the paint-over meeting a palette
with a pale family in it, and both are for the sheet stage, where `POST` is retuned against
the packed frames rather than a look.

The checkpoint sheet is `previews/v3-checkpoint-lookdev.png`: v2 in the engine at zoom 2 with
the arrow, v3 at the same density on the same ground, the vanilla recycler and the EM plant.


### Critique round 4 (the v3 look-dev) -- findings, verdicts, actions

A fresh-context reviewer was given only the checkpoint sheet, the 1x/2x sheet, two 4x hero
frames and the v2 engine crops, plus the owner's brief. Its verdicts before the fixes: rotor
reads as magnetic hardware but open-topped and therefore not sealed; the port reads only in
south; the route does not read; v3 is obviously different from v2 at a glance but "paler and
calmer" rather than richer.

| finding | verdict | action |
|---|---|---|
| The rotor face is open to the sky; the brief's armoured cowl with windows is absent | Fair | A composite end-cap turning with the rotor: solid inner and outer annuli, six short curved vent slots between them, a bolt circle, a polished rim. The first cut used six radial slots and read as a spoked wheel again -- concentric dashes are the vocabulary of a ventilated motor end shield, radial ones are a fan |
| Nothing links rotor to port; the discharge slot is invisible | Fair | The west cowl arc is split round a 20-degree notch; a dark chute runs from the bore edge through it down into the trough, violet-edged; the trough floor went dark so it reads as a channel with a bright ram head in it |
| The port has no cue on its top face, the one face every rotation sees | Fair | The hood's west half is an open throat -- a dark well the chips visibly drop into off the trough's end, rimmed in violet (the ejector lamp moved here) -- and the sill carries three hazard chevrons: chevrons in, chevrons out |
| The composite reads as beige plaster, the machine the lowest-contrast object on the sheet | Fair | Cool bone instead of warm beige, satin (roughness 0.34-0.54, metallic 0.10), in TWO values: `composite` on the cap, cowl, riser and hood; `compdark` a step darker on fairing, pockets, collar, armour plates and cabinet, each with a seam groove |
| The black hose is the highest-contrast line in east and west | Fair | Radius 0.03 -> 0.022, dark grey `hose` material instead of black rubber, a copper ferrule mid-run |
| The small violet strips read as painted stripes | Fair | The two deck strips are gone; violet is on the route only -- field gap, discharge edge, scanner, throat rim |
| The five painted grade squares still read as a quality-tier ladder and dilute the violet scheme | **Rejected.** The owner's rule allows colour to name a grade as paint and bans it only as light; "built-in quality" is the entity's reason to exist | Kept, quieter: mixed 45% toward neutral, on the riser's top face |
| Shorten the riser so the mouth is a larger share of the port | Rejected | The riser's height is what makes the port visible from behind the rotor in north; the throat now carries the reading instead |

After the round: 194 objects, 147 kinds; silhouette ok in all four, worst margin 0.09; cone
worst 2.25 after a 0.7% fit; painted luminance 77-82, sd 61-67, grey 38-48%. The grey share
rose with the cool low-saturation family and is deliberate; the sd is for the sheet stage.

## Phases 2–7 — production

The owner approved the checkpoint ("proceed"). Before the bake, a spot-check of eleven frames
of the anim, fx and glow layers in north and south confirmed the cycle end to end: doors shut
at f0, chips in the throat by f22–26, out of the mouth and on the sill by f36–40, doors shut
again by f48, f63 identical to f0 (anim wrap step 0.21 mean abs, fx 0.0). The doors were dark
steel on a dark body and read as nothing either way; they are worn bright steel now, so shut is
a bright plate and open is a black hole.

**The paint-over was re-swept for the v3 palette.** The raw v3 render already measures
luminance sd 39–43 (v2's raw measured 30) because a pale family now sits against dark cavities,
and v2's settings pushed the painted frames to 62–67 against the 43–56 band. Settled:
`form_amount` 0.28, `contrast_amount` 0.75, `crevice_amount` 0.45, `value` 0.88 — the pass
sharpens what the render has instead of inventing range.

**The bake.** 8 directions × 6 layers, 64 frames, 96 samples, GPU: 1,560 frames in about 100
minutes (the icon and wear renders shared the GPU for part of it). Then a second static pass of
base and shadow only — 16 frames — for the silhouette fix below.

**Gates, on the packed sheets, all eight directions (final, after round 5):** contrast sd 47.9–53.3, clipping 0.00%,
full-width rows 0% everywhere, fill 0.59–0.70, ragged 1.00–1.07, shadow 100% pure black, worst
north overhang 0.77 tiles — vanilla's ceiling exactly. **The first run failed south and mirrored south on
raggedness** (0.93 against the 0.95 floor): south shows the port block face-on, and a hopper
with a sill under it is one compact solid. Raggedness is bought with holes, not parts, so the
sill became a bridge plate on two short legs with daylight under it, and a guide post with a
hazard cap stands at each pocket corner. 0.98–1.04 after, everything else unchanged.
`FAILURES: none`. Edge-wear mask 9.6% bright, inside the gate. Object-ID pass: nothing draws
zero in any rotation.

**Sheets.** 48 PNGs, 8.2 MB on disk, **99.4 MB of VRAM** (anim 62.5, fx 19.7, light ~13,
base 1.9, shadow 1.8, lamp under 0.1) against v2's 100.9 and the vanilla recycler's 253.2.
Baked twice in full for the animated layers: once for v3 and once after the final review's
port, cap-material and composite changes (base, shadow, anim and glow; fx and lamp unchanged).

**The light sheets were strengthened after the first engine pass.** Photographed at midnight
beside a working vanilla recycler, the violet field ring read as a faint arc. The engine
weights an additive sprite by its alpha and the packed halo carried most of the ring's
presence at 26–44% alpha; the bloom multipliers went to 34% and 58%. Daylight was checked in
the same run for the magenta wash the previous session found and it is not there.

**The icons** were re-rendered from the v3 model with the same rig (ortho 2.35, elevation 37,
aimed at the rotor): the item icon now shows the vented cap and violet ring over the olive
half; the technology icon likewise.

**Validation.** `validate.ps1 -ModPath quality-recycler` → exit 0, data stage clean, six
layers, `graphics_set_flipped`, three working_visualisations. `pictures.lua` is unchanged: the
layer structure is v2's, and every width, height and shift lives in the sidecars.

**In the engine.** The rig was photographed again with the v3 sheets, same spec as the v2
baseline (four machines facing outward, chests on the output tiles, working and idle, three
grounds, noon and midnight, alt-mode). The yellow arrow lands on the port in all four
rotations — on the throat and riser from behind in north, on the mouth in south, on the
hopper's side in east and west — with the chest directly past it. `previews/v3-ingame-z2.jpg`
is the study sheet; the two full-size shots the brief named sit beside the design doc as
`ingame-v3-*.png` (git-ignored, like the v2 pair and `prototype.png`).

**The engine, second finding: nothing the probe had ever photographed was working.** A tick
sequence of one loop (the probe can shoot a list of tick offsets now) showed the rotor cap in
the same place across 28 ticks. Logging each machine's status at the shot answered it:
`no_power`. The probe's power was one big pole beside the energy interface 24 tiles away, and a
big pole supplies a 4x4 area; every v2 and v3 shot up to that point was of an idle machine
with the arrow drawn. The probe now researches every technology (recycling recipes are locked
behind `recycling`), powers each group from a substation at its centre relayed to the source,
and logs `status working` per machine before it shoots. Photographed again: the cap's slots
shift between ticks, the ram head travels north and back on a ~32-tick cycle, the doors part,
the scanner and the throat rim pulse, and the field ring glows — at midnight it is the
brightest thing on the machine after the green lamp, and by day it does not wash the cowl.
The mirrored set was photographed too (`mirror = true` in the spec sets `entity.mirroring`):
the arrow lands on the port in all eight orientations.

The one entity the probe cannot power with that layout is a neighbour more than nine tiles
from the group centre, which is where the comparison vanilla recycler and EM plant stood;
they photographed idle, which for the look comparison is what was wanted anyway.

`previews/v3-ingame-z2.jpg` (working, mirrored, idle, midnight) and
`previews/v3-ingame-grounds-z2.jpg` (Fulgoran dust, Aquilo snow, idle at midnight) are the
tracked study sheets; the full-size shots are `ingame-v3-*.png` beside the design doc.

### Critique round 5 (the engine shots) — findings, verdicts, actions

A fresh-context reviewer was given the engine study sheets (working, mirrored, idle, midnight,
two grounds), the v2 engine sheet, the offline grids and the vanilla A/B, plus the done-when
list. Its verdicts: the arrow lands on a visible port in all eight orientations; the rotor
reads as an electromagnet and nothing like v2's fan; the back half of the route reads, the
front half less so; it holds on Fulgoran dust and at midnight.

| finding | verdict | action |
|---|---|---|
| The port reads as a latched steel chest: two bright door plates with a centre seam on a flat face, and it looks the same working and idle in every frame that has no alt-mode icons | **Fair on the chest; the "never opens" is a sampling artefact** — every deliverable shot is taken at one tick, and the benchmark renderer produces a new frame only every few ticks, so a tick sequence cannot resolve the doors either. The fix has to read in ANY frame | The mouth is a real recess in the body's north end with a violet strip inside it that shows only when the doors are parted; the doors are dark gunmetal shutters, not bright plates |
| Flow cues point backwards: the intake carries the only big hazard panels, the output's chevrons are two yellow dabs | Fair | Hazard plates on both pocket lids (up-facing, every rotation) beside the sill's. An eave band over the mouth was tried and sat over the cone at the footprint's far edge |
| The black hose arc from the tank to the cowl is the boldest line in north, east and west | Partly — it was already thinned and greyed after round 4 | `hose` a step lighter again (`#3B3E44`) |
| A bare quadrant under a soft shadow in the south-east | Fair | A hydraulic power unit for the ram — a tank on Z, a motor block, a pressure hose to the cylinder's rear — where the design already implied one |
| Whites brighter than any vanilla surface; the idle ring is painted purple by day, so working and idle differ only slightly | Fair | `composite` and `compdark` a step darker; the render driver dims the three violet materials to 0.22 in the BASE pass only, so the base carries a dull painted gap and the working-only glow sheet carries the light — by day as at night |
| Ground-level overhang at both ends covers the near half of the next tile | True, and deliberate | No action: the cone bounds height, not reach, and vanilla spends the same reach on pipe stubs; the vanilla recycler's own output sits 0.6 past its box. Recorded in `deferred.md` as the thing to check with items on the ground |

Object count after the round: 214 and 163 kinds. Silhouette unchanged (margins 0.09–1.02),
cone worst 2.25 after the eave band was removed.
