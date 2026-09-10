# Quality Recycler entity — design notes

The mod's one entity: a recycler with quality built in, 3x3, unlocked after the first three
planets. This file is the visual record — what it is, what it looks like, and why each choice
was made. The numbers it must satisfy live in `decisions.md`; open questions in `deferred.md`.

The mod has **no art-direction register**, so this document sets the house style by default.
Anything here that generalises past this entity should move into one when a second entity exists.

Conceived 2026-09-10 via the `factorio-entity-design` session. **Modelled 2026-09-10** — the
Blender scene is `assets/quality-recycler/entity/quality-recycler/`, and the repo owner's concept
sheet is `prototype.png` beside this file. Three things in the sections below were changed by
building them; each is marked **[built]** and carries the measurement that forced it.

## Function & constraints

Shreds items back into their components like the vanilla recycler, but grades what comes out —
12% quality on every craft with no modules fitted, at twice the vanilla recycler's speed.

| | |
|---|---|
| Footprint | 3x3. `collision_box = {{-1.2,-1.2},{1.2,1.2}}` is the vanilla 3x3 convention (chemical plant, biochamber both measure 2.4) |
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
budget. It was chosen over a remelt crucible and an optical sorter because quality in Factorio is
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

**The four bins are a deliberate accepted risk.** The entity has one output inventory (the
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

| Element | Per loop | Why it loops | built |
|---|---|---|---|
| Eddy rotor | one full turn, 14 copper poles | the hero doing the action | yes |
| Fragments across the sorting gap | arc from rotor into bins, one per bin, evenly phased | shows separation happening | yes |
| Violet field glow at the rotor gap | two pulses, 2.20 down to 1.35 emission | the only emissive; small and local | yes |
| Ring-gear drive | two turns, counter to the rotor | ties the salvaged half to the new one | yes |
| Jaw maw | three counter-rotating toothed rollers | quotes the vanilla recycler's own jaw | yes |
| Auger | two turns, helical flights | the single output, visibly | yes |
| Dust puff at the maw | on each bite | the shredding is dirty work | **no** |

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

| file | what it does |
|---|---|
| `quality_recycler_gen.py` | the model, the materials, the animation rig and the direction transform. Idempotent, rebuilt from source every run |
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
| `-<D>-anim.png` | 64 | rotor, gear, rollers, auger, fragments |
| `-<D>-shadow.png` | 1 | `draw_as_shadow = true` |
| `-<D>-light.png` | 64 | `draw_as_glow = true`, `blend_mode = "additive"`, half resolution at `scale = 1.0` |

The anim layer renders with the body present as a **holdout**, not hidden: the
anim sheet composites *above* the base in game, so a moving part that ought to
be behind the hull would otherwise be drawn straight over it. A holdout punches
alpha-0 where the hull is nearer the camera, which is the occlusion the
composite cannot work out for itself.

`sheet_numbers.txt` beside them carries every width/height/shift; the sprite
sidecars are prototype work and are not written yet.

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
Measured on the packed sheets, **all eight directions**, 2026-09-10:

| | measured | vanilla reference |
|---|---|---|
| Overhang, worst of eight | **0.77 tiles** | chemical plant 0.77, recycler 0.69 |
| Overhang, N / E / S / W | 0.77 / 0.73 / 0.77 / 0.73 | chem 0.77 / 0.61 / 0.38 / 0.30 |
| Full-width rows | 0% in all eight | 0% across every shipped machine sprite |
| Fill | 0.83 - 0.87 | chem 0.78 - 0.82, recycler 0.72 - 0.84 |
| Ragged | 0.98 - 1.30 | chem 0.98 - 1.24, recycler 1.03 - 1.16 |
| Luminance sd | 49.9 - 53.4 | `gates.contrast` band 43-56 |
| Form / grain ratio | 0.57 | recycler 0.61, chem 1.08 |
| Luminance mean / saturation | 60.2 / 0.28 | recycler 67.0 / 0.31 |
| Distinct kinds of detail | 186 over 241 objects | audited vanilla band 8-15 kinds |
| Objects drawing zero pixels | 16 of 241, all of them legitimate | was 60 of 213 before the object-ID pass was runnable |
| Edge-wear mask | 2.9% bright | `gates.wear_mask` flood threshold |
| Luminance mean (look frame) | 65 | chemical plant 63, recycler 67 |
| Saturation (look frame) | 0.47 | chemical plant 0.47, recycler 0.31 |
| Clipped pixels | 0.00% | gate allows 0.05% |
| Shadow | 100% pure black, 12-17% soft edge | gate allows 8% soft |

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
