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


def wear_mask(path, max_bright_pct=20.0, max_survive_pct=35.0, bright=0.5):
    """The one gate that measures the MODEL rather than the finished sprite.

    Every other gate here reads the output PNG, which is why a broken edge-wear
    term shipped in this repo undetected: the sprite looked plausible, so all
    seven passed. `worn_metal()` chips paint where Geometry->Pointiness is
    high -- but pointiness is a PER-VERTEX quantity interpolated across faces,
    so a bevelled primitive, whose vertices all sit on convex edges, floods the
    whole face and the mask selects entire panels. The wear then comes from the
    noise it is multiplied by, not from the geometry: design-language.md tell
    #2, "uniform procedural noise instead of physically-placed wear", produced
    by the code written to avoid it.

    Render the term on its own -- Pointiness -> MapRange(0.53, 0.62) -> Emission
    through a `material_override` -- and pass the PNG here.

        bright%    share of the silhouette marked worn. Small and thin is what
                   chipped edges look like.
        survive%   share of that still standing after a 5x5 erosion. A thin
                   edge line vanishes; a whole flat face survives.

    Measured, same mask, same rig: a bare cube 48.6% (uniform flat grey, no
    edge signal at all), the same cube with one subdivision 1.8%, an imported
    dense mesh with a bevel 3.0%, this repo's beacon before the fix 55.0% and
    after 29.5%. The bands are a SANITY check, not a vanilla calibration --
    vanilla ships sprites, not geometry, so there is nothing to measure against.
    A dense assembly of many small parts legitimately scores higher than one
    object; treat a failure as "go and look at the mask", not as a verdict.
    """
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    vis = a[..., 3] > 0.03
    if not vis.any():
        return {"ok": False, "empty": True}
    lit = (a[..., :3].mean(axis=2) > bright) & vis
    n = int(lit.sum())
    if n == 0:
        return {"ok": False, "bright_pct": 0.0, "note": "no wear at all"}
    eroded = _erode5(lit)
    bright_pct = n / float(vis.sum()) * 100
    survive_pct = float(eroded.sum()) / n * 100
    return {"ok": bright_pct <= max_bright_pct and survive_pct <= max_survive_pct,
            "bright_pct": round(bright_pct, 1),
            "survive_pct": round(survive_pct, 1),
            "band": (max_bright_pct, max_survive_pct)}


def _erode5(mask):
    """5x5 binary erosion without a scipy dependency."""
    m = mask
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            m = m & np.roll(np.roll(mask, dy, axis=0), dx, axis=1)
    return m


def silhouette(path, max_full_pct=0.0, max_fill=0.90, min_ragged=1.05, floor=128):
    """The outline: is the sprite its own bounding box?

    Three numbers off the alpha mask, measured on every machine sprite shipped
    in 2.1 and Space Age (2026-08-30):

                        fill  ragged  full-width rows
      vanilla beacon    0.85    1.33        0%
      radar             0.66    2.19        0%
      roboport          0.74    1.85        0%
      nuclear reactor   0.72    1.14        0%
      foundry           0.58    1.63        0%
      biolab            0.83    1.37        0%
      electromag plant  0.88    1.54        0%
      -- this repo's beacon, as shipped --
      pure beacon       0.94    0.46       88%

    `full_pct` is the one that matters and it is the reason this exists.
    **Not one vanilla entity has a single scanline that crosses it from edge
    to edge**, and it is not an archetype thing -- the flat-topped platforms
    (beacon, radar, roboport, reactor) obey it exactly as the towers do. The
    Pure beacon did it on 88% of its rows, because a square deck plate
    projects to a filled square at the 45-degree rig and that one object then
    sets the whole outline. Seven other gates and a published release passed
    over it; nothing that reads colour or contrast can see it.

    The geometry to fix it by, which is not obvious: screen row is set by
    y + z, so a wall at constant x occupies every row from its minimum y+z to
    its maximum. A row is full width only when the west extreme and the east
    extreme both fall in it -- so put those two on parts whose y ranges are
    disjoint by more than the deck is thick, and the whole class of failure
    goes away.

    `fill` (silhouette area / bbox area) and `ragged` (alpha perimeter / bbox
    perimeter) are the softer companions. Defaults sit just outside the
    vanilla spread rather than at its middle: this is a floor, not a target.
    """
    a = np.asarray(Image.open(path).convert("RGBA"))[..., 3]
    m = a >= floor
    if not m.any():
        return {"ok": False, "error": "no opaque pixels"}
    ys, xs = np.nonzero(m)
    sub = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = sub.shape
    edge = np.zeros_like(sub)
    edge[:-1, :] |= sub[:-1, :] ^ sub[1:, :]
    edge[:, :-1] |= sub[:, :-1] ^ sub[:, 1:]
    full = float(sub.all(axis=1).mean() * 100)
    fill = float(sub.mean())
    ragged = float(edge.sum()) / float(2 * (w + h))
    return {"ok": full <= max_full_pct and fill <= max_fill and ragged >= min_ragged,
            "full_width_rows_pct": round(full, 1), "fill": round(fill, 2),
            "ragged": round(ragged, 2),
            "bands": (max_full_pct, max_fill, min_ragged)}


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
