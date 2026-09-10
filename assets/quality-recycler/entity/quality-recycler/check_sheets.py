"""Gate every packed sheet, in every direction.

A rotation-specific defect is invisible to a one-rotation check: every offline
metric in one mining drill's pipeline passed while all four rotations carried
the same visible fault. So each direction is measured separately, and the
per-direction overhang is measured too -- the number that decides whether this
machine covers the one placed behind it.
"""
import os
import sys

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
from factorio_render import gates                           # noqa: E402

DIRS = ("N", "E", "S", "W", "flipped-N", "flipped-E", "flipped-S", "flipped-W")
FOOTPRINT = 3
PX_PER_TILE = 64

# Measured off the shipped 2.1 sprites, per direction, 2026-09-10, from the
# FIRST OPAQUE ROW inside each cell -- not from the declared width/height:
#   chemical plant (3x3, rotatable)  0.77 / 0.61 / 0.38 / 0.30
#   vanilla recycler                 0.58 / 0.69 / 0.06 / 0.59
# Nothing vanilla ships goes past 0.77 in ANY rotation.
#
# The recycler's east sheet *declares* 0.86 and fills 0.69; the other 0.17 tiles
# are transparent padding the packer left. Read the declared box and this band
# comes out 0.09 too generous, which is exactly how this entity's own APEX got
# pushed past anything Wube ships.
VANILLA_OVERHANG = (0.06, 0.77)



# `gates.silhouette` floors raggedness at 1.05, and that floor does not survive
# being applied PER DIRECTION. Measured on the shipped 2.1 sheets, cell 0 of
# each direction's own sprite:
#
#   chemical plant   N 1.24   E 0.98   S 1.17   W 1.09
#   vanilla recycler N 1.16   E 1.12   S 1.03   W 1.10
#
# The chemical plant's east view is 0.98 and the recycler's south is 1.03 --
# both under the gate's floor, on art Wube shipped. A rotatable machine reads
# smoother from the side that shows its long flank, and the 1.14-2.19 band the
# floor came from was measured one direction per entity.
#
# So the floor here is 0.95: under the lowest vanilla rotation with a little
# room, rather than under a number no rotatable vanilla machine clears in every
# direction. Raising the machine's own east view to 1.05 would mean bolting on
# greebles to satisfy a threshold the reference art fails.
VANILLA_RAGGED_MIN = 0.95


def silhouette_per_direction(path):
    return gates.silhouette(path, min_ragged=VANILLA_RAGGED_MIN)

def overhang(path, shift_px):
    """Tiles the sprite draws past its own footprint, per edge.

    shift is in DISPLAY px (util.by_pixel, i.e. source px / 2 at scale 0.5),
    so it doubles back to source px before it can be compared with the image.
    """
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im)[..., 3]
    ys, xs = np.nonzero(a >= 8)
    if not len(ys):
        return None
    sx, sy = shift_px[0] * 2, shift_px[1] * 2
    top = (sy + ys.min() - im.height / 2) / PX_PER_TILE
    bot = (sy + ys.max() + 1 - im.height / 2) / PX_PER_TILE
    left = (sx + xs.min() - im.width / 2) / PX_PER_TILE
    right = (sx + xs.max() + 1 - im.width / 2) / PX_PER_TILE
    h = FOOTPRINT / 2.0
    return dict(north=-top - h, south=bot - h, west=-left - h, east=right - h)


def main():
    graphics = sys.argv[1]
    numbers = {}
    for raw in open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 "sheet_numbers.txt")):
        if ":" not in raw:
            continue
        key, rest = raw.split(":", 1)
        sh = rest.split("shift=util.by_pixel(")[1].split(")")[0]
        numbers[key.strip()] = tuple(float(v) for v in sh.split(","))

    worst, failures = 0.0, []
    for d in DIRS:
        base = os.path.join(graphics, "quality-recycler-%s.png" % d)
        if not os.path.exists(base):
            continue
        print("== %s" % d)
        bad = []
        for name, fn in (("contrast", gates.contrast),
                         ("clipping", gates.clipping),
                         ("silhouette", silhouette_per_direction)):
            r = fn(base)
            if not r.get("ok"):
                bad.append(name)
            print("   %-11s %s" % (name, r))
        shadow = os.path.join(graphics, "quality-recycler-%s-shadow.png" % d)
        if os.path.exists(shadow):
            print("   %-11s %s" % ("shadow", gates.shadow(shadow)))
        o = overhang(base, numbers.get("%s base" % d, (0.0, 0.0)))
        if o:
            worst = max(worst, o["north"])
            over = o["north"] > VANILLA_OVERHANG[1]
            if over:
                bad.append("overhang")
            print("   overhang    north %+.2f  south %+.2f  west %+.2f  east %+.2f%s"
                  % (o["north"], o["south"], o["west"], o["east"],
                     "  <-- OVER" if over else ""))
        if bad:
            failures.append("%s: %s" % (d, ", ".join(bad)))
    print("\nworst north overhang across directions: %.2f tiles "
          "(vanilla ships %.2f-%.2f)" % (worst, *VANILLA_OVERHANG))
    print("FAILURES: %s" % ("; ".join(failures) if failures else "none"))


main()
