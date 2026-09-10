"""Render the mythic and celestial technology dies.

    blender -b -P render_tech_icons.py -- <out_dir>

Writes <out_dir>/mythic-raw.png and celestial-raw.png at 512. make_tech_icons.py does the
drop shadow, the mipmap strips and the thumbnail.

Follows references/icons.md, not the entity rig: an icon is not on the tile grid, so
ortho_scale and px-per-tile mean nothing here, and the lighting is far lower - vanilla icons
carry deep near-black crevices where the entity key would flatten them to pale plastic.

The model turns corner-on, not the camera, so the key's direction in image space stays put.
"""

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
from factorio_render import rig as fr_rig                    # noqa: E402

RES = 512
ORTHO = 3.45         # the die's corner-on diagonal is 2.83; icons run edge to edge
ELEVATION = 40.0     # enough top face for the pips to read as a rhombus, not a stripe
ROLL = -5.0
MODEL_YAW = 45.0     # corner-on: the two lower tiers face front-left and front-right
MODEL_TILT = -7.0    # a die that sits perfectly square reads as a render, not a prop

# All four quality technologies, vanilla's two included: one die, one material, one camera.
# Each shows the tier it unlocks on top and the two below it on the visible side faces, which
# is the rule vanilla's own two follow.
ICONS = [
    # name, top face, left face, right face
    ("epic-quality", (4, "epic"), (2, "uncommon"), (3, "rare")),
    ("legendary-quality", (5, "legendary"), (3, "rare"), (4, "epic")),
    ("mythic-quality", (6, "mythic"), (4, "epic"), (5, "legendary")),
    ("celestial-quality", (7, "celestial"), (5, "legendary"), (6, "mythic")),
]


def look_at(obj, target):
    # to_track_quat takes the LOOK direction - target minus position. Passing the offset
    # FROM the target aims it exactly backwards and renders blank.
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def setup_camera(scene):
    data = bpy.data.cameras.new("ICON_Cam")
    data.type = "ORTHO"
    data.ortho_scale = ORTHO
    cam = bpy.data.objects.new("ICON_Cam", data)
    r = 12.0
    e = math.radians(ELEVATION)
    cam.location = (0.0, -r * math.cos(e), r * math.sin(e))
    scene.collection.objects.link(cam)
    look_at(cam, (0, 0, 0))
    # Roll about the camera's OWN axis, after aiming. Stuffing it into rotation_euler[1]
    # swings the aim off target and silently crops the subject.
    cam.rotation_euler.rotate_axis("Z", math.radians(ROLL))
    scene.camera = cam


def setup_lights(scene):
    for name, loc, energy, colour in (
            ("Key", (-3.0, -1.6, 4.6), 3.0, (1.0, 0.97, 0.92)),
            ("Fill", (2.8, -3.6, 0.7), 0.25, (1.0, 1.0, 1.0)),
            ("Rim", (1.6, 3.4, 2.6), 0.45, (0.78, 0.86, 1.0))):
        d = bpy.data.lights.new("ICON_" + name, "SUN")
        d.energy = energy
        d.color = colour
        o = bpy.data.objects.new("ICON_" + name, d)
        o.location = loc
        scene.collection.objects.link(o)
        look_at(o, (0, 0, 0))

    world = bpy.data.worlds.new("ICON_World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 0.05
    scene.world = world


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else "."
    os.makedirs(out, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    import die_gen as gen

    scene = bpy.context.scene
    setup_camera(scene)
    setup_lights(scene)

    scene.render.resolution_x = scene.render.resolution_y = RES
    scene.render.pixel_aspect_x = scene.render.pixel_aspect_y = 1.0
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    fr_rig.cycles(scene, samples=160)

    for name, top, left, right in ICONS:
        die, gems = gen.build(top[0], top[1], left, right)

        pivot = bpy.data.objects.new(gen.PREFIX + "pivot", None)
        scene.collection.objects.link(pivot)
        pivot.rotation_euler = (0, math.radians(MODEL_TILT), math.radians(MODEL_YAW))
        for obj in [die] + gems:
            obj.parent = pivot
            obj.matrix_parent_inverse = pivot.matrix_world.inverted()

        scene.render.filepath = os.path.join(out, "%s-raw.png" % name)
        bpy.ops.render.render(write_still=True)
        print("ICON DONE:", scene.render.filepath)


main()
