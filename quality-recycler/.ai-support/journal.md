# Journal — Quality Recycler

Append-only, newest first. What happened, dated.

## 2026-09-11 (third session, latest) — the port in east and west, the icon, the loop

The owner placed the 4x4 in all four directions and found the port "not at
centre" in east and west, the icon "not showing the totality of the machine",
and asked for more and better animation.

**The port was on the arrow all along; its height was not.** Measured
against this session's own engine shots, the mouth sat on the output position
in every direction. In east and west a part's height projects up-screen,
perpendicular to the output axis, so the tall riser and hood drew the port's
mass 0.6-0.9 tiles north of the mouth, and in east the port's 0.15-tile
westward offset added to that. The port is on the machine's centre line now
and low at the mouth end -- roof 0.68 falling to 0.55, only the back step the
trough feeds through keeping its height -- and the sill is twice as wide. The
rule went into `CLAUDE.md`: keep the output end low.

**The icon shows the whole machine.** Measured against vanilla's machine
icons, the whole machine at the old camera was wide, flat and dark; lowering
the camera made it flatter, because a flat machine's projected height grows
with elevation. 52 degrees, a hotter key and the entity paint-over on the icon
put it inside vanilla's band.

**The loop:** the rotor turns twice as far a loop, five ejected chips tumble
out of the mouth and down the chute, six stream along the feed trough.

**Measured.** 256 objects; every gate green in all eight directions (contrast 48.7-51.3, ragged 1.08-1.18, overhang 0.70-0.73), 154 MB of VRAM, data stage clean; in the engine the arrow is on the mouth in all eight orientations with the port's low end around it, and the icon measures 62x56, luminance 83.5, sd 54.7, saturation 0.40 against vanilla's 60x63, 79-100, 57-64, 0.41-0.60.

Not committed.

## 2026-09-11 (third session, later) — the balance pass

The owner asked for the recipe, technology and entity to be balanced "for
space age and vanilla", with crafting speed 1.25, the 12% built in and five
module slots. Entity: 1.25, five slots, 1 MW (800 kW per unit of speed, priced
like the electromagnetic plant's free productivity; 2.2x a recycler's power per
item). Recipe: a recycler and two quality module 3s in both games, then the
three planets' materials with Space Age or low-density structures and electric
engines without. Technology: the three-planet gate with Space Age, the rocket
(space plus utility science) without, 500 units at 60 s either way. Space Age
became an optional dependency for that; `item.lua` forks on `mods["space-age"]`
and both branches validate. The animation speed in `pictures.lua` dropped to
1.6 so the engine's crafting-speed scaling lands the loop at the same 32 ticks.
Not committed.

## 2026-09-11 (third session) — v4: 4x4, and nothing on the neighbours

The owner placed v3 in a row beside a vanilla recycler and circled two zones
that lay outside the placement area on the neighbouring machines -- the power
cabinet hanging 0.36 tiles past the west edge and the loading apron 0.55 past
the south -- and a bare quadrant on the pad in front of the plinth, asking for
slightly more content there and more animation. Mid-session: the entity is to
be **4x4**.

**Both zones were the cone rule working as designed.** It bounds height and
not reach, so low hardware may hang past the tiles, and vanilla spends the same
reach on pipe stubs. What no offline gate sees is that the neighbour is drawn
in that space. The rule is now the other way round for this entity: ground
hardware stays inside the footprint; only the sill, which is the output,
crosses the edge (`CLAUDE.md`).

**The 4x4 is the v3 machine at 1.2x, on the root.** One uniform scale, applied
the way the cone fit already is, so every literal in the layout and every keyed
animation offset grows together. 1.2 and not 4/3 because at 4/3 the cowl rim
and the riser back both pass the 4x4's APEX of 2.75; at 1.2 the worst cone
value is 2.72 with no fit, and the 0.4-tile margin left on every side is what
the cabinet and the apron moved into. The layout still speaks the 3x3's units
(1 unit = 1.2 tiles); `BASE_SCALE` in the generator carries the difference.

**The output moved 0.15 tiles west**, because a 4x4's centre is a tile corner
and x 0 is the boundary between two tiles -- the vanilla recycler's own -0.35
exists for the same reason. `vector_to_place_result = {-0.15, -2.3}` and the
whole port sits on that line. It could not go further west: the sill's rows in
east and west move with it and would cross the apron's.

**The pad carries the route's second leg now.** The closed transfer duct
became an open trough on legs from a spout on the hull to an inlet hood on the
cowl, with four chips streaming along it every loop -- up-facing, so every
rotation sees them move -- plus an operator console with a lit strip, a gauge
on the hydraulic unit, a walkway with a handrail and a ladder up the west
wall, and a low coolant step with two radiators filling the east margin. The
console's screen was drawn twice: at 0.19 x 0.15 units it was a purple slab,
and at 0.22 base dim it was a purple sticker on the idle machine; it is a lit
line at 0.06 in the base now.

**Measured.** 250 objects and 184 kinds; cone 2.72 under 2.75 with no fit; every gate green in all eight directions -- contrast 48.3-51.4, ragged 1.09-1.19, no full-width rows, north overhang 0.70-0.73; 151 MB of VRAM against the vanilla recycler's 253. The first pack failed raggedness in five directions (0.87-0.91): the wider pad had filled every silhouette hole with concrete. The apron, the walkway and the coolant step went onto short legs and the pad stopped short of all three, and the same frames measured 1.10-1.18. Photographed working in the engine in all eight orientations with the arrow on the port and the results in the predicted chest; a row of abutting machines beside a vanilla recycler and an EM plant with nothing on a neighbour; idle dark; three grounds; noon and midnight. A fresh-context review then widened the coolant step, added two drums to the bare corner and dressed the well's drum wall; its two other findings are logged as rejected in the art log.

Not committed: the owner decides that. The 2.0 track has not been touched;
the collision box, the output vector and the sheets all belong in the next
port.

## 2026-09-11 (second session) — v3: the machine agrees with its own arrow

The owner put v2 in the game and came back with three things, in order: nothing
ejects, it is not futuristic yet, and it is busy without being rich. The
screenshots the brief named were never on disk, so the rig was photographed
here -- which needed the screenshot harness fixed three ways first (Direct3D
finds no display output with the monitor asleep, so `--force-opengl` and
windowed mode; and the probe never inserted anything, so every crafting machine
it had ever shot was idle).

**The finding that re-laid the machine.** `vector_to_place_result = {0, -1.8}`
is a direct-output position, the same field a mining drill uses for its drop
point: the tile past the back edge, centred. The prototype comment called it
where a mined machine drops its contents, and v2's output chute sat on the
south-east while the yellow arrow left the north edge straight out of the rotor
cowl. v3 is laid out from that point backwards: maw on the south wall, a duct
across the seam, the rotor, a discharge notch through its cowl into a dark
trough running due north, a hydraulic pusher ram, an open throat in the port's
hood that the chips visibly drop into, the mouth with two doors, a sill painted
with chevrons -- chevrons in, chevrons out.

**A ram, not a flap, because of the camera.** The view direction is
(0, +y, -z), so the one motion it cannot see is a slope descending away from
it -- exactly a top-hinged flap dropping out of a north-facing mouth. A stroke
along y is visible in all four rotations. This is now a rule in `CLAUDE.md`.

**The rotor was redesigned a second time**, from an open spoked disc to sealed
magnetic hardware: a composite cowl with four windows onto copper windings, a
violet field gap, a vented end-cap turning with twelve blocky magnet segments
under it, a polished spindle. Three things were tried and rejected by
rendering: polished segments (a metal inside a bore reflects the bore, and
rendered as a dark annulus), coils at the well floor (4 px through the
windows), and six radial slots in the cap (a spoked wheel again -- concentric
slots are a motor end-shield, radial ones are a fan).

**The composite family went wrong first and was pulled back.** Put on every
new surface it measured mean luminance 87-98 against vanilla's 63-67 and read
as white plastic. Two values now, the bright one only on the cap, the cowl and
the port hood, the darker one on structure, all cool against the warm olive
and copper.

**The five lit quality lenses became paint.** In the engine they were a row of
indicator lights. Five matte squares on a dark plate on the riser's top face
now; violet is the only light and it is on the route only.

**A fresh-context reviewer saw the look-dev before the checkpoint.** Five
findings taken (open rotor face, invisible rotor-to-port link, no top-face cue
on the port, plaster-like composite, loud hoses), two rejected with reasons
(dropping the painted grade squares -- the owner's rule allows colour as paint;
shortening the riser -- its height is what shows the port behind the rotor).
The owner approved the checkpoint and the production pass followed: 194
objects and 147 kinds against v2's 205, silhouette clear in all four rotations
and both mirrorings, overhang 0.75, nothing drawing zero pixels.

**Then the engine said the machines had never been working.** A tick sequence
showed the rotor cap in the same place across 28 ticks; logging each machine's
status gave `no_power` -- the probe's one big pole 24 tiles from the rig
supplies a 4x4 area. Every screenshot the harness had ever taken, v2's
included, was of an idle machine with the arrow drawn. With research, power
and status logging in the probe, v3 was photographed working in all eight
orientations: the arrow on the port, the ram cycling, the doors parting, the
field ring and the route lights glowing at midnight, the idle machine shut
with only its green lamp.

The art log carries the numbers per phase; `docs/art/LESSONS.md` gained six
entries, including the profile-wide file search that hydrated OneDrive and
must never be repeated.

## 2026-09-11 — the rebuild, and the axis nobody had tried

The owner's verdict on the shipped art: "still very ugly and too far from what I
expected." Dark, low-contrast, the two-technologies story gone, the silhouette a
plain rectangle, the emissives scattered magenta dots. The audit confirmed every
line of it and added measurements, and `check_sheets.py` reported **FAILURES:
none** on the same sheets — contrast, clipping, full-width rows, fill,
raggedness, shadow purity and overhang all green on a sprite its own author
called unusable. That is the standing lesson of this mod restated: the gates read
the output PNG and cannot see that it is the wrong machine.

**The finding that changed the entity.** The design doc's rotor-axis analysis
compared X against Y, proved the concept sheet's east–west barrel is flat at this
projection, and settled on Y. It is correct and it is not sufficient. This rig
scales world Y and world Z to the same 64 px in the row direction, so a ring
about **Z** projects as a true circle too — and `set_direction()` rotates the
model about Z, which turns a Y-axis ring into an X-axis one in east and west. A
horizontal drum is round in two rotations and **edge-on in two**, which is
exactly why the shipped east and west views had no hero in them. Three blockouts
were built and rendered at gameplay zoom; at 1x the two horizontal-drum variants
collapse into a pale ring round a dark hole and the vertical disc stays a spoked
wheel. The owner approved the vertical rotor at the Phase 1 checkpoint.

**The colour diagnosis was not the one the sprite looked like it had.** Measured
against the shipped vanilla sheets, our value split was already near vanilla's —
the problem was chroma. 41% of the sprite sat below saturation 0.18 against the
vanilla recycler's 31% and the chemical plant's 12%, and the chroma that was
there was spread evenly across olive, copper, bronze, violet and blue. Vanilla
machines are **one colour with accents**: the share of chromatic pixels in the
single dominant 15-degree hue band measures 44% on the recycler, 48% on the
chemical plant and 54% on the electromagnetic plant, against 22% on ours. The
fix was concentration, not saturation. Grey is now 14–17%.

**`bronze` was rendering green, and had been for two builds.** Zone 2 stopped
being verdigris when it became heat-tempered bronze, but `patina=0.52` stayed on
the material — and patina is `#39685B`. On a lit swatch `bronze` measured
(113, 115, 78): green-dominant grey, on the rotor well and the seam, which are
two of the three largest curved surfaces in the sprite. The olive had the
mirror-image problem: `rust=0.22` plus `grime=0.40` rendered it (73, 67, 45) at
luminance 66 and hue 48 — red-dominant khaki, where the vanilla recycler's own
olive-green measures (96, 106, 57) at luminance 101 and is green-dominant by ten
points. Both were found by rendering every material as a lit stepped block and
measuring it (`swatch.py` / `measure_swatch.py`), which is now the way to tune
this palette.

**The object-ID pass earned its keep again, and the headline is embarrassing.**
**The shredder maw was a solid dark block with the rollers buried inside it.**
`maw-cav` was a filled box laid over an opening in a solid hull, so all three
rollers and all three tooth rings drew exactly zero pixels in all four rotations
— the olive half's entire identity, invisible, and nothing in the render says so
because a dark rectangle where a dark mouth belongs looks correct. The hull is
five spans around the opening now. The same pass found the lintel cutting off the
top roller (at 45 degrees a ray entering at the lintel drops one tile of z per
tile of y, so a 0.12-deep recess shows only down to z 0.57 and the roller sat at
0.58), the radiator and the deck vent inside the rotor deck, three cable runs
buried, and all four arc emitters under the guard arcs. 52 of 204 objects on the
first run; six on the second, all of them frame-0 false positives.

**Two parts rendered with no material at all** — `rotor-flange` and `cage-boss` —
and Blender's default grey is brighter than anything in this palette, so they
read as four deliberate white bullseyes round the rotor. `_emit()` prints a
warning now; nothing downstream can catch it.

**What the numbers say afterwards.** Silhouette: 0% full-width rows in all four
rotations and both mirrorings, worst margin 0.09 tiles, achieved by giving the
max-y extreme to a single tie bracket standing 0.12 clear of everything else —
`audit()` collects every vertex within 0.06 of an extreme into its row band, and
one 0.07-tile cage boss had been pulling in a deck, a capacitor bank and two
cable runs. Size 102 x 134 screen px against the chemical plant's 93 x 138,
bought by hanging low hardware past the footprint the way vanilla's pipe stubs
do — the cone bounds height, not reach. Eight animation systems, every loop's
wrap step inside the distribution of its own adjacent steps.

Two knobs that lied and are now documented in `docs/art/LESSONS.md`: the
paint-over cannot take out model noise (sweeping `crevice_amount` 0.95 to 0.40
moved local 5 px sd only 33.9 to 31.3), and `form_amount` improved every
statistic while bleaching the sprite, because `form_contrast` has radius 11 and
lifts whole faces toward each other.

## 2026-09-10 (third) — the content round, and the pass that should have run first

The owner asked for more content. What the round actually turned into was
building `check_visibility.py` — the object-ID pass, which this mod's own
`CLAUDE.md` has been telling everyone to run and which nobody had made runnable.
Its first report on the 213-object model:

**The ring gear drew zero pixels.** GEAR_XY was (-0.06, -1.01) and `rotor-house`
spans y -1.06..-0.94, so the design's one mechanical link between the salvaged
half and the new one — the whole reason the seam is a drive rather than a paint
line — was inside a wall, in all four rotations. So was **the radiator** (inside
the rear deck), **the entire capacitor bank** (embedded in a 0.14-tile apron
wall), **three more capacitor cans** (inside the rear deck), **three gauge pods**
(inside the apron), **the grease pot**, **the north pillow block**, and the four
**sorting-gap guide plates** at 0, 0, 2 and 7 px. 60 of 213 objects were paying
render time and sprite budget for nothing.

**The tool lied the first time and the fix is worth recording.** It wrote PNG
with the view transform set to Raw, on the theory that Raw keeps the lattice
intact through a byte. Only 34% of pixels classified and the report declared the
bins, the drive motor and the capacitor bank invisible — all three plainly in the
render. Writing scene-linear EXR instead took classification to 97%. A display
transform is a display transform; do not try to reason around one.

What moved, and why each is where it is now:

- **The rotor-house ROOF is the best real estate on the machine and was empty.**
  Up-facing, so it reads in all four rotations; at |y| ~1.00 where the cone still
  allows 1.25; and directly over the hero. It now carries the capacitor bank, the
  slip-ring and brush gear, the gauge cluster, the lubricator and three cable
  runs — every one of them a part that measured zero somewhere else.
- **The ring gear moved outboard** to y -1.14, in front of the wall that hid it,
  where it meshes on the drum's lower west quadrant in plain sight, with a shroud.
- **The guide plates became discharge chutes on the outside of the wall.** The
  sorting gap is not a place a viewer can see into on this machine — the drum is
  over it and the bearing wall in front of it. One short sloped chute per bin on
  the south face tells the same causal story where it can actually be read.
- **The north pillow block was deleted, not relocated.** In north the drum is in
  front of it; in south the rear deck tops out at 1.06 against its 1.05.
  Splitting `cheek-n` into two piers to open a window onto it changed nothing,
  because the wall was never the occluder. The window stayed anyway: `cheek-n`
  was 3.07% of the sprite as one slab, the fourth-largest object on the machine.

New content, all of it with a stated job: **auger gearmotor, chain guard and
sprocket** (the auger turned with nothing driving it, the same fault the maw
rollers had); a **cooling fan on the hood's south cap**, 5 turns a loop against
the rotor's 1, which is the machine's fourth moving part and the only one
outside the material path; a **tachometer** cabled to the slip ring; a **spares
crate** on the pad; **rad header**, **hydraulic line** and **coolant return**
runs, each joining two parts that already existed. 241 objects, 186 distinct
kinds, up from 213 and 161.

**Two modelling traps, both caught by the pass and invisible in a render.**
`cyl()` builds a solid disc, so a fan "ring" at r 0.235 was a lid over its own
hub. And a louvre bank recessed *below* its own frame draws nothing — the rear
vent fins were at z 0.99..1.055 under a frame topping at 1.065.

**The drum was a window pane and the fix was the radii, not the ribs.** With
every band within 0.03 of one radius the barrel had no curvature in its own
silhouette, so 12 axial copper ribs crossing 9 band edges resolved as gold
mullions over coloured glass. Tapering the ends to 0.575 against a middle of
0.640 gave the flank a curve and put both end flanges proud of the barrel they
cap. The ribs went to 16 at half-width 0.017. Bronze was tried for them and is
wrong: `bronze` carries heat 0.45 off the rotor and the ribs sit ON the rotor,
so they took the ramp at full strength and came out pale lavender. `copper`
carries heat 0.14 for exactly this reason.

Saturation override 0.62 -> 0.70, which lands 0.32 against the vanilla
recycler's 0.31.

## 2026-09-10 (later) — the density pass, and why every gate was green again

The repo owner rejected the sprites a second time. The gates were green a second
time: luminance sd 45-51 against a 43-56 band, saturation 0.44 against the
chemical plant's 0.47, zero full-width rows, overhang 0.75. What the sprite
actually looked like was a soft pale slab with two flat quadrants on it.

**The measurement that finally named it was the form/grain split, not the sd.**
Splitting luminance variance into form (>12 px) and grain (<3 px):

| | form | grain | ratio |
|---|---|---|---|
| vanilla recycler | 16.1 | 26.5 | **0.61** |
| chemical plant | 24.8 | 23.0 | 1.08 |
| this entity, before | 27.2 | 21.8 | **1.25** |

Vanilla carries its contrast in small hard-edged parts; this machine was
carrying it in broad shading. Two causes, one in post and one in the model.

**In post: `form_amount` was 1.70 and was making it worse.** An unsharp mask
lifts every frequency above its radius, so at form_radius 11 the knob spends
itself on the one band vanilla has least of — it was buying the sd number by
smoothing the machine. Dropped to **0.30**, with the sd paid for by
`contrast_amount` 1.35 (radius 7) and `crevice_amount` 1.30 (radius 1.8)
instead: form 15.6, grain 37.9, sd 52.9. Hard part separation and dark gaps.

**In the model: two flat plates and a bare deck.** The olive half was three
stacked boxes, and T2's and T3's tops were ~2 tiles of empty painted plate —
the camera sees the deck more than anything else, and vanilla never leaves one
bare. T3 is now a **rounded hood** (a cylinder about Y, r 0.30 at z 1.06),
which is the curved primary form the machine had none of, and the shredder
drive that turns the maw rollers now exists and sits on T2: motor with cooling
fins, gearbox with a split-line flange, belt guard, drive sprocket. Also added:
pillow-block bearings at both drum ends, a guard hoop, the catwalk the design
had always listed, the capacitor bank it had always listed, and guide plates in
the sorting gap. 138 objects to 213, 104 distinct kinds to 161.

**"A side wall renders as a one-pixel line" is a FIXED-entity rule, and this
entity rotates.** The west wall is the front elevation in east, the north wall
is in south, the east apron is in west — and only the south wall had ever been
given stiles, rails and a hatch. Three rotations were reading as blank painted
plates for that reason alone. All four walls now carry the same treatment.

**Nothing can stand on a deck already at the cone limit.** A finned cooler on
the rear deck measured `max(|x|,|y|) + z = 2.48` against APEX 2.25, and
`fit_cone()` refused it rather than shrinking the machine 9% to hide it — the
floor doing exactly its job. The deck tops out at 1.06 where the cone allows
1.07, so the detail went **downward** instead: a recessed louvre bank in the
deck, which costs no height and reads the same at 30 px.

**Three defects in the glow sheet, none of which any gate reads.**

- The **amber beacon was blown to pure white** — measured max (255, 255, 255)
  over the lamp, because #FF8A12 has a full red channel and the strength was
  1.9. The additive layer put a glowing orange egg on the machine in all eight
  directions. Strength 1.0; the green lamp had the same fault at 1.9 and is 1.2.
- The **south view had no violet field at all.** The north-facing pair sat at
  y 0.92 on the bearing cheek, and the rear deck spans y 0.92..1.24 up to
  z 1.06 — both slots were inside solid geometry. Moved to the cowl's north
  face at z 1.12, the first exposed surface north of the rotor.
- The **drum's nine bands were of roughly equal width**, so the flank
  alternated bright and dark every 10 px and read as a deck-chair stripe. Now
  wide tempered zones with narrow copper binding rings between them. The
  winding texture comes from the axial ribs, which is where it belongs — a
  winding runs along a rotor, not around it.

**The drum goes edge-on in east and west, and that is not fixable.** Its axis
is Y, so rotating the entity 90 degrees puts it on the camera's transverse
axis, where every circular cross-section projects to a line segment — the same
projection fact that ruled the X axis out originally, now unavoidable in two of
four rotations. What was fixable is that the one round feature left, the end
flange, existed at one end only, so east and west each showed a bare cut tube
on one side. Both ends carry a copper flange and bolt circle now.

Final, all eight directions: 0% full-width rows, contrast sd 50.1-52.5, ragged
0.99-1.20, fill 0.83-0.87, shadow 100% pure black, worst north overhang **0.77
tiles** — exactly the chemical plant's, vanilla's ceiling for a rotatable
machine. Wear mask 2.4% bright, well inside its band. Icons re-rendered from
the changed model.

## 2026-09-10 — the art rebuild, against the concept sheet

The repo owner rejected the first sprites: too far from `prototype.png`, "still a
lot to do". They were right, and the useful part is *why every numeric gate was
green while the sprite was wrong*. Measured on the shipped north sheet before any
change: luminance 68.7 against the vanilla recycler's 67.0, sd 49.1 against 44.5,
saturation in band, zero full-width rows, overhang 0.69. Nothing in the kit reads
**shape**, and shape was the whole fault — a pale flat pancake with a corrugated
panel where the drum should be and a spray of magenta over the middle.

**The cone was blamed for the flatness and was not the cause.** The constraint is
`max(|x|,|y|) + z <= APEX`, and at the footprint edge that leaves `APEX - 1.30`
of wall — 0.95 tiles at the old 2.25. The first build spent it anyway by putting
the south wall *outside* the footprint at y -1.58, where only 0.67 is available,
and got a 29 px front elevation. Keeping the hull inside its own tiles gives 56 px
at the same APEX. A machine cannot both hang past its tiles and be tall.

APEX went 2.25 -> 2.32 -> **2.27**, and the round trip is the lesson. 2.25 came
from the chemical plant's *north* alone, so all four directions were read off the
sidecars, and the vanilla recycler appeared to overhang 0.58 / **0.86** / 0.22 /
0.59 — grounds for raising the budget. Checking the same sheets by **first opaque
row** instead of by declared box: 0.58 / **0.69** / 0.06 / 0.59. The 0.86 was
0.17 tiles of transparent padding. The chemical plant, whose padding is under a
pixel, really does reach 0.77, and that is vanilla's ceiling for a rotatable
machine. APEX 2.27 lands on it exactly. **Measure opaque pixels, never the
declared sprite box** — a packer's margin is not art.

Bringing 2.32 back to 2.27 put seventeen parts over at once, which is what
`fit_cone()` exists for: one uniform scale moves `max(|x|,|y|) + z` by the same
factor for every vertex, where trimming needs a different edit per part (a box is
bound by its corner, a drum by the 45 degree point on its circle, a rib ring by
neither). The model ends 2.0% smaller inside its own footprint — 1.3 px on a
64 px tile — and the function refuses to scale below 0.94 so it cannot quietly
swallow a part left somewhere absurd.

**`audit()` had been checking `y + z`, which is the north overhang, not the cone.**
It passed a railing at `max(|x|,|y|) + z = 2.61` without a word, because that part
was low in *y*. It now ranks every object on the cone itself and names the
offenders. Six were found and fixed the first time it ran.

**The X-axis experiment, and why the design's original choice stands.** The concept
sheet draws the barrel lying east-west, so the drum was swung to X to match it. The
result was a flat striped rectangle with no barrel in it. The rig gotcha "a disc on
the transverse X axis is exactly edge-on" governs **every circular cross-section of
an X-axis cylinder**, not just a thin disc: a circle in the y-z plane projects to
`-(y0+z0) - r*sqrt(2)*sin(theta+45)`, a line segment, so the barrel keeps its
length and loses its roundness *including its silhouette*. Reverted to Y, where the
axis sits at 45 degrees to the view and the drum shows a curved flank plus one end
cap for the copper flange to live on. Recorded because the reasoning that led away
from it was plausible and wrong, and the sheet will tempt the next person the same
way.

What actually closed the gap to the concept, in order of how much it moved:

- **Massing.** Three tiers inside the footprint, 0.86 tiles of south wall.
- **The drum**, 0.92 -> 1.26 tiles across, with nine copper/violet/blue bands, 14
  axial ribs and a copper end flange. Bands alone would have been a mistake: a
  concentric-banded drum is rotationally symmetric and shows *no motion at all*
  when it spins. The ribs are what make the turn visible.
- **The maw**, from a grey grille to a dark box with three bright chrome rollers.
  Three attempts: gunmetal lining with scoured teeth (a grille), a dedicated
  near-black `cavity` material (better), and finally inverting the values —
  **bright rollers with dark teeth, stopping 0.15 tiles short of the opening at
  each end** so the darkness reads as cavity rather than as border.
- **Chevrons on dark backing plates.** They had been yellow-on-olive: two mid-tones
  of one warm hue, invisible at gameplay zoom however correct the geometry. Vanilla
  paints hazard stripes on black. Also genuinely diagonal now, via a new `xz_prism`
  that extrudes a polygon along Y instead of Z — a wall decal needs the other axis
  from a deck decal, and stepping a diagonal out of axis-aligned boxes reads as a
  staircase.
- **The olive palette, measured rather than judged.** The concept render's olive is
  `#584D33` at luminance 78 with a 10th percentile of 11; ours was `#71653F` at 101
  with a p10 of 38 — too bright, and with no dark end at all, which is what made a
  painted steel block read as a card. New base `#605932`, metallic 0.30 -> 0.18
  (this is flat paint, and at 0.30 the whole face carried one broad specular), and
  world ambient 0.15 -> 0.12 to let the shadows reach dark. It now measures
  `#5C4C32` at 78 against the sheet's 78.
- **The magenta went away.** Ten violet pips rode the drum's rim, so an additive
  glow layer swept an arc across the sprite every loop. Replaced with two static
  slots on the housing wall.

**Raggedness is bought with holes, not with parts.** A chunky machine reads smooth:
the rebuilt hull measured 0.97 against the 1.05 floor. The first fix added solid
blocks past the pad and raggedness went *down*, to 0.95 — each one grew the filled
area faster than the outline. `ragged` is alpha perimeter over bbox perimeter, so a
hole counts twice and a block counts against you. Four open railings clear of the
pad, a ladder standing off the west wall and four cables in open air took it to
1.11 without adding a single solid.

## 2026-09-10 — the prototype

Wrote the entity, item, recipe and technology; the data stage loads clean against
2.1.17 with base, elevated-rails, recycler, quality and space-age.

Built from scratch rather than deep-copied from `data.raw["furnace"]["recycler"]`.
A deepcopy would have carried the vanilla recycler's 2x4 collision box, its
circuit connector definitions, its `vector_to_place_result` and its frame-synced
working sound — all positioned for a machine this one is not the shape of, and
all of them the kind of thing that lands in the wrong place with nothing to warn
you. The working-sound *loop* is reused; its `sound_accents` are not, because
they fire on frames 14/20/45/60-63 of a jaw that bites, and this jaw is three
counter-rotating rollers.

The `space-age` dependency question is closed: the gate needs three science packs
that only exist with Space Age, so the dependency moved rather than the gate. It
does narrow the audience — `recycler` and `quality` ship independently of
`space-age` — and that is the cost of a tech gate the repo owner specified.

Sprite numbers stay out of the Lua entirely. `make_sheets.py` now writes a `.lua`
sidecar beside every PNG and `util.sprite_load` reads them, so a re-render changes
the crop and the shift and nothing in `prototypes/` is touched. Two things that
cost a validate each: `sounds` and `hit_effects` are globals inside base's own
data stage and have to be `require`d by file; and **`frame_count` is ignored in a
sidecar** — `util.sprite_load` takes only width, height, shift and line_length
from the file and everything else from its options table, so the anim layer loaded
as a single frame and the engine rejected the mismatched layer counts. A third,
caught by reading rather than by the loader: the light layer's shift has to come
from the full-resolution crop box, not the half-size cell box, or the glow lands
69 px left and 81 px up.

The icon is rendered at elevation 34 rather than `references/icons.md`'s 46. That
figure was tuned on vanilla's modules, which are small cubes; this machine is
squat enough that 46 letterboxed it and it turned to mush at the 32 px an icon is
actually read at.

## 2026-09-10 — animation, shadows, lights, and the rotation problem

Second `factorio-graphics` session: rigged the animation, added the shadow and
light passes, rendered all four directions and packed the sheets. Sixteen files,
4.4 MB total — the vanilla recycler spends 3.7 MB on one direction of its body
alone, because it animates the whole machine where this splits a static body
from a 64-frame overlay.

**The flat-render weakness the last session recorded is fixed, and the fix was
not where I first put it.** The raw frame measured luminance sd 26.5 against the
beacon's 31.6, and I had pushed the paint-over's `form_amount` to 1.85 to cover
it — the paint-over inventing contrast instead of sharpening it. Darkening the
palette did nothing: an absolute sd needs bright highlights as much as dark
crevices, and lowering everything moves the mean and the spread together. A
harder key with less sky fill (6.6 / 0.95 / 0.15 against the rig's validated
5.2 / 1.2 / 0.22) took the raw to sd 30.4, and the stock `form_amount` then
lands 45.7 on the packed sheet.

**The session's real finding: a rotatable entity has four north edges.**
Rotating the model swaps which axis points north, so the overhang for a
direction is `max(axis + z)` and getting north right says nothing about the
other three. North measures 0.69 tiles; east, south and west measure 1.42,
1.50 and 1.50 against a vanilla ceiling of 0.77 across every rotation of every
machine that ships. Worse, the silhouette guarantee is direction-specific too —
the disjoint-extremes massing that makes a full-width scanline impossible in
north leaves west at 23.4% full-width rows. And "put tall things south, height
is free there" turns out to be a north-only trick: rotate 180 degrees and the
cancellation becomes an addition, which is why the exhaust stack is the worst
single offender in the south view.

The condition that covers all four at once is `max(|x|,|y|) + z <= 2.25` — the
machine has to be a cone, tall in the middle and low at every edge, which is
exactly the shape of the chemical plant, the one vanilla 3x3 crafting machine
that rotates. This entity was a slab: 47 of its 105 objects broke the cone.
Put to the repo owner as a choice between re-massing and dropping to one
non-directional sheet, since `decisions.md` records rotatability as their
deliberate call; **they chose the re-mass plus the full eight sheets**.

The machine is now a stepped ziggurat and 0 of 114 objects break the cone, at a
worst-direction overhang of 0.75 against vanilla's 0.77 ceiling. Three things
the re-mass cost. The front elevation became a letterbox — the south wall was
1.06 tiles and the cone allows 0.67 at y -1.58, so the maw is a low slot and
the hopper a loading lip; every vanilla rotatable machine reads this way.
Raggedness collapsed to 0.99, because compact reads smooth — and the first fix
for that failed instructively: five railings and pipes added for perimeter all
sat *over the concrete pad*, drew opaque-on-opaque, and moved ragged from 0.99
to 0.98. Only geometry past the **pad's** outline makes new silhouette edge.
And every extreme has to be re-checked whenever anything moves: pulling the
east side in handed the east extreme to a bracket whose rows overlapped the
west chute's, and a `pipe_run` puts a flange 1.65x its radius past the endpoint
given, which quietly made a stub the west extreme and put 0.8% of scanlines
full width.

`cone_z(x, y)` is now the rule the massing is written against, `audit()` prints
the worst offender on every build, and `check_sheets.py` measures overhang per
direction off the packed sheets.

The cone alone was not enough. The re-massed machine still shipped 4.9%
full-width rows in west, because the disjoint-extremes guarantee is
direction-specific in its own right: a row is full width when the sprite's east
and west extremes fall in it, and *which parts those are* changes with the
rotation — in west they are the model's southernmost and northernmost parts and
the rows are `x + z` rather than `y + z`. `audit()` now projects all four
mappings; mirroring only negates screen x, which swaps the extremes and leaves
the row bands untouched, so the flipped set needs no separate pass. The fix was
to make the out-chute the sole southernmost part, clear of the auger housing
and the drain stub, so its row band sits above the north duct's.

Contrast needed one honest override back. The four rotations measure 39.4 /
44.4 / 46.8 / 49.5 at the preset's `form_amount`, because east presents far
more of its shaded side than west does, and one preset has to serve eight
sheets — 1.70 puts the worst inside the 43 floor and leaves the best under the
56 ceiling. That is a different thing from the 1.85 this file recorded earlier,
which was covering for a flat render; that one was fixed in the lighting.

Four modelling faults the object-ID pass and the layer montage caught, all of
them invisible in a plain render: the maw throat was a solid box whose front
face sat south of the rollers, so the shredder rendered as a 2 px line; the
rollers were then still hidden behind the lintel, because a part set deeper in
a recess appears HIGHER on screen and my three rollers were stacked into the
top of the opening; the fragments were technically rendering at 0.09 tiles and
effectively invisible; and six thin bright ridges on a 10 px drum merged into
one white stripe that strobed frame to frame instead of reading as teeth.

Two library gotchas worth not rediscovering. A freshly created empty has not
been through a depsgraph update, so `pivot.matrix_world` is still the identity
and `matrix_parent_inverse` from it is a no-op — every child silently shifts by
the pivot's position, and the drum moved 0.91 tiles up-screen. And the anim
layer has to render the body as a **holdout** rather than hidden: the anim
sheet composites above the base in game, so a moving part behind the hull would
otherwise be drawn straight over it.

## 2026-09-10 — the entity modelled in Blender

Ran `factorio-graphics` from the design plus a concept sheet the repo owner generated
(`prototype.png`). The scene is `assets/quality-recycler/entity/quality-recycler/`; all three
numeric gates pass and the measurements are in the design's new *Built* section.

The concept sheet and the design disagreed in two places and the sheet won one of them. Its
palette **replaces the design's verdigris green** for the new half with heat-tempered violet,
blue and bronze — which is the design's own heat-tint wear signature promoted to be the colour,
so it keeps the physics and drops the two-greens risk the design had flagged against itself. Its
massing did not win: the sheet draws a solid cube filling its 3x3, which is the one silhouette
this rig cannot ship, and the design's diagonal offset is what makes a full-width scanline
geometrically impossible. Two of the sheet's other decisions were unbuildable as drawn and got
changed with a reason each: the rotor turns about **Y** rather than east-west, because a disc on
the transverse axis is exactly edge-on to this camera and renders as a stripe; and the machine is
**1.56 tiles tall at the hood, not 2.5**, because at 2.5 it would draw 1.6 tiles past its own
footprint against a measured vanilla 3x3 band of 0.58 to 0.77.

The object-ID pass was worth more than every other check combined and should be the first thing
run on any future change. It found, in order: the drum sealed inside its own housing; a junction
box and four cables drawing zero pixels behind a wall; three instrument pods hanging in the
shredder's throat; a rivet row on a side wall, which at this pitch renders as a one-pixel line;
and a seam frame that had quietly grown to 17.9% of the sprite while the hero it joins held 4.9%.
Two traps in the tool itself, both of which produced confidently wrong reports before they were
understood: the legend must be a value lattice rather than a hue wheel (96 objects on a
golden-ratio hue collided so hard the report credited a ladder with 18% of the sprite), and
Blender's output path has to be absolute or the render lands elsewhere and the analysis silently
reads a stale image.

One `parts.py` gotcha cost a render and is worth not rediscovering: the greeble builders bake
their centre into the mesh and leave the object at the origin, so `place(rot=...)` rotates a part
about the **world** origin, not its own. A louvre bank placed at (1.44, -0.30) with `rot=90` flew
to (0.30, 1.44) and became the tallest thing in the sprite.

Still no `.lua`, and no sheets: what exists is one look-dev frame, not the eight directions.

## 2026-09-10 — entity design session

Ran `factorio-entity-design` end to end and wrote `quality-recycler-design.md`. The repo owner
added one constraint the scaffold did not have — unlocked after the first three planets — which
turned out to name a single real rung: `planet-discovery-aquilo` is the only vanilla technology
at metallurgic + electromagnetic + agricultural with no cryogenic pack. That gap between the
vanilla recycler (production science, Nauvis) and this one (three planets later) became the whole
art brief.

The design that came out: a salvaged vanilla recycler with planet-tier sorting gear grafted on,
hero being an eddy-current sorting rotor. Quality read as *separation* rather than
transmutation — a remelt crucible was rejected for implying a mechanic the entity does not have.

Reference numbers were measured rather than recalled, and two corrected assumptions were worth
the trouble. The **electromagnetic plant is 4x4, not 3x3** (collision 3.4 rounds up), so it is
this entity's mechanical precedent but not its size reference — chemical plant and biochamber
are, both at 2.4. And **violet 286 deg is the only quality-ramp colour no vanilla machine's
emissive claims**; legendary amber collides with the foundry. `counterpart.py` gave the palette
fractions: vanilla recycler 7-10% paint over a 45-49% rust substrate, against Space Age's
0.1-1.7%.

Three of the eight stages went against the recommendation, all recorded as chosen with the risk
stated: **four visible graded bins** over a sight-glass manifold (FFF-339 risk that four bins
imply four drawable outputs, mitigated by a common auger to one chute), **verdigris bronze** on
the new half over bare steel (two greens on one sprite, solved by separating them on material
behaviour rather than hue, with the copper seam collar between them), and the **full four
directions plus mirrored** render treatment over the single non-directional sheet every vanilla
3x3 uses — eight base sheets at 64 frames, the mod's largest art cost.

Still no `.lua`. The design fixed the footprint, the rotatability and the collision box, so those
moved into `decisions.md` where prototype work will look for them; `deferred.md` was rewritten
around what is now actually open, including a dependency problem the design created — the tech
gate needs Space Age science packs that `info.json` does not depend on.

## 2026-09-10 — mechanic decided

The repo owner gave concrete numbers for the entity: quality built in at 12% (no modules
needed), crafting speed 2x vanilla (1.0), footprint 3x3. Verified the mechanism against
`prototype-api.json` before recording it as decided rather than taking it on faith —
`effect_receiver.base_effect.quality` is a real, legal field on a `furnace`-type entity's parent
`CraftingMachinePrototype`, not a guess. Also checked the vanilla recycler's actual stats
(`data/recycler/data.lua`): `crafting_speed = 0.5`, `180kW`, `300` health, and a 2x4 — not
square — footprint, so 3x3 turns out to be barely bigger by tile count, mostly a shape change
worth flagging rather than assuming.

Recorded in `decisions.md`; the resolved question removed from `deferred.md`, which now lists
what's still open (name/prefix, recipe/tech placement, energy use, health, art). Still no
`.lua` written — this was a docs-only update, via `/claude-md-management:claude-md-improver`
redirected to this repo's own CLAUDE.md/.ai-support contract instead of that skill's generic
repo-wide audit.

## 2026-09-10 — scaffold

Mod started via `/factorio-mod-setup`. The brief: "a very simple mod... a new recycler kind to
the game, a recycler with embedded quality." Named `quality-recycler` after checking three
candidates against the mod portal API (all free); the repo owner picked it over
`embedded-quality-recycler` and `recycler-quality`.

Scaffolded per the repo's no-Lua-until-asked convention: `info.json`, `changelog.txt` (0.1.0,
open), `LICENSE`, `locale/en/`, `README.md`, this `.ai-support/` tree, and this mod's own
`CLAUDE.md`. Added to the root `CLAUDE.md` → *Mods in this repo* list. No prototype or script
code written.

Dependencies settled as `quality >= 2.1.0` and `recycler >= 2.1.0` (both explicit — see
`decisions.md`), confirmed against the installed `data/quality/info.json` and
`data/recycler/info.json`. `quality_required: true`; `expansion_required` deliberately left
unset after checking `doc-html/auxiliary/mod-structure.html` (it gates belt-stacking properties,
not quality).

The exact "embedded quality" mechanic is the open question in `deferred.md` — the next step is
`factorio-entity-design`, once the repo owner wants to move on it.
