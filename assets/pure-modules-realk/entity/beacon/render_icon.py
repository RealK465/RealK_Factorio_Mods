# Renders the beacon icon still for export_icon.py.
#
#   blender -b -P render_icon.py -- <out_dir>
#
# Icon rig per .claude/skills/factorio-graphics/references/icons.md: square
# frame, elevation 46 deg, roll -6, low icon lighting (a hot key flattens the
# icon to plastic), Cycles denoised. Bloom happens in export_icon.py, never
# here -- it must extend the PNG's alpha.
import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

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

TARGET = Vector((0, 0, 1.55))


def aim(obj, look_dir, roll_deg=0.0):
    # to_track_quat("-Z", "Y") takes the direction the -Z axis should face,
    # i.e. the LOOK direction (target minus position), not the offset from it
    quat = look_dir.to_track_quat("-Z", "Y")
    if roll_deg:
        quat = quat @ Quaternion((0, 0, 1), math.radians(roll_deg))
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = quat


def sun(name, from_pos, energy, color=(1, 1, 1)):
    data = bpy.data.lights.new(name, "SUN")
    data.energy = energy
    data.color = color
    obj = bpy.data.objects.new(name, data)
    aim(obj, -Vector(from_pos))
    bpy.context.scene.collection.objects.link(obj)
    return obj


def main():
    out_dir = sys.argv[sys.argv.index("--") + 1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    import beacon_gen
    beacon_gen.build_scene()

    for coll_name in ("PB_Arcs", "PB_Footprint", "PB_SlotEmpty", "PB_SlotBox", "PB_SlotLights"):
        c = bpy.data.collections.get(coll_name)
        if c:
            c.hide_render = True

    scn = bpy.context.scene
    elev = math.radians(46)
    cam_pos = TARGET + Vector((0, -math.cos(elev), math.sin(elev))) * 40
    cam_data = bpy.data.cameras.new("PB_IconCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 5.9
    cam_data.clip_end = 1000
    cam = bpy.data.objects.new("PB_IconCam", cam_data)
    cam.location = cam_pos
    aim(cam, TARGET - cam_pos, roll_deg=-6)
    scn.collection.objects.link(cam)
    scn.camera = cam

    sun("PB_IconKey", (-3.0, -1.6, 4.6), 3.0)
    sun("PB_IconFill", (2.8, -3.6, 0.7), 0.25)
    sun("PB_IconRim", (1.6, 3.4, 2.6), 0.45, color=(0.8, 0.9, 1.0))

    world = bpy.data.worlds.new("PB_IconWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 0.05
    scn.world = world

    scn.render.engine = "CYCLES"
    fr_rig.use_gpu(scn)
    scn.cycles.samples = 128
    scn.cycles.use_denoising = True
    scn.render.use_persistent_data = True
    scn.render.resolution_x = scn.render.resolution_y = 512
    scn.render.pixel_aspect_x = scn.render.pixel_aspect_y = 1.0
    scn.render.film_transparent = True
    scn.render.image_settings.file_format = "PNG"
    scn.render.image_settings.color_mode = "RGBA"
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.look = "None"

    os.makedirs(out_dir, exist_ok=True)
    scn.render.filepath = os.path.join(out_dir, "pure-beacon.png")
    bpy.ops.render.render(write_still=True)
    print("ICON RENDER DONE:", scn.render.filepath)


main()
