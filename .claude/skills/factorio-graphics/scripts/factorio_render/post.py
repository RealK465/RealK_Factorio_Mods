"""The paint-over pass -- the step between Blender and the spritesheet.

Wube do not ship raw renders. FFF-146: nearly every sprite is taken into
Photoshop, duplicated twice, the copies set to Multiply and Screen with
masks, "to enforce contrast, make edges clearer, define shape of entities
better", and FFF-432 says the same is still true for Space Age. A render that
skips this reads soft and CG next to vanilla no matter how good the lighting
was -- it is listed as failure tell #9 in references/design-language.md.

This module is that step, done arithmetically rather than by hand:

  local contrast   the Multiply/Screen pair -- mid-frequency shaping that
                   makes forms read as volumes instead of a smooth gradient
  crevice deepen   the dark line where two parts meet
  rim light        the bright catch along an edge facing the key sun
  alpha tighten    Cycles' 2 px antialiased fringe pulled in to a vanilla-
                   crisp silhouette

Two properties everything here has to preserve, and both are easy to break:

* **Every blur is alpha-weighted.** A plain gaussian over an RGBA sprite pulls
  transparent black in from outside the silhouette and lays a dark rind round
  the whole entity. Normalised convolution -- blur(rgb*a) / blur(a) -- is the
  only correct way to filter a sprite with an alpha channel.
* **Nothing may clip.** Factorio needs View Transform Standard, which clips
  hard at 1.0, so a contrast pass that pushes highlights past white destroys
  exactly the specular detail it was meant to sharpen. Every operator here is
  soft-limited and `report()` counts what landed on 255.

`crevice_deepen` and `rim_light` accept an AO and a normal pass. **Measured on
this rig, neither helps** — see "Render passes: measured, and not worth it" in
`references/pipeline.md`. The luminance-derived masks are as good or better at
64 px/tile, because the crevices are 1-2 px wide and the wear stack already
puts an AO node in every material. The parameters stay because a different
model at a different scale might benefit; the defaults do not use them.
"""

import numpy as np
from PIL import Image

try:
    from scipy.ndimage import gaussian_filter as _gauss
except ImportError:  # pragma: no cover - scipy is expected, PIL is the fallback
    _gauss = None
    from PIL import ImageFilter


# Key sun is upper-left (vanilla-measured: assembling-machine-1-shadow is
# shifted +44.5 px in X, so shadows fall right). In image space that is
# -x, -y.
KEY_DIR = (-0.72, -0.69)

# Calibrated against the shipped 2.1 art rather than chosen by eye. Measured
# over opaque pixels of vanilla source PNGs at 64 px/tile:
#
#   beacon-bottom  lum sd 43.0   sat 0.377
#   beacon-top     lum sd 46.8   sat 0.166
#   lab            lum sd 51.6   sat 0.296
#
# The beacon's own raw render measured sd 31.6 / sat 0.110 -- flat and grey
# against every one of those. contrast_amount 0.60 lands it at sd 43.4, i.e.
# vanilla beacon-bottom's own figure, with nothing clipped. **Target band for
# an entity body: lum sd 43-52.**
#
# Saturation is the honest limit of a post pass: 1.20 moves 0.110 -> 0.163 and
# a global saturate cannot go further without looking artificial, because the
# remaining gap is that vanilla has copper/rust/paint zones our palette does
# not. That is a material fix (references/materials.md), not a post fix.
PRESETS = {
    # Entity sprites: seen at 32-64 px/tile in play, on dark ground, next to
    # vanilla neighbours. Wants real mid-frequency shaping.
    #
    # `form_amount` carries most of the contrast and `contrast_amount` was cut
    # from 0.60 to match. The old preset hit its luminance-sd target purely
    # through the unsharp, which measured well and looked wrong: it lifted
    # 1-2 px grain at the expense of form, taking this repo's beacon from a
    # form/grain energy ratio of 1.32 in the raw render down to 0.64, where
    # every vanilla 5x5 entity measures 1.70 (cryogenic plant) to 3.27 (lab).
    # These values put this repo's beacon at luminance sd 54.5 with a ratio of
    # 2.90 and 0.005% clipped -- just under the cryogenic plant's 55.2 and well
    # above the lab's 51.6, so inside `gates.contrast`'s 43-56 band rather than
    # over the top of it, which 1.45 was.
    "entity": dict(form_radius=11.0, form_amount=1.25,
                   contrast_radius=7.0, contrast_amount=0.35,
                   crevice_radius=1.8, crevice_amount=0.36,
                   rim_amount=0.26, rim_radius=1.2,
                   # 1.0, not the old 1.20: form_contrast pushes values apart
                   # and chroma rides along with them, so a post-hoc boost on
                   # top double-counts. Colour belongs in the material, where
                   # it can be matched to a sampled vanilla value.
                   alpha_gamma=1.18, saturation=1.0, value=1.0),
    # Icons live at 32-64 px total and are already rendered with a harder
    # key; they need edge definition more than volume shaping.
    "icon": dict(form_radius=5.0, form_amount=0.55,
                 contrast_radius=4.0, contrast_amount=0.42,
                 crevice_radius=1.2, crevice_amount=0.30,
                 rim_amount=0.22, rim_radius=0.9,
                 alpha_gamma=1.10, saturation=1.10, value=1.0),
    # A wreck is burnt and unlit. Vanilla's sit at mean luminance 63.0
    # (beacon), 67.0 (nuclear reactor), 68.5 (cryogenic plant) over opaque
    # pixels; this mod's measured 78 before `value` existed, which reads as a
    # lit pile of scrap rather than a burnt one. 0.85 lands it at 65.5.
    "remnant": dict(form_radius=9.0, form_amount=0.80,
                    contrast_radius=6.0, contrast_amount=0.30,
                    crevice_radius=1.6, crevice_amount=0.32,
                    rim_amount=0.0, rim_radius=1.0,
                    alpha_gamma=1.10, saturation=1.0, value=0.85),
    # Frozen patches draw *over* the machine and must never go dark: no
    # crevice work, no rim, just a little shaping.
    "frozen": dict(contrast_radius=6.0, contrast_amount=0.18,
                   crevice_radius=1.5, crevice_amount=0.0,
                   rim_amount=0.0, rim_radius=1.0,
                   alpha_gamma=1.0, saturation=1.0, value=1.0),
}


# --- helpers ------------------------------------------------------------

def _blur(arr, radius):
    if radius <= 0:
        return arr
    if _gauss is not None:
        if arr.ndim == 3:
            return np.dstack([_gauss(arr[..., i], radius, mode="nearest")
                              for i in range(arr.shape[2])])
        return _gauss(arr, radius, mode="nearest")
    im = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(radius))).astype(np.float32) / 255.0


def alpha_blur(rgb, alpha, radius):
    """Normalised convolution: blur that ignores what is outside the sprite.

    Without this, every filter in this module would drag transparent black
    inward and ring the entity with a dark halo.
    """
    if radius <= 0:
        return rgb
    a = alpha[..., None]
    num = _blur(rgb * a, radius)
    den = _blur(a, radius)
    return np.where(den > 1e-4, num / np.maximum(den, 1e-4), rgb)


def _lum(rgb):
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def _soft_clip(x, knee=0.86):
    """Compress above `knee` instead of clipping, so highlights keep hue.

    Standard clips hard; anything this pass pushes past 1.0 would come back
    as flat white and take the colour with it.
    """
    out = np.where(x <= knee, x,
                   knee + (1.0 - knee) * np.tanh((x - knee) / max(1e-6, 1.0 - knee)))
    return np.clip(out, 0.0, 1.0)


def _load(im):
    a = np.asarray(im.convert("RGBA"), dtype=np.float32) / 255.0
    return a[..., :3], a[..., 3]


def _save(rgb, alpha):
    out = np.concatenate([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)[..., None]], axis=-1)
    return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA")


# --- the operators ------------------------------------------------------

def local_contrast(rgb, alpha, radius=7.0, amount=0.42):
    """The Multiply/Screen pair: push mid-frequency detail away from the local
    mean. Volume, not sharpness -- a large radius is the point."""
    if amount <= 0:
        return rgb
    low = alpha_blur(rgb, alpha, radius)
    return _soft_clip(rgb + (rgb - low) * amount)


def form_contrast(rgb, alpha, radius=10.0, amount=0.55, pivot=None):
    """Push whole FORMS apart in value, leaving fine detail exactly as rendered.

    `local_contrast` below is an unsharp mask, so it lifts every frequency
    ABOVE its radius -- on a densely greebled sprite that means it buys total
    contrast by converting form energy into 1-2 px grain. Measured on this
    repo's beacon: the raw render carried a form(>12 px)/grain(<3 px) variance
    ratio of 1.32, already inside vanilla's range, and the `entity` preset's
    unsharp pass took it to 0.64. Vanilla 5x5 entities measure 1.70
    (cryogenic plant) and 3.27 (lab); nothing shipped measures below 0.7.

    This applies the gain to the low-pass and adds the untouched residual back,
    so a hull face separates from the hull face beside it while the rivets on
    both stay where the render put them. That is what Wube's Photoshop
    paint-over actually does -- whole faces darkened and lightened by hand,
    not an edge filter.
    """
    if amount <= 0:
        return rgb
    low = alpha_blur(rgb, alpha, radius)
    detail = rgb - low
    m = alpha > 0.5
    if pivot is None:
        pivot = float(np.median(_lum(low)[m])) if m.any() else 0.5
    lifted = low + (low - pivot) * amount
    return _soft_clip(np.clip(lifted, 0.0, None) + detail)


def crevice_deepen(rgb, alpha, radius=1.8, amount=0.34, ao=None):
    """Darken where parts meet. With an AO pass this is physical; without one
    it falls back to the small-scale luminance low-pass, which finds the same
    seams in practice because they are the dark thin features."""
    if amount <= 0:
        return rgb
    if ao is not None:
        occ = np.clip(1.0 - ao, 0.0, 1.0)
    else:
        L = _lum(rgb)
        low = alpha_blur(L[..., None], alpha, radius)[..., 0]
        occ = np.clip((low - L) * 3.0, 0.0, 1.0)
    return rgb * (1.0 - occ[..., None] * amount)


def rim_light(rgb, alpha, amount=0.26, radius=1.2, direction=KEY_DIR, normal=None):
    """The bright catch vanilla has along every edge that faces the sun.

    Bevelled geometry produces this in the render, but at 64 px/tile it is
    one or two pixels wide and the render's antialiasing halves it. Adding it
    back in post is what makes edges read at gameplay zoom.
    """
    if amount <= 0:
        return rgb
    if normal is not None:
        facing = np.clip(normal[..., 0] * direction[0] + normal[..., 1] * -direction[1], 0, 1)
        edge = facing
    else:
        L = alpha_blur(_lum(rgb)[..., None], alpha, radius)[..., 0]
        gy, gx = np.gradient(L)
        # gradient points uphill in value; an edge lit from the key faces the
        # key when the brightness increases towards it
        edge = np.clip(-(gx * direction[0] + gy * direction[1]) * 6.0, 0.0, 1.0)
    edge = edge * alpha
    return _soft_clip(rgb + edge[..., None] * amount)


def tighten_alpha(alpha, gamma=1.18):
    """Pull Cycles' soft antialiased fringe in.

    gamma > 1 shrinks partial coverage towards transparent, which crisps the
    silhouette; too much and the sprite aliases, so this stays gentle.
    """
    if gamma == 1.0:
        return alpha
    return np.clip(alpha, 0, 1) ** gamma


def expose(rgb, amount=1.0):
    """A flat multiplier on the lit result.

    Not a substitute for lighting the scene right -- but a wreck, a frozen
    patch or an icon has a measured luminance vanilla holds it to, and closing
    a 13-point gap here beats re-tuning a validated rig for one output.
    """
    if amount == 1.0:
        return rgb
    return _soft_clip(rgb * amount)


def saturate(rgb, amount=1.04):
    if amount == 1.0:
        return rgb
    L = _lum(rgb)[..., None]
    return _soft_clip(L + (rgb - L) * amount)


# --- the pass -----------------------------------------------------------

def paint_over(im, preset="entity", ao=None, normal=None, **overrides):
    """Run the full pass over one frame. Never run it on a packed sheet --
    every filter here has a radius and would bleed one frame into the next."""
    cfg = dict(PRESETS[preset])
    cfg.update(overrides)
    rgb, alpha = _load(im)
    if not (alpha > 0).any():
        return im.copy()

    rgb = crevice_deepen(rgb, alpha, cfg["crevice_radius"], cfg["crevice_amount"], ao)
    rgb = form_contrast(rgb, alpha, cfg.get("form_radius", 10.0),
                        cfg.get("form_amount", 0.0))
    rgb = local_contrast(rgb, alpha, cfg["contrast_radius"], cfg["contrast_amount"])
    rgb = rim_light(rgb, alpha, cfg["rim_amount"], cfg["rim_radius"], normal=normal)
    rgb = saturate(rgb, cfg["saturation"])
    rgb = expose(rgb, cfg.get("value", 1.0))
    out_a = tighten_alpha(alpha, cfg["alpha_gamma"])
    # nothing outside the silhouette may pick up colour
    rgb = np.where(out_a[..., None] > 0, rgb, 0.0)
    return _save(rgb, out_a)


def report(before, after, alpha_floor=8):
    """What the pass actually did, in numbers. Clipping is the thing to
    watch: any growth in `clipped_pct` is detail turned into flat white."""
    def m(im):
        a = np.asarray(im.convert("RGBA"), dtype=np.float32)
        vis = a[..., 3] >= alpha_floor
        if not vis.any():
            return {}
        L = _lum(a[..., :3] / 255.0)[vis]
        return {
            "lum_mean": round(float(L.mean() * 255), 1),
            "lum_sd": round(float(L.std() * 255), 1),
            "lum_p01": round(float(np.percentile(L, 1) * 255), 1),
            "lum_p99": round(float(np.percentile(L, 99) * 255), 1),
            "clipped_pct": round(float((a[..., :3][vis] >= 255).mean() * 100), 2),
            "visible_px": int(vis.sum()),
        }
    b, a = m(before), m(after)
    return {"before": b, "after": a,
            "d_contrast": round(a.get("lum_sd", 0) - b.get("lum_sd", 0), 1),
            "d_mean": round(a.get("lum_mean", 0) - b.get("lum_mean", 0), 1),
            "d_clipped": round(a.get("clipped_pct", 0) - b.get("clipped_pct", 0), 2)}
