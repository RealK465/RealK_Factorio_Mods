# Item and technology icons for the Quality Assembler.
#
#   blender -b -P render_icon.py -- <ABSOLUTE out_dir>
#
# Writes <out_dir>/icon-raw.png at 512. make_icons.py does the rest.
#
# Icons follow references/icons.md, NOT the entity rig: they are not on the
# tile grid, so ortho_scale/footprint/px-per-tile are irrelevant, and the
# lighting is far lower -- vanilla icons carry deep near-black crevices and a
# strong dark side where the entity key would flatten them to pale plastic.
#
# The model is turned corner-on rather than the camera, so the key's direction
# in image space stays put. The whole machine is framed, the way vanilla frames
# its machine icons (the recycler mod learned that: two icons cropped into the
# hero were rejected as "not showing the totality of the machine").
import math
import os
import sys

import bpy
from mathutils import Vector

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

RES = 512
# 4.6 units of ortho covers the 3x3's corner-on extent with the riser and the
# compressor plate; make_icons.py trims to the subject anyway.
ORTHO = 4.6
# 50 degrees: the machine is 1.9 tiles tall on a 3-tile footprint, and
# vanilla's machine icons fill a near-square box. A lower camera would show
# more of the window and less of the deck; this one keeps the two halves and
# the cold vessel's top both readable.
ELEVATION = 47.0
ROLL = -5.0
# Turned clockwise so the SOUTH-EAST corner comes forward: the cold vessel,
# the hero, stands in front with its window toward the camera, and the blue
# half with the module rack sits behind and to the left. Turned the other way
# the first icon put the compressor in front and the hero at the back.
MODEL_YAW = -32.0
AIM = (0.0, 0.0, 0.62)


def look_at(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else "."
    os.makedirs(out, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    import qa_gen as gen
    import qa_layout
    scene = bpy.context.scene
    qa_layout.build(gen.build_materials())
    gen.organise()
    gen.animate(frames=64)
    bpy.data.collections["QA_Pipe"].hide_render = True
    scene.frame_set(20)

    # turn the machine, not the camera: one root, every part under it
    root = bpy.data.objects.new(gen.PREFIX + "root", None)
    scene.collection.objects.link(root)
    for obj in [o for o in bpy.data.objects
                if o.name.startswith(gen.PREFIX) and o.parent is None and o is not root]:
        obj.parent = root
        obj.matrix_parent_inverse = root.matrix_world.inverted()
    root.rotation_euler = (0, 0, math.radians(MODEL_YAW))
    bpy.context.view_layer.update()

    cam_data = bpy.data.cameras.new("QA_IconCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ORTHO
    cam = bpy.data.objects.new("QA_IconCam", cam_data)
    r = 12.0
    e = math.radians(ELEVATION)
    cam.location = (0.0, -r * math.cos(e), r * math.sin(e) + 0.6)
    scene.collection.objects.link(cam)
    look_at(cam, AIM)
    cam.rotation_euler.rotate_axis("Z", math.radians(ROLL))
    scene.camera = cam

    for name, loc, energy, colour in (
            ("Key",  (-3.0, -1.6, 4.6), 5.4, (1.0, 0.97, 0.92)),
            ("Fill", (2.8, -3.6, 0.7), 1.00, (1.0, 1.0, 1.0)),
            ("Rim",  (1.6, 3.4, 2.6), 0.60, (0.78, 0.86, 1.0))):
        d = bpy.data.lights.new("QA_Icon" + name, "SUN")
        d.energy = energy
        d.color = colour
        o = bpy.data.objects.new("QA_Icon" + name, d)
        o.location = loc
        scene.collection.objects.link(o)
        look_at(o, (0, 0, 0.75))

    world = bpy.data.worlds.new("QA_IconWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 0.12
    scene.world = world

    scene.render.resolution_x = scene.render.resolution_y = RES
    scene.render.pixel_aspect_x = scene.render.pixel_aspect_y = 1.0
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    fr_rig.cycles(scene, samples=128)

    scene.render.filepath = os.path.join(out, "icon-raw.png")
    bpy.ops.render.render(write_still=True)
    print("ICON DONE:", scene.render.filepath)


main()
