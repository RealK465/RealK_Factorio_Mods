"""The BEAUTY RENDER: one Quality Recycler, big, for art direction only.

    blender -b -P render_hero.py -- <out_dir> [--dir N|E|S|W] [--samples 256]

Why this exists separately from `quality_recycler_gen.py`'s look frame: the
look frame is 320x384 at 64 px/tile, which is the size the sprite actually
ships at and therefore the size that settles whether the sprite works. It is
useless for judging a MATERIAL -- a roughness decision or a patina falloff is
three pixels wide there. This renders the same machine, at the same camera, at
four times the pixel density, so a material can be looked at.

**Same camera, deliberately.** The 45-degree pitch with no yaw IS Factorio's
three-quarter view, and it is what decides which surfaces exist in the sprite
at all: at this rig only the deck and the front wall face the viewer. A prettier
beauty camera with some yaw on it would show detail the shipped sprite can
never contain, and every judgement made from it would be about a machine the
player will not see. The only things scaled up are resolution and samples.

`--turntable` additionally writes the four rotations side by side, because a
rotatable entity has four front elevations and a defect in three of them is
invisible from north.
"""
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import quality_recycler_gen as gen                             # noqa: E402

sys.path.insert(0, gen._skill_scripts())
from factorio_render import rig                                # noqa: E402

DIRECTIONS = {"N": 0.0, "E": -90.0, "S": 180.0, "W": 90.0}
# 4x the shipped density: 256 px/tile. The ortho_scale has to follow the canvas
# or the machine silently changes size -- px/tile = resolution_x / ortho_scale.
SCALE = 4
CANVAS = (gen.CANVAS[0] * SCALE, gen.CANVAS[1] * SCALE)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[0] if argv else ".")
    out.mkdir(parents=True, exist_ok=True)
    samples = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 256
    dirs = ["N"]
    if "--dir" in argv:
        dirs = argv[argv.index("--dir") + 1].split(",")
    if "--turntable" in argv:
        dirs = ["N", "E", "S", "W"]

    scene = rig.empty_scene()
    gen.build(gen.build_materials())
    gen.animate(frames=64)
    gen.set_direction(0)
    gen._FIT[0] = gen.fit_cone()

    rig.camera(scene, CANVAS)
    scene.camera.data.ortho_scale = gen.CANVAS[0] / 64.0
    rig.lights(scene, key=gen.KEY, fill=gen.FILL, ambient=gen.AMBIENT)
    rig.output(scene, CANVAS)
    scene.camera.data.ortho_scale = gen.CANVAS[0] / 64.0
    rig.cycles(scene, samples=samples)
    rig.use_gpu(scene)
    scene.render.use_persistent_data = True
    # frame 8: the rotor is turning and the fragments are in flight, so the
    # WORKING state is what gets art-directed. The idle state is the same
    # machine with the moving parts at rest and nothing emissive.
    scene.frame_set(8)

    for d in dirs:
        gen.set_direction(DIRECTIONS[d])
        scene.render.filepath = str(out / ("hero-%s.png" % d))
        bpy.ops.render.render(write_still=True)
        print("[hero] %s" % (out / ("hero-%s.png" % d)))


if __name__ == "__main__":
    main()
