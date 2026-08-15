# Crops the frozen render into graphics_set.frozen_patch and prints its Lua
# numbers.
#
#   python make_frozen.py <frames_dir> <mod_graphics_dir>
#
# Separate from make_sheets.py on purpose: the patch is one static frame off
# PB_Base, so it can be re-rendered on its own without paying for the 64-frame
# anim and arcs sheets. Same crop-and-shift maths as make_sheets, which is
# what keeps the overlay registered against beacon-base.png -- both boxes are
# measured from the same canvas centre, so the two shifts agree by
# construction rather than by hand-tuning.
#
# Also reports the numbers vanilla's own frozen patches measure, because that
# comparison is the only real check on whether the snow reads right: matching
# beacon/centrifuge/electric-furnace/lab means opaque coverage in the 8-15%
# band, a mean near (167,184,194), and caps and ice either side of it.
import os
import sys

import numpy as np
from PIL import Image

CANVAS = (512, 640)

# Measured over the four Space Age frozen patches, opaque pixels only.
VANILLA = {
    "coverage_pct": (7.9, 15.0),
    "mean_rgb": ((157, 174, 183), (196, 209, 216)),
    "cap_rgb": ((222, 229, 233), (232, 237, 239)),
    "ice_rgb": ((83, 107, 121), (149, 172, 185)),
}


def measure(img):
    px = img.load()
    w, h = img.size
    opaque = []
    any_alpha = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 8:
                any_alpha += 1
            if a >= 200:
                opaque.append((r, g, b))
    if not opaque:
        raise SystemExit("frozen render is empty -- nothing accumulated")
    n = len(opaque)
    mean = tuple(sum(c[i] for c in opaque) / n for i in range(3))
    lum = sorted((c, 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) for c in opaque)
    ordered = [c for c, _ in sorted(lum, key=lambda t: t[1])]
    q = max(1, n // 4)
    ice = tuple(sum(c[i] for c in ordered[:q]) / q for i in range(3))
    cap = tuple(sum(c[i] for c in ordered[-q:]) / q for i in range(3))
    total = w * h
    return {
        "coverage_pct": 100.0 * n / total,
        "any_alpha_pct": 100.0 * any_alpha / total,
        "mean_rgb": mean,
        "cap_rgb": cap,
        "ice_rgb": ice,
    }


def band(label, value, lo_hi):
    lo, hi = lo_hi
    if isinstance(lo, tuple):
        ok = all(lo[i] - 20 <= value[i] <= hi[i] + 20 for i in range(3))
        shown = "(%.0f,%.0f,%.0f)" % value
        want = "(%d,%d,%d)..(%d,%d,%d)" % (*lo, *hi)
    else:
        ok = lo - 3 <= value <= hi + 3
        shown = "%.1f" % value
        want = "%.1f..%.1f" % (lo, hi)
    return "  %-14s %-22s vanilla %-26s %s" % (label, shown, want, "ok" if ok else "OFF")


def against_machine(patch, out_dir):
    # The ratio that actually means something. Raw coverage over the sprite box
    # is not comparable between entities -- this beacon's box carries a lot of
    # empty sky around the pylons, vanilla's is filled corner to corner -- so
    # measure the snow against the machine it sits on. Vanilla: 12% of the
    # beacon's own opaque pixels, 20% of the lab's, roughly 35-42% counting
    # the soft fringe.
    base_path = os.path.join(out_dir, "beacon-base.png")
    if not os.path.exists(base_path):
        return None
    # Counts only -- the two crops have their own boxes and their own shifts,
    # so there is nothing to line up here.
    base = Image.open(base_path).convert("RGBA").getchannel("A")
    machine = sum(1 for v in base.getdata() if v >= 200)
    alpha = list(patch.getchannel("A").getdata())
    snow = sum(1 for v in alpha if v >= 200)
    fringe = sum(1 for v in alpha if v > 8)
    if not machine:
        return None
    return 100.0 * snow / machine, 100.0 * fringe / machine


# Vanilla's alpha, as a share of the machine's own opaque area. The shape is
# the point: solid outweighs faint. A patch with the ratio the other way up is
# a translucent film over the whole hull rather than drifts sitting on it, and
# it reads in game as the machine going pale -- which no single colour
# statistic catches, because every colour band can be in range while this is
# inverted.
ALPHA_BANDS = [(8, 60, "faint", (4.8, 10.7)), (60, 120, "veil", (3.9, 8.4)),
               (120, 200, "mid", (6.2, 11.0)), (200, 256, "solid", (11.9, 20.4))]


def alpha_bands(patch, out_dir):
    base_path = os.path.join(out_dir, "beacon-base.png")
    if not os.path.exists(base_path):
        return
    base = Image.open(base_path).convert("RGBA").getchannel("A")
    machine = sum(1 for v in base.getdata() if v >= 200)
    if not machine:
        return
    alpha = list(patch.getchannel("A").getdata())
    print("  alpha spread (%% of machine area, vanilla wants solid >= faint):")
    for lo, hi, label, want in ALPHA_BANDS:
        n = sum(1 for v in alpha if lo <= v < hi)
        pct = 100.0 * n / machine
        ok = "ok" if want[0] - 3 <= pct <= want[1] + 3 else "OFF"
        print("    %-6s %5.1f%%   vanilla %.1f..%.1f  %s" % (label, pct, want[0], want[1], ok))


def drift_alpha(img, floor=40, knee=150, gain=1.18):
    """Turn a film into drifts.

    The snow shader accumulates a long tail of very low alpha across the whole
    hull. Every colour statistic can sit in vanilla's range while that tail
    makes the patch a translucent veil over the entire machine instead of
    snow lying on it -- and in game that reads as the beacon going pale.
    Measured against the machine's own opaque area, the shipped patch put
    17.3% of it in the faint band where vanilla's four patches sit at
    4.8-10.7, and 50.6% under any alpha at all against vanilla's 35-42.

    Clipping the tail at 40 and lifting what is already solid puts every band
    back in range (faint 8.1%, veil 6.9%, mid 4.8%, solid 17.8%, any 37.5%).
    Fixing it here rather than in the shader keeps one render serving both --
    the accumulation itself is correct, it is the presentation that was soft.
    """
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    al = a[..., 3]
    out = np.where(al <= floor, 0.0, (al - floor) * (255.0 / (255.0 - floor)))
    out = np.where(out >= knee, np.minimum(255.0, out * gain), out)
    a[..., 3] = np.clip(out, 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def main():
    frames_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    src = drift_alpha(
        Image.open(os.path.join(frames_dir, "frozen", "f0000.png")).convert("RGBA"))
    bb = src.getbbox()
    if bb is None:
        raise SystemExit("frozen render is empty -- nothing accumulated")
    x0, y0 = max(bb[0] - 2, 0), max(bb[1] - 2, 0)
    x1, y1 = min(bb[2] + 2, CANVAS[0]), min(bb[3] + 2, CANVAS[1])
    # even width/height so scale=0.5 stays pixel-aligned in game
    if (x1 - x0) % 2:
        x1 += 1
    if (y1 - y0) % 2:
        y1 += 1

    patch = src.crop((x0, y0, x1, y1))
    patch.save(os.path.join(out_dir, "beacon-frozen.png"))

    cx = (x0 + x1) / 2 - CANVAS[0] / 2
    cy = (y0 + y1) / 2 - CANVAS[1] / 2
    report = ("frozen: width=%d height=%d shift=util.by_pixel(%.1f, %.1f)"
              % (x1 - x0, y1 - y0, cx / 2, cy / 2))
    print(report)

    m = measure(patch)
    print("  against vanilla's frozen patches:")
    print(band("coverage %", m["coverage_pct"], VANILLA["coverage_pct"]))
    print(band("mean rgb", m["mean_rgb"], VANILLA["mean_rgb"]))
    print(band("caps rgb", m["cap_rgb"], VANILLA["cap_rgb"]))
    print(band("ice rgb", m["ice_rgb"], VANILLA["ice_rgb"]))
    print("  any-alpha %%: %.1f (vanilla 15.9..28.8)" % m["any_alpha_pct"])
    ratio = against_machine(patch, out_dir)
    if ratio:
        print(band("snow/machine %", ratio[0], (11.9, 20.4)))
        print("  fringe/machine %%: %.1f (vanilla 35.1..41.7)" % ratio[1])
    alpha_bands(patch, out_dir)

    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "frozen_numbers.txt"), "w") as fh:
        fh.write(report + "\n")


main()
