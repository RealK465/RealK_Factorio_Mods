# Materials — the workflow that stopped renders looking CG

Flat single-colour Principled BSDFs are why early renders read "simple and
unnatural". The fix is layered, *scripted* materials: the generator script
authors the shader node graph in Python, so the material is parametric,
diffable, and re-renderable — far more controllable at sprite resolution than
any image you'd regenerate. Sprites end up ~200–300 px, so texel detail barely
survives the render; what survives is tonal variation, wear, and grime.

**The reference implementation is `worn_metal()` in
`assets/pure-modules-realk/entity/beacon/beacon_gen.py`** — part of the
user-approved beacon rig. Copy it into a new generator and retune the
parameters; promote it to a shared module only when a second mod actually
needs it.

## The validated layer stack

Order matters — each layer feeds the next. All mapping uses **Object
coordinates**, so script-generated primitives need no UVs.

1. **Base mottle** — two close tones of the same paint mixed by a
   large-scale Noise. Never a single flat colour.
2. **Vertical grime streaks** — Object coords with Z squashed (×0.18) into a
   Noise, multiplied dark. The squash smears the noise downward the way
   rain-carried dirt does.
3. **Height grime** (optional) — Z gradient multiplied in, darkening skirts.
4. **Rust in crevices** — Ambient Occlusion node (Distance ~0.35) inverted,
   MAX'd with a patchy noise mask, mixed toward rust brown. AO seeds it where
   geometry meets; the noise keeps it patchy instead of uniform.
5. **Per-object jitter** — ObjectInfo→Random driving Hue (0.47–0.53) and
   Value (0.85–1.15) on the accumulated colour. Neighbouring parts sharing a
   material never render identically — its absence is the single biggest
   "CG, not hand-painted" tell against the reference sprites.
6. **Edge wear** — Geometry→Pointiness through a narrow MapRange
   (≈0.53–0.62), multiplied by fine patchy noise, mixing toward bare metal.
   **Metallic and Roughness follow the same wear mask**: chipped edges go
   bare and shiny while the paint stays dull. This is what makes bevelled
   edges catch light the way vanilla does.

Cautions:

- **Pointiness and the AO node are Cycles features** — in EEVEE they flatten
  out and the whole stack dies quietly. Entities render in Cycles anyway
  (skill body); don't preview materials in EEVEE and wonder where the wear went.
- Pointiness reads *mesh* curvature: it needs the bevelled edges to exist in
  geometry. On an unbevelled primitive the mask finds nothing.
- The final mixed colour must still match vanilla numerically — sample the
  vanilla PNG, convert sRGB→linear, and drive `color_a`/`color_b` from that
  (see "Measure vanilla, don't eyeball it" in the skill body). The wear stack
  modulates a correct base; it does not rescue a wrong one.

## Node gotchas that cost a render each

Validated on the pure-modules-realk beacon (2026-08-06); each of these produced a
wrong-looking sprite before it was understood.

- **Object coordinates on a script-generated primitive span ±0.5 whatever the
  object's scale.** `cube()` helpers make a size-1 mesh and set `obj.scale`, so
  Texture Coordinate→Object is *normalised to the object*, not to world size:
  the same procedural texture comes out coarse on a small part and stretched on
  a thin plate. Tune texture scale per material family, and expect a 0.06-thick
  deck plate to squash the texture ~16× through its thickness.
- **Layer Weight's `Facing` (and `Fresnel`) output 0 face-on and 1 at grazing.**
  So a Mix with `Facing` as Factor puts input **A** down the middle of a tube
  facing the camera and **B** at its silhouette — that is how an arc gets a
  white core with a coloured fringe. Feed it through a MapRange if the fringe
  needs to win over more of the tube than raw Fresnel gives.
- **High-contrast emissive detail on a rotating part must sample world
  `Position`, not Object.** A loop that closes on the part's rotational
  symmetry (a 4-pod ring turning 90°) stops closing the moment an
  object-space pattern rides along with it. World-space fields stand still, the
  part spins through them, and the wrap is exact — with the bonus that the
  sheen then reads as energy travelling around the coil. Low-contrast surface
  detail (grime, facet bump) still wants Object coords: it has to stay stuck to
  the surface, and the mismatch at the wrap is invisible.
- **Photo grain goes in as luminance, never as colour.** Run the diffuse
  through RGB→BW and a MapRange into ~(1±grain), then MULTIPLY that grey into
  the paint. Mixing the photo's own colour shifts the chassis tint off the
  value sampled from vanilla, which is the one thing the procedural stack
  exists to protect.
- **Weather masks want a hard cap.** A rime/dust mask at 0.3 buries the identity
  colour under pale blotches and the entity turns grey — 0.08–0.14 over an
  up-facing-normal × patchy-noise mask is enough to read as cold at 64 px/tile.
  Same instinct as wear: it is a map, not a coat of paint.
- **Voronoi Distance-to-Edge only reads as circuitry when the traces are
  hairline.** At `From Max` 0.03 the cells themselves take colour and the panel
  reads as crazy paving; ~0.012 at scale 26, with the cell interiors left a
  single flat tone, reads as etched plating.

## Emissive geometry, not emissive colour

A flush emissive disc set into a surface reads as a sticker at any brightness —
the eye gets no depth cue, so it looks painted on. Recess the emitter, put a
lipped ring and a couple of aperture bars over it, and the same material reads
as light coming out of a shaft. Likewise an emissive core sealed inside an
opaque shell renders nothing: split the shell and let the gap show the core.
Both were the difference between "plastic" and "machine" on the beacon.

## Poly Haven — CC0 photo textures and HDRIs

**Status on this rig (verified 2026-08-05):** there is **no Poly Haven add-on
and no Poly Haven MCP tool** — the connected Blender MCP is not the
ahujasid/blender-mcp build, so don't go looking for a sidebar checkbox or
`download_polyhaven_asset` tool. What *is* verified working: the public API
(no key, CC0) is reachable from Blender 5.2's Python and from system Python.
Use the bundled helper:

```
python .claude/skills/factorio-graphics/scripts/polyhaven.py search textures --categories metal
python .claude/skills/factorio-graphics/scripts/polyhaven.py info  rusty_painted_metal
python .claude/skills/factorio-graphics/scripts/polyhaven.py fetch rusty_painted_metal --res 1k
```

It is also importable (`import polyhaven; polyhaven.fetch(slug)` returns
`{map_key: Path}`) from headless generator scripts or `execute_blender_code`.
Downloads land in `assets/third-party/polyhaven/<slug>/` — **git-ignored** and
re-fetchable, so the slug recorded in the generator script is the tracked
source, not the binaries. 1k is plenty at 64 px/tile.

**When photo maps beat procedural:** large, flat, repetitive surfaces whose
photographic grain procedural noise can't fake — corrugated roofing, tread
plate, concrete aprons, chain-link — and HDRIs if experimenting with world
lighting. **When they don't:** the machine's painted body. Procedural wins
there because the tint must be sampled from vanilla and the wear stack must
sit on top; a photo's baked-in colour fights both.

**Best pattern: combine, don't replace.** Multiply the photo diffuse over the
procedural paint at a low factor (0.2–0.4) for surface grain, keep the
procedural rust/jitter/edge-wear stack on top, and re-check the sampled
chassis colour afterwards — a photo's average tint shifts it.

Wiring image maps (Cycles):

- `Diffuse` → Base Color, colour space **sRGB**.
- `Rough`, `AO`, `nor_gl` → colour space **Non-Color**.
- `nor_gl` through a **Normal Map** node into the BSDF Normal input
  (`nor_gl` is the OpenGL convention Blender expects; ignore `nor_dx`).
- `AO` **multiplied into Base Color** — Cycles has no dedicated AO input, and
  an unwired AO map silently does nothing.
- Script-generated primitives have no useful UVs: set Image Texture
  projection to **BOX** (blend ≈0.25) and feed it Texture Coordinate→Object.

Verified-available slugs worth knowing (from the `metal` category, 25 total):
`metal_plate`, `metal_plate_02`, `corrugated_iron_02`, `rusty_painted_metal`,
`green_metal_rust`, `factory_wall`, `metal_grate_rusty`, `blue_metal_plate`.

## ambientCG — the other CC0 source, and the bigger one

`scripts/ambientcg.py`, same shape as `polyhaven.py`, same no-key public API,
same git-ignored cache (`assets/third-party/ambientcg/<id>/`) with the id in
the generator as the tracked source.

```
python .claude/skills/factorio-graphics/scripts/ambientcg.py search metal
python .claude/skills/factorio-graphics/scripts/ambientcg.py fetch Metal032 --res 1K
```

The two libraries genuinely differ and it is worth knowing which to reach for.
Poly Haven's texture set is small and photographic. ambientCG runs to 2000+ and
is far stronger on exactly the flat industrial surfaces a Factorio machine is
made of — tread and diamond plate, corrugated sheet, painted and rusted metal,
concrete aprons, chain-link. Its `CorrugatedSteel*` and `Metal*` families are
the first place to look for the panel grain a procedural noise cannot fake.

Two differences that bite:

- **Map names differ.** ambientCG ships `Color` / `Roughness` / `NormalGL` /
  `AmbientOcclusion` / `Metalness`, Poly Haven ships `Diffuse` / `Rough` /
  `nor_gl` / `AO`. `ambientcg.py` accepts the friendly aliases either way.
- **Not every asset has every map** — plenty have no AO at all. Check the dict
  the fetch returns rather than assuming four files landed; an unwired AO map
  silently does nothing anyway, so a missing one is not fatal.

`NormalGL`, never `NormalDX` — GL is the convention Blender's Normal Map node
expects, exactly as with Poly Haven's `nor_gl`.
