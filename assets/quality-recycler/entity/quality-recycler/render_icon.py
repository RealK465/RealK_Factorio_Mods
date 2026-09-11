# Item and technology icons for the Quality Recycler.
#
#   blender -b -P render_icon.py -- <out_dir>
#
# Writes <out_dir>/icon-raw.png at 512. make_icons.py does the rest.
#
# Icons follow references/icons.md, NOT the entity rig: they are not on the
# tile grid, so ortho_scale/footprint/px-per-tile are irrelevant, and the
# lighting is far lower -- vanilla icons carry deep near-black crevices and a
# strong dark side where the entity key would flatten them to pale plastic.
#
# The model is rotated corner-on rather than the camera, so the key's direction
# in image space stays put; turning the camera instead would mean re-checking
# the lighting for every change.
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
# 2.9, not 3.7. Measured against the vanilla recycler's own icon: it fills
# 60 x 62 of its 64 px square and 79% of the pixels are opaque, where this one
# at 3.7 filled 64 x 51 and 47% -- a small dark lump with a margin round it,
# which is what "serviceable, not vanilla-grade" meant. An icon is not on the
# tile grid, so nothing forces it to show the whole footprint: cropping into
# the rotor, which is the machine's identity, is worth more than fitting the
# aprons in.
ORTHO = 2.35
# 34 degrees, not the 46 in references/icons.md. That figure was tuned on
# vanilla's MODULES, which are small cubes; this machine is squat and wide, and
# at 46 it rendered as a letterbox that lost most of a 64 px square to empty
# margin and turned to mush at the 32 px it is actually read at. A lower
# elevation shows more front elevation and less roof, which makes the
# silhouette taller and closer to square.
# 37, back up from the 34 this shipped at and the 30 the tighter crop was first
# tried with. Lowering the elevation makes the silhouette taller, which is what
# a square icon wants -- but it also turns the rotor's face away from the light,
# and at 30 the hero rendered as a dark ring with a violet centre and no copper
# in it at all. 37 puts the pole pieces back in the light; the height comes from
# the crop instead.
ELEVATION = 37.0
ROLL = -6.0
MODEL_YAW = 38.0     # corner-on, so the top face is a rhombus not a rectangle
# Aim at the ROTOR, not the machine's centre. It is the hero, it is the only
# thing that says this is not the vanilla recycler, and at 32 px in a toolbar
# the difference between "a green box" and "a green box with a copper wheel on
# it" is the whole icon.
AIM = (0.30, 0.16, 0.86)


def look_at(obj, target):
    # to_track_quat takes the LOOK direction -- target minus position. Passing
    # the offset FROM the target aims it exactly backwards and renders blank.
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else "."
    os.makedirs(out, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    import quality_recycler_gen as gen
    import qr_layout
    import qr_anim
    scene = bpy.context.scene
    qr_layout.build(gen.build_materials())
    qr_anim.animate(frames=64)
    gen.set_direction(MODEL_YAW)
    scene.frame_set(8)

    cam_data = bpy.data.cameras.new("QR_IconCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ORTHO
    cam = bpy.data.objects.new("QR_IconCam", cam_data)
    r = 12.0
    e = math.radians(ELEVATION)
    cam.location = (0.0, -r * math.cos(e), r * math.sin(e) + 0.5)
    scene.collection.objects.link(cam)
    look_at(cam, AIM)
    # roll about the camera's OWN axis, applied after aiming. Stuffing it into
    # rotation_euler[1] swings the aim off target and silently crops the model.
    cam.rotation_euler.rotate_axis("Z", math.radians(ROLL))
    scene.camera = cam

    for name, loc, energy, colour in (
            ("Key",  (-3.0, -1.6, 4.6), 3.0, (1.0, 0.97, 0.92)),
            ("Fill", (2.8, -3.6, 0.7), 0.25, (1.0, 1.0, 1.0)),
            ("Rim",  (1.6, 3.4, 2.6), 0.45, (0.78, 0.86, 1.0))):
        d = bpy.data.lights.new("QR_Icon" + name, "SUN")
        d.energy = energy
        d.color = colour
        o = bpy.data.objects.new("QR_Icon" + name, d)
        o.location = loc
        scene.collection.objects.link(o)
        look_at(o, (0, 0, 0.75))

    world = bpy.data.worlds.new("QR_IconWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 0.05
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
