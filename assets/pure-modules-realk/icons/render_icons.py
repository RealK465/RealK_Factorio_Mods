"""Headless driver: build the model from source and render every Pure module.

    blender -b -P render_icons.py -- <out_dir>

Builds from pure_module_icon.py rather than opening the .blend, so the render
is reproducible from the script alone -- the .blend is a convenience for
editing by hand, not the source of truth.

Feed each result to export_icon.py to get the shippable PNGs.
"""

import os
import sys

import bpy

KINDS = ("speed", "productivity", "quality")

# Start from a genuinely empty scene. build() only purges its own PM_* objects,
# so Blender's startup cube would otherwise survive and render straight through
# the middle of the module -- which is exactly what happened the first time.
bpy.ops.wm.read_factory_settings(use_empty=True)

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out_dir = argv[0] if argv else os.path.join(here, "render")
os.makedirs(out_dir, exist_ok=True)

src = os.path.join(here, "pure_module_icon.py")
mod = {"__name__": "pure_module_icon"}
exec(compile(open(src).read(), src, "exec"), mod)

mod["build"]()
mod["setup_render"]()
for kind in KINDS:
    mod["tint"](kind)
    path = os.path.join(out_dir, "pure-%s-module.png" % kind)
    mod["render"](path)
    print("RENDERED", path)
