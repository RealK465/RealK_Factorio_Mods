# Headless render driver for the Quality Assembler.
#
#   blender -b -P render_entity.py -- <ABSOLUTE out_dir>
#       [--layers base,anim,run,fast,shadow,glow,lamp,pipes] [--frames N]
#       [--only 0,8] [--samples 96]
#
# Writes <out_dir>/<layer>/f####.png. Static layers render frame 0 only.
# ABSOLUTE path, always: Blender resolves a relative render.filepath against
# its own working directory and writes the run to somewhere like C:\renders.
#
# One elevation. An assembling machine's art is not directional -- the engine
# rotates only the fluid pipe pictures -- so there is no direction loop here,
# and the pipe stubs are rendered once each for the four pipe_picture keys.
#
# The layers, and which engine slot each one fills (qa_gen.py has the why):
#
#   base    the body, one frame                       graphics_set.animation
#   anim    the CRAFT loop: drive train, turntable,    graphics_set.animation
#           lock, arm, valves, gauges, louvres         (plays while crafting)
#   run     the REFRIGERATION, slow: fan, flywheel,    working_visualisation,
#           pulley, cabinet fan, compressor needle     always_draw + constant_speed
#   fast    fan, flywheel and pulley keyed fast,       working_visualisation,
#           made opaque by make_sheets.py              working only, fadeout
#   glow    what the cell throws, plus the vent puff   working_visualisation, glow
#   lamp    the three always-on points, pulsing        working_visualisation,
#                                                      always_draw + constant_speed
#   shadow  one frame, everything that casts           draw_as_shadow
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import qa_gen as gen                                        # noqa: E402
import qa_layout                                            # noqa: E402

sys.path.insert(0, gen._skill_scripts())
from factorio_render import rig as fr_rig                   # noqa: E402

# The semi-transparent parts: a holdout of one leaves a ghost with alpha up
# to about 40/255 over its whole footprint, and a crop box grows to the ghost
GLASS = ("window-glass", "sight-dome")

# Which collections each layer draws, and how the RUN parts are keyed for it.
#
# `anim`, `run` and `fast` keep QA_Base as a HOLDOUT rather than hiding it:
# all three composite ABOVE the base in game, so a moving part that ought to
# be hidden behind the hull would otherwise draw straight over it. A holdout
# punches alpha-0 where the nearer object is, which is exactly the occlusion
# the composite cannot work out for itself.
LAYERS = {
    "base":   dict(show=("QA_Base",), holdout=(), run="slow"),
    # Nothing animated stands behind the glass sight dome, so it is hidden
    # in every holdout layer; the window pane stays in the anim layer's
    # holdout because the turntable and the arm ARE behind it.
    "anim":   dict(show=("QA_Craft",), holdout=("QA_Base",), run="slow", hide=GLASS[1:]),
    # Nothing in the run and fast layers stands behind the window, and a
    # semi-transparent holdout leaves a faint ghost of the pane: the fast
    # layer's opaque mask then swallowed the whole window and would have
    # drawn a copy of the empty cell OVER the turntable while working. The
    # sight dome did the same to the fast fan's box (74 x 158 px) and to
    # every pipe picture until it was hidden too.
    "run":    dict(show=("QA_Run",), holdout=("QA_Base",), run="slow", hide=GLASS),
    "fast":   dict(show=("QA_Run",), holdout=("QA_Base",), run="fast", only=gen.FAST_KINDS,
                   hide=GLASS),
    # Emission-only, every light and the world off: what reaches the film IS
    # the emission -- and the cell's ceiling lamp lighting the turntable
    # counts, because Cycles bounces mesh light. That is what the window
    # throws when the machine works, which is what an additive glow sprite is.
    # The vent puff lives in QA_Glow and is drawn nowhere else.
    "glow":   dict(show=("QA_Base", "QA_Craft", "QA_Run", "QA_Glow"), holdout=(), run="slow",
                   emission=True),
    # The always-on lamps alone: the status lamp, the amber running lamp and
    # the violet family point. 64 frames -- they pulse -- of a few dozen px.
    "lamp":   dict(show=("QA_Base",), holdout=(), run="slow", emission=True,
                   only=("lamp-face", "amber-lamp", "modrack-violet", "console-lamp")),
    "shadow": dict(show=("QA_Base", "QA_Craft", "QA_Run"), holdout=(), run="slow"),
}
STATIC = {"base", "shadow"}
ALL_COLLS = gen.COLL_NAMES

# Emission strength of each lit material in the BASE pass. The base is drawn
# in every state, so an emissive lit in it lights the IDLE machine; the base
# carries the dim "cold and waiting" glow and the glow sheet carries the rest.
# The three always-on lamps are zeroed here and drawn by the lamp layer.
# Measured in the engine (2026-09-13): at celllamp 0.30 the idle window read
# at luminance 88 against the working one's 101-125 -- nearly as lit. Idle is
# "cold and waiting", not "on".
BASE_DIM = {"cyan": 0.10, "celllamp": 0.10, "cyanfloor": 0.05, "screen": 0.18,
            "strip": 0.08, "sightlamp": 0.10,
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


def show_only(show, holdout, only=None, hide=()):
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
            if only and name in show:
                obj.hide_render = not any(obj.name.startswith(gen.PREFIX + k) for k in only)
            else:
                obj.hide_render = False
            if any(obj.name == gen.PREFIX + h for h in hide):
                obj.hide_render = True


def _set_strengths(strengths):
    """Override emission strengths, suspending the material's own keyed
    animation while the override stands."""
    saved = []
    for name, strength in strengths.items():
        mat = bpy.data.materials.get(gen.PREFIX + name)
        if not mat or not mat.node_tree:
            continue
        ad = mat.node_tree.animation_data
        action = ad.action if ad else None
        if ad:
            ad.action = None
        sock = gen._emission_socket(name)
        if sock is None:
            continue
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
    show_only(LAYERS["shadow"]["show"], ())
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
    show_only(spec["show"], spec["holdout"], spec.get("only"), spec.get("hide", ()))
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
                c.hide_render = name == "QA_Glow"
        for obj in bpy.data.objects:
            if not obj.name.startswith(gen.PREFIX) or obj.type not in ("MESH", "CURVE", "EMPTY"):
                continue
            is_stub = obj.name.startswith(gen.PREFIX + "stub-")
            mine = obj.name.startswith(gen.PREFIX + "stub-" + key)
            # the glass is hidden outright: a semi-transparent holdout
            # leaves a faint ghost of the pane (and of the sight dome) in
            # every stub picture, and the crop box grows to the ghost
            obj.hide_render = (is_stub and not mine) or any(obj.name == gen.PREFIX + g for g in GLASS)
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
    fr_rig.camera(scene, gen.CANVAS)
    fr_rig.lights(scene, key=gen.KEY, fill=gen.FILL, ambient=gen.AMBIENT)
    fr_rig.output(scene, gen.CANVAS)
    fr_rig.cycles(scene, samples=samples)
    scene.render.use_persistent_data = True

    keyed = None
    for layer in layers:
        if layer == "pipes":
            render_pipes(scene, out)
            continue
        want = LAYERS[layer]["run"]
        if keyed != want:
            gen.animate(frames=frames, run=want)
            keyed = want
        target = os.path.join(out, layer)
        if layer == "shadow":
            render_shadow(scene, target)
        else:
            render_layer(scene, layer, target, frames, only)
        print("[render] %s" % layer)
    print("RENDER DONE:", ",".join(layers), "->", out)


main()
