"""Pure module icon generator.

One mesh, one tint pair. Every Pure module is this model with a different
(primary, secondary) colour, the same way vanilla builds its 12 module icons
from one model. Colours are lifted from vanilla's own `beacon_tint` fields so
the Pure tier sits in the same palette as tiers 1-3.

Run inside Blender:
    exec(open(r"<this file>").read())
    build(); tint("speed"); setup_render(); render(r"<out.png>")

Everything it creates is prefixed PM_ and rebuilt from scratch, so re-running
is safe.
"""

import bpy
import os
import sys
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
import math
from mathutils import Vector, Quaternion

PREFIX = "PM_"

# Both values are MEASURED off the vanilla tier-3 icon PNGs and converted to
# linear -- `body` from the lit chassis, `glow` from the brightest saturated
# dome pixels.
#
# Do not substitute beacon_tint here. Only speed and efficiency define one;
# productivity and quality have no beacon_tint in vanilla at all, so those
# values can only be invented, and inventing them got productivity's glow
# wrong (orange, where the art is plainly yellow) and quality's badly wrong
# (purple, where the art is red).
TYPES = {
    "speed":        {"body": (0.061, 0.262, 0.515), "glow": (0.102, 0.956, 0.956)},
    "productivity": {"body": (0.456, 0.080, 0.032), "glow": (0.956, 0.956, 0.156)},
    # Quality's chassis is a light warm silver. Sampling its most common
    # mid-tone lands on the shadowed side instead of the lit deck (its pose
    # shows more side than speed's does) and gives a dark olive that is about
    # four times too dark -- take the lit deck tone, sRGB (170,160,150).
    "quality":      {"body": (0.400, 0.351, 0.305), "glow": (0.750, 0.040, 0.020)},
    "efficiency":   {"body": (0.156, 0.456, 0.080), "glow": (0.010, 1.000, 0.010)},
}


# ---------------------------------------------------------------- utilities

def _purge():
    for ob in [o for o in bpy.data.objects if o.name.startswith(PREFIX)]:
        bpy.data.objects.remove(ob, do_unlink=True)
    for blk in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
        for d in [b for b in blk if b.name.startswith(PREFIX)]:
            if d.users == 0:
                blk.remove(d)


def _mat(name, base, metallic, rough, emit=None, emit_strength=0.0):
    """Create or re-apply a material. Re-applies on purpose: an early return
    here means palette edits silently do nothing on the second run."""
    m = bpy.data.materials.get(PREFIX + name) or bpy.data.materials.new(PREFIX + name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*base, 1.0)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    b.inputs["Emission Color"].default_value = (*(emit or (0, 0, 0)), 1.0)
    b.inputs["Emission Strength"].default_value = emit_strength
    return m


def _box(name, size, loc, mat, bevel=0.03, segments=3, clamp=True):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    ob = bpy.context.active_object
    ob.name = PREFIX + name
    ob.scale = Vector(size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        bm = ob.modifiers.new("bevel", "BEVEL")
        bm.width = bevel
        bm.segments = segments
        bm.limit_method = "ANGLE"
        bm.angle_limit = math.radians(30)
        bm.use_clamp_overlap = clamp
    ob.data.materials.append(mat)
    # 4.1+ dropped mesh.use_auto_smooth; shade_auto_smooth is the replacement.
    # Needed so bevels catch a continuous highlight instead of facetting.
    bpy.ops.object.shade_auto_smooth(angle=math.radians(32))
    return ob


def _cyl(name, r, depth, loc, mat, rot=(0, 0, 0), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth,
                                        location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.name = PREFIX + name
    bm = ob.modifiers.new("bevel", "BEVEL")
    bm.width = min(r * 0.35, depth * 0.35)
    bm.segments = 2
    bm.limit_method = "ANGLE"
    bm.angle_limit = math.radians(40)
    bm.use_clamp_overlap = True
    ob.data.materials.append(mat)
    return ob


# ------------------------------------------------------------------- model
#
# Modernised against vanilla: same squat chassis and same 3/4 read, but the
# three discrete domes become one continuous segmented lens (the tier-1/2/3
# icons count lit domes -- Pure is unnumbered, so it must not join that
# count), and the red/green/yellow wire loom becomes a flush gold edge
# connector. Colour moves off the paint and into the light.

W, D = 2.00, 1.85          # chassis footprint; near-square so the icon fills
                           # the 64px box the way vanilla's does
H = 0.80                   # chassis height; vanilla modules are chunky, a
                           # flatter slab loses the box read at 32 px
DECK_Z = H + 0.05          # top of the deck frame


def build(rot_z=38.0):
    _purge()

    # Metallic stays low on the painted surfaces: above ~0.3 the grey
    # specular swamps the tint and the icon reads neutral at 32 px.
    body = _mat("mat_body", (0.085, 0.098, 0.120), 0.18, 0.52)
    deck = _mat("mat_deck", (0.300, 0.325, 0.365), 0.22, 0.40)
    dark = _mat("mat_dark", (0.020, 0.021, 0.026), 0.10, 0.68)
    gold = _mat("mat_gold", (0.700, 0.520, 0.190), 1.00, 0.28)
    steel = _mat("mat_steel", (0.430, 0.450, 0.480), 0.90, 0.34)
    # Standard view transform clips hard. Emitting the near-white *secondary*
    # at any useful strength pushes G and B past 1.0 and the lens turns pure
    # white -- emit the primary instead and let the specular do the hotspot.
    _mat("mat_lens", (0.055, 0.090, 0.130), 0.0, 0.30, (0.44, 0.71, 1.00), 0.85)
    _mat("mat_accent", (0.055, 0.090, 0.130), 0.0, 0.25, (0.44, 0.71, 1.00), 0.70)
    # Deliberately NOT driven by tint(). A status readout is a readout on all
    # four Pure modules; tinting it would just double the lens colour and lose
    # the second light source.
    # 0.95 puts the screen just over export_icon's 0.58 bloom threshold, so it
    # actually reads as emitting rather than as a painted green panel.
    _mat("mat_screen", (0.050, 0.062, 0.028), 0.0, 0.35, (0.46, 0.78, 0.10), 0.95)
    lens = bpy.data.materials[PREFIX + "mat_lens"]
    accent = bpy.data.materials[PREFIX + "mat_accent"]
    screen = bpy.data.materials[PREFIX + "mat_screen"]
    # The key's white specular lifts the lens's red channel and turns the cyan
    # to white. Killing the highlight lets the emission carry the colour.
    lens.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.12
    screen.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.15

    # chassis
    _box("chassis", (W, D, H), (0, 0, H / 2), body, bevel=0.045, segments=3)

    # deck frame -- four bars around a recessed well, rather than a boolean,
    # so the inner edges get their own bevel highlight
    fx, fy = W - 0.12, D - 0.11                 # deck outer footprint
    wx, wy = 1.58, 0.92                         # well opening
    wcy = 0.0                                   # lens centred on the deck --
                                                # offset back, the front border
                                                # reads twice the back one
    bar_z = H + 0.005
    back_d = (fy / 2) - (wcy + wy / 2)
    front_d = (fy / 2) + (wcy - wy / 2)
    _box("deck_back", (fx, back_d, 0.10), (0, fy / 2 - back_d / 2, bar_z), deck, 0.022)
    _box("deck_front", (fx, front_d, 0.10), (0, -fy / 2 + front_d / 2, bar_z), deck, 0.022)
    side_x = (fx - wx) / 2
    for s, nm in ((-1, "l"), (1, "r")):
        _box("deck_" + nm, (side_x, wy, 0.10),
             (s * (fx / 2 - side_x / 2), wcy, bar_z), deck, 0.022)
    _box("well_floor", (wx, wy, 0.07), (0, wcy, H - 0.02), dark, 0.012)

    # Lens: one continuous bar rather than vanilla's three domes. Tiers 1-3
    # signal their tier by how many domes are lit, and Pure is unnumbered --
    # it must not read as a count. Two raised bridges keep the three-part
    # rhythm without joining that language.
    _box("lens", (1.48, 0.78, 0.40), (0, wcy, H + 0.13), lens, bevel=0.18, segments=8)
    # straps sit proud of the lens crown and wrap past its sides, so they read
    # as retaining hardware rather than cracks in the glass
    for i, x in enumerate((-0.49, 0.49)):
        _box("strap_%d" % i, (0.075, 0.94, 0.50), (x, wcy, H + 0.11), deck,
             bevel=0.030, segments=3)

    # vent grille on the back bar
    for i in range(4):
        x = -0.54 + i * 0.36
        _box("vent_%d" % i, (0.24, 0.10, 0.025), (x, fy / 2 - back_d / 2, bar_z + 0.052),
             dark, bevel=0.006)

    # front face: groove, recessed connector and gold pads
    yf = -D / 2
    _box("seam", (W - 0.10, 0.06, 0.085), (0, yf + 0.005, H * 0.66), dark, bevel=0.010)
    _box("conn_recess", (1.54, 0.05, 0.30), (0, yf + 0.010, H * 0.30), dark, bevel=0.010)
    # connector run gives up its left half to the screen
    for i in range(3):
        x = 0.16 + i * 0.24
        _box("pad_%d" % i, (0.165, 0.035, 0.200), (x, yf - 0.005, H * 0.30), gold, bevel=0.012)

    # lit status screen, low on the front face
    sz = H * 0.30
    _box("screen_bezel", (0.66, 0.05, 0.30), (-0.40, yf - 0.005, sz), dark, bevel=0.016)
    _box("screen_face", (0.52, 0.045, 0.19), (-0.40, yf - 0.020, sz), screen, bevel=0.010)
    # two hairlines only -- three read as a grille, and at 64 px they blur out
    # anyway, so they exist purely to stop the panel looking like flat paint
    for i, dz in enumerate((-0.045, 0.045)):
        _box("scan_%d" % i, (0.44, 0.02, 0.011), (-0.40, yf - 0.042, sz + dz),
             dark, bevel=0.003)

    # emissive accent line under the deck lip
    _box("accent", (W - 0.28, 0.035, 0.028), (0, yf + 0.002, H - 0.065), accent, bevel=0.006)

    # corner bolts in machined counterbores
    # Corner bolts sit on the full-width front/back bars and can take the
    # standard size. The side midpoints only have the 0.15-wide side bars to
    # land on, so they get a smaller bolt centred on the bar -- at full size
    # the counterbore overhangs the well and clips the lens.
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (fx / 2 - 0.10), sy * (fy / 2 - 0.10)
            _cyl("cbore_%d%d" % (sx, sy), 0.082, 0.03, (x, y, bar_z + 0.042), dark)
            _cyl("bolt_%d%d" % (sx, sy), 0.052, 0.045, (x, y, bar_z + 0.050), steel)
        xm = sx * (fx / 2 - side_x / 2)
        _cyl("cbore_mid_%d" % sx, 0.058, 0.03, (xm, wcy, bar_z + 0.042), dark)
        _cyl("bolt_mid_%d" % sx, 0.036, 0.045, (xm, wcy, bar_z + 0.050), steel)

    # rubber corner guards, echoing vanilla's black connector blocks
    for sx in (-1, 1):
        _box("guard_%d" % sx, (0.20, 0.22, 0.24),
             (sx * (W / 2 - 0.09), yf + 0.10, 0.12), dark, bevel=0.03)

    # Greebling. Vanilla machines are visually busy at this size -- a clean
    # box reads as untextured CG however good the lighting is. Each of these
    # earns its place by catching an edge highlight or breaking the silhouette.

    # corner posts down the four vertical chassis edges
    for sx in (-1, 1):
        for sy in (-1, 1):
            _box("post_%d%d" % (sx, sy), (0.12, 0.12, H - 0.07),
                 (sx * (W / 2 - 0.025), sy * (D / 2 - 0.025), H / 2 - 0.015),
                 deck, bevel=0.026)

    # heat fins on the left and right chassis faces
    for sx in (-1, 1):
        for i in range(3):
            _box("fin_%d_%d" % (sx, i), (0.05, D - 0.52, 0.055),
                 (sx * (W / 2), 0, 0.20 + i * 0.17), deck, bevel=0.014)

    # nameplate and a small status LED on the front deck bar, deliberately
    # tiny so it never competes with the lens
    plate_y = -fy / 2 + front_d / 2
    _box("plate", (0.60, 0.20, 0.022), (-0.06, plate_y, bar_z + 0.048), dark, bevel=0.008)
    _cyl("led", 0.045, 0.03, (0.62, plate_y, bar_z + 0.058), accent)

    # Vanilla views modules corner-on, not face-on -- the top face reads as a
    # rhombus. Spin the model rather than the camera so the key light keeps a
    # fixed upper-left direction in image space.
    bpy.ops.object.empty_add(location=(0, 0, 0))
    root = bpy.context.active_object
    root.name = PREFIX + "root"
    for ob in bpy.data.objects:
        if ob.name.startswith(PREFIX) and ob.type == "MESH":
            ob.parent = root
            ob.matrix_parent_inverse = root.matrix_world.inverted()
    root.rotation_euler[2] = math.radians(rot_z)

    tint("speed")


# -------------------------------------------------------------------- tint

def tint(kind):
    """Recolour the whole icon. This is the only thing that differs between
    the four Pure modules."""
    bodycol = TYPES[kind]["body"]
    glow = TYPES[kind]["glow"]

    def set_base(name, rgb):
        m = bpy.data.materials[PREFIX + name]
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1.0)

    def set_emit(name, rgb):
        m = bpy.data.materials[PREFIX + name]
        m.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (*rgb, 1.0)

    # The chassis and deck carry a real colour cast, not a neutral grey --
    # at 32 px the type has to be readable from the body, not just the lens.
    # DECK_GAIN compensates for the key's ~0.75 irradiance on the top face, so
    # the rendered deck lands on the sampled vanilla value rather than under it.
    set_base("mat_deck", tuple(min(1.0, v * 1.35) for v in bodycol))
    set_base("mat_body", tuple(v * 0.62 for v in bodycol))
    # The measured dome colours already have their off-channels near zero,
    # which is what keeps the lens from clipping to white under emission.
    for n in ("mat_lens", "mat_accent"):
        set_base(n, tuple(v * 0.06 for v in glow))
        set_emit(n, glow)


# ------------------------------------------------------------------ render

def setup_render(res=512, ortho=2.55, elev=46.0, azim=0.0, roll=-6.0):
    sc = bpy.context.scene

    for n in ("Light", "Camera"):
        ob = bpy.data.objects.get(n)
        if ob:
            bpy.data.objects.remove(ob, do_unlink=True)

    cam_d = bpy.data.cameras.new(PREFIX + "cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = ortho
    cam = bpy.data.objects.new(PREFIX + "cam", cam_d)
    sc.collection.objects.link(cam)
    target = Vector((0, 0, 0.34))
    e, a = math.radians(elev), math.radians(azim)
    cam.location = target + Vector((math.sin(a) * math.cos(e),
                                    -math.cos(a) * math.cos(e),
                                    math.sin(e))) * 12.0
    # Aim, then roll about the camera's own axis. Stuffing the roll into
    # euler[1] instead swings the aim off target.
    q = (target - cam.location).to_track_quat("-Z", "Y")
    cam.rotation_euler = (q @ Quaternion((0, 0, 1), math.radians(roll))).to_euler()
    sc.camera = cam

    def sun(name, loc, energy, color=(1, 1, 1)):
        ld = bpy.data.lights.new(PREFIX + name, "SUN")
        ld.energy = energy
        ld.color = color
        ld.angle = math.radians(6.0)
        ob = bpy.data.objects.new(PREFIX + name, ld)
        sc.collection.objects.link(ob)
        ob.location = loc
        c = ob.constraints.new("TRACK_TO")
        c.target = cam           # aimed by direction below, not at the camera
        ob.constraints.remove(c)
        v = -Vector(loc).normalized()
        ob.rotation_euler = v.to_track_quat("-Z", "Y").to_euler()
        return ob

    # Kept deliberately low. Vanilla icons carry deep black crevices and a
    # dark outline; a hotter key flattens the whole thing to pale plastic.
    sun("key", (-3.0, -1.6, 4.6), 3.0)                       # upper left
    sun("fill", (2.8, -3.6, 0.7), 0.25)                      # front right, soft
    sun("rim", (1.6, 3.4, 2.6), 0.45, (0.62, 0.80, 1.0))     # cool back rim

    w = bpy.data.worlds.get("PM_world") or bpy.data.worlds.new("PM_world")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.10, 0.12, 0.16, 1.0)
    bg.inputs[1].default_value = 0.05
    sc.world = w

    sc.render.engine = "CYCLES"
    fr_rig.use_gpu(sc)
    sc.cycles.samples = 128
    sc.cycles.use_denoising = True
    sc.render.use_persistent_data = True
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    # Factorio expects Standard; AgX washes the art out against vanilla.
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def render_all(out_dir):
    """The whole point of the tint parameter: the other three Pure modules are
    this same mesh and camera, re-tinted. Run export_icon.py on each result."""
    for kind in TYPES:
        tint(kind)
        render("%s/pure-%s-module.png" % (out_dir.rstrip("/"), kind))
