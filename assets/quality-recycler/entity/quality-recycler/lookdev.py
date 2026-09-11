"""Render the Phase 1 look-dev variants, at sprite density and at 4x.

    blender -b -P lookdev.py -- <ABSOLUTE out_dir> [--variants A,B,C]
                                [--dirs N,E] [--samples 96] [--builder blockout]

Absolute path, always: Blender resolves a relative `render.filepath` against
its own working directory, not the script's, and silently writes the run to
somewhere like C:\\renders. That cost one render here already.

Writes `<v>-<dir>.png` (320x384, the size the sprite actually ships at, which
is the size that settles whether it works) and `<v>-<dir>-hero.png` (4x, the
size a MATERIAL can be judged at). Same camera for both -- a prettier beauty
camera would show surfaces the shipped sprite can never contain.
"""
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import quality_recycler_gen as gen                                # noqa: E402
import qr_rebuild                                                 # noqa: E402
import qr_layout                                                  # noqa: E402
import qr_anim                                                    # noqa: E402

sys.path.insert(0, gen._skill_scripts())
from factorio_render import rig                                   # noqa: E402

DIRECTIONS = {"N": 0.0, "E": -90.0, "S": 180.0, "W": 90.0}
HERO_SCALE = 4


def arg(argv, flag, default):
    return argv[argv.index(flag) + 1] if flag in argv else default


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[0])
    out.mkdir(parents=True, exist_ok=True)
    variants = arg(argv, "--variants", "A,B,C").split(",")
    dirs = arg(argv, "--dirs", "N,E").split(",")
    samples = int(arg(argv, "--samples", "96"))
    builder = arg(argv, "--builder", "blockout")
    hero = "--no-hero" not in argv

    scene = rig.empty_scene()
    rig.lights(scene, key=gen.KEY, fill=gen.FILL, ambient=gen.AMBIENT)
    rig.cycles(scene, samples=samples)
    rig.use_gpu(scene)
    scene.render.use_persistent_data = True

    for v in variants:
        mats = gen.build_materials()
        a = (qr_rebuild.blockout(mats, v) if builder == "blockout"
             else qr_layout.build(mats))
        if builder != "blockout":
            qr_anim.animate(frames=64)
        gen.set_direction(0)
        gen._FIT[0] = gen.fit_cone()
        gen.set_direction(0)
        print("\n=== variant %s ===" % v)
        try:
            gen.audit(a)
        except Exception as exc:                      # audit must never block a look
            print("[audit] failed: %r" % (exc,))
        for d in dirs:
            gen.set_direction(DIRECTIONS[d])
            rig.camera(scene, gen.CANVAS)
            rig.output(scene, gen.CANVAS)
            scene.frame_set(int(arg(argv, "--frame", "0")))
            scene.render.filepath = str(out / ("%s-%s.png" % (v, d)))
            bpy.ops.render.render(write_still=True)
            if hero:
                big = (gen.CANVAS[0] * HERO_SCALE, gen.CANVAS[1] * HERO_SCALE)
                rig.camera(scene, big)
                rig.output(scene, big)
                # px/tile = resolution_x / ortho_scale, so the ortho scale has
                # to be pinned back or the machine silently changes size.
                scene.camera.data.ortho_scale = gen.CANVAS[0] / 64.0
                scene.render.filepath = str(out / ("%s-%s-hero.png" % (v, d)))
                bpy.ops.render.render(write_still=True)
            print("[lookdev] %s %s" % (v, d))
    print("LOOKDEV DONE ->", out)


main()
