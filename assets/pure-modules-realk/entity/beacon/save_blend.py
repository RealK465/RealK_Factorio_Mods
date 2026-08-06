# Regenerates the committed beacon.blend snapshot from the generator.
#
#   blender -b -P save_blend.py
#
# The .blend is a saved snapshot for interactive inspection; the generator
# scripts remain the source of truth.
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

bpy.ops.wm.read_factory_settings(use_empty=True)
import beacon_gen

objs = beacon_gen.build_scene()
beacon_gen.animate(objs, frames=64)
out = os.path.join(HERE, "beacon.blend")
bpy.ops.wm.save_as_mainfile(filepath=out)
print("SAVED:", out, os.path.exists(out))
