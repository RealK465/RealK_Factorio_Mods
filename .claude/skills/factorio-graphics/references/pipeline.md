# The pipeline — library, iteration loop, post, and the engine side

`SKILL.md` decides *what* a sprite has to look like. This file is *how the
work runs*: the shared code, what a render actually costs, the paint-over
between Blender and the spritesheet, and the prototype-side fields that make a
correct sprite behave correctly in game.

Read it before setting up a new mod's art, before touching a render driver,
and any time a render feels slow enough that you are tempted to skip a look.

## The shared library

`.claude/skills/factorio-graphics/scripts/factorio_render/` — tracked with the
skill, so it travels with a clone.

| Module | Needs Blender | What it is |
|---|---|---|
| `rig.py` | yes (`bpy`) | camera, sun, colour management, Cycles + device selection, render passes |
| `greeble.py` | yes | the vanilla parts vocabulary as bmesh builders |
| `imaging.py` | no | alpha-correct resize, crop, sheets, mipmaps, shadows |
| `post.py` | no | the paint-over pass |
| `vanilla.py` | no | composite real prototypes, A/B contact sheets, colour sampling |
| `gates.py` | no | the numeric checks |

Beside them, two fetchers and a harness: `polyhaven.py` and `ambientcg.py`
(CC0 textures, see `materials.md`) and `screenshot/` (photograph a sprite in
the running engine, below).

Everything except `rig`/`greeble` is plain Pillow + numpy, so post, comparison
and gating run in system Python and never wait on Blender.

Bootstrap it from a mod's asset scripts by walking up for the directory rather
than counting `..`, because these scripts get run three different ways
(`blender -b -P`, `python`, `exec()` in Blender's console) and only some of
them give `__file__` a real value:

```python
def _skill_scripts(start=None):
    d = os.path.abspath(start or globals().get("__file__") or os.getcwd())
    if os.path.isfile(d):
        d = os.path.dirname(d)
    while True:
        c = os.path.join(d, ".claude", "skills", "factorio-graphics", "scripts")
        if os.path.isdir(c):
            return c
        parent = os.path.dirname(d)
        if parent == d:
            raise RuntimeError("factorio-graphics scripts not found")
        d = parent

sys.path.insert(0, _skill_scripts())
```

The reference implementation of a mod using it is
`assets/pure-modules-realk/entity/beacon/` — generator, render driver,
`make_sheets.py`, `make_frozen.py`, `make_slots.py`, `make_remnant.py`.

## Iteration speed is a quality setting

Art comes out of look-fix-look cycles, so the cost of one cycle sets how good
the art gets. Measured on this machine (Ryzen 7 5800, RX 6800 XT, Blender 5.2,
the beacon at 512x640 / 96 samples):

| | |
|---|---|
| `build_scene()` from the generator | **62.9 s**, on every invocation |
| `open_mainfile(beacon.blend)` instead | **0.18 s** |
| one frame, Cycles **CPU** | 16-17 s |
| one frame, Cycles **GPU** (HIP) | 6.9-7.6 s |
| one frame, GPU + `use_persistent_data`, repeat | **2.2 s** |
| one bordered anim frame, GPU + persistent | **0.83 s** |
| denoising | ~0.4 s/frame |
| 24 samples vs 96 samples | 6.34 s vs 6.96 s |
| Workbench engine (layout check only) | 2.0 s |

Four things follow, and three of them were being left on the table:

- **Samples are almost free.** Quadrupling them cost 0.6 s. Do not lower
  samples to iterate faster; it buys nothing and costs noise.
- **Use the GPU.** `rig.use_gpu(scene)` tries OPTIX, HIP, CUDA, oneAPI in turn
  and falls back to CPU with a printed line. Never write
  `cycles.device = "GPU"` bare: with no usable compute device it falls back
  silently and you pay CPU time believing otherwise.
- **Turn on `render.use_persistent_data`.** 3.4x on repeat renders of the same
  layer. Turn it *off* around a `material_override` swap — it caches exactly
  what an override invalidates.
- **Reuse the saved `.blend` for looking, not for shipping.** 0.18 s against
  62.9 s. The generator stays the source of truth; regenerate the `.blend`
  after changing it, and never take a final render from a stale snapshot. The
  beacon driver exposes this as `--from-blend`.

Combined, the tight loop went from ~80 s to ~2.5 s.

Also worth knowing: EEVEE's engine id in Blender 5.2 is `BLENDER_EEVEE`, not
`BLENDER_EEVEE_NEXT`.

## The paint-over — the step that was missing

Wube do not ship raw renders. FFF-146: nearly every sprite goes into Photoshop
where the render is duplicated twice, the copies set to **Multiply and Screen**
with masks, *"to enforce contrast, make edges clearer, define shape of
entities better"*. FFF-432 confirms it is still true for Space Age.

`post.paint_over(image, preset)` is that step:

| operator | what it is |
|---|---|
| form contrast | whole faces pushed apart in value — the actual paint-over |
| local contrast | the Multiply/Screen pair — mid-frequency shaping, volume not sharpness |
| crevice deepen | the dark line where two parts meet |
| rim light | the bright catch along an edge facing the key sun |
| alpha tighten | Cycles' soft antialiased fringe pulled in |
| saturate / expose | small global corrections with measured targets |

**Calibrated, not chosen by eye.** Measured over opaque pixels of vanilla
source PNGs at 64 px/tile: `beacon-bottom` luminance sd **43.0**,
`beacon-top` **46.8**, `lab` **51.6**. This repo's raw beacon render measured
**31.6** — flat against every one of them, and that gap is the most reliable
"this is a render, not a Factorio sprite" signal there is. `contrast_amount
0.60` lands it at 43.4 with nothing clipped. **Target band for an entity body:
luminance sd 43-52** (`gates.contrast`).

### Luminance sd alone is not enough — check WHERE the contrast is

Hitting the sd band says how much contrast a sprite has, not what kind, and the
two are easy to confuse. Split the luminance variance into bands by differencing
successive alpha-weighted gaussians and compare **form** (>12 px) against
**grain** (<3 px):

| sprite | luminance sd | grain <3 px | form >12 px | form/grain |
|---|---|---|---|---|
| `cryogenic-plant-main` (5×5) | 0.217 | 21.3% | 36.2% | **1.70** |
| `lab` (5×5) | 0.202 | 16.0% | 52.4% | **3.27** |
| `beacon-bottom` (3×3) | 0.169 | 27.0% | 19.1% | 0.71 |
| this repo's beacon, raw render | 0.122 | 23.1% | 30.5% | 1.32 |
| the same frame after `contrast_amount 0.60` | 0.167 | 33.0% | 20.7% | **0.64** |

The raw render was already inside vanilla's range and the paint-over took it
out. `local_contrast` is an unsharp mask, so it lifts *every* frequency above
its radius; on a densely greebled sprite most of the energy sits at 1–3 px, so
it buys its sd target by converting form into sizzle. It measured correct and
looked wrong — the sprite read as uniformly busy where vanilla alternates calm
hulls against strong boundaries, which is the same thing `design-language.md`
calls "one busy hero zone against calm hulls".

`post.form_contrast()` applies the gain to the low-pass and adds the untouched
residual back, so a hull face separates from the face beside it while the
rivets on both stay where the render put them. That is what a hand paint-over
actually does. The `entity` preset now carries most of its contrast there
(`form_amount 1.45`, radius 11) with `contrast_amount` cut 0.60 → 0.35, which
lands sd 0.207 at ratio 3.31 with nothing clipped.

**A 3×3 entity legitimately measures lower** — the beacon's 0.71 is not a
defect, there simply is not room for 12 px forms on a 96 px sprite. Compare
against a vanilla entity of the same footprint.

Three rules the pass has to obey, each of which breaks it if ignored:

- **Every blur is alpha-weighted.** A plain gaussian over an RGBA sprite pulls
  transparent black in from outside the silhouette and rings the entity with a
  dark rind. Normalised convolution — `blur(rgb*a) / blur(a)` — is the only
  correct filter on a sprite with alpha.
- **Run it per frame, before packing.** Every operator has a radius; over an
  assembled sheet it bleeds each frame into its neighbour, which in game is a
  ghost of frame N appearing in frame N-1.
- **Nothing may clip.** Standard clips hard, so a contrast pass that pushes
  highlights past white destroys the specular detail it was meant to sharpen.
  Every operator is soft-limited and `post.report()` counts what landed on 255.

Presets: `entity`, `icon`, `remnant`, `frozen`. What each layer gets is a
per-mod decision — a shadow is already pure black, an additive glow layer would
be eaten by crevice deepening, and a layer carrying translucent vapour wants
`alpha_gamma=1.0` so the softness survives.

### Render passes: measured, and not worth it

The obvious next step is to feed the pass an AO and a normal buffer so crevices
darken where the geometry actually occludes. **Tested, and it does not pay at
this scale.** An AO render (material override, distance 0.35, local only)
changed the painted result by a mean of **2.0/255**, with only 3.1% of pixels
differing by more than 8 — and the AO-guided version scored slightly *worse* on
the contrast metric (sd 42.4 against 43.4, p01 14.5 against 11.0).

Two reasons, and both are structural rather than a tuning problem:

- at 64 px/tile the crevices that matter are 1-2 px wide, and a luminance
  low-pass finds those as well as a geometric one does;
- **the wear stack already puts a `ShaderNodeAmbientOcclusion` in every
  material** (`materials.md`), so the occlusion is baked into the beauty render
  before post ever sees it. A second AO term is measuring what is already there.

The `ao=` and `normal=` parameters stay on the operators in case a larger or
smoother model behaves differently. Do not add a pass pipeline for them by
default.

Two related non-wins from the same session, recorded so nobody re-runs them:

- **`cycles.denoising_use_gpu`** — 2.05 s against 2.08 s per frame. At 512x640
  the denoise is not what the frame costs. (Blender 5.2 already defaults the
  denoiser to `RGB_ALBEDO_NORMAL`, prefilter `ACCURATE`, quality `HIGH`, so the
  quality knobs are on out of the box.)
- **The compositor route to passes** is gone in Blender 5.2 anyway:
  `Scene.node_tree` is replaced by `Scene.compositing_node_group`,
  `CompositorNodeComposite` is undefined, and `CompositorNodeOutputFile` has no
  `file_slots`. A multilayer EXR would need an OpenEXR reader, which this
  machine's Python does not have. **Rendering a quantity through a
  `material_override` is the simple route** — that is how the AO test above was
  done, and it needs no compositor and no new dependency.

**What post cannot do.** Vanilla bodies measure saturation 0.30-0.38; the
beacon's palette measures 0.11 and a global saturate only reaches 0.16 before
looking artificial. The rest of that gap is that vanilla has copper, rust and
worn-paint *zones* — a material problem (`materials.md`), not a post one. Post
sharpens what the render got right; it does not add what the palette lacks.

## Alpha: the resize rule

Blender writes **straight (unassociated) alpha**. Measured on this repo's own
beacon render, 32% of partially transparent pixels carry `max(RGB) > alpha`.
So a plain `Image.resize()` averages colour across the alpha edge unweighted:
on `beacon-base.png` at 50%, mean `|dRGB|` was **75** on the antialiased
outline (max 221) against a correct resize, and on a 4x icon reduction 27-38%
of surviving pixels came out more than 8/255 wrong.

Factorio itself loads with `premul_alpha = true`, so the *files* are the right
convention — it is our own resampling that was wrong. **Use
`imaging.resize` / `imaging.scale` / `imaging.mipmap_strip`, never
`Image.resize`, on anything with an alpha channel.**

Related: crop against an **alpha floor** (`imaging.bbox_above`, default 8).
Cycles leaves a wash of alpha 1-7 across the film; it is invisible in game and
still grows the sprite and its atlas footprint.

## Look at it — the comparison gate

`SKILL.md`'s first checklist line is "opened a real vanilla PNG and compared
side by side". `vanilla.py` makes that mechanical, and it does three things
opening two PNGs cannot:

- composites an entity's **layers at their prototype shifts and scale**, so you
  are looking at what the game draws rather than at one file of several;
- puts both on the **terrain colour** they will sit on — dark structure on
  Nauvis dirt `(150,96,45)` hides and reveals completely different mistakes
  than the same sprite on white or on a transparency checker;
- renders at **game pixels and at a magnified zoom in one sheet**, because
  silhouette failures show at 1x and material failures at 3x.

```python
from factorio_render import vanilla
van  = vanilla.vanilla_panel("beacon")                     # built-in reference
ours = vanilla.compose(layers, footprint=(3, 3))           # your prototype's layers
vanilla.contact_sheet([("vanilla", van), ("ours", ours)], zooms=(1, 3)).save(out)
```

Then **open the file and look at it.** The sheet is the tool; reading it is
the gate.

`vanilla.from_data_raw(dump, name)` pulls layer specs straight out of a
`--dump-data` JSON (see the `factorio-validate` skill), which never drifts from
the prototype. `vanilla.area_vs_footprint` reports drawn size against the
entity's tiles — vanilla's beacon draws at 1.08x / 1.05x its 3x3 footprint;
anything several times its footprint is a different visual weight class from
the entity it sits beside, which is invisible in the PNG and obvious the moment
both are on ground.

## What is actually on screen — the ID render

A sprite is the only thing that ships, and a model can be full of geometry that
never reaches it. Swap every material for a flat emission carrying an index,
render one frame to **OpenEXR** (32-bit, so the index survives — an 8-bit PNG
goes through the sRGB transfer curve and quantises the low indices together),
and count pixels per index. Two things fall out that nothing else reports:

- **Buried features.** On this repo's beacon the containment well — the design
  document's whole subject, and the thing a comment in the generator described
  in detail — measured **0 visible pixels**, with its four aperture bars at
  2, 2, 2 and 0. `Dish` was a solid cylinder and the well lived inside it. The
  render looked plausible, the PNG looked plausible, and the feature had never
  once been on screen. Fixing it needed an annulus, not a lighting change.
- **Where the sprite's area actually goes.** The same pass put that one plain
  cylinder face at **8.0% of all visible pixels** — the largest and emptiest
  object in the entity, which is exactly where added detail pays. Guessing
  from the render had pointed at the wrong place twice.

It also lists geometry that costs render time for nothing: 146 of 645 objects
drew zero pixels, almost all of them rivets below the ~3 px legibility floor
(`greeble.legibility`). Read that as a hint, not an order — a rivet hidden in
the base layer may be doing its job in the frozen or remnant pass.

Count inside Blender (`img.pixels.foreach_get`) rather than reading the EXR
back with Pillow, which has no EXR reader in a default install.

**Build the scene the way the real driver does.** An analysis script that calls
`build_scene()` straight from Blender's startup file inherits the default cube,
which duly showed up owning 1.4% of the sprite and is not a real finding. The
shipping driver calls `read_factory_settings(use_empty=True)` first.

## Gates

`gates.check_all([...])` prints a table. Every band was measured off shipped
2.1 / Space Age art, and each one exists because a sprite passed visual review
and failed it:

| gate | band | why |
|---|---|---|
| `contrast` | lum sd 43-56 | raw renders land ~31 |
| `clipping` | <= 0.05% (entity body) | Standard clips hard. Icons differ — vanilla module icons measure 6.4-7.1% because their dome is *meant* to saturate; pass `max_pct=8` there |
| `crop_waste` | invisible < 60% of box | alpha 1-7 grows the sprite for nothing |
| `remnant` | lum mean 60-72 | vanilla: beacon 63.0, reactor 67.0, cryo plant 68.5 |
| `frozen_patch` | nothing opaque below lum 60; R<G<B; solid band >= faint band | dark snow paints soot on the machine; an inverted ratio is a film over the hull, not drifts on it |
| `tint_mask` | alpha median ~128, lum span >= 120 | see below |
| `shadow` | pure black, near-binary alpha | the engine tints and blends it itself |
| `footprint_gate` | tiles x 64 px exactly | catches a silently rescaled sprite |

## Tint masks have TWO requirements

`apply_tint` / `apply_module_tint` layers fail in two independent ways and it
is easy to satisfy only one:

- **Luminance.** The mask is *multiplied* by the tint, so a flat sprite can
  only ever produce a flat patch of colour. It must be a shaded greyscale
  render spanning a real range — vanilla's `beacon-module-mask-box` spans
  0-255 with mean 141.
- **Alpha.** FFF-218, verbatim: *"unless you are doing something extremely
  specific, the colour mask values should always be at 0.5 Alpha… The Alpha is
  black magic, keep it at 0.5 please"*, with the stated condition that both the
  mask and the area under it are desaturated. At full alpha the mask
  **replaces** the pixel and the machine's own shading disappears under a
  coloured decal; at 0.5 it modulates and the form shows through. Measured:
  vanilla `beacon-module-mask-box-1` median alpha **106**, max 253, nothing at
  255; `beacon-module-mask-lights-1` median **182**. This repo's masks measured
  median 255 with 76% fully opaque until it was corrected.

Not universal — vanilla's biter masks are 79% opaque. **Match the vanilla
counterpart of the thing you are masking**, and know why the number is what it
is. A `draw_as_light` sprite is not a tint mask and keeps its own alpha.

## Engine-side polish

Fields that cost one line and are easy never to notice:

- **`water_reflection`** (`EntityWithHealthPrototype`) — 23 vanilla files
  define one. It comes free when deriving from a vanilla entity; a from-scratch
  entity has none and looks wrong beside water until it does.
- **`usage` and `surface`** — sprite-atlas packing hints. Vanilla uses them
  heavily (117 x `usage = "enemy"`, 129 x `surface = "gleba"`). `usage` groups
  related sprites, `surface` groups sprites used in the same place.
- **`dice` / `dice_x` / `dice_y`** — slices a large sprite for atlas packing.
  Vanilla uses it across dozens of big sprites.
- **`allow_forced_downscale`** — lets a sprite be halved on load even at High
  sprite quality. Right for decoration, wrong for anything a player reads.
- **`fog_mask`** on a `WorkingVisualisation` — Space Age fog interaction.
- **`light`** on a `WorkingVisualisation` — a real light source, separate from
  `draw_as_glow`.
- **No normal maps for entities.** The `normal-map` sprite flag exists but only
  asteroids, platform backdrops and tile effect maps use it. Everything an
  entity's surface does has to be baked into the sprite, which is exactly why
  the paint-over matters.

## The game's own QA flags

Run against the real engine, cheap, and nothing else finds these:

```
factorio --dump-icon-sprites            every icon the game loaded, as PNGs
factorio --report-autogenerated-icon-mipmaps
factorio --log-spritesheets-to-optimize N   sheets with near-transparent noise
factorio --check-unused-prototype-data      properties the engine ignored
```

`--dump-icon-sprites` is the quick way to build a vanilla icon reference
corpus. See the `factorio-validate` skill for running the game headless
without touching this repo's `mod-list.json`, and for the
`--benchmark-graphics` screenshot harness that puts a sprite on a real map.

## Blender extensions can be installed headlessly

Blender 4.2+ has a real package manager and a CLI for it, so an add-on can be a
*declared, reproducible* dependency instead of something a human clicked once:

```
blender --command extension sync                       # refresh the catalogue
blender --command extension list                       # 1161 packages here
blender --command extension install <id> --enable
blender --command extension install-file -r <repo> --enable pkg.zip
```

Verified working on this machine. Free/open packages from the official
repository that are actually relevant, all confirmed present in the catalogue:

| id | why |
|---|---|
| `boltfactory` | parametric bolts and nuts — literally the first row of the greeble table |
| `ambientcg_material_importer` | one-click CC0 PBR materials, the second texture source beside Poly Haven |
| `hardflow` | open-source hard-surface boolean toolkit |
| `bool_tool` | booleans |
| `thebetterbaker`, `attribute_baker` | PBR / attribute baking to image |
| `CryptoMatte_ID_Color` | per-object masks in the compositor |

The catalogue has no greeble, kitbash or decal generator that is both free and
scriptable — the good ones (Random Flow, DECALmachine, KIT OPS, Sanctus) are
commercial and GUI-driven, which is the wrong shape for a headless pipeline and
an awkward fit for a GPLv3 repo. **For a scripted pipeline, write the parts
vocabulary in `bmesh` rather than buying a kit.**

## Other tools, evaluated

- **[factorio-spritter](https://github.com/fgardt/factorio-spritter)** —
  **adopted, as a packaging step.** Rust CLI, Windows binary in releases
  (v1.8.1), fetched to the git-ignored `assets/third-party/tools/spritter/`.
  `spritter optimize -r <graphics dir>` runs oxipng losslessly (lossy is opt-in
  and stays off): measured **11.7% off this mod's PNGs, 846 kB, in 20 s**.
  Verified safe the only way worth trusting — alpha came out byte-identical and
  RGB changed *only* on fully transparent pixels, which oxipng zeroes to
  compress; zero visible pixels moved, and Factorio premultiplies on load
  anyway. Its sheet-building overlaps `imaging.py` but it cannot do the shadow
  masking, tint-mask alpha or contact-shadow work, so it packages rather than
  replaces.
- **[Material Maker](https://www.materialmaker.org/) 1.7** (MIT, free) —
  **tried and dropped.** Its CLI export produced no files here across three
  configurations (`--headless`, a real GPU display driver, and `--quit-after
  600`), exiting 0 each time after printing `Exporting Material ... to ...`.
  Even working it would be a 110 MB GUI tool for a job ambientCG plus the
  procedural stack already covers, and a tool that needs a GUI to be reliable
  is the wrong shape for a headless pipeline. The zip is left in
  `assets/third-party/tools/` if anyone wants it interactively; nothing depends
  on it.
- **[G'MIC](https://gmic.eu/)** — **not adopted, and the reason matters.**
  Its filters overlap `post.py`, which is already alpha-correct and calibrated
  against vanilla, so it would add a binary dependency for no gain. It becomes
  worth fetching the day this repo has a **tiling** sprite again — a belt, a
  wall, a pipe, a terrain transition — where `fx_make_seamless` and its texture
  synthesis do something nothing here does. Not before.
- **CC0 asset sources** — Poly Haven (`scripts/polyhaven.py`) and ambientCG
  (`scripts/ambientcg.py`), both wired and both verified fetching. Also
  BlendSwap CC0 greeble packs and [awesome-cc0](https://github.com/madjin/awesome-cc0).
  Licence-check every download: this repo is GPLv3 and ships its art.
- **[snouz/factorio_free_graphics_for_modders](https://github.com/snouz/factorio_free_graphics_for_modders)**
  — catalogue of open-licence mod art, useful as calibration reference.
- **`maketx`** is bundled with Blender (`blender --command maketx`) — OIIO's
  tiled/mipmapped texture builder. Only matters if a scene becomes texture-bound,
  which at 1k photo maps it is not.
- **AI upscalers and generators: do not ship their output.** Wube retain all
  rights to the base game's assets and reserve the right to demand removal of
  derived work; the community asks mods to disclose AI art so it can be avoided.
  Nothing in this pipeline needs it — rendering at the target resolution beats
  upscaling by construction.
- Community Blender templates ([forum t=114275](https://forums.factorio.com/viewtopic.php?t=114275),
  [t=5336](https://forums.factorio.com/viewtopic.php?t=5336), PreLeyZero's
  `blender-example` mod) are where this skill's sun angles and colour
  management came from. They stop at the render; nothing published there covers
  the footprint gate, the layer split, remnants, frozen patches or the post
  pass.

## The parts vocabulary

`greeble.py` builds the things `design-language.md` says a Factorio machine is
made of, so a generator reaches "8-15 distinct kinds of functional detail"
by composing rather than by reinventing each part:

`bolt_ring` · `rivet_row` · `flange` · `pipe_run` (flanged at every bend) ·
`cable` (catenary sag) · `louvre_bank` · `radiator` · `handwheel` ·
`gauge_pod` · `junction_box` · `ladder` · `railing` · `skid_feet` ·
`placard` · `bolt_detailed`

Every builder bevels (the pointiness wear mask needs real curvature), offsets
stacked plates by `EPS` (exactly coplanar faces render **opaque black** in
Cycles), and normalises its own bounds (reversed bounds invert normals on the
mirrored half of a symmetric part).

**`legibility(size_tiles)` before modelling anything small.** It converts a
size to source and gameplay pixels and tells you what kind of detail it is
allowed to be — under ~3 px in play it is texture, not geometry, and modelling
it is work that costs render time and shows nothing. A 0.05-tile fitting is
1.6 px. A 0.2-tile one is 6.4 px: silhouette and value only, no line-work.

`bolt_detailed` uses the `boltfactory` extension for a fitting big enough to
show thread, and falls back to a flat hex head otherwise — 2736 verts of
thread on a 3 px feature is wasted either way. It carries two traps worth
knowing generally:

- **`rig.empty_scene()` disables every installed extension**, because
  `read_factory_settings` resets preferences. Pass `keep_addons=(...)` or
  re-enable on demand.
- **`hasattr(bpy.ops.mesh, "bolt_add")` is always True** — `bpy.ops` resolves
  lazily and only raises when called. Test `"bolt_add" in dir(bpy.ops.mesh)`.

## Photographing a sprite in the running engine

`scripts/screenshot/` — a probe mod plus `shoot.ps1`, which stages the mod
under test into a scratch mod directory, creates a save, runs the game with
its renderer, and collects the pictures.

```
.\shoot.ps1 -ModPath <mod> -Entity pure-beacon -Compare beacon -Module pure-speed-module -Out shots
.\shoot.ps1 -ModPath <mod> -SpecJson groups.json -Out shots
```

The quick form places a row of the entity plus a vanilla neighbour and shoots
at zoom 1 and 2, with and without alt-mode. The probe powers what it places
(an `electric-energy-interface` outside the framing), inserts modules if asked,
pins the surface to always-day and shoots at `daytime = 0` with clouds and fog
off, `anti_alias = true`.

This answers what nothing offline can: render_layer ordering between an entity
and its own shadow, `apply_module_tint` against a real module, `draw_as_light`
against real darkness, and how the sprite reads on terrain the map generator
actually produced. **Its first run showed the beacon row fusing into one
unbroken slab far more clearly than the offline composite had.**

Four things it exists to get right, each found by testing:

- **Verify by counting PNGs, never by the exit code.** A graphics mode can exit
  **0** having photographed nothing. (The known cause is a DRM check on Steam
  builds, which the dev installs don't have — `SteamAppId=427520` is still set
  as cheap insurance and simply does nothing here. The lesson generalises: a
  clean exit is not evidence a screenshot exists.)
- **Scratch write-data.** The `.lock`, the log and `script-output` all follow
  write-data, so a `config.ini` relocating it keeps the run out of the install's
  own user-data folder entirely.
- **Spread the work over ticks.** Chunk generation, placement and
  screenshotting each need the previous one finished; a screenshot requested in
  the same tick as the entity photographs empty ground.
- **Pass the spec as JSON, not generated Lua.** PowerShell unrolls
  single-element arrays, so a hand-rolled serialiser turned a one-group spec
  into the group itself and the probe iterated its fields. `ConvertTo-Json`
  plus the engine's own `helpers.json_to_table` has neither problem.

Also: `LuaEntity.minable` is read-only in 2.1.

### Shoot at night too — it is the only way to check a light layer

`shoot.ps1 -Daytimes '0,0.5'` shoots each time of day (0 noon, 0.5 midnight)
and suffixes the midnight files `-d0.5`. **A `draw_as_light` /
`blend_mode = "additive"` layer renders in the light pass and is simply absent
at noon** — and no offline composite can show it either, because the darkness
it is added to does not exist in the PNGs. A beacon core that glows after dark
is invisible in every check except this one.

Pass it as a **quoted string**, and note why the parameter is typed `[string]`
rather than `[double[]]`: Windows PowerShell binds a typed array parameter from
`-File` by taking one value and dropping the rest. `-Daytimes 0,0.5` arrives as
a single element 0.5 and `-Daytimes 0 0.5` as a single element 0, with no error
either way — the run shoots one time of day and reports success. The script
splits the string itself for that reason.

### Gates measure quantity; shape needs the eye

Worth stating plainly because it cost a round trip here. The frozen-patch gate
checks colour bands, coverage against the machine's own area, and the
solid-outweighs-faint rule — and a patch passed **every one of them** while
still reading as the machine going pale, because the snow was the right colour
in the right quantity spread evenly instead of gathered into drifts. Numbers
cannot see that. What found it was compositing the patch over the base on
Aquilo ground beside the cryogenic plant's and looking.

The same caution applies to the contrast gate: hitting luminance sd says how
much contrast there is, not where it sits (see the form/grain split above).

### `game.take_screenshot`, the parameters that matter

What the probe sets and why — useful when writing a custom spec:

| parameter | why it matters here |
|---|---|
| `position`, `surface`, `zoom` | frame the entity; zoom 1 is 32 px/tile, the size players see |
| `resolution` | up to 16384x16384 |
| `anti_alias` | renders at double resolution and downscales — the honest legibility test |
| `daytime` | pin it to noon so night tinting does not confound a colour check |
| `show_entity_info` | alt-mode overlay on or off |
| `show_gui`, `hide_clouds`, `hide_fog`, `water_tick` | remove everything that is not the sprite |

The run mechanism is `--benchmark-graphics <save> --benchmark-ticks N`, which
loads a save with the renderer, ticks events normally and quits. Plain
`--benchmark` is headless: `game.take_screenshot` silently writes nothing while
`helpers.write_file` output still appears, which looks exactly like a
screenshot bug and is not.

## Measuring what the art costs

The game logs its atlas allocation at startup — `Initial atlas bitmap size`,
one `Created an atlas bitmap (size WxH)` line per sheet, and a
`[Local Video Memory] Budget/CurrentUsage` line. Diffing those lines between a
run with and without the mod is the honest way to answer "what does our art
cost a player", and `--log-spritesheets-to-optimize N` names the sheets whose
near-transparent noise is wasting the space.
