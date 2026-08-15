# Wreck scene for the Pure beacon's corpse sprite.
#
# Reuses beacon_gen wholesale -- its scaffolding, its part vocabulary and its
# material factory. Two swaps do most of the work:
#
#   * a material dict with the SAME KEYS but burnt values, so every reused
#     part builder renders dead without being touched (the emissive keys are
#     what would otherwise leak a glowing LED into a wreck);
#   * HEAT_SOURCES pointed at the blast centre instead of the radiator, so
#     worn_metal's rime thins toward the middle for free -- the design's
#     soot-centre / frost-rim band map falls out of the existing node graph.
#
# Design: pure-modules-realk/.ai-support/pure-beacon-design.md (Remnants section)
import math
import random

import bpy
import bmesh
from mathutils import Vector, Matrix, Euler

import beacon_gen as bg

PREFIX = "PBR_"
bg.PREFIX = PREFIX                # every reused helper names its objects PBR_*
bg.HEAT_SOURCES = [(0.0, 0.0)]    # frost thins toward the blast, not the fins

PAD_Z = 0.30                      # top of the collapsed plinth; the intact one is 0.75

# beacon_gen's shared palette constants, captured before anything dims them:
# wreck_materials() rebuilds per variation and would otherwise compound.
_BARE0, _RUST0, _FROST0 = bg.BARE, bg.RUST, bg.FROST


# --------------------------------------------------------------------------
# materials -- same keys as beacon_gen.build_materials(), burnt values

def wreck_materials():
    # Measured against vanilla: cryogenic-plant, nuclear-reactor and beacon
    # remnants all sit at mean luminance 63-67 over their opaque pixels, and an
    # undimmed version of this palette rendered 93. A wreck is burnt and unlit,
    # and belongs a good deal darker than the machine it came from -- the rig
    # itself is the entity's and is not the thing to touch.
    DIM = 0.62

    def d(c):
        return tuple(v * DIM for v in c)

    bg.BARE, bg.RUST, bg.FROST = d(_BARE0), d(_RUST0), d(_FROST0)

    def fade(c, k=0.58):
        # Burnt paint loses chroma. Measured against vanilla: every shipped
        # remnant is 88-99% warm pixels (cryogenic plant 88.0, nuclear reactor
        # 94.5, base beacon 99.4) because rust wins whatever the machine was
        # painted -- and the cryogenic plant is a teal machine. This wreck came
        # out 64% warm and 35% cold, which is the identity colour surviving far
        # too well. Pulling the paint toward its own luminance lets the rust on
        # top of it read.
        lum = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
        return tuple(v + (lum - v) * k for v in c)

    paint_a, paint_b = fade(d(bg.PAINT_A)), fade(d(bg.PAINT_B))
    # Bare steel the paint has been knocked off, and the sooted char that
    # replaces it anywhere near the middle. Both stay well above pure black:
    # Standard clips at both ends and a black wreck loses all its form.
    # Warm rather than neutral -- a neutral grey here reads as cold slag and
    # was most of why this wreck stayed blue against vanilla's rusted ones.
    bare_a, bare_b = d((0.132, 0.112, 0.092)), d((0.072, 0.060, 0.048))
    char_a, char_b = d((0.088, 0.066, 0.048)), d((0.048, 0.035, 0.025))

    hull = bg.worn_metal("wreck_hull", paint_a, paint_b,
                         metallic=0.20, rough_lo=0.55, rough_hi=0.85, grime=0.55,
                         wear=0.78, rust=0.85, noise_scale=5.0, frost=0.10, grain=0.16)
    # thrown clear of the fire, so the paint survives and the rime returns
    hull_cold = bg.worn_metal("wreck_hull_cold", paint_a, paint_b,
                              metallic=0.20, rough_lo=0.55, rough_hi=0.82, grime=0.4,
                              wear=0.6, rust=0.6, noise_scale=5.0, frost=0.32, grain=0.16)
    burnt = bg.worn_metal("wreck_burnt", char_a, char_b,
                          metallic=0.30, rough_lo=0.62, rough_hi=0.9, grime=0.5,
                          wear=0.55, rust=0.4, noise_scale=6.0, frost=0.0, grain=0.14)
    bare = bg.worn_metal("wreck_bare", bare_a, bare_b,
                         metallic=0.42, rough_lo=0.45, rough_hi=0.72, grime=0.5,
                         wear=0.7, rust=0.7, noise_scale=5.5, frost=0.06, grain=0.14)
    rusty = bg.worn_metal("wreck_rusty", d((0.115, 0.056, 0.026)), d((0.062, 0.030, 0.014)),
                          metallic=0.15, rough_lo=0.65, rough_hi=0.9,
                          wear=0.6, rust=0.5, noise_scale=4.5, frost=0.10)
    iron = bg.worn_metal("wreck_iron", d((0.034, 0.026, 0.020)), d((0.022, 0.017, 0.013)),
                         metallic=0.35, rough_lo=0.6, rough_hi=0.85,
                         wear=0.45, rust=0.6, frost=0.08)
    gunmetal = bg.worn_metal("wreck_gunmetal", d((0.068, 0.054, 0.042)), d((0.044, 0.035, 0.027)),
                             metallic=0.40, rough_lo=0.5, rough_hi=0.75,
                             wear=0.55, rust=0.45, frost=0.10)
    holmium = bg.worn_metal("wreck_holmium", d(bg.HOLM_A), d(bg.HOLM_B),
                            metallic=0.45, rough_lo=0.35, rough_hi=0.6,
                            wear=0.5, rust=0.35, frost=0.14, grain=0.12)
    copper = bg.worn_metal("wreck_copper", d((0.26, 0.10, 0.045)), d((0.13, 0.055, 0.028)),
                           metallic=0.65, rough_lo=0.45, rough_hi=0.7,
                           wear=0.35, rust=0.55, noise_scale=6.0, frost=0.06)
    # The coil bands keep their machined look but lose the energy sheen: a
    # sheen node here is the difference between "dead hardware" and "still on".
    ring = bg.worn_metal("wreck_ring", d((0.104, 0.086, 0.070)), d((0.066, 0.054, 0.043)),
                         metallic=0.30, rough_lo=0.55, rough_hi=0.8,
                         wear=0.55, rust=0.35, frost=0.12)
    hose = bg.rubber("wreck_hose", (0.014, 0.014, 0.015))
    dead = bg.plain("wreck_dead", d((0.034, 0.029, 0.024)), metallic=0.15, rough=0.62)
    void = bg.plain("wreck_void", (0.020, 0.021, 0.023), metallic=0.1, rough=0.8)
    # Burst canister glass: sooted and opaque. A clean transmissive shell in a
    # wreck reads as intact hardware, which is the opposite of the point.
    glass = bg.plain("wreck_glass", d((0.052, 0.045, 0.038)), metallic=0.25, rough=0.45)

    mats = {
        "crystal_dead": dead_crystal(),
        "steel": hull, "frosty": hull_cold, "steel_dark": burnt,
        "bare": bare, "burnt": burnt, "cold": hull_cold,
        "rusty": rusty, "iron": iron, "gunmetal": gunmetal,
        "holmium": holmium, "copper": copper, "ring": ring,
        "hose": hose, "cable": bg.rubber("wreck_cable", (0.019, 0.018, 0.017)),
        "socket_dark": void, "dial": bg.plain("wreck_dial", d((0.14, 0.135, 0.12)),
                                              metallic=0.0, rough=0.75),
        "insulation": bg.worn_metal("wreck_insulation", d((0.10, 0.094, 0.088)),
                                    d((0.060, 0.056, 0.052)), metallic=0.12,
                                    rough_lo=0.7, rough_hi=0.9, wear=0.4, rust=0.5),
        "glass": glass,
        "footprint": bg.emission_only("footprint_white", (1, 1, 1), 1.0),
    }
    # Every remaining key any reused builder might reach for resolves to dead
    # matter. Listing them is the point: a missed emissive key is a lit lamp
    # in a burnt-out machine, and nothing in the render would flag it.
    for key in ("glow", "glow_hot", "core", "crystal", "arc", "strip", "vent_glow",
                "heat_glow", "radiator", "screen", "led_green", "led_amber",
                "led_cyan", "fluid_hot", "fluid_cold", "warm", "etched", "tread",
                "deck", "deck_id", "deck_arrows", "deck_cold", "deck_caution",
                "holmium_label", "holmium_id", "riser_hazard", "riser_id",
                "power_hv", "holmium_etch", "hatch_lid"):
        mats.setdefault(key, dead)
    # a few of those deserve better than generic dead matter
    mats["deck"] = mats["tread"] = burnt
    mats["holmium_label"] = mats["holmium_id"] = mats["holmium_etch"] = holmium
    mats["riser_hazard"] = mats["riser_id"] = hull
    mats["hatch_lid"] = mats["power_hv"] = burnt
    mats["fluid_hot"] = mats["fluid_cold"] = void
    return mats


def _dim(c, k=0.62):
    return tuple(v * k for v in c)


def dead_crystal():
    # What is left of the quantum core, and it has to still READ as crystal.
    # An earlier pass made it frosted and desaturated on the theory that dead
    # means dull; it rendered as blue gravel. A conchoidal fracture in a mineral
    # is glassy, not matte, so:
    #   - low roughness, so facets throw hard speculars that differ face to face
    #   - a Fresnel ramp to near-white ice at grazing angles, which is the single
    #     strongest "this is transparent material" cue available without
    #     transmission (real transmission would punch holes in a sprite rendered
    #     on transparent film)
    #   - the blue stays saturated. A broken sapphire is still blue.
    # Emission stays at zero throughout: bright edges, but nothing self-lit.
    m = bg._get_mat("wreck_crystal")
    nt, out = bg._reset_nodes(m)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["IOR"].default_value = 1.7
    coord = nt.nodes.new("ShaderNodeTexCoord")

    # facet-to-facet colour variation, deliberately a wide range so neighbouring
    # faces separate in value instead of averaging to one blue blob
    cells = nt.nodes.new("ShaderNodeTexVoronoi")
    cells.inputs["Scale"].default_value = 6.0
    nt.links.new(coord.outputs["Object"], cells.inputs["Vector"])
    facet = nt.nodes.new("ShaderNodeMix")
    facet.data_type = "RGBA"
    facet.inputs["A"].default_value = (*_dim(bg.srgb("#0B2233")), 1)
    facet.inputs["B"].default_value = (*_dim(bg.srgb("#27607D")), 1)
    tone = nt.nodes.new("ShaderNodeMapRange")
    tone.inputs["From Min"].default_value = 0.10
    tone.inputs["From Max"].default_value = 0.70
    nt.links.new(cells.outputs["Distance"], tone.inputs["Value"])
    nt.links.new(tone.outputs["Result"], facet.inputs["Factor"])

    # ice-bright rim where the surface turns away: the glass tell
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.30
    rim = nt.nodes.new("ShaderNodeMix")
    rim.data_type = "RGBA"
    rim.inputs["B"].default_value = (*_dim(bg.srgb("#9FC6D8")), 1)
    nt.links.new(facet.outputs["Result"], rim.inputs["A"])
    rim_amt = nt.nodes.new("ShaderNodeMapRange")
    rim_amt.inputs["To Min"].default_value = 0.34
    rim_amt.inputs["To Max"].default_value = 0.0
    nt.links.new(lw.outputs["Facing"], rim_amt.inputs["Value"])
    nt.links.new(rim_amt.outputs["Result"], rim.inputs["Factor"])

    # soot only in the crevices, so it belongs to the same fire as the hull
    # without burying the mineral
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.25
    ao_inv = nt.nodes.new("ShaderNodeMath")
    ao_inv.operation = "SUBTRACT"
    ao_inv.inputs[0].default_value = 1.0
    ao_inv.use_clamp = True
    nt.links.new(ao.outputs["AO"], ao_inv.inputs[1])
    soot_amt = nt.nodes.new("ShaderNodeMath")
    soot_amt.operation = "MULTIPLY"
    soot_amt.inputs[1].default_value = 0.72
    nt.links.new(ao_inv.outputs["Value"], soot_amt.inputs[0])
    sooted = nt.nodes.new("ShaderNodeMix")
    sooted.data_type = "RGBA"
    sooted.inputs["B"].default_value = (0.020, 0.019, 0.018, 1)
    nt.links.new(rim.outputs["Result"], sooted.inputs["A"])
    nt.links.new(soot_amt.outputs["Value"], sooted.inputs["Factor"])
    nt.links.new(sooted.outputs["Result"], bsdf.inputs["Base Color"])

    # polished facets, dulled only where the soot sits
    rough = nt.nodes.new("ShaderNodeMapRange")
    rough.inputs["To Min"].default_value = 0.27
    rough.inputs["To Max"].default_value = 0.55
    nt.links.new(soot_amt.outputs["Value"], rough.inputs["Value"])
    nt.links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])

    # internal cleavage planes, shallow -- the silhouette does the shape work
    cracks = nt.nodes.new("ShaderNodeTexVoronoi")
    cracks.feature = "DISTANCE_TO_EDGE"
    cracks.inputs["Scale"].default_value = 9.0
    nt.links.new(coord.outputs["Object"], cracks.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.22
    nt.links.new(cracks.outputs["Distance"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


# --------------------------------------------------------------------------
# wreck vocabulary

def _superellipse(w, d, sides, jag, squareness, rnd):
    # Ragged rectangle: a superellipse sampled at `sides` points with a jittered
    # radius. Sampling a plain circle by angle gives a diamond at low side
    # counts, which reads as a cut shape rather than a torn one.
    pts = []
    e = 2.0 / squareness
    for i in range(sides):
        a = 2 * math.pi * (i + rnd.uniform(-0.15, 0.15)) / sides
        ca, sa = math.cos(a), math.sin(a)
        x = math.copysign(abs(ca) ** e, ca) * w * 0.5
        y = math.copysign(abs(sa) ** e, sa) * d * 0.5
        k = 1.0 + rnd.uniform(-jag, jag)
        pts.append((x * k, y * k))
    return pts


def torn_plate(coll, mats, name, pos, size, rot=0.0, tilt=(0.0, 0.0), key="steel",
               thick=0.055, jag=0.16, sides=11, squareness=5.0, seed=0):
    # A sheet ripped off the hull: ragged outline, real thickness so the torn
    # edge catches the key light, flat-shaded so the facets stay crisp.
    rnd = random.Random(seed)
    me = bpy.data.meshes.new(PREFIX + name + "M")
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, 0.0))
             for x, y in _superellipse(size[0], size[1], sides, jag, squareness, rnd)]
    bm.faces.new(verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=-thick)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(PREFIX + name, me)
    obj.data.materials.append(mats[key])
    obj.location = pos
    obj.rotation_euler = (tilt[0], tilt[1], rot)
    bpy.context.scene.collection.objects.link(obj)
    bg.link_to(obj, coll)
    bg.bevel(obj, width=min(0.016, thick * 0.3), segments=2)
    return obj


def torn_shell(coll, mats, name, pos, radius, arc, length, yaw=0.0, dome=False,
               tilt=(0.0, 0.0), key="steel", thick=0.045, jag=0.18, seed=0,
               nu=16, nv=9):
    # A curved panel torn off a drum or a housing. This is the piece that makes
    # the Space Age wrecks read: a flat plate is a plate from any angle, but a
    # curved shell shows its dark concave inside and says the machine was hollow.
    #
    # The cross-section is built ALREADY UPRIGHT and resting on z=0. Generating
    # it around the local origin and rotating the object into place instead put
    # every shell a full `radius` into the air -- they floated, and one of them
    # was single-handedly the tallest thing in the sprite.
    rnd = random.Random(seed)
    me = bpy.data.meshes.new(PREFIX + name + "M")
    bm = bmesh.new()
    drop = math.cos(arc / 2)
    grid = []
    for j in range(nv):
        u = (-0.5 + j / (nv - 1)) * length
        a0 = -arc / 2 * (1 - rnd.uniform(0, jag))     # each row spans a slightly
        a1 = arc / 2 * (1 - rnd.uniform(0, jag))      # different arc -> ragged sides
        row = []
        for i in range(nu):
            a = a0 + (a1 - a0) * i / (nu - 1)
            y = radius * math.sin(a)
            z = radius * (math.cos(a) - drop) if dome else radius * (1 - math.cos(a))
            row.append(bm.verts.new((u, y, z)))
        grid.append(row)
    for i in range(nu):                                # ...and ragged ends
        grid[0][i].co.x += length * rnd.uniform(0, jag)
        grid[nv - 1][i].co.x -= length * rnd.uniform(0, jag)
    for j in range(nv - 1):
        for i in range(nu - 1):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(PREFIX + name, me)
    obj.data.materials.append(mats[key])
    obj.location = pos
    obj.rotation_euler = (tilt[0], tilt[1], yaw)
    bpy.context.scene.collection.objects.link(obj)
    bg.link_to(obj, coll)
    sol = obj.modifiers.new("Sol", "SOLIDIFY")
    sol.thickness = thick
    bg.smooth(obj, angle=50)
    return obj


def _in_span(a, a0, a1):
    span = (a1 - a0) % (2 * math.pi)
    if span < 1e-6:
        return True
    return ((a - a0) % (2 * math.pi)) <= span


def ring_arc(coll, mats, name, major, minor, loc, span=None, rot=(0, 0, 0),
             squash=(1.0, 1.0, 0.7), pods=(), key="ring"):
    # A containment coil after the fact: optionally cut to an arc, then squashed
    # non-uniformly so it reads as bent metal rather than a tidy torus.
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=64, minor_segments=14,
                                     location=(0, 0, 0))
    ring = bpy.context.object
    ring.name = PREFIX + name
    if span is not None:
        me = ring.data
        bm = bmesh.new()
        bm.from_mesh(me)
        kill = [v for v in bm.verts
                if not _in_span(math.atan2(v.co.y, v.co.x), span[0], span[1])]
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
        bm.to_mesh(me)
        bm.free()
    ring.data.materials.append(mats[key])
    ring.scale = squash
    ring.location = loc
    ring.rotation_euler = rot
    bg.smooth(ring)
    bg.link_to(ring, coll)

    for i, (ang, size) in enumerate(pods):
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2, radius=1.0,
            location=(major * math.cos(ang), major * math.sin(ang), 0))
        pod = bpy.context.object
        pod.name = PREFIX + name + "Pod%d" % i
        pod.scale = size
        pod.rotation_euler = (0, 0, ang)
        pod.data.materials.append(mats["holmium"])
        bg.smooth(pod)
        bg.link_to(pod, coll)
        pod.parent = ring
        for k, sgn in enumerate((-1, 1)):
            ca = ang + sgn * 0.23
            clamp = bg.cube("%sClamp%d%d" % (name, i, k),
                            (minor * 2.2, minor * 0.9, minor * 2.2),
                            (major * math.cos(ca), major * math.sin(ca), 0),
                            (0, 0, ca), mats["gunmetal"])
            bg.bevel(clamp, width=0.012, segments=2)
            bg.link_to(clamp, coll)
            clamp.parent = ring
    return ring


def pylon_arm(coll, mats, name, loc, rot, length=2.25, bow=0.42, radius=0.19,
              coil=True, tip=True, key="steel"):
    # The electrode arm, built along +X at the origin and then laid wherever it
    # landed. Same bowed taper as the standing pylon so a player recognises it.
    taper_curve = bpy.data.curves.new(PREFIX + name + "TaperC", "CURVE")
    taper_curve.dimensions = "2D"
    tspl = taper_curve.splines.new("POLY")
    tspl.points.add(1)
    tspl.points[0].co = (0, 1.0, 0, 1)
    tspl.points[1].co = (1, 0.5, 0, 1)
    taper = bpy.data.objects.new(PREFIX + name + "Taper", taper_curve)
    bpy.context.scene.collection.objects.link(taper)
    bg.link_to(taper, coll)

    root, tip_pos = Vector((0, 0, 0)), Vector((length, 0, 0))
    h0 = Vector((length * 0.33, 0, bow))
    h1 = Vector((length * 0.72, 0, bow * 0.85))
    curve = bpy.data.curves.new(PREFIX + name + "C", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 6
    curve.use_fill_caps = True
    curve.taper_object = taper
    spl = curve.splines.new("BEZIER")
    spl.bezier_points.add(1)
    p0, p1 = spl.bezier_points
    p0.co = root
    p0.handle_left = root - (h0 - root)
    p0.handle_right = h0
    p1.co = tip_pos
    p1.handle_left = h1
    p1.handle_right = tip_pos + (tip_pos - h1)
    arm = bpy.data.objects.new(PREFIX + name, curve)
    arm.data.materials.append(mats[key])
    bpy.context.scene.collection.objects.link(arm)
    bg.link_to(arm, coll)
    taper.parent = arm

    ctrl = (root, h0, h1, tip_pos)
    children = []
    on_curve = bg.bezier_pt(ctrl, 0.45)
    collar = bg.cylinder(name + "Collar", 0.23, 0.16, on_curve, material=mats["gunmetal"])
    collar.rotation_euler = (0, math.radians(90), 0)
    bg.bevel(collar, width=0.03)
    bg.smooth(collar)
    bg.link_to(collar, coll)
    children.append(collar)
    if tip:
        cap = bg.cylinder(name + "Cap", 0.15, 0.16, tip_pos,
                          (0, math.radians(90), 0), mats["steel_dark"])
        bg.bevel(cap, width=0.03)
        bg.smooth(cap)
        bg.link_to(cap, coll)
        children.append(cap)
        # the emitter bead, dark: this is the one part a player watched glow
        bead = bg.sphere(name + "Tip", 0.09, tip_pos + Vector((0.13, 0, 0)),
                         mats["socket_dark"])
        bg.smooth(bead)
        bg.link_to(bead, coll)
        children.append(bead)
    if coil:
        c = bg.helix_on_bezier(coll, mats, name + "Coil", ctrl, 0.05, 0.34,
                               turns=4.5, wire=0.036,
                               radius_at=lambda t: radius * (1.0 - 0.5 * t))
        children.append(c)
        seat = bg.cylinder(name + "Seat", 0.26, 0.07, bg.bezier_pt(ctrl, 0.03),
                           (0, math.radians(90), 0), mats["iron"])
        bg.smooth(seat)
        bg.link_to(seat, coll)
        children.append(seat)
    for c in children:
        c.parent = arm
    arm.location = loc
    arm.rotation_euler = rot
    return arm


def loose_coil(coll, mats, name, a, b, turns=5.0, wire=0.032, radius=0.15,
               sag=0.0, key="copper"):
    # Induction winding sprung off its pylon: a helix orbiting a straight run
    # instead of the pylon bezier, because it is no longer wrapped around
    # anything.
    a, b = Vector(a), Vector(b)
    axis = b - a
    side = Vector((-axis.y, axis.x, 0))
    side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
    up = axis.normalized().cross(side)
    curve = bpy.data.curves.new(PREFIX + name + "C", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = wire
    curve.bevel_resolution = 2
    spl = curve.splines.new("POLY")
    n = max(int(turns * 18), 12)
    spl.points.add(n - 1)
    for k in range(n):
        s = k / (n - 1)
        ang = 2 * math.pi * turns * s
        # the loops open out where the winding was pulled apart
        r = radius * (0.75 + 0.5 * s)
        p = (a + axis * s + side * (r * math.cos(ang)) + up * (r * math.sin(ang))
             - Vector((0, 0, sag * math.sin(math.pi * s))))
        spl.points[k].co = (p.x, p.y, p.z, 1)
    obj = bpy.data.objects.new(PREFIX + name, curve)
    obj.data.materials.append(mats[key])
    bpy.context.scene.collection.objects.link(obj)
    bg.link_to(obj, coll)
    return obj


def crystal_half(coll, mats, name, pos, rot, scale=1.0, seed=0):
    # One recognisable half of the core: the same 6-sided bipyramid profile the
    # intact crystal is built from, so a player who watched it spin recognises
    # the piece. Two side faces are torn away and the rim is chipped.
    rnd = random.Random(seed)
    me = bpy.data.meshes.new(PREFIX + name + "M")
    bm = bmesh.new()
    r, h = 0.46 * scale, 0.86 * scale
    ring = []
    for i in range(6):
        a = 2 * math.pi * i / 6
        j = rnd.uniform(0.86, 1.14)
        ring.append(bm.verts.new((r * j * math.cos(a), r * j * math.sin(a), 0.0)))
    waist = []
    for i in range(6):
        a = 2 * math.pi * i / 6
        j = rnd.uniform(0.88, 1.12)
        waist.append(bm.verts.new((r * 0.62 * j * math.cos(a),
                                   r * 0.62 * j * math.sin(a), h * 0.58)))
    tip = bm.verts.new((rnd.uniform(-0.10, 0.10) * r, rnd.uniform(-0.10, 0.10) * r, h))
    bm.faces.new(list(reversed(ring)))              # the fracture plane
    broken = rnd.randrange(6)
    for i in range(6):
        k = (i + 1) % 6
        if i == broken:                             # a facet sheared clean off
            continue
        bm.faces.new((ring[i], ring[k], waist[k], waist[i]))
        bm.faces.new((waist[i], waist[k], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(PREFIX + name, me)
    obj.data.materials.append(mats["crystal_dead"])
    obj.location = pos
    obj.rotation_euler = rot
    bpy.context.scene.collection.objects.link(obj)
    bg.link_to(obj, coll)
    sol = obj.modifiers.new("Sol", "SOLIDIFY")
    sol.thickness = 0.03
    return obj


def crystal_shard(coll, mats, name, pos, rot, length=0.45, radius=0.10, sides=5, seed=0):
    # A splinter of the core: a tapered prism with a point at one end and a flat
    # fracture at the other. The previous version was a jittered icosphere and
    # read as gravel -- crystal is prismatic and pointed, and at 64 px/tile the
    # silhouette is the only thing carrying that.
    rnd = random.Random(seed)
    me = bpy.data.meshes.new(PREFIX + name + "M")
    bm = bmesh.new()
    base, mid = [], []
    for i in range(sides):
        a = 2 * math.pi * i / sides
        j = rnd.uniform(0.78, 1.22)
        base.append(bm.verts.new((radius * j * math.cos(a), radius * j * math.sin(a), 0.0)))
        mid.append(bm.verts.new((radius * 0.74 * j * math.cos(a),
                                 radius * 0.74 * j * math.sin(a), length * 0.60)))
    apex = bm.verts.new((rnd.uniform(-0.25, 0.25) * radius,
                         rnd.uniform(-0.25, 0.25) * radius, length))
    bm.faces.new(list(reversed(base)))
    for i in range(sides):
        k = (i + 1) % sides
        bm.faces.new((base[i], base[k], mid[k], mid[i]))
        bm.faces.new((mid[i], mid[k], apex))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(PREFIX + name, me)
    obj.data.materials.append(mats["crystal_dead"])
    obj.location = pos
    obj.rotation_euler = rot
    bpy.context.scene.collection.objects.link(obj)
    bg.link_to(obj, coll)
    return obj


def build_core(coll, mats, rnd, variation):
    # The core neither survived intact nor vanished: the plasma it held is long
    # gone, and the mineral that held it is lying in the crater it made.
    big, small = variation["crystal"]
    crystal_half(coll, mats, "CoreHalfA", big["pos"], big["rot"], scale=1.35,
                 seed=rnd.randrange(1 << 20))
    crystal_half(coll, mats, "CoreHalfB", small["pos"], small["rot"], scale=0.95,
                 seed=rnd.randrange(1 << 20))
    # Splinters, half of them driven into the rubble point-up. A shard standing
    # on end is what makes the group read as shattered rather than dropped.
    for i in range(7):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(0.55, 1.75)
        ln = rnd.uniform(0.30, 0.62)
        upright = i % 2 == 0
        rot = ((rnd.uniform(-0.45, 0.45), rnd.uniform(-0.45, 0.45), rnd.uniform(0, 6.28))
               if upright else
               (math.radians(90) + rnd.uniform(-0.35, 0.35), rnd.uniform(-0.3, 0.3),
                rnd.uniform(0, 6.28)))
        crystal_shard(coll, mats, "CoreChip%d" % i,
                      (r * math.cos(a) + 0.05, r * math.sin(a), 0.10),
                      rot, length=ln, radius=rnd.uniform(0.075, 0.125),
                      sides=rnd.choice((5, 5, 6)), seed=rnd.randrange(1 << 20))


def toppled(coll, build, loc, rot=(0, 0, 0)):
    # Runs one of beacon_gen's assembly builders and then tips the whole thing
    # over. The builders each emit several unparented objects, so capturing what
    # appeared and transforming it is the only way to reuse them lying down.
    before = set(bpy.data.objects)
    build()
    bpy.context.view_layer.update()      # matrix_world is stale until this runs
    made = [o for o in bpy.data.objects if o not in before]
    m = Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
    for o in made:
        if o.parent is None:
            o.matrix_world = m @ o.matrix_world
        bg.link_to(o, coll)
    return made


def wreck_canister(coll, mats, name, pos, ang, r=0.16, h=0.62, burst=False):
    # Fluoroketone tank on its side. The burst one keeps its end caps and strap
    # and loses everything between them -- a hollow trough reads as "emptied"
    # where a dented cylinder just reads as a cylinder.
    rot = (0, math.radians(90), ang)
    if burst:
        bpy.ops.mesh.primitive_cylinder_add(vertices=28, radius=r, depth=h,
                                            location=pos, rotation=rot)
        shell = bpy.context.object
        shell.name = PREFIX + name
        me = shell.data
        bm = bmesh.new()
        bm.from_mesh(me)
        # keep the lower half only, in the shell's own frame
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x < -0.25 * r],
                         context="VERTS")
        bm.to_mesh(me)
        bm.free()
        shell.data.materials.append(mats["glass"])
        sol = shell.modifiers.new("Sol", "SOLIDIFY")
        sol.thickness = 0.018
        bg.smooth(shell)
        bg.link_to(shell, coll)
    else:
        shell = bg.cylinder(name, r, h, pos, rot, mats["glass"], verts=28)
        bg.smooth(shell)
        bg.link_to(shell, coll)
    d = Vector((math.cos(ang), math.sin(ang), 0))
    for k, s in enumerate((-1, 1)):
        cap = bg.cylinder(name + "Cap%d" % k, r * 1.12, 0.07,
                          Vector(pos) + d * (s * (h / 2 + 0.01)), rot,
                          mats["iron"], verts=20)
        bg.bevel(cap, width=0.02, segments=2)
        bg.smooth(cap)
        bg.link_to(cap, coll)
    bpy.ops.mesh.primitive_torus_add(major_radius=r * 1.06, minor_radius=r * 0.10,
                                     major_segments=20, minor_segments=8,
                                     location=Vector(pos) + d * (h * 0.2),
                                     rotation=rot)
    strap = bpy.context.object
    strap.name = PREFIX + name + "Strap"
    strap.data.materials.append(mats["iron"])
    bg.smooth(strap)
    bg.link_to(strap, coll)
    return shell


# --------------------------------------------------------------------------
# the wreck

def build_floor(coll, mats, rnd):
    # Deck plating, heaved. Deliberately NOT a paved footprint: four slab
    # quarters covering the tile square read as a cracked floor and hide
    # everything under them, which is the opposite of what a wreck is for.
    # These are smaller, tilted hard, and leave the middle open.
    frags = [
        ("DeckBL", (-1.58, 1.38, 0.24), (1.55, 1.30), 0.35, (0.24, -0.11), "rusty"),
        ("DeckBR", (1.66, 1.12, 0.26), (1.40, 1.55), -0.52, (-0.19, 0.26), "steel"),
        ("DeckFL", (-1.48, -1.45, 0.22), (1.45, 1.35), -0.26, (0.30, 0.17), "burnt"),
        ("DeckFR", (1.52, -1.34, 0.28), (1.55, 1.25), 0.64, (-0.13, -0.28), "rusty"),
        ("DeckB", (0.20, 1.78, 0.20), (0.95, 0.80), 0.10, (0.33, 0.0), "steel"),
        ("DeckF", (-0.22, -1.80, 0.18), (1.05, 0.75), -0.09, (-0.36, 0.0), "burnt"),
        # two inboard shards, so the open middle is not a clean circle
        ("DeckI0", (-0.95, 0.62, 0.20), (0.85, 0.70), 0.9, (0.42, 0.20), "bare"),
        ("DeckI1", (1.02, -0.48, 0.19), (0.80, 0.75), -0.7, (-0.38, -0.22), "bare"),
    ]
    for name, pos, size, rot, tilt, key in frags:
        torn_plate(coll, mats, name, pos, size, rot=rot, tilt=tilt, key=key,
                   thick=0.16, jag=0.15, sides=11, squareness=4.0,
                   seed=rnd.randrange(1 << 20))

    # Exposed frame, in broken lengths at unrelated angles. Two full-length
    # ribs crossing at the centre turn the crater into a wheel with spokes --
    # the eye reads that as a deliberate graphic, not as wreckage.
    for i, (x, y, ln, a, tilt) in enumerate(((-1.05, 0.72, 1.5, 0.42, 0.10),
                                             (0.88, 1.15, 1.2, 2.05, -0.14),
                                             (0.45, -1.20, 1.7, 1.35, 0.07),
                                             (-1.35, -0.55, 1.0, 2.75, 0.18))):
        rib = bg.cube("Rib%d" % i, (ln, 0.13, 0.12), (x, y, 0.16), (0, tilt, a),
                      mats["gunmetal"])
        bg.bevel(rib, width=0.02, segments=2)
        bg.link_to(rib, coll)


def build_hollow(coll, mats, rnd):
    # Where the core was. Nothing survives of it -- an unconfined plasma core
    # vents rather than falling over -- so the centre is a hole, and the deck
    # around it is peeled up and pointing outward.
    # No disc. A horizontal dark cylinder here renders as a big black circle
    # and reads as a hole punched in the artwork -- the one shape nothing in
    # vanilla's wrecks has. The crater floor is overlapping burnt fragments
    # instead, so no circular edge exists anywhere in the middle.
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.9
        r = rnd.uniform(0.0, 0.52)
        torn_plate(coll, mats, "Crater%d" % i,
                   (r * math.cos(a) + 0.02, r * math.sin(a) + 0.05,
                    0.02 + rnd.uniform(0, 0.06)),
                   (rnd.uniform(0.80, 1.20), rnd.uniform(0.70, 1.10)),
                   rot=rnd.uniform(0, 6.28),
                   tilt=(rnd.uniform(-0.16, 0.16), rnd.uniform(-0.16, 0.16)),
                   key="burnt", thick=0.05, jag=0.24, sides=9, squareness=2.2,
                   seed=rnd.randrange(1 << 20))
    # the well's collar, split open rather than a tidy ring
    ring_arc(coll, mats, "WellLip", 0.96, 0.11, (0.02, 0.05, 0.14),
             span=(0.55, 5.7), squash=(1.0, 1.0, 0.8), key="burnt")
    # deck peeled up and outward around the hole -- steep, because the blast
    # came from underneath and this is the only place the sprite gets height
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.35
        r = 1.08 + rnd.uniform(-0.06, 0.12)
        torn_plate(coll, mats, "Peel%d" % i,
                   (r * math.cos(a) + 0.02, r * math.sin(a) + 0.05, 0.20),
                   (0.66 + rnd.uniform(-0.12, 0.20), 0.36), rot=a + math.pi / 2,
                   tilt=(rnd.uniform(0.42, 0.88), 0.0),
                   key=("bare", "burnt", "rusty")[i % 3],
                   thick=0.045, jag=0.26, sides=8, squareness=2.6,
                   seed=rnd.randrange(1 << 20))
    # wreckage collapsed into the middle, the mass that keeps the centre of the
    # sprite from being dead space
    for i in range(3):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(0.24, 0.74)
        torn_plate(coll, mats, "Rubble%d" % i,
                   (r * math.cos(a) + 0.02, r * math.sin(a) + 0.05,
                    0.14 + rnd.uniform(0, 0.10)),
                   (rnd.uniform(0.34, 0.62), rnd.uniform(0.28, 0.50)),
                   rot=rnd.uniform(0, 6.28),
                   tilt=(rnd.uniform(-0.40, 0.40), rnd.uniform(-0.40, 0.40)),
                   key=("bare", "rusty", "burnt")[i % 3], thick=0.045, jag=0.28,
                   sides=7, squareness=2.4, seed=rnd.randrange(1 << 20))


def build_rim(coll, mats, rnd):
    # Rim beams: buckled where they stayed, dropped off the edge where they did
    # not. One long straight survivor keeps the 5x5 footprint legible.
    segs = [
        ("RimF0", (-1.30, -2.24, PAD_Z - 0.02), (1.90, 0.34, 0.20), 0.05, (0.06, 0.0)),
        ("RimF1", (0.95, -2.34, PAD_Z - 0.10), (1.35, 0.34, 0.20), -0.16, (-0.10, 0.12)),
        ("RimB0", (0.30, 2.22, PAD_Z - 0.04), (2.60, 0.34, 0.20), -0.03, (0.0, 0.08)),
        ("RimL0", (-2.18, 0.95, PAD_Z - 0.06), (0.34, 1.15, 0.20), 0.04, (0.10, 0.0)),
        ("RimR0", (2.22, -0.62, PAD_Z - 0.12), (0.34, 1.05, 0.20), -0.06, (-0.14, 0.0)),
        # thrown clear, lying on open ground past the pad
        ("RimOff", (0.10, -2.55, 0.09), (1.60, 0.30, 0.18), 0.30, (0.0, 0.0)),
    ]
    for name, pos, size, rot, tilt in segs:
        beam = bg.cube(name, size, pos, (tilt[0], tilt[1], rot),
                       mats["cold"] if name == "RimOff" else mats["steel"])
        bg.bevel(beam, width=0.04)
        bg.link_to(beam, coll)
    bg.rivet_row(coll, mats, "RivF", (-2.10, -2.24, PAD_Z + 0.10),
                 (-0.55, -2.24, PAD_Z + 0.10), 7)
    bg.rivet_row(coll, mats, "RivB", (-0.90, 2.22, PAD_Z + 0.10),
                 (1.45, 2.22, PAD_Z + 0.10), 8)


def build_drums(coll, mats, rnd, toppled_corner=2):
    # Corner drums. Three still stand -- leaning, capless, with the snapped
    # stub of their pylon still bolted on -- and one has gone over on its side.
    corners = [(1, 1), (1, -1), (-1, -1), (-1, 1)]
    for i, (sx, sy) in enumerate(corners):
        x, y = 1.85 * sx, 1.85 * sy
        if i == toppled_corner:
            ang = math.atan2(sy, sx)
            post = bg.cylinder("Drum%d" % i, 0.46, 1.0,
                               (x + 0.34 * sx, y + 0.30 * sy, 0.46),
                               (0, math.radians(90), ang + 0.35), mats["cold"])
            bg.bevel(post, width=0.06)
            bg.smooth(post)
            bg.link_to(post, coll)
            continue
        h = 0.50 if i == 1 else 0.62
        post = bg.cylinder("Drum%d" % i, 0.46, h, (x, y, h / 2 - 0.06),
                           (rnd.uniform(-0.16, 0.16), rnd.uniform(-0.16, 0.16), 0),
                           mats["steel"])
        bg.bevel(post, width=0.06)
        bg.smooth(post)
        bg.link_to(post, coll)
        # sheared open at the top, with the winding seat still bolted on
        torn_plate(coll, mats, "DrumTop%d" % i, (x, y, h - 0.08), (0.86, 0.86),
                   rot=rnd.uniform(0, 3.0),
                   tilt=(rnd.uniform(-0.22, 0.22), rnd.uniform(-0.22, 0.22)),
                   key="burnt", thick=0.05, jag=0.20, sides=9, squareness=2.0,
                   seed=rnd.randrange(1 << 20))
        if i == 3:
            # one snapped pylon root left, folded almost flat over its drum --
            # upright stubs on every corner put 90 px of empty height into the
            # sprite and read as spouts
            pylon_arm(coll, mats, "DrumStub", (x, y, h - 0.02),
                      (0, math.radians(20), math.atan2(sy, sx)),
                      length=0.78, bow=0.12, radius=0.19, coil=True, tip=False)


def build_rings(coll, mats, variation):
    # The hero. The outer coil came down more or less whole and bent; the inner
    # one snapped, and its two arcs are the pieces that landed furthest out.
    # Thicker than the coils were: intact, they read through their lit seams,
    # and a dead 0.105 band is 7 source px of dark grey that disappears into
    # the rubble. Mass is the only thing carrying them now.
    ring_arc(coll, mats, "RingOuter", 1.5, 0.155, (0.12, 0.24, 0.42),
             span=(0.5, 5.9),                               # snapped, nearly whole
             rot=(math.radians(9), math.radians(-5), math.radians(24)),
             squash=(1.18, 0.80, 0.55),
             pods=[(1.1, (0.20, 0.15, 0.12)),
                   (2.8, (0.20, 0.15, 0.12)),
                   (4.4, (0.20, 0.15, 0.12))])              # fourth pod torn off
    a, b = variation["arcs"]
    ring_arc(coll, mats, "RingInnerA", 1.0, 0.125, a["loc"], span=a["span"],
             rot=a["rot"], squash=(1.05, 0.94, 0.62),
             pods=[(a["pod"], (0.16, 0.12, 0.10))])
    ring_arc(coll, mats, "RingInnerB", 1.0, 0.125, b["loc"], span=b["span"],
             rot=b["rot"], squash=(0.96, 1.08, 0.62),
             pods=[(b["pod"], (0.16, 0.12, 0.10))])


def build_plant(coll, mats, rnd, variation):
    # Big curved bodies first. Compared side by side at game scale, the single
    # clearest difference from vanilla was that vanilla wrecks are full of
    # cylinders -- tanks, domes, fat corrugated hose -- while this one was a
    # mosaic of flat plates. Curvature is what gives a wreck its highlights.
    for i, (x, y, z, r, ln, ang, key) in enumerate(variation["tanks"]):
        bg.tank_h(coll, mats, "Tank%d" % i, r, ln, (x, y, z), ang, mat_key=key)
    # Support plant, thrown outward. These are the pieces carrying the surviving
    # paint and the surviving rime, so they are what keeps the wreck from
    # reading as an anonymous grey pile.
    toppled(coll, lambda: bg.radiator(coll, mats, "Rad", (0, 0, 0), ang=0.0),
            variation["radiator"][0], variation["radiator"][1])
    toppled(coll, lambda: bg.grate_panel(coll, mats, "Grate", (0, 0, 0), (0.85, 0.62), bars=8),
            variation["grate"][0], variation["grate"][1])
    toppled(coll, lambda: bg.manifold(coll, mats, "Man", (0, 0, 0), 0.0),
            variation["manifold"][0], variation["manifold"][1])

    for i, c in enumerate(variation["canisters"]):
        wreck_canister(coll, mats, "Can%d" % i, c["pos"], c["ang"], burst=c["burst"])

    # severed lines, still anchored at one end inside the wreck
    for i, (a, b) in enumerate(variation["hoses"]):
        bg.hose_run(coll, mats, "Hose%d" % i, a, b, sag=0.12, lateral=0.34,
                    rings=11, radius=0.135, mat_key="hose")
    # ruptured pipe stubs poking out of the deck
    for i, (x, y, ang) in enumerate(((-0.95, 1.62, 0.7), (1.42, -0.62, -0.5),
                                     (0.35, 1.85, 2.4))):
        bg.pipe_run(coll, mats, "PipeStub%d" % i,
                    [(x, y, PAD_Z + 0.02),
                     (x + 0.30 * math.cos(ang), y + 0.30 * math.sin(ang), PAD_Z + 0.20),
                     (x + 0.62 * math.cos(ang), y + 0.62 * math.sin(ang), PAD_Z + 0.14)],
                    0.055, mat_key="copper", flange_ts=(0.15,))


def build_debris(coll, mats, rnd, variation):
    # Torn hull panels: the Space Age remnant grammar, and what does most of the
    # work for "the machine came apart". Some landed paint-up, some underside-up.
    for i, (x, y, w, d, rot, key) in enumerate(variation["panels"]):
        torn_plate(coll, mats, "Panel%d" % i, (x, y, 0.06 + rnd.uniform(0, 0.05)),
                   (w, d), rot=rot,
                   tilt=(rnd.uniform(-0.13, 0.13), rnd.uniform(-0.13, 0.13)),
                   key=key, thick=0.055, jag=0.20, sides=11, squareness=4.0,
                   seed=rnd.randrange(1 << 20))

    # Curved shells off the drums and the containment housing. Mostly troughs
    # rather than domes, so the camera sees into their dark insides.
    for i, (x, y, z, r, arc, ln, yaw, dome, key) in enumerate(variation["shells"]):
        torn_shell(coll, mats, "Shell%d" % i, (x, y, z), r, arc, ln, yaw=yaw,
                   dome=dome, tilt=(rnd.uniform(-0.10, 0.10), rnd.uniform(-0.10, 0.10)),
                   key=key, thick=0.045, jag=0.20, seed=rnd.randrange(1 << 20))

    for i, (a, b, turns, radius) in enumerate(variation["coils"]):
        loose_coil(coll, mats, "Coil%d" % i, a, b, turns=turns, radius=radius,
                   wire=0.033, sag=0.05)

    # small shards and hardware flung clear -- placed by polar scatter so the
    # spray reads as radial, which is the one thing that says "it went off"
    kinds = ("bolt", "bolt", "stub", "box", "clip")
    for i in range(variation["scatter"]):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(*variation["scatter_r"])
        x, y = r * math.cos(a), r * math.sin(a)
        z = 0.04 if r > 2.30 else 0.30
        bg.greeble(coll, mats, "Frag%d" % i, kinds[i % len(kinds)], (x, y, z),
                   rnd.uniform(0, 6.28), rnd.uniform(1.1, 2.0))
    for i in range(variation["shards"]):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(*variation["shard_r"])
        torn_plate(coll, mats, "Shard%d" % i,
                   (r * math.cos(a), r * math.sin(a), 0.035),
                   (rnd.uniform(0.30, 0.62), rnd.uniform(0.24, 0.50)),
                   rot=rnd.uniform(0, 6.28),
                   tilt=(rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25)),
                   key=rnd.choice(("bare", "cold", "burnt", "rusty")),
                   thick=0.035, jag=0.28, sides=7, squareness=2.5,
                   seed=rnd.randrange(1 << 20))


# --------------------------------------------------------------------------
# variations -- vanilla's beacon remnant ships two, chosen at random per corpse

def _variation(i):
    # Positions are deliberately tight. Measured off vanilla: cryogenic-plant
    # remnants span 5.8 tiles for a 5-tile machine and nuclear-reactor remnants
    # 6.4 -- a wreck is the building collapsed in place, not a debris field.
    # An earlier pass threw pieces out to 4 tiles and rendered 8 tiles wide.
    if i == 0:
        return {
            "seed": 4711,
            "toppled_corner": 2,
            "arcs": (
                {"loc": (-1.92, -1.48, 0.14), "span": (0.35, 3.0),
                 "rot": (math.radians(6), math.radians(3), math.radians(38)),
                 "pod": 1.6},
                {"loc": (1.38, 1.36, PAD_Z + 0.24), "span": (3.5, 5.8),
                 "rot": (math.radians(24), math.radians(-9), math.radians(-40)),
                 "pod": 4.6},
            ),
            "pylons": (
                # across the deck, through the middle: the piece that stops the
                # crater being a gap in the composition
                {"loc": (1.62, 1.02, PAD_Z + 0.14), "rot": (0.0,
                                                            math.radians(4),
                                                            math.radians(212))},
                # flung clear, but laid ALONG the wreck's edge. Radiating
                # outward, its tip reached 4 tiles and read as a tail.
                {"loc": (1.92, -1.88, 0.16), "rot": (0.0,
                                                     math.radians(-3),
                                                     math.radians(198)),
                 "length": 1.65},
            ),
            "crystal": (
                {"pos": (0.16, -0.34, 0.16),
                 "rot": (math.radians(52), math.radians(14), math.radians(35))},
                {"pos": (-0.80, 0.60, 0.14),
                 "rot": (math.radians(108), math.radians(-18), math.radians(-52))},
            ),
            "radiator": ((-2.10, -0.92, 0.10), (math.radians(96), 0, math.radians(28))),
            "grate": ((1.05, -1.92, PAD_Z + 0.06), (0, math.radians(17), math.radians(-24))),
            "manifold": ((-1.68, 0.42, PAD_Z + 0.16), (math.radians(74), 0, math.radians(50))),
            "canisters": (
                {"pos": (-2.28, 1.05, 0.17), "ang": math.radians(24), "burst": False},
                {"pos": (1.62, 2.05, 0.16), "ang": math.radians(-52), "burst": True},
            ),
            "tanks": (
                (-1.62, -1.72, 0.42, 0.38, 1.45, math.radians(28), "rusty"),
                (1.28, 1.92, 0.36, 0.32, 1.15, math.radians(-64), "cold"),
            ),
            "shells": (
                (-2.08, -0.32, 0.24, 0.78, 2.3, 1.55, 0.42, False, "cold"),
                (2.14, 0.66, 0.26, 0.58, 2.0, 1.15, -0.31, False, "rusty"),
                (-0.46, 2.06, 0.30, 0.70, 1.8, 1.30, 0.18, True, "rusty"),
                (0.62, -0.35, 0.46, 0.66, 2.4, 1.10, 1.15, False, "bare"),
                (1.58, -2.05, 0.22, 0.52, 2.2, 0.95, 0.86, False, "steel"),
            ),
            "hoses": (
                ((-0.62, 1.18, PAD_Z + 0.10), (-1.95, 1.92, 0.07)),
                ((1.15, -0.85, PAD_Z + 0.08), (2.18, -1.15, 0.06)),
                ((0.05, -1.55, PAD_Z + 0.06), (-0.95, -2.32, 0.06)),
            ),
            "panels": (
                (-2.22, -1.34, 1.65, 1.20, 0.42, "cold"),
                (2.30, -0.80, 1.10, 1.20, -0.31, "rusty"),
                (0.24, 2.16, 1.75, 1.15, 0.18, "bare"),
                (2.04, 1.42, 0.70, 0.62, 0.86, "rusty"),
                (-1.88, 1.92, 1.00, 0.88, -0.55, "steel"),
                (-0.80, -2.12, 1.15, 0.80, 0.09, "bare"),
            ),
            "coils": (
                ((-0.88, -1.38, PAD_Z + 0.16), (0.62, -1.88, PAD_Z + 0.12), 3.5, 0.23),
                ((-2.15, 0.32, 0.14), (-1.50, 0.88, 0.12), 3.5, 0.13),
            ),
            "scatter": 13,
            "shards": 7,
            "scatter_r": (1.35, 2.25),
            "shard_r": (1.70, 2.40),
        }
    return {
        "seed": 90210,
        "toppled_corner": 0,
        "arcs": (
            {"loc": (1.96, -1.18, 0.15), "span": (2.9, 5.6),
             "rot": (math.radians(-5), math.radians(7), math.radians(-46)),
             "pod": 4.1},
            {"loc": (-1.32, 1.55, PAD_Z + 0.22), "span": (0.7, 3.1),
             "rot": (math.radians(-21), math.radians(8), math.radians(63)),
             "pod": 1.9},
        ),
        "pylons": (
            {"loc": (-1.48, 1.14, PAD_Z + 0.14), "rot": (0.0,
                                                         math.radians(-4),
                                                         math.radians(-28))},
            {"loc": (-1.98, -1.92, 0.16), "rot": (0.0,
                                                  math.radians(3),
                                                  math.radians(-14)),
             "length": 1.65},
        ),
        "crystal": (
            {"pos": (-0.24, -0.28, 0.16),
             "rot": (math.radians(-48), math.radians(-16), math.radians(-42))},
            {"pos": (0.84, 0.56, 0.14),
             "rot": (math.radians(112), math.radians(16), math.radians(58))},
        ),
        "radiator": ((2.16, 1.18, 0.10), (math.radians(-92), 0, math.radians(-36))),
        "grate": ((-1.25, -1.78, PAD_Z + 0.06), (0, math.radians(-21), math.radians(31))),
        "manifold": ((1.52, 0.68, PAD_Z + 0.16), (math.radians(-70), 0, math.radians(-44))),
        "canisters": (
            {"pos": (2.32, -0.30, 0.17), "ang": math.radians(-68), "burst": False},
            {"pos": (-1.42, 2.16, 0.16), "ang": math.radians(36), "burst": True},
        ),
        "tanks": (
            (1.58, -1.78, 0.42, 0.38, 1.45, math.radians(-28), "rusty"),
            (-1.22, 1.88, 0.36, 0.32, 1.15, math.radians(64), "cold"),
        ),
        "shells": (
            (2.06, -0.38, 0.24, 0.78, 2.3, 1.55, -0.38, False, "cold"),
            (-2.16, 0.62, 0.26, 0.58, 2.0, 1.15, 0.29, False, "rusty"),
            (0.62, 2.02, 0.30, 0.70, 1.8, 1.30, -0.14, True, "rusty"),
            (-0.58, -0.42, 0.46, 0.66, 2.4, 1.10, -1.05, False, "bare"),
            (-1.68, -1.98, 0.22, 0.52, 2.2, 0.95, -0.79, False, "steel"),
        ),
        "hoses": (
            ((0.72, 1.28, PAD_Z + 0.10), (1.98, 1.82, 0.07)),
            ((-1.25, -0.75, PAD_Z + 0.08), (-2.20, -0.92, 0.06)),
            ((0.35, -1.45, PAD_Z + 0.06), (1.16, -2.36, 0.06)),
        ),
        "panels": (
            (2.24, -1.30, 1.65, 1.20, -0.38, "cold"),
            (-2.28, -0.78, 1.15, 1.20, 0.29, "rusty"),
            (-0.34, 2.12, 1.75, 1.15, -0.14, "bare"),
            (-2.10, 1.40, 0.70, 0.62, -0.79, "rusty"),
            (1.88, 1.88, 1.00, 0.88, 0.61, "steel"),
            (0.88, -2.10, 1.15, 0.82, -0.07, "bare"),
        ),
        "coils": (
            ((0.92, -1.24, PAD_Z + 0.16), (-0.60, -1.82, PAD_Z + 0.12), 3.5, 0.23),
            ((2.10, 0.50, 0.14), (1.45, 1.14, 0.12), 3.5, 0.13),
        ),
        "scatter": 14,
        "shards": 8,
        "scatter_r": (1.35, 2.28),
        "shard_r": (1.70, 2.42),
    }



def build_scene(variation=0):
    bg.clean()
    wreck = bg.coll("Wreck")
    footprint = bg.coll("Footprint")
    mats = wreck_materials()
    v = _variation(variation)
    rnd = random.Random(v["seed"])

    build_floor(wreck, mats, rnd)
    build_hollow(wreck, mats, rnd)
    build_rim(wreck, mats, rnd)
    build_drums(wreck, mats, rnd, toppled_corner=v["toppled_corner"])
    build_rings(wreck, mats, v)
    for i, p in enumerate(v["pylons"]):
        pylon_arm(wreck, mats, "Pylon%d" % i, p["loc"], p["rot"],
                  length=p.get("length", 2.25),
                  key="steel" if i == 0 else "cold")
    build_core(wreck, mats, rnd, v)
    build_plant(wreck, mats, rnd, v)
    build_debris(wreck, mats, rnd, v)

    bpy.ops.mesh.primitive_plane_add(size=5.0, location=(0, 0, 0.001))
    plane = bpy.context.object
    plane.name = PREFIX + "FootprintPlane"
    plane.data.materials.append(mats["footprint"])
    bg.link_to(plane, footprint)

    bpy.context.view_layer.update()
    return {"wreck": wreck, "footprint": footprint}
