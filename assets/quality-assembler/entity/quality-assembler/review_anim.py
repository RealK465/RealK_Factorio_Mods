"""Lay the animated layers over the base, frame by frame, so a loop can be
judged as motion rather than as a sheet.

    py -3.14 review_anim.py <frames_dir> [--frames 0,10,17,...] [--out review.png]

Composites base + anim + run + fast + glow (additive) + lamp (additive) for
each frame present, painted with the shipped POST, on Nauvis dirt, at 3x
source, in a row with the frame number; below it, tight crops of the three
places motion has to read -- the window, the compressor, the condenser --
at 6x. Frames missing a layer just skip it, so a partial `--only` render
reviews fine.
"""
import glob
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw


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


HERE = Path(__file__).resolve().parent
sys.path.insert(0, _skill_scripts())
sys.path.insert(0, str(HERE))
from factorio_render import post                            # noqa: E402
from make_look import POST                                  # noqa: E402

GROUND = (150, 96, 45)
CANVAS = (320, 352)
# tight windows in source pixels (x0, y0, x1, y1): the vessel window, the
# compressor's belt drive, the condenser fan
CROPS = {"window": (176, 130, 246, 190), "compressor": (70, 60, 140, 120),
         "condenser": (196, 200, 262, 262)}


def load(frames_dir, layer, f):
    p = os.path.join(frames_dir, layer, "f%04d.png" % f)
    return Image.open(p).convert("RGBA") if os.path.exists(p) else None


def add(base, light):
    """Additive blend of a light layer, the way the engine draws glow."""
    if light is None:
        return base
    b = np.asarray(base, np.float32)
    l = np.asarray(light, np.float32)
    a = l[..., 3:4] / 255.0
    out = b.copy()
    out[..., :3] = np.clip(b[..., :3] + l[..., :3] * a, 0, 255)
    # light over open ground still has to show: take the light's alpha where
    # the base has none (the vent puff above the dome)
    out[..., 3] = np.maximum(b[..., 3], l[..., 3])
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def painted(im):
    return post.paint_over(im, **POST) if im is not None else None


def composite(frames_dir, f, base):
    im = base.copy()
    for layer in ("anim", "run", "fast"):
        lay = painted(load(frames_dir, layer, f))
        if lay is not None:
            im = Image.alpha_composite(im, lay)
    for layer in ("glow", "lamp"):
        lay = load(frames_dir, layer, f)
        if lay is not None:
            keep = lay.convert("RGB").convert("L").point(lambda v: 255 if v >= 14 else 0)
            lay.putalpha(ImageChops.multiply(lay.getchannel("A"), keep))
            im = add(im, lay)
    return im


def on_ground(im):
    bg = Image.new("RGB", im.size, GROUND)
    bg.paste(im, (0, 0), im)
    return bg


def main():
    frames_dir = sys.argv[1]
    out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else os.path.join(frames_dir, "review.png")
    if "--frames" in sys.argv:
        frames = [int(v) for v in sys.argv[sys.argv.index("--frames") + 1].split(",")]
    else:
        frames = sorted(int(os.path.basename(p)[1:5]) for p in glob.glob(os.path.join(frames_dir, "anim", "f*.png")))
    base = painted(load(frames_dir, "base", 0))
    if base is None:
        raise SystemExit("no base frame in " + frames_dir)
    comps = [(f, composite(frames_dir, f, base)) for f in frames]
    bb = base.getbbox()
    crop = (bb[0] - 4, bb[1] - 4, bb[2] + 4, bb[3] + 4)
    cw, ch = (crop[2] - crop[0]) * 2, (crop[3] - crop[1]) * 2
    tw = sum(((c[2] - c[0]) * 5 + 6) for c in CROPS.values())
    W = max(cw * len(comps) + 8 * (len(comps) + 1), tw)
    H = ch + 30 + max((c[3] - c[1]) * 5 for c in CROPS.values()) * len(comps) + 30 * len(comps) + 20
    sheet = Image.new("RGB", (W, H), (24, 24, 26))
    dr = ImageDraw.Draw(sheet)
    x = 8
    for f, im in comps:
        g = on_ground(im.crop(crop)).resize((cw, ch), Image.NEAREST)
        sheet.paste(g, (x, 20))
        dr.text((x, 4), "frame %d" % f, fill=(235, 235, 235))
        x += cw + 8
    y = ch + 40
    for f, im in comps:
        x = 8
        dr.text((x, y - 14), "frame %d" % f, fill=(235, 235, 235))
        for name, c in CROPS.items():
            g = on_ground(im.crop(c)).resize(((c[2] - c[0]) * 5, (c[3] - c[1]) * 5), Image.NEAREST)
            sheet.paste(g, (x, y))
            dr.text((x + 2, y + 2), name, fill=(255, 255, 255))
            x += g.width + 6
        y += max((c[3] - c[1]) * 5 for c in CROPS.values()) + 30
    sheet.save(out)
    print("[review] %s (%d frames)" % (out, len(comps)))


if __name__ == "__main__":
    main()
