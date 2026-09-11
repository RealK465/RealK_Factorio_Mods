"""Render every material as a lit panel and measure what it actually becomes.

    blender -b -P swatch.py -- <ABSOLUTE out_dir> [--samples 64]

A base colour is not what a material renders. The `worn_metal` stack mixes in
grime, rust, edge wear and a per-object jitter, and then the rig's key, fill and
sky decide the rest -- so tuning a palette by editing hex codes and looking at
the machine is a slow loop with three variables in it. This renders a 3x3-tile
block per material at the SAME camera, key, fill and ambient the entity uses,
and prints the rendered statistics beside the target.

Two panels per material, and the reason matters: a flat plate shows the lit top
only, where a stepped block shows a lit top, a shaded south wall and a crevice
between them. The entity's own luminance spread comes from the second, so a
palette tuned on flat swatches lands the mean and misses the range.

Targets are measured off the shipped 2.1 sprites and printed with the result:

    vanilla recycler  olive-green band (96, 106, 57) lum 101 sat 0.47
    vanilla recycler  overall lum 67, 31% of pixels below saturation 0.18
    vanilla chem plant overall lum 63, 12% below saturation 0.18
"""
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import quality_recycler_gen as gen                               # noqa: E402
import qr_rebuild as rb                                          # noqa: E402

sys.path.insert(0, gen._skill_scripts())
from factorio_render import rig                                  # noqa: E402

# Order matters only for reading the contact sheet; keep the two halves apart.
ORDER = ["olive", "hazard", "scoured", "steel", "gunmetal", "cavity",
         "concrete", "temper", "tempers", "temperv", "bronze", "copper",
         "rubber", "glass"]
COLS = 5
PITCH = 1.15


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[0])
    out.mkdir(parents=True, exist_ok=True)
    samples = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 64

    scene = rig.empty_scene()
    mats = gen.build_materials()
    rb.extra_materials()
    names = [n for n in ORDER if n in gen._MATS]
    names += [n for n in sorted(gen._MATS) if n not in names]

    n = len(names)
    rows = (n + COLS - 1) // COLS
    for i, name in enumerate(names):
        cx = (i % COLS - (COLS - 1) / 2.0) * PITCH
        cy = ((rows - 1) / 2.0 - i // COLS) * PITCH
        # a stepped block, not a plate: lit top, shaded south wall, one crevice
        gen.box("sw%02d-lo" % i, (cx - 0.50, cy - 0.50, 0.0),
                (cx + 0.50, cy + 0.50, 0.26), mat=name)
        gen.box("sw%02d-hi" % i, (cx - 0.34, cy - 0.34, 0.26),
                (cx + 0.34, cy + 0.22, 0.56), mat=name)
        gen.cyl("sw%02d-cy" % i, (cx + 0.24, cy - 0.30, 0.40), 0.13, 0.28,
                axis="Y", mat=name, seg=18)

    span = max(COLS, rows) * PITCH + 0.6
    canvas = (int(span * 64) & ~1, int(span * 64) & ~1)
    rig.camera(scene, canvas)
    scene.camera.data.ortho_scale = span
    rig.lights(scene, key=gen.KEY, fill=gen.FILL, ambient=gen.AMBIENT)
    rig.output(scene, canvas)
    rig.cycles(scene, samples=samples)
    rig.use_gpu(scene)
    scene.render.filepath = str(out / "swatches.png")
    bpy.ops.render.render(write_still=True)

    # the cell geometry the measuring script needs, so it never has to guess
    with open(out / "swatches.txt", "w") as fh:
        fh.write("canvas %d %d\ncols %d\nrows %d\npitch %.4f\nspan %.4f\n"
                 % (canvas[0], canvas[1], COLS, rows, PITCH, span))
        for i, name in enumerate(names):
            fh.write("cell %d %s\n" % (i, name))
    print("[swatch] %s  (%d materials)" % (out / "swatches.png", len(names)))


main()
