# Headless render driver for the Quality Assembler.
#
#   blender -b -P render_entity.py -- <ABSOLUTE out_dir>
#       [--layers base,anim,idle,shadow,glow,lamp,pipes] [--frames N]
#       [--only 0,8] [--samples 96]
#
# Writes <out_dir>/<layer>/f####.png. Static layers render frame 0 only.
# ABSOLUTE path, always: Blender resolves a relative render.filepath against
# its own working directory and writes the run to somewhere like C:\renders.
#
# One elevation. An assembling machine's art is not directional -- the engine
# rotates only the fluid pipe pictures -- so there is no direction loop here,
# and the pipe stubs are rendered once each for the four pipe_picture keys.
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import qa_gen as gen                                        # noqa: E402
import qa_layout                                            # noqa: E402

sys.path.insert(0, gen._skill_scripts())
from factorio_render import rig as fr_rig                   # noqa: E402

# Which collections each layer draws.
#
# `anim` and `idle` keep QA_Base as a HOLDOUT rather than hiding it: both
# composite ABOVE the base in game, so a moving part that ought to be hidden
# behind the hull would otherwise draw straight over it. A holdout punches
# alpha-0 where the nearer object is, which is exactly the occlusion the
# composite cannot work out for itself.
LAYERS = {
    "base":   dict(show=("QA_Base",), holdout=(), idle=False),
    "anim":   dict(show=("QA_Moving",), holdout=("QA_Base",), idle=False),
    "idle":   dict(show=("QA_Moving",), holdout=("QA_Base",), idle=True),
    # Emission-only, every light and the world off: what reaches the film IS
    # the emission -- and the cell's ceiling lamp lighting the turntable
    # counts, because Cycles bounces mesh light. That is what the window
    # throws when the machine works, which is what an additive glow sprite is.
    "glow":   dict(show=("QA_Base", "QA_Moving"), holdout=(), idle=False, emission=True),
    # The always-on lamps alone: the status lamp, the amber running lamp and
    # the violet family point. One frame, a few dozen pixels.
    "lamp":   dict(show=("QA_Base",), holdout=(), idle=False, emission=True,
                   only=("lamp-face", "amber-lamp", "modrack-violet")),
    "shadow": dict(show=("QA_Base", "QA_Moving"), holdout=(), idle=False),
}
STATIC = {"base", "shadow", "lamp"}
ALL_COLLS = ("QA_Base", "QA_Moving", "QA_Pipe")

# Emission strength of each lit material in the BASE pass. The base is drawn
# in every state, so an emissive lit in it lights the IDLE machine; the base
# carries the dim "cold and waiting" glow and the glow sheet carries the rest.
# The three always-on lamps are zeroed here and drawn by the lamp layer.
# Measured in the engine (2026-09-13): at celllamp 0.30 the idle window read
# at luminance 88 against the working one's 101-125 -- nearly as lit. Idle is
# "cold and waiting", not "on".
BASE_DIM = {"cyan": 0.10, "celllamp": 0.10, "cyanfloor": 0.05, "screen": 0.18,
            "cyanlamp": 0.0, "amber": 0.0, "violet": 0.0}
# ...and in the GLOW pass the always-on lamps are zeroed so they are not
# added twice.
GLOW_ZERO = {"cyanlamp": 0.0, "amber": 0.0, "violet": 0.0}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        raise SystemExit("usage: blender -b -P render_entity.py -- <out_dir> "
                         "[--layers a,b] [--frames N] [--only 0,8]")
    out, layers = argv[0], ["base"]
    frames, only, samples = 64, None, 96
    i = 1
    while i < len(argv):
        if argv[i] == "--layers":
            layers = argv[i + 1].split(",")
        elif argv[i] == "--frames":
            frames = int(argv[i + 1])
        elif argv[i] == "--only":
            only = [int(v) for v in argv[i + 1].split(",")]
        elif argv[i] == "--samples":
            samples = int(argv[i + 1])
        else:
            raise SystemExit("unknown arg: " + argv[i])
        i += 2
    return out, layers, frames, only, samples


def show_only(show, holdout, only=None):
    for name in ALL_COLLS:
        c = bpy.data.collections.get(name)
        if c:
            c.hide_render = name not in show and name not in holdout
    for name in ALL_COLLS:
        c = bpy.data.collections.get(name)
        if not c:
            continue
        held = name in holdout
        for obj in c.objects:
            obj.is_holdout = held
            if only:
                obj.hide_render = not any(obj.name.startswith(gen.PREFIX + k) for k in only)
            else:
                obj.hide_render = False


def _set_strengths(strengths):
    saved = []
    for name, strength in strengths.items():
        mat = bpy.data.materials.get(gen.PREFIX + name)
        if not mat or not mat.node_tree:
            continue
        ad = mat.node_tree.animation_data
        action = ad.action if ad else None
        if ad:
            ad.action = None
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        sock = bsdf.inputs["Emission Strength"]
        saved.append((mat, action, sock, sock.default_value))
        sock.default_value = strength
    return saved


def _restore_strengths(saved):
    for mat, action, sock, value in saved:
        sock.default_value = value
        if action is not None and mat.node_tree.animation_data:
            mat.node_tree.animation_data.action = action


def _lights_off(scene):
    dark = []
    for o in bpy.data.objects:
        if o.type == "LIGHT":
            dark.append((o.data, o.data.energy))
            o.data.energy = 0.0
    bg = scene.world.node_tree.nodes["Background"] if scene.world else None
    if bg:
        sock = bg.inputs["Strength"]
        dark.append((sock, sock.default_value))
        sock.default_value = 0.0
    return dark


def _lights_on(dark):
    for holder, value in dark:
        if hasattr(holder, "energy"):
            holder.energy = value
        else:
            holder.default_value = value


def render_shadow(scene, out_dir):
    show_only(("QA_Base", "QA_Moving"), ())
    scene.frame_set(0)
    # 0.005 below ground, never level with it: a catcher plane exactly at the
    # model's ground level is coplanar with every foot, and two shells sharing
    # an exactly coplanar face render OPAQUE BLACK in Cycles.
    bpy.ops.mesh.primitive_plane_add(size=16, location=(0, 0, -0.005))
    catcher = bpy.context.object
    catcher.name = "QA_ShadowCatcher"
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


def render_layer(scene, layer, out_dir, frames, only):
    spec = LAYERS[layer]
    show_only(spec["show"], spec["holdout"], spec.get("only"))
    dark, dimmed = [], []
    if layer == "base":
        dimmed = _set_strengths(BASE_DIM)
    if spec.get("emission"):
        dark = _lights_off(scene)
        if layer == "glow":
            dimmed = _set_strengths(GLOW_ZERO)
    os.makedirs(out_dir, exist_ok=True)
    todo = [0] if layer in STATIC else (only or list(range(frames)))
    for f in todo:
        scene.frame_set(f)
        scene.render.filepath = os.path.join(out_dir, "f%04d.png" % f)
        bpy.ops.render.render(write_still=True)
    _lights_on(dark)
    _restore_strengths(dimmed)
    for o in bpy.data.objects:
        if o.name.startswith(gen.PREFIX):
            o.hide_render = False


def render_pipes(scene, out):
    """One picture per pipe_picture key. The hull is a HOLDOUT, so the sprite
    carries only what stands outside it -- the south, east and west pictures
    are drawn in front of the entity, and a stub drawn over the skid's top
    would read as a pipe lying on the deck."""
    scene.frame_set(0)
    for key in ("N", "S", "E", "W"):
        for name in ALL_COLLS:
            c = bpy.data.collections.get(name)
            if c:
                c.hide_render = False
        for obj in bpy.data.objects:
            if not obj.name.startswith(gen.PREFIX) or obj.type not in ("MESH", "CURVE", "EMPTY"):
                continue
            is_stub = obj.name.startswith(gen.PREFIX + "stub-")
            mine = obj.name.startswith(gen.PREFIX + "stub-" + key)
            # the glass pane is hidden outright: a semi-transparent holdout
            # leaves a faint ghost of the window in every stub picture, and
            # the crop box grows to the ghost
            obj.hide_render = (is_stub and not mine) or obj.name == gen.PREFIX + "window-glass"
            obj.is_holdout = not is_stub
        target = os.path.join(out, "pipe-" + key)
        os.makedirs(target, exist_ok=True)
        scene.render.filepath = os.path.join(target, "f0000.png")
        bpy.ops.render.render(write_still=True)
        print("[render] pipe-%s" % key)
    for obj in bpy.data.objects:
        if obj.name.startswith(gen.PREFIX):
            obj.is_holdout = False
            obj.hide_render = False


def main():
    out, layers, frames, only, samples = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    qa_layout.build(gen.build_materials())
    gen.organise()
    gen.animate(frames=frames, idle=False)
    fr_rig.camera(scene, gen.CANVAS)
    fr_rig.lights(scene, key=gen.KEY, fill=gen.FILL, ambient=gen.AMBIENT)
    fr_rig.output(scene, gen.CANVAS)
    fr_rig.cycles(scene, samples=samples)
    scene.render.use_persistent_data = True

    posed_idle = False
    # the idle loop last: it re-keys the scene, and everything else wants
    # the working loop
    order = [l for l in layers if l != "idle"] + (["idle"] if "idle" in layers else [])
    for layer in order:
        if layer == "pipes":
            render_pipes(scene, out)
            continue
        if layer == "idle" and not posed_idle:
            gen.animate(frames=frames, idle=True)
            posed_idle = True
        target = os.path.join(out, layer)
        if layer == "shadow":
            render_shadow(scene, target)
        else:
            render_layer(scene, layer, target, frames, only)
        print("[render] %s" % layer)
    print("RENDER DONE:", ",".join(layers), "->", out)


main()
