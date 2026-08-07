# Headless render driver for the Pure beacon entity sprites.
#
#   blender -b -P render_entity.py -- <out_dir> [--layers base,anim,arcs,shadow,frozen,footprint]
#                                    [--frames N] [--only 3,8,55]
#
# Writes <out_dir>/<layer>/f####.png. Static layers render frame 0 only.
# --only renders just those frames of the loop, still numbered for their
# place in it -- for eyeballing one beat without paying for all 64.
#
# Rig: 64 px/tile "military projection" -- ortho camera pitched 45 deg with
# pixel_aspect_x = sqrt(2), which renders the ground plane square (footprint
# gate: the 5x5 test plane must land exactly 320x320 px) and world-Z heights
# at 64 px/unit. Calibrated by the footprint layer, do not tweak blind.
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

PX_PER_TILE = 64
CANVAS = (512, 640)
ORTHO_SCALE = 8.0          # tiles across CANVAS[0] -> 512/8 = 64 px/tile
PIXEL_ASPECT_X = 1.41421   # 1/cos(45): squares the foreshortened ground plane

LAYER_COLLS = {
    "base": ("PB_Base",),
    "anim": ("PB_Moving",),
    "arcs": ("PB_Arcs",),
    # deck plant that moves: holographic glyphs, cryo vapour, the shard's
    # pulse. Its own loop and its own crop box -- re-rendering the rings for
    # a vapour puff would cost 64 frames of the far larger anim sheet.
    "deck": ("PB_Deck",),
    "footprint": ("PB_Footprint",),
    # static geometry ONLY: a baked shadow of the floating rings/crystal lands
    # ~2 tiles right of the building as a detached, frozen blob (found in game)
    "shadow": ("PB_Base",),
    "slot-box": ("PB_SlotBox",),
    "slot-lights": ("PB_SlotLights",),
    # Aquilo frost overlay -- the whole machine, crystal and rings included.
    # Rendered at animation frame 0, which is why the prototype sets
    # reset_animation_when_frozen: a frozen beacon is pinned to that pose, so
    # the ice on the rings lands where the rings actually are. Vanilla's
    # centrifuge does exactly this for its drums.
    # PB_Deck is deliberately absent: the frozen layer swaps every material
    # for the snow shader, and the deck plant's animated parts are a
    # hologram, vapour and cable light -- none of which ice over. Their
    # static bodies are in PB_Base and do get frosted.
    "frozen": ("PB_Base", "PB_Moving"),
}
STATIC_LAYERS = {"base", "shadow", "footprint", "slot-box", "slot-lights", "frozen"}

# Render-region borders (min_x, min_y, max_x, max_y, bottom-up fractions) for
# layers whose content only covers the moving region -- saves ~70% per frame.
BORDERS = {
    "anim": (0.20, 0.52, 0.80, 1.0),
    # the arcs layer now runs the full height of the electrodes, from the
    # induction coil at the foot of a pylon to the core, so its region has to
    # reach down past the front pylon roots -- clipping it is silent
    "arcs": (0.16, 0.28, 0.84, 1.0),
}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        raise SystemExit("usage: blender -b -P render_entity.py -- <out_dir> [--layers a,b] [--frames N]")
    out_dir = argv[0]
    layers = ["base", "anim"]
    frames = 1
    only = None
    i = 1
    while i < len(argv):
        if argv[i] == "--layers":
            layers = argv[i + 1].split(",")
            i += 2
        elif argv[i] == "--frames":
            frames = int(argv[i + 1])
            i += 2
        elif argv[i] == "--only":
            only = [int(v) for v in argv[i + 1].split(",")]
            i += 2
        else:
            raise SystemExit("unknown arg: " + argv[i])
    return out_dir, layers, frames, only


def set_engine(scn):
    # Cycles for everything: the shadow pass needs it anyway, and its real
    # AO/GI is what makes crevices dark and parts sit together (EEVEE reads
    # flat by comparison -- tried, rejected).
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 96
    scn.cycles.use_denoising = True
    # The frozen layer turns every material into a mostly-transparent snow
    # mix, and a camera ray crossing this model meets far more than the
    # default 8 transparent surfaces -- the coil stacks alone are dozens of
    # helix wires. Past the limit Cycles gives up on the ray and returns
    # OPAQUE BLACK, which lands as soot blotches over exactly the densest
    # greeble. Nothing in the render warns about it; it just looks like a
    # shading bug.
    scn.cycles.transparent_max_bounces = 128


def rig():
    scn = bpy.context.scene

    cam_data = bpy.data.cameras.new("PB_Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ORTHO_SCALE
    cam_data.sensor_fit = "HORIZONTAL"
    cam_data.clip_start = 0.1
    cam_data.clip_end = 1000
    cam = bpy.data.objects.new("PB_Cam", cam_data)
    cam.location = (0, -60, 60)
    cam.rotation_euler = (math.radians(45), 0, 0)
    scn.collection.objects.link(cam)
    scn.camera = cam

    # Key sun from the upper LEFT so shadows fall right (vanilla-measured).
    key = bpy.data.lights.new("PB_Key", "SUN")
    key.energy = 5.2
    key_o = bpy.data.objects.new("PB_Key", key)
    key_o.rotation_euler = (0, math.radians(-39.3), math.radians(5))
    scn.collection.objects.link(key_o)

    # Soft front fill so the camera-facing side is never black.
    fill = bpy.data.lights.new("PB_Fill", "SUN")
    fill.energy = 1.2
    fill_o = bpy.data.objects.new("PB_Fill", fill)
    fill_o.rotation_euler = (math.radians(45), 0, 0)
    scn.collection.objects.link(fill_o)

    world = bpy.data.worlds.new("PB_World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 0.22
    scn.world = world

    scn.render.resolution_x, scn.render.resolution_y = CANVAS
    scn.render.pixel_aspect_x = PIXEL_ASPECT_X
    scn.render.pixel_aspect_y = 1.0
    scn.render.film_transparent = True
    scn.render.image_settings.file_format = "PNG"
    scn.render.image_settings.color_mode = "RGBA"
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.look = "None"


def show_only(layer):
    all_colls = {name for names in LAYER_COLLS.values() for name in names}
    for coll_name in all_colls:
        c = bpy.data.collections.get(coll_name)
        if c:
            c.hide_render = True
    for coll_name in LAYER_COLLS.get(layer, ()):
        bpy.data.collections[coll_name].hide_render = False


def set_border(layer):
    scn = bpy.context.scene
    border = BORDERS.get(layer)
    scn.render.use_border = border is not None
    scn.render.use_crop_to_border = False
    if border:
        (scn.render.border_min_x, scn.render.border_min_y,
         scn.render.border_max_x, scn.render.border_max_y) = border


def render_layer(layer, out_dir, frames, only=None):
    import beacon_gen
    scn = bpy.context.scene
    show_only(layer)
    set_border(layer)
    # The frozen layer renders the same geometry as base, with every material
    # swapped for the snow shader -- so the only thing that survives to film
    # is the accumulation, and the machine underneath stays transparent.
    bpy.context.view_layer.material_override = (
        beacon_gen.snow_override() if layer == "frozen" else None)
    layer_dir = os.path.join(out_dir, layer)
    os.makedirs(layer_dir, exist_ok=True)
    todo = [0] if layer in STATIC_LAYERS else (only or list(range(frames)))
    for f in todo:
        scn.frame_set(f)
        if layer == "arcs":
            beacon_gen.update_arcs(f, frames)
        scn.render.filepath = os.path.join(layer_dir, "f%04d.png" % f)
        bpy.ops.render.render(write_still=True)
    bpy.context.view_layer.material_override = None


def render_shadow(out_dir, frames):
    # Cycles shadow catcher: geometry casts but is hidden from camera, so the
    # output is the ground shadow alone on transparent film.
    scn = bpy.context.scene
    show_only("shadow")
    set_border("shadow")
    scn.frame_set(0)
    bpy.ops.mesh.primitive_plane_add(size=14, location=(0, 0, 0))
    catcher = bpy.context.object
    catcher.name = "PB_ShadowCatcher"
    catcher.is_shadow_catcher = True
    meshes = [o for o in bpy.data.objects
              if o.name.startswith("PB_") and o is not catcher and o.type in ("MESH", "CURVE")]
    for o in meshes:
        o.visible_camera = False
    layer_dir = os.path.join(out_dir, "shadow")
    os.makedirs(layer_dir, exist_ok=True)
    scn.render.filepath = os.path.join(layer_dir, "f0000.png")
    bpy.ops.render.render(write_still=True)
    for o in meshes:
        o.visible_camera = True
    bpy.data.objects.remove(catcher, do_unlink=True)


def main():
    out_dir, layers, frames, only = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    import beacon_gen
    objs = beacon_gen.build_scene()
    # The frozen layer needs the moving parts keyed even when it is the only
    # layer being rendered, so frame 0 is the same pose the anim sheet opens on
    # rather than wherever build_scene happened to leave them.
    # Always pose the scene, even for a one-frame test: the deck plant's
    # vapour and cable pulses are keyframed, so an unanimated frame 0 leaves
    # every puff stacked on the vent mouth.
    beacon_gen.animate(objs, frames=frames if frames > 1 else 64)
    rig()
    scn = bpy.context.scene
    set_engine(scn)
    for layer in layers:
        if layer == "shadow":
            render_shadow(out_dir, frames)
        else:
            render_layer(layer, out_dir, frames, only)
    print("RENDER DONE:", ",".join(layers), "->", out_dir)


main()
