---
name: factorio-graphics
description: Use when creating, rendering, or exporting any Factorio art — entity sprites, animations, shadows, item and technology icons, thumbnail.png — when setting up, driving or debugging Blender for Factorio work, or when a sprite or render looks too simple, flat, clean, toy-like or otherwise unlike vanilla. Covers the vanilla design language and render conventions needed to make art indistinguishable from vanilla Factorio 2.1, plus the known failure modes of this specific Blender + MCP rig. Read it before opening Blender or authoring a sprite — a wrong camera, scale or colour setting is invisible until the sprite is in game. Conceiving a new entity from scratch is factorio-entity-design's job; this skill builds from the document it produces.
---

# Factorio graphics — vanilla-matching conventions

Goal: art that sits next to base-game entities on the same belt and reads as first-party.

The pipeline order matters: **design (`references/design-language.md`) → model → materials (`references/materials.md`) → render → post (`references/pipeline.md`) → sheets**. Most failed sprites failed at the first step, not the last — but the *post* step is not optional either, and this repo shipped without it for a while. Wube take every sprite into Photoshop and hand-work contrast and edges over it (FFF-146); a raw render reads soft and CG beside vanilla however good the lighting was.

**There is a shared library: `scripts/factorio_render/`** — render rig and device selection, the parts vocabulary and the placement API that makes a machine a parts list, the paint-over pass, alpha-correct resizing and sheet packing, vanilla A/B comparison, and the numeric gates. Use it rather than re-deriving any of it per mod; `references/pipeline.md` is its guide and also covers what a render actually costs, the engine-side polish fields, and the game's own QA flags.

Graphics are produced in Blender via the **Blender MCP**. Inspect the scene before changing it, follow existing naming, never destructively modify objects without asking.

## Confidence — read this first

Two very different tiers of information live in this file. Don't confuse them.

- **Trustworthy:** anything measured from the game's own `data/base` (Factorio 2.1.x) — sprite sizes, px/tile, layer structure, icon dimensions, shadow direction. These are facts read off Wube's shipped assets. The same goes for `references/design-language.md`: it is sourced from Wube's own FFF write-ups and a direct audit of the shipped 2.1 + Space Age sprites, not from taste.
- **NOT trustworthy:** the lighting/material/colour numbers from the 2026-08-04 assembler-4 run. **That output was ugly and did not look like Factorio.** Those values are *escapes from specific failure modes* (pure black, blown white) — they are the boundaries of "not obviously broken", not a validated vanilla look. Treat them as starting points to move away from, not targets.

The full log of that run is kept outside the repo; `CLAUDE.local.md` records its path if it is available on this machine.

**The only real ground truth is vanilla itself.** Before and after every render, put your sprite next to the actual vanilla art and **look at it**. Do this with `vanilla.py`, not by opening two files:

```python
from factorio_render import vanilla
van  = vanilla.vanilla_panel("beacon")
ours = vanilla.compose(my_layers, footprint=(3, 3))
vanilla.contact_sheet([("vanilla", van), ("ours", ours)], zooms=(1, 3)).save(out)
```

It composites both entities' **layers at their prototype shifts and scale**, on the **terrain colour they will sit on**, at game pixels *and* magnified — three things opening two PNGs cannot do, and each of them is a failure this repo has shipped. The comparison that revealed the beacon draws 1.58x / 2.31x its own footprint where vanilla's draws 1.08x / 1.05x took under a second and had never been run. If it doesn't survive that comparison, no config in this file will save it.

### Measure vanilla, don't eyeball it

Colour is the one thing you can settle numerically, and doing so beats judgement every time. Sample the vanilla PNG, convert sRGB to linear, and use that as the material's base colour; then re-sample your own render and compare the same statistic. Matching the lit chassis of a vanilla module this way landed on `(70,140,190)` — byte-identical to Wube's — after several rounds of eyeballing had produced grey.

Two cautions learned the hard way:

- **Pick a statistic that means the same thing on both images.** The most common mid-tone lands on the lit deck for one entity and the shadowed side of another, purely because their poses show different amounts of face. That reported "matching" for an icon that was four times too dark. Bloom haze and near-white speculars will also masquerade as chassis if you average brightness naively. An automated comparator written during this session gave confident wrong numbers three different ways and was deleted; **side-by-side visual comparison is what actually converges.**
- **Confirm a prototype field exists before treating its absence as a default.** `beacon_tint` looks like the game's own answer for module colour, but only speed and efficiency define one — productivity and quality have none. Reading it "from the game" therefore produced invented values: orange for a glow the art draws yellow, purple for one it draws red. A missing field is not a neutral field.

## Design before Blender

The sprites that came out "simple and unnatural" were designed *inside* Blender — primitives arranged until they looked plausible, then lit. Vanilla art is designed on paper first and modelled second; Wube goes line art → concept (inactive and active states) → 3D → paint-over.

**If the entity has no design document yet, stop and run `factorio-entity-design`.** That skill runs the conception session with the user — mod context, vanilla and real-equipment references, the eight stages in order — and writes `<mod>/.ai-support/<subject>-design.md`. This skill builds from that document. Modelling from an improvised brief instead is precisely how the simple-and-unnatural sprites happened.

**Before any geometry, write the design plan defined in `references/design-language.md`** — hero working part, family resemblance to a vanilla entity, silhouette, a component list with a stated purpose per part (power in / material through / heat out / human service), 4–6 material zones, a wear map, a busy/calm map, and the working state. That file is the anatomy of a vanilla entity — greeble vocabulary, colour discipline, the tells that make sprites read amateur — measured off the shipped sprites and Wube's own FFF posts. A design that skips it cannot be rescued by camera, lighting or materials downstream.

## Why the first attempt looked wrong

The assembler-4 model was generated by a Python script from primitives with flat coloured materials. That approach cannot reach vanilla, regardless of lighting:

- **No design.** Silhouette, functional greebles and the machine's story are decided before modelling — see `references/design-language.md`.
- **Sharp 90° primitive edges.** Vanilla catches a bright highlight along every edge — bevel every hard edge. The edge-wear mask in `references/materials.md` also needs the bevel to exist in geometry.
- **Flat single colours.** Panel seams, dirt maps, edge wear, colour variation across a single surface — a uniform Principled BSDF colour is the single biggest tell.
- **No baked ambient occlusion** darkening every crevice and joint.

So when the output looks wrong, **fix design and modelling first, then materials.** Lighting tweaks are the last 10%, not the first. Script-generating geometry is fine for blockout and iteration, but design, detail and texturing have to happen on top of it.

**Don't reinvent the parts.** `greeble.py` builds the vocabulary `references/design-language.md` asks for — flanged pipe runs, sagging cables, louvre banks, finned radiators, bolt circles, rivet rows, handwheels, gauge pods, ladders, railings, skid feet, placards — each already bevelled, non-coplanar and normal-correct. And **`parts.py` places them**, in one line each, alongside CC0 models from Poly Haven:

```python
a = parts.Assembly("PB_", mats)
a.place("greeble:radiator", at=(-0.9, -1.2), size=0.6, mat="iron")
a.place("polyhaven:exterior_aircon_unit", at=(1.0, -0.8), size=1.1, mat="gunmetal")
a.scatter(parts.SCATTERABLE, area=REGIONS, z=0.75, n=20, **a_survey)
```

That is the difference between "8–15 distinct kinds of functional detail" being an afternoon and being a parameter — the beacon costs 4,054 lines because every part was written by hand. `parts.catalogue()` lists what exists; `references/pipeline.md` has the rest, including the import recipe an outside mesh needs before the wear stack will work on it.

Call `greeble.legibility(size)` **before** modelling anything small: under ~3 px in play a feature is texture, not geometry, and modelling it costs render time to show nothing. `scatter()` warns when its own parts fall below that line.

## Starting a new entity's generator

**Copy `assets/generator-template.py`.** It is a runnable skeleton wired to
`parts.py`, with a section per design-plan stage — hero first and oversized,
then housing, then the four flows, then the tertiary scatter — and an `audit()`
that prints the detail budget and the north overhang before you spend a render
on either.

Three numbers it enforces, all of which this repo shipped wrong:

- **distinct kinds ≥ 8** on a production machine (`Assembly.report()`), because
  the band in `design-language.md` is only a target if something counts it.
- **tallest `y + z` under the footprint's half-depth + 0.8**, because that sum
  sets how far the sprite draws past its own tiles. Vanilla 5×5s overhang
  0.52–0.81; the beacon shipped at 2.06 and covered the machine behind it.
- **the east and west extremes on parts whose y ranges do not overlap**, which
  is what stops a scanline crossing the sprite edge to edge. **No vanilla
  entity has a single full-width row**; the beacon shipped with 88% of its rows
  full width, because a square deck plate projects to a filled square at this
  rig and one object then owns the whole outline. `gates.silhouette` is the
  finished check and `design-language.md` → *Silhouette* has the arithmetic;
  the template checks it on the geometry, before a render is paid for.

Writing a generator from scratch instead is how the beacon reached 4,054 lines
for one entity — at which point changing a shape is expensive, and
`references/pipeline.md` is emphatic that iteration count is what the art is
actually made of.

## Where the files live

The `.blend` and every other unshipped source (textures, HDRIs, reference boards, generator scripts) belong in **`assets/<mod-name>/`** at the repo root. Only the exported PNGs and their `.lua` sidecars go into the mod's `graphics/`.

```
assets/pure-modules-realk/
  entity/beacon/       beacon.blend, textures, vanilla refs
  icons/
pure-modules-realk/
  graphics/entity/beacon/beacon-base.png
```

The split is structural, not cosmetic: `fmtk package` zips the mod folder, so a source kept outside it *cannot* be shipped by accident and `package.ignore` never has to be maintained for art. Subdivide `assets/<mod-name>/` by subject once a mod outgrows a couple of files, mirroring the `graphics/` path the renders land in.

`assets/` is tracked in git and pushed — **commit the `.blend` along with the PNGs it produced**, so the render is reproducible instead of a one-off. `.blend1`/`.blend2` autosaves are ignored.

Blender saves to wherever it was last pointed, which is almost never here — pass an **absolute path** under `assets/<mod-name>/` when saving over MCP, and check the result rather than assuming. Same for renders: `render_viewport_to_path` ignores the path you give it (see below), so move the output into place yourself.

## Environment

- **Blender 4.4+** (`CLAUDE.local.md` records the version installed here). Recent enough to matter: since 4.4, actions are *slotted* and `action.fcurves` is **gone**. Use a compatibility helper:
  ```python
  act.fcurves                                 # Blender < 4.4
  strip.channelbag(ad.action_slot).fcurves    # Blender 4.4+  (layers > strips > channelbag)
  ```
- **Rendering does not need the MCP bridge, and shouldn't use it.** Drive Blender headless instead:
  ```
  blender -b -P assets/<mod-name>/<subject>/render_*.py -- <out_dir>
  ```
  Have that script build the scene from the generator rather than opening the `.blend`, so a render is reproducible from source and survives the `.blend` being edited by hand. This is strictly better than the bridge — no GUI, scriptable, repeatable — and it keeps working while the user has Blender open or closed.
- **Render on the GPU, keep persistent data on, and reuse the `.blend` while iterating.** Call `rig.use_gpu(scene)` — never `cycles.device = "GPU"` bare, which falls back to CPU silently when no compute device is usable. Measured here: one frame 16.5 s on CPU, 7.0 s on GPU, 2.2 s with `render.use_persistent_data`; rebuilding the scene from the generator costs 62.9 s where reopening the saved `.blend` costs 0.18 s. The look-fix-look loop went from ~80 s to ~2.5 s, and **iteration count is what the art is made of** — treat this as a quality setting. Numbers, caveats and the `--from-blend` pattern: `references/pipeline.md`.
- **The bridge is for interactive work**: inspecting a scene, screenshots, poking at objects mid-session. It must be started from inside Blender — nothing external can start it — so if port 9876 is dead, ask the user to run `bpy.ops.blmcp.server_start()` in Blender's Python console (UI: `Edit > Preferences > Add-ons > MCP > Start MCP Bridge Server`). **A dead bridge never blocks a render**; switch to headless and carry on.
- **Headless starts from Blender's startup file, so the default cube is there.** A generator that only purges its own prefixed objects will render that cube straight through the middle of the model. Call `bpy.ops.wm.read_factory_settings(use_empty=True)` first.
- **`blender_factorio_utils` add-on** provides `bpy.ops.factorio.setup_environment()`, `bpy.ops.factorio.create_shadow_catcher()`, `render_animations`, and a `factorio_utils_rotator` empty.
- **Poly Haven (CC0 textures/HDRIs): no add-on, no MCP tool — script it.** This rig's Blender MCP is not the ahujasid build; it has no Poly Haven functions, so don't search for them. The public API is verified reachable (no key) from both Blender's Python and system Python — use `scripts/polyhaven.py` (CLI or `import polyhaven`). Downloads cache in `assets/third-party/polyhaven/<slug>/`, git-ignored; details in `references/materials.md`.
- **Pillow, numpy and scipy** are expected in system Python — `factorio_render` needs all three (scipy only for a faster gaussian; it degrades to Pillow's). Don't probe for Pillow with `Image.__module__` — that raises on a module object and gives a false negative.
- `render_viewport_to_path` **ignores the path you pass it** and writes into Blender's temp dir. Read the real path out of the tool result.

## Rig gotchas — hit these once already

- **`to_track_quat("-Z", "Y")` takes the LOOK direction** — target minus
  position. Passing the offset *from* the target aims the camera (or sun)
  exactly backwards and renders blank. Cost one empty render to find.

- **Never parent the model to `factorio_utils_rotator`.** That empty carries the **camera and lights**; it orbits a *stationary* model to render directions. Parenting the model to it produces N identical frames. Model sits unparented at the world origin.
- **Do parent any extra fill light to the rotator**, so every rendered direction is lit identically.
- **`setup_environment()` deletes more than it says.** It's documented to remove the object named `Light`; driven headlessly over MCP its internal `select_all(action='DESELECT')` doesn't take effect, so the following delete also eats the active object. **Explicitly deselect everything before calling it.**
- **Two shells sharing an exactly coplanar face render OPAQUE BLACK in Cycles.**
  Measured on the Modern Belts splitter: a housing box and a roof plate both
  topping out at the same z rendered **64% black** over the part; dropping the
  box by 0.004 fixed it to 0%. It looks like a shading or normals bug and is
  neither — bevel, subdivision and winding were each ruled out first, one
  render at a time. Any time two boxes are meant to sit flush, offset one by a
  few thousandths. The same applies to the **shadow catcher**: a catcher plane
  exactly at the model's ground level is coplanar with every foot plate, so
  drop it ~0.003 below.

- **Winding follows the caller, and `sgn * a, sgn * b` reverses it.** Bounds
  written as `rect(u0, u1, sgn * inner, sgn * outer)` run the polygon backwards
  for `sgn = -1`, inverting every normal on that side of a symmetric part.
  Normalise the bounds inside the builder rather than fixing it downstream:
  `bmesh.ops.recalc_face_normals` is *not* the escape hatch, because it flips
  faces on intersecting closed shells — which is what a machine assembled from
  overlapping boxes in one mesh is.

- **A swept curve's handles must be fractions of its span, not absolute
  lengths.** Bezier handles tuned by eye against one height silently deform
  the shape the moment that height changes — and a height is exactly the kind
  of thing that becomes a knob later. Measured on the beacon's pylons: handles
  of 0.75 up and 0.55 down were 38% and 28% of a 1.95-tile rise; lowering the
  tips to a 1.20 rise left them at 63% and 46%, and four masts curled over
  into limp tentacles that read as bent tubing. Store the fractions
  (`0.385 * rise`, `0.36 * run`) and the curve keeps its shape at any size.
  Note `run` is per **axis** if the handles were written per axis — using the
  diagonal length instead overshoots by √2.

- **A mast's RADIUS is a fraction of its rise too, and so is every fitting
  on it.** Same trap, one level up, and it is the one that actually shows.
  The beacon's electrode tubes were 0.19 thick against a 1.95 rise — a 10:1
  mast. Lowering them to a 1.20 rise for the overhang left the radius alone,
  so the identical tube became 3:1 across its own diameter: a stub whose
  bend read as a kink and whose taper read as a traffic cone. The winding
  at its foot did not scale either, and on a 48 px pylon that bulb ate 15 px
  of the 48. **Whenever a dimension becomes a knob, sweep everything that
  was proportioned against it** — radius, taper, collars, caps, wire gauge —
  and put them all behind the one constant so they cannot drift apart. The
  beacon had `PYLON_R0` *and* a hard-coded `bevel_depth` *and* a hard-coded
  taper, three spellings of one number.

- **An inward-leaning mast is far shorter on screen than it is in the model,
  and by different amounts at the near and far ends of the machine.** Screen
  row is `-(y + z)`, so a pylon that rises 1.20 while leaning 0.45 *inward*
  travels only 0.75 tiles on screen if it leans north (the rise and the run
  cancel) but 1.65 if it leans south (they add). Measured on the beacon's
  four identical corner electrodes: **48 px at the back, 106 px at the
  front.** Nothing is wrong with the geometry and it still reads as "those
  poles are deformed".

  The painful part: that apparent length **is** the north overhang, one for
  one. Raising the tips to lengthen the rear masts raises the sprite's top
  edge by exactly as much, so there is no free version of the fix — the only
  levers are starting the tube lower inside its base, and not spending the
  little length there is on fittings.

- **A semi-transparent object used as a HOLDOUT leaves a ghost.** A glass pane or a glass
  dome marked `is_holdout` punches the part behind it as it should, but also returns alpha of
  up to ~40/255 over its whole footprint where nothing is behind it. Every crop box in that
  layer then grows to the ghost: on the quality assembler a 0.1-tile glass sight dome turned a
  40 x 38 px fan overlay into 74 x 158 and a 16 x 38 pipe stub into 138 x 116, and an opaque
  overlay built from the union alpha swallowed the whole window. Hide the glass outright in
  every layer that has nothing behind it, and keep it as a holdout only where a moving part
  genuinely sits behind it.
- Generator scripts should be **idempotent**: delete only your own prefixed objects (`AM4_*`) and rebuild. And make `make_material()` *re-apply* values to an existing datablock rather than early-returning — otherwise palette edits silently do nothing.

## The one rule that matters most

Vanilla has **no single consistent camera angle**. Wube prioritises how a thing looks on the tile grid over mathematical consistency — measured angles off vanilla sprites range ~38° to ~53°, and the oil refinery is four separate models rather than one rotated one.

Don't chase a magic number. Match, in priority order:
1. **Footprint alignment** — the entity sits exactly on its tile footprint.
2. **Lighting and shadow direction** — what makes art read "vanilla" at a glance.
3. **Material grime and paint** — vanilla is worn painted industrial, never clean, never bare chrome.
4. Camera angle — start at 45°, adjust until 1 and 3 look right.

## What the camera can actually see

At a 45° pitch with no yaw, exactly two surfaces of a building face the
camera: the **top/deck** and the **front (−Y) wall**. The side walls sit
edge-on and render as a one-pixel line, and anything behind a tall central
mass is simply gone. Measured repeatedly on the pure-modules-realk beacon: a control
console placed on the right flank was invisible behind a manifold; a whole
pass that migrated hardware out to the rear quadrants changed 5.6% of the
sprite's pixels; side-wall detail never appeared at all.

- Budget detail where the camera looks. The front half and the top carry the
  greeble; rear hardware only reads if it breaks the skyline above the tallest
  central element.
- A brief asking to "engage all four quadrants" is in tension with a tall
  centrepiece. Either raise the rear hardware until it clears the silhouette,
  or accept that the ring exists for the model and not for the sprite.
- Decide this by rendering, never by reasoning about the 3D scene. Two parts
  0.3 tiles apart in depth can sit exactly on top of each other on screen.

**Run the object-ID pass BEFORE adding detail, not after.** It is the only
check that measures the model rather than the output PNG, and on a dense
machine the answer is never what you expect: 60 of the quality recycler's 213
objects drew zero pixels — its ring gear inside a bearing wall, its radiator
inside a deck, its entire capacitor bank embedded in a 0.14-tile apron. Adding
content on top of that is paying twice. And when the pass calls a part dead,
find out what the occluder actually IS before rebuilding around it: three parts
there were deleted rather than moved, because the thing hiding them was the
hero drum in one rotation and a deck in another, and no wall could be opened.

**A ROTATABLE entity has four front elevations, not one.** Everything above is
written for a fixed entity, where the side walls really are one-pixel lines and
detail belongs on the deck and the −Y wall. Rotating the model swaps which wall
faces the camera: the west wall is the front elevation in east, the north wall
is in south, the east wall is in west. Measured on this repo's quality recycler
— three of its four rotations shipped reading as blank painted plates because
only the south wall had ever been given stiles, rails and a focal point, and
nothing in the gate kit reads that. Give every outward wall the same treatment,
and judge it by rendering all four, never by reasoning from the north view.

The same asymmetry bites the emissive layer. An emissive on a wall is face-on in
one rotation, a thin bright streak in two, and invisible in the fourth; an
UP-facing one is compact in all four, because the deck is the one surface this
camera always sees. Prefer up-facing slots, and check the glow sheet per
direction — a violet pair on this machine sat inside solid geometry and one
rotation had no glow at all, which no gate reads.

**A disc on a transverse (X) axis is EXACTLY edge-on and renders as a line.**
The camera looks along `(0, cos 45, −sin 45)`, which lies entirely in the Y-Z
plane — so a wheel, gear, pulley or fan whose axis is world X has the view
direction *inside its own plane* and projects to a stripe as wide as the part
is thick, whatever its diameter. Found the hard way on a mining drill's
flywheel: a 0.9-tile wheel rendered as a 5 px sliver, and an occlusion audit
came back clean because nothing was covering it. Rotating machinery has to
turn about **Y** (front-to-back, like vanilla's steam engine crank) or **Z**
(the assembler's horizontal gear deck). Both present a face; X never does.

**`pipe_covers` only works if the connection is on the machine's PERIMETER.**
The engine draws the cover in the tile *outside* the connection, so a machine
whose connections sit mid-flank — anything forced inboard by a small footprint
— gets a flat grey slab floating in open ground beside it, once per connection.
Measured in game on a 2x3 drill whose condensate ports had to go in the middle
row: two slabs, in all four rotations. The chemical plant is fine because its
ports are on its edges. If the ports cannot move, declare neither `pipe_covers`
nor `pipe_picture` and draw the stub in the sprite; the machine then looks the
same connected or not, which is a smaller price than floating art.

**The harness photographs WORKING machines only if the spec makes them work, and it
says so.** `shoot.ps1` takes a JSON spec; per entity, `insert` / `insert_count` puts a slow
item in a crafting machine (recycling runs at a sixteenth of the craft time), `inserts` (a
list of `{name, count}`) and `fluids` (a list of `{name, amount}`, put straight into the fluid
box) feed a multi-ingredient or fluid recipe -- processing units at 10 s keep an assembler
working for a whole run where a gear recipe hits `full_output` inside forty ticks --
`mirror = true` photographs the `use_mirroring` set, and per group `shoot_ticks = [50, 58, ...]` shoots a
tick sequence tagged `-t<offset>` so a loop can be judged in motion (the benchmark renderer
produces a new frame only every few ticks; sample eight apart). The probe researches every
technology, powers each group from a substation at its centre, and logs every machine's
`status` before each shot — read for `status working`, because a locked recipe, an empty
input or an out-of-range pole all photograph as a plausible idle machine (measured 2026-09-11:
every shot before that day was of an unpowered machine). It also logs where the engine
actually put each entity and on what grid (`-> engine position 7,1 (grid 4x4)`), because
`create_entity` snaps a building to its tile grid and a spec position off that grid lands
somewhere else without a word -- and because an owner's save can hold machines placed
under an older, smaller box, half a tile off the grid the current prototype snaps to. A group
with `belt_report = true` also logs every belt lane's item count and largest stack at each
shot, which is how "does the direct output stack on a belt" was answered (it does, to the
force's bonus) when the prototype API had no field to read. On a machine whose monitor is asleep
or whose session has no display output, pass `-ExtraArgs '--force-opengl'`; the harness
already writes windowed mode into its scratch config.

**Photograph every ROTATION, not just north.** A rotation-specific defect is
invisible to a one-rotation check, and every offline metric in one drill's
render pipeline passed while all four rotations carried the same visible fault.
Place four entities, one per direction, unconnected, and shoot them in one run
— it costs one `--benchmark-graphics` pass.

**A pipe joint cannot be judged offline — photograph it.** Two separate
offline composites of one mining drill reported every fluid connection
closed while the game showed daylight between the machine's flange and the
pipe's. Two reasons, both worth knowing: a pipe that TERMINATES against a
machine draws `pipe-ending-up/down/left/right`, **not** the straight sprite
(measured 2.1.14: `pipe-straight-vertical` is opaque y 12..95 on its 128 px
canvas, `pipe-ending-up` y 12..100), so a check built on the straight sprite
compares against art the game never draws there; and a scan *along* the pipe
axis cannot see a notch *beside* it, which is where the daylight actually was.
Build the joint in the engine with `--benchmark-graphics` and a probe mod that
places pipes on every connection and screenshots at zoom 6. It costs about a
minute and it is the only thing that has ever been right about this.

## Clearance between parts

Props that share volume fuse into one blob at sprite scale. Audit it
mechanically rather than by eye —
`assets/pure-modules-realk/entity/beacon/audit_overlaps.py` is the working example:
it BVH-tests every static part against every other, filters parts of the same
assembly and a whitelist of deliberate junctions, and reports worst-first.

**When the sprite comes out too big, measure which objects are doing it** —
do not squint at the render. Evaluate every object, transform its vertices by
`matrix_world`, and rank them by the quantity the sprite's edges actually
depend on. At a 45° pitch with the aspect compensation, screen row =
`centre − 64·(y + z)`, so **`y + z` is the axis to sort on** for the top and
bottom edges, and plain `x` for the sides:

```python
me = obj.evaluated_get(dg).to_mesh()
pts = [obj.matrix_world @ v.co for v in me.vertices]
rows.append((obj.name, max(p.y + p.z for p in pts), min(p.y + p.z for p in pts)))
```

Two bugs on the beacon's remnant were invisible in the render and instant in
that report: curved shell panels generated as an arc *around their own origin*
floated a full radius into the air and were the tallest thing in the sprite,
and a fallen arm modelled along +X was rotated by another 90° so it pointed
straight **down**, 1.5 tiles underground, with only its top showing.

**Build the BVH from world-space polygons.** `BVHTree.FromObject` works in the
object's *local* space, so every primitive centred on its own origin overlaps
every other one and the whole report is noise — that cost a full round of
fixing phantom collisions. Take `to_mesh()` on the evaluated object, transform
its vertices by `matrix_world`, and feed `BVHTree.FromPolygons`.

Where two parts are *meant* to touch, model the junction — flange, collar,
clamp, gland — instead of opening a gap. A uniform gap everywhere reads as
floating props; a fitting reads as engineering.

## Scale

- 1 Blender unit = 1 Factorio tile.
- 1 tile = **32 px in-game**, rendered at **64 px in source art**, declared `scale = 0.5`.
- The add-on's stock rig is `ortho_scale = 8.0` over 256 px = 32 px/tile (**low res — don't ship this**).
- **Use `ortho_scale = 5.0` over 320 px = 64 px/tile**, then `scale = 0.5`. (This one *is* sound — it's arithmetic against the measured vanilla px/tile, not a look judgement.)
- The general rule is **px/tile = `resolution_x` / `ortho_scale`**, so a canvas has to be resized in step with the scale or the whole sprite silently changes size. Growing a canvas from 512 to 576 for more headroom means `ortho_scale` 8.0 → 9.0. Re-run the footprint gate after any such change — it is the only thing that catches it.
- Camera orthographic at `(0, -60, 60)`, rotated 45°, targeting the world origin.
- Because the camera targets the origin and that *is* the entity's position, `shift = {0, 0}`. Only add shift when the art deliberately overhangs.

**Overhang north is what players actually notice, and it has a measured band.**
A tall entity draws above its own tiles and covers whatever is placed behind
it. Measured off vanilla 5x5s (2026-08-30): foundry **0.52** tiles past the
footprint's north edge, cryogenic plant **0.70**, biolab **0.81**. This repo's
beacon measured **2.06** and a machine placed north of it was overlapped by two
tiles — reported from play, not caught by any gate.

The arithmetic to check it: at the 45° rig, screen row = `centre − 64·(y + z)`,
so **the sprite's top edge is set by whichever part has the largest `y + z`** —
a part far north raises it exactly as much as a tall one, which is why ranking
objects by height alone blames the wrong ones. Rank by `y + z`, and convert:
`overhang = max(y + z) − footprint_half`.

**Footprint check before any final render:** render a plane the size of the entity's tile footprint. It must come out square at exactly `tiles × 64` px. The ground in Factorio is drawn top-down while buildings are pseudo-3D, so a naive 45° pitch foreshortens the footprint — the working compensation (beacon-validated): **`pixel_aspect_x = 1.41421` (1/cos 45°) with `sensor_fit = 'HORIZONTAL'`** on the 45°-pitch ortho camera. That renders the ground plane square *and* world-Z heights at exactly 64 px/unit. Verified by an automated gate: 5×5 plane → 320×320 px at ≥50% alpha.

## Lighting

Vanilla-verified direction: `assembling-machine-1-shadow` is shifted **+44.5 px in X**, so shadows fall **right**, essentially level in Y. Light comes from the **upper left**. If your shadow falls left or strongly down, the sun is wrong.

- Sun rotation **X 0°, Y −39.3°, Z 5°**. The sign matters and the community value has it backwards for this rig: +39.3° casts shadows LEFT (verified the hard way on the beacon); −39.3° puts the sun upper-left with shadows falling right.
- **The stock rig leaves the camera-facing side black** — it creates one key sun behind-left only. Add sky ambient plus a soft front fill sun, parented to the rotator.
- **Validated set (pure-modules-realk beacon, 2026-08-05, user-approved in game): key 5.2 / front fill 1.2 / world ambient 0.22, rendered in Cycles.** Start here, not from the older assembler-4 escape values (key 3.6 / fill 1.15 / ambient 0.26 — those were merely "not broken").
- **Render entities in Cycles, not EEVEE.** EEVEE was tried and rejected on the beacon: no AO or contact shadows, so parts read flat and detached no matter the lighting. Cycles' GI is what makes crevices dark and assemblies sit together — and the shadow pass needs it anyway. ~96 samples denoised is enough at this resolution.

## Colour management — the blowout trap

Factorio requires **View Transform: Standard**. Blender 4.x/5.x defaults to **AgX**, which washes art out relative to vanilla.

- View Transform: **Standard**
- Look: **None** was used on the assembler-4 run; a forum guide suggests **Medium High Contrast + exposure −0.150**. Since that run looked wrong, the contrast option is worth trying — vanilla art is high-contrast, and Look None may be part of why the output read flat.
- Film: **transparent**

**Standard clips hard.** This is the single easiest way to ruin a render: emission strengths of 5–8 blow straight to pure white and you lose the colour entirely. **Keep emission ~1.8–2.2** to avoid total blowout — but that alone does not keep the *hue*: at 1.9 a cyan glow still clipped to white on the beacon. To keep a glow coloured, the **max emitted channel (colour × strength) must stay ≈ 1.0–1.1**; the low off-channels are the colour.

## Post — never ship a raw render

Wube duplicate every render twice in Photoshop, set the copies to Multiply and Screen with masks, and hand-work "contrast, clearer edges, better-defined shape" over the result (FFF-146; still true for Space Age per FFF-432). `design-language.md` lists skipping it as tell #9. `post.paint_over(image, preset)` is that step, arithmetically.

- **It is calibrated against vanilla, not chosen by eye.** Vanilla source art at 64 px/tile measures luminance sd **43.0** (beacon-bottom), **46.8** (beacon-top), **51.6** (lab). This repo's raw beacon render measured **31.6** — flat against all three, and that gap is the most reliable "render, not Factorio sprite" signal there is. **Target band for an entity body: sd 43–52** — what vanilla measures. `gates.contrast` enforces the wider **(43, 56)**; aim at the first, and read a pass against the second rather than assuming they are the same number.
- **Run it per frame, before packing.** Every operator has a radius; over an assembled sheet it bleeds frame N into frame N−1.
- **Not every layer wants it.** A shadow is already pure black; an additive glow layer gets eaten by crevice deepening; a layer carrying translucent vapour needs `alpha_gamma=1.0` or the softness it is made of gets thinned away.
- **Luminance sd alone will mislead you — check WHERE the contrast sits.** Split the variance into form (>12 px) and grain (<3 px). Vanilla 5×5 entities run form/grain **1.70** (cryogenic plant) to **3.27** (lab); this repo's beacon rendered at 1.32 and the paint-over's unsharp pass pushed it *down* to 0.64 while hitting its sd target, because an unsharp mask lifts every frequency above its radius and most of a greebled sprite's energy is 1–3 px wide. `post.form_contrast` applies the gain to the low-pass instead, so whole faces separate and the rivets stay put. Numbers and the preset split: `references/pipeline.md`.
- **It sharpens what the render got right; it cannot add what the palette lacks.** Vanilla bodies measure saturation 0.27–0.44 with 77–83% of pixels above sat 0.12; this beacon measured 0.16 with only 47% — over half the sprite effectively greyscale. No post setting fixes that. The rest is copper/rust/paint *zones* — a materials fix, and `references/materials.md` has the measured targets.

## Alpha: never resize RGBA directly

Blender writes **straight (unassociated) alpha**, so `Image.resize()` averages colour across the alpha edge unweighted and lays a dark rind round the sprite. Measured on this repo's own art: 32% of partially transparent pixels carry `max(RGB) > alpha`; a 50% reduction came out mean `|dRGB|` **75** on the antialiased outline, and a 4× icon reduction put 27–38% of surviving pixels more than 8/255 wrong. Factorio loads with `premul_alpha = true`, so the *files* are the right convention — the resampling was the bug.

**Use `imaging.resize` / `imaging.scale` / `imaging.mipmap_strip`.** And crop against an alpha floor (`imaging.bbox_above`, default 8): Cycles leaves alpha 1–7 across the film, invisible in game and still growing the sprite and its atlas footprint.

## Materials — vanilla feel

**How to actually build them is in `references/materials.md`** — the
validated scripted node-graph stack (base mottle → grime streaks → AO rust →
per-object jitter → pointiness edge wear, reference implementation
`worn_metal()` in the beacon generator) plus the verified Poly Haven CC0
texture/HDRI route. A flat single-colour Principled BSDF is never acceptable
on a shipped sprite; read that file before authoring any material.

- Factorio machines are **painted metal**, not bare metal. Metallic 0.75+ on a body renders near-black, because a metal surface with a dim world has nothing to reflect.
  - **Body: metallic 0.15–0.45.** Trim/gold accents only: 1.0.
- Muted steel, oxidised iron, olive/khaki, dark grey plastics.
- Saturated colour used **sparingly and functionally** — status indicators, pipes, a single accent band. Never large body panels.
- Edge wear, grime in crevices, surface variation. Clean flat surfaces read as non-vanilla instantly.
- Emissives are small and belong in the `-status-light` layer, not baked into the base.
- Keep glowing parts **actually visible** — an emissive core fully enclosed in an opaque shell shows nothing. Use collars/struts and leave the core exposed.
- Sanity-check geometry with a bounding-box read: pipes poking through their own flanges is easy to miss in viewport.

## Shadows

Vanilla shadows are a **separate sprite**, pure black + transparent, no gradients.

**EEVEE has no shadow catcher — the shadow pass needs Cycles.** Use `bpy.ops.factorio.create_shadow_catcher()`. Skipping this is why an otherwise-good machine reads as floating.

Two view layers:
1. **Entity layer** — model, transparent background, shadow catcher off.
2. **Shadow layer** — shadow-catcher ground plane, material override black, model excluded from colour output.

Filter the shadow layer in compositing to hard black/alpha — no soft grey gradient; Factorio tints and blends it itself. Measured off vanilla: shadow alpha is essentially binary, so threshold the catcher output (~alpha ≥ 110 → 255, else 0) plus a 1 px blur for edge AA. Declare with `draw_as_shadow = true`.

**A cast shadow can erase the very thing the design is about.** An entity that
reads as raised does so because you can see ground *under* it — and a
physically correct shadow from a deck 0.34 tiles up lands straight in that gap
and fills it. Measured on the Modern Belts belt: 1–2 px of ground survived
across the entire fascia, so on terrain the structure and its shadow merged
into one dark bar and the belt read as lying flat. Casting from the legs alone
still threw spikes out past the tile. What worked is what vanilla does — no
cast shadow, just a small contact shadow generated in post from the feet's own
alpha, offset a few px and confined below the deck line. **Gate it with a
number**: count transparent pixels per row in the gap and require most of it to
be open.

**Judge every sprite on the terrain it will sit on, not on a neutral grey.**
The ground colour `(58,54,44)` this file recommends for remnants is a dark
neutral, and dark structure on dark ground hides exactly the mistakes that
scream on Nauvis dirt (roughly `(150,96,45)`). A fascia that looked articulated
on the test background was a solid black bar in game.

**Bake shadows of static geometry only.** A static shadow of an animated or floating part (a spinning ring, a hovering crystal) lands displaced by its height, detached from the building, and stays frozen while the part moves — it reads as a wrong dark blob on the ground (found in game on the beacon). Vanilla either ships an animated `draw_as_shadow` sheet or omits the shadow for such parts; omitting is the cheap correct default.

**The shadow must not overlap the entity's own base sprite.** Shadows composite ABOVE `floor-mechanics` and `lower-object` (the layer name `lower-object-above-shadow` is the tell), so if the body sprite lives on one of those layers, every shadow pixel under the building silhouette darkens the entity's own surface in game at ~50% — invisible in the PNGs, obvious on the map (found in game on the beacon: 80% of the sprite was self-shadowed). Mask the baked shadow by the base sprite's alpha so only the cast shadow on open ground remains; the beacon's `make_sheets.py` does this.

## Entity sprite layer structure

Vanilla splits an entity into separate PNGs, composited as `layers`:

| Suffix | Purpose | Prototype flags |
|---|---|---|
| `-base` | static body | `repeat_count` matching the anim frame count |
| `-anim` | only the moving part | `frame_count = 64` |
| `-shadow` | shadow pass | `draw_as_shadow = true` |
| `-status-light` | working/status glow | `draw_as_glow = true`, `blend_mode = "additive"` |

Keep the animated part in its own smaller sprite instead of re-rendering the whole body per frame — vanilla `-anim` sheets are far smaller than the body for this reason.

**Animation: vanilla is 64 frames at `line_length = 8` (8×8 grid).** A 32-frame 8×4 sheet works but is below vanilla smoothness — match 64 for tier-parity with base entities.

**A tinted mask has two independent requirements, and satisfying one is easy.**

*Luminance* — any layer with `apply_tint` / `apply_module_tint` is *multiplied*
by the tint, so a flat sprite can only ever produce a flat patch of colour.
Vanilla's `beacon-module-mask-box` spans luminance 26–255 with a mean near 146;
a mask built from an emission-only material measured 249/254/255 and read as a
pastel rectangle pasted onto the machine.

*Alpha* — FFF-218, verbatim: *"unless you are doing something extremely
specific, the colour mask values should always be at 0.5 Alpha… The Alpha is
black magic, keep it at 0.5 please"*, on the stated condition that both the mask
and the area under it are desaturated. At full alpha the mask **replaces** the
pixel and the machine's own shading vanishes under a coloured decal; at ~0.5 it
modulates and the form shows through. Measured: vanilla
`beacon-module-mask-box-1` median alpha **106**, max 253, *nothing* at 255;
`beacon-module-mask-lights-1` median **182**. This repo's masks measured median
255 with 76% fully opaque until it was corrected. Not universal — vanilla's
biter masks are 79% opaque — so **match the vanilla counterpart** of whatever
you are masking. A `draw_as_light` sprite is not a tint mask and keeps its own
alpha. Gate: `gates.tint_mask`. Render masks with ordinary lit materials in
neutral grey and let the tint land on real form.

**An overlay layer must not redraw what the base sprite already contains.**
Duplicated geometry across layers is not just wasted work: the overlay draws
above the base and silently occludes whatever else was there. The beacon's
module-slot sprite redrew a socket housing the base already had, and covered
13 rows of the front lip under each of four slots. Every individual PNG looked
correct, because no single file can show one layer covering another. Composite
the layers at their prototype shifts and diff against the base alone to find
it:

```python
diff = ImageChops.difference(base_only.convert("RGB"), with_overlays.convert("RGB"))
# changed rows outside the overlay's intended footprint = occlusion
```

**Re-render only the layers a change touches.** The animated sheets are the
expensive part (64 frames each); a deck or hull edit only invalidates `base`
and `shadow`. Keep the frame directory around and rebuild the sheets from it.

**Status lights do not survive a deepcopy.** If you derive an entity from a vanilla one, its `working_visualisations` glow sprite is positioned for *that* shape. Re-author it or drop it deliberately.

**`idle_animation` does not play.** A crafting machine that is not working is frozen, and the
idle sheet is drawn at the frame the working animation stopped on -- which is why the API
requires the two to share a frame count. It is an alternate LOOK for the stopped machine (the
electromagnetic plant's darker base), never a slower loop. Measured on the quality assembler
2026-09-13 with a tick sequence: a `no_recipe` machine did not change a pixel between t+6 and
t+18 while the working one beside it moved. A second sheet with different fan angles would jump
the instant the machine stopped.

**But a working visualisation with `always_draw` AND `constant_speed` plays in every state** --
idle, no recipe, even unpowered. Measured the same day with the anim sheet in three slots at
once on an unpowered machine: the base animation and a plain `always_draw` copy did not change
a pixel over five shots; the `constant_speed` copy moved every shot and closed its loop after
exactly 128 ticks (64 frames at `animation_speed = 0.5`). That is the slot for anything that
should run while idle -- a refrigerator's fan, a pilot lamp's pulse. It runs at ONE speed; "slow
when idle, fast when working" is done with a working-only visualisation drawn OVER it, made
opaque (the painted base under the moving part, cut to the disc it sweeps) and listed after it,
since working visualisations draw in list order, with `fadeout` so the part runs down on stop
rather than jumping. The quality assembler's `make_sheets.py` builds those overlays.

**The base animation is not scaled by the crafting speed.** Same tick sequence, on the working
machine at `crafting_speed = 2`: every layer returned to identical pixels after 128 ticks, the
declared `animation_speed`. Author the loop's timing against the declared speed.

**A turning part's step per frame must stay under about 0.4 of its blade or spoke period**, or
the wagon-wheel effect turns it backwards in game. A fan at 5 turns over 64 frames steps 28° a
frame: past half of a seven-blade period (51°) and it strobed backwards on the quality
assembler -- the tick sequence showed the working fan changing LESS between shots than the idle
one; against a five-blade period (72°, step 0.39) it reads forward. Check every wheel: step =
360 x turns / frames, against 360 / blades.

**`pipe_picture` is drawn centred on the tile OUTSIDE the connection**, the same origin
`pipe_covers` use, not on the entity. Measured the same day: stubs rendered about the entity
centre and declared with entity-relative shifts drew a full tile past the pipe -- a floating hook
above the north one, a spare flange on the south one's far end. Subtract the outside tile's
offset (two tiles, 64 display px at `scale = 0.5`) from the shift, and keep the stub to a collar
at the hull plus a short barrel: the pipe entity's own ending sprite carries the flange at the
joint, and a flange on the stub doubles it.

## Remnants (corpses)

A wreck follows almost none of the entity rules above, and measuring vanilla settles
every question. Two incompatible styles ship in 2.1 — pick by the entity's era:

- **Base 1.x art** (`beacon-remnants`) — a near-plan-view *nest of guts*: hull gone,
  copper windings and hoses tangled inside a broken rim.
- **Space Age 2.0 art** (`cryogenic-plant-remnants`) — the machine *comes apart into
  recognisable panels* that lie flat and overlap in a low pile, identity paint surviving
  in patches under heavy rust. **This is the one to match for anything modern.**

Measured off base and Space Age, and none of it is guesswork:

- **No `draw_as_shadow`, anywhere.** Zero hits across every vanilla remnant. The ground
  shadow is composited into the colour sprite as soft grey. One flat RGBA per variation:
  no layers, no glow, no animation.
- **Zero emissives.** The cryogenic plant's bright windows are dark holes in its wreck.
- **Mean luminance 63–67** over opaque pixels — cryo 67.1, reactor 65.8, beacon 62.9. (`gates.remnant` enforces the wider **(60, 72)**.)
  A wreck is burnt and unlit and sits well below the machine it came from. This is the
  easiest thing to get wrong: a first pass that simply re-materialled a model with the
  *entity's* validated rig measured 93 and read as a lit pile of scrap. Dim the material
  palette; do not touch a rig that is already validated for the entity.
- **Size is roughly the building, not a debris field.** 5×5 entities: cryogenic plant
  370×354 source px (5.8 tiles), nuclear reactor 410×396 (6.4). Debris thrown out to
  4 tiles is wrong — the machine collapsed in place.
- **The soft fringe past the pieces is DARK, not pale.** Measured over the
  semi-transparent band (alpha 6–170): cryogenic plant **(20,16,11)**, nuclear reactor
  **(3,3,2)**, beacon **(14,12,10)**, at mean alpha 67–76 and covering 15–51% as many
  pixels as the wreck itself. It is scorch and shadow spill, not dust.
  **This is a trap worth naming**: opened on a white background, a vanilla remnant's dark
  soft edge *looks* like pale grey haze, and building an ash halo to that misreading
  produced a light ring that glowed around the whole silhouette the moment it sat on the
  game's dark ground. Generate the fringe in post from the wreck's own alpha (dilate →
  subtract silhouette → speckle) and colour it near-black.
- **Judge a remnant composited on the ground colour**, roughly `(58,54,44)`, never on
  white or on a transparency checker. Everything above about value and fringe is
  invisible otherwise.
- **Variations** are stacked vertically in one PNG and selected with a `y` offset —
  what base's `make_rotated_animation_variations_from_sheet` does. Two is typical.
- Prototype: `type = "corpse"`, `tile_width`/`tile_height` matching the entity,
  `selectable_in_game = false`, `hidden_in_factoriopedia = true`,
  `final_render_layer = "remnants"`, `expires = false`,
  `time_before_removed = 60 * 60 * 15`. Wire it with `entity.corpse = "<name>"`.
  **No locale key** — vanilla defines none for its own remnants, and the corpse is
  unselectable and hidden, so the name never renders.

Two traps found building one:

- **Threshold the shadow catcher before softening it.** Cycles returns a faint ambient
  wash across the *entire* catcher plane. Left in, it greys the whole tile and — being
  non-zero everywhere — drags the sprite's crop box out to the full canvas. Same fix the
  entity's shadow pass uses: hard-threshold, then blur 1–2 px for edge AA.
- **Apply an alpha floor before computing the crop.** Ash grains and antialiasing at
  alpha 1–7 are invisible in game and still grow the sprite; a 410 px wreck cropped to
  500 px purely on pixels nobody can see.

Reuse of an entity's generator is the cheap way in: keep its helpers and part vocabulary,
and swap the **material dict's values under the same keys** so every reused part builder
renders dead without being edited. Missing one emissive key leaves a lit LED in a
burnt-out machine and nothing in the render flags it.

## Frozen patches (Aquilo)

`graphics_set.frozen_patch` (and `LabPrototype::frozen_patch`, `inserter.platform_frozen`, …)
is a **single overlay sprite drawn on top of the normal art while the entity is frozen** —
transparent wherever the machine still shows. It is never a re-render of the machine. The
entity only ever *reaches* the frozen state if `heating_energy` is set, which the `freezing`
feature flag gates — see the repo `CLAUDE.md`. Without it the patch is dead weight.

Measured across all four Space Age patches (beacon, centrifuge, electric furnace, lab):

- **Colour** is a cool blue-white, always R < G < B at saturation 0.10–0.17. Opaque mean
  (157,174,183)–(196,209,216); bright caps (222,229,233)–(232,237,239); packed ice in the
  recesses (83,107,121)–(149,172,185).
- **Never dark.** Not one opaque pixel of any vanilla patch falls below luminance 60, and the
  1st percentile sits at 73. This is the easiest thing to get wrong, and the worst: the patch
  draws *over* the entity, so dark snow paints soot blotches on the machine.
- **Coverage, measured against the machine's own opaque area** (not the sprite box — box
  percentages are not comparable between entities): solid alpha 12–20%, everything above
  alpha 8 about 35–42%. **The shape matters more than the totals — vanilla's solid band
  outweighs its faintest band.** A patch with that ratio inverted is a translucent film over
  the whole hull rather than drifts sitting on it, and reads in game as the machine going
  pale. Every colour statistic can be in range while this is inverted, so check it explicitly.
- Snow sits on up-facing surfaces and convex edges, patchy, with bare metal showing through.
  Flat vertical walls stay bare.

The cheap way to author one: render the same geometry as the base layer with a **material
override** whose alpha is driven by world normal Z, pointiness and noise, and whose colour
mixes between an ice tone and a snow tone by an Ambient Occlusion term — so recesses go
blue-grey and exposed caps go white, which is exactly vanilla's split. Drive coverage and
colour from *separate* curves off that AO: one curve for both leaves the crevices bare instead
of icy. `snow_override()` in the pure-modules-realk beacon generator is the worked example, and
`make_frozen.py` beside it gates the result against every number above.

If the patch covers animated parts, set `reset_animation_when_frozen = true` and render it at
frame 0 — vanilla's centrifuge does this so the ice lands on its drums rather than beside them.

**The trap that costs an afternoon: Cycles' transparent bounce limit.** A material override
turns every surface semi-transparent, so a camera ray crossing a detailed model meets far more
than the default 8 transparent surfaces. Past the limit Cycles gives up on the ray and returns
**opaque black** — which lands as soot blotches over exactly the densest greeble, looks like a
shading bug, and is invisible in any per-material check. Set
`scn.cycles.transparent_max_bounces = 128`. Two related consequences once it is raised:

- **`AddShader` emission accumulates per layer.** A constant emission "floor" added under the
  lit result gets summed once per surface the ray crosses, and stacked geometry saturates to
  pure white. Floor the value with albedo and lighting instead.
- **Mask back faces** (`Geometry > Backfacing`) and undersides. Otherwise the inside of every
  shell is snowed too and composites into the pixel, so the sprite goes white where the model
  is *thickest* rather than where the drifts are.

And the ordinary blowout rule still applies hardest here: snow albedo near 0.7 linear clips
straight to flat 255 under this rig's 5.2 key sun. The picked colours sit well below where the
snow lands.

## Tiling sprites: clip to empty, don't reorder

A sprite that has to tile seamlessly (belts, walls, pipes) is usually generated
by laying a world-locked pattern down and clipping it to the tile. Clipping
produces an **empty** range whenever a feature falls entirely outside — and an
empty range is `hi < lo`, which looks exactly like "bounds given backwards".

Normalising it is a trap. On Modern Belts a `min`/`max` helper that swapped
reversed bounds turned every clipped-away chevron into a valid range *in the
overhang*, so each tile drew a phantom fragment onto its neighbour. In game the
arrow spacing alternated 29.5 / 34.5 px instead of a constant 32, which reads
as "every tile is different" — and no single sprite looks wrong, so it is
invisible until the run is tiled.

Swap only the axes where reversal is meaningful (an across-the-run pair written
`sgn * inner, sgn * outer` genuinely reverses for `sgn = -1`); let the clipped
axis fall through to the empty guard. Then verify by tiling: concatenate the
tile's own columns several times and assert the feature spacing is constant.

## Terrain tile transitions — the edge is the art

A tile's edge against a different tile (water shore, lava ledge, void rim) is not part of the
tile's own variants: it is a **transition spritesheet**, defined on the *neighbouring ground*
tile and drawn on the target tile. Measured off base's out-of-map sheets and Space Age's
foundation (2.1.14), and verified by rebuilding the system for a mod:

- **One sheet, three bands**: overlay (drawn above both tiles), background (the wall/bed, drawn
  in the target's layer group), mask. Band x-offsets and block y-offsets come from a layout
  constant — reuse base's (`tile_spritesheet_layout.transition_4_4_8_1_1` etc. from
  `__base__/prototypes/tile/tile-graphics`) and mimic its geometry exactly rather than
  inventing one.
- **Blocks per piece kind** — inner corner, outer corner, side, u, o — variants along x, and
  **4 rotation rows per block, ordered CLOCKWISE from north by where the ground sits**:
  row 0 ground-north (the visible wall face), row 1 ground-east, row 2 ground-south (a rim
  only — that wall faces away from the camera), row 3 ground-west. Corner rows follow the same
  step: inner row 0 = ground N+E, u row 0 = open south. **Decoded, not read off art**: a sheet
  of solid colour codes (block in R, rotation in G, piece-row in B) rendered by the engine over
  a set_tiles arena of canonical shapes — reading vanilla art suggested counterclockwise and
  shipped every east/west wall mirrored.
- **Anchoring**: a `tile_height = 2` piece has its top 1x1 tile centred on the tile being drawn
  and hangs one tile south (the docs' one load-bearing sentence). Masks and o-pieces are forced
  to height 1.
- **Masks are luminance-coded on opaque pixels**, not alpha: white means "draw the ground
  tile's own texture here". This is what makes one sheet correct against every terrain —
  grass tears as grass, concrete as concrete, painted by the engine.
- **Only near-dark may touch a piece border.** Where the rim turns a corner, the neighbouring
  tile carries no face piece, so a bright feature ending on the border reads as a razor cut.
  Vanilla keeps bright detail in mid-piece clumps; force edge columns dim — and inside corner
  and u pieces, *taper* the face toward each side that carries ground (shorter, dimmer columns
  over the last ~26 px) so the wall turns instead of stopping. Never taper an open side: the
  neighbouring tile's face continues across it.
- **A mask lip eats whatever hugs the same edge.** The narrow wall slivers on east/west/south
  boundaries sit in exactly the band the ground lip covers; a 10–30 px lip erased them
  entirely in the engine. Give the face edge a deep lip and every other edge a shallow one
  (~5–14 px), and keep slivers wider than the lip above them.
- **A winding edge is almost never straight.** In a real 100x64 map sample the longest straight
  north rim was one tile — corners and side slivers carry the look. Judge art on a real
  boundary shape, not on a straight test strip.
- Patching transitions onto vanilla tiles is a data-stage loop with two traps: base **shares
  one transitions table between several tiles** (all four grasses), so guard every append with
  a has-it-already check or the engine dies on a duplicate pair; and transition group ids are a
  tiny shared namespace (0-2 base, 3 Space Age lava) — declare yours
  `my_group_id = my_group_id or N` so mods can cooperate.

Everything above was established on a working implementation (a chasm tile with cliff-style
walls, since removed from the repo). **Verify transition art in a real engine, never by an
offline mockup** — a compositor built on careful art-reading still got the rotation order and
two art-interaction rules wrong; the `factorio-validate` skill's `--benchmark-graphics`
harness is cheap and tells the truth. The dev installs are DRM-free, so it runs whenever asked.

## Sprite metadata sidecars

Vanilla puts a `.lua` beside each PNG, loaded by `util.sprite_load`:

```lua
-- thing-base.lua
return { width = 198, height = 184, shift = util.by_pixel(0.0, 4.0), line_length = 1 }
```
```lua
util.sprite_load("__mod__/graphics/entity/thing/thing-base",
  { priority = "high", repeat_count = 64, scale = 0.5 })
```

Keeps pixel dimensions next to the art. Use it, or declare `width`/`height`/`shift`/`scale` inline — but be consistent within a mod. `shift` is in pixels via `util.by_pixel`, relative to entity centre.

**Prototype-side polish** costs a line each and is easy never to notice: `water_reflection` (free when deriving from a vanilla entity, absent on a from-scratch one), the `usage` / `surface` sprite-atlas hints vanilla uses in hundreds of places, `dice` for a large sprite, `light` on a working visualisation, and `fog_mask` on Fulgora/Aquilo. Entities get **no normal maps** — the flag exists but only asteroids, platform backdrops and tile effect maps use it, so everything the surface does has to be baked into the sprite. List and the game's own QA flags (`--dump-icon-sprites`, `--log-spritesheets-to-optimize`, `--report-autogenerated-icon-mipmaps`): `references/pipeline.md`.

## Icons

Rendered separately from the entity, usually a more head-on 3/4 view so the item reads at 32 px in the toolbar.

| Kind | Logical size | Vanilla file size (mipmap strip) |
|---|---|---|
| Item / recipe / entity icon | 64×64 | **120×64** (64 + 32 + 16 + 8, horizontal) |
| Technology icon | 256×256 | **480×256** (256 + 128 + 64 + 32) |

Mipmaps are optional but vanilla-standard — they stop icons shimmering when scaled in the UI. A plain 64×64 / 256×256 works and is what the assembler-4 test shipped. Test the silhouette at 32 px before committing to a design.

**Everything above this section is written for entity sprites, and most of it does not apply to icons** — icons have no shadow sprite, no layers, no animation, and are not locked to the tile grid, so the `ortho_scale` and footprint rules are irrelevant to them. Before rendering an icon, read **`references/icons.md`**: the camera and lighting that actually worked, why bloom has to be applied after the render rather than in the compositor, and the drop shadow that technology icons carry and item icons don't.

## Before calling a sprite done

- [ ] **Built the `vanilla.contact_sheet` A/B — your layers and a real vanilla entity's, on Nauvis dirt, at 1× and 3× — and looked at it.** Nothing else on this list matters if this fails.
- [ ] `gates.check_all` run and green: contrast, clipping, crop waste, shadow, tint masks, and whichever of remnant / frozen apply
- [ ] **`gates.silhouette` run and green** — zero full-width rows, fill ≤ 0.90, ragged ≥ 1.05.
      No vanilla entity has one scanline crossing it edge to edge; this repo's beacon had 88%
      of its rows that way through a published release, past every other gate here
- [ ] **`gates.wear_mask` run on the edge-wear term** — the only gate that measures the *model*. Every other one reads the output PNG, which is how a wear term that marked 55% of the beacon shipped unnoticed (`references/materials.md`)
- [ ] Form/grain ratio checked against a vanilla entity of the **same footprint**, and saturation distribution against `references/materials.md`
- [ ] Object-ID render run — nothing the design depends on is buried inside another object (`references/pipeline.md`). **Write the pass to scene-linear EXR, not PNG**: a display transform will not preserve the ID lattice, and setting the view transform to Raw does not save it — measured on the quality recycler, PNG classified 34% of pixels and reported three plainly visible assemblies as invisible, where EXR classified 97%. A worked implementation is `assets/quality-recycler/entity/quality-recycler/check_visibility.py`
- [ ] Paint-over applied per frame before packing; no layer that shouldn't have it did
- [ ] Every resize went through `imaging`, not `Image.resize`
- [ ] Drawn size against the entity's footprint checked with `area_vs_footprint`, and the **north overhang** measured against vanilla's 0.52–0.81 tiles
- [ ] Design plan written per `references/design-language.md` and the render reviewed against it
- [ ] Silhouette broken on at least two sides, asymmetric, front elevation visible (not plan view) — and it still reads clearly at 32 px. A square deck plate projects to a
      filled square at this rig, and four symmetric corner posts undo the cut on their own
- [ ] At least 8 distinct kinds of functional greeble on a production machine (fewer on a utility entity), each with a visible purpose — power in, material through, heat out, human service
- [ ] At least 4 material zones; identity paint desaturated and confined to housing; one semantic accent colour
- [ ] Wear placed by physics — edges chipped clean, crevices grimed, soot at heat exits, rust at feet — never uniform noise
- [ ] One busy hero zone against calm hulls; sprite tested tiled in rows and next to vanilla neighbours, not only as a lone render
- [ ] Edges are bevelled; surfaces are not flat single colours; crevices are dark
- [ ] Footprint test plane renders square at exactly `tiles × 64` px
- [ ] `ortho_scale 5.0` / 320 px per 5 tiles, `scale = 0.5` in the prototype
- [ ] View Transform **Standard**, Look **None**, film transparent
- [ ] Emission ≤ ~2.2 — check nothing clipped to white
- [ ] Body metallic ≤ 0.45 — check nothing rendered near-black
- [ ] Detail sits where the camera looks — nothing important on a side wall or
      buried behind a tall centrepiece
- [ ] Tinted masks are shaded greyscale, not flat white
- [ ] Overlay layers composited over the base and diffed — no unintended occlusion
- [ ] Interpenetration audited in world space; deliberate contacts have a fitting
- [ ] Base / anim / shadow / status-light exported as separate PNGs
- [ ] **Shadow layer actually rendered** (Cycles pass) — not skipped
- [ ] Remnants: shadow baked into the colour sprite, no emissives, mean luminance
      near vanilla's 63–67 — measured, not eyeballed
- [ ] Frozen patch: nothing below luminance 60, solid alpha band ≥ faint band,
      coverage measured against the machine's area — and transparent_max_bounces raised
- [ ] Front-facing side is lit; fill light parented to the rotator
- [ ] Model unparented from the rotator; directions are genuinely different
- [ ] `.blend` saved under `assets/<mod-name>/`, PNGs exported into the mod's `graphics/` — no source files inside the mod folder
- [ ] Validated with `--dump-data` (see CLAUDE.md), then **photographed in the engine** with `scripts/screenshot/shoot.ps1` — a row of it plus a vanilla neighbour, at zoom 1 and 2 — and the pictures looked at. Data-stage exit 0 is not proof it looks right, and neither is an offline composite: module tint, `draw_as_light`, render-layer order and shadow blending only resolve in the renderer. It runs with the game open
