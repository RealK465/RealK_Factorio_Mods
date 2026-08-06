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

A sprite begins as a short written plan, not as geometry. Put it in
`assets/<mod-name>/<subject>/design.md` (or the mod's `.ai-support/` if it is
more discussion than spec). Every section below appears in it; a section that
is genuinely empty says why.

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

- **Never ship the bounding box.** Break the outline on at least two sides:
  at least one tall element (mast, chimney, dish, tower, tank) and at least
  one low one (pipe stub, skid foot, hopper) past the footprint. Model to the
  collision box, then let soft details breach the tile modestly — vanilla
  balances "overlapping the tile to be aesthetically nicer" against
  readability (FFF-146).
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
