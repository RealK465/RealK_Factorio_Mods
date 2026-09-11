"""Build the machine from source and save the .blend beside it.

    blender -b -P save_blend.py -- [out.blend]

The `.blend` is a CACHE, not the source: `qr_layout.py` plus `qr_anim.py` is
what the machine actually is, and every render driver rebuilds from them rather
than opening the file. Saving one is still worth doing — it is what lets the
scene be opened and poked at by hand, and the repo commits it alongside the
PNGs it produced so a sprite can be reproduced later.

Defaults to `quality-recycler.blend` in this folder. The pre-rebuild scene is
kept untouched at `versions/quality-recycler-v0-original.blend`.
"""
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import quality_recycler_gen as gen                              # noqa: E402
import qr_layout                                                # noqa: E402
import qr_anim                                                  # noqa: E402

sys.path.insert(0, gen._skill_scripts())
from factorio_render import rig                                 # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[0]) if argv else HERE / "quality-recycler.blend"

    scene = rig.empty_scene()
    a = qr_layout.build(gen.build_materials())
    qr_anim.animate(frames=64)
    gen.set_direction(0)
    gen._FIT[0] = gen.fit_cone()
    gen.set_direction(0)
    gen.audit(a)
    rig.camera(scene, gen.CANVAS)
    rig.lights(scene, key=gen.KEY, fill=gen.FILL, ambient=gen.AMBIENT)
    rig.output(scene, gen.CANVAS)
    rig.cycles(scene, samples=96)
    scene.frame_end = 63
    bpy.ops.wm.save_as_mainfile(filepath=str(out))
    print("[blend] %s" % out)


main()
