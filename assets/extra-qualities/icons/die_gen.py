"""The quality die - the model behind both technology icons.

Vanilla's epic-quality and legendary-quality icons are one worn white die photographed
corner-on, its top face carrying the tier being unlocked and the two visible side faces the
two tiers below it. Measured off those two PNGs (2.1.17): the die fills x 28..235, y 24..255
of the 256 box, body mean RGB about (160,147,145), luminance sd 52-56, and the soft fringe
under it is a drop shadow at mean alpha 120, RGB (23,21,20).

This builds the same die, once per tier. Pip layouts are the quality glyphs' own arrangements,
so the die face and the little icon on an item agree.

An earlier pass split the celestial die open with a glowing fracture, on the grounds that no die
has a seven face. It was removed: the glow read as stray blue lines across the icon, and a
fourth die that does not match the other three undoes the consistency this set exists for.

Two things a first pass got wrong, both worth keeping in mind:

* **A die is convex, so ambient occlusion does nothing to it.** Vanilla's grime is painted,
  not occlusion - the stains have to come from noise and from pointiness, or the body renders
  as clean pale plastic. AO only earns its place inside the pip sockets.
* **The sockets are cylinders, not dimples.** The dark ring round each gem is the socket wall
  seen edge-on; a shallow spherical cap has no wall and loses it.

Imported by render_tech_icons.py; not runnable on its own.
"""

import math

import bmesh
import bpy
from mathutils import Vector

PREFIX = "EQ_"

# Pip arrangements in face space, half-width 1. **Identical shapes to the quality glyphs** -
# the die face and the little icon on an item have to agree, or the two icon sets read as
# two mods. Six is a hexagonal ring, seven is that ring with the middle filled.
LAYOUTS = {
    1: [(0, 0)],
    2: [(-0.5, 0.5), (-0.5, -0.5)],
    3: [(-0.5, 0.5), (-0.5, -0.5), (0.5, -0.5)],
    4: [(-0.5, 0.5), (0.5, 0.5), (-0.5, -0.5), (0.5, -0.5)],
    5: [(-0.62, 0.62), (0.62, 0.62), (-0.62, -0.62), (0.62, -0.62), (0, 0)],
    6: [(math.cos(math.radians(a)) * 0.76, math.sin(math.radians(a)) * 0.76)
        for a in range(0, 360, 60)],
    7: [(math.cos(math.radians(a)) * 0.76, math.sin(math.radians(a)) * 0.76)
        for a in range(0, 360, 60)] + [(0, 0)],
}

# Pip colours, linear. The five vanilla ones are the fills measured off Wube's own quality
# glyphs; the two new ones match this mod's.
PIP_COLOURS = {
    "uncommon": (0.05, 0.72, 0.09),
    "rare": (0.02, 0.30, 1.00),
    "epic": (0.55, 0.00, 1.00),
    "legendary": (1.00, 0.30, 0.00),
    "mythic": (1.00, 0.03, 0.06),
    "celestial": (0.00, 0.80, 1.00),
}

DIE_HALF = 1.0
BEVEL = 0.17
SOCKET_D = 0.115       # how deep the socket is cut
PANEL_D = 0.022        # depth of the recessed face panel

# Pip size follows the count, as it does on the quality glyphs: four pips on a grid have room
# for big gems, five need the corners pushed out so the middle one fits, and six or seven ring
# the face and shrink again. `inset` is the grid offset or the hexagon's radius, `socket` the
# wall radius, `pip` the gem, `sink` how far the gem sits below the face. Half-face units.
#
# **Sockets must not overlap.** They are cut out of the die as one joined cutter, and two
# cylinders that intersect inside it make the exact boolean discard the whole body - which
# renders as gems floating in mid-air with no die behind them. `_check_clearance` is the guard.
METRICS = {
    1: dict(inset=0.000, socket=0.340, pip=0.280, sink=0.200),
    2: dict(inset=0.355, socket=0.300, pip=0.245, sink=0.175),
    3: dict(inset=0.355, socket=0.300, pip=0.245, sink=0.175),
    4: dict(inset=0.355, socket=0.300, pip=0.245, sink=0.175),
    5: dict(inset=0.420, socket=0.245, pip=0.200, sink=0.145),
    6: dict(inset=0.500, socket=0.213, pip=0.175, sink=0.125),
    7: dict(inset=0.500, socket=0.213, pip=0.175, sink=0.125),
}


def _clear():
    for obj in list(bpy.data.objects):
        if obj.name.startswith(PREFIX):
            bpy.data.objects.remove(obj, do_unlink=True)


def _mat(name, base, roughness=0.5, metallic=0.0, emission=None, emission_strength=0.0):
    """Re-applies values to an existing datablock so palette edits are not silently lost."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*base, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
        # The key's white highlight lifts a glow to white on its own - see icons.md.
        bsdf.inputs["Specular IOR Level"].default_value = 0.18
    return mat


def bone_material(stain_tint=(0.5, 0.45, 0.40)):
    """Worn ivory: blotched staining, grubby crevices, chipped edges.

    `stain_tint` is the tier colour bled into the grime, which is what gives vanilla's epic
    die its purple cast and the legendary one its amber.
    """
    name = PREFIX + "bone"
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    coord = nt.nodes.new("ShaderNodeTexCoord")
    geom = nt.nodes.new("ShaderNodeNewGeometry")

    def noise(scale, detail, roughness=0.6):
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = roughness
        nt.links.new(coord.outputs["Object"], n.inputs["Vector"])
        return n

    def ramp(src, lo, hi, c0=(0, 0, 0, 1), c1=(1, 1, 1, 1)):
        r = nt.nodes.new("ShaderNodeValToRGB")
        r.color_ramp.elements[0].position = lo
        r.color_ramp.elements[0].color = c0
        r.color_ramp.elements[1].position = hi
        r.color_ramp.elements[1].color = c1
        nt.links.new(src, r.inputs["Fac"])
        return r

    def mix(fac, a, b, blend="MIX"):
        m = nt.nodes.new("ShaderNodeMixRGB")
        m.blend_type = blend
        if isinstance(fac, bpy.types.NodeSocket):
            nt.links.new(fac, m.inputs["Fac"])
        else:
            m.inputs["Fac"].default_value = 0.5 if fac is None else fac
        for socket, value in (("Color1", a), ("Color2", b)):
            if isinstance(value, bpy.types.NodeSocket):
                nt.links.new(value, m.inputs[socket])
            else:
                m.inputs[socket].default_value = (*value, 1.0)
        return m

    ivory = (0.72, 0.68, 0.60)
    # A hint of the tier colour in the grime, not a wash of it - vanilla's epic die is
    # brown with a purple cast, not a purple die.
    stain = tuple(0.075 + 0.030 * c for c in stain_tint)

    blotch = ramp(noise(4.2, 9.0).outputs["Fac"], 0.28, 0.46)
    body = mix(blotch.outputs["Color"], stain, ivory)

    # Fine speckle so no face is a single tone at 256 px.
    speckle = ramp(noise(26.0, 6.0).outputs["Fac"], 0.36, 0.70,
                   c0=(0.55, 0.52, 0.48, 1), c1=(1.06, 1.05, 1.03, 1))
    body = mix(0.40, body.outputs["Color"], speckle.outputs["Color"], blend="MULTIPLY")

    # Pointiness: convex edges get knocked clean, concave corners hold dirt. A die is convex
    # overall, so this and the noise are the only things standing between it and pale plastic.
    point = nt.nodes.new("ShaderNodeMapRange")
    point.inputs["From Min"].default_value = 0.50
    point.inputs["From Max"].default_value = 0.58
    nt.links.new(geom.outputs["Pointiness"], point.inputs["Value"])
    body = mix(point.outputs["Result"], body.outputs["Color"], (0.66, 0.63, 0.58))

    grime = nt.nodes.new("ShaderNodeMapRange")
    grime.inputs["From Min"].default_value = 0.485
    grime.inputs["From Max"].default_value = 0.435
    nt.links.new(geom.outputs["Pointiness"], grime.inputs["Value"])
    body = mix(grime.outputs["Result"], body.outputs["Color"], (0.105, 0.088, 0.072))

    # The sockets are the one place a die is actually concave, so AO belongs there.
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.30
    ao_ramp = ramp(ao.outputs["Color"], 0.22, 0.92, c0=(0.20, 0.17, 0.14, 1))
    body = mix(1.0, body.outputs["Color"], ao_ramp.outputs["Color"], blend="MULTIPLY")

    nt.links.new(body.outputs["Color"], bsdf.inputs["Base Color"])

    rough = nt.nodes.new("ShaderNodeMapRange")
    rough.inputs["To Min"].default_value = 0.36
    rough.inputs["To Max"].default_value = 0.78
    nt.links.new(blotch.outputs["Color"], rough.inputs["Value"])
    nt.links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = 0.0

    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.22
    nt.links.new(noise(55.0, 8.0).outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


def _face_frame(face):
    """(origin, u, v, normal) for a named face of the die, in object space."""
    frames = {
        "top": (Vector((0, 0, DIE_HALF)), Vector((1, 0, 0)), Vector((0, 1, 0))),
        "left": (Vector((-DIE_HALF, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))),
        "right": (Vector((0, -DIE_HALF, 0)), Vector((1, 0, 0)), Vector((0, 0, 1))),
    }
    origin, u, v = frames[face]
    return origin, u, v, origin.normalized()


def _check_clearance(count, places, socket_r):
    if len(places) < 2:
        return
    closest = min((a - b).length for i, (a, _) in enumerate(places)
                  for b, _ in places[i + 1:])
    if closest <= socket_r * 2:
        raise ValueError(
            "%d-pip face: sockets overlap (centres %.3f apart, radius %.3f). The boolean "
            "would discard the die body." % (count, closest, socket_r))


def _pip_positions(face, count):
    origin, u, v, normal = _face_frame(face)
    m = METRICS[count]
    pts = LAYOUTS[count]
    span = max(max(abs(p[0]), abs(p[1])) for p in pts) or 1.0
    k = m["inset"] / span if span else 0.0
    places = [(origin + u * (px * k) + v * (py * k), normal) for px, py in pts]
    _check_clearance(count, places, m["socket"])
    return places, m


def _mesh_object(name, bm, centre):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = centre
    return obj


def _uv_sphere(name, centre, radius, segments=32):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=segments // 2, radius=radius)
    return _mesh_object(name, bm, centre)


def _cylinder(name, centre, radius, depth, normal, segments=40):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments,
                          radius1=radius, radius2=radius, depth=depth)
    obj = _mesh_object(name, bm, centre)
    obj.rotation_euler = Vector((0, 0, 1)).rotation_difference(normal).to_euler()
    return obj


def _torus(name, centre, major, minor, normal, segments=48):
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=False, segments=segments, radius=major)
    bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:], axis=(0, 0, 1),
                   cent=(0, 0, 0), dvec=(0, 0, 0), angle=0, steps=1)
    bm.free()
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments,
                          radius1=major + minor, radius2=major + minor * 0.55,
                          depth=minor * 2.2)
    inner = bmesh.new()
    bmesh.ops.create_cone(inner, cap_ends=True, segments=segments,
                          radius1=major - minor * 0.2, radius2=major - minor * 0.2,
                          depth=minor * 6)
    obj = _mesh_object(name, bm, centre)
    cut = _mesh_object(name + "_cut", inner, centre)
    obj.rotation_euler = Vector((0, 0, 1)).rotation_difference(normal).to_euler()
    cut.rotation_euler = obj.rotation_euler
    _boolean(obj, cut, "DIFFERENCE")
    obj.data.materials.clear()
    for poly in obj.data.polygons:
        poly.material_index = 0
    return obj


def _panel(name, origin, normal, half=0.785, depth=None):
    """A shallow recessed panel: the raised rim round each face of a vanilla die."""
    depth = PANEL_D if depth is None else depth
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(half * 2, half * 2, depth * 4), verts=bm.verts)
    obj = _mesh_object(name, bm, origin + normal * (depth * 2 - depth))
    obj.rotation_euler = Vector((0, 0, 1)).rotation_difference(normal).to_euler()
    bev = obj.modifiers.new("bevel", "BEVEL")
    bev.width = 0.095
    bev.segments = 6
    bev.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bev.name)
    return obj


def build(top_count, top_colour, left, right):
    """Build the die. `left` and `right` are (count, colour-name) for the two side faces."""
    _clear()

    bpy.ops.mesh.primitive_cube_add(size=DIE_HALF * 2, location=(0, 0, 0))
    die = bpy.context.active_object
    die.name = PREFIX + "die"

    bev = die.modifiers.new("bevel", "BEVEL")
    bev.width = BEVEL
    bev.segments = 8
    bev.limit_method = "ANGLE"
    bev.harden_normals = True
    bpy.context.view_layer.objects.active = die
    bpy.ops.object.modifier_apply(modifier=bev.name)
    for poly in die.data.polygons:
        poly.use_smooth = True

    faces = [
        ("top", top_count, top_colour),
        ("left", left[0], left[1]),
        ("right", right[0], right[1]),
    ]

    # Each vanilla face is a shallow recessed panel with a raised rim, and the pips sit
    # inside it. Cut those first, so the sockets go through the panel floor.
    panels = [_panel("%spanel_%s" % (PREFIX, face), _face_frame(face)[0], _face_frame(face)[3])
              for face, _, _ in faces]
    _boolean(die, _join(panels, PREFIX + "panels"), "DIFFERENCE")

    sockets, gems = [], []
    for face, count, colour in faces:
        places, m = _pip_positions(face, count)
        for i, (centre, normal) in enumerate(places):
            # The cutter straddles the face, so the socket bottom sits SOCKET_D inside it.
            sockets.append(_cylinder(
                "%ssocket_%s_%d" % (PREFIX, face, i),
                centre + normal * (SOCKET_D * 1.5 - SOCKET_D),
                m["socket"], SOCKET_D * 3.0, normal,
            ))
            gem = _uv_sphere("%sgem_%s_%d" % (PREFIX, face, i),
                             centre - normal * m["sink"], m["pip"])
            rgb = PIP_COLOURS[colour]
            gem.data.materials.append(_mat(
                PREFIX + "gem_" + colour,
                tuple(c * 0.45 for c in rgb),
                roughness=0.14,
                emission=rgb,
                emission_strength=0.75,
            ))
            for poly in gem.data.polygons:
                poly.use_smooth = True
            gems.append(gem)

            # Bezel: the dark metal collar round each gem. Without it the socket wall
            # catches the key and each pip renders with a white halo.
            bezel = _torus("%sbezel_%s_%d" % (PREFIX, face, i),
                           centre - normal * (PANEL_D + 0.012), m["socket"], 0.034, normal)
            bezel.data.materials.append(_mat(
                PREFIX + "bezel_" + colour,
                tuple(0.030 + 0.055 * c for c in rgb),
                roughness=0.38, metallic=0.85,
            ))
            for poly in bezel.data.polygons:
                poly.use_smooth = True
            gems.append(bezel)

    _boolean(die, _join(sockets, PREFIX + "sockets"), "DIFFERENCE")

    # A boolean leaves an empty material slot 0 behind and points every polygon at it, so
    # the die renders in Blender's default grey however good the material is. Clear the
    # list and re-seat it.
    die.data.materials.clear()
    die.data.materials.append(bone_material(PIP_COLOURS[top_colour]))
    for poly in die.data.polygons:
        poly.material_index = 0

    return die, gems


def _join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    return joined


def _boolean(target, cutter, operation):
    mod = target.modifiers.new("bool_" + cutter.name, "BOOLEAN")
    mod.object = cutter
    mod.operation = operation
    mod.solver = "EXACT"
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
