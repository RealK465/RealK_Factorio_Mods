# Headless render driver for the Quality Recycler.
#
#   blender -b -P render_entity.py -- <ABSOLUTE out_dir>
#       [--layers base,anim,fx,glow,lamp,shadow] [--dirs N,E,S,W]
#       [--frames N] [--only 0,8] [--samples 96]
#
# Writes <out_dir>/<DIR>/<layer>/f####.png. Static layers render frame 0 only.
# ABSOLUTE path, always: Blender resolves a relative render.filepath against
# its own working directory, not the script's, and writes the run to somewhere
# like C:\renders without complaining.
#
# THE MODEL ROTATES, THE CAMERA DOES NOT. Factorio's light is world-fixed --
# shadows fall the same screen direction whichever way a machine faces, which
# is why Wube ship the oil refinery as four separate models rather than one
# orbited one. Orbiting the camera would carry the shadow round with it and
# every direction but north would be lit wrong.
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import quality_recycler_gen as gen                          # noqa: E402
import qr_layout                                            # noqa: E402
import qr_anim                                              # noqa: E402

sys.path.insert(0, gen._skill_scripts())
from factorio_render import rig as fr_rig                   # noqa: E402

# Factorio's north is the default orientation and rotating to east turns the
# entity clockwise seen from above, which is NEGATIVE about Z in Blender.
DIRECTIONS = {"N": 0.0, "E": -90.0, "S": 180.0, "W": 90.0}

# Which collections each layer draws.
#
# `anim` and `fx` deliberately keep the layers BELOW them in the render as
# HOLDOUTS rather than hiding them: both composite ABOVE the base in game, so a
# moving part that ought to be hidden behind the hull would otherwise be drawn
# straight over it. A holdout punches alpha-0 where the nearer object is, which
# is exactly the occlusion the composite cannot work out for itself.
#
# `fx` is separate from `anim` because the fragments must VANISH when the
# machine stops. The anim sheet is a layer of `animation` and is drawn always
# (frozen at frame 0 when idle); fx is a working_visualisation and is not. A
# chip frozen in mid-air over an idle machine is the failure this split exists
# to avoid.
LAYERS = {
    "base":   dict(show=("QR_Base",), holdout=()),
    "anim":   dict(show=("QR_Moving",), holdout=("QR_Base",)),
    "fx":     dict(show=("QR_Fx",), holdout=("QR_Base", "QR_Moving")),
    # Emission-only, with every light and the world switched off: what reaches
    # the film IS the emission, which is what an additive light sprite is.
    "glow":   dict(show=("QR_Base", "QR_Moving", "QR_Fx"), holdout=()),
    # The status lamp alone, always drawn, so an idle machine still glows at
    # night. One frame, a few dozen pixels; the cheapest layer on the entity.
    "lamp":   dict(show=("QR_Base", "QR_Moving", "QR_Fx"), holdout=(),
                   only_prefix="lamp"),
    # Static silhouettes only. The rotor, gear, rollers and fan all turn in
    # place so their outline never changes and they belong here; the flying
    # fragments do not, and a baked shadow of something in flight lands
    # displaced from the machine and then never moves.
    "shadow": dict(show=("QR_Base", "QR_Moving"), holdout=()),
}
STATIC = {"base", "shadow", "lamp"}
EMISSION_ONLY = {"glow", "lamp"}
ALL_COLLS = ("QR_Base", "QR_Moving", "QR_Fx")


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        raise SystemExit("usage: blender -b -P render_entity.py -- <out_dir> "
                         "[--layers a,b] [--dirs N,E] [--frames N] [--only 0,8]")
    out, layers, dirs = argv[0], ["base"], ["N"]
    frames, only, samples = 64, None, 96
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
        elif argv[i] == "--samples":
            samples = int(argv[i + 1])
        else:
            raise SystemExit("unknown arg: " + argv[i])
        i += 2
    return out, layers, dirs, frames, only, samples


def show_only(spec):
    keep = spec.get("only_prefix")
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
            if keep:
                obj.hide_render = not obj.name.startswith(gen.PREFIX + keep)
            else:
                obj.hide_render = False


def render_shadow(scene, out_dir):
    show_only(LAYERS["shadow"])
    scene.frame_set(0)
    # 0.005 below ground, never level with it: a catcher plane exactly at the
    # model's ground level is coplanar with every foot plate, and two shells
    # sharing an exactly coplanar face render OPAQUE BLACK in Cycles.
    bpy.ops.mesh.primitive_plane_add(size=16, location=(0, 0, -0.005))
    catcher = bpy.context.object
    catcher.name = "QR_ShadowCatcher"
    catcher.is_shadow_catcher = True
    hidden = [o for o in bpy.data.objects
              if o.name.startswith(gen.PREFIX) and o is not catcher
              and o.type in ("MESH", "CURVE")]
    for o in hidden:
        o.visible_camera = False
    os.makedirs(out_dir, exist_ok=True)
    scene.render.filepath = os.path.join(out_dir, "f0000.png")
    bpy.ops.render.render(write_still=True)
    for o in hidden:
        o.visible_camera = True
    bpy.data.objects.remove(catcher, do_unlink=True)


VIOLETS = ("violet", "violet2", "violet3")


def _dim_violets(strength):
    """The base sheet is drawn in every state, so a field ring lit in it makes
    an IDLE machine glow by day. The glow sheet is the working-only layer;
    the base carries the ring as a dull painted gap. Materials with keyframed
    emission get their action detached for the pass and restored after."""
    saved = []
    for name in VIOLETS:
        mat = bpy.data.materials.get(gen.PREFIX + name)
        if not mat or not mat.node_tree:
            continue
        ad = mat.node_tree.animation_data
        action = ad.action if ad else None
        if ad:
            ad.action = None
        bsdf = next((n for n in mat.node_tree.nodes
                     if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        sock = bsdf.inputs["Emission Strength"]
        saved.append((mat, action, sock, sock.default_value))
        sock.default_value = strength
    return saved


def _restore_violets(saved):
    for mat, action, sock, value in saved:
        sock.default_value = value
        if action is not None and mat.node_tree.animation_data:
            mat.node_tree.animation_data.action = action


def render_layer(scene, layer, out_dir, frames, only, restore):
    spec = LAYERS[layer]
    show_only(spec)
    dark = []
    dimmed = _dim_violets(0.22) if layer == "base" else []
    if layer in EMISSION_ONLY:
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
    _restore_violets(dimmed)
    if restore:
        for o in bpy.data.objects:
            o.hide_render = False


def main():
    out, layers, dirs, frames, only, samples = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    qr_layout.build(gen.build_materials())
    qr_anim.animate(frames=frames)
    # Fit the model to the cone before posing it. Without this the driver
    # renders the UNFITTED geometry -- `_FIT` stays 1.0, because fit_cone()
    # lives in the generator's own main() and nothing here called it -- and the
    # sheets come out at the raw APEX the fit exists to bring down. That
    # shipped once: eight directions packed at 0.81-0.83 tiles of overhang
    # against vanilla's 0.77 ceiling, while the audit printed 0.77 and was
    # telling the truth about geometry nobody was rendering.
    gen.set_direction(0)
    gen._FIT[0] = gen.fit_cone()
    fr_rig.camera(scene, gen.CANVAS)
    fr_rig.lights(scene, key=gen.KEY, fill=gen.FILL, ambient=gen.AMBIENT)
    fr_rig.output(scene, gen.CANVAS)
    fr_rig.cycles(scene, samples=samples)
    fr_rig.use_gpu(scene)
    scene.render.use_persistent_data = True

    for d in dirs:
        mirror = d.startswith("flipped-")
        gen.set_direction(DIRECTIONS[d.replace("flipped-", "")], mirror=mirror)
        for layer in layers:
            target = os.path.join(out, d, layer)
            if layer == "shadow":
                render_shadow(scene, target)
            else:
                render_layer(scene, layer, target, frames, only,
                             restore=layer == "lamp")
            print("[render] %s/%s" % (d, layer))
    print("RENDER DONE:", ",".join(dirs), "x", ",".join(layers), "->", out)


main()
