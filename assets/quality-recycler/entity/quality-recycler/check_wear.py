"""Render the edge-wear term on its own and gate it.

    blender -b -P check_wear.py -- <out_dir>

`gates.wear_mask` is the only check in the kit that measures the MODEL rather
than the output PNG, and it is the one that catches the failure every other
gate is blind to: `worn_metal()` chips paint where Geometry->Pointiness is
high, but pointiness is per-vertex and interpolated, so on an under-subdivided
box it floods whole panels. The paint then comes off everywhere, the sprite
turns pale and uniform, and seven gates still pass because the sprite is
plausible on its own terms.

This drives the same term through a `material_override` so what is measured is
the mask, not a sprite that happens to contain it.
"""
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
import quality_recycler_gen as gen                             # noqa: E402

sys.path.insert(0, gen._skill_scripts())
from factorio_render import gates, rig                         # noqa: E402


def wear_override():
    m = bpy.data.materials.new("QR_wearmask")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.53
    mr.inputs["From Max"].default_value = 0.62
    em = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(geo.outputs["Pointiness"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], em.inputs["Strength"])
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[0] if argv else ".")
    out.mkdir(parents=True, exist_ok=True)

    scene = rig.empty_scene()
    gen.build(gen.build_materials())
    gen.set_direction(0)
    rig.camera(scene, gen.CANVAS)
    rig.lights(scene, key=gen.KEY, fill=gen.FILL, ambient=gen.AMBIENT)
    rig.output(scene, gen.CANVAS)
    rig.cycles(scene, samples=16)
    rig.use_gpu(scene)
    scene.view_layers[0].material_override = wear_override()
    scene.render.filepath = str((out / "wear.png").resolve())
    bpy.ops.render.render(write_still=True)
    print("[wear] %s" % gates.wear_mask(out / "wear.png"))


main()
