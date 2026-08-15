"""Pixel operations for Factorio sprites, with the alpha handled correctly.

Everything a sprite goes through between Blender and the mod's graphics/
folder: resizing, cropping, packing, mipmaps, shadows. Pure Pillow + numpy,
so it runs in system Python and never needs Blender.

The one rule the whole module exists for: RGBA that came out of Blender is
straight (unassociated) alpha, and you cannot resize it directly. Measured on
this repo's own beacon render, 32% of partially transparent pixels carry
max(RGB) > alpha, and a plain Image.resize() then averages colour across the
alpha edge unweighted -- mean |dRGB| 75 on the antialiased outline (max 221)
against a correct resize. It reads as a dark rind on every soft edge, and is
worst exactly where sprites are downscaled most: icons at 512 -> 64 and the
mipmap chain under them. Factorio itself loads with premul_alpha = true, so
the *files* are right; it was our own resampling that was wrong.
"""

import numpy as np
from PIL import Image, ImageChops, ImageFilter


# --- alpha-correct resampling -------------------------------------------

def to_premul(im):
    """RGBA image -> float array in [0,1] with RGB premultiplied by alpha."""
    a = np.asarray(im.convert("RGBA"), dtype=np.float32) / 255.0
    return np.concatenate([a[..., :3] * a[..., 3:4], a[..., 3:4]], axis=-1)


def from_premul(arr):
    """Premultiplied float array -> straight-alpha RGBA image."""
    al = np.maximum(arr[..., 3:4], 1e-6)
    rgb = np.clip(arr[..., :3] / al, 0.0, 1.0)
    rgb = np.where(arr[..., 3:4] > 0, rgb, 0.0)
    out = np.concatenate([rgb, np.clip(arr[..., 3:4], 0, 1)], axis=-1)
    return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA")


def resize(im, size, resample=Image.LANCZOS):
    """Alpha-correct resize. Use instead of Image.resize on any RGBA."""
    pm = np.clip(to_premul(im), 0, 1)
    tmp = Image.fromarray((pm * 255.0 + 0.5).astype(np.uint8), "RGBA")
    small = np.asarray(tmp.resize(size, resample), dtype=np.float32) / 255.0
    return from_premul(small)


def scale(im, factor, resample=Image.LANCZOS):
    return resize(im, (max(1, round(im.width * factor)),
                       max(1, round(im.height * factor))), resample)


# --- cropping -----------------------------------------------------------

def bbox_above(im, alpha_floor=8):
    """Bounding box of pixels at or above alpha_floor.

    Cycles leaves a wash of alpha 1-7 across the film -- ash grains, edge
    antialiasing, a faint ambient term on the shadow catcher. None of it is
    visible in game and all of it grows the sprite: a 410 px wreck cropped to
    500 px purely on pixels nobody can see. Always crop against a floor.
    """
    a = np.asarray(im.convert("RGBA"))[..., 3]
    ys, xs = np.nonzero(a >= alpha_floor)
    if len(xs) == 0:
        return None
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def even_box(bb, canvas, pad=2):
    """Pad a bbox and round it to even width/height.

    scale = 0.5 halves the sprite in game, so an odd source dimension lands it
    on a half pixel and softens every edge.
    """
    if bb is None:
        raise ValueError("empty layer -- nothing above the alpha floor")
    x0, y0 = max(bb[0] - pad, 0), max(bb[1] - pad, 0)
    x1, y1 = min(bb[2] + pad, canvas[0]), min(bb[3] + pad, canvas[1])
    if (x1 - x0) % 2:
        x1 = x1 + 1 if x1 < canvas[0] else x1 - 1
    if (y1 - y0) % 2:
        y1 = y1 + 1 if y1 < canvas[1] else y1 - 1
    return (x0, y0, x1, y1)


def union_box(images, canvas, alpha_floor=8, pad=2):
    bb = None
    for im in images:
        b = bbox_above(im, alpha_floor)
        if b:
            bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]),
                                       max(bb[2], b[2]), max(bb[3], b[3]))
    return even_box(bb, canvas, pad)


def shift_by_pixel(box, canvas, sprite_scale=0.5):
    """util.by_pixel arguments for a crop box, in display pixels."""
    cx = (box[0] + box[2]) / 2 - canvas[0] / 2
    cy = (box[1] + box[3]) / 2 - canvas[1] / 2
    return cx * sprite_scale, cy * sprite_scale


# --- sheets and mipmaps -------------------------------------------------

def pack_sheet(images, box, cols=8):
    w, h = box[2] - box[0], box[3] - box[1]
    rows = (len(images) + cols - 1) // cols
    out = Image.new("RGBA", (w * cols, h * rows), (0, 0, 0, 0))
    for i, im in enumerate(images):
        out.paste(im.crop(box), ((i % cols) * w, (i // cols) * h))
    return out


def unpack_sheet(sheet_img, frame_w, frame_h, count, cols=8):
    """Split a packed sheet back into frames -- lets post run per frame."""
    out = []
    for i in range(count):
        c, r = i % cols, i // cols
        out.append(sheet_img.crop((c * frame_w, r * frame_h,
                                   (c + 1) * frame_w, (r + 1) * frame_h)))
    return out


def mipmap_strip(icon, size, levels=4):
    """Vanilla's horizontal mipmap strip: 64+32+16+8 = 120 wide for a 64 icon.

    Every level is generated from the full-size image rather than from the
    level above, so the chain never compounds resampling error.
    """
    total = sum(size >> i for i in range(levels))
    strip = Image.new("RGBA", (total, size), (0, 0, 0, 0))
    x = 0
    for i in range(levels):
        s = size >> i
        strip.alpha_composite(resize(icon, (s, s)), (x, 0))
        x += s
    return strip


# --- shadows ------------------------------------------------------------

def harden_shadow(shadow_img, base_img=None, threshold=110, blur=1.0,
                  base_alpha_cut=32):
    """Vanilla shadow sprites are pure black with essentially binary alpha.

    Thresholding removes the ambient wash Cycles leaves over the whole catcher
    plane; a 1 px blur puts the edge antialiasing back. If base_img is given,
    every shadow pixel under the building's own silhouette is erased --
    shadows composite above floor-mechanics and lower-object, so an overlap
    darkens the entity's own surface in game while looking fine in the PNGs.
    """
    a = shadow_img.convert("RGBA").getchannel("A").point(
        lambda v: 255 if v >= threshold else 0)
    if blur:
        a = a.filter(ImageFilter.GaussianBlur(blur))
    if base_img is not None:
        keep = base_img.convert("RGBA").getchannel("A").point(
            lambda v: 0 if v >= base_alpha_cut else 255)
        a = Image.composite(a, Image.new("L", a.size, 0), keep)
    out = Image.new("RGBA", shadow_img.size, (0, 0, 0, 0))
    out.putalpha(a)
    return out


def contact_shadow(base_img, offset=(3, 3), blur=2.0, strength=140, above=None):
    """A small grounding shadow derived from the sprite's own alpha.

    What vanilla does for entities whose physically correct cast shadow would
    fill the gap the design depends on (a raised deck reads raised because you
    can see ground under it). `above` clips the shadow to rows below a given
    y, so it stays under the structure instead of climbing it.
    """
    a = np.asarray(base_img.convert("RGBA"))[..., 3]
    m = Image.fromarray((a > 32).astype(np.uint8) * 255, "L")
    m = m.transform(m.size, Image.AFFINE, (1, 0, -offset[0], 0, 1, -offset[1]))
    m = m.filter(ImageFilter.GaussianBlur(blur))
    arr = np.asarray(m).astype(np.float32) * (strength / 255.0)
    if above is not None:
        arr[:above, :] = 0
    out = Image.new("RGBA", base_img.size, (0, 0, 0, 0))
    out.putalpha(Image.fromarray(arr.astype(np.uint8), "L"))
    return out


# --- checks -------------------------------------------------------------

def occlusion_diff(base_img, overlays):
    """Rows an overlay changes outside its own intended footprint.

    An overlay draws above the base and silently hides whatever was there. No
    single PNG can show it; only the composite can.
    """
    comp = base_img.convert("RGBA").copy()
    for im, pos in overlays:
        comp.alpha_composite(im.convert("RGBA"), pos)
    d = ImageChops.difference(base_img.convert("RGB"), comp.convert("RGB"))
    arr = np.asarray(d).max(axis=-1)
    return sorted(int(y) for y in np.nonzero(arr.max(axis=1) > 8)[0])


def stats(im, alpha_floor=8):
    """Luminance and alpha statistics over the visible part of a sprite."""
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    m = a[..., 3] >= alpha_floor
    if not m.any():
        return {}
    lum = (0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2])[m]
    al = a[..., 3][m]
    return {
        "px": int(m.sum()),
        "lum_mean": round(float(lum.mean()), 1),
        "lum_p01": round(float(np.percentile(lum, 1)), 1),
        "lum_p99": round(float(np.percentile(lum, 99)), 1),
        "alpha_median": int(np.median(al)),
        "alpha_max": int(al.max()),
        "pct_alpha_255": round(100.0 * float((al >= 255).mean()), 1),
    }
