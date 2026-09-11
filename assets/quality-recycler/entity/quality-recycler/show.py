"""Paint over a look-dev render, composite it on Nauvis, and measure it.

    py -3.14 show.py <renders/review subdir> <tag> <out.png> [--dirs NESW]

Writes `<tag>-<dir>-post.png` beside the raw frames and one contact sheet at
2x and 4x game zoom, then prints the four statistics that have actually moved
this sprite, each against the vanilla number it is aimed at:

  quarter spread   mean luminance of the top quarter minus the bottom quarter.
                   This is LIGHT DIRECTION, and it is what a flat-reading
                   sprite is missing. Vanilla recycler 27.7, chemical plant
                   48.5; a sprite near 18 reads as mush at gameplay zoom
                   however good its overall contrast is.
  local sd         mean 5 px luminance sd at GAME pixels. This is NOISE.
                   Vanilla recycler 29.2 with 56% of the body above 25,
                   chemical plant 27.1 / 44%. Above that band, added detail is
                   subtracting.
  luminance sd     the whole-sprite figure `gates.contrast` bands at 43-56.
  grey             fraction below saturation 0.18. Vanilla recycler 31%,
                   chemical plant 12%.

POST comes from make_look, so this and the shipped sheets can never disagree
about the paint-over -- which they did once, and the measurement that followed
said a change had done nothing when it had simply not been applied.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import uniform_filter

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[3] / ".claude" / "skills" / "factorio-graphics" / "scripts"))

from factorio_render import imaging, post                    # noqa: E402
from make_look import POST                                   # noqa: E402

GROUND = (150, 96, 45)
SCRATCH = Path(sys.argv[3]).parent if len(sys.argv) > 3 else HERE


def measure(im, label):
    a = np.asarray(im.convert("RGBA"), np.float32)
    m = a[..., 3] >= 200
    ys, xs = np.where(m)
    y0, y1 = ys.min(), ys.max()
    L = a[..., :3] @ [0.2126, 0.7152, 0.0722]
    q = []
    for k in range(4):
        lo, hi = y0 + (y1 - y0) * k // 4, y0 + (y1 - y0) * (k + 1) // 4
        sel = m[lo:hi + 1]
        q.append(L[lo:hi + 1][sel].mean() if sel.any() else 0.0)
    g = imaging.scale(im.convert("RGBA"), 0.5)
    ga = np.asarray(g, np.float32)
    gm = ga[..., 3] >= 200
    gl = ga[..., :3] @ [0.2126, 0.7152, 0.0722]
    mu = uniform_filter(gl, 5)
    sd = np.sqrt(np.maximum(uniform_filter(gl * gl, 5) - mu * mu, 0))[gm]
    rgb = a[..., :3][m] / 255.0
    mx, mn = rgb.max(1), rgb.min(1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    print("%-10s top/bot %5.1f/%5.1f spread %5.1f | local sd %5.1f busy %4.1f%% "
          "| lum sd %5.1f | grey %4.1f%% | %dx%d screen px"
          % (label, q[0], q[3], q[0] - q[3], sd.mean(), 100 * (sd > 25).mean(),
             L[m].std(), 100 * (sat < 0.18).mean(),
             (xs.max() - xs.min() + 1) // 2, (y1 - y0 + 1) // 2))


def main():
    d = HERE / "renders" / "review" / sys.argv[1]
    tag = sys.argv[2]
    out_path = Path(sys.argv[3])
    dirs = sys.argv[sys.argv.index("--dirs") + 1] if "--dirs" in sys.argv else "NESW"

    cells = []
    for k in dirs:
        raw = Image.open(d / ("%s-%s.png" % (tag, k))).convert("RGBA")
        painted = post.paint_over(raw, **POST)
        painted.save(d / ("%s-%s-post.png" % (tag, k)))
        measure(painted, "ours " + k)
        game = imaging.scale(painted, 0.5)
        for zoom in (2, 4):
            im = imaging.scale(game, zoom, resample=Image.NEAREST)
            bg = Image.new("RGB", im.size, GROUND)
            bg.paste(im, (0, 0), im)
            cells.append(("%s %dx" % (k, zoom), bg))
    print("targets   vanilla recycler spread 27.7 local sd 29.2 busy 56%% "
          "lum sd 44.5 grey 31%% 70x144 | chem plant 48.5 / 27.1 / 44%% / 50.4 "
          "/ 12%% / 93x138")

    cw = max(c[1].width for c in cells) + 10
    ch = max(c[1].height for c in cells) + 24
    sheet = Image.new("RGB", (cw * len(dirs), ch * 2), (24, 24, 26))
    dr = ImageDraw.Draw(sheet)
    for i, (lab, im) in enumerate(cells):
        col, row = i // 2, i % 2
        sheet.paste(im, (col * cw + 5, row * ch + 18))
        dr.text((col * cw + 5, row * ch + 4), lab, fill=(235, 235, 235))
    sheet.save(out_path)
    print("[show] %s" % out_path)


main()
