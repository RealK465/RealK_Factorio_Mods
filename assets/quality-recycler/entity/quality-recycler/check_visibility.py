"""Object-ID pass: how many pixels does each object actually draw?

    blender -b -P check_visibility.py -- <out_dir> [--dirs N,E,S,W]

The mod's CLAUDE.md says to run this before judging any change to the model,
and until now it was done by hand each time. It is the only check that answers
"is this part in the sprite at all" -- every gate in the kit reads the finished
PNG, so a part sealed inside a housing, buried in a deck or hidden behind a
wall costs render time, costs sprite budget and shows nothing, and no gate
says a word. The last hand-run of it found the drum sealed in its own housing,
a junction box and four cables drawing zero pixels, three instrument pods in
the throat of the shredder, and a seam frame that had grown to 17.9% of the
sprite while the hero it joins held 4.9%.

**The encoding is a value LATTICE, not a hue wheel.** Hues alias into each
other once the film filter touches them and the report then lies confidently.
Each object gets a flat emission colour from an 8x8x8 grid of tenths, the frame
is written as scene-linear EXR so no display transform can touch it, and the
pixel filter is a 0.01-wide box so no pixel is a blend of two objects. Interior
pixels snap to a lattice point exactly; the few that do not are edges and are
dropped -- typically under 4% of the sprite.
"""
import os
import sys
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import quality_recycler_gen as gen
import qr_layout
import qr_anim                             # noqa: E402

sys.path.insert(0, gen._skill_scripts())
from factorio_render import rig                                # noqa: E402

DIRECTIONS = {"N": 0.0, "E": -90.0, "S": 180.0, "W": 90.0}
# tenths, so every value survives the round trip through a byte exactly
STEPS = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]


def lattice():
    for r in STEPS:
        for g in STEPS:
            for b in STEPS:
                yield (r, g, b)


def paint_ids(objs):
    """One flat emission material per object. Returns colour -> name."""
    codes, gen_ = {}, lattice()
    for obj in objs:
        try:
            c = next(gen_)
        except StopIteration:
            raise RuntimeError("more objects than lattice points")
        m = bpy.data.materials.new("QRID_%s" % obj.name)
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
    dirs = ["N"]
    if "--dirs" in argv:
        dirs = argv[argv.index("--dirs") + 1].split(",")

    scene = rig.empty_scene()
    a = qr_layout.build(gen.build_materials())
    qr_anim.animate(frames=64)
    pass  # animation comes from qr_anim, wired above
    gen.set_direction(0)
    gen._FIT[0] = gen.fit_cone()

    objs = [o for o in bpy.data.objects
            if o.name.startswith(gen.PREFIX) and o.type == "MESH"]
    objs.sort(key=lambda o: o.name)
    codes = paint_ids(objs)

    rig.camera(scene, gen.CANVAS)
    rig.output(scene, gen.CANVAS)
    rig.cycles(scene, samples=1)
    scene.cycles.use_denoising = False
    # no world, no lights: what reaches the film is the emission and nothing else
    for lamp in [o for o in bpy.data.objects if o.type == "LIGHT"]:
        bpy.data.objects.remove(lamp, do_unlink=True)
    if scene.world:
        scene.world.use_nodes = True
        bg = scene.world.node_tree.nodes.get("Background")
        if bg:
            bg.inputs["Strength"].default_value = 0.0
    # **Write EXR, not PNG.** The first cut of this wrote PNG and set the view
    # transform to Raw to keep the lattice intact; only 34% of pixels then
    # classified and the report declared the bins, the drive motor and the
    # capacitor bank invisible while all three are plainly in the render. A
    # display transform is a display transform -- EXR carries the scene-linear
    # value the emission shader actually produced, so the round trip is exact
    # and no colour-management setting can quietly break it.
    scene.render.image_settings.file_format = "OPEN_EXR"
    scene.render.image_settings.color_depth = "32"
    scene.render.image_settings.color_mode = "RGBA"
    # a near-zero box filter so no pixel is a blend of two objects
    scene.render.filter_size = 0.01
    try:
        scene.cycles.pixel_filter_type = "BOX"
    except (AttributeError, TypeError):
        pass

    import numpy as np
    report = {}
    for d in dirs:
        gen.set_direction(DIRECTIONS[d.replace("flipped-", "")],
                          mirror=d.startswith("flipped-"))
        scene.render.filepath = str(out / ("ids-%s.exr" % d))
        bpy.ops.render.render(write_still=True)

        img = bpy.data.images.load(scene.render.filepath)
        img.colorspace_settings.name = "Non-Color"
        px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
        bpy.data.images.remove(img)
        opaque = px[px[:, 3] > 0.5][:, :3]
        # scene-linear straight out of the emission shader: snap to the nearest
        # tenth, which is unambiguous because the lattice is 0.1 apart and an
        # interior pixel is not a blend
        keys = np.rint(opaque * 10).astype(np.int32)
        uniq, counts = np.unique(keys, axis=0, return_counts=True)
        seen = {}
        for k, n in zip(uniq, counts):
            name = codes.get(tuple(int(v) for v in k))
            if name:
                seen[name] = seen.get(name, 0) + int(n)
        total = sum(seen.values())
        for name in codes.values():
            report.setdefault(name, {})[d] = seen.get(name, 0)
        print("[ids] %s: %d objects visible of %d, %d classified px"
              % (d, sum(1 for v in seen.values() if v), len(codes), total))

    print("\n== objects drawing NOTHING in any direction ==")
    dead = [n for n, v in report.items() if max(v.values()) == 0]
    for n in sorted(dead):
        print("   %s" % n)
    if not dead:
        print("   (none)")

    print("\n== below the legibility floor (max < 12 px in every direction) ==")
    faint = [(max(v.values()), n) for n, v in report.items()
             if 0 < max(v.values()) < 12]
    for n, name in sorted(faint):
        print("   %5d px  %s" % (n, name))
    if not faint:
        print("   (none)")

    print("\n== biggest 18, by best direction ==")
    big = sorted(((max(v.values()), n) for n, v in report.items()), reverse=True)
    grand = sum(max(v.values()) for v in report.values())
    for n, name in big[:18]:
        print("   %6d px  %5.2f%%  %s" % (n, 100.0 * n / grand, name))


if __name__ == "__main__":
    main()
