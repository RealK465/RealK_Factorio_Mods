# Quality Recycler entity — design notes

The mod's one entity: a recycler with quality built in, 4x4, unlocked after the first three
planets. This file is the visual record — what it is, what it looks like, and why each choice
was made. The numbers it must satisfy live in `decisions.md`; open questions in `deferred.md`.

The mod has **no art-direction register**, so this document sets the house style by default.
Anything here that generalises past this entity should move into one when a second entity exists.

Conceived 2026-09-10 via the `factorio-entity-design` session. **Modelled 2026-09-10** — the
Blender scene is `assets/quality-recycler/entity/quality-recycler/`, and the repo owner's concept
sheet is `prototype.png` beside this file. Three things in the sections below were changed by
building them; each is marked **[built]** and carries the measurement that forced it.

**Rebuilt twice since.** The 2026-09-11 rebuild (marked **[rebuilt 2026-09-11]**) put the
rotor on the Z axis; the same day's second session (**v3**, the last section of this file)
rebuilt the machine around the engine's real output position, redesigned the rotor as sealed
magnetic hardware and added a composite panel family. Where an earlier section and the v3
section disagree, v3 is current.

## Function & constraints

Shreds items back into their components like the vanilla recycler, but grades what comes out —
12.5% quality on every craft with no modules fitted (12% when this was written), at twice the
vanilla recycler's speed.

| | |
|---|---|
| Footprint | **4x4 since 2026-09-11** (the owner's call; 3x3 before). `collision_box = {{-1.7,-1.7},{1.7,1.7}}` is the vanilla 4x4 convention (the electromagnetic plant measures 3.4). Everything below this table that says 3x3 describes the machine as first built; the *v4* section says what the larger box changed |
| Fluid connections | none — it is a `furnace`, deep-copied from `data.raw["furnace"]["recycler"]` |
| Rotatable | **yes, four directions plus mirrored** — the full vanilla recycler treatment. Direction reads off the maw and the west scrap chute |
| Module slots | not decided; vanilla recycler has 4. See *Not settled* |
| Energy | electric. Draw not decided; vanilla recycler is 180 kW |
| Tier | after Vulcanus, Fulgora and Gleba — metallurgic + electromagnetic + agricultural science, no cryogenic |

**The tech rung is a real one, not a vague late-game.** Exactly one vanilla technology sits at
those three sciences with no cryogenic pack: `planet-discovery-aquilo`. Verified 2026-09-10 by
scanning every `type = "technology"` in `data/space-age/prototypes/technology.lua` — everything
else at that level also needs cryogenic, so it is post-Aquilo. This entity unlocks at the exact
moment the player has all three mid-game planets' industries and nothing from Aquilo yet.

## Lore anchor

It is **not a new machine**. It is a vanilla recycler that came back from three planets with
half of it replaced. The shredder end is the same battered olive machine the player has been
running since production science; the sorting end is Fulgoran-grade equipment grafted on, and
the seam between them is visible and deliberate.

That is Factorio's own premise — DIY equipment assembled from salvaged and better technology —
and it is what makes the palette legible instead of arbitrary. Two things worth ruling out:

- The rotor is **not** a magic quality field. It is an eddy-current separator: a copper-wound
  drum spun fast enough to induce currents in the fragments passing it, flinging them by
  conductivity into different bins. Real recycling plants use exactly this, downstream of
  exactly this kind of shredder.
- The violet is **not** a brand colour. It is where the rotor housing got hot — steel tempering
  runs straw, bronze, purple, blue as temperature rises, and the hottest zone lands on purple.
  It happens to be epic quality's colour too, which is the point, but the surface has a physical
  reason to be that colour before the semantics arrive.

## Hero & family

**Hero: the eddy-current sorting rotor.** Modelled first, oversized, and it keeps the detail
budget. **[rebuilt 2026-09-11] It turns about Z, not Y** — a vertical poled disc in a bronze well,
not a horizontal drum. See *The rotor axis* below; the reason is the rotation cone, not taste. It was chosen over a remelt crucible and an optical sorter because quality in Factorio is
*selection out of the same input*, not creation — a separator is honest about the mechanic where
a crucible would imply transmutation the entity does not do.

**Family: the vanilla recycler, salvaged, with planet-tier gear grafted on.** It quotes the
recycler's jaw maw, olive skirt, hazard chevrons and brass fittings on the intake half. The
sorting half quotes Fulgora — oxidised bronze, exposed rotor, a machine that looks recovered
rather than manufactured.

Two anchors, and they are different entities:

- **Mechanical precedent — the electromagnetic plant.** `effect_receiver = { base_effect =
  { productivity = 0.5 }}`, a permanent module-free effect, is the exact shape of this entity's
  `quality = 0.12`. Also the model for a rusted hull whose identity lives in an animated layer
  over the top. It is **4x4** (collision 3.4), so it is not the size reference.
- **Size family — the chemical plant and the biochamber**, both 3x3 at collision 2.4. The
  chemical plant is the one to study: it is the audit's case study for a 3x3 that breaks its
  outline on all four sides.

## Silhouette

**Two masses on a diagonal, offset, with an open gap between them.**

```
PLAN 3x3, N up          SIDE, from S
+-----+-----+-----+              ______
|  .  |   ROTOR   |         ____/######\___
+-----+   TOWER   +        /    `--(o)--'   \
| SORT GAP  |     |       | maw |  |  | bins |
+-----+-----+-----+       |_[]__|__|__|______|
|  INTAKE   |bins |        ^ substantial S wall
|   MAW     |     |
+-----+-----+-----+
```

- **Tall:** the rotor at the centre, with the exhaust stack directly above the seam. **[built]**
  — the height is **1.36 at the hood crown, 1.54 at the stack cap**, not the 2.5 this section first
  claimed. Screen row is `-(y + z)`, so a 2.5-tile mass sitting north draws 1.6 tiles past the
  footprint and covers whatever is placed behind it. Measured off the shipped 2.1 sprites: the
  **chemical plant overhangs 0.77 tiles north, the biochamber ~0.1, the vanilla recycler 0.58**.
  The built model sits at **0.68 north and 0.75 in its worst direction**.
  The design first bought that height back by putting the stack in the *south*, where a negative
  y cancels a positive z — **which is a north-only trick**, and the stack became the worst
  offender in the machine once the other three rotations were rendered. It is central now, where
  its height is free in every direction and it is the skyline in all four. See *the rotation
  cone* below.
- **Low, past the footprint:** the hopper lip breaching the south edge, the scrap chute
  breaching the west.
- **Front elevation:** a substantial south wall on the intake half — not a plan view. The
  near-plan-view render with no south face is the single tell that most reliably outs mod art.
- **Anchored** on a concrete pad with skid feet, with a dirt skirt and AO where it meets ground.

**The offset is load-bearing, not styling.** Screen row is set by `y + z`, so a full-width
scanline happens whenever the west extreme and the east extreme land in the same row. Putting the
intake widest to the west at the front and the rotor widest to the east at the back makes their
y-ranges disjoint, so **no full-width row is geometrically possible**. The audit found not one
full-width row across every vanilla machine sprite, and this repo's own beacon shipped at 88%
full-width rows past seven gates — none of which read shape. Getting it from the massing rather
than from a later fix is the whole reason this stage came before components.

Target: fill ~0.68, ragged ~1.7. Audited vanilla bands are fill 0.58-0.88 and ragged 1.14-2.19.

**[built]** The offset did its job — **0% full-width rows in all four rotations**, with the
two extremes' row bands 0.51 tiles apart at worst, so no scanline *can* cross. Fill came out
**0.84**, in band.

**[rebuilt 2026-09-11]** Still 0% full-width rows in all four rotations and both mirrorings, and
fill came down to **0.65–0.76** against the chemical plant's 0.75 — a more broken outline than
the first build's 0.83–0.87. Two things changed how it is achieved:

- **The extremes are assigned deliberately, and one of them needed a part of its own.**
  `audit()` collects every vertex within **0.06** of an extreme into that extreme's row band, so
  the machine's northernmost part — a 0.07-tile cage boss at y 1.12 — was pulling in the rotor
  step, the capacitor bank and two cable runs, and handing east a 0.96-tile band of full-width
  rows. A tie bracket standing 0.12 clear of everything else owns max-y alone now, and its rows
  (−1.06..−0.75 in east) miss the loading apron's (0.43..1.38) entirely. The four mappings are
  worked out in `qr_layout.py`'s module docstring rather than discovered by rendering.
- **The raggedness comes from hardware hanging PAST the footprint**, not from railings over the
  pad. The cone bounds height, not reach: at ground level it allows ±2.25, and vanilla spends it
  — the chemical plant's sprite is 145 screen px tall against a 96 px footprint, nearly all of the
  excess in pipe stubs at z ≈ 0. The loading apron, the scrap chute and the output chute hang to
  ±2.05 below z 0.35, which took the sprite from 86 × 112 screen px to **102 × 134**.

**Raggedness is bought with holes, not with parts, and that is the opposite of the
obvious move.** `gates.silhouette` measures `ragged` as **alpha perimeter over bounding-box
perimeter**, so a hole counts twice — once for each side — and a solid block counts *against*
you by growing the filled area and often the bbox with it. Massing this machine as the chunky
block the concept asks for took raggedness to 0.97, under the 1.05 floor; the first fix added
solid greebles past the pad and it fell further, to **0.95**. What worked was open frame in
clear air: four railings standing clear of the pad's own outline, a ladder standing off the
west wall, and four cables. **1.11**, with no solid geometry added at all.

Two placement rules the fix depends on, both learned by breaking them:

- **A railing level with the pad edge is worthless.** Its posts draw opaque-on-opaque over
  the pad and the daylight between them never becomes alpha. They have to clear the pad's
  outline (x -1.36..1.34, y -1.42..1.38), not sit on it.
- **Nothing else may come within 0.06 of an extreme.** `audit()` collects every vertex in
  that band into the extreme's row range, so a second part touching it hands over its whole
  row span. A cooler at y 1.62 beside a duct at 1.66 put 0.21 tiles of rows full width; the
  out-chute at x 1.44 beside the east bracket at 1.48 put 0.43.

## Component list — the four flows

Seven flows and 161 distinct kinds over 213 objects, against an audited vanilla band of 8-15 kinds. Parts marked `>` already exist
in `factorio_render`'s catalogue and cost roughly one line each to place.

| Flow | Parts |
|---|---|
| **Hero** | Eddy-current drum with exposed copper pole faces, oversized · copper end flange and bolt circle at **both** ends · split pillow blocks with bolt pairs and a grease line · a guard hoop over the drum's west shoulder · ring-gear drive taken off the salvaged half, so the seam is mechanical rather than cosmetic |
| **Power in** | `>junction_box` on the tower and a second on the hood · four sagging `>cable` runs · four capacitor cans with a copper busbar on the east apron — the rotor draws hard and that should show |
| **Material through** | Jaw maw and hopper, salvaged olive, breaching the south edge · scrap chute past the west edge · the open sorting gap with a splitter ridge and four angled guide plates · four graded bins · a common auger under them running to one output chute at the south-east |
| **Heat out** | `>louvre_bank` on the hood flank and `>radiator` fins on the deck · a recessed louvre bank in the rear deck · exhaust stack and cowl with soot. Earned, not decorative: eddy currents genuinely make heat |
| **Human service** | `>ladder` up the tower and a second off the west wall · a grated catwalk at the seam with `>railing` · `>handwheel` at the coolant line and at the hatch · `>gauge_pod` cluster · `>placard` stencils and hazard chevrons |
| **Shredder drive** | Finned motor about Y · gearbox with a split-line flange and bolt ring · belt guard sloping to the roller shafts · drive sprocket. The rollers turned and nothing on the model turned them |
| **Structure** | `>rivet_row` along panel seams on all four walls · stiles and rails on all four walls · `>skid_feet` at the corners · `>flange` collar at the seam · concrete pad |

**The olive half's top tier is a rounded hood, not a third flat plate.** Two
stacked box tops were ~2 tiles of empty painted deck, and the camera sees the
deck more than any other surface — vanilla never leaves one bare. A cylinder
about Y at r 0.30 is the curved primary form the machine otherwise has none of
outside the drum, and it carries the crown pipe, clamps, inspection plate,
gauge, stack and beacon on top of it.

**All four walls carry front-elevation treatment, not just the south one.**
"A side wall renders as a one-pixel line" is a rule for a FIXED entity. This one
rotates, so the west wall is the front elevation in east, the north wall is in
south, and the east apron is in west. Treating only the south wall left three
rotations reading as blank painted plates.

**[rebuilt 2026-09-11] The four bins are gone; a grading unit replaced them.** One instrument pod
on the south-east deck carries five up-facing lenses in the exact quality colours read out of
`data/quality/prototypes/quality.lua` — normal `#B2B2B2`, uncommon `#2BA53D`, rare `#1968B2`, epic
`#8900B2`, legendary `#B26800` — with a scan window a bar sweeps across, and one output chute
beside it. UP-facing is the whole design: an emissive on a wall is face-on in one rotation, a
bright streak in two and invisible in the fourth, where the deck is the one surface this camera
always sees. Five rather than four, because the neutral tier is what makes the row read as a scale.
This also retires the risk the paragraph below was spending, and the paragraph is kept for its
reasoning.

**The four bins were a deliberate accepted risk.** The entity has one output inventory (the
vanilla recycler's `result_inventory_size = 12`), so four visible bins can imply four separately
drawable outputs — the FFF-339 class of error, where a detail promises a mechanic the entity does
not have. The repo owner chose them anyway for legibility, over a four-sight-glass manifold. The
mitigation is the **common auger**: all four bins visibly discharge onto one belt running to a
single chute, so the single output is on screen alongside the four grades.

**Cut deliberately:** nothing that implies filtering, circuit control or fluid handling.

## Material zones

Six. Zones 1 and 2 are the two halves and must stay legibly different — that separation is the
design.

1. **Salvaged olive** — warm and dark, and **sampled off the concept sheet's own hero
   render rather than off its palette chip**. The render measures `#584D33` at luminance
   78 with a 10th percentile of 11; the chip measures `#6F6F42` at 107, and a chip is a
   flat swatch where a hull is a lit surface. Painting the chip gave `#71653F` at
   luminance 101 with a p10 of **38** — 29% too bright and, more damaging, with no dark
   end at all, which is exactly what makes a painted steel block read as a flat card.
   Base is now `#605932` (warmer than the render it produces: grime and the key shift
   hue about 10 degrees toward yellow-green on the way through), and it measures
   `#5C4C32` at luminance 78 against the sheet's 78.
   **Metallic 0.18, not 0.30.** This is flat paint on steel over the machine's one large
   uninterrupted surface; at 0.30 under a 6.6 key the whole face carried a single broad
   specular sheen — `design-language.md`'s "flat single colours" tell, arrived at from
   the other direction. Confined to the intake skirt and hopper, chipped hard at edges.
2. **Heat-tempered bronze** — the new half. **[built], and this replaces the verdigris green
   this section originally specified.** The repo owner's concept sheet has no second green in
   it: it promotes this document's own *heat-tint wear signature* to be the new half's *colour*,
   running violet near the rotor through blue to bronze at the extremities. Same physical story
   as the wear map below, one fewer risk — the two-greens problem the paragraph after this list
   worries about simply stops existing — and the sheet's own purple chip measures **hue 290**
   against the violet 286 chosen for the emissive, so the accent survives intact.
   Sampled off the concept render, not off its chips: the render sits at `#5B4F6E` (sat 0.28,
   val 0.43) where the chips sit at sat 0.48, and a chip painted across a whole half is a toy.
3. **Bare / galvanised steel** — the tower frame, ducts, catwalk, auger housing.
4. **Dark iron / gunmetal** — the maw cavity, bin mouths, rotor housing interior, every recess.
5. **Copper** — rotor windings and pole faces, the seam collar. Physically motivated: eddy
   rotors are copper.
6. **Rubber black** — cables, hose runs, the auger belt.

**The two halves are separated by material behaviour as well as hue.** Olive is flat chipped
paint, warm and dark; the tempered half is an oxide film over bronze, blotchy and cool. Different
surface physics separates more strongly than different hue does at gameplay zoom, and the
**copper seam frame sits physically between them** as a warm divider. (This paragraph originally
existed to manage a two-greens clash; with zone 2 no longer green the clash is gone, and what
remains is still the right instruction.)

Whole-entity paint fraction should land near **4-5%** — between base-game (13.7-44.7%) and Space
Age (0.1-1.7%), which is exactly right for a salvaged base-game machine wearing planet-tier gear.
The vanilla recycler measures 7-10%.

**Emissive: violet, 286 deg** — epic quality's `{137, 0, 178}`. It is the only colour in the
quality ramp that no vanilla machine's emissive claims. Verified 2026-09-10 against
`counterpart.py`: foundry orange 15 deg, electromagnetic plant cyan 195 deg, biochamber green
75 deg, cryogenic plant red/orange, fusion reactor magenta-red 345 deg, vanilla recycler green
status lamp 90 deg with orange interior 30 deg. Legendary amber (`{178,104,0}`, ~35 deg) was
rejected because it collides with the foundry.

## Wear map

All three signatures, each owning a region — a map of use, not an overlay.

- **Heat tint, at the rotor zone.** Steel tempering colours radiating from the hottest point:
  straw, bronze, purple, blue. This is where the violet accent gets its physical cause.
- **Scour polish, along the material path.** Maw jaws, chute floors, sorting-gap lip and bin
  mouths worn mirror-bright. Traces the route through the machine in pure value contrast, which
  is what survives at gameplay zoom.
- **Metallic dust, downwind of the rotor.** Grey-metal fines piling on horizontal surfaces and
  drifting in the sorting gap. Keep it as value clumping, not glitter — a fine sparkle sits below
  the ~3px legibility floor and reads as noise.

And the generic placements, all by physics:

- Edges, corners and anything protruding: chipped to bare metal **and cleaner** — grime wears off
  exactly where paint does.
- Panel joins, seams and the skirt: grime pools, darkening toward the ground.
- Below the rotor bearings: oil streaks running down.
- Exhaust cowl and louvres: soot, fading downward onto the tower roof.
- Feet, flanges, weld seams, pad edge: rust wherever water sits.
- **Hand-polish** — patina rubbed to bright bronze on ladder rungs, railing top rail, handwheel
  and hatch handles. This is the human-service flow told through wear, and it is a strong
  equipment read that costs nothing.

No surface at 100% clean paint, and no uniform wear either.

## Busy / calm

- **Dense hero zone: the rotor deck, north-east.** Drum, pole faces, bearing housings, ring gear,
  cables, junction box, gauge cluster. This is where the budget is spent.
- **Calm: the salvaged olive intake skirt.** Large flat panels carrying only rivet rows, edge
  chipping and the grime gradient.
- **Calm: the tower's south wall** — the front elevation, held quiet with a ladder and one
  placard so the mass reads.
- **Kept low so the hero is never occluded: the four bins.** Plain open-topped boxes with a
  colour-coded lip and a rivet row, nothing more. The bins read as *result*, the rotor as *cause*,
  which is also the correct causal story. Their legibility comes from colour and count, not from
  hardware, so keeping them simple costs the four-grade read nothing.

## State & animation

**[rebuilt 2026-09-11]** Nine working systems plus a designed idle, in `qr_anim.py`.

| # | Element | Per loop | Layer | Why it loops |
|---|---|---|---|---|
| 1 | Eddy rotor, 14 poles | 2 pole pitches, 0.80 deg/frame | anim | the hero doing the action |
| 2 | Drive wheel, 20 teeth, counter-rotating | 5 tooth pitches | anim | ties the salvaged half to the new one |
| 3 | Three shredder rollers, 9 teeth, counter-rotating | 4 pitches | anim | quotes the vanilla recycler's own jaw |
| 4 | Cooling fan, 5 blades | 6 pitches | anim | a second rhythm, so the machine is not one clock |
| 5 | Feeder ram on the loading apron | one stroke, quick in and slow out | anim | mechanical effort, and the apron's reason to exist |
| 6 | Four fragments in flight into the output chute | one per quarter loop | fx | shows separation happening |
| 7 | Violet field pulse at the coil | two beats a loop, phase-locked to the rotor | light | the rotor's energy, small and local |
| 8 | Four Fulgoran arcs at the rotor contacts | a fixed irregular pattern, not random | light | Fulgora is the opposite of periodic |
| 9 | Grading scan sweep, five lenses lighting in sequence | two sweeps | light | makes "built-in quality" visible |
| - | Green status lamp | never animates | lamp | `always_draw`, so idle reads as idle |

No two systems share a period: the gear's 5 against the rotor's 2 and the fan's 6 are chosen so
three parts never turn in lockstep, which would read as one mechanism rather than several.

**`animation_speed = 2`, not the vanilla recycler's 4.** A crafting machine's animation is scaled
by its crafting speed unless `constant_speed` is set, and this machine runs at 1.0 against the
recycler's 0.5 — at 4 it would play at twice the recycler's apparent tempo standing next to one.
Per-frame rotor rotation is then 0.80 degrees against a 25.7-degree pole pitch, well under the
half-pitch limit, so it cannot wagon-wheel backwards.

**Seamlessness is measured, not assumed.** For each animated layer, the wrap step |f63 -> f0| is
compared against the distribution of the loop's own 63 other adjacent steps: `anim` wrap 0.135
against a median of 0.129 and a max of 0.202, `fx` wrap 0.045 against a median of 0.067. Comparing
the wrap to |f0 - f1| alone gives a false positive on a flicker layer, whose typical step *is* a
discontinuity.

**Every loop closes exactly on 64 frames**, and each rotation is a whole number
of turns for that reason: a loop that does not close is the animation
equivalent of a seam, and the sprite jumps on the wrap once a second forever.
The gear's 2:1 against the drum is chosen to close rather than to be
geometrically exact — the true ratio from the radii is 1.61.

The jaw is **rollers turning**, not the design's "intermittent bite". A bite
needs two jaws closing on each other, and the vanilla recycler's own jaw sound
is frame-synced to that; three counter-rotating shredder drums are what the
geometry supports and what a real shredder does. Recorded as a change, not an
oversight.

**Idle:** rotor still, field glow off, maw shut. Only the green status lamp, per the vanilla
convention. The difference between idle and working must be readable at a glance without zoom.

**The bin lips are colour-coded in paint, never lit.** Colour identifies the grade; light never
claims one. A sprite sheet cannot know what quality actually came out, so a lit amber bin would
read as "I just got a legendary" on a fixed animation loop. This is the same FFF-339 discipline
the four-bin decision above already spends once — spending it twice would be careless.

Motion reads effortful and mechanical throughout. The drill's weak radial sweep was replaced for
reading as "gently harvesting" (FFF-350); nothing here should sweep gently.

**Direction** reads off the maw and the west scrap chute, which are asymmetric and unmistakable.

## Built — the scene, and what it measures

`assets/quality-recycler/entity/quality-recycler/` holds the sources — nothing there ships, and
only exported PNGs go into the mod's `graphics/`:

**[rebuilt 2026-09-11]** The generator was split by job. Everything still imports the first file,
and the geometry helpers, materials, cone rule, direction transform and audit all live there
unchanged.

| file | what it does |
|---|---|
| `quality_recycler_gen.py` | materials, geometry helpers, the cone rule, `set_direction()`, `audit()`, `fit_cone()`. Idempotent, rebuilt from source every run |
| `qr_rebuild.py` | the curved primitives the generator could not make — `ring()` (a true annulus or arc on any axis), `torus()`, `radial_bars()`, `barrel()`, `hood()`, `yz_prism()`, `wall_chevrons()` — plus the three Phase 1 look-dev variants and the quality-lens materials |
| `qr_layout.py` | **the machine**: pad, rotor, drive wheel, shredder, junction, grading unit, service corner, power, heat, stack, structure, emissives, fragments |
| `qr_anim.py` | the eight working systems and the idle |
| `lookdev.py` | one-frame look-dev at sprite density and at 4x, with `audit()` on every build |
| `swatch.py` / `measure_swatch.py` | every material as a lit stepped block through the entity's own rig, and what it measures. **This is how the palette is tuned** — a base colour is not what a material renders |
| `show.py` | paint over a look-dev frame, composite on Nauvis and print the four numbers that actually move this sprite, each against its vanilla target |
| `preview_game.py` | composite the packed sheets the way the ENGINE draws them — real terrain, night, the real vanilla recycler / EM plant / chemical plant beside ours at matched density, and looping GIFs |
| `render_entity.py` | headless driver: `--layers base,anim,glow,shadow --dirs N,E,S,W --frames 64` |
| `make_sheets.py` | paint-over per frame, pack to 8x8, write `sheet_numbers.txt` |
| `make_look.py` | one-frame look-dev: paint-over, gates, the vanilla A/B |
| `check_sheets.py` | the gates and the per-direction overhang, on the packed sheets |
| `check_wear.py` | renders the edge-wear term alone through a `material_override` and gates it — the only check that measures the MODEL rather than an output PNG |
| `check_visibility.py` | the object-ID pass, as a script rather than something rebuilt by hand each time: every object gets a flat emission colour off a value lattice, renders to scene-linear EXR, and reports what draws nothing, what is under the legibility floor, and what the biggest objects are |
| `quality-recycler.blend` | the saved scene |

Two helpers in the generator worth knowing about before adding surface detail:
**`xz_prism()`** extrudes a polygon along Y instead of Z, which is what a decal on a
vertical wall needs (`prism()` can only decorate a deck), and **`chevrons()`** builds a
hazard band out of it — leaning parallelograms on a dark backing plate, because vanilla
paints hazard stripes on black and yellow-on-olive is two mid-tones of one hue.

**Four layers, not one animated body.** The vanilla recycler ships its whole
machine as a 64-frame sheet (`recycler-N.png` is 1360x2432, 3.7 MB, per
direction). Splitting the static body from the moving parts costs four sheets
instead of two and lands all thirty-two files at **14.2 MB together** — still
well under the 30 MB the vanilla recycler spends on the same eight directions.
The anim layer is 13.0 MB of it, the base 0.7, the glow 0.5 and the shadow
under 0.1, so the moving parts are where any future budget has to come from:

| layer | frames | prototype |
|---|---|---|
| `-<D>.png` | 1 | the body; `repeat_count = 64` to stay in step |
| `-<D>-anim.png` | 64 | rotor, drive wheel, rollers, fan, feeder ram. A LAYER of `animation`, so it is always drawn and merely stops advancing when the machine idles -- which is right for a rotor, whose parked pose is the idle design |
| `-<D>-shadow.png` | 1 | `draw_as_shadow = true` |
| `-<D>-fx.png` | 64 | **[added 2026-09-11]** the fragments in flight. A `working_visualisation`, so they VANISH when the machine stops; a chip frozen in mid-air over an idle machine is a bug you cannot un-see, and that is the whole reason this is not in `anim` |
| `-<D>-light.png` | 64 | `draw_as_glow = true`, `blend_mode = "additive"`, `fadeout = true`, half resolution at `scale = 1.0` |
| `-<D>-lamp.png` | 1 | **[added 2026-09-11]** the green status lamp alone, `always_draw = true`, so an idle machine still glows at night. 22x22 px -- the cheapest layer on the entity |

The anim layer renders with the body present as a **holdout**, not hidden: the
anim sheet composites *above* the base in game, so a moving part that ought to
be behind the hull would otherwise be drawn straight over it. A holdout punches
alpha-0 where the hull is nearer the camera, which is the occlusion the
composite cannot work out for itself.

`sheet_numbers.txt` beside them carries every width/height/shift; the sprite
sidecars are prototype work and are not written yet.

## The rotor axis — Z, and why Y was not enough

**[rebuilt 2026-09-11]** The section below is kept because its analysis is correct and still
explains why the concept sheet's east–west barrel is impossible. What it missed is the third
option. At this rig screen row is `-(y + z)` and screen column is `x`, so:

| ring axis | north / south | east / west |
|---|---|---|
| **Z** | true circle | **true circle** |
| Y | true circle | **edge-on line** |
| X | edge-on line | true circle |

`set_direction()` rotates the model about Z, which turns a Y-axis ring into an X-axis one in east
and west. So a horizontal drum is round in two rotations and **flat in two** — which is exactly
what the first build's east and west views were, and no amount of banding or material work fixed
them. **On a rotatable entity, a Z-axis rotor is the only radial form that reads in all four.**

The hero is therefore a vertical disc: fourteen copper pole pieces radiating from a tempered hub,
over an open bore with an eighteen-slot stator visible through the gaps, inside a bronze well,
under four guard arcs with daylight between them and a toroidal field coil above. It projects as a
circle with spokes from every side.

The lore survives intact — a vertical eddy rotor is still an induction separator, and the fragments
still fly off it radially into the output. What is lost is the literal horizontal barrel, and the
repo owner approved that trade at the Phase 1 checkpoint after seeing all three options at
gameplay zoom.

### The original Y-versus-X analysis, which stands

**The drum turns about Y, north-south — and this was built the other way once, to
check.** The concept sheet draws its bands wrapping an east-west barrel. Swinging the
drum to X to match it produced a **flat striped rectangle with no barrel in it**, and
the reason is worth stating precisely, because the obvious reading of the rig gotcha
lets you talk yourself out of it.

"A disc on the transverse X axis is exactly edge-on" is usually read as being about
thin discs — gears, flywheels — leaving a long *cylinder* seemingly safe, since a
cylinder about X is perpendicular to the view and should be seen broadside. It is not
safe. Every circular cross-section of that cylinder is edge-on: a circle in the y-z
plane at radius `r` projects to screen row `-(y0+z0) - r*sqrt(2)*sin(theta+45)`, which
is a **line segment**. So the barrel keeps its full length and loses its roundness
entirely, silhouette included, and no amount of banding or shading puts it back.

On Y the axis sits at 45 degrees to the view, so the drum shows a curved flank *and*
one end cap — which is where the copper end flange and its bolt circle live, and they
are most of what the concept's rotor crop actually shows. The Y axis is also where an
eddy-current separator's drum sits relative to west-to-east flow.

The cost is honest: the sheet's barrel lies across the machine and this one stands up
it. That is a limit of Factorio's projection, not a choice still open.

| | measured | vanilla reference |
|---|---|---|
Measured on the packed sheets, **all eight directions**, 2026-09-11:

| | measured | vanilla reference |
|---|---|---|
| Overhang, worst of eight | **0.77 tiles** | chemical plant 0.77, recycler 0.69 |
| Overhang, N / E / S / W | 0.72 / 0.75 / 0.75 / 0.77 | chem 0.77 / 0.61 / 0.38 / 0.30 |
| Full-width rows | **0% in all eight** | 0% across every shipped machine sprite |
| Fill | 0.65 - 0.76 | chem 0.75, recycler 0.79 |
| Ragged | 0.96 - 1.31 | chem 0.98 - 1.24, recycler 1.03 - 1.16 |
| Luminance sd | 46.3 - 48.0 | `gates.contrast` band 43-56 |
| Neutral grey (sat < 0.18) | **13 - 17%** | recycler 31%, chem plant 12% |
| Top-quarter minus bottom-quarter luminance | E/S/W 27.8 - 30.5, **N 10.4** | recycler 27.7, chem plant 48.5 |
| Local 5 px luminance sd, at game pixels | 31.2 - 33.4 | recycler 29.2, chem plant 27.1 |
| Sprite size, screen px | **102 x 134** | chem plant 93 x 138, recycler 70 x 144 |
| Clipped pixels | 0.00% | gate allows 0.05% |
| Shadow | 100% pure black, 16-27% soft edge | gate allows 8% soft |
| Edge-wear mask | 9.7% bright, 20.0% survive | `gates.wear_mask` band 20-35 |
| Distinct kinds of detail | 139 over 205 objects | audited vanilla band 8-15 kinds |
| Objects drawing zero pixels | 6 of 205, all keyed OFF at frame 0 | - |
| VRAM, 48 PNGs | **100.9 MB** | recycler 253.2, foundry 151.8, EM plant 147.7, cryo 36.8, chem 16.1 |

**North's top-to-bottom spread is the weak direction at 10.4** against the other three's
27.8-30.5 and the vanilla recycler's 27.7. In north the loading apron, the hazard chevrons and the
grading pod all fall in the bottom quarter and none of them is dark, so the gradient flattens. It
is one rotation of four and it is not visible as a fault; it is recorded because it is the number
that would move first if this entity gets another pass.

Local 5 px sd is the other number outside vanilla's band, and it is understood rather than
unexplained: it is the cost of 205 objects on a 3x3, and the paint-over cannot take it out --
sweeping `crevice_amount` 0.95 to 0.40 moved it only 33.9 to 31.3 while flattening the sprite.
The next pass on this entity should cut parts, not turn knobs.

**The raggedness floor had to be measured per direction rather than taken from
the gate.** `gates.silhouette` floors it at 1.05, and this machine's east view
came in at 0.96. Measuring the shipped sheets the same way, cell 0 of each
direction: the **chemical plant's east is 0.98** and the **vanilla recycler's
south is 1.03** — both under that floor, on Wube's own art. A rotatable machine
reads smoother from whichever side shows its long flank, and the 1.14-2.19 band
the floor came from was measured one direction per entity. `check_sheets.py`
therefore uses 0.95, which sits under the lowest vanilla rotation; raising the
east view to 1.05 would have meant bolting greebles on to clear a bar the
reference art does not.

**Luminance sd is the wrong number to steer the paint-over by, and steering by
it made this sprite worse twice.** The band is 43-56 and this machine sat
inside it at 45-51 through two rejected builds. Split the variance instead —
form above 12 px against grain below 3 px:

| | form | grain | ratio |
|---|---|---|---|
| vanilla recycler | 16.1 | 26.5 | **0.61** |
| chemical plant | 24.8 | 23.0 | 1.08 |
| this entity at `form_amount` 1.70 | 27.2 | 21.8 | **1.25** |

Vanilla carries its contrast in small hard-edged parts. `form_contrast` has
radius 11, so raising it spends the budget on exactly the band vanilla has
least of: the knob was buying the sd number by SMOOTHING the machine. The
render is not the problem — the raw frame measures sd 30.5, near the Pure
beacon's 31.6, under a harder key with less sky fill (**6.6 / 0.95 / 0.15**
against the rig's validated 5.2 / 1.2 / 0.22).

Settled overrides: **`form_amount` 0.30**, with the sd paid for by
`contrast_amount` **1.35** (radius 7) and `crevice_amount` **1.30**
(radius 1.8), plus `saturation` 0.62 and `value` 0.90. That lands form 15.6,
grain 37.9, sd 52.9 — hard part separation and dark gaps, which is what
vanilla actually is. Saturation leaves at 0.30 against the vanilla recycler's
0.31.

**The object-ID pass is the tool that earned its keep here, and it is now
`check_visibility.py` rather than something rebuilt by hand.** Every object gets
a flat colour off a value lattice, renders, and is counted. It has found, across
two sessions: the drum sealed inside its own housing; a junction box and four
cables drawing zero pixels behind a wall; three instrument pods hanging in the
throat of the shredder; a seam frame grown to 17.9% of the sprite while the hero
it joins held 4.9%; **the ring gear**, the design's one mechanical link between
the two halves, buried inside the bearing wall; **the radiator** inside the rear
deck; **the entire capacitor bank** embedded in a 0.14-tile apron; the north
pillow block behind the drum; the sorting-gap guide plates at 0, 0, 2 and 7
pixels; and a fan "ring" built with `cyl()`, which makes a solid disc, lidding
the hub it was meant to surround. None of that is visible in a render, and none
of it is reasoning you can do about the 3D scene.

Two things about the tool itself, both learned by getting them wrong:

- **The encoding must be a value lattice, not a hue wheel**, or the report
  aliases and lies.
- **Write scene-linear EXR, not PNG.** The first cut set the view transform to
  Raw to keep the lattice intact through a PNG; only 34% of pixels then
  classified, and the report confidently declared the bins, the drive motor and
  the capacitor bank invisible while all three were plainly in the render. EXR
  carries the value the emission shader produced and no colour-management
  setting can quietly break it — classification went to 97%.

**What the pass cannot tell you is whether an occluder can be moved.** Three
parts here are genuinely unviewable and were deleted rather than relocated: the
north pillow block, its hub and its bolt circle. In north the drum itself is in
front of them; in south the rear deck tops out at 1.06 against their 1.05.
Splitting `cheek-n` into two piers to open a window onto them did not help,
because the wall was never the occluder.

## The rotation cone — the constraint that re-massed this entity

**A rotatable entity has four north edges, not one.** Rotating the model about
Z swaps which axis points north, so the overhang for a direction is
`max(axis + z)` — and satisfying it for north says nothing about the other
three. The single condition that covers all four is

```
max(|x|, |y|) + z  <=  footprint_half + overhang_budget      (2.32 for a 3x3)
```

i.e. the machine has to fit inside a **cone**: tall in the middle, low at every
edge. That is exactly the shape of the chemical plant — the one vanilla 3x3
crafting machine that rotates — and it is why its four directions measure
0.77 / 0.61 / 0.38 / 0.30 where this machine, which is 1.4-1.9 tiles tall at
its own perimeter, measures **0.69 / 1.42 / 1.50 / 1.50**.

**The budget is 0.77, and getting there needed the measurement done twice.**
2.25 came from the chemical plant's *north* figure alone. Reading all four
directions off the sidecars — `height/128 - shift_y/32 - footprint_half`, with
the recycler's half-depth 2.0 in north/south and 1.0 in east/west, since it is
2x4 — gave the recycler 0.58 / **0.86** / 0.22 / 0.59, and APEX was raised to
2.32 on the strength of that 0.86.

**That 0.86 is transparent padding.** The declared sprite box is what the
packer left, not what the art fills. Measuring the first opaque row inside each
cell instead:

| | N | E | S | W |
|---|---|---|---|---|
| vanilla recycler, declared | 0.58 | **0.86** | 0.22 | 0.59 |
| vanilla recycler, opaque | 0.58 | **0.69** | 0.06 | 0.59 |
| chemical plant, opaque | **0.77** | 0.61 | 0.38 | 0.30 |

So nothing vanilla ships draws more than **0.77** tiles past its own tiles in
any rotation, the original figure was right, and the padding overstated it by
0.17 on one sheet. APEX is 2.27 — the chemical plant's exact ceiling. Measure
opaque pixels, never the declared box.

**The cone is not what flattens a machine — leaving the footprint is.** At the
footprint edge the cone allows `APEX - 1.30`, which is 0.97 tiles of wall. The
first build put its south wall at y -1.58, *outside* its own tiles, where only
0.69 is available, and shipped a 29 px front elevation; the same APEX with the
hull inside the footprint gives 55 px. A machine can hang past its tiles or it
can be tall, and the second is worth far more. Every tier is now sized against
`cone_z()` at its own outermost corner, and no part of the hull crosses ±1.32.

**`fit_cone()` does the last 2% with a uniform scale rather than by trimming.**
Correcting APEX from 2.32 to 2.27 put seventeen parts over at once, each needing
a different edit — what binds a box is its corner, what binds a drum is the 45
degree point on its circle, what binds a rib ring is neither. One uniform scale
moves `max(|x|,|y|) + z` by the same factor for every vertex, so it fixes all
seventeen and changes no proportion; the model ends 2.0% smaller inside its own
footprint, which is 1.3 px on a 64 px tile. It refuses to scale below 0.94, so
it cannot quietly hide a part left somewhere absurd.

**`audit()` checked `y + z` for a year and that is the north overhang, not the
cone.** It passed a railing at `max(|x|,|y|) + z = 2.61` in silence, because
that part was low in *y* and only tall in *x*. It ranks every object on the cone
itself now and prints the offenders; six turned up the first time it ran.

**The first build ignored this and was re-massed because of it.** Measured off
its packed sheets before the fix:

| | north overhang | full-width rows | ragged | contrast sd |
|---|---|---|---|---|
| N | 0.69 | 0% | 1.17 | 45.7 |
| E | **1.42** | 0% | 0.93 | 41.3 |
| S | **1.50** | 9.5% | 0.94 | 47.4 |
| W | **1.50** | 23.4% | 1.79 | 51.7 |
| *vanilla, any rotation* | *0.06-0.77* | *0%* | *1.14-2.19* | *43-52* |

47 of its 105 objects broke the cone. The machine is now a stepped ziggurat —
a low apron at the footprint edge, two steps up through the hulls, the rotor
and its stack owning the middle — and **0 of 114 objects break it**, at a
worst-direction overhang of 0.75 tiles against vanilla's 0.77 ceiling.

Two things this says that the north view alone could not:

- **The silhouette guarantee is direction-specific too**, and it is a separate
  problem from the cone. A row is full width only when the sprite's east and
  west extremes fall in it, so the fix is to give those to parts whose row
  ranges are disjoint — but *which* parts those are changes with the rotation.
  In west the extremes are the model's southernmost and northernmost parts and
  the rows are `x + z`, not `y + z`. Checking north alone passed this machine
  twice while west shipped 23.4% and then 4.9% full-width rows. `audit()` now
  projects all four mappings:

  | direction | screen x | screen row |
  |---|---|---|
  | N | `x` | `y + z` |
  | E | `y` | `-x + z` |
  | S | `-x` | `-y + z` |
  | W | `-y` | `x + z` |

  Mirroring negates screen x, which swaps the two extremes and leaves every
  row band untouched — so the flipped set needs no separate pass.
- **"Put tall things south, height is free there" is a north-only trick.** The
  exhaust stack was placed at y -1.05 precisely because a negative y cancels a
  positive z. Rotate 180 degrees and that cancellation becomes an addition —
  the stack is the single worst offender in the south view at
  `max(|x|,|y|) + z = 3.44`.

`cone_z(x, y)` in the generator is the rule, `audit()` prints the worst
offender on every build, and `check_sheets.py` measures the overhang per
direction off the packed sheets. Three things the re-mass cost, all worth
knowing before the next entity is designed:

- **The front elevation became a letterbox.** The south wall used to be 1.06
  tiles tall at y -1.58; the cone allows 0.67 there. The maw is now a low slot
  and the hopper a loading lip rather than a raised chute. Every vanilla
  rotatable machine reads this way, and it is the price of rotating.
- **Raggedness had to be rebuilt.** A compact machine reads smooth: the
  re-massed hull measured 0.99 against the 1.05 floor. The first attempt to
  fix it added railings and pipes that all sat *over the concrete pad*, so
  they drew opaque-on-opaque and contributed no alpha boundary at all — ragged
  moved 0.99 to 0.98. Only geometry past the **pad's** own outline makes new
  silhouette edge. Five protrusions that clear it took it to 1.16.
- **Every extreme has to be re-checked when anything moves.** Pulling the east
  side in handed the east extreme to a bracket whose rows overlapped the west
  chute's, and a `pipe_run`'s endpoint flange sits 1.65x its radius further
  out than the point given — which quietly made the stub the west extreme and
  put 0.8% of scanlines full width.

## Render budget

The repo owner chose the **full vanilla recycler treatment: four directions plus mirrored**, and
confirmed it a second time after the rotation cone turned it from a render cost into a massing
constraint. That is eight directions at four layers each — 1,040 Cycles frames, about fifty
minutes on this machine.

It comes out far smaller on disk than vanilla's, because vanilla animates the whole machine
(`recycler-N.png` alone is 1360x2432 and 3.7 MB, per direction) where this splits a static body
from a 64-frame overlay of only the parts that move. Numbers per direction are in
`sheet_numbers.txt`.

## Not settled

- **Frozen layer for Aquilo.** Deliberately skipped for now. Nothing breaks — the entity just
  renders unfrosted on Aquilo next to vanilla entities that do freeze. Note that at eight
  directions, adding it later is eight more sprites, not one.
- **Prototype name and prefix.** Nothing chosen. The design would support a name that reads as
  the sorting step rather than the shredding one.
- **Recipe, and whether it gets its own technology** or an effect added to an existing one. The
  science gate is decided (see *Function & constraints*); the tech's own identity is not, and
  neither is its icon.
- **Energy draw, health, module slots, pollution.** Vanilla recycler is 180 kW / 300 hp / 4 slots
  / 2 pollution per minute; the electromagnetic plant is 2000 kW / 350 hp / 5 slots / 4. Nothing
  chosen between them.
- **`space-age` dependency.** The tech gate needs the three planet science packs, which only
  exist with Space Age, but `info.json` currently declares only `base`, `quality` and `recycler`.
  Either the dependency set or the gate has to move. Prototype-stage question, flagged here
  because the design is what created it.
- **Item icon and `thumbnail.png`.** Not designed. Both are `factorio-graphics` work once the
  entity render exists.
- **Sounds.** Not considered. The vanilla recycler has an elaborate working sound with
  frame-synced jaw and trash variations that would be worth studying rather than reusing blindly.

## v3 — the ejection pass (2026-09-11, second session)

**[rebuilt 2026-09-11, v3]** The v2 build above was photographed in the engine and the owner's
brief on it was: nothing ejects, it is not futuristic yet, and it is busy without being rich.
Each section below that v3 changes is marked; the reasoning for every change is here, the
measurements in `docs/art/quality-recycler/LOG.md`. v2 is commit 57acdf1, with its later
generator state in `assets/quality-recycler/entity/quality-recycler/versions/*-v2.py`.

### Where the output actually is

`vector_to_place_result = {0, -1.8}` on the prototype is a **direct-output position**, the
same field a mining drill uses for its drop point: the tile past the machine's back edge,
centred. The yellow alt-mode arrow leaves the footprint there, and the results appear there.
v2's art had the output chute on the south-east and the arrow pointing out of the rotor
housing. **v3 is laid out from that point backwards.** Blender's +y is north, so the port is
at (0, +1.5) in the model. Nothing about the prototype value changed; the art agrees with it
now.

### The route, and why it is a ram

Intake stays on the south wall (the maw), which is the side opposite the output. From there:
three shredder rollers → a flanged transfer duct east across the seam into the rotor well →
sorting at the rotor → a **discharge notch cut through the cowl's west side**, down a dark
chute → a **collection trough running due north** along x −0.46..−0.10 at z 0.62..0.92 → a
**hydraulic pusher ram** whose head travels 0.72 tiles north and takes the chips with it →
off the trough's end into the port hood's **open throat** → out of the mouth on the north edge
as two doors part → over a sill painted with hazard chevrons → onto the next tile.

**A ram, not a flap, and the reason is the camera.** The view direction is (0, +y, −z), so
the one motion this camera cannot see is a slope descending away from it — which is exactly
what a top-hinged flap dropping out of a north-facing mouth would be: invisible in north, a
line in east and west. A stroke along y is screen-vertical in north and south and
screen-horizontal in east and west: visible in all four. The brief's other options (a shutter,
a vibrating tray, a transfer arm) were weighed the same way; a Z-axis arm would also read in
all four, but a straight ram along a straight trough is the simpler, stronger shape at
gameplay zoom, and it lets the chips ride ahead of a single bright head.

**The trough is raised** (z 0.62..0.92) because in east the rotor stands between it and the
camera; at deck height it vanished behind the cowl, raised its top 0.36 tiles clear it.

**The throat is what makes the port read from behind.** In north the mouth faces away and the
hopper is behind the rotor. The hood's west half is left open — a dark rectangular well that
the chips visibly drop into off the trough's end, rimmed in violet by the ejector lamp — and
up-facing surfaces are the ones every rotation sees. The riser (the hopper's tall back, to
z 0.99) carries the painted grade squares on its top for the same reason.

**The sill owns the sprite's max-y extreme on purpose.** `audit()` hands an extreme's whole
row band to every part within 0.06 of it, so a small low plate (0.44 × 0.15 × 0.06) standing
0.12 clear of everything keeps that band tiny, and the apron's rows never share it in east or
west. The apron lost its rails and moved 0.06 west for the same reason. In south a chest on
the output tile draws over the sill; the throat and the doors carry the reading there.

### The rotor, second redesign — sealed magnetic hardware

**[rebuilt v3]** v2's rotor was fourteen tapered copper poles radiating from a hub in the
open, and in the engine it read as a fan. v3's is, from the outside in: an armoured composite
**cowl** (four arcs, R 0.50..0.72) with four **windows** onto twelve **copper winding
bundles**; a thin **violet field gap** (R 0.478..0.498); a composite **end-cap** turning with
the rotor — a solid outer and inner annulus with **six short curved vent slots** between them,
a bolt circle, a polished rim — and under it twelve **blocky magnet segments** alternating
gunmetal and worn bright steel in a copper retaining ring; a polished spindle through the
middle with a copper collar. Two arcs flicker across the field gap.

Three things were tried and rejected on the way, each by rendering: **polished segments**
(a metal inside a bore has only the bore to reflect and came out as a dark annulus; worn
steel at metallic 0.42 reads bright); **coils at the well floor** (4 px through the windows —
at 45° a window 0.22 wide shows nothing 0.2 tiles below it; they sit 0.055 under the rim
now); and **six radial slots in the cap** (a spoked wheel again; concentric slots are the
vocabulary of a ventilated motor end-shield and stopped the reading at once).

The rotor turns 60° per loop, which is two pole pitches and one slot pitch, so the twelve
poles and the six slots close on the same frame.

### Material zones, revised

Zone 2 (the tempered bronze) is now the new half's *structure* — the plinth, the hopper body,
the trough base, the coolant tank — and two new zones sit on top of it:

7. **Composite, bright** — `#B6B5AB` lit, satin (roughness 0.34–0.54, metallic 0.10), cool
   bone. On the rotor cap, the cowl, the port riser and hood only: the two hero zones.
8. **Composite, dark** — `#7E8380`, the same family a step darker, on the trough fairing, the
   port pockets, the feed collar, the armour plates and the power cabinet, each with a dark
   seam groove.

Both are cool against the warm olive and copper, which tells the two-technologies contrast
through temperature as well as hue. The first v3 pass put the bright composite on everything
new and measured mean luminance 87–98 against vanilla's 63–67 — white plastic; pulled back to
the hero zones, the pale cowl is the brightest large form, which is the hierarchy the design
wants. `polished` (metallic 0.55) is confined to small machined parts: the spindle, the ram
cylinder, the cowl clamps and rim, the doors' frame.

**The five quality colours are paint, not light.** v2's five lit lenses read as a row of
indicator lights in the engine. v3 paints five matte squares — each grade mixed 45% toward a
neutral, chipped at the edges — on a dark plate on the riser's top face, and the scan window
is gone. Colour may name a grade as paint; light never claims one. Violet is the only light
and it is on the route only: the field gap, the discharge edge, the scanner over the trough,
the throat rim. The green status lamp stays.

### Cut, moved, added

- **Cut:** the drive gear in the slot, the cooling fan, the louvre bank, the gauge pods, the
  capacitor bank and busbar, the lifting gantry, the north tie bracket, the scrap chute and
  the two deck strips. Fewer, larger forms: 194 objects and 147 kinds against v2's 205.
- **Moved:** the exhaust stack onto the olive crown where the fan was (the old machine had a
  chimney; the retrofit kept it); the status lamp stays on the cap.
- **Added:** the feed collar framing the maw in dark composite with rivet rows; armour plates
  on the west skirt and the north wall; a power cabinet with two copper insulators hanging
  past the west edge (the sprite's west extreme, replacing the scrap chute — a second chute
  confused the route); a coolant tank on Z in the north-west with two thin grey hoses to the
  cowl, ferruled; two power cables from the deck's junction box up onto the cowl and two more
  across the seam into a junction box on the old hull — the new half plugging into the old.

### State & animation, revised

| # | Element | Per loop | Layer |
|---|---|---|---|
| 1 | magnet ring, retaining ring and vented cap, 60° | 2 pole pitches / 1 slot pitch | anim |
| 2 | three shredder rollers, counter-rotating | 4 pitches | anim |
| 3 | feeder ram on the apron | one stroke | anim |
| 4 | **ejector ram**, 0.72 tiles north and back | out slowly f2–26, hold, back quickly f30–42 | anim |
| 5 | **port doors** parting and closing | open f22–28, shut f42–48 | anim |
| 6 | **three chips**: ride the ram, drop into the throat, leave the mouth, land on the sill, are thrown back down the discharge chute | one batch | fx |
| 7 | violet field gap and discharge edge, two beats | phase-locked to the rotor | light |
| 8 | scanner over the trough lights as the batch passes | f8–16 | light |
| 9 | ejector lamp on the throat rim | f20–40 | light |
| 10 | two arcs across the field gap, irregular | fixed pattern | light |
| — | green status lamp | never | lamp |

Idle is frame 0: doors shut, ram home, cap parked, no chip (the fx layer is a
working_visualisation and does not draw), no violet. Only the green lamp.

### After the engine (round 5)

Photographed working in all eight orientations, a fresh-context review read the port as a
latched steel chest — two bright door plates with a centre seam on a flat face — and could not
tell working from idle in a single frame. Four changes, each with its reason:

- **The mouth is a recess** in the body's north end, with a **violet strip inside it** that is
  visible only while the doors are parted. Any frame with the doors open now shows a lit
  throat; a shut one shows dark gunmetal shutters, not a lid. Bright doors were the chest.
- **The field ring is dimmed in the base sheet** (the render driver sets the three violet
  materials to 0.22 for the base pass only). The base is drawn in every state, so a ring lit
  in it made an idle machine glow by day; the working-only glow sheet is the state cue now, by
  day as it already was at night.
- **A hydraulic power unit** — tank on Z, motor block, pressure hose to the cylinder's rear —
  fills the south-east corner the review found bare, and it is the part the ram already
  implied.
- **Hazard plates on the pocket lids**, up-facing, so the output end carries hazard weight in
  every rotation and the chevrons no longer point only at the intake. An eave band over the
  mouth was tried and sat over the cone.

Rejected: shortening the ground-level overhang (deliberate, see `deferred.md`).

## v4 — the 4x4, inside its own tiles (2026-09-11, third session)

**[rebuilt 2026-09-11, v4]** The owner put v3 in the game beside its neighbours and came back
with three things: two zones of the sprite sit outside the placement area and overlap the
entities next to it; the pad in front of the plinth barely has any content and the animation
could do more; and, mid-session, the entity is to be **4x4**. The reasoning for each change is
here, the measurements in `docs/art/quality-recycler/LOG.md`. v3 is commit 59d9c7f.

### The two zones, and the rule they became

The zones circled in the owner's screenshots are the v3 power cabinet and the loading apron.
Both were placed on purpose: the cone bounds height, not reach, and the 3x3 spent the same
reach on low hardware that vanilla spends on pipe stubs (the cabinet to 0.36 tiles past the
west edge, the apron to 0.55 past the south). What the offline gates cannot see is that a
neighbour is drawn in that space too. Placed in a row, each machine's apron lay across the
next machine's wall, and beside a vanilla recycler the cabinet lay on the recycler's body.

**Ground-level hardware stays inside the footprint.** Everything at or near ground level now
sits inside ±1.95 tiles. The one exception is deliberate: the sill under the mouth reaches
0.28 tiles past the north edge, because that tile is the output and the sill is what the chips
land on. The sill is 0.20 layout units wide instead of 0.22 (see the silhouette below).

### 4x4, and how the machine grew

A 4x4 was the owner's call. Two ways to fill it were weighed:

- **Re-lay the machine at 1:1 with more and bigger sub-machines.** The right answer for a
  hero asset with unlimited time; every literal in a 900-line layout moves, and the v3 forms
  that already work — the rotor, the port, the olive half — would be rebuilt for no gain in
  legibility.
- **Scale the v3 machine uniformly and spend the margin on the two zones.** One number on the
  root, exactly as `fit_cone()` is applied, so every part and every keyed animation offset
  grows together. Chosen.

The scale is **1.2, not 4/3**, and the cone decides it: the 4x4's APEX is 2.75 (half-depth 2.0
plus the same 0.75), and at 4/3 the cowl rim and the riser back both land past it — the
machine would fill its tiles to the edge at height and cover the one behind it. At 1.2 the
worst cone value is 2.72, no fit is needed, and 0.4 tiles of margin remain on every side at
ground level. That margin is what the cabinet and the apron moved into.

The layout file therefore still speaks the 3x3's units: 1 unit = 1.2 tiles, the footprint
edge is ±1.667 there, and the audit prints tiles. `quality_recycler_gen.BASE_SCALE` carries it.

**The output is on the west centre tile, and so is the port.** A 4x4's centre is a tile
corner, so a result placed at x 0 would sit on the boundary between the two centre tiles past
the north edge — the vanilla recycler, which is 2 wide, offsets its own to −0.35 for exactly
this reason. The prototype says the same `{-0.35, -2.3}` and the whole port (body, riser,
roof, throat, mouth, doors, pockets, sill, feet, grade paint) sits on `PORT_X = -0.29` units,
which is that offset in the layout's units. Two intermediate values were tried and are the
reason the number is worth not touching again: −0.12 units for one build, then 0 for one, and
what each cost is under *round 7* and *round 8* below. The sill's rows in east and west move
with the port, and the apron's east edge sits at −0.70 so they still clear its rows.

### The pad, filled: the route's second leg made visible

v3 drew the shredder-to-rotor leg as a closed duct, and the pad in front of the plinth —
the front of the machine's east half in north — was concrete with a hose across it. It now
carries the route:

- **A spout** on the hull's east face, a dark opening in a composite frame.
- **An open feed trough** on two legs from the spout across the pad and up onto the plinth,
  rising 0.21 units over its run, with a dark bed between two low walls.
- **An inlet hood** bolted to the cowl at 250°, its outer face carrying the dark opening the
  trough runs into.
- **Four more chips** streaming along the trough, a quarter length apart, one full length per
  loop, each tumbling 60° over the run. They start inside the spout and end inside the hood,
  both solid and both held out of the fx layer, so the wrap from t 0.98 to t 0 happens out of
  sight. That is the animation the owner asked for: the shredder's discharge visibly travels
  to the sorter in every rotation, because the trough is up-facing.
- **An operator console** on the pad facing the intake (human service): composite, a sloped
  top with a bezel and a **violet status strip** that breathes on a slow two-beat in the glow
  sheet, a label plate on its face, a conduit into the plinth. The first pass drew the screen
  at 0.19 × 0.15 units and it read as a purple slab; it is a lit line now, and in the base
  sheet it is dimmed to 0.06 (the other violets stay at 0.22) so an idle machine shows dark
  glass rather than a purple sticker.
- **A pressure gauge** on the hydraulic unit's motor block.

Knock-on moves, each for a collision: the deck junction box east to (0.36, −0.55) and its
seam east of the hood; the two seam cables became bridged conduits rising over the trough
(a sagging cable at trough height would lie across the chips); the pressure hose runs low
across the pad and passes under the trough; the seam rivets rose above the spout.

### The west wall and the east margin

- **A walkway with a handrail** along the west skirt's foot, and **a ladder up the west wall**
  from it, built by hand because the library's ladder lies in the X-Z plane and this one
  climbs a wall that faces west. The walkway is where the v3 kick plate was; the open rail
  and rungs are what the silhouette's raggedness is made of in north and south.
- **The power cabinet** moved from past the west edge to the pad against the skirt, at the
  south-west, and lost its feet (it stands on the pad). Its rows in north and south still
  clear the cowl's, which is what lets it stay the west extreme.
- **A low coolant step** east of the plinth under the cowl's overhang, with two radiators and
  a return pipe off the cowl. It fills the 0.4 tiles the scale left inside the east edge, and
  it is the sprite's east extreme now: its rows in north (−0.22..1.58) and south (−1.08..0.71)
  stay clear of the cabinet's, which is what lets it be wider than the cowl. Its south end
  stops at y −0.30 units for exactly that reason — at −0.40 the two bands touched.
- **The pad** first grew to ±1.55 units on the west and south, and that cost the silhouette:
  raggedness fell to 0.87–0.91 in five of the eight directions against the 0.95 floor. The
  reason is worth keeping. `ragged` is alpha perimeter over box perimeter, and it is bought
  with holes — but a hole only counts when the *ground* shows through it. The walkway's rail,
  the space under the apron and the space under the coolant step all looked onto concrete
  once the pad reached under them, and the sprite's outline became the pad's own straight
  edges. So the three platforms now stand on short legs with daylight under them — the same
  construction as the sill — and the pad stops at the skirt on the west, is notched out under
  the apron, and ends 0.16 short of the coolant step. The same eight base frames then measure
  1.10–1.18, inside vanilla's 0.98–1.24. The pad is still 0.07 inside every extreme, so it
  never owns an edge and never makes a row full width.

### After the engine (round 6)

A fresh-context review of the engine shots passed the two zones, the pad, the states and the
grounds, and found three things worth a static re-render: the east side still left 0.3 tiles
of dirt inside the edge (the coolant step widened to 1.82 tiles, its rows unchanged); the
pad's south-east corner was plain slab in north (two coolant drums); and in south the rotor
well's drum wall was a dark undetailed mass under the pale port blocks (two bands, a seam and
a nameplate). Rejected: the green lamp lit when idle — it is the idle cue by design — and a
visible mouth in east and west, which the camera cannot give a face that is edge-on to it;
the sill and the pocket plates mark the output there.


### After play (round 7): the port in east and west, the icon, the loop

The owner placed the 4x4 in all four directions and circled the port in east and west: the
arrow sat at the bottom of the port block, where in north and south it sat at its centre.
Measured against this session's own engine shots, whose placement geometry is known, **the
arrow was on the mouth in every direction** — the port was not misplaced. What moved was the
port's *bulk*: in east and west a part's height projects up-screen, so the 1.19-tile riser and
the hood over the mouth drew their pale mass 0.6–0.9 tiles north of the mouth on the ground,
and in east the port's own 0.15-tile offset west added to it. North and south hide the same
projection because there height and distance stack along the output axis, where the port
already reads as "behind" or "in front". Two changes, both geometric:

- **The port was centred on the machine** (`PORT_X = 0`), with the result left at
  x −0.15 tiles on the reasoning that 5 px from the seam is still inside a 0.7-tile mouth.
  It was, and that is exactly what round 8 undid: the mouth straddled the seam, so nothing
  told a player which of the two tiles under it was the output.
- **The port is low at the mouth end.** The roof falls from 0.68 at the riser to 0.55 at the
  mouth (it was 0.92 to 0.52), the riser's front step is 0.66, the throat walls 0.60, the
  body under the roof 0.48; only the back step the trough feeds through keeps its height
  (0.94, just over the trough's top), and the grade paint rides on it. The port's visual
  centre in east moved from about 0.75 tiles north of the arrow to about 0.3 — the rest is
  the mouth's own doors and lintel, which stand 0.15–0.5 tiles high and must.

The rule this leaves: **keep the output end low; the tall part of a port belongs behind the
mouth, not over it**, because a rotatable machine shows that height perpendicular to the
output axis in two of its four rotations. It is what vanilla's recycler does — its output end
is its low end.

**The icon shows the whole machine now.** Two earlier icons cropped into the rotor on the
reasoning that the hero is the identity; the owner read the result as not showing the
machine, which is the verdict that counts. Measured against vanilla's machine icons (recycler,
electromagnetic plant, foundry: subjects 60x63 of the 64 px box, 61–76% opaque, luminance
mean 79–100 with sd 57–64, saturation 0.41–0.60), the whole machine at the old 40-degree
elevation trimmed to 62x50 and measured 49 / 29 / 0.31 — wide, flat, dark. Lowering the camera
made it *flatter* (62x46 at 33 degrees): those are tall machines and this one is 1.2 tiles high
on a 5.4-tile corner-on footprint, so its projected height is 5.4 sin(e) + 1.2 cos(e) and only
reaches its width near 52 degrees. At 52 with the key at 5.4, the fill at 1.0 and the entity
paint-over applied to the icon (saturation 1.3, value 1.06) it measures 62x56, 54% opaque,
83.5 / 54.7 / 0.40, 0.4% clipped — inside the band on everything but opacity, which a machine
with a stepped outline cannot match against a box-shaped one.

**The loop is busier and reads as a working machine.** The rotor turns 120 degrees a loop
instead of 60 (1.9 degrees a frame against a 30-degree pole pitch, so it still cannot
wagon-wheel); five chips ride the ejector instead of three and tumble as they fly out of the
mouth and again down the discharge chute; six chips stream along the feed trough instead of
four.

**Measured after the round.** 256 objects, 184 kinds, cone 2.72 under 2.75, silhouette margins 0.19-0.33. Gates on the packed sheets, all eight directions: contrast sd 48.7-51.3, clipping 0%, full-width rows 0%, fill 0.71-0.80, ragged 1.08-1.18, shadow 100% pure black, north overhang 0.70-0.73; `FAILURES: none`. 154 MB of VRAM. Data stage clean on 2.1.17. Photographed working in the engine (every quality recycler `status working`): the arrow sits on the mouth in all eight orientations, and in east and west the sill, pockets and roof now sit around it with only the thin riser back step above -- the geometry cannot do better than that, because the mouth's own doors and lintel stand 0.15-0.5 tiles high. The abutting row still shows ground between every pair of machines.

### After play (round 8): the port on the output tile (2026-09-12)

The owner played the machine facing south with a steel chest on each of the two centre tiles
past the mouth and sent a screenshot: the alt-mode arrow sat on the seam between the chests,
and the port's mouth, doors, sill and hazard pockets were symmetric about that seam. Nothing
in the picture said which chest would fill. The round-7 argument — the arrow is inside the
mouth either way — was true and beside the point: the mouth was in both tiles.

Two changes, made together because the art is built from the output position:

- **The result is at `{-0.35, -2.3}`**, the vanilla recycler's own x for an even-width
  machine. 0.35 tiles from the seam is 11 px at gameplay zoom, and the arrow sprite, about
  half a tile wide, now sits entirely inside the west tile.
- **The port moved to that line** (`PORT_X = -0.29` units), and its **throat is centred over
  the mouth** rather than being the hood's west half: the trough discharges at x −0.46..−0.10
  and the throat cannot follow the port further west, so the port has a hood shoulder on each
  side of a central well instead of a solid east half. Body, riser, roof, mouth, doors,
  pockets, bollards, feet, sill and grade paint all followed. The seam between the two
  centre tiles now falls beside the port rather than through it.

What the move cost, and how it was paid: the sill owns the sprite's max-y extreme, so in east
and west its rows must stay clear of the apron's. It is **0.44 units wide** now (four
chevrons, the outer legs inboard) instead of 0.60, and the **apron's east edge moved from
−0.56 to −0.70** with its track, legs, chevrons and the feeder ram following; the worst
silhouette margin is 0.14 tiles (west), against 0.19 before. The round-7 worry — that an
offset port reads north of the arrow in east — did not come back, because the round-7 fix
that actually mattered was the low mouth end, which stayed: in east the offset projects
up-screen, but so does the output tile, by the same amount.

**East and west: the port is posed per direction.** The owner then sent two more screenshots,
east and west, with the port block plainly north of the arrow. Measured on this session's own
engine shots: in east the port's parts spread from 0.2 to 1.7 tiles north of the machine's
centre with the arrow at 0.35, the block's centre 0.7 tiles north of it; in west the block's
centre sat 0.4 tiles north of the arrow. The cause is the projection, not the layout. Screen
row is `-x + z` in east and `x + z` in west, so a part's height *and* its extent across the
output axis both become screen height, and the arrow -- a ground position -- is at the port's
foot in both. Round 7's low mouth end helped and could not finish it: the port is 1.6 tiles
wide across the axis and up to 0.94 high, and everything with height draws above its own
ground. No single geometry centres the block on the arrow in east *and* west, because the
height term has the same sign in both while the port's offset flips.

So the port is posed per direction, the way vanilla's oil refinery is four models: for the
east and west renders (and their mirrors) the raised parts of the port -- body, riser, roof
shoulders, throat, doors, mouth, pockets, bollards, feet, grade paint -- slide `PORT_EW_SHIFT`
= 0.25 units (0.3 tiles) screen-south via `delta_location`, which stacks on the doors' keyed
travel. The five ejected chips are keyed to follow only on frames 27..45 (inside the hopper and
flying out of the mouth), with both jumps landing on frames where the chip is scaled to
nothing; they ride the unmoved trough before and tumble down the unmoved chute after. **The
sill, its legs and its chevrons do not move**: they are the drop point at ground level, and
the sill owns the sprite's max-y extreme, whose rows in west would otherwise slide into the
apron's and break the silhouette guarantee. The mouth's ground line ends up 0.3 tiles south of
the arrow in east, straddling the seam; the sill still sits inside the output tile, and it is
the sill a player reads at ground level. `qr_layout.port_shift()` is registered on
`gen.DIRECTION_HOOKS` and runs from `set_direction()`, so every driver -- render, look-dev,
object-ID pass -- poses the same way; north and south get a zero shift, and the audit, which
reads the model at north, is unaffected.

**Measured after the round.** 257 objects, 186 kinds, cone 2.72 under 2.75. Gates on the
packed sheets, all eight directions: contrast sd 48.7–51.6, clipping 0%, full-width rows 0%,
fill 0.71–0.81, ragged 1.11–1.20, shadow 100% pure black, north overhang 0.70–0.73;
`FAILURES: none`. Data stage clean on 2.1.17 with and without Space Age. In the engine, every
machine working, a chest on both candidate tiles in all eight orientations: the arrow sits
inside one chest, that chest receives the results, and the mouth, doors and sill are over it.
Beside a vanilla recycler with the same chest pair, both machines feed the west tile.

### State & animation, revised

| # | Element | Per loop | Layer |
|---|---|---|---|
| 1 | magnet ring, retaining ring and vented cap, 120° | 4 pole pitches / 2 slot pitches | anim |
| 2 | three shredder rollers, counter-rotating | 4 pitches | anim |
| 3 | feeder ram on the apron, 0.11 units (the head stops short of the bottom roller) | one stroke | anim |
| 4 | ejector ram, 0.72 units north and back | out slowly f2–26, hold, back quickly f30–42 | anim |
| 5 | port doors parting and closing | open f22–28, shut f42–48 | anim |
| 6 | five chips: ride the ram, drop into the throat, tumble out of the mouth onto the sill, are thrown tumbling back down the discharge chute | one batch | fx |
| 7 | **six chips streaming along the feed trough**, spout to hood, tumbling | one trough length | fx |
| 8 | violet field gap and discharge edge, two beats | phase-locked to the rotor | light |
| 9 | scanner over the trough lights as the batch passes | f8–16 | light |
| 10 | ejector lamp on the throat rim | f20–40 | light |
| 11 | **console status strip**, a slow breathe | two beats | light |
| 12 | two arcs across the field gap, irregular | fixed pattern | light |
| — | green status lamp | never | lamp |

Idle is frame 0: doors shut, both rams home, cap parked, no chip anywhere, the console's
strip dark glass. Only the green lamp.

### Measured

250 objects, 184 distinct kinds. Cone worst 2.72 against APEX 2.75 (no fit applied), north overhang 0.70 on the geometry. Gates on the packed sheets, all eight directions: contrast sd 48.3-51.4, clipping 0.00%, full-width rows 0% everywhere, fill 0.72-0.81, ragged 1.09-1.19 (vanilla 0.98-1.24), shadow 100% pure black, north overhang 0.70-0.73 tiles against vanilla's 0.77 ceiling; `FAILURES: none`. Edge-wear mask 11.4% bright, survive 22.2% inside the 20-35 band. Object-ID pass: 186-202 of 238 objects drew per direction before the review round's additions, nothing dead. 96 files, 12 MB on disk, **151 MB of VRAM** (v3's 99 MB times the 1.44 area of a 1.2x sprite; the vanilla recycler is 253). Data stage clean on 2.1.17. Photographed working in the engine in all eight orientations (every machine logged `status working`): the arrow lands on the port in each, the results land in the chest on the tile the offset predicts and in the other tile for the mirrored set; a row of three abutting machines beside a vanilla recycler and an electromagnetic plant shows an unbroken strip of ground between every pair and nothing on a neighbour; idle machines are dark with the green lamp only; at midnight the console strip is quieter than the field ring; Fulgoran dust and Aquilo snow read as well as Nauvis. The icons were re-rendered from the v4 model.
