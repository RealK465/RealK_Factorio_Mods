"""Composite a look frame on Nauvis dirt at game zoom and magnified, and print
the numbers that move this sprite.

    py -3.14 show.py <dir-holding-look.png> [--post]

Writes look-sheet.png beside it: the raw (or painted, with --post) frame at
2x game zoom and at 3x source, next to the vanilla assembling machine 3 at
the same zooms, both on the ground they sit on. Judging a sprite on a
neutral grey is how dark structure on dark ground hides its mistakes.
"""
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


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
from factorio_render import imaging, post, vanilla                # noqa: E402

GROUND = (150, 96, 45)
AM3 = vanilla.resolve("__base__/graphics/entity/assembling-machine-3/assembling-machine-3-base.png")


def stats(im, label):
    a = np.asarray(im.convert("RGBA"), np.float32)
    m = a[..., 3] >= 200
    rgb = a[..., :3][m] / 255.0
    mx, mn = rgb.max(1), rgb.min(1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    lum = (rgb @ [0.2126, 0.7152, 0.0722]) * 255
    ys, xs = np.where(m)
    print("%-10s lum %5.1f sd %5.1f | sat %.2f  >=.12 %3.0f%% | opaque %dx%d src px (%.2f x %.2f tiles)"
          % (label, lum.mean(), lum.std(), sat.mean(), 100 * (sat >= 0.12).mean(),
             xs.max() - xs.min() + 1, ys.max() - ys.min() + 1,
             (xs.max() - xs.min() + 1) / 64.0, (ys.max() - ys.min() + 1) / 64.0))


def on_ground(im, zoom):
    g = imaging.scale(im, zoom) if zoom != 1 else im
    if zoom < 1:
        pass
    bg = Image.new("RGB", g.size, GROUND)
    bg.paste(g, (0, 0), g)
    return bg


def main():
    d = Path(sys.argv[1])
    src = Image.open(d / "look.png").convert("RGBA")
    if "--post" in sys.argv:
        from make_look import POST
        src = post.paint_over(src, **POST)
        src.save(d / "look-post.png")
    am3 = Image.open(AM3).convert("RGBA")
    stats(src, "ours")
    stats(am3, "am3")
    cells = []
    for label, im in (("ours", src), ("am3", am3)):
        game = imaging.scale(im, 0.5)
        cells.append(("%s 2x game" % label, on_ground(game, 1).resize((game.width * 2, game.height * 2), Image.NEAREST)))
        cells.append(("%s 3x src" % label, on_ground(im, 1).resize((im.width * 3, im.height * 3), Image.NEAREST)))
    cw = max(c[1].width for c in cells) + 12
    ch = max(c[1].height for c in cells) + 22
    sheet = Image.new("RGB", (cw * 2, ch * 2), (24, 24, 26))
    dr = ImageDraw.Draw(sheet)
    for i, (lab, im) in enumerate(cells):
        col, row = i // 2, i % 2
        sheet.paste(im, (col * cw + 6, row * ch + 18))
        dr.text((col * cw + 6, row * ch + 4), lab, fill=(235, 235, 235))
    sheet.save(d / "look-sheet.png")
    # a tight crop of ours at 3x for reading detail
    bb = imaging.bbox_above(src, 8)
    crop = src.crop((max(bb[0] - 6, 0), max(bb[1] - 6, 0), bb[2] + 6, bb[3] + 6))
    on_ground(crop, 1).resize((crop.width * 3, crop.height * 3), Image.LANCZOS).save(d / "look-3x.png")
    print("[show] %s" % (d / "look-sheet.png"))


if __name__ == "__main__":
    main()
