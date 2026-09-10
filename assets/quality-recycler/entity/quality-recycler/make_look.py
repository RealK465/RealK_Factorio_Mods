"""Paint-over, gates and the vanilla A/B for the Quality Recycler look frame.

Run after quality_recycler_gen.py has written look.png:

    py -3.14 make_look.py <dir-holding-look.png>

Wube take every render into Photoshop and hand-work contrast and edges over it
(FFF-146); `post.paint_over` is that step arithmetically, and a raw render
reads soft and CG beside vanilla however good the lighting was.

POST below overrides two of the stock "entity" preset's values, and both are
measurements against the shipped 2.1 sprites:

  saturation 0.72  form_contrast pushes values apart and chroma rides out with
                   them. The preset was tuned on the Pure beacon, whose raw
                   render came in at saturation 0.16; this entity's palette --
                   olive paint, copper, a hazard yellow -- comes in at 0.33 and
                   would leave at 0.59, past the 0.27-0.47 vanilla sit at. The
                   correction goes here, not in the materials: those are
                   sampled off the vanilla recycler and the owner's own concept
                   chips, and are the one part not to guess at.
  value      0.88  the pass landed mean luminance 76.7 where the vanilla 3x3s
                   measure 63 (chemical plant) and 67 (vanilla recycler). A
                   sprite brighter than its neighbours reads as a different
                   material once it is on ground rather than on white.

  form_amount 1.70  ONE preset has to serve eight directions, and they do not
                   measure alike: at the stock 1.25 the four rotations land
                   39.4 / 44.4 / 46.8 / 49.5, because east presents far more
                   of its shaded side than west does. 1.70 puts the worst
                   (east, 43.6) inside the band and leaves the best (west,
                   54.5) under the 56 ceiling.

**This is not the same override that used to sit here, and the distinction
matters.** `form_amount` was once 1.85 while the RAW render measured luminance
sd 26.5 -- the paint-over inventing contrast rather than sharpening it, which
is the failure mode `pipeline.md` warns about. That was fixed in the render: a
harder key with less sky fill (6.6 / 0.95 / 0.15 against the rig's validated
5.2 / 1.2 / 0.22) took the raw to sd 30.4, near the Pure beacon's 31.6. The
1.70 here is spending that headroom on the worst of eight views, not covering
for a flat one.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def _skill_scripts(start=None):
    import os
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
from factorio_render import gates, post, vanilla            # noqa: E402

POST = dict(preset="entity", saturation=0.70, value=0.90, form_amount=0.30,
            contrast_amount=1.35, crevice_amount=1.30)

# **form_amount 0.30, down from 1.70, and this is the measurement that turned
# this sprite round.** Luminance sd was in band the whole time -- 45-51 against
# a 43-56 gate -- while the sprite still read as a soft CG blob beside vanilla.
# Splitting the variance says why. Form (>12 px) against grain (<3 px):
#
#     vanilla recycler  form 16.1  grain 26.5  ratio 0.61
#     chemical plant    form 24.8  grain 23.0  ratio 1.08
#     this entity @1.70 form 27.2  grain 21.8  ratio 1.25
#
# An unsharp mask lifts every frequency above its radius, and at form_radius 11
# almost all of a greebled sprite's energy is 1-3 px wide -- so pushing
# form_amount to hit an sd target spends it on the ONE band vanilla has least
# of, and buys the absolute number by making the machine smoother. Dropping it
# to 0.30 and paying for the sd with contrast_amount (radius 7) and
# crevice_amount (radius 1.8) instead lands form 15.6 / grain 37.9 / sd 52.9:
# hard part separation and dark gaps, which is what vanilla actually is.

# Measured off the shipped sprites at 2.1.17 (see .ai-support/analysis).
TARGETS = ("vanilla 3x3: chemical plant lum 63 sat 0.47 (95%% >= .12), north "
           "overhang 0.77 tiles; vanilla recycler lum 67 sat 0.31 (78%%), "
           "overhang 0.58. gates.contrast wants lum sd 43-56.")


def stats(im):
    a = np.asarray(im, dtype=np.float32)
    m = a[..., 3] >= 200
    rgb = a[..., :3][m] / 255.0
    mx, mn = rgb.max(1), rgb.min(1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    lum = (rgb @ [0.2126, 0.7152, 0.0722]) * 255
    return dict(lum=lum.mean(), sd=lum.std(), sat=sat.mean(),
                sat12=100 * (sat >= 0.12).mean())


def main():
    d = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    raw = Image.open(d / "look.png").convert("RGBA")
    painted = post.paint_over(raw, **POST)
    painted.save(d / "look-post.png")

    for label, im in (("raw", raw), ("painted", painted)):
        s = stats(im)
        print("%-8s lum %5.1f  sd %5.1f  sat %.2f  sat>=.12 %3.0f%%"
              % (label, s["lum"], s["sd"], s["sat"], s["sat12"]))
    print("targets  " + TARGETS.replace("%%", "%"))

    print("\n-- gates --")
    for name, fn in (("contrast", gates.contrast), ("clipping", gates.clipping),
                     ("silhouette", gates.silhouette)):
        print("  %-11s %s" % (name, fn(d / "look-post.png")))
    print("  crop_waste  deferred -- the canvas is deliberately oversized for "
          "look-dev; cropping happens when the sheets are packed.")

    # The A/B is the check nothing else substitutes for: our layers and a real
    # vanilla entity's, composited on the terrain both will sit on, at game
    # pixels and magnified.
    van = vanilla.vanilla_panel("beacon")
    ours = vanilla.compose(
        [vanilla.Layer(str(d / "look-post.png"), painted.width, painted.height,
                       shift=(0, 0), scale=0.5)],
        size=(320, 320), footprint=(3, 3))
    vanilla.contact_sheet([("vanilla beacon 3x3", van),
                           ("quality recycler", ours)], zooms=(1, 3)) \
        .save(d / "ab.png")
    print("\n[ab] %s" % (d / "ab.png"))


if __name__ == "__main__":
    main()
