"""Object-ID pass: how many pixels does each object actually draw?

    blender -b -P check_visibility.py -- <out_dir>

The only check that answers "is this part in the sprite at all" -- every
gate in the kit reads the finished PNG, so a part sealed inside a housing,
buried in a deck or hidden behind a wall costs render time and shows nothing,
and no gate says a word. The recycler's first hand-run of this found 60 of
213 objects drawing nothing.

The encoding is a value LATTICE, not a hue wheel: each object gets a flat
emission colour from an 8x8x8 grid of tenths, the frame is written as
scene-linear EXR so no display transform can touch it, and the pixel filter
is a near-zero box so no pixel is a blend of two objects.
"""
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import qa_gen as gen                                           # noqa: E402
import qa_layout                                               # noqa: E402

sys.path.insert(0, gen._skill_scripts())
from factorio_render import rig                                # noqa: E402

STEPS = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]


def lattice():
    for r in STEPS:
        for g in STEPS:
            for b in STEPS:
                yield (r, g, b)


def paint_ids(objs):
    codes, gen_ = {}, lattice()
    for obj in objs:
        c = next(gen_)
        m = bpy.data.materials.new("QAID_%s" % obj.name)
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (c[0], c[1], c[2], 1.0)
        em.inputs["Strength"].default_value = 1.0
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
        obj.data.materials.clear()
        obj.data.materials.append(m)
        codes[tuple(round(v * 10) for v in c)] = obj.name
    return codes


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[0] if argv else ".")
    out.mkdir(parents=True, exist_ok=True)
    frame = int(argv[argv.index("--frame") + 1]) if "--frame" in argv else 0
    # `--hide window-glass`: the pass paints every material opaque, so a pane
    # of glass hides everything behind it -- hide it to audit the cell
    hide = argv[argv.index("--hide") + 1].split(",") if "--hide" in argv else []

    scene = rig.empty_scene()
    qa_layout.build(gen.build_materials())
    gen.organise()
    gen.animate(frames=64)
    bpy.data.collections["QA_Pipe"].hide_render = True

    for nm in hide:
        o = bpy.data.objects.get(gen.PREFIX + nm)
        if o is not None:
            o.hide_render = True
    objs = [o for o in bpy.data.objects
            if o.name.startswith(gen.PREFIX) and o.type == "MESH"
            and not o.name.startswith(gen.PREFIX + "stub-") and not o.hide_render]
    objs.sort(key=lambda o: o.name)
    codes = paint_ids(objs)

    rig.camera(scene, gen.CANVAS)
    rig.output(scene, gen.CANVAS)
    rig.cycles(scene, samples=1)
    scene.cycles.use_denoising = False
    for lamp in [o for o in bpy.data.objects if o.type == "LIGHT"]:
        bpy.data.objects.remove(lamp, do_unlink=True)
    if scene.world:
        scene.world.use_nodes = True
        bg = scene.world.node_tree.nodes.get("Background")
        if bg:
            bg.inputs["Strength"].default_value = 0.0
    scene.render.image_settings.file_format = "OPEN_EXR"
    scene.render.image_settings.color_depth = "32"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filter_size = 0.01
    try:
        scene.cycles.pixel_filter_type = "BOX"
    except (AttributeError, TypeError):
        pass

    import numpy as np
    scene.frame_set(frame)
    scene.render.filepath = str(out / "ids.exr")
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(scene.render.filepath)
    img.colorspace_settings.name = "Non-Color"
    px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
    bpy.data.images.remove(img)
    opaque = px[px[:, 3] > 0.5][:, :3]
    keys = np.rint(opaque * 10).astype(np.int32)
    uniq, counts = np.unique(keys, axis=0, return_counts=True)
    seen = {}
    for k, n in zip(uniq, counts):
        name = codes.get(tuple(int(v) for v in k))
        if name:
            seen[name] = seen.get(name, 0) + int(n)
    total = sum(seen.values())
    print("[ids] %d objects visible of %d, %d classified px of %d opaque"
          % (sum(1 for v in seen.values() if v), len(codes), total, len(opaque)))

    print("\n== objects drawing NOTHING ==")
    dead = [n for n in codes.values() if seen.get(n, 0) == 0]
    for n in sorted(dead):
        print("   %s" % n)
    if not dead:
        print("   (none)")
    print("\n== below the legibility floor (< 12 px) ==")
    faint = sorted((seen[n], n) for n in seen if 0 < seen[n] < 12)
    for n, name in faint:
        print("   %5d px  %s" % (n, name))
    print("\n== biggest 24 ==")
    for n, name in sorted(((v, k) for k, v in seen.items()), reverse=True)[:24]:
        print("   %6d px  %5.2f%%  %s" % (n, 100.0 * n / max(total, 1), name))


if __name__ == "__main__":
    main()
