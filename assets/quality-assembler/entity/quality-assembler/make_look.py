"""The settled paint-over for the Quality Assembler. Every other tool imports
POST from here, so the look-dev frames and the shipped sheets can never
disagree about it.

Wube take every render into Photoshop and hand-work contrast and edges over
it (FFF-146); `post.paint_over` is that step arithmetically, calibrated
against the shipped 2.1 sprites (references/pipeline.md).

    py -3.14 make_look.py <dir-holding-look.png>

prints the raw and painted statistics against the vanilla 3x3 targets and
runs the gates on the painted frame.
"""
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image


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


sys.path.insert(0, _skill_scripts())
from factorio_render import gates, post                     # noqa: E402

# Starting point: the stock entity preset, which was calibrated on the Pure
# beacon's raw render (sd 31.6) -- this machine's raw frame measures close to
# that. The recycler's overrides (sat 0.70, value 0.88) were for a palette
# that came in at sat 0.33 and left too bright; this one is sampled darker
# and bluer, so it starts at the preset and moves only on measurement.
POST = dict(preset="entity", form_amount=0.90, contrast_amount=0.55,
            crevice_amount=0.42, saturation=1.0, value=1.0)

TARGETS = ("vanilla 3x3 assemblers: AM3 lum 75 sd 52 sat 0.47 (96% >= .12); "
           "AM2 lum 65 sd 48 sat 0.36 (90%). gates.contrast wants lum sd 43-56.")


def stats(im):
    a = np.asarray(im, dtype=np.float32)
    m = a[..., 3] >= 200
    rgb = a[..., :3][m] / 255.0
    mx, mn = rgb.max(1), rgb.min(1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    lum = (rgb @ [0.2126, 0.7152, 0.0722]) * 255
    return dict(lum=lum.mean(), sd=lum.std(), sat=sat.mean(), sat12=100 * (sat >= 0.12).mean(),
                clip=100 * (a[..., :3][m] >= 255).mean())


def main():
    d = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    raw = Image.open(d / "look.png").convert("RGBA")
    painted = post.paint_over(raw, **POST)
    painted.save(d / "look-post.png")
    for label, im in (("raw", raw), ("painted", painted)):
        s = stats(im)
        print("%-8s lum %5.1f  sd %5.1f  sat %.2f  sat>=.12 %3.0f%%  clipped %.2f%%"
              % (label, s["lum"], s["sd"], s["sat"], s["sat12"], s["clip"]))
    print("targets  " + TARGETS)
    print("-- gates --")
    for name, fn in (("contrast", gates.contrast), ("clipping", gates.clipping),
                     ("silhouette", gates.silhouette)):
        print("  %-11s %s" % (name, fn(d / "look-post.png")))


if __name__ == "__main__":
    main()
