# Item and technology icons

Read alongside `SKILL.md`. Most of that file is about entity sprites; this covers what is
different about icons. Everything here was derived by matching vanilla module icons in
Factorio 2.1 and is measured rather than recalled, but the numbers are a starting rig — the
comparison against a real vanilla PNG is still what decides.

## What does and doesn't carry over

| From SKILL.md | Applies to icons? |
|---|---|
| Measure vanilla, don't eyeball | **Yes** — more so, since colour is the whole job |
| Bevel every edge, greeble, avoid flat colour | **Yes** |
| View Transform Standard, emission ≤ ~2.2, metallic ≤ 0.45 | **Yes** |
| `ortho_scale 5.0` / 64 px per tile / footprint test plane | **No** — icons aren't on the tile grid |
| Shadow as a separate pure-black sprite, `draw_as_shadow` | **No** — see drop shadow below |
| Layer split: base / anim / shadow / status-light | **No** — an icon is one flat PNG |

## Sizes

| Kind | Logical | Shipped strip |
|---|---|---|
| Item / recipe / entity icon | 64×64 | **120×64** = 64 + 32 + 16 + 8, laid out horizontally |
| Technology icon | 256×256 | **480×256** = 256 + 128 + 64 + 32 |

Declare `icon_size = 64` (the default) or `256`; the game infers the mipmap levels from the
extra width. Vanilla module items declare no `icon_size` at all and ship 120×64.

## The camera

Icons read best a little more head-on than an entity, and vanilla views its modules
**corner-on** rather than face-on — the top face is a rhombus, not a rectangle. Getting that
wrong is the single biggest silhouette difference and no amount of colour work hides it.

A rig that matched vanilla modules:

- Orthographic, `ortho_scale` ≈ 2.55 for a ~2-unit-wide subject at 512×512, so the subject
  nearly fills the frame. Vanilla icons run edge to edge; margins read as a sticker.
- Elevation 46°, azimuth 0°, roll −6°.
- **Rotate the model, not the camera**, to get the corner-on view — about 38° about Z. Turning
  the camera instead swings the key light's direction in image space, so every recolour would
  need its lighting re-checked.
- Aim with `to_track_quat`, then apply roll about the camera's own axis. Stuffing roll into
  `rotation_euler[1]` swings the aim off target and silently crops the subject.

Render at 512 and downscale to 64 with Lanczos. Rendering at 64 directly throws away the
antialiasing that makes the icon read.

## Lighting

Much lower than the entity figures in SKILL.md. Vanilla icons carry deep near-black crevices
and a strong dark side; a hot key flattens everything to pale plastic.

| Light | Position | Energy |
|---|---|---|
| Key | upper left, `(-3.0, -1.6, 4.6)` | 3.0 |
| Fill | front right, `(2.8, -3.6, 0.7)` | 0.25 |
| Rim | back, `(1.6, 3.4, 2.6)`, cool tint | 0.45 |
| World | neutral dark | 0.05 |

Cycles, ~128 samples, denoised, `film_transparent`. EEVEE is fine for previews.

## Emission without clipping

View Transform Standard clips hard, and a glowing lens is the easiest thing in an icon to
ruin. Two rules that took several rounds to find:

- **Emit a colour whose off-channels are near zero.** A near-white cyan at strength 1.0 puts
  green and blue at 1.0 already; anything added on top — diffuse, specular, bloom — pushes red
  up too and the result is white. Vanilla's lit module domes sample at `(84,252,252)`: red
  stays at 20 while the others max out. That low red *is* the colour.
- **Kill the specular on emissive surfaces** (`Specular IOR Level` ≈ 0.12). The key's white
  highlight lifts red on its own and turns a saturated glow white regardless of emission.

## Bloom belongs after the render, not in the compositor

The glow has to extend the PNG's **alpha**, not just its colour. With `film_transparent`, an
emissive spilling into transparent pixels leaves alpha at 0, so in game the halo simply isn't
there. Vanilla's module icons carry a visible cyan haze *past* the chassis silhouette, in
pixels that are partly transparent — that only works if alpha is bloomed too.

So: render, then in Pillow extract pixels above a luminance threshold, gaussian blur them, and
add the result to both RGB and alpha. Set the threshold just above the lit chassis so the
bloom picks up the emissive parts and the bevel highlights only; below that, the whole body
hazes over.

Note the coupling: emission strength and bloom threshold have to be tuned together. A screen
that renders just under the threshold reads as painted-on rather than lit, and the fix is to
raise emission, not to lower the threshold.

## Technology icons carry a drop shadow; item icons do not

Visible in any vanilla pair. A tech icon without one reads as a sticker next to the rest of
the tech tree. Inset the subject inside the 256 box so the shadow has somewhere to fall,
offset the silhouette by roughly `(11, 13)`, blur ~7, cap the alpha around 150, and composite
it under the subject.

## Colour: one model, N tints

Vanilla builds its twelve module icons from one model re-coloured, and so should a mod. Keep a
per-type table of the measured colours and a `tint()` that reapplies them, then render the
same camera once per type. The material function must **re-apply** values to an existing
datablock rather than early-returning when it already exists, or palette edits silently do
nothing on the second run.

## Before calling an icon done

- [ ] Compared side by side with the real vanilla PNG at the same zoom, at 64 px **and** 32 px
- [ ] Silhouette and type colour still readable at 32 px
- [ ] Colours sampled from vanilla art, not from a prototype field that may not exist
- [ ] Nothing clipped to white — check the hottest pixel's red channel against vanilla's
- [ ] Bloom extends alpha, verified on a transparent background
- [ ] Tech icon has a drop shadow; item icon does not
- [ ] Output is the mipmap strip, 120×64 or 480×256, RGBA
- [ ] Renders live in `assets/<mod-name>/`, only the PNGs in the mod's `graphics/`
