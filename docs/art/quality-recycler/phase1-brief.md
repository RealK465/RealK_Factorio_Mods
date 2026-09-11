# Phase 1 brief — Quality Recycler rebuild

Checkpoint. Everything below is measured from this session unless it says otherwise.

**Images in this folder**
- `contact-sheet.png` — the three look-dev directions, north and east, at game zoom (1x) and 3x.
- `before-after.png` — the shipped sprite (top row) against the recommended direction (bottom row), all four rotations, on Nauvis dirt.
- `D-<dir>-post.png` — the recommended direction, four rotations, paint-over applied.
- `A|B|C-<dir>-hero.png` — the three directions at 4x, for looking at form.

---

## Recommendation: direction B, developed (shown as "D" / the AFTER row)

**The hero becomes a vertical-axis eddy rotor: a 14-pole copper disc in a bronze well, under four
guard arcs and a toroidal field coil.** The reason is geometric, not stylistic, and it is the one
finding that changes everything else.

At this rig, screen row is `-(y + z)` and screen column is `x`. Feed a circle through that and:

| ring axis | north / south | east / west |
|---|---|---|
| **Z** | true circle | **true circle** |
| Y | true circle | **edge-on line** |
| X | edge-on line | true circle |

`set_direction()` rotates the model about Z, so a Y-axis drum is round in two rotations and flat
in two. **On a rotatable entity a Z-axis rotor is the only radial form that reads in all four.**
The shipped build's drum is on Y, which is why its east and west views lose the hero completely
and read as a striped box. The design doc's own analysis compared X against Y and concluded Y
correctly; it did not consider Z, because the rotation cone was worked out afterwards.

You can see the consequence directly in `contact-sheet.png` at 1x: A and C collapse into a pale
ring round a dark hole (a porthole, a washing-machine door), and B stays a spoked wheel.

### Conflicts with the design doc, and how they are resolved

| conflict | resolution |
|---|---|
| The doc's hero is a horizontal copper-wound **drum** (eddy-current separator); B makes it a vertical **disc** | The lore survives — a vertical eddy rotor is still an induction separator, and fragments still fly off it radially into the output. What is lost is the literal horizontal barrel. **This is the one change I would like confirmed**, because it is the doc's stated identity element. |
| The doc specifies **four output bins** with colour-coded lips; the brief asks for a **grading unit with five indicators** | Built as the brief asks: one grading pod with five up-facing lenses in the exact quality colours, plus a single output chute. This also retires the FFF-339 risk the doc itself flagged ("four visible bins can imply four separately drawable outputs"). |
| The doc says the concept sheet's east–west barrel is impossible | Confirmed and unchanged. Every circular cross-section of an X-axis cylinder is edge-on. |
| Brief says module slots undecided; `decisions.md` says 4 | Immaterial to the art; nothing changed. |

---

## What the audit measured, and what it means for Phase 2

### Every numeric gate on the shipped art is green

Contrast sd 49.9–53.4 (band 43–56), clipping 0.00%, full-width rows 0% in all eight directions,
fill 0.83–0.87, shadow 100% pure black, worst overhang 0.77 tiles against vanilla's 0.77 ceiling.
`check_sheets.py` reports **FAILURES: none**. The gates read the output PNG, so they cannot see
that it is the wrong machine.

### The sprite is grey where vanilla is chromatic

Opaque-pixel census, `grey` = fraction below saturation 0.18:

| | lum | p50 | olive 40–95° | copper 10–40° | violet 250–320° | grey |
|---|---|---|---|---|---|---|
| vanilla recycler N | 67.0 | 63 | 12.0% | 35.2% | 0.9% | **31.4%** |
| vanilla chemical plant N | 63.0 | 47 | 25.7% | 61.3% | 0.0% | **12.3%** |
| shipped sprite N | 60.2 | 45 | 14.1% | 20.3% | 4.6% | **41.2%** |
| direction D (blockout) N | 60.4 | 48 | 13.3% | 31.2% | 4.7% | **42.0%** |

Copper is now right (31% against the recycler's 35%, the rotor doing that work). **Grey is still
42% against vanilla's 12–31%.**

### …and it scatters its chroma where vanilla concentrates it

This is the sharper version of the same finding, and it came out of putting our sprite beside the
three real machines on real grass (`preview-shipped/vanilla-ab-nauvis.png`). Share of chromatic
pixels falling in the single dominant 15° hue band:

| | chromatic pixels | share in the dominant 15° band | saturation, p75 |
|---|---|---|---|
| vanilla recycler | 68.6% | **44.2%** | 0.51 |
| vanilla chemical plant | 87.7% | **48.4%** | 0.75 |
| vanilla EM plant | 57.8% | **54.3%** | 0.52 |
| ours, shipped | 58.8% | **22.1%** | 0.54 |
| ours, direction D | 57.9% | **33.5%** | 0.57 |

**Our saturation is already in vanilla's range.** What is wrong is that olive, copper, bronze,
violet and blue carry comparable weight, so no hue owns the machine and the eye integrates it to
grey. Each vanilla machine is *one colour with accents* — the recycler is green, the chemical plant
is gold, the EM plant is blue.

So Phase 3's target is not "more saturation", it is **concentration**: one warm family (olive
through bronze) carrying ~45% of the chromatic pixels, violet kept as a small deliberate accent
rather than a co-equal zone, and the incidental blue cut entirely.

The same A/B shows two more things for Phase 2: **vanilla shadows are soft and hug the machine**
where ours is a hard offset slab (the gate passes it because it measures purity, not shape), and
**vanilla machines break their footprint box on several sides** where ours sits tidily inside it.

### The olive is half the luminance vanilla uses

Sampling only pixels in the 55–110° hue band at saturation ≥ 0.18:

| | mean RGB | luminance | saturation |
|---|---|---|---|
| **vanilla recycler** | **(96, 106, 57)** | **101** | **0.47** |
| shipped sprite | (69, 71, 49) | 69 | 0.33 |
| direction D blockout | (53, 54, 35) | 52 | 0.38 |

Vanilla's olive is green-dominant by 10 points and sits at luminance 101. Ours is neutral (53 vs
54 — no green bias at all) at luminance 52. The design doc darkened it deliberately, sampled off
the concept sheet's hero render rather than off vanilla, and that is where the "dark, low-contrast,
forms merge" read comes from. **Phase 3 repaints the olive toward (96, 106, 57).**

### The sprite is smaller than its 3x3 peer

Opaque bounding box, at screen pixels (scale 0.5), footprint 96 px:

| | screen px | fill | bottom 10% of rows solid |
|---|---|---|---|
| vanilla chemical plant (3x3) | **100 x 145** | 0.75 | 0.61 |
| vanilla recycler (2x4) | 80 x 150 | 0.79 | 0.71 |
| shipped sprite | 99 x 118 | 0.85 | 0.75 |
| direction D blockout | **86 x 112** | 0.83 | **0.91** |

The blockout is 23% shorter than the chemical plant and its bottom band is almost solid across the
full width, which is what fuses the two masses into one brick. Both are Phase 2 work: grow the
envelope toward 100 x 140 screen px and break the shared plinth so each mass lands on its own feet.

(An independent critique put vanilla's fill at 58–65%; measured, it is 0.75–0.88, so ours at 0.83
is inside the band. Its other four findings all checked out and are folded in above.)

---

## The animation systems

Eight, against the brief's minimum of five. Frame counts are per direction; every loop closes
exactly on its frame count, so nothing jumps on the wrap.

| # | system | layer | frames | why it loops there |
|---|---|---|---|---|
| 1 | **Eddy rotor spin** — 14 poles, two pole pitches per loop | anim | 64 | the hero doing the action |
| 2 | **Shredder rollers** — three counter-rotating, 9 teeth, 6 tooth pitches | anim | 64 | quotes the vanilla recycler's own jaw |
| 3 | **Cooling fan** on the intake hood — 5 turns per loop | anim | 64 | a second rhythm, so the machine is not one clock |
| 4 | **Sorting flap** at the gap — one open/shut cycle | anim | 64 | mechanical effort at the seam |
| 5 | **Fragments in flight** across the gap into the chute, four phased | fx | 64 | shows separation happening |
| 6 | **Field pulse + winding pulses** — travelling bright band on the coil, phase-locked to the rotor | light | 64 | the only large emissive, and it explains the rotor |
| 7 | **Grading scan sweep** — a bar crossing the window, the five lenses lighting in sequence behind it | light | 64 | makes "built-in quality" visible |
| 8 | **Fulgoran arcs** at the rotor contacts, irregular flicker | light | 64 | Fulgora, and it never looks periodic |
| — | **Status lamp**, green, always drawn | lamp | 1 | idle reads as idle at a glance |

**Idle state:** the rotor parked with one pole piece at top dead centre, rollers shut, flap closed,
every emissive off except the green lamp. Idle is the `anim` layer frozen at frame 0 (it is a layer
of `animation`, so it is always drawn), plus the always-drawn lamp; systems 5–8 are
`working_visualisations` without `always_draw`, so they vanish when the machine stops, and the
light layer carries `fadeout = true` so it eases off rather than cutting.

**Speed.** `animation_speed = 2`, not the vanilla recycler's 4. Crafting-machine animations are
scaled by crafting speed unless `constant_speed` is set, and this machine runs at 1.0 against the
vanilla recycler's 0.5 — so 4 here would play at twice the vanilla recycler's apparent tempo. At 2
the two machines read at the same rate side by side. Per-frame rotor rotation is 0.80 degrees
against a 25.7-degree pole pitch, so it cannot wagon-wheel.

Two things I checked in the docs rather than assuming:
- **`states` (VisualState) exists on `WorkingVisualisations` in 2.1** and the electromagnetic plant
  uses it for warm-up / working / cool-down. A spin-up sequence is therefore possible. I have **not**
  put it in the plan: it multiplies the sheet count, and the EM plant is the only vanilla user.
- **`apply_tint = "status"` with `status_colors` is legal but no vanilla crafting machine uses it** —
  only mining drills. The status lamp is a plain green sprite, matching the vanilla convention.

---

## Render plan and budget

Six sheets per direction, eight directions: `base` (1f), `anim` (64f), `fx` (64f), `light` (64f),
`lamp` (1f), `shadow` (1f). 1,560 Cycles frames at 96 samples, GPU (HIP) with persistent data —
about 75 minutes on this machine, run headless in the background with logs.

VRAM, `width x height x 4` over every sheet, measured on the real files:

| entity | VRAM | note |
|---|---|---|
| vanilla recycler | **253 MB** | 8 directions x 64 frames, whole machine animated |
| foundry | 152 MB | |
| electromagnetic plant | 149 MB | |
| **Quality Recycler, shipped now** | **58.7 MB** | anim 48.0, light 7.8, base 1.5, shadow 1.4 |
| **Quality Recycler, planned** | **~115 MB** | the rotor grows the anim sheet; fx and lamp are new |
| cryogenic plant | 37 MB | |
| chemical plant | 17 MB | |

Planned sits between the cryogenic plant and the EM plant, and at 45% of the vanilla recycler we
are replacing. There is room; I will report the measured total at the end rather than the estimate.

---

## Questions where a different answer changes the design

1. **The rotor axis.** B turns the design doc's horizontal copper-wound drum into a vertical disc.
   It is the reason the hero survives all four rotations, and it is the doc's stated identity
   element. If you want the horizontal drum kept, say so and I will build variant A properly
   instead — it costs the east and west rotations most of the hero, and I would compensate with a
   large Z-axis field coil over the drum (variant C's idea, executed better).
2. **Four bins or five lenses.** I have built five lenses on a grading pod and dropped the four
   bins. The doc chose the bins deliberately; the brief asks for five indicators. Currently the
   brief wins.
3. **Frozen patch for Aquilo.** The vanilla recycler ships one, and Space Age sets
   `heating_energy = "100kW"` on it. Ours has no `heating_energy`, so it will never freeze and a
   frozen patch would be dead weight. Adding it is a gameplay change (the machine would stop on
   Aquilo without heat), which the brief puts out of scope — **so I am not doing it**, and it goes
   in the final report as a follow-up.

Nothing else is blocking. If you say nothing I will build B as described.

---

## What Phase 2 onward will do

1. **Forms.** Grow the envelope to ~100 x 140 screen px; break the shared plinth; push the two
   masses onto a real diagonal with a 5–7 screen-px channel of visible ground between them; open
   the maw to 28–34 x 10–14 screen px with the rollers visible against a near-black cavity; build
   the seam as a bolted flange rather than a butt joint; add the tertiary clusters.
2. **Materials.** Repaint the olive toward vanilla's (96, 106, 57) at luminance ~100; take grey
   from 42% to under 30%; build the temper gradient, brushed copper and oxidised bronze as reusable
   node groups; take the emission off the quality lenses' base colour so they render their true
   values and let the glow layer carry the bloom.
3. **Animation.** The eight systems above, each verified on its own loop before they are combined.
4. **Render, pack, integrate, validate, and iterate on critique rounds.**
