"""Dossier on a vanilla entity: sprites, paint fraction, emissive accent.

Phase 2 of the entity-design session needs the nearest vanilla relative's real numbers.
Sampling them by hand goes wrong in a specific, repeatable way -- see PAINT_HUE_MAX -- so
this does it once, correctly.

    python counterpart.py foundry
    python counterpart.py electromagnetic-plant

It reports measurements and does not interpret them; how to read the numbers is in
../references/reference-hunt.md, where it can be kept current. For drawn-size-vs-footprint
use factorio_render.vanilla.area_vs_footprint, which composites layers at their prototype
shifts -- measuring a raw PNG canvas here would give a second, disagreeing answer.

Reads only the pinned dev install's data/. Writes nothing.
"""

import argparse
import glob
import os
import sys

# Reuse factorio_render's data/ locator rather than re-deriving it: it is deliberately
# pinned to the install holding this repo, so a second game version on the machine cannot
# silently change the numbers underneath a design. numpy comes with it.
_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, os.pardir, os.pardir, "factorio-graphics", "scripts"))

try:
    from factorio_render import vanilla  # noqa: F401  (imported for find_data_dir)
except ImportError:
    sys.exit("factorio_render not importable -- expected it beside factorio-graphics/scripts/")

try:
    import numpy as np
    from PIL import Image
except ImportError:
    sys.exit("Pillow and numpy are required: pip install Pillow numpy")


# A machine's identity paint is a *minority* of its pixels; the majority is the oxide and
# grime substrate nearly every Factorio entity shares. Sampling the modal hue therefore
# reports that every entity in the game is orange, including the blue assembling machine 3.
# The statistic that means something is the fraction landing OUTSIDE this band.
PAINT_HUE_MAX = 60.0

# Below this saturation a pixel is grey steel, not paint of any colour.
SAT_FLOOR = 0.18
# Excludes black crevices and blown speculars, neither of which carries identity colour.
VAL_FLOOR, VAL_CEIL = 0.12, 0.97

# Emissive layers are sampled looser: they are mostly transparent, and their white-hot core
# is genuinely hueless, so it must not vote on the accent colour.
GLOW_ALPHA_FLOOR, GLOW_VAL_FLOOR, GLOW_SAT_FLOOR = 40, 0.25, 0.12

# Stride cap for the biggest animation sheets. Applied as a 2-D stride so it thins rows and
# columns alike -- a flat-index stride aliases onto gcd(step, width) columns and can sample
# an eighth of a sprite's width while looking thorough.
MAX_SAMPLES = 1_000_000

# A single-frame sprite for even a 5x5 entity is roughly 350x400 px at vanilla's 64 px/tile.
# Anything much past this is an animation sheet -- a grid of frames -- whose pixel mix is
# diluted by whatever the animation does. Worth flagging rather than dropping: the sheets
# are where the working state lives.
SHEET_PX = 1200

# Pipe stubs, connection patches and similar fragments are part of the entity but are not
# the machine, and averaging them into its palette drags the number toward bare metal. Every
# vanilla fragment measured has one dimension well under this; every machine body clears it.
FRAGMENT_PX = 100

_SIZES = {}


def size_of(path):
    """Cached (w, h). Every PNG here is asked its size 2-4 times over one run."""
    if path not in _SIZES:
        with Image.open(path) as im:
            _SIZES[path] = im.size
    return _SIZES[path]


def classify(filename):
    """Which kind of layer a vanilla PNG is, by the naming vanilla actually uses."""
    n = os.path.basename(filename).lower()
    for token, kind in (("shadow", "shadow"), ("remnant", "remnant"), ("frozen", "frozen"),
                        ("mask", "tint mask"), ("smoke", "particle"),
                        ("reflection", "reflection"),
                        # The status lamp is the standard vanilla working indicator, present
                        # on nearly every machine and green on all of them. It is emissive,
                        # but it is not the entity's own accent -- letting it vote answers
                        # "which glow band is free" with green every time. Vanilla spells it
                        # both -status-light and -lamp.
                        ("status", "status lamp"), ("lamp", "status lamp"),
                        ("light", "emissive"), ("glow", "emissive"), ("working", "emissive")):
        if token in n:
            return kind
    w, h = size_of(filename)
    if min(w, h) < FRAGMENT_PX:
        return "fragment"
    return "base"


def _hsva(path):
    """(hue_deg, sat, val, alpha) as strided float arrays. PIL's HSV is C-implemented."""
    with Image.open(path) as src:
        im = src.convert("RGBA")
    w, h = im.size
    stride = max(1, int((w * h / MAX_SAMPLES) ** 0.5))
    hsv = np.asarray(im.convert("RGB").convert("HSV"), dtype=np.float32)[::stride, ::stride]
    alpha = np.asarray(im.getchannel("A"), dtype=np.uint8)[::stride, ::stride]
    return hsv[..., 0] * (360.0 / 255.0), hsv[..., 1] / 255.0, hsv[..., 2] / 255.0, alpha


def survey_base(path):
    hue, sat, val, alpha = _hsva(path)
    opaque = alpha >= 250
    n = int(opaque.sum())
    if not n:
        return None
    painted = opaque & (sat >= SAT_FLOOR) & (val >= VAL_FLOOR) & (val <= VAL_CEIL)
    nonrust = painted & (hue >= PAINT_HUE_MAX)
    return dict(paint_pct=100.0 * int(nonrust.sum()) / n,
                substrate_pct=100.0 * int((painted & ~nonrust).sum()) / n,
                mean_sat=float(sat[opaque].mean()),
                mean_val=float(val[opaque].mean()))


def survey_glow(path):
    hue, sat, val, alpha = _hsva(path)
    keep = (alpha >= GLOW_ALPHA_FLOOR) & (val >= GLOW_VAL_FLOOR) & (sat >= GLOW_SAT_FLOOR)
    if not keep.any():
        return None
    buckets = (np.round(hue[keep] / 15.0) * 15).astype(int) % 360
    values, counts = np.unique(buckets, return_counts=True)
    order = np.argsort(-counts)[:3]
    total = int(counts.sum())
    return [(int(values[i]), 100.0 * int(counts[i]) / total) for i in order]


def band(deg):
    for limit, name in ((15, "red"), (45, "orange"), (70, "yellow"), (160, "green"),
                        (200, "cyan"), (255, "blue"), (290, "violet"), (345, "magenta")):
        if deg < limit:
            return name
    return "red"


def find_prototype(data_dir, entity):
    """file:line where the prototype declares its name, entity definitions first.

    A name matches in item.lua, recipe.lua, technology.lua and the Factoriopedia and
    tips-and-tricks simulation scripts too. The entity is the one this script is for, and
    it is not alphabetically first, so an unsorted head of the list misses it entirely.
    """
    needle = ('name = "%s"' % entity).encode("utf-8")
    hits = []
    for lua in glob.iglob(os.path.join(data_dir, "*", "prototypes", "**", "*.lua"),
                          recursive=True):
        try:
            with open(lua, "rb") as fh:
                blob = fh.read()
        except OSError:
            continue
        if needle not in blob:
            continue
        rel = os.path.relpath(lua, data_dir).replace(os.sep, "/")
        for n, line in enumerate(blob.split(b"\n"), 1):
            if needle in line:
                hits.append((0 if "/prototypes/entity/" in "/" + rel else 1, rel, n))
    hits.sort()
    return ["%s:%d" % (rel, n) for _, rel, n in hits]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("entity", help="vanilla entity name, e.g. foundry")
    args = ap.parse_args()

    data = vanilla.find_data_dir()
    roots = sorted(glob.glob(os.path.join(data, "*", "graphics", "entity", args.entity)))
    if not roots:
        near = sorted({os.path.basename(p) for p in
                       glob.glob(os.path.join(data, "*", "graphics", "entity", "*"))
                       if args.entity.split("-")[0] in os.path.basename(p)})[:12]
        sys.exit("no graphics/entity/%s under %s\nnearest names: %s"
                 % (args.entity, data, ", ".join(near) or "(none)"))

    print("entity   : %s" % args.entity)
    print("data     : %s" % data)
    for hit in find_prototype(data, args.entity)[:4]:
        print("prototype: data/%s   <- read the real fields here" % hit)

    pngs = []
    for root in roots:
        pngs.extend(sorted(glob.glob(os.path.join(root, "*.png"))))

    print("\n%-46s %-11s %9s" % ("sprite", "kind", "size"))
    bases, glows = [], []
    for p in pngs:
        kind = classify(p)
        w, h = size_of(p)
        print("%-46s %-11s %9s" % (os.path.basename(p)[:46], kind, "%dx%d" % (w, h)))
        if kind == "base":
            bases.append(p)
        elif kind == "emissive":
            glows.append(p)

    def is_sheet(p):
        w, h = size_of(p)
        return w > SHEET_PX or h > SHEET_PX

    # Single frames first: they are what "what colour is it" is asked of.
    bases.sort(key=lambda p: (is_sheet(p), "-base" not in os.path.basename(p), p))

    if bases:
        print("\n--- base layers: how much of it is PAINT, not rust ---")
        print("%-42s %8s %10s %6s %6s %6s"
              % ("sprite", "paint%", "substrate%", "sat", "val", "note"))
        for p in bases[:6]:
            s = survey_base(p)
            if s:
                print("%-42s %7.1f%% %9.1f%% %6.2f %6.2f %6s"
                      % (os.path.basename(p)[:42], s["paint_pct"], s["substrate_pct"],
                         s["mean_sat"], s["mean_val"], "sheet" if is_sheet(p) else ""))
        if any(is_sheet(p) for p in bases[:6]):
            print("Rows marked 'sheet' are grids of animation frames -- their mix is diluted")
            print("by the animation. Trust the single-frame rows for the palette.")

    if glows:
        print("\n--- emissive layers: the semantic accent colour ---")
        for p in glows[:6]:
            top = survey_glow(p)
            if top:
                print("%-46s %s" % (os.path.basename(p)[:46],
                                    "  ".join("%ddeg %s %.0f%%" % (d, band(d), pct)
                                              for d, pct in top)))


if __name__ == "__main__":
    main()
