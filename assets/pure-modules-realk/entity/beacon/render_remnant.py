# Headless render driver for the Pure beacon's remnants.
#
#   blender -b -P render_remnant.py -- <out_dir> [--layers wreck,shadow,footprint]
#                                                [--variations 2]
#
# Writes <out_dir>/v<N>/<layer>/f0000.png.
#
# The rig is the entity's, unchanged and deliberately: same 64 px/tile ortho
# camera, same pixel_aspect_x, same sun. A remnant has to line up with the tile
# footprint the building stood on, and matching the camera is what guarantees
# that. Only the canvas shrinks -- the wreck is flat, so there is no 4.9-tile
# pylon overhang to leave room for.
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
def _skill_scripts(start=None):
    """Find .claude/skills/factorio-graphics/scripts by walking up.

    Not a fixed number of "..": these scripts are run headless by Blender, by
    python, and by exec() from Blender's console, and only some of those give
    __file__ a real value.
    """
    d = os.path.abspath(start or globals().get("__file__") or os.getcwd())
    if os.path.isfile(d):
        d = os.path.dirname(d)
    while True:
        c = os.path.join(d, ".claude", "skills", "factorio-graphics", "scripts")
        if os.path.isdir(c):
            return c
        parent = os.path.dirname(d)
        if parent == d:
            raise RuntimeError("factorio-graphics scripts not found above " + str(start))
        d = parent


sys.path.insert(0, _skill_scripts())

from factorio_render import rig as fr_rig

CANVAS = (576, 576)
ORTHO_SCALE = 9.0          # 576/9 -> 64 px/tile, same as the entity
PIXEL_ASPECT_X = 1.41421   # 1/cos(45): squares the foreshortened ground plane

LAYER_COLLS = {
    "wreck": ("PBR_Wreck",),
    "shadow": ("PBR_Wreck",),
    "footprint": ("PBR_Footprint",),
}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        raise SystemExit("usage: blender -b -P render_remnant.py -- <out_dir> "
                         "[--layers wreck,shadow] [--variations N]")
    out_dir = argv[0]
    layers = ["wreck", "shadow"]
    variations = 2
    i = 1
    while i < len(argv):
        if argv[i] == "--layers":
            layers = argv[i + 1].split(",")
            i += 2
        elif argv[i] == "--variations":
            variations = int(argv[i + 1])
            i += 2
        else:
            raise SystemExit("unknown arg: " + argv[i])
    return out_dir, layers, variations


def set_engine(scn):
    scn.render.engine = "CYCLES"
    fr_rig.use_gpu(scn)
    scn.cycles.samples = 96
    scn.cycles.use_denoising = True
    scn.render.use_persistent_data = True


def rig():
    scn = bpy.context.scene

    cam_data = bpy.data.cameras.new("RIG_Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ORTHO_SCALE
    cam_data.sensor_fit = "HORIZONTAL"
    cam_data.clip_start = 0.1
    cam_data.clip_end = 1000
    cam = bpy.data.objects.new("RIG_Cam", cam_data)
    cam.location = (0, -60, 60)
    cam.rotation_euler = (math.radians(45), 0, 0)
    scn.collection.objects.link(cam)
    scn.camera = cam

    key = bpy.data.lights.new("RIG_Key", "SUN")
    key.energy = 5.2
    key_o = bpy.data.objects.new("RIG_Key", key)
    key_o.rotation_euler = (0, math.radians(-39.3), math.radians(5))
    scn.collection.objects.link(key_o)

    fill = bpy.data.lights.new("RIG_Fill", "SUN")
    fill.energy = 1.2
    fill_o = bpy.data.objects.new("RIG_Fill", fill)
    fill_o.rotation_euler = (math.radians(45), 0, 0)
    scn.collection.objects.link(fill_o)

    world = bpy.data.worlds.new("RIG_World")
    world.use_nodes = True
    bg_node = world.node_tree.nodes["Background"]
    bg_node.inputs["Color"].default_value = (1, 1, 1, 1)
    bg_node.inputs["Strength"].default_value = 0.22
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
    for names in LAYER_COLLS.values():
        for name in names:
            c = bpy.data.collections.get(name)
            if c:
                c.hide_render = True
    for name in LAYER_COLLS.get(layer, ()):
        bpy.data.collections[name].hide_render = False


def render_layer(layer, out_dir):
    scn = bpy.context.scene
    show_only(layer)
    layer_dir = os.path.join(out_dir, layer)
    os.makedirs(layer_dir, exist_ok=True)
    scn.render.filepath = os.path.join(layer_dir, "f0000.png")
    bpy.ops.render.render(write_still=True)


def render_shadow(out_dir):
    # Cycles shadow catcher. Unlike the entity's, every part of a wreck is
    # static, so a baked shadow can never drift out from under a moving piece.
    scn = bpy.context.scene
    show_only("shadow")
    bpy.ops.mesh.primitive_plane_add(size=16, location=(0, 0, 0))
    catcher = bpy.context.object
    catcher.name = "RIG_ShadowCatcher"
    for c in list(catcher.users_collection):
        c.objects.unlink(catcher)
    scn.collection.objects.link(catcher)   # never inside a hidden layer collection
    catcher.is_shadow_catcher = True
    meshes = [o for o in bpy.data.objects
              if o.name.startswith("PBR_")
              and o.type in ("MESH", "CURVE")]
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
    out_dir, layers, variations = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    import remnant_gen
    rig()
    scn = bpy.context.scene
    set_engine(scn)
    for v in range(variations):
        remnant_gen.build_scene(variation=v)
        vdir = os.path.join(out_dir, "v%d" % v)
        for layer in layers:
            if layer == "shadow":
                render_shadow(vdir)
            else:
                render_layer(layer, vdir)
        print("VARIATION DONE:", v)
    print("RENDER DONE:", ",".join(layers), "->", out_dir)


main()
