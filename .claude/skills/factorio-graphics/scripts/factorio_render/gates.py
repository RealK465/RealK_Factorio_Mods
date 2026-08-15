"""Numeric gates -- the checks that catch what looking cannot.

Every band here was measured off the shipped 2.1 / Space Age art, and every
one of them exists because a sprite passed visual review and failed it. Run
them before calling anything done; `check_all` prints a table.

They are deliberately cheap and side-effect free, so there is no reason to
skip one.
"""

import numpy as np
from PIL import Image

from . import imaging


def _visible(im, floor=8):
    a = np.asarray(im.convert("RGBA"), dtype=np.float32)
    m = a[..., 3] >= floor
    return a, m


def _lum(a):
    return a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722


def contrast(path, lo=43.0, hi=56.0):
    """Entity body: luminance sd in vanilla's band.

    Measured on vanilla source art at 64 px/tile -- beacon-bottom 43.0,
    beacon-top 46.8, lab 51.6. A raw Cycles render of a well-modelled machine
    lands around 31, which is the single most reliable "this is a render, not
    a Factorio sprite" signal. The paint-over pass exists to close it.
    """
    a, m = _visible(Image.open(path))
    sd = float(_lum(a[..., :3])[m].std())
    return {"ok": lo <= sd <= hi, "lum_sd": round(sd, 1), "band": (lo, hi)}


def clipping(path, max_pct=0.05):
    """Nothing may sit on 255. View Transform Standard clips hard, so a
    clipped channel is colour that has been thrown away, not brightness.

    The 0.05% default is an ENTITY BODY figure. Icons are different and the
    difference is deliberate: their glowing dome is meant to saturate, and
    vanilla's own module icons measure 6.4-7.1% clipped where its beacon icon
    measures 0.24%. Pass `max_pct=8` for an icon with an emissive, and keep
    the tight default for anything that is only lit, never emitting.
    """
    a, m = _visible(Image.open(path))
    pct = float((a[..., :3][m] >= 255).mean() * 100)
    return {"ok": pct <= max_pct, "clipped_pct": round(pct, 3)}


def crop_waste(path, floor=8):
    """Share of the sprite's own box that is below the visibility floor.

    Ash grains and antialiasing at alpha 1-7 are invisible in game and still
    grow the sprite and its atlas footprint.
    """
    a = np.asarray(Image.open(path).convert("RGBA"))[..., 3]
    total = a.size
    invisible = int((a < floor).sum())
    return {"ok": invisible / total < 0.6, "invisible_pct": round(100 * invisible / total, 1)}


def remnant(path, lo=60.0, hi=72.0):
    """A wreck is burnt and unlit. Vanilla: cryogenic plant 67.1, nuclear
    reactor 65.8, beacon 62.9 mean luminance over opaque pixels. Re-materialling
    a model with the entity's own validated rig measured 93 and read as a lit
    pile of scrap."""
    a, m = _visible(Image.open(path), floor=200)
    mean = float(_lum(a[..., :3])[m].mean())
    return {"ok": lo <= mean <= hi, "lum_mean": round(mean, 1), "band": (lo, hi)}


def frozen_patch(path, base_path=None):
    """Aquilo frost overlay. Three things, all measured across the four
    vanilla patches, and the third is the one that gets inverted silently:

      * nothing opaque below luminance 60 (the patch draws OVER the machine,
        so dark snow paints soot blotches on it);
      * cool blue-white, R < G < B;
      * the SOLID band must outweigh the faintest band -- vanilla is drifts
        sitting on the hull, not a translucent film over all of it.
    """
    a, m = _visible(Image.open(path))
    opaque = a[..., 3] >= 200
    lum = _lum(a[..., :3])
    out = {}
    if opaque.any():
        out["lum_min"] = round(float(lum[opaque].min()), 1)
        out["lum_p01"] = round(float(np.percentile(lum[opaque], 1)), 1)
        rgb = a[..., :3][opaque].mean(axis=0)
        out["mean_rgb"] = tuple(int(v) for v in rgb.round())
        out["cool"] = bool(rgb[0] < rgb[1] < rgb[2])
    solid = float((a[..., 3] >= 200).sum())
    faint = float(((a[..., 3] >= 8) & (a[..., 3] < 80)).sum())
    out["solid_px"], out["faint_px"] = int(solid), int(faint)
    out["solid_outweighs_faint"] = solid >= faint
    if base_path:
        b = np.asarray(Image.open(base_path).convert("RGBA"))[..., 3]
        area = float((b >= 8).sum())
        if area:
            out["solid_pct_of_machine"] = round(100 * solid / area, 1)
            out["any_pct_of_machine"] = round(100 * float((a[..., 3] >= 8).sum()) / area, 1)
    out["ok"] = (out.get("lum_min", 999) >= 60 and out.get("cool", False)
                 and out["solid_outweighs_faint"])
    return out


def tint_mask(path, target_alpha=128, tolerance=45, min_lum_span=120):
    """apply_*_tint layers. Two independent failures:

      alpha at 255 -- the mask replaces the pixel instead of modulating it,
      and the machine's shading disappears under a flat coloured decal.
      FFF-218 asks modders to keep colour-mask alpha at 0.5.
      Vanilla beacon-module-mask-box: median 106, max 253, none at 255.

      flat luminance -- the mask is multiplied by the tint, so a flat sprite
      can only produce a flat patch of colour. Vanilla spans 0-255.
    """
    a, m = _visible(Image.open(path))
    al = a[..., 3][m]
    lum = _lum(a[..., :3])[m]
    med = float(np.median(al))
    span = float(lum.max() - lum.min())
    return {
        "ok": abs(med - target_alpha) <= tolerance and span >= min_lum_span,
        "alpha_median": round(med),
        "pct_alpha_255": round(100 * float((al >= 255).mean()), 1),
        "lum_span": round(span, 1),
        "lum_mean": round(float(lum.mean()), 1),
    }


def shadow(path, max_soft_pct=8.0):
    """Vanilla shadow sprites are pure black with essentially binary alpha --
    the engine tints and blends them itself, so a soft grey gradient is the
    game's job, not the sprite's."""
    a = np.asarray(Image.open(path).convert("RGBA"))
    vis = a[..., 3] >= 8
    if not vis.any():
        return {"ok": False, "empty": True}
    soft = float(((a[..., 3] > 24) & (a[..., 3] < 231)).sum()) / float(vis.sum())
    black = float((a[..., :3][vis] <= 8).all(axis=-1).mean())
    return {"ok": soft * 100 <= max_soft_pct * 4 and black > 0.95,
            "soft_pct": round(soft * 100, 1), "pure_black_pct": round(black * 100, 1)}


def check_all(items):
    """items: list of (label, callable) -> prints a table, returns all-ok."""
    ok = True
    for label, fn in items:
        try:
            r = fn()
        except Exception as exc:            # a gate must never mask a failure
            print("  %-28s ERROR %s" % (label, exc))
            ok = False
            continue
        mark = "ok  " if r.get("ok") else "FAIL"
        ok = ok and bool(r.get("ok"))
        detail = " ".join("%s=%s" % (k, v) for k, v in r.items() if k != "ok")
        print("  %-28s %s  %s" % (label, mark, detail))
    return ok


PX_PER_TILE = 64

def footprint_gate(png_path, tiles, alpha_floor=128, tolerance=1):
    """The one gate that catches a rescaled sprite.

    Render a plane the size of the entity's tile footprint; it must come out
    square at exactly tiles x 64 px. The ground is drawn top-down while
    buildings are pseudo-3D, so a naive 45-degree pitch foreshortens it --
    PIXEL_ASPECT_X is the compensation and this is what proves it still holds.
    """
    a = np.asarray(Image.open(png_path).convert("RGBA"))[..., 3]
    ys, xs = np.nonzero(a >= alpha_floor)
    w, h = int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)
    want_w, want_h = tiles[0] * PX_PER_TILE, tiles[1] * PX_PER_TILE
    ok = abs(w - want_w) <= tolerance and abs(h - want_h) <= tolerance
    return {"ok": ok, "measured": (w, h), "expected": (want_w, want_h)}
