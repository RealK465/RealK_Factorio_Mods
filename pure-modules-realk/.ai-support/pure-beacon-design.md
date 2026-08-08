# Pure beacon — design notes

Consolidated 2026-08-06 from four dated iteration docs (design spec, implementation plan,
Aquilo art revision, remnants design) into one living reference, cross-checked against the
shipped prototypes rather than carried over verbatim — several placeholder numbers in the
originals (a 2 MW placeholder energy cost, `allowed_module_categories = {"pure-speed"}`,
draft rig constants later recalibrated) were superseded by the balance pass and are not
repeated here. This file covers *why the beacon looks, animates and dies the way it does* —
the visual and lore record. For balance numbers, settings, and open engineering questions,
see the mod's own `CLAUDE.md`.

## Lore anchor

The beacon is unlocked on Aquilo, so it is built out of what Aquilo is made of: extreme
cold, fusion power, fluoroketone coolant, quantum processors. Every material and story
choice below resolves against that anchor.

- The crystal is **not** a magic gem — it is a stabilised quantum-plasma core.
- The two rings are **not** decoration — they are magnetic containment coils,
  tokamak-style, holding the core off the pedestal.
- The arcs are **not** lightning — they are contained plasma discharge running from the
  electrode tips into the confinement volume.
- The hull is frozen; the core is not. Hot-core-against-frozen-hull is the whole palette,
  and it is what keeps an ice-cyan machine from reading monochrome.

## Function, hero & family

Transmits module effects over `supply_area_distance = 10` (25×25 tiles). The hero is the
containment assembly — core plus the two counter-rotating rings — and it keeps the entire
emissive budget. Everything else on the platform is support plant explaining how the core
is fed and kept cold.

Family: vanilla beacon (copper windings, sagging cables, riveted rim, tall mast) escalated
to Space Age Aquilo tier — cryogenic-plant pale turquoise, fusion-plant copper and
gunmetal, quantum-processor blue. Reads as the same manufacturer as the cryogenic plant
standing next to it, which is also the beacon's stated size family (both 5×5) for the
remnants and dying explosion below.

## Silhouette

Low riveted 5×5 plinth, four curved electrode pylons breaking the outline at the corners,
core floating above the centre, machinery amphitheater tall at the back and low at the
front so the core stays readable. Total sprite height ~4.5 tiles, overhanging upward like
vanilla tall entities. Beacons tile in rows, so the frame stays visually open (FFF-195,
FFF-378) — the platform gets denser, the gaps between pylons do not.

## Look

**Crystal:** ice-cyan faceted quantum-plasma core, ~1 tile tall, bright core, semi-translucent
facets, floating ~2 tiles above the base centre. 6-fold facet symmetry (for loopable yaw).

**Rings:** two gunmetal magnetic-containment rings with glowing cyan seams. Outer
near-horizontal, ~3 tiles across, 4-fold symmetric detail. Inner smaller, tilted, 3-fold
symmetric detail.

## Component list — the four flows

| Flow | Parts |
|---|---|
| Power in | Copper induction helix around the foot of each pylon; a second finer winding under each glowing tip; sagging rubber cable from the deck up every pylon; manifolds with valve wheels |
| Material through | Fluoroketone canisters (hot orange / cold blue split), coolant hoses from the canister skid to the containment chamber, copper pipe runs with bolted flanges, ribbed hoses down from the chamber into the body |
| Heat out | Radiator fins at the front-left glowing warm — the only warm light on the platform — with rime deliberately absent around them; frost accumulating everywhere the fins are not |
| Human service | Bolted hatch, two analog dials, valve handwheels, hazard kick plates, a grated walk panel, rivet rows |

Cut for lying about mechanics (FFF-339): nothing that implies beacons network with each
other. Cables run *within* the entity only — the same rule the remnants below follow.

## Materials & wear

1. Frost-teal painted steel — identity, housing and skirt only.
2. Holmium plate — cooler silver-blue, slightly more reflective; accent panels only.
3. Gunmetal / dark cast iron — mechanism, flanges, cavities.
4. Copper — windings and pipe runs, part-patinated.
5. Matte black rubber — hoses and cables, sheen only at grazing angles.
6. Rime — pale blue-white, matte, layered *over* zones 1–4 by mask, never a zone of its own.

Emissives, all small: plasma blue (core, ring seams, arcs, pylon tips), status LEDs in
green/amber/cyan, warm orange in the radiator gap and the hot half of a canister.

Wear map: edges and corners chipped to bare metal; rust at feet, tank straps, flanges, and
anywhere two parts bolt together; grime pooled in deck seams, darkening toward the skirt;
**frost on upward-facing surfaces and convex edges**, heaviest at the back and left (away
from the radiator), absent near the fins and near the core — frost is the Aquilo
equivalent of dust, a map of temperature rather than a noise overlay.

Busy zone: the containment assembly and the amphitheater arc behind it. Calm zone: the
plinth's front face and side skirts, carrying only seams, rivets, grime and frost — kept
low so the busy zone is never occluded.

Trade-offs, deliberately accepted: frost is capped well below "snowed on" — at 64 px/tile
a heavy rime mask turns the hull into a white blob and destroys the value contrast vanilla
depends on. The core is emissive but bounded — Standard view transform clips hard, so the
saturated blue stays near strength 1.0 and only the near-white core centre is allowed to
blow out; brightness comes from contrast against a dark hull, not a bigger number. Photo
texture (Poly Haven `metal_plate`, `snow_02`) is multiplied in at low factor for grain
only — the tint stays procedural so it can stay matched to the measured vanilla chassis
value.

## State & animation

Idle: rings frozen, arcs absent, LEDs and canisters still lit (a beacon with no modules is
powered, not dead). Working: rings counter-rotate (outer +90°, inner −120° per loop), core
bobs ±3 px, ring seams carry a scrolling sheen, and the discharge runs its beat — charge
climbs an electrode from its induction coil, the tip flashes, the arc fires into the core.
64-frame perfect loop, `draw_animation_when_idle = false` — see the mod's `CLAUDE.md` for
the open question over what that flag actually does on this entity.

| Element | Per loop | Why it loops |
|---|---|---|
| Outer ring | +90° | 4-fold symmetry |
| Inner ring | −120° | 3-fold symmetry |
| Crystal bob | 1 sine cycle, ±3 px (source px) | integer cycle count |
| Crystal yaw | +60° | 6-fold facet symmetry |
| Climb | 12 pylon-beats, 6 frames each, coil → tip | schedule authored per frame |
| Arcs | the same 12 beats, 7 frames each, tip → crystal | schedule authored per frame |
| Sparks | shed at each tip flash and along each arc | ages wrap modulo the loop |
| Motes | 5 adrift in the containment volume | integer turn and bob counts |

The beat order is diagonal, other diagonal, a wave round all four, then all four at once —
`ARC_BEATS` in the generator. Six frames of the loop carry neither a climb nor an arc, which
is the machine breathing rather than strobing. The climbing bolt is held on the
camera-facing side of its pylon on purpose: the arcs layer renders with the base collection
hidden, so a bolt routed round the back has nothing to occlude it and would composite
straight through the electrode.

Layer flags, shift and scale numbers are the render pipeline's own measured output, not
restated here — see `prototypes/beacon/graphics.lua`. The arcs sheet no longer shares the
rings' crop box; the discharge reaches the foot of each pylon and carries its own.

## Deck plant

Added after the animation passes above, so it is absent from the tables there. The platform
floor carries four small devices and the cabling that feeds them, all of it support plant for
the core rather than anything that competes with it.

- **Holographic readout** — a projection standing off an emitter bar between two lit rails.
  The glyphs are a brick texture used as an *alpha* mask, so the plane is mostly transparent
  and only the strokes emit; a flat emissive plate was tried first and read exactly like the
  pastel sticker the graphics skill warns about.
- **Cryogenic vent** — a rimed ribbed stack with a dark mouth, breathing vapour. Aquilo said
  out loud, and the deck's only moving fluid.
- **Sensor array** — a dish turned to face the camera (dark inside, lit rim) plus two unequal
  whips. Deliberately small: the left walkway slot is about 0.3 tiles wide.
- **Floor shard** — a chip of the core's own mineral through a cracked, rimed collar. Its glow
  is a third of the core's; the tell that it is the same substance is the colour, not the
  brightness.

**Placement was measured, not designed.** A first pass placed all four off the deck occupancy
map and three came out occluded — the walkway flanks look open in plan and are criss-crossed by
the chamber hoses overhead, and the whole rear deck sits behind the amphitheater. What settled
it was a ray-cast visibility map (cast every candidate point toward the camera and see what is
in the way) plus a full AABB dump of both front quadrants. The pockets they sit in are named in
the generator's comments.

**The cables are short, and that is a constraint rather than a choice.** The clear floor is a
band roughly 0.25 tiles wide between the pedestal at r=1.12 and a continuous ring of plant —
rim pipe, both manifolds, the coolant skid, the capacitor bank, the bus bar, the flank tanks.
Routing to a corner drum was attempted with a search over start angle and one waypoint; the
best line on every corner still crossed 28-40 of 40 sample points through the radiator, the
manifolds or the tanks. So each device takes a short service run off the chamber instead, and
the electrodes keep the cable they already have up from their own drum. The hologram is fed
from the bus bar's end lug, which is what a power rail is for.

**Animation** is a fourth sheet, `beacon-deck.png`, 64 frames at animation_speed 0.5 like the
others and `always_draw` like the rings. The glyphs hold still and a scan band sweeps and wraps
(scrolling them would not loop — the brick pattern is random per row, so after N rows of travel
the image is not the one it started on); vapour puffs rise, spread and thin on staggered
phases; and a charge runs out the cryo and holo cables timed to arrive as their electrode
starts to climb, off the same `ARC_BEATS` schedule. Only those two cables pulse: the deck layer
renders with the base hidden, so a bead has nothing to hide behind, and both of those runs are
on open walkway.

A latent bug surfaced doing this and is worth recording: the four rim beams used to cross at
full length, putting two **coincident outer faces** at every corner. `worn_metal`'s ambient
occlusion term reads a face's own coplanar twin as total occlusion and renders a hard-edged
black rectangle there — and which face wins depends on BVH order, so it appeared and vanished
as unrelated geometry was added elsewhere on the deck. The audit never reported it because
`("Rim", "Rim")` is whitelisted. The side beams now butt into the front and back pair.

## Aquilo frost overlay

Added after the four original design passes, so it isn't in any of them by name — folded
in here since it's now part of the shipped look. A static overlay drawn on top of the
sprite while the beacon is frozen (gated on `feature_flags["freezing"]`, not
`mods["space-age"]`), covering the rings and crystal at their frame-0 pose —
`reset_animation_when_frozen` pins the animation there so the ice lands on the rings
instead of beside them, the same trick vanilla's centrifuge uses for its drums. Numbers
are the measured output of `make_frozen.py`, which gates the result against every vanilla
frozen patch on colour bands, coverage against the machine's own area, and alpha spread —
the alpha spread is what catches a patch that's technically the right colour and still
reads as a film. Current values live in `prototypes/beacon/graphics.lua`.

## Render pipeline

Sources in `assets/pure-modules-realk/entity/beacon/` (tracked, never shipped) — regen commands
are in the mod's own `CLAUDE.md`. The entity and remnant renders share one rig verbatim so
both stay pixel-aligned: 64 px/tile ortho camera, `pixel_aspect_x = √2` to square the
ground plane under the 45° camera angle, sun upper-left (shadows fall right), View
Transform **Standard**, film transparent, Cycles with a shadow-catcher pass for the shadow
layer. The footprint test plane must render exactly 320×320 px for the 5×5 entity — the
gate that blocks everything else until it passes. Judged side-by-side against real vanilla
PNGs at every stage — that comparison is the ground truth, not any config value.

## Remnants

Two shipped remnant grammars exist in 2.1 and they don't mix: base-game art
(`beacon-remnants`) is a near-plan-view *nest of guts* — hull gone, copper windings and
hoses in a tangle inside a broken rim. Space Age art (`cryogenic-plant-remnants`) instead
comes apart into recognisable panels lying flat and overlapping in a low pile. The Pure
beacon is a 2.0-era Aquilo machine in the cryogenic plant's family, so **the Space Age
grammar governs** — torn-off panels, not a nest. Vanilla's beacon remnant earns one nod:
its hero is a spill of copper coil, kept here as a secondary motif since this beacon has
copper induction helixes to unravel.

Measured off both references, non-negotiable:

1. Pieces lie **flat**, spread ~1.2–1.3× the footprint.
2. Identity paint **survives in patches** under heavy rust — the machine stays recognisable.
3. Shells read **hollow** — concave interiors visible and dark. Mean luminance 63–67 over
   opaque pixels (measured: `cryogenic-plant-remnants` 67.1, `nuclear-reactor-remnants`
   65.8, `beacon-remnants` 62.9) — a wreck is unlit and belongs well below the machine it
   came from.
4. A **dark scorch fringe**, fuzzy and speckled, extending past the pieces (measured over
   the semi-transparent band: cryo (20,16,11), reactor (3,3,2), beacon (14,12,10)) —
   emphatically not pale ash; always composite on ground colour before judging, since the
   dark edge reads as grey haze on a white background.
5. A few **small fragments flung clear** of the main pile.
6. **Zero emissives** — the cryo plant's bright windows are dark holes in its wreck.
7. The ground shadow is **baked into the colour sprite**; no vanilla remnant uses
   `draw_as_shadow`.

**Story:** containment failed. The plasma the core held vents rather than lying about on
the ground — with no field on it, there's nothing left to see. The mineral shell that held
it did not vent: it shattered, and the pieces sit in the crater it made. Everything else
fell *outward* from that point. The crystal was originally specified as vented entirely,
leaving only a hollow; RealK asked for it to be present instead, which is the better call —
vanilla remnants keep one recognisable piece so a player can tell what died there, and the
core is the most recognisable thing this beacon has. Drawn as one near-whole half of the
bipyramid plus a spray of splinters, with **no emission at all** — the tell that it's dead
is that its facets are lit from the upper left like every other surface in the sprite.

**Hero and read:** the rings carry the read — "the containment came down." Outer ring bent
into a flattened oval, lying across the broken deck at a slight tilt, one side propped on
the buckled rim, pods still attached, one torn off — the biggest, clearest shape in the
sprite. Inner ring snapped into two arcs, one curved-side-up front-left, the other
half-buried in deck wreckage back-right. Secondary recognisables, in order of how much they
matter: the four curved electrode pylons (two snapped to stubs, one fallen across the
plinth, one flung clear, tip dead), the unravelled copper helixes, the coolant canisters,
the radiator fin stack, torn teal hull panels.

**Burn and frost map**, three concentric bands from the blast centre:

| Band | Paint | Rust | Frost | Soot |
|---|---|---|---|---|
| Centre (the hollow, ~1 tile) | burned off, bare/blued metal | low | none | heavy |
| Mid (the broken deck) | patchy teal under bloom | heavy | trace | moderate |
| Outer (thrown clear) | teal largely intact | moderate | present on upward faces | light |

Frost surviving only on the pieces thrown furthest out is the Aquilo tell — pale rime
against a soot-black centre is the value contrast a monochrome grey wreck wouldn't have.

**Variations:** two, stacked vertically in one PNG (`graphics/entity/beacon/remnants/
pure-beacon-remnants.png`), selected by `y` offset in `prototypes/beacon/remnants.lua`.
They differ by scatter seed and by the rotation of the flung-clear debris and the fallen
pylon — the plinth and outer ring stay put so both still read as the same machine.

## Dying explosion

`prototypes/beacon/explosion.lua`, sized against the cryogenic plant — same 5×5, and this
beacon's stated family — `big_explosion()` and `large_explosion(0.7, 1.0)`, deliberately a
step below the nuclear reactor's `massive_explosion`: a beacon is a large machine, not a
reactor. Vanilla's five particle emitters are kept and scaled rather than restated: repeat
counts ×2.2, offset deviation ×2.6 (0.50–0.59 tile deviation → 1.29–1.54, landing inside
the 2.2 collision box instead of vanilla's half-tile), speed from centre ×1.35. A sixth
emitter throws 26 crystal shards from a tighter box (the core sat in the middle), thrown
higher and faster than the hull debris because containment let go first — reuses base's
greyscale glass particle (`damaged-assembling-machine-glass-particle-small`) with an
ice-blue tint (`{0.52, 0.76, 0.95, 1}`) multiplied onto `pictures` only, so it needs no new
art and the shadow layer stays untinted.
