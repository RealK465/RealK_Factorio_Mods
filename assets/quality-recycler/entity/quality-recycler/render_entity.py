# Headless render driver for the Quality Recycler.
#
#   blender -b -P render_entity.py -- <out_dir> [--layers base,anim,glow,shadow]
#                                     [--dirs N,E,S,W] [--frames N] [--only 0,8]
#
# Writes <out_dir>/<DIR>/<layer>/f####.png. Static layers render frame 0 only.
#
# THE MODEL ROTATES, THE CAMERA DOES NOT. Factorio's light is world-fixed --
# shadows fall the same screen direction whichever way a machine faces, which
# is why Wube ship the oil refinery as four separate models rather than one
# orbited one. Orbiting the camera would carry the shadow round with it and
# every direction but north would be lit wrong.
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


def _skill_scripts(start=None):
    d = os.path.abspath(start or globals().get("__file__") or os.getcwd())
    if os.path.isfile(d):
        d = os.path.dirname(d)
    while True:
        c = os.path.join(d, ".claude", "skills", "factorio-graphics", "scripts")
        if os.path.isdir(c):
            return c
        parent = os.path.dirname(d)
        if parent == d:
            raise RuntimeError("factorio-graphics scripts not found")
        d = parent


sys.path.insert(0, _skill_scripts())
from factorio_render import rig as fr_rig                   # noqa: E402

# Factorio's north is the default orientation and rotating to east turns the
# entity clockwise seen from above, which is NEGATIVE about Z in Blender.
# Flagged for in-engine confirmation: the skill is explicit that a
# rotation-specific fault is invisible to a one-rotation check, and no offline
# composite can settle which sheet the engine actually draws for `east`.
DIRECTIONS = {"N": 0.0, "E": -90.0, "S": 180.0, "W": 90.0}

# Which collections each layer draws. `anim` deliberately keeps QR_Base in the
# render as a HOLDOUT rather than hiding it: the anim sheet composites ABOVE
# the base in game, so a moving part that ought to be hidden behind the hull
# would otherwise be drawn straight over it. A holdout punches alpha-0 where
# the hull is nearer the camera, which is exactly the occlusion the composite
# needs and cannot work out for itself.
LAYERS = {
    "base":   dict(show=("QR_Base",), holdout=()),
    "anim":   dict(show=("QR_Moving", "QR_Fx"), holdout=("QR_Base",)),
    # Emission-only, with every light and the world switched off: what reaches
    # the film IS the emission, which is what an additive light sprite is.
    # The whole machine is present so the static status lamp is in it too.
    "glow":   dict(show=("QR_Base", "QR_Moving", "QR_Fx"), holdout=()),
    # Static silhouettes only. The drum, gear, rollers and auger all turn in
    # place, so their outline never changes and they belong here; the flying
    # fragments do not, and a baked shadow of something in flight lands
    # displaced from the machine and then never moves.
    "shadow": dict(show=("QR_Base", "QR_Moving"), holdout=()),
}
STATIC = {"base", "shadow"}
ALL_COLLS = ("QR_Base", "QR_Moving", "QR_Fx")


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        raise SystemExit("usage: blender -b -P render_entity.py -- <out_dir> "
                         "[--layers a,b] [--dirs N,E] [--frames N] [--only 0,8]")
    out, layers, dirs, frames, only = argv[0], ["base"], ["N"], 64, None
    i = 1
    while i < len(argv):
        if argv[i] == "--layers":
            layers = argv[i + 1].split(",")
        elif argv[i] == "--dirs":
            dirs = argv[i + 1].split(",")
        elif argv[i] == "--frames":
            frames = int(argv[i + 1])
        elif argv[i] == "--only":
            only = [int(v) for v in argv[i + 1].split(",")]
        else:
            raise SystemExit("unknown arg: " + argv[i])
        i += 2
    return out, layers, dirs, frames, only


def show_only(spec):
    for name in ALL_COLLS:
        c = bpy.data.collections.get(name)
        if c:
            c.hide_render = name not in spec["show"] and name not in spec["holdout"]
    for name in ALL_COLLS:
        c = bpy.data.collections.get(name)
        if not c:
            continue
        held = name in spec["holdout"]
        for obj in c.objects:
            obj.is_holdout = held


def render_shadow(scene, out_dir):
    spec = LAYERS["shadow"]
    show_only(spec)
    scene.frame_set(0)
    # 0.005 below ground, never level with it: a catcher plane exactly at the
    # model's ground level is coplanar with every foot plate, and two shells
    # sharing an exactly coplanar face render OPAQUE BLACK in Cycles.
    bpy.ops.mesh.primitive_plane_add(size=16, location=(0, 0, -0.005))
    catcher = bpy.context.object
    catcher.name = "QR_ShadowCatcher"
    catcher.is_shadow_catcher = True
    hidden = [o for o in bpy.data.objects
              if o.name.startswith("QR_") and o is not catcher
              and o.type in ("MESH", "CURVE")]
    for o in hidden:
        o.visible_camera = False
    os.makedirs(out_dir, exist_ok=True)
    scene.render.filepath = os.path.join(out_dir, "f0000.png")
    bpy.ops.render.render(write_still=True)
    for o in hidden:
        o.visible_camera = True
    bpy.data.objects.remove(catcher, do_unlink=True)


def render_layer(scene, layer, out_dir, frames, only):
    spec = LAYERS[layer]
    show_only(spec)
    dark = []
    if layer == "glow":
        for o in bpy.data.objects:
            if o.type == "LIGHT":
                dark.append((o.data, o.data.energy))
                o.data.energy = 0.0
        bg = scene.world.node_tree.nodes["Background"] if scene.world else None
        if bg:
            sock = bg.inputs["Strength"]
            dark.append((sock, sock.default_value))
            sock.default_value = 0.0
    os.makedirs(out_dir, exist_ok=True)
    todo = [0] if layer in STATIC else (only or list(range(frames)))
    for f in todo:
        scene.frame_set(f)
        scene.render.filepath = os.path.join(out_dir, "f%04d.png" % f)
        bpy.ops.render.render(write_still=True)
    for holder, value in dark:
        if hasattr(holder, "energy"):
            holder.energy = value
        else:
            holder.default_value = value


def main():
    out, layers, dirs, frames, only = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    import quality_recycler_gen as gen

    scene = bpy.context.scene
    gen.build(gen.build_materials())
    gen.animate(frames=frames)
    # Fit the model to the cone before posing it. Without this the driver
    # renders the UNFITTED geometry -- `_FIT` stays 1.0, because fit_cone()
    # lives in the generator's own main() and nothing here called it -- and the
    # sheets come out at the raw 2.32 the fit exists to bring down. That shipped
    # once: eight directions packed at 0.81-0.83 tiles of overhang against
    # vanilla's 0.77 ceiling, while the generator's audit printed 0.77 and was
    # telling the truth about geometry nobody was rendering.
    gen.set_direction(0)
    gen._FIT[0] = gen.fit_cone()
    fr_rig.camera(scene, gen.CANVAS)
    fr_rig.lights(scene, key=gen.KEY, fill=gen.FILL, ambient=gen.AMBIENT)
    fr_rig.output(scene, gen.CANVAS)
    fr_rig.cycles(scene, samples=96)

    for d in dirs:
        mirror = d.startswith("flipped-")
        gen.set_direction(DIRECTIONS[d.replace("flipped-", "")], mirror=mirror)
        for layer in layers:
            target = os.path.join(out, d, layer)
            if layer == "shadow":
                render_shadow(scene, target)
            else:
                render_layer(scene, layer, target, frames, only)
            print("[render] %s/%s" % (d, layer))
    print("RENDER DONE:", ",".join(dirs), "x", ",".join(layers), "->", out)


main()
