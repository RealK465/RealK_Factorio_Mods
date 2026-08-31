# Design language — what to model before how to render it

Read this **before opening Blender**, whenever an entity or icon subject is being
designed — and come back to it when a render "follows all the rules" yet still
reads simple, clean, toy-like or generically sci-fi. Camera, lighting and
materials (SKILL.md, `materials.md`) cannot rescue a design that is a box with
a flat colour; this file is about the design itself.

Sources, in confidence order: Wube's own Factorio Friday Facts (cited as
FFF-nnn — these are the artists explaining their actual decisions), and a
direct visual audit (2026-08-05) of the shipped 2.1 sprites in `data/base` and
`data/space-age` plus Krastorio 2 / Space Exploration for contrast. This is
design intent from the source, not folklore.

Contents: the design plan · the story method · silhouette · greeble vocabulary
· materials & colour · wear · detail distribution · state & animation · 2.0
evolution · why sprites read amateur · case studies · reference material.

## The design plan — the required first artifact

A sprite begins as a short written plan, not as geometry. It lives in the mod's
`.ai-support/<subject>-design.md` — the subject-design genre in the repo
`CLAUDE.md` → *AI support folders*, listed in that folder's `index.md` — and
the `factorio-entity-design` skill is the process that produces it. Every
section below appears in it; a section that is genuinely empty says why.

1. **Function & hero** — what the machine does, and the single working part
   that does it. That part gets the visual budget and is modelled first, at
   exaggerated size; the housing is built around it. Wube centres the mining
   drill on its bit "the part that does the action" (FFF-350) and the fusion
   generator on its rotor/stator (FFF-420).
2. **Family** — which vanilla entity anchors it, and what it quotes. Vanilla
   designs in families: the crash-site lab keeps the lab's dome (FFF-301),
   elevated rails are red because trains are red (FFF-378). For a
   tier-above-vanilla entity, quote the vanilla proportions and escalate.
3. **Silhouette** — describe it at thumbnail size: what breaks the outline, on
   which sides; where the tall element is; what the front elevation shows.
4. **Component list** — every part to be modelled, each with its purpose.
   A part with no purpose is cut; a purpose with no part is a gap.
5. **Material zones** — 4–6 zones, named with colours (see below).
6. **Wear map** — where chips, rust, soot, oil and dust go, and why.
7. **Busy/calm map** — the one dense hero zone; the calm hulls.
8. **State & animation** — what moves when working, what glows, how idle
   differs, and how direction reads at a glance if the entity rotates.

The plan is cheap and the model is not: Wube itself goes line art → concept
(inactive *and* active states) → 3D → paint-over (FFF-146, FFF-432), precisely
so nobody models detail the camera never sees.

## The story method — four flows plus a hero

A vanilla machine is legible industrial equipment: a viewer can reconstruct
what it does. When a design feels arbitrary or "unnatural", it is usually
because these questions have no visible answer. Make all four flows visible:

- **Power in** — cables with natural sag, insulators, a transformer box, coils.
  Vanilla even standardises one circuit-connector greeble reused on every
  connectible entity (FFF-210).
- **Material through** — pipes with bolted flanges, hoppers, chutes, bay
  doors, an output where the product visibly leaves. Route pipes to the
  *actual* prototype connection points; for Wube the fusion plant's whole
  layout was driven by them (FFF-420).
- **Heat out** — fans, louvres, finned radiators, a chimney — with soot where
  the heat exits.
- **Human service** — a hatch, handwheel valve, ladder, railing, placard,
  stencilled number. This is what makes it equipment rather than a prop.

Two boundaries keep the story honest:

- **Every detail is a gameplay message — don't lie.** Wube deleted cables
  *between* beacons because they implied beacons network with each other
  (FFF-339). A detail that implies a mechanic the entity doesn't have gets cut.
- **Big machines are assemblies, not scaled-up shapes.** A 5×5 is composed of
  distinct plausible sub-machines (tank + reactor + control cabin), each with
  its own story, connected by visible plumbing (FFF-420, FFF-442).

## Silhouette — decided before any detail

"Things need to be recognizable from far away" (FFF-350): the sprite is
~64–200 px in play, and the silhouette does more identification work than
every greeble combined.

- **Never ship the bounding box**, and this one has a hard number:
  **no horizontal scanline may cross the sprite from edge to edge.** Measured
  across every machine sprite in 2.1 and Space Age — beacon, radar, roboport,
  nuclear reactor, foundry, biolab, electromagnetic plant — **not one has a
  single full-width row**. It is not an archetype thing; the flat-topped
  platforms obey it exactly as the towers do. Break the outline on at least
  two sides: at least one tall element (mast, chimney, dish, tower, tank) and
  at least one low one (pipe stub, skid foot, hopper) past the footprint.
  Model to the collision box, then let soft details breach the tile modestly —
  vanilla balances "overlapping the tile to be aesthetically nicer" against
  readability (FFF-146).

  Two companion numbers off the same sprites: **fill** (silhouette area over
  bounding-box area) runs 0.58–0.88, and **ragged** (alpha perimeter over
  bounding-box perimeter) runs 1.14–2.19. `gates.silhouette` measures all
  three. This repo's beacon shipped at fill 0.94, ragged 0.46 and **88%
  full-width rows** — a published release, past seven other gates, because
  every one of them reads colour or contrast and none of them read shape.

  **The geometry that fixes it is not obvious, so here it is.** Screen row is
  set by `y + z`, so a wall at constant x occupies every row from its minimum
  `y + z` to its maximum. A row is full width only when the west extreme and
  the east extreme both land in it. So give those two extremes to parts whose
  y ranges are **disjoint by more than the deck is thick** — widest to the east
  at the front, widest to the west at the back — and the entire failure class
  disappears. A square deck plate is the usual culprit: at this rig it projects
  to a filled square and sets the whole outline by itself. Four symmetric
  corner posts re-create the fault on their own, whatever the hull does.
- **Vary the roofline.** Vanilla tops are jagged with mechanism (the
  assembler's whole top deck is exposed machinery), not flat lids.
- **Prefer asymmetry.** No face repeats another; attachments sit off-centre
  and on corners. "Heavy and industrial, but not quite perfectly stable and
  rigid" (FFF-378) — massive yet slightly improvised. CAD-clean symmetry is
  the enemy.
- **Consider open-frame construction** — radar's truss legs, the substation
  lattice, the big drill's portal gantry. Negative space inside the silhouette
  is a vanilla signature no solid box has. Utility entities that tile in rows
  (poles, beacons) *should* be visually transparent so they don't wall off
  the factory behind them (FFF-195, FFF-378).
- **Show a front elevation.** The audited tell that most reliably outs K2 and
  SE next to vanilla is a near-plan-view render — all roof, no south face.
  Vanilla's ~45° camera shows a substantial wall on the south side.
- **Anchor it to the ground.** Concrete pad, feet, a skirt of dirt/AO — the
  ramp got a concrete base specifically to "show where it touches the ground"
  (FFF-378), and the beacon digs a hole in its collision box to read taller
  (FFF-339). Then test the sprite *in context*: tiled in a row, in a block,
  next to vanilla neighbours — never only as a lone render.

## Greeble vocabulary

Aim for **8–15 distinct kinds** of functional detail on a production machine
(audited range across vanilla), fewer on a utility entity — poles and beacons
get less, not more. Draw from the audited vanilla set:

Most of the table below is already built: `greeble.py` has the builders and
`parts.py` places them in one line each, alongside CC0 industrial models — see
`pipeline.md`. Naming a part that exists is the difference between this band
being a target and being an afternoon per row, and `Assembly.report()` counts
the distinct kinds actually placed against it.

| Greeble | Vanilla usage notes |
|---|---|
| Pipes with flanged joints | Every joint gets a bolted flange; bends have purpose (elbow, union, valve at the junction). No straight featureless cylinders |
| Rubber cables, 2–4 | Red/blue/green/orange, sagging naturally — vanilla's cheapest "alive" detail (beacon, roboport, substation) |
| Circuit connector / junction box | One standardised module, reused (FFF-210) |
| Coils & windings | Copper, hand-wound look (beacon, EM plant) |
| Gears, chains, pistons, flywheels | Exposed in a working bay — vanilla machines are their own cutaway (assembler-2's whole deck) |
| Fans, louvres, finned radiators | The heat story; soot nearby |
| Tanks & drums | Riveted bands, bolt-circle lids, gauge pods |
| Valves with red handwheels | At pipe junctions (chemical plant: 3) |
| Rivet/bolt rows, panel seams | Along every panel edge — panels read as *assembled* plates, not one surface |
| Hazard chevrons | Small strips on moving/dangerous edges, never the base colour |
| Stencils, placards, decals | Numbers and warning signs — crash-site tanks "always have a number" (FFF-301) |
| Ladders, railings, catwalks | On large buildings; the human-scale cue |
| Status LEDs, small screens | 1–2 pinpricks; belongs to the working-state story |
| Concrete pad / skid feet | The ground anchor |

Rules of use:

- **Modular repetition reads as engineered; one-offs read as noise.** The same
  bolt, vent or connector repeated at plausible intervals beats five unique
  gadgets.
- **Anything under ~2–3 px at gameplay zoom is texture, not geometry**
  (FFF-350's "small pixel area" constraint). Rivets on a 3×3 machine are
  texture/normal detail; a fan housing is geometry.
- Detail concentrates at the hero part and at connection points (flanges,
  power attach, output); large hulls stay geometrically calm and carry
  interest through texture — seams, paint wear, grime gradients.

### Fluid connection stubs — measured off base 2.1.14

A machine with fluid boxes draws its own pipe stubs in the body sprite; the
engine adds nothing when a pipe connects. Every number below is measured off
vanilla's own shipped sprites (2026-08-19), because a first attempt that
styled them small could not visually meet a base pipe:

- **The vanilla pipe barrel is 0.52 tiles of lit metal** (33 src px at
  64 px/tile), 0.64 with its dark shading; the sprite's opaque box is a full
  1.00 tile. A physically modelled side barrel of r ≈ 0.19 tiles projects the
  matching band at the 45° rig (band = 2√2·r).
- **A machine's drawn stub is 0.64–0.70 tiles wide** (chemical plant south
  stubs 0.69–0.70, centred within 1 game px of the connection tile's centre
  line; boiler side stubs ≈ 0.62). Machine stubs are *fatter* than the pipe.
- **Flanges sit LOW and oversized**: the boiler's side flange nearly touches
  the ground at the tile edge, spanning most of the hull height, and the pipe
  run tucks under it. A stub at deck height with a small flange reads
  disconnected however correct its x/y is.
- **End every stub in a bolted flange with a dark open bore**, slightly proud
  of the tile edge (boiler: ~0.08 tiles). The open bore is what makes a
  connecting pipe read as joined; `pipecoverspictures()` caps it when nothing
  is connected.
- **The engine draws pipe covers on a 128 px canvas centred on the OUTSIDE
  tile**, plate hugging the machine edge: side plates 13×51 px (0.20×0.80
  tiles) centred 2 px above the tile-centre row, frontal plates 51×44. Declare
  `pipe_covers = pipecoverspictures()` on every fluid box — chemical plant,
  boiler, refinery and electric mining drill all do; `pipe_picture` is only
  for machines whose stubs come and go with the recipe (assembling machines).
- **Judge the joint by compositing** the uncropped frame with real
  `pipe-straight-*.png` sprites at their tile positions — the only check that
  catches a diameter or height mismatch before the game does.

## Materials & colour — zones, not a colour

Minimum **4 material zones**, typically 5–6 (audited across every vanilla
entity):

1. **One desaturated painted identity colour** — worn blue (assembler), olive
   (radar), green-grey (furnace), mustard (chem plant), oxide red (foundry).
   Confined to housing/skirt panels; never covering the mechanism.
2. **Bare / galvanized steel** — ducts, frames.
3. **Dark iron / gunmetal** — mechanism, cavities, mouths.
4. **One warm metal** — copper or brass (coils, trim, fittings).
5. **Rubber/hose black** — cables, hoses.
6. Optional: white ceramic, glass, small emissive.

Colour discipline, from FFF-320 ("terrain is a background… comfortable
contrast with the entities") and the audit:

- Large areas low-saturation; saturation is spent in small accents — valves,
  wires, LEDs.
- **One semantic accent colour per entity**, chosen to mean something: red =
  train family (FFF-378), pale turquoise = cryogenic cold (FFF-432). If the
  identity colour itself is saturated (pumpjack green), compensate with heavy
  wear and a rusty substructure.
- Warm-vs-cool pairing is a vanilla habit: brass frame / blue glow (lab),
  rust lattice / navy body (substation), copper / steel (beacon).
- Emissives: 1–2 small points, or the machine's actual process (furnace
  mouth, lab dome) glowing from *inside* geometry. Large surface glow is a
  Space Age animated-layer device over a dark shell, not a painted-on face.

## Wear — mandatory, placed by physics

"Factorio buildings tend to be weathered" is the single most-cited difference
between vanilla and mod art (Wube forum t=89250); the machines are lore-dirty,
DIY copies of crashed-ship tech. But wear is a **map of use, not a noise
overlay** (Deadlock989, same thread):

- Edges, corners and anything that sticks out: **chipped to bare metal and
  cleaner** — dirt gets worn off exactly where paint does.
- Crevices, panel joins, skirts: **grime pools**. Dirt gradient darkens
  toward the ground.
- Heat exits: soot. Mechanisms: oil streaks *below* them. Feet, flanges, weld
  seams, anywhere water sits: rust.
- No surface at 100% clean paint; no uniform wear either.

Implementation (pointiness edge wear, AO rust, grime streaks) is the
validated stack in `materials.md` — this file decides *where* wear belongs so
those masks are tuned per design, not left at defaults.

## The detail budget — making the band countable

"8–15 distinct kinds" is only a target if something counts. `Assembly.report()`
does: it returns the objects placed and the **distinct kinds** among them, and
the generator template's `audit()` prints both and says so when the count is
short. Run it before rendering, not after.

Three rules for spending the budget, all of them learned by getting them wrong
on this repo's own art:

- **Spend on missing flows, not on more of what is there.** A count short of 8
  is almost never fixed by adding bolts. Ask which of power in / material
  through / heat out / human service has no visible answer — human service is
  the one that is missing most often, and it is the one that makes a model read
  as equipment rather than a prop.
- **More parts is not more detail past the legibility floor.** At 64 px/tile a
  feature under ~3 px at gameplay zoom is a smudge; `greeble.legibility()` says
  which side of that line a size falls on, and `scatter()` warns when its own
  parts are below it. Detail spent there costs render time and shows nothing.
- **Density has a ceiling set by the deck, not by ambition.** The beacon asks
  for 20 tertiary greebles and fits about 10; raising the attempt budget
  fivefold changed nothing, because minimum spacing plus obstacles plus its
  walkway annulus leave room for ten. `scatter()` reports the shortfall with a
  rejection tally — read it, because the fix is a design change (tighter
  spacing, a narrower keep-out, another region) and never a bigger budget.

**And count against the right thing.** This repo's beacon measures *denser*
than vanilla's — more parts, more saturation, more contrast — and still read as
"too simple" to its author, because what differs is shape language, not
quantity. Vanilla's beacon is low, open and irregular; this one is a closed
symmetric façade. Put your sprite next to its vanilla counterpart at 1× on
Nauvis dirt before deciding you need more parts; the answer is often fewer,
arranged differently.

## Detail distribution — busy against calm

One deliberately dense hero zone (usually the exposed mechanism deck) against
calm zones that carry only seams, rivets and wear. The audit's contrast pair:
vanilla keeps this discipline everywhere; SE's pulveriser spreads detail
evenly and turns to noise at game zoom, K2's plants leave the silhouette a
full flat tile. Uniform density reads as noise; uniform emptiness reads as
toy.

## State, direction, animation

- Working motion looks **effortful and mechanical** — the drill's weak radial
  sweep was replaced because it read as "gently harvesting" (FFF-350).
- Idle/status glow is small and local; the beacon's screen-filling beam was
  cut for "call[ing] too much attention" and replaced with subtle interior
  blinking (FFF-339).
- A rotatable entity must show its direction at a glance (FFF-420): the
  business face is asymmetric — intake, chute, lamp.
- Plan the active state in the design doc; Wube concepts inactive and active
  side by side (FFF-432).

## The 2.0 / Space Age evolution — same grammar, new emphasis

The audit of `data/space-age` confirms the vocabulary is unchanged (rivets,
flanges, worn paint, cables) with three shifts worth copying for new art:

- **More vertical and stepped** — foundry and big drill build in tiers rather
  than one mass with attachments.
- **Emissive as protagonist** — the static base is kept dark and desaturated
  so animated light layers (melt glow, rotor arc) carry the identity.
- **Confident negative space** — the EM plant's empty bore, the drill's open
  portal; the centre of the sprite is left to animation or ground.

## Why homemade sprites read "simple and unnatural"

The audited tells, each traceable to a violated rule above — use as a review
list when a render feels off:

1. Showroom-clean surfaces, no weathering (the #1 community-cited tell).
2. Uniform procedural noise/roughness everywhere instead of physically-placed
   wear.
3. Bounding-box silhouette: the model fills its tile edge-to-edge, flat
   "tray" base with parts arranged on top (K2's tell).
4. Near-plan-view presentation, no front elevation (K2 and SE's tell).
5. Large saturated colour fields without compensating wear (K2 purple, SE
   orange); glossy chrome and clean-PBR plastic.
6. Detail spread evenly — noise at zoom — or absent — toy at zoom.
7. Even proportions, symmetric massing, "cute / toy-like / miniature diorama"
   reads.
8. Parts with no visible function; no power, material, heat or human story.
9. A raw render shipped with no post pass: vanilla hand-paints contrast, edge
   definition and grime over nearly every render (FFF-146, still true for
   Space Age per FFF-432). In this pipeline that's the Pillow/compositor
   post step — budget for it.

## Case studies (from the shipped-sprite audit)

- **Beacon** (utility, tiles in rows): low square housing + tall segmented
  mast; 6 copper coils, 8 sagging red cables, bolted corner plates, riveted
  rim; copper/steel/red palette; interior busy, frame calm. Open enough to
  see through; digs into the ground for height without occluding.
- **Chemical plant** (fluid machine): outline broken on all four sides —
  chimney, pipe elbows, tank cluster, squat drum; ~12 flanged pipe segments,
  3 red handwheel valves; mustard/grey/dark-green + red accents; rust at
  every flange, streaks down tanks.
- **Assembling machine 2** (the archetype): chamfered box whose *entire top*
  is an exposed working bay — gears, chain drive, flywheel, piston; blue
  identity paint confined to the skirt, chipped along every panel edge; busy
  deck / calm skirt.
- **Radar** (open frame): dish + truss legs + piston + guy wires — no "face"
  at all; olive paint mottled over every plate; the most broken silhouette in
  the game.
- **Foundry** (Space Age tiering): crucible tower → calm shaft → mechanical
  skirt; riveted bands, ladle arm, ring gear; oxide-red + verdigris +
  soot; process readable top to bottom (charge → melt → pour → cast).

## The legibility floor

A detail's size in *source pixels* decides what kind of detail it is allowed to
be. At 64 px/tile a strip of 0.55 × 0.16 tiles is 35 × 10 px, and half that at
gameplay scale. Measured on the beacon's front lip, three passes running:

- A flat plate carrying a texture pattern reads as a smudge. Etched line-work,
  fine grain and hairline traces all vanish; the plate becomes a grey blob and
  looks like an unfinished blockout.
- What survives is **silhouette and value** — a raised plate with a lit top
  chamfer and a shadow line beneath, a bezel, a bolt head, a bright dot.
- Text is finished below roughly 10 px of cap height. Use a bold shape
  (chevrons, a triangle, an arrow) when a mark has to read at that size, and
  keep lettering for icons and technology art where there is room for it.

The same measurement settles recessed versus raised. On a front wall that the
rig lights with fill only, a recess reads as a dark opening however carefully
it is framed, because no key light reaches into it; a plate standing proud of
the surface catches the key on its top chamfer and reads as a panel. Recess
things the camera looks *down* into, raise things it looks *at*.

## Reference material

- **Vanilla PNGs** — the ground truth: `data/base/graphics/entity/…` and
  `data/space-age/graphics/entity/…` under the game install. Open them next
  to every design and every render.
- **Hurricane046's "Factorio Buildings"** — the community gold standard for
  vanilla-matching art; the Figma board is browser-only, but the same renders
  ship as the MIT-licensed `hurricane-graphics` mod on the portal
  (https://mods.factorio.com/mod/hurricane-graphics) — downloadable as
  side-by-side calibration reference. Reference only: study, don't copy into
  a mod, and keep downloads in `exemples/` or the scratchpad, never
  committed.
- **FFF posts worth rereading whole** when designing something similar:
  FFF-339 (beacon), FFF-350 (mining drill), FFF-378 (elevated rails),
  FFF-420 (fusion), FFF-432 (Aquilo, post-production), FFF-146 (the GFX
  pipeline).
