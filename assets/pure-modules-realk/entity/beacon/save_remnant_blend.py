# Regenerates the committed remnant.blend snapshot from the generator.
#
#   blender -b -P save_remnant_blend.py [-- <variation>]
#
# The .blend is a saved snapshot for interactive inspection; the generator
# scripts remain the source of truth. Variation 0 is saved by default -- the
# two differ only in scatter and placement data, so one is enough to look at.
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
variation = int(argv[0]) if argv else 0

bpy.ops.wm.read_factory_settings(use_empty=True)
import remnant_gen

remnant_gen.build_scene(variation=variation)
out = os.path.join(HERE, "remnant.blend")
bpy.ops.wm.save_as_mainfile(filepath=out)
print("SAVED:", out, os.path.exists(out))
