"""Measure the rendered swatches and print each material against its target.

    py -3.14 measure_swatch.py <dir holding swatches.png + swatches.txt>

Reports, per material, the rendered mean RGB / luminance / saturation / hue over
opaque pixels, plus the 10th and 90th luminance percentiles -- the spread is
what decides whether a surface reads as a panel or as a card, and a mean alone
hides it.

The last block is the one that matters for the whole sprite. Vanilla machines
are ONE colour with accents: the share of chromatic pixels falling in a single
15-degree hue band measures 44% on the vanilla recycler, 48% on the chemical
plant and 54% on the electromagnetic plant, against 22% on this entity's shipped
sprite. Concentration, not saturation, is the thing to steer.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

TARGETS = {
    "olive": "vanilla recycler olive-green (96,106,57) lum 101 sat 0.47",
    "concrete": "vanilla pads sit near lum 60-75, warm not neutral",
    "copper": "hero surface -- bright, hue 15-30, sat >= 0.45",
    "scoured": "worn bright metal; bright but NOT white, lum <= 175",
}


def stats(a):
    m = a[..., 3] >= 250
    if m.sum() < 200:
        return None
    rgb = a[..., :3][m].astype(np.float32) / 255.0
    mx, mn = rgb.max(1), rgb.min(1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    lum = (rgb @ [0.2126, 0.7152, 0.0722]) * 255
    r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
    h = np.zeros(len(rgb))
    d = mx - mn
    nz = d > 1e-6
    i = (mx == r) & nz
    h[i] = ((g - b)[i] / d[i]) % 6
    i = (mx == g) & nz
    h[i] = ((b - r)[i] / d[i]) + 2
    i = (mx == b) & nz
    h[i] = ((r - g)[i] / d[i]) + 4
    h *= 60
    return dict(rgb=rgb.mean(0) * 255, lum=lum.mean(), sat=sat.mean(),
                hue=np.median(h[sat >= 0.12]) if (sat >= 0.12).any() else -1,
                p10=np.percentile(lum, 10), p90=np.percentile(lum, 90),
                grey=100 * (sat < 0.18).mean())


def main():
    d = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    meta = {}
    cells = []
    for line in open(d / "swatches.txt"):
        k, _, v = line.partition(" ")
        if k == "cell":
            i, name = v.split()
            cells.append((int(i), name))
        else:
            meta[k] = v.split()
    cols, rows = int(meta["cols"][0]), int(meta["rows"][0])
    W, H = int(meta["canvas"][0]), int(meta["canvas"][1])
    im = np.asarray(Image.open(d / "swatches.png").convert("RGBA"))
    cw, chh = W / cols, H / rows

    print("%-10s %-18s %5s %5s %5s %5s %6s %5s  %s"
          % ("material", "rendered RGB", "lum", "p10", "p90", "sat", "hue", "grey", "target"))
    for i, name in cells:
        c, r = i % cols, i // cols
        x0, x1 = int(c * cw), int((c + 1) * cw)
        y0, y1 = int(r * chh), int((r + 1) * chh)
        s = stats(im[y0:y1, x0:x1])
        if not s:
            print("%-10s  (no opaque pixels -- cell empty)" % name)
            continue
        print("%-10s (%3.0f,%3.0f,%3.0f)      %5.1f %5.0f %5.0f %5.2f %6.0f %4.0f%%  %s"
              % (name, s["rgb"][0], s["rgb"][1], s["rgb"][2], s["lum"],
                 s["p10"], s["p90"], s["sat"], s["hue"], s["grey"],
                 TARGETS.get(name, "")))


main()
