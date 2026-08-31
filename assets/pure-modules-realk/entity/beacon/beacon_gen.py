# Scene generator for the Pure beacon. Primitives + modifiers, no sculpting,
# so the whole model rebuilds deterministically. Idempotent: deletes its own
# PB_* objects and rebuilds. Units: 1 Blender unit = 1 Factorio tile.
#
# Value targets measured off vanilla (cryogenic-plant-main.png quantized):
# lit panels sRGB 100-150, highlights ~200, ~30% of the sprite below sRGB 70.
# Base colours below are linear and deliberately dark; vanilla reads dark.
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

PREFIX = "PB_"

REPO_ROOT = Path(__file__).resolve().parents[4]
POLYHAVEN_DIR = REPO_ROOT / "assets" / "third-party" / "polyhaven"

# Socket centres in tiles, entity-relative; -Y is the camera-facing front.
SOCKET_POSITIONS = [(-1.5, -2.3), (-0.5, -2.3), (0.5, -2.3), (1.5, -2.3)]

# Pylon tip world positions, filled in by build_pylons; arc anchors.
TIP_POSITIONS = []
# Pylon bezier control points, same order, so the coils and cables that wrap
# a pylon can be evaluated on the curve instead of guessing at the chord.
PYLON_CURVES = []

# One beat of the discharge cycle: charge climbs an electrode from its
# induction coil to the tip, the tip flashes, then it fires into the core.
# Both counts are frames of the 64-frame loop.
CLIMB_FRAMES = 6
ARC_FRAMES = 7
CLIMB_T0 = 0.06        # where on the pylon curve the charge enters

# (start frame, pylon indices). Pylons are indexed +x+y, +x-y, -x+y, -x-y, so
# (0, 3) and (1, 2) are the two diagonals and 0-1-3-2 walks the square.
# Diagonal, other diagonal, a wave round all four, then all four together.
ARC_BEATS = [
    (0, (0, 3)),
    (16, (1, 2)),
    (30, (0,)), (32, (1,)), (34, (3,)), (36, (2,)),
    (51, (0, 1, 2, 3)),
]

# Direction from the entity toward the camera. The climbing bolt is held on
# this side of the pylon because the arcs layer renders with the base
# collection hidden: nothing would occlude a bolt routed behind the pipe, so
# it would composite straight through the electrode instead of behind it.
VIEW_DIR = Vector((0, -1, 1)).normalized()

PYLON_R0 = 0.19        # pylon pipe bevel_depth, halved at the tip by the taper

CYAN = (0.55, 0.85, 1.0)


def srgb(hex_str):
    # sRGB hex -> linear, so a colour picked in the design doc lands as picked
    h = hex_str.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


# Aquilo palette: hot quantum-plasma core against a frozen hull.
PLASMA_DEEP = srgb("#0B7FFF")   # crystal body, saturated
PLASMA_LIT = srgb("#29B6FF")    # crystal facets catching the core
PLASMA_HOT = srgb("#EAFBFF")    # core and arc centreline, near white
ARC_OUTER = srgb("#4FD8FF")     # arc fringe
FROST = srgb("#C8DCEA")         # rime
COOLANT_HOT = srgb("#FF8A2B")
COOLANT_COLD = srgb("#6FD8FF")
LED_GREEN = srgb("#69FF8C")
LED_AMBER = srgb("#FFB020")
HEAT_ORANGE = srgb("#FF6A18")   # heat-pipe interior, the warm counterweight
# Crystal-only tones, deliberately deeper and bluer than the PLASMA_* set the
# arcs and seams share. post.form_contrast stretches each channel about one
# common pivot, so a bright saturated pixel gains chroma AND drifts in hue as
# the top channel meets the soft clip: the crystal measured (85,175,220) before
# that pass existed and (87,204,219) after, i.e. it turned turquoise. Pulling
# green down at the source, and dropping the emission so less of the crystal
# reaches the clip at all, is what holds the hue.
CRYSTAL_DEEP = srgb("#1A5CB0")
CRYSTAL_LIT = srgb("#2F80B8")
CRYSTAL_RIM = srgb("#C0DEEE")


# --------------------------------------------------------------------------
# Poly Haven photo maps -- grain only, multiplied over procedural paint. The
# cache is git-ignored, so fetch on demand and degrade to pure-procedural if
# there is no network: the render must never depend on binaries not in git.

_IMG_CACHE = {}

# Where the deck is coldest: frost thins near anything hot and thickens with
# distance from all of it, so the rime reads as a temperature map. Aquilo
# machines freeze without heating, so this is the planet's mechanic on screen.
HEAT_SOURCES = [(-1.32, -1.52), (1.72, -0.24)]


def local_image(rel):
    path = Path(__file__).resolve().parent / rel
    if not path.exists():
        print("  [texture] missing %s; run make_stencils.py" % rel)
        return None
    img = bpy.data.images.load(str(path), check_existing=True)
    img.colorspace_settings.name = "sRGB"
    return img


def photo_map(slug, kind):
    key = (slug, kind)
    if key in _IMG_CACHE:
        return _IMG_CACHE[key]
    d = POLYHAVEN_DIR / slug
    if not d.is_dir() or not list(d.glob("*_%s_*" % kind)):
        try:
            sys.path.insert(0, str(REPO_ROOT / ".claude" / "skills"
                                   / "factorio-graphics" / "scripts"))
            import polyhaven
            polyhaven.fetch(slug, res="1k")
        except Exception as exc:                     # offline, or API moved
            print("  [polyhaven] %s unavailable (%s); procedural only" % (slug, exc))
    hits = sorted(d.glob("*_%s_*.jpg" % kind)) + sorted(d.glob("*_%s_*.png" % kind)) \
        if d.is_dir() else []
    img = None
    if hits:
        img = bpy.data.images.load(str(hits[0]), check_existing=True)
        img.colorspace_settings.name = "sRGB" if kind == "diff" else "Non-Color"
    _IMG_CACHE[key] = img
    return img


# --------------------------------------------------------------------------
# scaffolding

def clean():
    for obj in [o for o in bpy.data.objects if o.name.startswith(PREFIX)]:
        bpy.data.objects.remove(obj, do_unlink=True)
    for coll in [c for c in bpy.data.collections if c.name.startswith(PREFIX)]:
        bpy.data.collections.remove(coll)


def coll(name):
    c = bpy.data.collections.new(PREFIX + name)
    bpy.context.scene.collection.children.link(c)
    return c


def link_to(obj, collection):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    collection.objects.link(obj)


def smooth(obj, angle=30):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))


def bevel(obj, width=0.05, segments=3):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    return mod


def cube(name, scale, location, rotation=(0, 0, 0), material=None):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.name = PREFIX + name
    obj.scale = scale
    obj.location = location
    obj.rotation_euler = rotation
    if material:
        obj.data.materials.append(material)
    return obj


def cylinder(name, radius, depth, location, rotation=(0, 0, 0), material=None, verts=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                        location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = PREFIX + name
    if material:
        obj.data.materials.append(material)
    return obj


def annulus(name, r_in, r_out, height, location, material=None, verts=48):
    """Flat ring with a real hole. A solid cylinder buries whatever sits under
    it -- the containment well's glow and its aperture bars rendered exactly
    zero pixels between them until this existed, because `Dish` was solid and
    they lived inside it.

    The shell is closed and non-self-intersecting, so recalc_face_normals is
    safe here; it is not safe on the overlapping-box assemblies elsewhere in
    this file.
    """
    me = bpy.data.meshes.new(PREFIX + name + "M")
    bm = bmesh.new()
    hz = height * 0.5
    ring = {}
    for r, rk in ((r_in, "i"), (r_out, "o")):
        for z, zk in ((-hz, "lo"), (hz, "hi")):
            ring[rk + zk] = [bm.verts.new((r * math.cos(2 * math.pi * i / verts),
                                           r * math.sin(2 * math.pi * i / verts), z))
                             for i in range(verts)]
    for i in range(verts):
        j = (i + 1) % verts
        bm.faces.new((ring["olo"][i], ring["olo"][j], ring["ohi"][j], ring["ohi"][i]))
        bm.faces.new((ring["ihi"][i], ring["ihi"][j], ring["ilo"][j], ring["ilo"][i]))
        bm.faces.new((ring["ohi"][i], ring["ohi"][j], ring["ihi"][j], ring["ihi"][i]))
        bm.faces.new((ring["ilo"][i], ring["ilo"][j], ring["olo"][j], ring["olo"][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(PREFIX + name, me)
    obj.location = location
    if material:
        obj.data.materials.append(material)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def sphere(name, radius, location, material=None, subdiv=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = PREFIX + name
    if material:
        obj.data.materials.append(material)
    return obj


# --------------------------------------------------------------------------
# materials

def _reset_nodes(m):
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    return nt, out


def _get_mat(name):
    m = bpy.data.materials.get(PREFIX + name)
    if m is None:
        m = bpy.data.materials.new(PREFIX + name)
    return m


RUST = (0.14, 0.055, 0.025)
# Chipped paint shows bare steel, and vanilla renders that warm rather than
# neutral -- its highlight band measures hue 41 at saturation 0.14, where this
# was a flat grey (saturation 0.04) that drained colour from every worn edge.
BARE = srgb("#9E9890")


def worn_metal(name, color_a, color_b, metallic, rough_lo, rough_hi,
               grime=0.0, noise_scale=9.0, wear=0.5, rust=0.35,
               frost=0.0, grain=0.0, grain_slug="metal_plate",
               scratch=0.0, decal=None, decal_fit=1.0):
    # Painted worn metal, Cycles-only tricks and proud of it:
    #   - pointiness masks convex edges -> chipped paint, bare shiny metal
    #   - ambient occlusion seeds rust in crevices, patchy via noise
    #   - Z-stretched noise streaks grime down the side faces
    #   - photo grain multiplied in as luminance only, so the sampled tint holds
    #   - rime on up-facing surfaces and edges: Aquilo's version of dust
    #   - roughness varies everywhere; worn edges go shiny, frost goes matte
    m = _get_mat(name)
    nt, out = _reset_nodes(m)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")

    def noise_node(scale, detail=2.6):
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        return n

    def map_range(lo, fr=(0.0, 1.0)):
        r = nt.nodes.new("ShaderNodeMapRange")
        r.inputs["From Min"].default_value = fr[0]
        r.inputs["From Max"].default_value = fr[1]
        r.inputs["To Min"].default_value = lo[0]
        r.inputs["To Max"].default_value = lo[1]
        return r

    def math_node(op, v=None):
        n = nt.nodes.new("ShaderNodeMath")
        n.operation = op
        n.use_clamp = True
        if v is not None:
            n.inputs[1].default_value = v
        return n

    def mix_color(blend="MIX"):
        n = nt.nodes.new("ShaderNodeMix")
        n.data_type = "RGBA"
        n.blend_type = blend
        return n

    def grey_of(value_out):
        n = nt.nodes.new("ShaderNodeCombineColor")
        for ch in ("Red", "Green", "Blue"):
            nt.links.new(value_out, n.inputs[ch])
        return n.outputs["Color"]

    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Object"], sep.inputs["Vector"])
    geo = nt.nodes.new("ShaderNodeNewGeometry")

    # base paint: two close tones mottled by large noise
    mottle = noise_node(noise_scale)
    paint = mix_color()
    paint.inputs["A"].default_value = (*color_a, 1.0)
    paint.inputs["B"].default_value = (*color_b, 1.0)
    nt.links.new(mottle.outputs["Fac"], paint.inputs["Factor"])
    color_out = paint.outputs["Result"]

    # photo grain: luminance only. A photo's own tint would shift the chassis
    # colour away from the value sampled off vanilla, so it never reaches
    # Base Color as colour -- only as brightness variation.
    normal_out = None
    if grain > 0:
        diff = photo_map(grain_slug, "diff")
        if diff:
            mapping = nt.nodes.new("ShaderNodeMapping")
            mapping.inputs["Scale"].default_value = (0.5, 0.5, 0.5)
            nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = diff
            tex.projection = "BOX"
            tex.projection_blend = 0.25
            nt.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
            bw = nt.nodes.new("ShaderNodeRGBToBW")
            nt.links.new(tex.outputs["Color"], bw.inputs["Color"])
            gmap = map_range((1.0 - grain, 1.0 + grain), fr=(0.12, 0.55))
            nt.links.new(bw.outputs["Val"], gmap.inputs["Value"])
            grained = mix_color("MULTIPLY")
            grained.inputs["Factor"].default_value = 1.0
            nt.links.new(color_out, grained.inputs["A"])
            nt.links.new(grey_of(gmap.outputs["Result"]), grained.inputs["B"])
            color_out = grained.outputs["Result"]

            nor = photo_map(grain_slug, "nor_gl")
            if nor:
                ntex = nt.nodes.new("ShaderNodeTexImage")
                ntex.image = nor
                ntex.projection = "BOX"
                ntex.projection_blend = 0.25
                nt.links.new(mapping.outputs["Vector"], ntex.inputs["Vector"])
                nmap = nt.nodes.new("ShaderNodeNormalMap")
                nmap.inputs["Strength"].default_value = 0.2
                nt.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
                normal_out = nmap.outputs["Normal"]

    # vertical grime streaks: object coords squashed in Z feed a noise, so it
    # smears downward the way rain-carried dirt does
    squash = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(sep.outputs["X"], squash.inputs["X"])
    nt.links.new(sep.outputs["Y"], squash.inputs["Y"])
    zmul = math_node("MULTIPLY", 0.18)
    nt.links.new(sep.outputs["Z"], zmul.inputs[0])
    nt.links.new(zmul.outputs["Value"], squash.inputs["Z"])
    streak_noise = noise_node(noise_scale * 1.6)
    nt.links.new(squash.outputs["Vector"], streak_noise.inputs["Vector"])
    streak_mask = map_range((0.0, 0.35), fr=(0.42, 0.62))
    nt.links.new(streak_noise.outputs["Fac"], streak_mask.inputs["Value"])
    streaked = mix_color("MULTIPLY")
    streaked.inputs["B"].default_value = (0.4, 0.45, 0.46, 1.0)
    nt.links.new(color_out, streaked.inputs["A"])
    nt.links.new(streak_mask.outputs["Result"], streaked.inputs["Factor"])
    color_out = streaked.outputs["Result"]

    if grime > 0:
        ramp = map_range((1.0 - grime, 1.0), fr=(-0.5, 0.6))
        nt.links.new(sep.outputs["Z"], ramp.inputs["Value"])
        gray = nt.nodes.new("ShaderNodeCombineColor")
        for ch in ("Red", "Green", "Blue"):
            nt.links.new(ramp.outputs["Result"], gray.inputs[ch])
        dark = mix_color("MULTIPLY")
        dark.inputs["Factor"].default_value = 1.0
        nt.links.new(color_out, dark.inputs["A"])
        nt.links.new(gray.outputs["Color"], dark.inputs["B"])
        color_out = dark.outputs["Result"]

    # rust: crevices (low AO) plus patchy noise
    if rust > 0:
        ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = 0.35
        ao_inv = math_node("SUBTRACT")
        ao_inv.inputs[0].default_value = 1.0
        nt.links.new(ao.outputs["AO"], ao_inv.inputs[1])
        rust_noise = noise_node(noise_scale * 0.6, detail=3.0)
        rust_patch = map_range((0.0, 1.0), fr=(0.52, 0.68))
        nt.links.new(rust_noise.outputs["Fac"], rust_patch.inputs["Value"])
        seed = math_node("MAXIMUM")
        nt.links.new(ao_inv.outputs["Value"], seed.inputs[0])
        nt.links.new(rust_patch.outputs["Result"], seed.inputs[1])
        rust_amt = math_node("MULTIPLY", rust)
        nt.links.new(seed.outputs["Value"], rust_amt.inputs[0])
        rusted = mix_color()
        rusted.inputs["B"].default_value = (*RUST, 1.0)
        nt.links.new(color_out, rusted.inputs["A"])
        nt.links.new(rust_amt.outputs["Value"], rusted.inputs["Factor"])
        color_out = rusted.outputs["Result"]

    # per-object hue/value jitter: neighbouring parts in one material family
    # never render identically (the single biggest "painted by hand" tell in
    # the reference sprites)
    obj_info = nt.nodes.new("ShaderNodeObjectInfo")
    hue_map = map_range((0.47, 0.53))
    nt.links.new(obj_info.outputs["Random"], hue_map.inputs["Value"])
    val_map = map_range((0.74, 1.26))
    nt.links.new(obj_info.outputs["Random"], val_map.inputs["Value"])
    jitter = nt.nodes.new("ShaderNodeHueSaturation")
    nt.links.new(hue_map.outputs["Result"], jitter.inputs["Hue"])
    nt.links.new(val_map.outputs["Result"], jitter.inputs["Value"])
    nt.links.new(color_out, jitter.inputs["Color"])
    color_out = jitter.outputs["Color"]

    # edge wear: convex edges chip to bare metal, patchy via fine noise
    edge = map_range((0.0, 1.0), fr=(0.53, 0.62))
    nt.links.new(geo.outputs["Pointiness"], edge.inputs["Value"])
    wear_noise = noise_node(noise_scale * 1.5)
    wear_patch = map_range((0.25, 1.0), fr=(0.35, 0.65))
    nt.links.new(wear_noise.outputs["Fac"], wear_patch.inputs["Value"])
    edge_mask = math_node("MULTIPLY")
    nt.links.new(edge.outputs["Result"], edge_mask.inputs[0])
    nt.links.new(wear_patch.outputs["Result"], edge_mask.inputs[1])
    wear_amt = math_node("MULTIPLY", wear)
    nt.links.new(edge_mask.outputs["Value"], wear_amt.inputs[0])
    worn = mix_color()
    worn.inputs["B"].default_value = (*BARE, 1.0)
    nt.links.new(color_out, worn.inputs["A"])
    nt.links.new(wear_amt.outputs["Value"], worn.inputs["Factor"])
    color_out = worn.outputs["Result"]

    # scratches: high-traffic horizontal surfaces get dragged-across marks,
    # so the noise is stretched along one axis and masked to up-facing faces
    if scratch > 0:
        sc_nrm = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Normal"], sc_nrm.inputs["Vector"])
        walked = map_range((0.0, 1.0), fr=(0.55, 0.95))
        nt.links.new(sc_nrm.outputs["Z"], walked.inputs["Value"])
        stretch = nt.nodes.new("ShaderNodeCombineXYZ")
        xmul = math_node("MULTIPLY", 0.12)
        nt.links.new(sep.outputs["X"], xmul.inputs[0])
        nt.links.new(xmul.outputs["Value"], stretch.inputs["X"])
        nt.links.new(sep.outputs["Y"], stretch.inputs["Y"])
        nt.links.new(sep.outputs["Z"], stretch.inputs["Z"])
        sc_noise = noise_node(noise_scale * 3.2, detail=1.6)
        nt.links.new(stretch.outputs["Vector"], sc_noise.inputs["Vector"])
        sc_mask = map_range((0.0, 1.0), fr=(0.62, 0.72))
        nt.links.new(sc_noise.outputs["Fac"], sc_mask.inputs["Value"])
        sc_amt = math_node("MULTIPLY")
        nt.links.new(sc_mask.outputs["Result"], sc_amt.inputs[0])
        nt.links.new(walked.outputs["Result"], sc_amt.inputs[1])
        sc_scale = math_node("MULTIPLY", scratch)
        nt.links.new(sc_amt.outputs["Value"], sc_scale.inputs[0])
        scratched = mix_color()
        scratched.inputs["B"].default_value = (*BARE, 1.0)
        nt.links.new(color_out, scratched.inputs["A"])
        nt.links.new(sc_scale.outputs["Value"], scratched.inputs["Factor"])
        color_out = scratched.outputs["Result"]

    # rime: frost settles on up-facing surfaces first and on convex edges
    # next, patchy either way. It layers over the wear because it is the last
    # thing deposited -- and it is capped low, since a heavy mask turns the
    # hull into a white blob at 64 px/tile.
    frost_amt = None
    if frost > 0:
        nrm = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Normal"], nrm.inputs["Vector"])
        up = map_range((0.0, 1.0), fr=(0.45, 0.95))
        nt.links.new(nrm.outputs["Z"], up.inputs["Value"])
        fnoise = noise_node(noise_scale * 1.3, detail=8.0)
        fpatch = map_range((0.0, 1.0), fr=(0.52, 0.70))
        nt.links.new(fnoise.outputs["Fac"], fpatch.inputs["Value"])
        flat_rime = math_node("MULTIPLY")
        nt.links.new(up.outputs["Result"], flat_rime.inputs[0])
        nt.links.new(fpatch.outputs["Result"], flat_rime.inputs[1])
        edge_rime = math_node("MULTIPLY")
        nt.links.new(edge.outputs["Result"], edge_rime.inputs[0])
        nt.links.new(fpatch.outputs["Result"], edge_rime.inputs[1])
        rime = math_node("MAXIMUM")
        nt.links.new(flat_rime.outputs["Value"], rime.inputs[0])
        nt.links.new(edge_rime.outputs["Value"], rime.inputs[1])
        # ...and thicker the further a surface sits from the radiator, which
        # is what makes the rime read as a temperature map rather than dirt
        pos = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Position"], pos.inputs["Vector"])
        flatten = nt.nodes.new("ShaderNodeCombineXYZ")
        nt.links.new(pos.outputs["X"], flatten.inputs["X"])
        nt.links.new(pos.outputs["Y"], flatten.inputs["Y"])
        nearest = None
        for src in HEAT_SOURCES:
            heat = nt.nodes.new("ShaderNodeVectorMath")
            heat.operation = "DISTANCE"
            heat.inputs[1].default_value = (*src, 0.0)
            nt.links.new(flatten.outputs["Vector"], heat.inputs[0])
            if nearest is None:
                nearest = heat.outputs["Value"]
            else:
                closer = math_node("MINIMUM")
                closer.use_clamp = False
                nt.links.new(nearest, closer.inputs[0])
                nt.links.new(heat.outputs["Value"], closer.inputs[1])
                nearest = closer.outputs["Value"]
        cold = map_range((0.45, 1.4), fr=(0.9, 2.9))
        nt.links.new(nearest, cold.inputs["Value"])
        chilled = math_node("MULTIPLY")
        nt.links.new(rime.outputs["Value"], chilled.inputs[0])
        nt.links.new(cold.outputs["Result"], chilled.inputs[1])
        frost_amt = math_node("MULTIPLY", frost)
        nt.links.new(chilled.outputs["Value"], frost_amt.inputs[0])
        frost_inv = math_node("SUBTRACT")
        frost_inv.inputs[0].default_value = 1.0
        nt.links.new(frost_amt.outputs["Value"], frost_inv.inputs[1])
        iced = mix_color()
        iced.inputs["B"].default_value = (*FROST, 1.0)
        # photo grain in the rime itself, so frost is granular rather than a
        # flat pale wash -- the one place a snow photo beats procedural noise
        snow = photo_map("snow_02", "diff")
        if snow:
            smap_node = nt.nodes.new("ShaderNodeMapping")
            smap_node.inputs["Scale"].default_value = (1.4, 1.4, 1.4)
            nt.links.new(coord.outputs["Object"], smap_node.inputs["Vector"])
            stex = nt.nodes.new("ShaderNodeTexImage")
            stex.image = snow
            stex.projection = "BOX"
            stex.projection_blend = 0.25
            nt.links.new(smap_node.outputs["Vector"], stex.inputs["Vector"])
            sbw = nt.nodes.new("ShaderNodeRGBToBW")
            nt.links.new(stex.outputs["Color"], sbw.inputs["Color"])
            sgain = map_range((0.72, 1.18), fr=(0.35, 0.9))
            nt.links.new(sbw.outputs["Val"], sgain.inputs["Value"])
            flat = nt.nodes.new("ShaderNodeRGB")
            flat.outputs["Color"].default_value = (*FROST, 1.0)
            grainy = mix_color("MULTIPLY")
            grainy.inputs["Factor"].default_value = 1.0
            nt.links.new(flat.outputs["Color"], grainy.inputs["A"])
            nt.links.new(grey_of(sgain.outputs["Result"]), grainy.inputs["B"])
            nt.links.new(grainy.outputs["Result"], iced.inputs["B"])
        nt.links.new(color_out, iced.inputs["A"])
        nt.links.new(frost_amt.outputs["Value"], iced.inputs["Factor"])
        color_out = iced.outputs["Result"]
    # stencil decal: one cell of the atlas, mapped from the object's own XY,
    # painted over everything else and then worn back off. Texture, not
    # geometry -- at 64 px/tile a stencil is ~10 px and geometry would be
    # both invisible and expensive.
    if decal is not None:
        atlas = local_image("textures/stencils.png")
        if atlas:
            col, row = decal
            dmap = nt.nodes.new("ShaderNodeMapping")
            # object coords run -0.5..0.5 whatever the object's scale, so one
            # cell of a 4x4 atlas is a scale of 0.25 and a centre offset
            dmap.inputs["Scale"].default_value = (0.25 * decal_fit, 0.25 * decal_fit, 1.0)
            dmap.inputs["Location"].default_value = (col * 0.25 + 0.125,
                                                     (3 - row) * 0.25 + 0.125, 0.0)
            nt.links.new(coord.outputs["Object"], dmap.inputs["Vector"])
            dtex = nt.nodes.new("ShaderNodeTexImage")
            dtex.image = atlas
            dtex.extension = "CLIP"
            nt.links.new(dmap.outputs["Vector"], dtex.inputs["Vector"])
            flake = noise_node(noise_scale * 3.5)
            flake_mask = map_range((0.55, 1.0), fr=(0.4, 0.62))
            nt.links.new(flake.outputs["Fac"], flake_mask.inputs["Value"])
            ink = math_node("MULTIPLY")
            nt.links.new(dtex.outputs["Alpha"], ink.inputs[0])
            nt.links.new(flake_mask.outputs["Result"], ink.inputs[1])
            painted = mix_color()
            painted.inputs["B"].default_value = (0.74, 0.73, 0.68, 1.0)
            nt.links.new(color_out, painted.inputs["A"])
            nt.links.new(ink.outputs["Value"], painted.inputs["Factor"])
            color_out = painted.outputs["Result"]
    nt.links.new(color_out, bsdf.inputs["Base Color"])

    # metallic and roughness follow the wear: chipped edges are bare and shiny
    met = map_range((metallic, 0.75))
    nt.links.new(wear_amt.outputs["Value"], met.inputs["Value"])
    met_out = met.outputs["Result"]
    if frost_amt is not None:                  # ice is not metal
        no_shine = math_node("MULTIPLY")
        nt.links.new(met_out, no_shine.inputs[0])
        nt.links.new(frost_inv.outputs["Value"], no_shine.inputs[1])
        met_out = no_shine.outputs["Value"]
    nt.links.new(met_out, bsdf.inputs["Metallic"])

    rnoise = noise_node(noise_scale * 2.1)
    rmap = map_range((rough_lo, rough_hi))
    nt.links.new(rnoise.outputs["Fac"], rmap.inputs["Value"])
    rough_worn = map_range((0.0, -1.0))  # subtracts up to 1 at full wear
    nt.links.new(wear_amt.outputs["Value"], rough_worn.inputs["Value"])
    rough = math_node("MULTIPLY_ADD")
    rough.use_clamp = True
    nt.links.new(rough_worn.outputs["Result"], rough.inputs[0])
    rough.inputs[1].default_value = 0.35
    nt.links.new(rmap.outputs["Result"], rough.inputs[2])
    rough_out = rough.outputs["Value"]
    if frost_amt is not None:                  # rime is matte
        kept = math_node("MULTIPLY")
        nt.links.new(rough_out, kept.inputs[0])
        nt.links.new(frost_inv.outputs["Value"], kept.inputs[1])
        added = math_node("MULTIPLY", 0.92)
        nt.links.new(frost_amt.outputs["Value"], added.inputs[0])
        matte = math_node("ADD")
        nt.links.new(kept.outputs["Value"], matte.inputs[0])
        nt.links.new(added.outputs["Value"], matte.inputs[1])
        rough_out = matte.outputs["Value"]
    nt.links.new(rough_out, bsdf.inputs["Roughness"])

    if normal_out is not None:
        nt.links.new(normal_out, bsdf.inputs["Normal"])

    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def plain(name, color, metallic=0.2, rough=0.6, emission=None, strength=1.8):
    m = _get_mat(name)
    nt, out = _reset_nodes(m)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def emission_only(name, color, strength=1.0):
    m = _get_mat(name)
    nt, out = _reset_nodes(m)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1.0)
    em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def rubber(name, color=(0.017, 0.018, 0.021)):
    # Matte black hose. The only thing that reads at sprite scale is that it
    # is dull face-on and picks up a sheen at grazing angles -- which is what
    # separates rubber from painted steel in one glance.
    m = _get_mat(name)
    nt, out = _reset_nodes(m)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.0
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.3
    rough = nt.nodes.new("ShaderNodeMapRange")
    rough.inputs["To Min"].default_value = 0.88
    rough.inputs["To Max"].default_value = 0.34
    nt.links.new(lw.outputs["Facing"], rough.inputs["Value"])
    nt.links.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
    grain = nt.nodes.new("ShaderNodeTexNoise")
    grain.inputs["Scale"].default_value = 70.0
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.15
    nt.links.new(grain.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def canister_glass():
    m = _get_mat("canister_glass")
    nt, out = _reset_nodes(m)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (0.42, 0.56, 0.62, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.14
    # alpha rather than transmission: refraction through a thin cylinder at
    # 64 px/tile buys nothing and costs samples, and alpha keeps the fluid
    # behind it legible
    bsdf.inputs["Alpha"].default_value = 0.26
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def screen_readout(color=(0.30, 0.80, 1.0), strength=0.95):
    # The hero light: one backlit console, brighter and larger than any
    # indicator, so the eye has somewhere to land. Rows of glyph blocks read
    # as a readout at 64 px/tile; actual legibility is not the point.
    m = _get_mat("screen_readout")
    nt, out = _reset_nodes(m)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (0.02, 0.03, 0.04, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.0
    # matte and barely specular: tilted up at the key sun, a glossy screen
    # returns a white blowout that swallows the emission colour entirely
    bsdf.inputs["Roughness"].default_value = 0.68
    bsdf.inputs["Specular IOR Level"].default_value = 0.08
    coord = nt.nodes.new("ShaderNodeTexCoord")
    rows = nt.nodes.new("ShaderNodeTexWave")
    rows.bands_direction = "Y"
    rows.inputs["Scale"].default_value = 4.5
    nt.links.new(coord.outputs["Object"], rows.inputs["Vector"])
    row_ramp = nt.nodes.new("ShaderNodeMapRange")
    row_ramp.inputs["From Min"].default_value = 0.35
    row_ramp.inputs["From Max"].default_value = 0.6
    row_ramp.inputs["To Min"].default_value = 0.12
    nt.links.new(rows.outputs["Fac"], row_ramp.inputs["Value"])
    blocks = nt.nodes.new("ShaderNodeTexNoise")
    blocks.inputs["Scale"].default_value = 4.0
    nt.links.new(coord.outputs["Object"], blocks.inputs["Vector"])
    block_ramp = nt.nodes.new("ShaderNodeMapRange")
    block_ramp.inputs["From Min"].default_value = 0.35
    block_ramp.inputs["From Max"].default_value = 0.65
    block_ramp.inputs["To Min"].default_value = 0.30
    nt.links.new(blocks.outputs["Fac"], block_ramp.inputs["Value"])
    lit = nt.nodes.new("ShaderNodeMath")
    lit.operation = "MULTIPLY"
    nt.links.new(row_ramp.outputs["Result"], lit.inputs[0])
    nt.links.new(block_ramp.outputs["Result"], lit.inputs[1])
    gain = nt.nodes.new("ShaderNodeMath")
    gain.operation = "MULTIPLY"
    gain.inputs[1].default_value = strength
    nt.links.new(lit.outputs["Value"], gain.inputs[0])
    bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
    nt.links.new(gain.outputs["Value"], bsdf.inputs["Emission Strength"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def coolant_fluid(name="coolant_fluid", color=None, half_height=0.31):
    # Fluoroketone. Colour-coded per tank in a hot/cold pair; the gradient is
    # kept as a lit band inside one colour rather than a rainbow.
    m = _get_mat(name)
    nt, out = _reset_nodes(m)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.25
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Object"], sep.inputs["Vector"])
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = -half_height
    rng.inputs["From Max"].default_value = half_height
    nt.links.new(sep.outputs["Z"], rng.inputs["Value"])
    tint = color or COOLANT_COLD
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.02
    ramp.color_ramp.elements[0].color = (*[c * 0.35 for c in tint], 1)
    ramp.color_ramp.elements[1].position = 0.98
    ramp.color_ramp.elements[1].color = (*tint, 1)
    mid = ramp.color_ramp.elements.new(0.45)
    mid.color = (*[min(1.0, c * 1.25 + 0.12) for c in tint], 1)
    nt.links.new(rng.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 0.9
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


HOLO_ROWS = 7.0
HOLO_SCAN_BOOST = 0.30     # peak = strength * 1.30; above ~1.35 the blue clips


def holo_glyphs(name="holo_glyph", strength=0.92, rows=HOLO_ROWS, width=0.17):
    # Rows of unequal blocks: alien text, not a lit rectangle. A flat emissive
    # plate is the classic tell -- it reads as a pastel sticker pasted onto
    # the machine, which is exactly what the first pass of this panel did --
    # so the plane is mostly TRANSPARENT and only the strokes emit. A brick
    # texture is the cheap way there: random per-brick value, unequal widths
    # from the squash, and mortar gaps that become the spaces between glyphs.
    m = _get_mat(name)
    nt, out = _reset_nodes(m)
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.name = "HoloScroll"      # animate() keyframes its Location
    nt.links.new(coord.outputs["Generated"], mapping.inputs["Vector"])
    brick = nt.nodes.new("ShaderNodeTexBrick")
    brick.offset = 0.35
    brick.offset_frequency = 2
    brick.squash = 1.7
    brick.squash_frequency = 3
    brick.inputs["Scale"].default_value = 1.0
    brick.inputs["Color1"].default_value = (1, 1, 1, 1)
    brick.inputs["Color2"].default_value = (0.24, 0.24, 0.24, 1)
    brick.inputs["Mortar"].default_value = (0, 0, 0, 1)
    brick.inputs["Mortar Size"].default_value = 0.055
    brick.inputs["Bias"].default_value = -0.15
    brick.inputs["Brick Width"].default_value = width
    brick.inputs["Row Height"].default_value = 1.0 / rows
    nt.links.new(mapping.outputs["Vector"], brick.inputs["Vector"])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*ARC_OUTER, 1.0)

    # A readout that SCROLLED would not loop: the brick pattern is random per
    # row, so after N rows of travel the image is not the one it started on.
    # So the glyphs hold still and a scan band sweeps them and wraps, which is
    # seamless by construction -- and a flicker rides on top at a whole number
    # of cycles per loop for the same reason.
    scan_t = nt.nodes.new("ShaderNodeValue")
    scan_t.name = "HoloScanT"
    flicker = nt.nodes.new("ShaderNodeValue")
    flicker.name = "HoloFlicker"
    flicker.outputs[0].default_value = 1.0
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(mapping.outputs["Vector"], sep.inputs["Vector"])

    def mth(op, a=None, b=None, c=None):
        n = nt.nodes.new("ShaderNodeMath")
        n.operation = op
        for i, v in enumerate((a, b, c)):
            if v is None:
                continue
            if hasattr(v, "default_value") or hasattr(v, "links"):
                nt.links.new(v, n.inputs[i])
            else:
                n.inputs[i].default_value = v
        return n.outputs[0]

    swept = mth("ADD", sep.outputs["Y"], scan_t.outputs[0])
    wrapped = mth("WRAP", swept, 1.0, 0.0)
    dist = mth("ABSOLUTE", mth("SUBTRACT", wrapped, 0.5))
    band = mth("LESS_THAN", dist, 0.07)
    gain = mth("ADD", 1.0, mth("MULTIPLY", band, HOLO_SCAN_BOOST))
    nt.links.new(mth("MULTIPLY", mth("MULTIPLY", gain, flicker.outputs[0]), strength),
                 em.inputs["Strength"])

    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(brick.outputs["Color"], mix.inputs["Fac"])
    nt.links.new(tr.outputs["BSDF"], mix.inputs[1])
    nt.links.new(em.outputs["Emission"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return m


def vapor_puff(name="vapor_puff"):
    # Cryogenic exhaust: pale, cold and mostly not there. Alpha is driven by
    # facing so the silhouette of each puff softens at its rim instead of
    # ending on a hard edge, which is what separates vapour from a sphere.
    m = _get_mat(name)
    nt, out = _reset_nodes(m)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (0.33, 0.40, 0.46, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.95
    bsdf.inputs["Emission Color"].default_value = (*FROST, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 0.12
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.42
    # facing the camera -> thin; grazing -> the puff is deep, so denser
    alpha = nt.nodes.new("ShaderNodeMapRange")
    alpha.inputs["To Min"].default_value = 0.46
    alpha.inputs["To Max"].default_value = 0.05
    nt.links.new(lw.outputs["Facing"], alpha.inputs["Value"])
    # animate_deck keyframes this so a puff dissipates instead of popping
    fade = nt.nodes.new("ShaderNodeValue")
    fade.name = "VaporFade"
    fade.outputs[0].default_value = 1.0
    dim = nt.nodes.new("ShaderNodeMath")
    dim.operation = "MULTIPLY"
    nt.links.new(alpha.outputs["Result"], dim.inputs[0])
    nt.links.new(fade.outputs[0], dim.inputs[1])
    nt.links.new(dim.outputs[0], bsdf.inputs["Alpha"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def etched_plate():
    # Faint glyph traces lit from inside the plating. Voronoi's distance to
    # cell edge is the cheapest thing that reads as etched circuitry.
    m = _get_mat("etched_plate")
    nt, out = _reset_nodes(m)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Metallic"].default_value = 0.3
    bsdf.inputs["Roughness"].default_value = 0.45
    coord = nt.nodes.new("ShaderNodeTexCoord")
    voro = nt.nodes.new("ShaderNodeTexVoronoi")
    voro.feature = "DISTANCE_TO_EDGE"
    voro.inputs["Scale"].default_value = 26.0
    nt.links.new(coord.outputs["Object"], voro.inputs["Vector"])
    # thin traces only: at the first attempt the cells themselves took colour
    # and the panel read as crazy paving rather than etched plating
    lines = nt.nodes.new("ShaderNodeMapRange")
    lines.inputs["From Min"].default_value = 0.0
    lines.inputs["From Max"].default_value = 0.012
    lines.inputs["To Min"].default_value = 1.0
    lines.inputs["To Max"].default_value = 0.0
    nt.links.new(voro.outputs["Distance"], lines.inputs["Value"])
    tint = nt.nodes.new("ShaderNodeMath")
    tint.operation = "MULTIPLY"
    tint.inputs[1].default_value = 0.5
    nt.links.new(lines.outputs["Result"], tint.inputs[0])
    plate = nt.nodes.new("ShaderNodeMix")
    plate.data_type = "RGBA"
    plate.inputs["A"].default_value = (0.052, 0.060, 0.068, 1)
    plate.inputs["B"].default_value = (0.09, 0.14, 0.16, 1)
    nt.links.new(tint.outputs["Value"], plate.inputs["Factor"])
    nt.links.new(plate.outputs["Result"], bsdf.inputs["Base Color"])
    glow = nt.nodes.new("ShaderNodeMath")
    glow.operation = "MULTIPLY"
    glow.inputs[1].default_value = 0.4
    nt.links.new(lines.outputs["Result"], glow.inputs[0])
    bsdf.inputs["Emission Color"].default_value = (*CYAN, 1.0)
    nt.links.new(glow.outputs["Value"], bsdf.inputs["Emission Strength"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def crystal_quantum():
    # Faceted quantum mineral: Voronoi cracks in the normal, cell-to-cell
    # colour variation between the two blues, and a Fresnel rim so the edges
    # flare brighter than the faces.
    m = _get_mat("crystal_quantum")
    nt, out = _reset_nodes(m)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.34
    coord = nt.nodes.new("ShaderNodeTexCoord")

    cells = nt.nodes.new("ShaderNodeTexVoronoi")
    cells.inputs["Scale"].default_value = 5.5
    nt.links.new(coord.outputs["Object"], cells.inputs["Vector"])
    facet = nt.nodes.new("ShaderNodeMix")
    facet.data_type = "RGBA"
    facet.inputs["A"].default_value = (*CRYSTAL_DEEP, 1)
    facet.inputs["B"].default_value = (*CRYSTAL_LIT, 1)
    tone = nt.nodes.new("ShaderNodeMapRange")
    tone.inputs["From Min"].default_value = 0.15
    tone.inputs["From Max"].default_value = 0.75
    tone.inputs["To Max"].default_value = 0.55
    nt.links.new(cells.outputs["Distance"], tone.inputs["Value"])
    nt.links.new(tone.outputs["Result"], facet.inputs["Factor"])
    nt.links.new(facet.outputs["Result"], bsdf.inputs["Base Color"])

    cracks = nt.nodes.new("ShaderNodeTexVoronoi")
    cracks.feature = "DISTANCE_TO_EDGE"
    cracks.inputs["Scale"].default_value = 5.5
    nt.links.new(coord.outputs["Object"], cracks.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    nt.links.new(cracks.outputs["Distance"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    # emission: blue over the faces, near-white where the rim catches
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.32
    rim_col = nt.nodes.new("ShaderNodeMix")
    rim_col.data_type = "RGBA"
    rim_col.inputs["A"].default_value = (*CRYSTAL_DEEP, 1)
    rim_col.inputs["B"].default_value = (*CRYSTAL_RIM, 1)
    nt.links.new(lw.outputs["Facing"], rim_col.inputs["Factor"])
    nt.links.new(rim_col.outputs["Result"], bsdf.inputs["Emission Color"])
    rim_str = nt.nodes.new("ShaderNodeMapRange")
    rim_str.inputs["To Min"].default_value = 0.15
    rim_str.inputs["To Max"].default_value = 0.54
    nt.links.new(lw.outputs["Facing"], rim_str.inputs["Value"])
    nt.links.new(rim_str.outputs["Result"], bsdf.inputs["Emission Strength"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def arc_plasma():
    # Contained discharge, not lightning: white down the centreline of the
    # tube (facing the camera) fading to electric blue at its silhouette.
    # Strength stays ~1 because Standard clips -- the white core is the mix,
    # not a bigger number.
    m = _get_mat("arc_plasma")
    nt, out = _reset_nodes(m)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 1.05
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.45
    fringe = nt.nodes.new("ShaderNodeMapRange")
    fringe.inputs["From Max"].default_value = 0.5
    nt.links.new(lw.outputs["Facing"], fringe.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = (*PLASMA_HOT, 1)
    mix.inputs["B"].default_value = (*ARC_OUTER, 1)
    nt.links.new(fringe.outputs["Result"], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], em.inputs["Color"])
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def add_etch(mat, scale=24.0, depth=0.45):
    # Fine etched line-work mixed into whatever already feeds Base Color, for
    # accent plate that should read as machined rather than painted.
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return mat
    link = next((l for l in nt.links if l.to_socket == bsdf.inputs["Base Color"]), None)
    if link is None:
        return mat
    src = link.from_socket
    nt.links.remove(link)
    coord = nt.nodes.new("ShaderNodeTexCoord")
    voro = nt.nodes.new("ShaderNodeTexVoronoi")
    voro.feature = "DISTANCE_TO_EDGE"
    voro.inputs["Scale"].default_value = scale
    nt.links.new(coord.outputs["Object"], voro.inputs["Vector"])
    lines = nt.nodes.new("ShaderNodeMapRange")
    lines.inputs["From Max"].default_value = 0.02
    lines.inputs["To Min"].default_value = depth
    lines.inputs["To Max"].default_value = 0.0
    nt.links.new(voro.outputs["Distance"], lines.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["B"].default_value = (0.10, 0.12, 0.15, 1.0)
    nt.links.new(src, mix.inputs["A"])
    nt.links.new(lines.outputs["Result"], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    return mat


def add_tread(mat, scale=13.0, strength=0.22):
    # Anti-slip diamond plate: two crossed wave bands into a bump, so walkable
    # deck reads differently from smooth plating without new geometry.
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return mat
    coord = nt.nodes.new("ShaderNodeTexCoord")
    waves = []
    for sign in (1, -1):
        mapping = nt.nodes.new("ShaderNodeMapping")
        mapping.inputs["Rotation"].default_value = (0, 0, math.radians(45 * sign))
        nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
        wave = nt.nodes.new("ShaderNodeTexWave")
        wave.inputs["Scale"].default_value = scale
        nt.links.new(mapping.outputs["Vector"], wave.inputs["Vector"])
        waves.append(wave)
    grid = nt.nodes.new("ShaderNodeMath")
    grid.operation = "MULTIPLY"
    nt.links.new(waves[0].outputs["Fac"], grid.inputs[0])
    nt.links.new(waves[1].outputs["Fac"], grid.inputs[1])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    nt.links.new(grid.outputs["Value"], bump.inputs["Height"])
    prior = next((l for l in nt.links if l.to_socket == bsdf.inputs["Normal"]), None)
    if prior is not None:
        src = prior.from_socket
        nt.links.remove(prior)
        nt.links.new(src, bump.inputs["Normal"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def add_energy_sheen(mat, color=CYAN, strength=0.9, noise_scale=4.5):
    # Fresnel rim plus a mottled band, for surfaces carrying the field.
    # The band samples WORLD position, not object: the rings spin through a
    # field that stands still, so the 64-frame loop still closes exactly on
    # their rotational symmetry (an object-space band would rotate with them
    # and pop at the wrap).
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        return mat
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = noise_scale
    noise.inputs["Detail"].default_value = 4.0
    nt.links.new(geo.outputs["Position"], noise.inputs["Vector"])
    band = nt.nodes.new("ShaderNodeMapRange")
    band.inputs["From Min"].default_value = 0.4
    band.inputs["From Max"].default_value = 0.65
    band.inputs["To Min"].default_value = 0.35
    band.inputs["To Max"].default_value = 1.0
    nt.links.new(noise.outputs["Fac"], band.inputs["Value"])
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.3
    rim = nt.nodes.new("ShaderNodeMapRange")
    rim.inputs["From Min"].default_value = 0.35
    rim.inputs["To Min"].default_value = 0.05
    rim.inputs["To Max"].default_value = 0.85
    nt.links.new(lw.outputs["Facing"], rim.inputs["Value"])
    amt = nt.nodes.new("ShaderNodeMath")
    amt.operation = "MULTIPLY"
    nt.links.new(rim.outputs["Result"], amt.inputs[0])
    nt.links.new(band.outputs["Result"], amt.inputs[1])
    scale = nt.nodes.new("ShaderNodeMath")
    scale.operation = "MULTIPLY"
    scale.inputs[1].default_value = strength
    nt.links.new(amt.outputs["Value"], scale.inputs[0])
    bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
    nt.links.new(scale.outputs["Value"], bsdf.inputs["Emission Strength"])
    return mat


# Paint families shared by the plain and the stencilled variants of a
# material, so a decal panel can never drift from the panel beside it.
# Saturation, not coverage, is what makes an identity colour read. Measured
# against vanilla's own strongly-coloured machine: the lab's blue runs
# saturation 0.45, the cryogenic plant's warm hull 0.34, the base beacon 0.44.
# This paint ran 0.14 -- on 29% of the sprite and still reading monochrome,
# because 53% of our pixels sat below saturation 0.12 where vanilla keeps
# 17-23% there. Raising the paint alone is not enough; DARK below carries the
# other half of the fix.
PAINT_A, PAINT_B = srgb("#5C7C80"), srgb("#2F464A")
# The counterweight, and the bigger half of the change. This family plus
# gunmetal and cast_iron own ~40% of the sprite and were all neutral blue-grey,
# which is what flattened the whole machine. Vanilla has no neutral mass at
# all: its darkest value band is its MOST saturated (cryogenic plant 0.35 at
# value < 0.12, falling to 0.14 in the highlights) because crevices fill with
# warm rust and bounce while speculars go white. Warm oxidised steel here
# reproduces that ramp and gives the teal something to be cold against.
DARK_A, DARK_B = srgb("#574839"), srgb("#362920")
HOLM_A, HOLM_B = srgb("#7B909E"), srgb("#4D5D6B")


def deck_paint(name, decal=None, decal_fit=1.0, scratch=0.45):
    # Hull paint that gets walked on: same colour as the housing, more wear.
    return worn_metal(name, PAINT_A, PAINT_B,
                      metallic=0.25, rough_lo=0.45, rough_hi=0.70, grime=0.30,
                      wear=0.45, rust=0.28, noise_scale=5.0, frost=0.08,
                      grain=0.14, scratch=scratch, decal=decal, decal_fit=decal_fit)


def dark_paint(name, decal=None, decal_fit=1.0):
    return worn_metal(name, DARK_A, DARK_B,
                      metallic=0.35, rough_lo=0.5, rough_hi=0.65,
                      wear=0.5, rust=0.3, frost=0.09, grain=0.12,
                      decal=decal, decal_fit=decal_fit)


# Snow tones for the frozen overlay. Measured off Space Age's own frozen
# patches (beacon, centrifuge, electric furnace, lab): the exposed caps sit
# near (225,231,235) and the packed ice in the crevices near (105,130,145),
# always R < G < B at a saturation around 0.15. These are albedos, not the
# rendered result: under this rig's 5.2 key sun anything near 0.7 linear clips
# to flat 255, so the picked values sit well below where the snow lands.
SNOW_CAP = srgb("#B8C2C8")
SNOW_SHADE = srgb("#24333F")


def snow_override(name="frost_overlay", coverage=1.0):
    # The material every static part is swapped for while rendering the
    # `frozen` layer, so what reaches the PNG is the snow and nothing else --
    # which is exactly what graphics_set.frozen_patch wants: an overlay pasted
    # over the normal sprite, transparent wherever the machine still shows.
    #
    # Same vocabulary as worn_metal's rime -- up-facing normal, convex edges,
    # patchy noise -- turned up from a dusting to a full coat, and deliberately
    # WITHOUT its heat-source term: a beacon is frozen precisely because its
    # heaters have stopped, so nothing on the deck is warm enough to keep
    # itself clear any more.
    m = _get_mat(name)
    nt, out = _reset_nodes(m)

    def map_range(lo, fr=(0.0, 1.0)):
        r = nt.nodes.new("ShaderNodeMapRange")
        r.inputs["From Min"].default_value = fr[0]
        r.inputs["From Max"].default_value = fr[1]
        r.inputs["To Min"].default_value = lo[0]
        r.inputs["To Max"].default_value = lo[1]
        return r

    def math_node(op, v=None):
        n = nt.nodes.new("ShaderNodeMath")
        n.operation = op
        n.use_clamp = True
        if v is not None:
            n.inputs[1].default_value = v
        return n

    coord = nt.nodes.new("ShaderNodeTexCoord")
    geo = nt.nodes.new("ShaderNodeNewGeometry")

    # what faces the sky holds snow; convex edges catch it next
    nrm = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], nrm.inputs["Vector"])
    up = map_range((0.0, 1.0), fr=(0.63, 0.90))
    nt.links.new(nrm.outputs["Z"], up.inputs["Value"])
    edge = map_range((0.0, 0.30), fr=(0.555, 0.615))
    nt.links.new(geo.outputs["Pointiness"], edge.inputs["Value"])

    # drifted, not painted on: the noise is what leaves bare metal showing
    # through, and a uniform coat is the tell that reads as a white blob
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 2.7
    noise.inputs["Detail"].default_value = 2.0
    nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
    patch = map_range((0.0, 1.0), fr=(0.425, 0.565))
    nt.links.new(noise.outputs["Fac"], patch.inputs["Value"])

    # Snow only lands on surfaces the sky can reach. Without this the inside
    # of every shell is snowed too, and since the layer is semi-transparent
    # those hidden faces still composite into the pixel -- the sprite goes
    # white where the model is thickest rather than where the drifts are.
    front = math_node("SUBTRACT")
    front.inputs[0].default_value = 1.0
    nt.links.new(geo.outputs["Backfacing"], front.inputs[1])

    flat_snow = math_node("MULTIPLY")
    nt.links.new(up.outputs["Result"], flat_snow.inputs[0])
    nt.links.new(patch.outputs["Result"], flat_snow.inputs[1])
    edge_snow = math_node("MULTIPLY")
    nt.links.new(edge.outputs["Result"], edge_snow.inputs[0])
    nt.links.new(patch.outputs["Result"], edge_snow.inputs[1])
    # a convex edge collects snow only if it is not an underside
    up_loose = map_range((0.0, 1.0), fr=(0.10, 0.50))
    nt.links.new(nrm.outputs["Z"], up_loose.inputs["Value"])
    edge_up = math_node("MULTIPLY")
    nt.links.new(edge_snow.outputs["Value"], edge_up.inputs[0])
    nt.links.new(up_loose.outputs["Result"], edge_up.inputs[1])
    edge_snow = edge_up
    cover = math_node("MAXIMUM")
    nt.links.new(flat_snow.outputs["Value"], cover.inputs[0])
    nt.links.new(edge_snow.outputs["Value"], cover.inputs[1])

    # snow needs sky access: little reaches under an overhang, and what does
    # reach a crevice packs down to grey ice instead of staying white. One AO
    # term drives both the amount and the colour, which is what produces
    # vanilla's split between bright caps and blue-grey recesses.
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 1.20
    ao.samples = 32
    # Two separate curves off the same AO, because colour and coverage do not
    # want the same one. Driving both from one made the recesses bare instead
    # of icy: snow does reach a crevice, it just packs down grey there rather
    # than staying white.
    open_sky = map_range((0.0, 1.0), fr=(0.50, 0.95))       # tone: tight
    nt.links.new(ao.outputs["AO"], open_sky.inputs["Value"])
    sheltered = map_range((0.0, 1.0), fr=(0.30, 0.70))      # amount: no floor
    nt.links.new(ao.outputs["AO"], sheltered.inputs["Value"])
    amount = math_node("MULTIPLY")
    nt.links.new(cover.outputs["Value"], amount.inputs[0])
    nt.links.new(sheltered.outputs["Result"], amount.inputs[1])
    faced = math_node("MULTIPLY")
    nt.links.new(amount.outputs["Value"], faced.inputs[0])
    nt.links.new(front.outputs["Value"], faced.inputs[1])
    amount = faced
    # Drifts have edges. Vanilla's patches are nearly binary in alpha, so the
    # soft shoulder gets squeezed out here -- left in, it coats the whole hull
    # in a half-transparent film and the machine reads shrink-wrapped rather
    # than snowed on.
    crisp = map_range((0.0, 1.0), fr=(0.375, 0.515))
    nt.links.new(amount.outputs["Value"], crisp.inputs["Value"])
    amount = crisp
    if coverage != 1.0:
        scaled = math_node("MULTIPLY", coverage)
        nt.links.new(amount.outputs["Result"], scaled.inputs[0])
        amount = scaled

    tone = nt.nodes.new("ShaderNodeMix")
    tone.data_type = "RGBA"
    tone.inputs["A"].default_value = (*SNOW_SHADE, 1.0)
    tone.inputs["B"].default_value = (*SNOW_CAP, 1.0)
    nt.links.new(open_sky.outputs["Result"], tone.inputs["Factor"])

    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(tone.outputs["Result"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.62


    # alpha comes from mixing to Transparent rather than from a Principled
    # alpha socket, so Cycles antialiases the snow line against the film
    transp = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(amount.outputs[0], mix.inputs["Fac"])
    nt.links.new(transp.outputs["BSDF"], mix.inputs[1])
    nt.links.new(bsdf.outputs["BSDF"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return m


def build_materials():
    return {
        # frost-teal paint, the mod's Aquilo-adjacent identity colour
        "steel": worn_metal("steel_frost", PAINT_A, PAINT_B,
                            metallic=0.25, rough_lo=0.45, rough_hi=0.68, grime=0.35,
                            wear=0.4, rust=0.3, noise_scale=5.0,
                            frost=0.08, grain=0.14),
        "steel_dark": dark_paint("steel_dark"),
        "gunmetal": worn_metal("gunmetal", srgb("#473C32"), srgb("#302720"),
                               metallic=0.42, rough_lo=0.4, rough_hi=0.55,
                               wear=0.45, rust=0.34, frost=0.12, grain=0.12),
        # holmium plate: cooler and more reflective than the hull, used as
        # inserts so the identity teal has something to sit against
        "holmium": worn_metal("holmium_plate", HOLM_A, HOLM_B,
                              metallic=0.5, rough_lo=0.22, rough_hi=0.40,
                              wear=0.3, rust=0.03, frost=0.10, grain=0.12),
        # sparse warm accents so the palette isn't monochrome (vanilla always
        # mixes a warm material into cold steel)
        "warm": worn_metal("warm_brown", (0.16, 0.10, 0.06), (0.10, 0.06, 0.035),
                           metallic=0.2, rough_lo=0.5, rough_hi=0.7,
                           wear=0.3, rust=0.7),
        # cold-end plant: same paint family, but iced over hard. Only the
        # parts whose JOB is to be cold wear this -- reservoir, condenser fins
        # -- so the heavy rime reads as function, not weather everywhere.
        "frosty": worn_metal("frost_steel", PAINT_A, PAINT_B,
                             metallic=0.2, rough_lo=0.5, rough_hi=0.75,
                             wear=0.3, rust=0.12, frost=0.30, grain=0.12),
        # bare rusted steel -- the references lean hard on it
        "rusty": worn_metal("rusty_steel", (0.17, 0.085, 0.04), (0.09, 0.045, 0.022),
                            metallic=0.15, rough_lo=0.6, rough_hi=0.85,
                            wear=0.55, rust=0.25, noise_scale=4.5, frost=0.12),
        # dark cast iron for fittings and flanges
        "iron": worn_metal("cast_iron", srgb("#211A16"), srgb("#17110E"),
                           metallic=0.35, rough_lo=0.5, rough_hi=0.7,
                           wear=0.35, rust=0.42, frost=0.14),
        # copper piping, worn and part-patinated
        "copper": worn_metal("copper_pipe", (0.3, 0.11, 0.05), (0.16, 0.06, 0.03),
                             metallic=0.7, rough_lo=0.35, rough_hi=0.55,
                             wear=0.25, rust=0.3, noise_scale=6.0, frost=0.07),
        # containment coil bodies: worn metal that also carries the field
        "ring": add_energy_sheen(
            worn_metal("coil_ring", srgb("#3D3731"), srgb("#2B2621"),
                       metallic=0.28, rough_lo=0.5, rough_hi=0.68,
                       wear=0.4, rust=0.22, frost=0.10),
            color=ARC_OUTER, strength=0.22),
        "hose": rubber("hose_rubber"),
        # armoured conduit: light enough to read as a separate run against the
        # deck paint, where a second black rubber line just merges with the
        # first. Metal, so the key catches its top and gives it a round
        # section at 4 px wide.
        "conduit": worn_metal("conduit_braid", srgb("#695E52"), srgb("#473E35"),
                              metallic=0.45, rough_lo=0.34, rough_hi=0.56,
                              wear=0.4, rust=0.30, frost=0.10, grain=0.18),
        "cable": rubber("cable_rubber", (0.021, 0.020, 0.019)),
        "crystal": crystal_quantum(),
        "core": plain("crystal_core", CRYSTAL_RIM, metallic=0.0, rough=0.3,
                      emission=CRYSTAL_RIM, strength=0.95),
        # emission stays ~1: Standard clips hard and the blue blows to white
        # anywhere above (the hue is the point, not the brightness). Fresnel
        # makes the tips flare at their rim without raising the number.
        "glow": add_energy_sheen(
            plain("glow_plasma", (0.06, 0.12, 0.18), metallic=0.0, rough=0.35),
            color=ARC_OUTER, strength=1.05),
        # the containment well under the core: bright enough to bounce onto
        # the surrounding machinery, dim enough to stay blue instead of white
        # Dim on purpose. Once the well was actually open this became a large
        # up-facing emissive disc, and at the old strength it clipped to a flat
        # cyan plate that outshone the crystal -- which is the hero and holds
        # the emissive budget. The recess does the work: 0.15 of dark iron
        # shaft wall above it reads as depth, so the light only has to suggest
        # that something is burning down there.
        "glow_hot": plain("glow_hot", (0.055, 0.135, 0.20), metallic=0.0, rough=0.3,
                          emission=PLASMA_LIT, strength=0.52),
        "arc": arc_plasma(),
        # sparks and motes: a couple of pixels each, so only the hue survives
        # -- kept just under the clip point rather than pushed white
        "spark": emission_only("spark", srgb("#7FE3FF"), 1.05),
        # cable pulse: dimmer than a spark and stretched along the run, so it
        # reads as light moving THROUGH the cable rather than an orb resting
        # on top of it
        "pulse": emission_only("cable_pulse", ARC_OUTER, 0.72),
        "glass": canister_glass(),
        "fluid_hot": coolant_fluid("coolant_hot", COOLANT_HOT),
        "fluid_cold": coolant_fluid("coolant_cold", COOLANT_COLD),
        "etched": etched_plate(),
        # deck plating and its stencilled variants -- one material per atlas
        # cell, because the cell is baked into the node graph
        "deck": deck_paint("deck_plate"),
        "deck_id": deck_paint("deck_id", decal=(0, 0)),
        "deck_arrows": deck_paint("deck_arrows", decal=(2, 0)),
        "deck_cold": deck_paint("deck_cold", decal=(1, 2)),
        "holmium_label": worn_metal("holmium_label", HOLM_A, HOLM_B,
                                    metallic=0.5, rough_lo=0.22, rough_hi=0.40,
                                    wear=0.3, rust=0.03, frost=0.10, grain=0.12,
                                    decal=(0, 1)),
        "holmium_id": worn_metal("holmium_id", HOLM_A, HOLM_B,
                                 metallic=0.5, rough_lo=0.22, rough_hi=0.40,
                                 wear=0.3, rust=0.03, frost=0.10, grain=0.12,
                                 decal=(2, 1)),
        "deck_caution": deck_paint("deck_caution", decal=(0, 3)),
        # label plates take the rim's own paint: a darker plate reads as a
        # rectangle stuck on the beam, and the mark loses the contrast fight
        "riser_hazard": worn_metal("riser_hazard", PAINT_A, PAINT_B,
                                   metallic=0.25, rough_lo=0.45, rough_hi=0.68,
                                   wear=0.4, rust=0.3, noise_scale=5.0,
                                   frost=0.08, grain=0.14, decal=(1, 0)),
        "riser_id": worn_metal("riser_id", PAINT_A, PAINT_B,
                               metallic=0.25, rough_lo=0.45, rough_hi=0.68,
                               wear=0.4, rust=0.3, noise_scale=5.0,
                               frost=0.08, grain=0.14, decal=(2, 0)),
        "power_hv": dark_paint("power_hv", decal=(0, 2)),
        "screen": screen_readout(),
        # front-lip accent: cool holmium with machined line-work, replacing
        # the yellow segmented strips that read as circuit-board contacts
        "holmium_etch": add_etch(worn_metal("holmium_etch", HOLM_A, HOLM_B,
                                            metallic=0.5, rough_lo=0.22, rough_hi=0.38,
                                            wear=0.28, rust=0.03, frost=0.12, grain=0.12)),
        # walkway plating, so a walkable surface reads differently underfoot
        "tread": add_tread(deck_paint("deck_tread", scratch=0.55)),  # walkway
        # heat pipe: insulation stays warm, so no rime settles on it
        "insulation": worn_metal("heat_insulation", (0.155, 0.145, 0.135),
                                 (0.095, 0.088, 0.082), metallic=0.12,
                                 rough_lo=0.6, rough_hi=0.82, wear=0.35, rust=0.3,
                                 frost=0.0, grain=0.12),
        # deliberately dimmer than the readout and far dimmer than the core
        "heat_glow": plain("heat_glow", (0.12, 0.045, 0.02), metallic=0.0, rough=0.5,
                           emission=HEAT_ORANGE, strength=0.7),
        "hatch_lid": dark_paint("hatch_lid", decal=(2, 2)),
        "strip": emission_only("strip_light", ARC_OUTER, 0.5),
        # Holographic projection. Emission only and deliberately UNDER the
        # core's own strength: the containment crystal keeps the emissive
        # budget, and a second cyan light source that competes with it flattens
        # the hero. Max channel stays at 1.0 so Standard does not clip the hue
        # to white -- the low red and green ARE the colour.
        "holo": holo_glyphs(),
        "holo_rail": emission_only("holo_rail", ARC_OUTER, 0.55),
        # projector lens: dark glass that only lights at its rim
        "lens": add_energy_sheen(
            plain("holo_lens", (0.02, 0.05, 0.07), metallic=0.0, rough=0.22),
            color=ARC_OUTER, strength=0.75),
        # Cryo exhaust. Albedo well under the snow value that clips to flat
        # 255 under this rig's 5.2 key sun, and mostly transparent so a puff
        # reads as vapour rather than as a white blob stuck to the deck.
        "vapor": vapor_puff(),
        # the floor shard's interior: the same plasma as the core but a third
        # of the brightness, so it reads as a chip off it and not a rival
        "shard_core": plain("shard_core", (0.08, 0.20, 0.30), metallic=0.0,
                            rough=0.3, emission=PLASMA_LIT, strength=0.42),
        "vent_glow": plain("vent_glow", (0.04, 0.09, 0.12), metallic=0.0,
                           rough=0.6, emission=ARC_OUTER, strength=0.34),
        "radiator": plain("radiator_hot", (0.10, 0.045, 0.02), metallic=0.1, rough=0.5,
                          emission=COOLANT_HOT, strength=0.95),
        "led_green": emission_only("led_green", LED_GREEN, 1.0),
        "led_amber": emission_only("led_amber", LED_AMBER, 1.0),
        "led_cyan": emission_only("led_cyan", ARC_OUTER, 1.0),
        "dial": plain("dial_face", (0.34, 0.33, 0.29), metallic=0.0, rough=0.55),
        "socket_dark": plain("socket_dark", srgb("#14100D"), metallic=0.2, rough=0.75),
        "footprint": emission_only("footprint_white", (1, 1, 1), 1.0),
    }


# --------------------------------------------------------------------------
# equipment helpers -- the vocabulary the amphitheater is assembled from

def pipe_run(base, mats, name, pts, radius, mat_key="copper", flange_ts=(), rings=0,
             ring_key="iron"):
    # smooth NURBS pipe through pts; optional cast-iron flange tori along it
    # and ribbed rings (hose look)
    curve = bpy.data.curves.new(PREFIX + name + "C", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 4
    curve.use_fill_caps = True
    spl = curve.splines.new("NURBS")
    spl.points.add(len(pts) - 1)
    for p, (x, y, z) in zip(spl.points, pts):
        p.co = (x, y, z, 1)
    spl.use_endpoint_u = True
    obj = bpy.data.objects.new(PREFIX + name, curve)
    obj.data.materials.append(mats[mat_key])
    bpy.context.scene.collection.objects.link(obj)
    link_to(obj, base)

    def lerp_path(t):
        # crude arc-length-free interpolation along control points
        f = t * (len(pts) - 1)
        i = min(int(f), len(pts) - 2)
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        return a.lerp(b, f - i), (b - a).normalized()

    marks = [(t, 1.6) for t in flange_ts]
    if rings:
        marks += [((k + 1) / (rings + 1), 1.25) for k in range(rings)]
    for j, (t, size) in enumerate(marks):
        pos, tang = lerp_path(t)
        quat = tang.to_track_quat("Z", "Y")
        bpy.ops.mesh.primitive_torus_add(major_radius=radius * size,
                                         minor_radius=radius * 0.45,
                                         major_segments=20, minor_segments=8,
                                         location=pos)
        fl = bpy.context.object
        fl.name = PREFIX + name + "F%d" % j
        fl.rotation_mode = "QUATERNION"
        fl.rotation_quaternion = quat
        fl.data.materials.append(mats[ring_key])
        smooth(fl)
        link_to(fl, base)
    return obj


def tank_h(base, mats, name, r, length, pos, ang, mat_key="rusty"):
    # horizontal tank: cylinder + dome ends + two iron straps
    body = cylinder(name, r, length, pos, (0, math.radians(90), ang),
                    mats[mat_key], verts=24)
    smooth(body)
    link_to(body, base)
    d = Vector((math.cos(ang), math.sin(ang), 0))
    for k, s in enumerate((-1, 1)):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r * 0.98, segments=20, ring_count=10,
                                             location=Vector(pos) + d * (s * length / 2))
        cap = bpy.context.object
        cap.name = PREFIX + name + "Cap%d" % k
        cap.data.materials.append(mats[mat_key])
        smooth(cap)
        link_to(cap, base)
    for k, t in enumerate((-0.25, 0.25)):
        bpy.ops.mesh.primitive_torus_add(major_radius=r * 1.04, minor_radius=r * 0.09,
                                         major_segments=24, minor_segments=8,
                                         location=Vector(pos) + d * (t * length))
        strap = bpy.context.object
        strap.name = PREFIX + name + "Strap%d" % k
        strap.rotation_euler = (0, math.radians(90), ang)
        strap.data.materials.append(mats["iron"])
        smooth(strap)
        link_to(strap, base)
    return body


def silo(base, mats, name, r, h, pos, mat_key="steel"):
    body = cylinder(name, r, h, pos, material=mats[mat_key], verts=24)
    smooth(body)
    link_to(body, base)
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=r * 1.05, radius2=r * 0.25,
                                    depth=h * 0.35,
                                    location=(pos[0], pos[1], pos[2] + h / 2 + h * 0.17))
    top = bpy.context.object
    top.name = PREFIX + name + "Top"
    top.data.materials.append(mats["iron"])
    smooth(top)
    link_to(top, base)
    stub = cylinder(name + "Stub", r * 0.2, h * 0.3,
                    (pos[0], pos[1], pos[2] + h * 0.75), material=mats["copper"], verts=12)
    smooth(stub)
    link_to(stub, base)
    return body


def manifold(base, mats, name, pos, ang):
    body = cube(name, (0.55, 0.4, 0.45), pos, (0, 0, ang), mats["steel_dark"])
    bevel(body, width=0.04)
    link_to(body, base)
    d = Vector((math.cos(ang), math.sin(ang), 0))
    side = Vector((-math.sin(ang), math.cos(ang), 0))
    for k in range(3):
        off = d * ((k - 1) * 0.16)
        p = Vector(pos) + off + Vector((0, 0, 0.3))
        stub = cylinder(name + "S%d" % k, 0.055, 0.35, p, material=mats["copper"], verts=12)
        smooth(stub)
        link_to(stub, base)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.11, minor_radius=0.028,
                                     major_segments=16, minor_segments=8,
                                     location=Vector(pos) + side * 0.24 + Vector((0, 0, 0.1)))
    wheel = bpy.context.object
    wheel.name = PREFIX + name + "Wheel"
    wheel.rotation_euler = (math.radians(90), 0, ang)
    wheel.data.materials.append(mats["rusty"])
    smooth(wheel)
    link_to(wheel, base)
    return body


def bezier_pt(ctrl, t):
    p0, h0, h1, p1 = (Vector(c) for c in ctrl)
    u = 1 - t
    return (u ** 3) * p0 + (3 * u * u * t) * h0 + (3 * u * t * t) * h1 + (t ** 3) * p1


def bezier_tan(ctrl, t):
    p0, h0, h1, p1 = (Vector(c) for c in ctrl)
    u = 1 - t
    d = 3 * u * u * (h0 - p0) + 6 * u * t * (h1 - h0) + 3 * t * t * (p1 - h1)
    return d.normalized()


def helix_on_bezier(base, mats, name, ctrl, t0, t1, turns, wire, radius_at,
                    mat_key="copper", per_turn=18, phase=0.0):
    # Winding that actually follows a bowed pole: sample the pylon's own
    # bezier, build a tangent frame at each sample, and orbit it. Retuning
    # turns/pitch is then one number, not a remodel.
    curve = bpy.data.curves.new(PREFIX + name + "C", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = wire
    curve.bevel_resolution = 2
    spl = curve.splines.new("POLY")
    n = max(int(turns * per_turn), 10)
    spl.points.add(n - 1)
    for k in range(n):
        s = k / (n - 1)
        t = t0 + (t1 - t0) * s
        p = bezier_pt(ctrl, t)
        tan = bezier_tan(ctrl, t)
        side = tan.cross(Vector((0, 0, 1)))
        if side.length < 1e-3:
            side = Vector((1, 0, 0))
        side.normalize()
        up = tan.cross(side)
        a = 2 * math.pi * turns * s + phase
        r = radius_at(t) + wire * 1.1
        q = p + side * (r * math.cos(a)) + up * (r * math.sin(a))
        spl.points[k].co = (q.x, q.y, q.z, 1)
    obj = bpy.data.objects.new(PREFIX + name, curve)
    obj.data.materials.append(mats[mat_key])
    bpy.context.scene.collection.objects.link(obj)
    link_to(obj, base)
    return obj


def hose_run(base, mats, name, a, b, sag=0.22, lateral=0.0, rings=6,
             radius=0.055, mat_key="hose"):
    # Flexible line, never a straight segment: two dipped control points give
    # the catenary and a lateral offset gives the S. NURBS smooths through
    # them, so the shape is soft where a pipe would be rigid.
    a, b = Vector(a), Vector(b)
    d = b - a
    side = Vector((-d.y, d.x, 0))
    side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
    p1 = a + d * 0.32 + side * lateral - Vector((0, 0, sag * 0.9))
    p2 = a + d * 0.66 + side * (lateral * 0.45) - Vector((0, 0, sag))
    return pipe_run(base, mats, name, [tuple(a), tuple(p1), tuple(p2), tuple(b)],
                    radius, mat_key=mat_key, rings=rings)


def canister(base, mats, name, pos, r=0.16, h=0.62, fluid_key="fluid_cold"):
    # Fluoroketone tank. They come in colour-coded pairs -- amber hot leg,
    # icy cold leg -- so the coolant loop is legible at a glance.
    fluid = cylinder(name + "Fluid", r * 0.8, h, pos, material=mats[fluid_key], verts=20)
    smooth(fluid)
    link_to(fluid, base)
    shell = cylinder(name, r, h, pos, material=mats["glass"], verts=24)
    smooth(shell)
    link_to(shell, base)
    for k, s in enumerate((-1, 1)):
        cap = cylinder(name + "Cap%d" % k, r * 1.12, 0.07,
                       (pos[0], pos[1], pos[2] + s * (h / 2 + 0.01)),
                       material=mats["iron"], verts=20)
        bevel(cap, width=0.02, segments=2)
        smooth(cap)
        link_to(cap, base)
    bpy.ops.mesh.primitive_torus_add(major_radius=r * 1.06, minor_radius=r * 0.10,
                                     major_segments=20, minor_segments=8,
                                     location=(pos[0], pos[1], pos[2]))
    strap = bpy.context.object
    strap.name = PREFIX + name + "Strap"
    strap.data.materials.append(mats["iron"])
    smooth(strap)
    link_to(strap, base)
    stub = cylinder(name + "Stub", r * 0.22, 0.16,
                    (pos[0], pos[1], pos[2] + h / 2 + 0.1),
                    material=mats["copper"], verts=10)
    smooth(stub)
    link_to(stub, base)
    return shell


def gauge(base, mats, name, pos, ang=0.0, r=0.11):
    # Analog dial, tilted up toward the camera so the face reads
    rot = (math.radians(72), 0, ang)
    face = cylinder(name, r, 0.03, pos, rot, mats["dial"], verts=20)
    smooth(face)
    link_to(face, base)
    bpy.ops.mesh.primitive_torus_add(major_radius=r * 1.04, minor_radius=r * 0.16,
                                     major_segments=20, minor_segments=8,
                                     location=pos, rotation=rot)
    rim = bpy.context.object
    rim.name = PREFIX + name + "Rim"
    rim.data.materials.append(mats["iron"])
    smooth(rim)
    link_to(rim, base)
    needle = cube(name + "Needle", (0.012, 0.012, r * 1.3),
                  (pos[0], pos[1] - 0.03, pos[2] + 0.01),
                  (math.radians(72), math.radians(35), ang), mats["socket_dark"])
    link_to(needle, base)
    return face


def led_strip(base, mats, name, pos, size, key, ang=0.0):
    strip = cube(name, size, pos, (0, 0, ang), mats[key])
    link_to(strip, base)
    return strip


def grate_panel(base, mats, name, pos, size, bars=9):
    # Real bars over a dark well: at 64 px/tile the light caught on the bar
    # tops and the black between them is what sells it, and a flat striped
    # texture cannot fake that in Cycles.
    w, d = size
    well = cube(name + "Well", (w, d, 0.05), (pos[0], pos[1], pos[2] - 0.045),
                material=mats["socket_dark"])
    link_to(well, base)
    for i in range(bars):
        y = -d / 2 + d * (i + 0.5) / bars
        bar = cube(name + "B%d" % i, (w * 0.97, d / bars * 0.45, 0.05),
                   (pos[0], pos[1] + y, pos[2]), material=mats["gunmetal"])
        link_to(bar, base)
    for k, s in enumerate((-1, 1)):
        edge = cube(name + "Edge%d" % k, (0.05, d + 0.06, 0.06),
                    (pos[0] + s * (w / 2 + 0.02), pos[1], pos[2]),
                    material=mats["steel_dark"])
        bevel(edge, width=0.015, segments=2)
        link_to(edge, base)
    return well


def radiator(base, mats, name, pos, ang=0.0, fins=7, w=0.62, d=0.5):
    # The only warm light on the platform. Frost is deliberately absent here
    # -- the fins are what keeps this corner above freezing.
    x, y, z = pos
    body = cube(name, (w, d, 0.16), (x, y, z), (0, 0, ang), mats["steel_dark"])
    bevel(body, width=0.03, segments=2)
    link_to(body, base)
    core = cube(name + "Core", (w * 0.88, d * 0.88, 0.12), (x, y, z + 0.13),
                (0, 0, ang), mats["radiator"])
    link_to(core, base)
    for i in range(fins):
        fy = -d / 2 + d * (i + 0.5) / fins
        off = Vector((-math.sin(ang) * fy, math.cos(ang) * fy, 0))
        fin = cube(name + "F%d" % i, (w * 0.94, d / fins * 0.36, 0.26),
                   (x + off.x, y + off.y, z + 0.3), (0, 0, ang), mats["gunmetal"])
        bevel(fin, width=0.012, segments=2)
        link_to(fin, base)
    return body


# --------------------------------------------------------------------------
# deck surface -- paneling first, then clusters, then scattered small parts.
# Layering it in that order is what stops the deck reading as isolated props
# dropped on an empty slab.

def deck_ring(base, mats, r_in=1.12, r_out=1.54, z=0.775, seams=7, key="tread"):
    # The primary panel: an annular walkway that follows the chamber instead
    # of a rectangular grid. A flattened torus gives the chamfered edge a
    # milled plate has, and radial seams divide it into plates along the
    # contour.
    major, minor = (r_in + r_out) / 2, (r_out - r_in) / 2
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=72, minor_segments=12,
                                     location=(0, 0, z))
    ring = bpy.context.object
    ring.name = PREFIX + "DeckRing"
    ring.scale = (1, 1, 0.11)
    ring.data.materials.append(mats[key])
    smooth(ring)
    link_to(ring, base)
    for i in range(seams):
        a = math.radians(360 / seams * i + 13)
        strip = cube("DeckRingSeam%d" % i, (minor * 1.9, 0.035, 0.016),
                     (major * math.cos(a), major * math.sin(a), z + 0.026),
                     (0, 0, a), mats["socket_dark"])
        link_to(strip, base)
    return ring


def panel(base, mats, name, pos, size, rot=0.0, key="deck", rivets=0, thick=0.055):
    w, d = size
    plate = cube(name, (w, d, thick), pos, (0, 0, rot), mats[key])
    bevel(plate, width=0.018, segments=2)
    link_to(plate, base)
    if rivets:
        c, s = math.cos(rot), math.sin(rot)
        for side in (-1, 1):
            for i in range(rivets):
                lx = (-0.5 + (i + 0.5) / rivets) * (w - 0.12)
                ly = side * (d / 2 - 0.055)
                riv = sphere("%sRiv%d%d" % (name, side > 0, i), 0.025,
                             (pos[0] + lx * c - ly * s, pos[1] + lx * s + ly * c,
                              pos[2] + thick / 2), mats["gunmetal"], subdiv=1)
                link_to(riv, base)
    return plate


def stencil_plate(base, mats, name, pos, size, key, upright=True, rot=0.0):
    # The decal maps from the object's local XY, so a stencil on a vertical
    # face needs a plate turned to face the camera rather than a mark painted
    # on the wall's own material.
    w, h = size
    rotation = (math.radians(90), 0, rot) if upright else (0, 0, rot)
    plate = cube(name, (w, h, 0.014), pos, rotation, mats[key])
    link_to(plate, base)
    return plate


def seam_light(base, mats, name, pos, length, rot=0.0):
    # A strip running along a panel seam: long, dim, and doing a different job
    # from the round indicators, which is what gives the lights a hierarchy.
    strip = cube(name, (length, 0.035, 0.012), pos, (0, 0, rot), mats["strip"])
    link_to(strip, base)
    housing = cube(name + "Housing", (length + 0.05, 0.075, 0.022),
                   (pos[0], pos[1], pos[2] - 0.012), (0, 0, rot), mats["steel_dark"])
    link_to(housing, base)
    return strip


def led_cluster(base, mats, name, pos, keys, rot=0.0, pitch=0.075, r=0.028):
    # Indicators always come in twos or threes; a lone dot reads as an
    # accident rather than a readout.
    n = len(keys)
    for i, key in enumerate(keys):
        off = (i - (n - 1) / 2) * pitch
        led = sphere("%s%d" % (name, i), r,
                     (pos[0] + off * math.cos(rot), pos[1] + off * math.sin(rot), pos[2]),
                     mats[key], subdiv=1)
        link_to(led, base)


def access_panel(base, mats, name, pos, size=(0.60, 0.20)):
    # A RAISED cover plate, not an inset one. On this rig the front face gets
    # only fill light, so a recessed panel reads as a dark opening however
    # neatly it is framed; a plate standing proud of the beam catches the key
    # on its top chamfer and throws a shadow line under itself, which is what
    # makes it read as a panel at 38x13 source px.
    x, y, z = pos
    w, h = size
    shadow = cube(name + "Shadow", (w + 0.06, 0.02, h + 0.05), (x, y + 0.010, z),
                  material=mats["socket_dark"])
    link_to(shadow, base)
    face = cube(name, (w, 0.055, h), (x, y - 0.020, z), material=mats["holmium"])
    bevel(face, width=0.022, segments=3)
    link_to(face, base)
    for k, sz in enumerate((-1, 1)):
        edge = cube("%sEdge%d" % (name, k), (w - 0.05, 0.06, 0.022),
                    (x, y - 0.024, z + sz * (h / 2 - 0.030)), material=mats["gunmetal"])
        bevel(edge, width=0.008, segments=2)
        link_to(edge, base)
    for k, (sx, sz) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1))):
        screw = cylinder("%sScrew%d" % (name, k), 0.020, 0.035,
                         (x + sx * (w / 2 - 0.055), y - 0.048, z + sz * (h / 2 - 0.048)),
                         (math.radians(90), 0, 0), mats["gunmetal"], verts=6)
        link_to(screw, base)
    return face


def indicator_lamp(base, mats, name, pos, key, w=0.14, h=0.06, ang=0.0):
    # A wall indicator is hardware, not a decal: back plate sunk into the
    # face, dark socket behind the lens, and cheeks plus a drip hood standing
    # proud of it, so the light sits IN a housing. pos is the point ON the
    # wall; the lamp extends along the face normal, local -Y rotated by ang.
    x, y, z = pos
    c, s = math.cos(ang), math.sin(ang)

    def at(lx, ly, lz):
        return (x + lx * c - ly * s, y + lx * s + ly * c, z + lz)

    back = cube(name + "Back", (w + 0.10, 0.03, h + 0.08), at(0, -0.007, 0),
                (0, 0, ang), mats["steel_dark"])
    bevel(back, width=0.01, segments=2)
    link_to(back, base)
    sock = cube(name + "Sock", (w + 0.03, 0.02, h + 0.03), at(0, -0.028, 0),
                (0, 0, ang), mats["socket_dark"])
    link_to(sock, base)
    lens = cube(name, (w, 0.018, h), at(0, -0.040, 0), (0, 0, ang), mats[key])
    link_to(lens, base)
    for k, sgn in enumerate((-1, 1)):
        cheek = cube("%sCheek%d" % (name, k), (0.026, 0.065, h + 0.05),
                     at(sgn * (w / 2 + 0.036), -0.0275, 0), (0, 0, ang),
                     mats["gunmetal"])
        bevel(cheek, width=0.008, segments=2)
        link_to(cheek, base)
    hood = cube(name + "Hood", (w + 0.11, 0.075, 0.02),
                at(0, -0.030, h / 2 + 0.035), (0, 0, ang), mats["gunmetal"])
    bevel(hood, width=0.008, segments=2)
    link_to(hood, base)
    return lens


def greeble(base, mats, name, kind, pos, rot, scale):
    x, y, z = pos
    if kind == "bolt":
        head = cylinder(name, 0.038 * scale, 0.05 * scale, (x, y, z + 0.02),
                        material=mats["gunmetal"], verts=6)
        head.rotation_euler = (0, 0, rot)
        link_to(head, base)
    elif kind == "stub":
        pipe = cylinder(name, 0.033 * scale, 0.16 * scale, (x, y, z + 0.07),
                        material=mats["copper"], verts=10)
        smooth(pipe)
        link_to(pipe, base)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.05 * scale, minor_radius=0.016 * scale,
                                         major_segments=12, minor_segments=6,
                                         location=(x, y, z + 0.03))
        flange = bpy.context.object
        flange.name = PREFIX + name + "Flange"
        flange.data.materials.append(mats["iron"])
        smooth(flange)
        link_to(flange, base)
    elif kind == "box":
        box = cube(name, (0.17 * scale, 0.13 * scale, 0.10 * scale),
                   (x, y, z + 0.05), (0, 0, rot), mats["steel_dark"])
        bevel(box, width=0.012, segments=2)
        link_to(box, base)
    elif kind == "clip":
        bpy.ops.mesh.primitive_torus_add(major_radius=0.055 * scale, minor_radius=0.014 * scale,
                                         major_segments=14, minor_segments=6,
                                         location=(x, y, z + 0.03),
                                         rotation=(math.radians(90), 0, rot))
        clip = bpy.context.object
        clip.name = PREFIX + name
        clip.data.materials.append(mats["iron"])
        smooth(clip)
        link_to(clip, base)


def deck_survey(base, z_lo=0.86, margin=0.06):
    # Read the deck straight off the scene rather than restating the layout:
    # anything tall is an obstacle, anything flat is a surface to stand on.
    # Sampling the surface matters -- a part placed at a fixed height floats
    # wherever there is no panel under it, and a 2 px gap is visible in game.
    obstacles, surfaces = [], []
    for obj in base.objects:
        if obj.type not in ("MESH", "CURVE"):
            continue
        # A run traced by many points gets a keep-out that follows the cable;
        # boxing its extents instead covers most of a quadrant and blanks the
        # scatter around it. Coarse curves (2-4 points) keep the AABB, so the
        # pylons and the older hoses survey exactly as they always did.
        if obj.type == "CURVE" and obj.data.bevel_depth:
            pts = [p for spl in obj.data.splines
                   for p in (spl.bezier_points if spl.type == "BEZIER" else spl.points)]
            if len(pts) >= 10:
                rad = obj.data.bevel_depth + margin
                for p in pts:
                    w = obj.matrix_world @ Vector(p.co[:3])
                    top = w.z + obj.data.bevel_depth
                    if top >= z_lo:
                        obstacles.append((w.x - rad, w.y - rad, w.x + rad, w.y + rad))
                    elif top > 0.76:
                        surfaces.append((w.x - rad, w.y - rad, w.x + rad, w.y + rad, top))
                continue
        corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        top = max(c.z for c in corners)
        xs = [c.x for c in corners]
        ys = [c.y for c in corners]
        if top >= z_lo:
            obstacles.append((min(xs) - margin, min(ys) - margin,
                              max(xs) + margin, max(ys) + margin))
        elif top > 0.76:
            surfaces.append((min(xs), min(ys), max(xs), max(ys), top))
    return obstacles, surfaces


def surface_z(x, y, surfaces, default=0.752):
    tops = [t for x0, y0, x1, y1, t in surfaces if x0 <= x <= x1 and y0 <= y <= y1]
    return max(tops) if tops else default


SCATTER_REGIONS = [
    (-1.95, -2.02, 1.95, -1.05),   # front equipment shelf
    (-1.95, -1.05, -1.15, 0.95),   # left flank
    (1.15, -1.05, 1.95, 0.95),     # right flank
]
GREEBLE_KINDS = ("bolt", "bolt", "stub", "box", "clip")

# Keep-out rectangles for props too low for deck_survey's obstacle threshold
# (the sump grate tops out below 0.86); a bolt dropped on the bars reads as
# debris, not detail.
SCATTER_EXCLUDE = [
    (1.55, 0.04, 2.03, 0.48),    # sump grate + its edge frames
]


def scatter_greebles(base, mats, count=20, min_dist=0.26, seed=17):
    # Rejection sampling with a minimum spacing: jittered rotation and scale,
    # nothing overlapping a prop, nothing dropped on the walkway ring.
    obstacles, surfaces = deck_survey(base)
    rng = random.Random(seed)
    placed = []
    for attempt in range(count * 80):
        if len(placed) >= count:
            break
        x0, y0, x1, y1 = SCATTER_REGIONS[rng.randrange(len(SCATTER_REGIONS))]
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = math.hypot(x, y)
        if 1.02 < r < 1.70:                      # keep the walkway clear
            continue
        if any(ex0 <= x <= ex1 and ey0 <= y <= ey1
               for ex0, ey0, ex1, ey1 in SCATTER_EXCLUDE):
            continue
        if any((x - px) ** 2 + (y - py) ** 2 < min_dist ** 2 for px, py in placed):
            continue
        if any(bx0 <= x <= bx1 and by0 <= y <= by1 for bx0, by0, bx1, by1 in obstacles):
            continue
        greeble(base, mats, "Greeble%02d" % len(placed), rng.choice(GREEBLE_KINDS),
                (x, y, surface_z(x, y, surfaces) - 0.004),
                rng.uniform(0, 2 * math.pi), rng.uniform(0.8, 1.3))
        placed.append((x, y))
    print("  [scatter] %d tertiary greebles" % len(placed))
    return placed


def heat_pipe_run(base, mats, name, x_out, x_in, y, z, segments=3):
    # Aquilo's most recognisable hardware, and the deck's only heat story: a
    # lagged pipe whose interior glow shows in the gaps between jacket
    # sections and at the end cap. The core runs the full length so every
    # seam lights, rather than faking a glow per joint.
    span = abs(x_in - x_out)
    core = cylinder(name + "Core", 0.072, span, ((x_in + x_out) / 2, y, z),
                    (0, math.radians(90), 0), mats["heat_glow"], verts=16)
    smooth(core)
    link_to(core, base)
    lo = min(x_in, x_out)
    gap = 0.05
    seg = (span - gap * (segments - 1)) / segments
    for i in range(segments):
        cx = lo + seg / 2 + i * (seg + gap)
        jacket = cylinder("%sJacket%d" % (name, i), 0.132, seg, (cx, y, z),
                          (0, math.radians(90), 0), mats["insulation"], verts=20)
        bevel(jacket, width=0.02, segments=2)
        smooth(jacket)
        link_to(jacket, base)
        for k, s in enumerate((-1, 1)):
            bpy.ops.mesh.primitive_torus_add(major_radius=0.152, minor_radius=0.028,
                                             major_segments=20, minor_segments=8,
                                             location=(cx + s * seg / 2, y, z),
                                             rotation=(0, math.radians(90), 0))
            flange = bpy.context.object
            flange.name = PREFIX + "%sFlange%d%d" % (name, i, k)
            flange.data.materials.append(mats["iron"])
            smooth(flange)
            link_to(flange, base)
    # end cap at the rim, and the collar where it enters the chamber
    cap = cylinder(name + "Cap", 0.15, 0.06, (max(x_in, x_out) + 0.03, y, z),
                   (0, math.radians(90), 0), mats["heat_glow"], verts=20)
    smooth(cap)
    link_to(cap, base)
    collar = cylinder(name + "Collar", 0.17, 0.07, (lo - 0.04, y, z),
                      (0, math.radians(90), 0), mats["gunmetal"], verts=20)
    bevel(collar, width=0.02, segments=2)
    smooth(collar)
    link_to(collar, base)
    saddle = cube(name + "Saddle", (0.16, 0.24, 0.20),
                  ((x_in + x_out) / 2, y, z - 0.20), material=mats["steel_dark"])
    bevel(saddle, width=0.02, segments=2)
    link_to(saddle, base)
    return core


def relief_valve(base, mats, name, pos, ang=0.0):
    x, y, z = pos
    stand = cylinder(name, 0.042, 0.26, (x, y, z + 0.13), material=mats["copper"], verts=12)
    smooth(stand)
    link_to(stand, base)
    body = cube(name + "Body", (0.13, 0.11, 0.10), (x, y, z + 0.29), (0, 0, ang),
                mats["gunmetal"])
    bevel(body, width=0.015, segments=2)
    link_to(body, base)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.075, minor_radius=0.014,
                                     major_segments=16, minor_segments=6,
                                     location=(x, y, z + 0.38))
    wheel = bpy.context.object
    wheel.name = PREFIX + name + "Wheel"
    wheel.data.materials.append(mats["rusty"])
    smooth(wheel)
    link_to(wheel, base)
    for k in range(3):
        a = math.radians(120 * k)
        spoke = cube(name + "Spoke%d" % k, (0.14, 0.012, 0.012),
                     (x, y, z + 0.38), (0, 0, a), mats["rusty"])
        link_to(spoke, base)
    gauge(base, mats, name + "Gauge", (x + 0.13, y - 0.13, z + 0.22),
          ang=math.radians(-20), r=0.075)
    return stand


def sight_glass(base, mats, name, pos, r, fluid_key):
    # Narrow window with a fill level: the cheapest way to say "there is
    # something in this tank" on a prop that is otherwise a smooth cylinder.
    x, y, z = pos
    # "Level"/"Void", not "Fill"/"Empty": the audit groups sub-parts by their
    # shared prefix up to an uppercase boundary, and Fill/Frame split on a
    # lowercase letter, which mis-reports the window seated in its own bezel
    frame = cube(name + "Frame", (0.075, 0.03, 0.40), (x, y - r - 0.012, z),
                 material=mats["iron"])
    link_to(frame, base)
    level = cube(name + "Level", (0.045, 0.02, 0.20), (x, y - r - 0.020, z - 0.09),
                 material=mats[fluid_key])
    link_to(level, base)
    void = cube(name + "Void", (0.045, 0.02, 0.17), (x, y - r - 0.020, z + 0.10),
                material=mats["socket_dark"])
    link_to(void, base)
    return frame


def cable_tray(base, mats, name, a, b, box_t=0.55):
    # Ties two clusters into one system. Ends in glands rather than stopping
    # in mid-air, which is what makes a run read as connected hardware.
    a, b = Vector(a), Vector(b)
    d = b - a
    ang = math.atan2(d.y, d.x)
    mid = (a + b) / 2
    length = d.length
    floor = cube(name, (length, 0.15, 0.022), (mid.x, mid.y, mid.z),
                 (0, 0, ang), mats["steel_dark"])
    link_to(floor, base)
    for k, s in enumerate((-1, 1)):
        rail = cube("%sRail%d" % (name, k), (length, 0.02, 0.055),
                    (mid.x - math.sin(ang) * s * 0.075,
                     mid.y + math.cos(ang) * s * 0.075, mid.z + 0.02),
                    (0, 0, ang), mats["steel_dark"])
        link_to(rail, base)
    rng = random.Random(31)
    for k in range(3):
        off = (k - 1) * 0.042
        pts = []
        for t in (0.0, 0.35, 0.7, 1.0):
            p = a.lerp(b, t)
            pts.append((p.x - math.sin(ang) * off,
                        p.y + math.cos(ang) * off,
                        p.z + 0.045 + rng.uniform(-0.006, 0.006)))
        pipe_run(base, mats, "%sCable%d" % (name, k), pts, 0.018,
                 mat_key="cable" if k else "warm")
    box_pos = a.lerp(b, box_t)
    box = cube(name + "Box", (0.22, 0.18, 0.17), (box_pos.x, box_pos.y, box_pos.z + 0.10),
               (0, 0, ang), mats["holmium"])
    bevel(box, width=0.018, segments=2)
    link_to(box, base)
    for k, s in enumerate((-1, 1)):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.038, minor_radius=0.014,
                                         major_segments=12, minor_segments=6,
                                         location=(box_pos.x + math.cos(ang) * s * 0.115,
                                                   box_pos.y + math.sin(ang) * s * 0.115,
                                                   box_pos.z + 0.09),
                                         rotation=(0, math.radians(90), ang))
        gland = bpy.context.object
        gland.name = PREFIX + "%sGland%d" % (name, k)
        gland.data.materials.append(mats["iron"])
        smooth(gland)
        link_to(gland, base)
    return floor


def fuel_bay(base, mats, name, pos, ang=0.0):
    # Swappable fuel-cell bay: low service hardware for the front shelf.
    # Three cartridge slots behind a dark mouth, centre cell half withdrawn
    # with its grip toward the camera -- somebody is mid-swap.
    x, y, z = pos
    c, s = math.cos(ang), math.sin(ang)

    def at(lx, ly, lz):
        return (x + lx * c - ly * s, y + lx * s + ly * c, z + lz)

    body = cube(name, (0.34, 0.36, 0.24), at(0, 0, 0.12), (0, 0, ang),
                mats["holmium_label"])
    bevel(body, width=0.02, segments=2)
    link_to(body, base)
    mouth = cube(name + "Mouth", (0.27, 0.05, 0.17), at(0, -0.17, 0.13),
                 (0, 0, ang), mats["socket_dark"])
    link_to(mouth, base)
    for k in range(3):
        lx = (k - 1) * 0.10
        out = 0.15 if k == 1 else 0.012
        cart = cube("%sCell%d" % (name, k), (0.085, 0.15, 0.12),
                    at(lx, -0.145 - out, 0.13), (0, 0, ang), mats["gunmetal"])
        bevel(cart, width=0.012, segments=2)
        link_to(cart, base)
        grip = cube("%sGrip%d" % (name, k), (0.06, 0.02, 0.024),
                    at(lx, -0.225 - out, 0.16), (0, 0, ang), mats["rusty"])
        link_to(grip, base)
    led = sphere(name + "Led", 0.024, at(0.125, -0.19, 0.215),
                 mats["led_amber"], subdiv=1)
    link_to(led, base)
    return body


def ammonia_reservoir(base, mats, name, pos, r=0.26, h=0.92):
    # Ammonia slush reservoir: one tall frosted tank instead of the twin rear
    # canisters, with a lit sight glass showing the fill -- Aquilo's ocean,
    # stored. Tall mass in the rear corner is what the depth gradient wants,
    # and the glass gives the coldest quadrant one small light of its own.
    x, y, z = pos                                    # z = base of the tank
    body = cylinder(name, r, h, (x, y, z + h / 2), material=mats["frosty"],
                    verts=24)
    bevel(body, width=0.03, segments=2)
    smooth(body)
    link_to(body, base)
    dome = sphere(name + "Dome", r * 0.96, (x, y, z + h - 0.02), mats["frosty"])
    smooth(dome)
    link_to(dome, base)
    for k, t in enumerate((0.30, 0.72)):
        bpy.ops.mesh.primitive_torus_add(major_radius=r * 1.05,
                                         minor_radius=r * 0.09,
                                         major_segments=24, minor_segments=8,
                                         location=(x, y, z + h * t))
        strap = bpy.context.object
        strap.name = PREFIX + name + "Strap%d" % k
        strap.data.materials.append(mats["iron"])
        smooth(strap)
        link_to(strap, base)
    vent = cylinder(name + "Vent", 0.05, 0.18,
                    (x + 0.10, y - 0.06, z + h + 0.17),
                    material=mats["copper"], verts=10)
    smooth(vent)
    link_to(vent, base)
    sight_glass(base, mats, name + "Glass", (x, y, z + h * 0.48), r, "fluid_cold")
    return body


def bus_bar(base, mats, name, a, b, posts=(0.45, 0.72)):
    # Holmium superconductor bus on insulator standoffs: lugged onto the HV
    # side, collared into the chamber wall, so the power story reads as one
    # line from the transformer to the core.
    a, b = Vector(a), Vector(b)
    d = b - a
    ang = math.atan2(d.y, d.x)
    mid = (a + b) / 2
    bar = cube(name, (d.length, 0.055, 0.045), tuple(mid), (0, 0, ang),
               mats["holmium"])
    bevel(bar, width=0.012, segments=2)
    link_to(bar, base)
    rail = cube(name + "Rail", (d.length * 0.82, 0.03, 0.03),
                (mid.x, mid.y, mid.z + 0.045), (0, 0, ang), mats["holmium"])
    link_to(rail, base)
    for k, t in enumerate(posts):
        p = a.lerp(b, t)
        post = cylinder("%sPost%d" % (name, k), 0.030, 0.10,
                        (p.x, p.y, p.z - 0.075), material=mats["iron"], verts=10)
        smooth(post)
        link_to(post, base)
        insu = cylinder("%sInsu%d" % (name, k), 0.045, 0.035,
                        (p.x, p.y, p.z - 0.033), material=mats["hose"], verts=12)
        smooth(insu)
        link_to(insu, base)
        foot = cube("%sFoot%d" % (name, k), (0.11, 0.09, 0.02),
                    (p.x, p.y, p.z - 0.129), (0, 0, ang), mats["steel_dark"])
        link_to(foot, base)
    lug = cube(name + "Lug", (0.09, 0.11, 0.10), tuple(a), (0, 0, ang),
               mats["copper"])
    bevel(lug, width=0.012, segments=2)
    link_to(lug, base)
    collar = cube(name + "Collar", (0.10, 0.13, 0.13), tuple(b), (0, 0, ang),
                  mats["gunmetal"])
    bevel(collar, width=0.015, segments=2)
    link_to(collar, base)
    return bar


def inspection_hatch(base, mats, name, pos, size=(0.52, 0.42), ang=0.0):
    x, y, z = pos
    w, d = size
    frame = cube(name + "Frame", (w + 0.08, d + 0.08, 0.03), (x, y, z - 0.01),
                 (0, 0, ang), mats["steel_dark"])
    link_to(frame, base)
    lid = cube(name, (w, d, 0.035), (x, y, z + 0.022), (0, 0, ang), mats["hatch_lid"])
    bevel(lid, width=0.012, segments=2)
    link_to(lid, base)
    for k, s in enumerate((-1, 1)):
        hinge = cylinder("%sHinge%d" % (name, k), 0.022, 0.10,
                         (x - math.sin(ang) * (d / 2) + math.cos(ang) * s * (w / 3),
                          y + math.cos(ang) * (d / 2) + math.sin(ang) * s * (w / 3),
                          z + 0.03), (0, math.radians(90), ang), mats["iron"], verts=8)
        smooth(hinge)
        link_to(hinge, base)
    latch = cube(name + "Latch", (0.07, 0.10, 0.045),
                 (x + math.sin(ang) * (d / 2 + 0.02),
                  y - math.cos(ang) * (d / 2 + 0.02), z + 0.04),
                 (0, 0, ang), mats["gunmetal"])
    bevel(latch, width=0.01, segments=2)
    link_to(latch, base)
    return lid


def chamber_strut(base, mats, name, deg, r_out=1.50, r_in=1.16, z_lo=0.81, z_hi=1.20):
    # Replaces the sunk hoops that used to pass straight through the dish rim.
    # A strut with a footing and a bracket says the same thing and can be
    # placed without intersecting anything.
    a = math.radians(deg)
    p0 = Vector((r_out * math.cos(a), r_out * math.sin(a), z_lo))
    p1 = Vector((r_in * math.cos(a), r_in * math.sin(a), z_hi))
    d = p1 - p0
    strut = cylinder(name, 0.05, d.length, (p0 + p1) / 2, material=mats["gunmetal"])
    strut.rotation_mode = "QUATERNION"
    strut.rotation_quaternion = d.to_track_quat("Z", "Y")
    smooth(strut)
    link_to(strut, base)
    foot = cube(name + "Foot", (0.20, 0.16, 0.05), (p0.x, p0.y, p0.z + 0.01),
                (0, 0, a), mats["steel_dark"])
    bevel(foot, width=0.015, segments=2)
    link_to(foot, base)
    for k, s in enumerate((-1, 1)):
        bolt = sphere("%sBolt%d" % (name, k), 0.022,
                      (p0.x - math.sin(a) * s * 0.065, p0.y + math.cos(a) * s * 0.065,
                       p0.z + 0.035), mats["gunmetal"], subdiv=1)
        link_to(bolt, base)
    bracket = cube(name + "Bracket", (0.13, 0.12, 0.09), (p1.x, p1.y, p1.z),
                   (0, 0, a), mats["iron"])
    bevel(bracket, width=0.015, segments=2)
    link_to(bracket, base)
    return strut


def build_coolant_cluster(base, mats):
    panel(base, mats, "PanelCoolant", (-1.16, -1.54, 0.78), (1.4, 0.96),
          rot=math.radians(4), key="deck_cold", rivets=4)
    radiator(base, mats, "Radiator", (-1.32, -1.52, 0.90), ang=math.radians(4))
    stencil_plate(base, mats, "RadLabel", (-1.32, -1.785, 0.93), (0.34, 0.12),
                  "riser_hazard")
    canister(base, mats, "CanHot", (-0.88, -1.58, 1.18), fluid_key="fluid_hot")
    canister(base, mats, "CanCold", (-0.48, -1.60, 1.18), fluid_key="fluid_cold")
    sight_glass(base, mats, "CanColdGlass", (-0.48, -1.60, 1.18), 0.16, "fluid_cold")

    pump = cube("CoolPump", (0.36, 0.28, 0.20), (-0.90, -1.16, 0.91),
                (0, 0, math.radians(-9)), mats["holmium_label"])
    bevel(pump, width=0.02, segments=2)
    link_to(pump, base)
    motor = cylinder("CoolPumpMotor", 0.10, 0.16, (-0.90, -1.16, 1.09),
                     (math.radians(90), 0, math.radians(-9)), mats["gunmetal"], verts=14)
    smooth(motor)
    link_to(motor, base)

    # the loop, drawn: tanks to pump, pump to radiator, floor port to tanks
    pipe_run(base, mats, "CoolPipeA",
             [(-0.88, -1.44, 1.30), (-0.90, -1.30, 1.16), (-0.90, -1.20, 1.02)],
             0.036, mat_key="copper", flange_ts=(0.6,))
    pipe_run(base, mats, "CoolPipeB",
             [(-1.06, -1.16, 0.98), (-1.30, -1.24, 0.98), (-1.46, -1.36, 0.96)],
             0.034, mat_key="copper", flange_ts=(0.5,))
    hose_run(base, mats, "CoolHose", (-0.62, -1.86, 0.90), (-0.57, -1.80, 0.96),
             sag=0.06, lateral=0.04, rings=3, radius=0.034, mat_key="hose")
    led_cluster(base, mats, "CoolLed", (-1.05, -1.29, 1.02),
                ("led_cyan", "led_green"), rot=math.radians(-9))


def build_power_cluster(base, mats):
    panel(base, mats, "PanelPower", (1.28, -1.58, 0.78), (1.5, 0.92),
          rot=math.radians(-3), key="deck_arrows", rivets=4)
    for i, cx in enumerate((0.88, 1.15, 1.42)):
        cell = cylinder("Cap%d" % i, 0.115, 0.40, (cx, -1.74, 1.01),
                        material=mats["gunmetal"], verts=16)
        bevel(cell, width=0.03, segments=2)
        smooth(cell)
        link_to(cell, base)
        top = cylinder("CapTop%d" % i, 0.055, 0.06, (cx, -1.74, 1.24),
                       material=mats["copper"], verts=10)
        smooth(top)
        link_to(top, base)
    busbar = cube("Busbar", (0.62, 0.045, 0.03), (1.15, -1.74, 1.26), material=mats["copper"])
    link_to(busbar, base)

    transformer = cube("Transformer", (0.40, 0.34, 0.30), (1.66, -1.18, 0.95),
                       (0, 0, math.radians(-14)), mats["power_hv"])
    bevel(transformer, width=0.025, segments=2)
    link_to(transformer, base)
    for i in range(5):
        fin = cube("TransFin%d" % i, (0.34, 0.03, 0.10),
                   (1.66 + (i - 2) * 0.065 * math.sin(math.radians(-14)),
                    -1.18 + (i - 2) * 0.065 * math.cos(math.radians(-14)), 1.15),
                   (0, 0, math.radians(-14)), mats["gunmetal"])
        link_to(fin, base)
    led_cluster(base, mats, "PowerLed", (1.60, -1.36, 1.02),
                ("led_amber", "led_amber", "led_green"), rot=math.radians(-14), pitch=0.062)

    hose_run(base, mats, "PowerCable", (1.40, -1.74, 1.24), (1.62, -1.34, 1.04),
             sag=0.10, lateral=0.06, rings=3, radius=0.032, mat_key="cable")


def build_console_cluster(base, mats):
    # The hero readout sits front and centre, on the one stretch of deck that
    # is never occluded in this projection -- a console tucked down the right
    # flank was invisible behind the manifold and the pylon.
    panel(base, mats, "PanelConsole", (0.06, -1.46, 0.78), (0.98, 0.78),
          rot=math.radians(-2), key="holmium_id", rivets=3)
    ped = cube("ConsolePed", (0.44, 0.26, 0.24), (0.06, -1.40, 0.93),
               (0, 0, math.radians(-4)), mats["steel_dark"])
    bevel(ped, width=0.02, segments=2)
    link_to(ped, base)
    # +44 about X, not -44: rotating a plate's +Z normal by a negative angle
    # points it away from the camera, which renders the back of the screen
    tilt = (math.radians(44), 0, math.radians(-4))
    backing = cube("ConsoleBacking", (0.54, 0.36, 0.05), (0.06, -1.52, 1.10),
                   tilt, mats["gunmetal"])
    bevel(backing, width=0.015, segments=2)
    link_to(backing, base)
    screen = cube("ConsoleScreen", (0.44, 0.27, 0.02), (0.06, -1.543, 1.124),
                  tilt, mats["screen"])
    link_to(screen, base)
    brow = cube("ConsoleBrow", (0.56, 0.07, 0.04), (0.06, -1.44, 1.235),
                (0, 0, math.radians(-4)), mats["steel_dark"])
    bevel(brow, width=0.012, segments=2)
    link_to(brow, base)
    led_cluster(base, mats, "ConsoleLed", (0.06, -1.26, 1.03),
                ("led_green", "led_cyan", "led_amber"), rot=math.radians(-4), pitch=0.07)
    # the console's data cable used to stop in mid-air; now it plugs into the
    # fuel bay's west face through a gland
    hose_run(base, mats, "ConsoleCable", (0.26, -1.32, 0.98), (0.40, -1.40, 0.95),
             sag=0.03, lateral=0.03, rings=2, radius=0.028, mat_key="cable")
    bpy.ops.mesh.primitive_torus_add(major_radius=0.045, minor_radius=0.015,
                                     major_segments=14, minor_segments=6,
                                     location=(0.378, -1.40, 0.948),
                                     rotation=(0, math.radians(90), math.radians(-5)))
    cgland = bpy.context.object
    cgland.name = PREFIX + "ConsoleCableGland"
    cgland.data.materials.append(mats["iron"])
    smooth(cgland)
    link_to(cgland, base)


def build_heat_run(base, mats):
    # The deck had no heat anywhere, which on Aquilo is the one thing that
    # cannot be missing. Its glow sits opposite the cyan readout so the deck
    # carries the same warm/cold tension as the coolant loop.
    panel(base, mats, "PanelHeat", (1.70, -0.24, 0.78), (0.60, 0.66),
          key="holmium", rivets=3)
    heat_pipe_run(base, mats, "HeatPipe", 2.22, 1.24, -0.24, 1.04)
    relief_valve(base, mats, "Relief", (1.86, -0.48, 0.99), ang=math.radians(-12))
    mast = cylinder("SensorMast", 0.018, 0.36, (1.30, -0.16, 1.00),
                    material=mats["gunmetal"], verts=8)
    link_to(mast, base)
    tip = sphere("SensorTip", 0.032, (1.30, -0.16, 1.20), mats["glow"], subdiv=1)
    smooth(tip)
    link_to(tip, base)


# --------------------------------------------------------------------------
# deck plant -- floor cabling and the alien-tech props it feeds
#
# Everything in this section is support hardware for the containment core and
# all of it is deliberately low: the deck may get busier, but the core stays
# the only thing breaking the skyline. Heights are sampled off the deck with
# surface_z rather than assumed -- a prop at a fixed z floats wherever there
# is no panel under it, and a 2 px gap shows at 64 px/tile.

def _cable_saddles(base, mats, name, pts, radius, saddles, key="holmium"):
    # A floor run is pinned down every so often, and the clamp is what stops
    # it reading as a line drawn on the plate. Holmium, not iron: a dark clamp
    # on a dark cable on a dark deck is three values of nothing.
    n = len(pts)
    for j, t in enumerate(saddles):
        f = t * (n - 1)
        i = min(int(f), n - 2)
        p0, p1 = Vector(pts[i]), Vector(pts[i + 1])
        pos = p0.lerp(p1, f - i)
        ang = math.atan2(p1.y - p0.y, p1.x - p0.x)
        sad = cube("%sSaddle%d" % (name, j),
                   (radius * 1.4, radius * 3.8, radius * 2.4),
                   (pos.x, pos.y, pos.z - radius * 0.34), (0, 0, ang), mats[key])
        bevel(sad, width=radius * 0.24, segments=2)
        link_to(sad, base)


def _cable_lat(t, amp, waves, phase):
    # The meander, tapered to nothing at both ends so a run still lands on its
    # glands however hard the middle wanders. Shared with the router: checking
    # the straight anchor line instead let the built cable wander into a tank
    # the route had cleared.
    return amp * math.sin(2 * math.pi * waves * t + phase) * math.sin(math.pi * t)


def _polyline_at(anchors, t):
    # Position and local direction a fraction t along a polyline, by length.
    # Waypoints are what let a run bow around the flank tanks instead of
    # driving through them.
    segs = [(Vector(anchors[i]), Vector(anchors[i + 1]))
            for i in range(len(anchors) - 1)]
    lens = [(b - a).length for a, b in segs]
    total = sum(lens) or 1.0
    d = t * total
    for k, ((a, b), L) in enumerate(zip(segs, lens)):
        if d <= L or k == len(segs) - 1:
            return a.lerp(b, min(d / L, 1.0) if L else 0.0), (b - a).normalized()
        d -= L
    a, b = segs[-1]
    return b, (b - a).normalized()


def floor_cable(base, mats, name, anchors, surfaces, waves=1.4, amp=0.20,
                radius=0.05, mat_key="hose", saddles=(0.34, 0.68), n=20,
                hump=0.022, phase=0.0, ribs=0, ring_key="copper"):
    # A run that LIES on the deck instead of spanning it. The slack is
    # horizontal: a cable resting on a floor meanders in plan, and only
    # bellies upward between saddles -- a catenary here would read as a hoop
    # standing off the plate. The small hump matters more than it sounds: a
    # run pressed flat to the deck catches no key light and disappears into
    # the plate it lies on.
    #
    # Resting height follows whatever is underneath, so a run crossing the
    # walkway ring and stepping down onto bare plinth stays in contact with
    # both.
    a0, b0 = Vector(anchors[0]), Vector(anchors[-1])
    pts = []
    for k in range(n):
        t = k / (n - 1)
        p, tang = _polyline_at(anchors, t)
        side = Vector((-tang.y, tang.x, 0))
        side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
        q = p + side * _cable_lat(t, amp, waves, phase)
        rest = surface_z(q.x, q.y, surfaces) + radius * 0.92
        if t < 0.18:
            u = t / 0.18
            z = a0.z + (rest - a0.z) * (u * u * (3 - 2 * u))
        elif t > 0.82:
            u = (1 - t) / 0.18
            z = b0.z + (rest - b0.z) * (u * u * (3 - 2 * u))
        else:
            z = rest + hump * math.sin(math.pi * (t - 0.18) / 0.64)
        pts.append((q.x, q.y, z))
    obj = pipe_run(base, mats, name, pts, radius, mat_key=mat_key,
                   rings=ribs, ring_key=ring_key)
    _cable_saddles(base, mats, name, pts, radius, saddles)
    return pts, obj


def cable_gland(base, mats, name, pos, ang, r=0.075):
    # Where a run meets a wall it gets a fitting, not a gap.
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=r * 0.36,
                                     major_segments=16, minor_segments=8,
                                     location=pos,
                                     rotation=(0, math.radians(90), ang))
    g = bpy.context.object
    g.name = PREFIX + name
    g.data.materials.append(mats["iron"])
    smooth(g)
    link_to(g, base)
    return g


def junction_box(base, mats, name, pos, ang, size=(0.20, 0.16, 0.13)):
    # Where a spur leaves a feeder. Gives the run a reason to change
    # direction and puts one light-valued block down on the walkway.
    box = cube(name, size, (pos[0], pos[1], pos[2] + size[2] * 0.42),
               (0, 0, ang), mats["holmium_label"])
    bevel(box, width=0.018, segments=2)
    link_to(box, base)
    lid = cube(name + "Lid", (size[0] * 0.70, size[1] * 0.46, 0.018),
               (pos[0], pos[1], pos[2] + size[2] * 1.02), (0, 0, ang), mats["gunmetal"])
    link_to(lid, base)
    return box


# The four feeders from the containment pedestal out to the corner electrodes.
#
# Angles are chosen off the render, not off the model. At a 45 deg pitch the
# walkway FLANKS (either side of the chamber, around y = -0.4) are the open
# floor this camera actually sees; the lane straight across the front sits
# directly behind the console screen and brow, and a trunk routed through it
# rendered completely invisible -- 1.6% of the sprite changed for a full
# cable system. So the two front feeders are the heavy, detailed ones and
# leave the pedestal out into those flanks, while the rear pair is thinner
# and routed mainly so the machine is wired rather than to be looked at.
#
# (name, corner x sign, corner y sign, radius, waves, amp, phase, saddles,
#  material, ribs). The route itself is searched, not written down -- see
# _route_feeder. Everything else is deliberately unequal: four identical
# sweeps at 90 deg to each other read as a stamped pattern, and the two the
# camera looks straight at are the heavy, detailed ones.
FEEDER_SPECS = [
    ("FL", -1, -1, 0.072, 1.15, 0.20, 0.4, (0.26, 0.55, 0.82), "conduit", 7),
    ("FR", 1, -1, 0.062, 1.45, 0.17, 2.4, (0.30, 0.62, 0.88), "hose", 9),
    ("BL", -1, 1, 0.046, 1.30, 0.12, 1.2, (0.34, 0.72), "hose", 0),
    ("BR", 1, 1, 0.041, 1.60, 0.10, 3.0, (0.38, 0.76), "conduit", 0),
]


# Device placements, taken off a ray-cast visibility map of the deck (cast
# every candidate point toward the camera and see what is in the way) rather
# than off the layout. The difference is not small: a first pass placed these
# by reading the occupancy map, and three of the four came out occluded --
# the walkway flanks look open in plan and are criss-crossed by the chamber
# hoses overhead, and the whole rear deck sits behind the amphitheater.
#
# What is actually clear is the front-left and front-right of the walkway,
# plus the shelf edge ahead of the coolant skid. All four go there, which is
# also where the camera looks.
# Each of these is a pocket read off a full AABB map of the front quadrants,
# not a guess: holo between the bus bar (y >= -1.16) and the capacitor bank
# (y <= -1.62), inboard of the front-right pylon cap (x >= 1.25) and outboard
# of the fuel bay (x <= 0.74); shard between the chamber lamp hood (x <= 0.52)
# and the bus bar (x >= 0.79); vent and sensor on the left walkway, clear of
# the grate, the radiator (y <= -1.28) and the flank tank (y >= 0.12).
HOLO_POS, HOLO_ANG = (1.00, -1.34), math.radians(-6.0)
CRYO_POS, CRYO_ANG = (-1.13, -0.83), math.radians(-140.0)
SENSOR_POS, SENSOR_ANG = (-1.22, -0.25), math.radians(-104.0)
SHARD_POS = (0.66, -1.13)
VENT_PUFFS = 4

PULSE_LEN = 8           # frames a charge takes to run out along a feeder
PULSE_T0, PULSE_T1 = 0.06, 0.72
# The deck layer renders with the base collection hidden, so a pulse bead has
# nothing to hide behind. Both runs it travels are on open walkway, which is
# what makes that safe. Values are the pylon each feeder's charge precedes.
PULSE_FEEDERS = {"cryo": 3, "holo": 1}


def build_holo_panel(base, deck, mats, pos, ang, surfaces):
    # A projected readout standing off its emitter, not a screen bolted to a
    # bracket -- the one piece of hardware on the deck that is obviously not
    # ordinary industrial plant. Kept low and thin so it never competes with
    # the containment chamber behind it.
    x, y = pos
    z = surface_z(x, y, surfaces)
    c, s = math.cos(ang), math.sin(ang)

    def at(lx, ly, lz):
        return (x + lx * c - ly * s, y + lx * s + ly * c, z + lz)

    body = cube("HoloBase", (0.34, 0.24, 0.085), at(0, 0, 0.042), (0, 0, ang),
                mats["holmium_label"])
    bevel(body, width=0.018, segments=2)
    link_to(body, base)
    # emitter bar: the thing the projection visibly comes out of
    bar = cube("HoloEmitter", (0.28, 0.055, 0.030), at(0, -0.055, 0.10),
               (0, 0, ang), mats["gunmetal"])
    bevel(bar, width=0.008, segments=2)
    link_to(bar, base)
    for k, lx in enumerate((-0.085, 0.085)):
        lens = cylinder("HoloLens%d" % k, 0.022, 0.014, at(lx, -0.055, 0.118),
                        material=mats["lens"], verts=10)
        smooth(lens)
        link_to(lens, base)
    # two raked posts framing the projection volume
    for k, lx in enumerate((-0.155, 0.155)):
        post = cube("HoloPost%d" % k, (0.030, 0.030, 0.20),
                    at(lx, 0.045, 0.16), (math.radians(-9), 0, ang), mats["gunmetal"])
        bevel(post, width=0.007, segments=2)
        link_to(post, base)
    led_cluster(base, mats, "HoloLed", at(0.115, 0.085, 0.095),
                ("led_cyan", "led_green"), rot=ang, pitch=0.055, r=0.020)
    # Two lit rails bracket the projection volume, so the glyphs read as
    # something being thrown between them rather than a panel hanging in air.
    for k, lz in enumerate((0.148, 0.318)):
        rail = cube("HoloRail%d" % k, (0.26, 0.016, 0.010), at(0, 0.010, lz),
                    (0, 0, ang), mats["holo_rail"])
        link_to(rail, base)

    # The projection itself is animated, so it lives in the deck layer. A
    # plate tilted +48 about X faces this camera; -48 renders its back.
    glyph = cube("HoloGlyph", (0.255, 0.165, 0.004),
                 at(0, 0.010, 0.233), (math.radians(48), 0, ang), mats["holo"])
    link_to(glyph, deck)
    return glyph, None


def build_cryo_vent(base, deck, mats, pos, ang, surfaces):
    # Aquilo's own hardware, said out loud: a low-pressure cryogenic exhaust,
    # rimed solid, breathing vapour onto a deck that is already frozen.
    x, y = pos
    z = surface_z(x, y, surfaces)
    flange = cylinder("CryoFlange", 0.155, 0.030, (x, y, z + 0.015),
                      material=mats["iron"], verts=20)
    smooth(flange)
    link_to(flange, base)
    stack = cylinder("CryoStack", 0.098, 0.30, (x, y, z + 0.175),
                     material=mats["frosty"], verts=20)
    smooth(stack)
    link_to(stack, base)
    for k, h in enumerate((0.09, 0.19, 0.27)):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.107, minor_radius=0.018,
                                         major_segments=20, minor_segments=8,
                                         location=(x, y, z + h))
        rib = bpy.context.object
        rib.name = PREFIX + "CryoRib%d" % k
        rib.data.materials.append(mats["frosty"])
        smooth(rib)
        link_to(rib, base)
    mouth = cylinder("CryoMouth", 0.078, 0.020, (x, y, z + 0.328),
                     material=mats["socket_dark"], verts=18)
    smooth(mouth)
    link_to(mouth, base)
    # feed line dropping into the deck, and a hand valve on it
    pipe_run(base, mats, "CryoFeed",
             [(x + 0.13 * math.cos(ang), y + 0.13 * math.sin(ang), z + 0.09),
              (x + 0.26 * math.cos(ang), y + 0.26 * math.sin(ang), z + 0.055),
              (x + 0.34 * math.cos(ang), y + 0.34 * math.sin(ang), z + 0.02)],
             0.026, mat_key="copper", flange_ts=(0.5,))
    wheel = cylinder("CryoValve", 0.052, 0.014,
                     (x + 0.13 * math.cos(ang), y + 0.13 * math.sin(ang), z + 0.145),
                     material=mats["rusty"], verts=14)
    smooth(wheel)
    link_to(wheel, base)
    indicator_lamp(base, mats, "CryoLed", (x - 0.10 * math.sin(ang),
                                           y + 0.10 * math.cos(ang), z + 0.21),
                   "led_cyan", w=0.075, h=0.036, ang=ang)

    # the puffs are animated, so they belong to the deck layer -- and each
    # gets its own material so it can fade on its own schedule
    puffs = []
    for k in range(VENT_PUFFS):
        p = sphere("CryoPuff%d" % k, 0.075, (x, y, z + 0.40),
                   vapor_puff("vapor_puff%d" % k), subdiv=2)
        smooth(p)
        link_to(p, deck)
        puffs.append(p)
    return puffs, (x, y, z + 0.34)


def build_sensor_array(base, mats, pos, ang, surfaces):
    # Sensing, the flow the deck did not have: a steerable dish and a rod
    # array, aimed off-axis so the pair reads as tracking something rather
    # than as decoration bolted down square.
    x, y = pos
    z = surface_z(x, y, surfaces)
    c, s = math.cos(ang), math.sin(ang)

    def at(lx, ly, lz):
        return (x + lx * c - ly * s, y + lx * s + ly * c, z + lz)

    skid = cube("SensorSkid", (0.34, 0.23, 0.050), at(0, 0, 0.026), (0, 0, ang),
                mats["steel_dark"])
    bevel(skid, width=0.014, segments=2)
    link_to(skid, base)
    yoke = cube("SensorYoke", (0.065, 0.065, 0.14), at(-0.075, 0, 0.115),
                (0, 0, ang), mats["gunmetal"])
    bevel(yoke, width=0.012, segments=2)
    link_to(yoke, base)
    # A dish only reads as a dish if the camera can see INTO it. The wide end
    # goes at +Z and the whole cone is tipped 44 deg about X, which is what
    # aims the opening down the view axis; the first pass had it edge-on and
    # rendered a bright holmium blade. Dark inside, lit rim -- the contrast
    # between the two is the entire read at 24 px across.
    bpy.ops.mesh.primitive_cone_add(vertices=26, radius1=0.042, radius2=0.152,
                                    depth=0.060, location=at(-0.070, 0, 0.215),
                                    rotation=(math.radians(44), 0, ang))
    dish = bpy.context.object
    dish.name = PREFIX + "SensorDish"
    dish.data.materials.append(mats["gunmetal"])
    smooth(dish)
    link_to(dish, base)
    axis = dish.matrix_world.to_3x3() @ Vector((0, 0, 1))
    rim_at = Vector(dish.location) + axis * 0.038
    bpy.ops.mesh.primitive_torus_add(major_radius=0.152, minor_radius=0.014,
                                     major_segments=26, minor_segments=8,
                                     location=rim_at,
                                     rotation=(math.radians(44), 0, ang))
    rim = bpy.context.object
    rim.name = PREFIX + "SensorRim"
    rim.data.materials.append(mats["holmium"])
    smooth(rim)
    link_to(rim, base)
    # feed horn on three struts, standing out of the dish toward the camera
    feed_at = Vector(dish.location) + axis * 0.105
    for k in range(3):
        a = math.radians(90 + 120 * k)
        edge = rim_at + (dish.matrix_world.to_3x3() @
                         Vector((0.12 * math.cos(a), 0.12 * math.sin(a), 0)))
        pipe_run(base, mats, "SensorStrut%d" % k,
                 [tuple(edge), tuple(edge.lerp(feed_at, 0.5)), tuple(feed_at)],
                 0.008, mat_key="gunmetal")
    horn = cylinder("SensorHorn", 0.021, 0.045, feed_at,
                    (math.radians(44), 0, ang), mats["iron"], verts=12)
    smooth(horn)
    link_to(horn, base)
    tip = sphere("SensorHornTip", 0.022, feed_at + axis * 0.030,
                 mats["led_cyan"], subdiv=1)
    smooth(tip)
    link_to(tip, base)
    # the rod array: two unequal whips, so it is an array and not a comb
    for k, (lx, h) in enumerate(((0.105, 0.21), (0.155, 0.150))):
        rod = cylinder("SensorRod%d" % k, 0.011, h, at(lx, 0.02, 0.055 + h / 2),
                       (math.radians(5 * (2 * k - 1)), 0, ang), mats["gunmetal"], verts=8)
        link_to(rod, base)
        bead = sphere("SensorBead%d" % k, 0.021, at(lx, 0.02, 0.055 + h),
                      mats["led_amber" if k else "led_cyan"], subdiv=1)
        link_to(bead, base)
    led_cluster(base, mats, "SensorLed", at(0.015, -0.078, 0.056),
                ("led_green", "led_cyan"), rot=ang, pitch=0.048, r=0.017)
    return skid


def build_floor_shard(base, deck, mats, pos, surfaces):
    # A chip of the same mineral the core is made of, left in the deck where
    # it grew. Its glow is a third of the core's: the tell that it is the
    # same substance is the colour, not the brightness.
    x, y = pos
    z = surface_z(x, y, surfaces)
    # cracked collar where it came through the plate
    bpy.ops.mesh.primitive_torus_add(major_radius=0.098, minor_radius=0.024,
                                     major_segments=18, minor_segments=8,
                                     location=(x, y, z + 0.012))
    collar = bpy.context.object
    collar.name = PREFIX + "ShardCollar"
    collar.scale = (1, 1, 0.6)
    collar.data.materials.append(mats["iron"])
    smooth(collar)
    link_to(collar, base)
    rime = cylinder("ShardRime", 0.122, 0.016, (x, y, z + 0.008),
                    material=mats["frosty"], verts=18)
    smooth(rime)
    link_to(rime, base)
    # the shard: a 6-sided pyramid, raked over so it is not a spike on end
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.082, radius2=0.0,
                                    depth=0.30, location=(x, y, z + 0.135),
                                    rotation=(math.radians(17), 0, math.radians(24)))
    shard = bpy.context.object
    shard.name = PREFIX + "Shard"
    shard.data.materials.append(mats["crystal"])
    link_to(shard, base)
    for k, (dx, dy, sc, rot) in enumerate(((-0.10, 0.045, 0.42, 40),
                                           (0.095, -0.035, 0.30, -25))):
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.082 * sc, radius2=0.0,
                                        depth=0.30 * sc,
                                        location=(x + dx, y + dy, z + 0.135 * sc),
                                        rotation=(math.radians(30), 0, math.radians(rot)))
        sp = bpy.context.object
        sp.name = PREFIX + "ShardSplinter%d" % k
        sp.data.materials.append(mats["crystal"])
        link_to(sp, base)
    # the lit interior lives in the deck layer so it can breathe with the core
    core = sphere("ShardCore", 0.042, (x, y, z + 0.105), mats["shard_core"], subdiv=2)
    smooth(core)
    link_to(core, deck)
    return core


# Service cables, one per device: (device, pedestal angle, radius, waves,
# amp, phase, saddles, material, ribs).
#
# They are SHORT, and that is a measured constraint rather than a stylistic
# choice. The clear floor on this deck is a band about 0.25 tiles wide between
# the pedestal wall at r=1.12 and a continuous ring of plant starting near
# r=1.5, so there is nowhere for a long run to go: routing to a corner drum
# was tried and the best line on every corner still crossed 28-40 of 40
# sample points through the radiator, the manifolds or the flank tanks. Each
# electrode keeps the cable it already has, up from its own drum.
#
# The pedestal angle is set a little off the device's own bearing so the run
# arrives across the walkway rather than radially, which is what gives it
# something to sag over.
# Angles are chosen off the AABB map, and two of them matter:
#  - cryo leaves at 232 deg, below the sensor. At 194 it ran straight through
#    the sensor skid and both its whips on the way past.
#  - holo is fed from the BUS BAR's end lug instead of the chamber. The bar
#    spans x 0.79..1.45 across y -1.16..-0.77, squarely between the pedestal
#    and the holo pocket, and no line from the pedestal reaches the panel
#    without crossing it. Tapping a device off a power rail is what a power
#    rail is for, so this is the better drawing anyway.
SERVICE_SPECS = [
    ("cryo", 232.0, None, 0.058, 0.85, 0.10, 0.4, (0.45,), "conduit", 4),
    ("holo", None, (1.36, -1.12, 0.93), 0.050, 0.80, 0.07, 2.4, (0.45,), "hose", 5),
    ("sensor", 168.0, None, 0.036, 0.75, 0.06, 1.1, (0.5,), "hose", 0),
    ("shard", -58.0, None, 0.030, 0.70, 0.05, 2.9, (0.5,), "conduit", 0),
]

# how far back from a device's centre its gland sits, so the run lands on the
# housing rather than in the air beside it
DEVICE_INSET = {"cryo": 0.17, "holo": 0.20, "sensor": 0.21, "shard": 0.11}


def _device_pos(dev):
    return {"cryo": CRYO_POS, "holo": HOLO_POS,
            "sensor": SENSOR_POS, "shard": SHARD_POS}[dev]


def build_deck_cables(base, mats):
    _, surfaces = deck_survey(base)
    runs = {}
    for dev, deg, src_pt, rad, waves, amp, phase, saddles, key, ribs in SERVICE_SPECS:
        if src_pt is None:
            a = math.radians(deg)
            start = (1.12 * math.cos(a), 1.12 * math.sin(a), 0.97)
        else:
            start = src_pt
            a = math.atan2(_device_pos(dev)[1] - start[1],
                           _device_pos(dev)[0] - start[0])
        tx, ty = _device_pos(dev)
        d = Vector((tx - start[0], ty - start[1], 0))
        n = d.normalized() if d.length > 1e-4 else Vector((1, 0, 0))
        inset = DEVICE_INSET[dev]
        end = (tx - n.x * inset, ty - n.y * inset, 0.86)
        pts, _ = floor_cable(base, mats, "DeckFeed" + dev.capitalize(),
                             [start, end], surfaces, radius=rad, waves=waves,
                             amp=amp, phase=phase, saddles=saddles,
                             mat_key=key, ribs=ribs, n=14)
        cable_gland(base, mats, "DeckFeedGland" + dev.capitalize(), start, a,
                    r=rad * 1.6)
        cable_gland(base, mats, "DeckFeedEnd" + dev.capitalize(), end,
                    math.atan2(n.y, n.x), r=rad * 1.7)
        runs[dev] = (pts, surfaces)
    return surfaces, runs


def build_prop_spurs(base, mats, runs, surfaces):
    # Nothing further to lay: every device is already fed directly. Kept as
    # the hook the scene assembly calls, so the ordering stays explicit.
    return


def build_deck_props(base, deck, mats, surfaces):
    glyph, _ = build_holo_panel(base, deck, mats, HOLO_POS, HOLO_ANG, surfaces)
    puffs, vent_mouth = build_cryo_vent(base, deck, mats, CRYO_POS, CRYO_ANG, surfaces)
    build_sensor_array(base, mats, SENSOR_POS, SENSOR_ANG, surfaces)
    shard_core = build_floor_shard(base, deck, mats, SHARD_POS, surfaces)
    beads = {}
    for tag in PULSE_FEEDERS:
        b = sphere("Pulse" + tag.capitalize(), 0.048, (0, 0, 0.85),
                   mats["pulse"], subdiv=2)
        smooth(b)
        link_to(b, deck)
        beads[tag] = b
    return {"glyph": glyph, "puffs": puffs, "beads": beads,
            "vent_mouth": vent_mouth, "shard_core": shard_core}


def build_deck(base, mats, deck):
    deck_ring(base, mats)
    # outer plates: different sizes, a few degrees off square, seams offset so
    # nothing lines up into a grid
    panel(base, mats, "PanelLeft", (-1.72, 0.10, 0.78), (0.62, 1.35),
          rot=math.radians(-3), key="deck_id", rivets=5)
    panel(base, mats, "PanelBackRight", (1.02, 1.06, 0.78), (0.95, 0.8),
          rot=math.radians(6), key="deck")
    panel(base, mats, "PanelBackLeft", (-0.38, 1.02, 0.78), (0.78, 0.7),
          rot=math.radians(-5), key="etched")
    grate_panel(base, mats, "Grate", (-1.11, -0.78, 0.78), (0.50, 0.62), bars=7)
    # sump grate beside the heat pipe: the one place on deck warm enough for
    # meltwater, so the drain sits where the water would actually be
    grate_panel(base, mats, "Sump", (1.79, 0.26, 0.772), (0.30, 0.26), bars=5)
    build_coolant_cluster(base, mats)
    build_power_cluster(base, mats)
    build_console_cluster(base, mats)
    build_heat_run(base, mats)
    # a tray tying the power cluster to the coolant side, so the two read as
    # one system instead of two islands
    cable_tray(base, mats, "Tray", (0.92, -1.90, 0.812), (-0.42, -1.92, 0.812))
    inspection_hatch(base, mats, "Inspect", (-1.70, -1.20, 0.808),
                     size=(0.50, 0.40), ang=math.radians(3))
    # painted markings, on the bare stretch of shelf in front of the props
    stencil_plate(base, mats, "MarkArrows", (0.53, -1.17, 0.812), (0.34, 0.18),
                  "deck_arrows", upright=False, rot=math.radians(-2))
    stencil_plate(base, mats, "MarkCaution", (-0.74, -1.14, 0.812), (0.40, 0.24),
                  "deck_caution", upright=False, rot=math.radians(3))
    # labels on the plinth's front face, the most visible surface on the model
    stencil_plate(base, mats, "LabelHazard", (0.62, -2.362, 0.86), (0.40, 0.17),
                  "riser_hazard")
    stencil_plate(base, mats, "LabelId", (-0.60, -2.362, 0.86), (0.30, 0.15),
                  "riser_id")
    seam_light(base, mats, "SeamLightFront", (-0.10, -1.06, 0.812), 0.85,
               rot=math.radians(2))
    seam_light(base, mats, "SeamLightLeft", (-1.72, 0.86, 0.812), 0.5,
               rot=math.radians(90))
    _, surfaces = deck_survey(base)
    return build_deck_props(base, deck, mats, surfaces)


# --------------------------------------------------------------------------
# static base

def rivet_row(base, mats, name, start, end, count, radius=0.035):
    a, b = Vector(start), Vector(end)
    for i in range(count):
        p = a.lerp(b, i / max(count - 1, 1))
        r = sphere("%s%d" % (name, i), radius, p, mats["steel_dark"], subdiv=1)
        link_to(r, base)


def build_plinth(base, mats):
    slab = cube("Plinth", (4.6, 4.6, 0.75), (0, 0, 0.375), material=mats["steel"])
    bevel(slab, width=0.12)
    link_to(slab, base)

    # Rim beams framing the deck. The side pair BUTTS into the front and back
    # pair (4.70 - 2*0.34) instead of crossing it. Full-length beams both ways
    # put two coincident outer faces at each corner, and worn_metal's ambient
    # occlusion term reads a face's own coplanar twin as total occlusion --
    # which renders a hard-edged BLACK rectangle over the corner. It is not
    # stable, either: which face wins depends on BVH order, so it appears and
    # vanishes as unrelated geometry is added elsewhere on the deck, and the
    # audit never reported it because ("Rim", "Rim") is whitelisted. The
    # outline is unchanged -- every beam still reaches +-2.35 on its long axis.
    for i, (sx, sy, sz) in enumerate([(4.7, 0.34, 0.22), (0.34, 4.02, 0.22)]):
        for j, off in enumerate((-2.18, 2.18)):
            loc = (0, off, 0.82) if i == 0 else (off, 0, 0.82)
            beam = cube("Rim%d%d" % (i, j), (sx, sy, sz), loc, material=mats["steel"])
            bevel(beam, width=0.04)
            link_to(beam, base)

    # chunky corner drums under the pylons -- cylinders catch light gradients
    # the way vanilla's rounded forms do
    for i, (sx, sy) in enumerate([(1, 1), (1, -1), (-1, 1), (-1, -1)]):
        post = cylinder("Corner%d" % i, 0.46, 1.0, (1.85 * sx, 1.85 * sy, 0.5),
                        material=mats["steel"])
        bevel(post, width=0.06)
        smooth(post)
        link_to(post, base)
        cap = cylinder("CornerCap%d" % i, 0.34, 0.14, (1.85 * sx, 1.85 * sy, 1.05),
                       material=mats["steel_dark"])
        bevel(cap, width=0.03)
        smooth(cap)
        link_to(cap, base)

    # bent service run along the back rim, flanged where it joins
    for i, (px, py) in enumerate(((-0.55, 1.86), (-0.30, 1.80))):
        pipe_run(base, mats, "BackPipe%d" % i,
                 [(px - 0.7, py - 0.12, 1.36), (px, py, 1.38),
                  (px + 0.75, py - 0.05, 1.34)],
                 0.065, mat_key="gunmetal", flange_ts=(0.3, 0.75))

    # Access panels on the front rim. The yellow segmented plates that were
    # here read as circuit-board contacts; the flat holmium plates that
    # replaced them read as nothing at all, which was worse.
    for i, px in enumerate((-1.05, 1.05)):
        access_panel(base, mats, "LipPanel%d" % i, (px, -2.364, 0.86))

    # control readout on the front rim: dial and indicator lamps. Each lamp is
    # seated hardware -- housing, dark socket, recessed lens under a drip hood
    # -- because a bare emissive box floating off the face reads as a decal.
    # Two sizes, so the row reads as instruments rather than tiling.
    gauge(base, mats, "RimGauge", (-1.72, -2.40, 0.88))
    pod = cylinder("RimGaugePod", 0.085, 0.09, (-1.72, -2.355, 0.865),
                   (math.radians(72), 0, 0), mats["steel_dark"], verts=16)
    smooth(pod)
    link_to(pod, base)
    for i, (px, key, w) in enumerate(((-0.32, "led_green", 0.13),
                                      (-0.09, "led_green", 0.13),
                                      (0.16, "led_amber", 0.18))):
        indicator_lamp(base, mats, "RimLamp%d" % i, (px, -2.35, 0.875), key, w=w)

    # bottom rail, so the front face is framed top and bottom instead of
    # running off the edge of the hull under the ports
    sill = cube("FrontSill", (4.7, 0.36, 0.16), (0, -2.17, 0.075), material=mats["steel"])
    bevel(sill, width=0.04)
    link_to(sill, base)
    sill_lip = cube("FrontSillLip", (4.62, 0.05, 0.05), (0, -2.36, 0.145),
                    material=mats["steel_dark"])
    link_to(sill_lip, base)
    rivet_row(base, mats, "RivSill", (-2.0, -2.33, 0.075), (2.0, -2.33, 0.075), 9, 0.032)

    # rivet rows along the rim beams
    rivet_row(base, mats, "RivF", (-2.0, -2.18, 0.95), (2.0, -2.18, 0.95), 9)
    rivet_row(base, mats, "RivB", (-2.0, 2.18, 0.95), (2.0, 2.18, 0.95), 9)
    rivet_row(base, mats, "RivL", (-2.18, -2.0, 0.95), (-2.18, 2.0, 0.95), 9)
    rivet_row(base, mats, "RivR", (2.18, -2.0, 0.95), (2.18, 2.0, 0.95), 9)
    # rivets down the front face
    rivet_row(base, mats, "RivFF", (-2.05, -2.32, 0.55), (2.05, -2.32, 0.55), 7, 0.04)


def build_dish(base, mats):
    pedestal = cylinder("Pedestal", 1.1, 0.5, (0, 0, 1.0), material=mats["steel"])
    bevel(pedestal, width=0.05)
    smooth(pedestal)
    link_to(pedestal, base)
    # An ANNULUS, not a disc. This was a solid cylinder and it was the single
    # largest object in the sprite (8.0% of visible pixels, a plain plate) --
    # and it swallowed the containment well whole: an object-ID render measured
    # DishGlow at 0 visible pixels and the four aperture bars at 2, 2, 2 and 0.
    # The well the comment below describes has never actually been on screen.
    dish = annulus("Dish", 0.66, 0.95, 0.2, (0, 0, 1.32), material=mats["gunmetal"])
    bevel(dish, width=0.025, segments=2)
    smooth(dish)
    link_to(dish, base)
    # Containment well, not a lit disc: the glow is recessed under a lipped
    # ring and crossed by aperture bars, so the light reads as coming out of
    # a shaft. A flush emissive circle at this size just looks like a sticker.
    # Recessed 0.15 below the annulus rim, which is ~10 px of visible shaft
    # wall at 64 px/tile -- enough to read as depth rather than as a lid.
    dish_glow = cylinder("DishGlow", 0.615, 0.05, (0, 0, 1.245), material=mats["glow_hot"])
    smooth(dish_glow)
    link_to(dish_glow, base)
    # shaft floor around the emitter, so the well has a bottom rather than a
    # hole straight through the pedestal
    floor = cylinder("DishWellFloor", 0.655, 0.04, (0, 0, 1.222), material=mats["iron"])
    smooth(floor)
    link_to(floor, base)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.68, minor_radius=0.10,
                                     major_segments=44, minor_segments=12,
                                     location=(0, 0, 1.38))
    lip = bpy.context.object
    lip.name = PREFIX + "DishLip"
    lip.data.materials.append(mats["iron"])
    smooth(lip)
    link_to(lip, base)
    hub = cylinder("DishHub", 0.15, 0.07, (0, 0, 1.40), material=mats["gunmetal"])
    bevel(hub, width=0.02, segments=2)
    smooth(hub)
    link_to(hub, base)
    # Aperture bars, now crossing an open well instead of embedded in a solid
    # plate. Three rather than four: an even count reads as a grille, an odd
    # one as machinery, and it leaves the biggest gap off-centre.
    for i in range(3):
        bar = cube("DishBar%d" % i, (0.058, 1.36, 0.05), (0, 0, 1.372),
                   (0, 0, math.radians(18 + 60 * i)), mats["gunmetal"])
        bevel(bar, width=0.014, segments=2)
        link_to(bar, base)

    # curved collar easing the pedestal into the dish
    bpy.ops.mesh.primitive_torus_add(major_radius=1.02, minor_radius=0.1,
                                     major_segments=48, minor_segments=12,
                                     location=(0, 0, 1.24))
    collar = bpy.context.object
    collar.name = PREFIX + "DishCollar"
    collar.data.materials.append(mats["gunmetal"])
    smooth(collar)
    link_to(collar, base)

    # clamp blocks around the dish rim
    for i in range(4):
        ang = math.radians(45 + 90 * i)
        clamp = cube("DishClamp%d" % i, (0.22, 0.3, 0.24),
                     (1.0 * math.cos(ang), 1.0 * math.sin(ang), 1.36),
                     (0, 0, ang), mats["steel_dark"])
        bevel(clamp, width=0.04)
        link_to(clamp, base)

    # struts carrying the chamber, footed on the walkway and bracketed to
    # the collar -- the hoops that used to be here ran through the dish rim
    for i, deg in enumerate((48, 132)):
        chamber_strut(base, mats, "Strut%d" % i, deg)

    # coolant lines leaving the containment chamber and dropping into the
    # plant below: every one lands on something that could plausibly take it
    def on_collar(deg, r=1.13, z=1.26):
        a = math.radians(deg)
        return (r * math.cos(a), r * math.sin(a), z)

    for i, (deg, target, sag) in enumerate((
            (215, (-1.45, -0.62, 1.24), 0.20),
            (325, (1.36, -0.80, 1.24), 0.20),
            (255, (-0.90, -1.16, 1.04), 0.16),
            (100, (-1.14, 1.18, 1.16), 0.16))):
        start = on_collar(deg)
        hose_run(base, mats, "ChamberHose%d" % i, start, target,
                 sag=sag, lateral=0.12 if i % 2 else -0.12, rings=5,
                 radius=0.052, mat_key="hose")
        # a gland at each end: where a hose meets a wall or a pump, the fix
        # for an intersection is a fitting, not a gap
        for k, (px, py, pz) in enumerate((start, target)):
            bpy.ops.mesh.primitive_torus_add(major_radius=0.075, minor_radius=0.024,
                                             major_segments=16, minor_segments=8,
                                             location=(px, py, pz))
            gland = bpy.context.object
            gland.name = PREFIX + "ChamberGland%d%d" % (i, k)
            gland.data.materials.append(mats["iron"])
            smooth(gland)
            link_to(gland, base)

    # status lamps seated on the chamber wall. The old flat strips sat inside
    # the pedestal's radius and rendered buried; these mount proud of the
    # curve, at deliberately unequal angles so the pair doesn't read tiled.
    for i, a in enumerate((-0.20, 0.36)):
        indicator_lamp(base, mats, "DishLed%d" % i,
                       (1.094 * math.sin(a), -1.094 * math.cos(a), 1.06),
                       "led_cyan", w=0.13, h=0.05, ang=a)


def build_pylons(base, mats):
    TIP_POSITIONS.clear()
    PYLON_CURVES.clear()

    # shared taper: pylon pipes thin toward the tip
    taper_curve = bpy.data.curves.new(PREFIX + "PylonTaperC", "CURVE")
    taper_curve.dimensions = "2D"
    tspl = taper_curve.splines.new("POLY")
    tspl.points.add(1)
    tspl.points[0].co = (0, 1.0, 0, 1)
    tspl.points[1].co = (1, 0.5, 0, 1)
    taper = bpy.data.objects.new(PREFIX + "PylonTaper", taper_curve)
    bpy.context.scene.collection.objects.link(taper)
    link_to(taper, base)  # no bevel -> renders nothing

    for i, (sx, sy) in enumerate([(1, 1), (1, -1), (-1, 1), (-1, -1)]):
        # curved swept pipe: rises from the corner drum, bowing inward
        root = Vector((1.85 * sx, 1.85 * sy, 0.95))
        tip_pos = Vector((1.4 * sx, 1.4 * sy, 2.9))
        curve = bpy.data.curves.new(PREFIX + "PylonC%d" % i, "CURVE")
        curve.dimensions = "3D"
        curve.bevel_depth = 0.19
        curve.bevel_resolution = 6
        curve.use_fill_caps = True
        curve.taper_object = taper
        spl = curve.splines.new("BEZIER")
        spl.bezier_points.add(1)
        p0, p1 = spl.bezier_points
        p0.co = root
        p0.handle_left = root + Vector((0.05 * sx, 0.05 * sy, -0.4))
        p0.handle_right = root + Vector((-0.02 * sx, -0.02 * sy, 0.75))
        p1.co = tip_pos
        p1.handle_left = tip_pos + Vector((0.16 * sx, 0.16 * sy, -0.55))
        p1.handle_right = tip_pos + Vector((-0.16 * sx, -0.16 * sy, 0.55))
        pylon = bpy.data.objects.new(PREFIX + "Pylon%d" % i, curve)
        pylon.data.materials.append(mats["steel"])
        bpy.context.scene.collection.objects.link(pylon)
        link_to(pylon, base)

        # collar sits ON the bowed pipe: evaluate the bezier, not the chord
        h0 = root + Vector((-0.02 * sx, -0.02 * sy, 0.75))
        h1 = tip_pos + Vector((0.16 * sx, 0.16 * sy, -0.55))
        ctrl = (root, h0, h1, tip_pos)
        PYLON_CURVES.append(ctrl)
        on_curve = bezier_pt(ctrl, 0.45)
        collar = cylinder("PylonCollar%d" % i, 0.23, 0.16, on_curve,
                          material=mats["gunmetal"])
        bevel(collar, width=0.03)
        smooth(collar)
        link_to(collar, base)
        cap = cylinder("PylonCap%d" % i, 0.15, 0.16, tip_pos + Vector((0, 0, 0.02)),
                       material=mats["steel_dark"])
        bevel(cap, width=0.03)
        smooth(cap)
        link_to(cap, base)
        tip = sphere("PylonTip%d" % i, 0.09, tip_pos + Vector((0, 0, 0.13)), mats["glow"])
        smooth(tip)
        link_to(tip, base)
        TIP_POSITIONS.append(tip_pos + Vector((0, 0, 0.15)))

        # copper induction windings: a heavy one at the foot, a fine one just
        # under the tip, so each pylon reads as an electrode feeding the field
        helix_on_bezier(base, mats, "PylonCoil%d" % i, ctrl, 0.05, 0.34,
                        turns=4.5, wire=0.036, radius_at=pylon_radius)
        helix_on_bezier(base, mats, "PylonTipCoil%d" % i, ctrl, 0.70, 0.83,
                        turns=3.0, wire=0.024, radius_at=pylon_radius, phase=0.6)
        base_ring = cylinder("PylonCoilSeat%d" % i, 0.26, 0.07, bezier_pt(ctrl, 0.03),
                             material=mats["iron"])
        smooth(base_ring)
        link_to(base_ring, base)

        # feed cable from the corner drum up to the collar, hanging slack
        # routed outboard of the winding: at the old offsets the cable ran
        # straight through the coil it was supposed to feed
        clamp_at = on_curve + Vector((0.42 * sx, 0.42 * sy, -0.04))
        hose_run(base, mats, "PylonCable%d" % i,
                 (1.85 * sx + 0.42 * sx, 1.85 * sy - 0.10 * sy, 1.10),
                 clamp_at, sag=0.18, lateral=0.0, rings=4,
                 radius=0.045, mat_key="cable")
        clamp = cube("PylonClamp%d" % i, (0.13, 0.13, 0.09),
                     (clamp_at.x - 0.06 * sx, clamp_at.y - 0.06 * sy, clamp_at.z),
                     (0, 0, math.radians(45) * sx * sy), mats["iron"])
        bevel(clamp, width=0.015, segments=2)
        link_to(clamp, base)


def build_sockets(base, mats):
    # The base draws the ports in full -- housing, bezel, recess and contacts.
    # The module visualisation then draws ONLY the cartridge on top of them,
    # so nothing is rendered twice and nothing of the lip gets covered.
    for i, (px, py) in enumerate(SOCKET_POSITIONS):
        sock = cube("Socket%d" % i, (0.72, 0.3, 0.55), (px, py, 0.42), material=mats["steel"])
        bevel(sock, width=0.03)
        link_to(sock, base)
        frame = cube("SocketFrame%d" % i, (0.6, 0.06, 0.44), (px, py - 0.14, 0.42),
                     material=mats["steel_dark"])
        link_to(frame, base)
        cav = cube("SocketCavity%d" % i, (0.5, 0.12, 0.34), (px, py - 0.14, 0.4),
                   material=mats["socket_dark"])
        link_to(cav, base)
        # contacts on the face of the recess, so an empty port reads as a
        # socket waiting for a cartridge rather than a hole
        for k, z in enumerate((0.475, 0.325)):
            rail = cube("SocketRail%d%d" % (i, k), (0.34, 0.02, 0.030),
                        (px, py - 0.205, z), material=mats["gunmetal"])
            link_to(rail, base)
        for k, sx in enumerate((-1, 1)):
            guide = cube("SocketGuide%d%d" % (i, k), (0.028, 0.02, 0.30),
                         (px + sx * 0.225, py - 0.205, 0.40), material=mats["gunmetal"])
            link_to(guide, base)
        # lower bezel: the ports used to run straight off the bottom of the
        # hull with nothing under them
        sill = cube("SocketSill%d" % i, (0.78, 0.1, 0.07), (px, py - 0.02, 0.135),
                    material=mats["steel_dark"])
        bevel(sill, width=0.018, segments=2)
        link_to(sill, base)


def build_dish_plant(base, mats):
    """Machinery on the front of the containment annulus.

    Placed by measurement rather than taste: an object-ID render put `Dish` at
    8.0% of all visible pixels as a single plain face, the largest and emptiest
    thing in the sprite. The front half is also the only half the 45-degree
    camera can see into, and everything here stays under z 1.8 so the inner
    ring (lowest sweep z 2.13) and the crystal above it keep their clearance.

    Deliberately NOT mirrored. Vanilla has no bilaterally symmetric entity and
    this beacon read as a monument largely because of it, so the two sides
    carry different plant at different heights and different angles.
    """
    def on_ring(deg, r, z):
        a = math.radians(deg)
        return (r * math.cos(a), r * math.sin(a), z)

    TOP = 1.42                      # annulus top face

    # -- left: a tall condenser stack, the taller of the two ------------------
    lx, ly, _ = on_ring(249, 0.80, TOP)
    body = cylinder("DishCondBody", 0.105, 0.30, (lx, ly, TOP + 0.15),
                    material=mats["holmium"], verts=16)
    smooth(body)
    link_to(body, base)
    for k in range(4):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.118, minor_radius=0.020,
                                         major_segments=18, minor_segments=6,
                                         location=(lx, ly, TOP + 0.05 + 0.07 * k))
        fin = bpy.context.object
        fin.name = PREFIX + "DishCondFin%d" % k
        fin.data.materials.append(mats["copper"])
        smooth(fin)
        link_to(fin, base)
    cap = cylinder("DishCondCap", 0.075, 0.09, (lx, ly, TOP + 0.34),
                   material=mats["gunmetal"], verts=14)
    bevel(cap, width=0.014, segments=2)
    link_to(cap, base)
    relief_valve(base, mats, "DishCondValve", (lx - 0.17, ly - 0.09, TOP - 0.02),
                 ang=math.radians(-24))

    # -- right: a squat control head, lower and turned the other way ----------
    rx, ry, _ = on_ring(303, 0.775, TOP)
    junction_box(base, mats, "DishCtl", (rx, ry, TOP + 0.055), math.radians(28),
                 size=(0.19, 0.15, 0.115))
    sight_glass(base, mats, "DishSight", (rx + 0.12, ry - 0.05, TOP + 0.02),
                0.045, "fluid_cold")
    gauge(base, mats, "DishCtlGauge", (rx - 0.14, ry - 0.10, TOP + 0.10),
          ang=math.radians(18), r=0.070)
    led_strip(base, mats, "DishCtlLed", (rx, ry - 0.09, TOP + 0.125),
              (0.085, 0.016, 0.010), "led_green", ang=math.radians(28))

    # -- the hose between them ----------------------------------------------
    # Arced OVER the well rather than round it: the collar (r 0.92-1.12,
    # z 1.14-1.34) and the four rim clamps leave no clear route at dish level,
    # and a line at annulus height would run inside the annulus solid.
    # Arched, not sagging. A catenary between these two anchors dips to about
    # z 1.43 and the lip torus tops out at 1.48, so the ribbed rings clipped
    # straight through it (the audit caught DishLoopF5 and F7). Arcing it over
    # keeps the whole run clear of the lip and reads as rigid line rather than
    # flexible hose, which is what a coolant crossover on a pressure vessel is.
    mx, my = (lx + rx) * 0.5, (ly + ry) * 0.5
    pipe_run(base, mats, "DishLoop",
             [(lx, ly, TOP + 0.29),
              (mx - 0.06, my - 0.11, TOP + 0.37),
              (rx + 0.03, ry - 0.04, TOP + 0.16)],
             0.036, mat_key="conduit", rings=7, ring_key="iron")
    # short service run off the control head, back down onto the annulus
    pipe_run(base, mats, "DishCtlDrop",
             [(rx + 0.02, ry + 0.05, TOP + 0.05),
              (rx + 0.10, ry + 0.16, TOP - 0.01),
              (rx + 0.13, ry + 0.26, TOP - 0.03)],
             0.026, mat_key="copper", rings=3)

    # -- annulus surface: vents and a bolt circle -----------------------------
    # The ring is 0.29 wide (about 18 px), so this is the largest flat band on
    # the machine and the cheapest place to buy detail.
    for i, deg in enumerate((198, 216, 234, 324, 342, 0, 18)):
        a = math.radians(deg)
        vent = cube("DishVent%d" % i, (0.055, 0.20, 0.022),
                    (0.805 * math.cos(a), 0.805 * math.sin(a), TOP - 0.004),
                    (0, 0, a), mats["iron"])
        link_to(vent, base)
    for i in range(14):
        a = math.radians(12 + 360 * i / 14.0)
        greeble(base, mats, "DishBolt%d" % i, "bolt",
                (0.915 * math.cos(a), 0.915 * math.sin(a), TOP - 0.012), a, 0.85)
    return None


def build_amphitheater(base, mats):
    # ring of machinery around the pit: tall at the back, low at the front so
    # the glow stays readable -- the Quantum Stabilizer layout
    # tall units flank the rings; anything tall on the back midline lands
    # straight behind the crystal in this projection and kills its read
    silo(base, mats, "SiloBR", 0.28, 0.85, (1.18, 1.42, 1.18), mat_key="steel")
    # cryo condenser dressing: frosted fin plates on the visible south-west
    # arc (the north-east is where HoseBack lands) and two vapor ports on the
    # shoulder, so the rear-right stack reads as the cold end of the loop
    for i, deg in enumerate((145, 185, 225, 265)):
        fa = math.radians(deg)
        fin = cube("SiloBRFin%d" % i, (0.18, 0.035, 0.55),
                   (1.18 + 0.33 * math.cos(fa), 1.42 + 0.33 * math.sin(fa), 1.16),
                   (0, 0, fa), mats["frosty"])
        bevel(fin, width=0.01, segments=2)
        link_to(fin, base)
    for k, deg in enumerate((205, 255)):
        va = math.radians(deg)
        vx = 1.18 + 0.29 * math.cos(va)
        vy = 1.42 + 0.29 * math.sin(va)
        vent = cylinder("SiloBRVent%d" % k, 0.05, 0.16, (vx, vy, 1.55),
                        (math.radians(55), 0,
                         math.atan2(math.cos(va), -math.sin(va))),
                        mats["copper"], verts=10)
        smooth(vent)
        link_to(vent, base)
        mouth = sphere("SiloBRVentM%d" % k, 0.030,
                       (1.18 + 0.36 * math.cos(va), 1.42 + 0.36 * math.sin(va),
                        1.60), mats["socket_dark"], subdiv=1)
        link_to(mouth, base)
    # coolant skid where the induction coils used to sit -- the windings moved
    # onto the pylons, which is where a beacon's field is actually generated
    skid = cube("CanSkid", (0.86, 0.62, 0.08), (-1.14, 1.43, 0.83),
                material=mats["steel_dark"])
    bevel(skid, width=0.02, segments=2)
    link_to(skid, base)
    ammonia_reservoir(base, mats, "CanRes", (-1.16, 1.40, 0.87))
    tank_h(base, mats, "TankBack", 0.24, 1.1, (0, 1.58, 1.05), 0.0,
           mat_key="steel_dark")
    tank_h(base, mats, "TankR", 0.26, 0.85, (1.5, 0.70, 1.07), math.radians(90),
           mat_key="rusty")
    tank_h(base, mats, "TankL", 0.26, 0.85, (-1.5, 0.55, 1.07), math.radians(90),
           mat_key="steel")
    manifold(base, mats, "ManifoldL", (-1.5, -0.55, 1.03), math.radians(100))
    manifold(base, mats, "ManifoldR", (1.5, -0.55, 1.03), math.radians(80))
    # the front shelf keeps only low service hardware: the rusty silo that
    # crowded the console moved out, a knee-height fuel-cell bay moved in
    fuel_bay(base, mats, "FuelBay", (0.555, -1.48, 0.806), ang=math.radians(-5))

    # where the chamber hose lands, and a junction box beside it
    port = cylinder("FloorPort", 0.17, 0.09, (-0.62, -1.96, 0.82), material=mats["iron"])
    bevel(port, width=0.02, segments=2)
    smooth(port)
    link_to(port, base)
    for k in range(6):
        a = math.radians(60 * k)
        bolt = sphere("FloorPortBolt%d" % k, 0.022,
                      (-0.62 + 0.13 * math.cos(a), -1.96 + 0.13 * math.sin(a), 0.87),
                      mats["gunmetal"], subdiv=1)
        link_to(bolt, base)
    box = cube("Junction", (0.34, 0.26, 0.22), (0.98, -1.92, 0.90), (0, 0, math.radians(-6)),
               mats["holmium"])
    bevel(box, width=0.02, segments=2)
    link_to(box, base)
    # beacon lamp on the box top, in a socketed base -- the strip that used to
    # hover off the front face clipped both the box and the rim beam
    lamp_base = cylinder("JunctionLampBase", 0.045, 0.05, (0.97, -1.97, 1.035),
                         material=mats["gunmetal"], verts=12)
    bevel(lamp_base, width=0.01, segments=2)
    smooth(lamp_base)
    link_to(lamp_base, base)
    lamp = sphere("JunctionLamp", 0.030, (0.97, -1.97, 1.07),
                  mats["led_amber"], subdiv=1)
    link_to(lamp, base)

    # readouts on the machinery that has something to report
    gauge(base, mats, "ManGaugeL", (-1.46, -0.86, 1.21), ang=math.radians(-12))
    gauge(base, mats, "ManGaugeR", (1.60, -0.90, 1.20), ang=math.radians(12))

    # pipe and hose network tying it together
    hose_run(base, mats, "HoseBack", (1.50, 1.66, 1.12), (1.18, 1.42, 1.55),
             sag=0.14, lateral=0.16, rings=6, radius=0.068)
    pipe_run(base, mats, "PipeCanDish",
             [(-1.10, 1.38, 1.86), (-0.95, 1.05, 1.52), (-0.62, 0.62, 1.30)],
             0.06, mat_key="copper", flange_ts=(0.5,))
    pipe_run(base, mats, "PipeManPed",
             [(1.55, -0.66, 1.26), (1.34, -0.50, 1.28), (1.18, -0.34, 1.24)],
             0.055, mat_key="copper", flange_ts=(0.35, 0.9))
    # the rim pipe now terminates INTO the winch box at the rear-left pole
    # base instead of stopping in mid-deck
    pipe_run(base, mats, "PipeRimL",
             [(-1.86, -1.2, 0.98), (-1.86, -0.2, 0.98), (-1.86, 0.8, 0.98),
              (-1.86, 0.98, 0.88), (-1.87, 1.10, 0.80)],
             0.08, mat_key="rusty", flange_ts=(0.14, 0.36))
    hose_run(base, mats, "HoseFront", (1.52, -0.52, 1.18), (1.95, -1.10, 0.98),
             sag=0.13, lateral=0.20, rings=5, radius=0.062)
    bracket = cube("HoseBracket", (0.14, 0.16, 0.12), (1.97, -1.10, 0.92),
                   (0, 0, math.radians(-8)), mats["iron"])
    bevel(bracket, width=0.015, segments=2)
    link_to(bracket, base)

    # rear-left pole base: the service box the rim pipe feeds, hosed onward
    # to the reservoir skid so the corner joins the coolant loop
    wbox = cube("WinchBox", (0.20, 0.16, 0.22), (-1.88, 1.12, 0.855),
                (0, 0, math.radians(4)), mats["steel_dark"])
    bevel(wbox, width=0.018, segments=2)
    link_to(wbox, base)
    hose_run(base, mats, "WinchHose", (-1.80, 1.16, 0.94), (-1.42, 1.39, 0.96),
             sag=0.05, lateral=0.05, rings=3, radius=0.030, mat_key="hose")
    for k, (px, py, pz) in enumerate(((-1.80, 1.16, 0.94), (-1.42, 1.39, 0.96))):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.048, minor_radius=0.016,
                                         major_segments=14, minor_segments=6,
                                         location=(px, py, pz))
        gland = bpy.context.object
        gland.name = PREFIX + "WinchHoseGland%d" % k
        gland.data.materials.append(mats["iron"])
        smooth(gland)
        link_to(gland, base)

    # left flank tie: the tank feeds the manifold, entering at its rear stub
    pipe_run(base, mats, "PipeTankMan",
             [(-1.50, -0.10, 1.08), (-1.55, -0.25, 1.16), (-1.53, -0.39, 1.22)],
             0.042, mat_key="copper", flange_ts=(0.5,))

    # rear tie: the back tank drains into the condenser stack
    hose_run(base, mats, "HoseTB", (0.55, 1.55, 1.12), (0.94, 1.44, 1.02),
             sag=0.10, lateral=-0.08, rings=4, radius=0.045, mat_key="hose")
    for k, (px, py, pz) in enumerate(((0.55, 1.55, 1.12), (0.94, 1.44, 1.02))):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.065, minor_radius=0.02,
                                         major_segments=14, minor_segments=6,
                                         location=(px, py, pz))
        gland = bpy.context.object
        gland.name = PREFIX + "HoseTBGland%d" % k
        gland.data.materials.append(mats["iron"])
        smooth(gland)
        link_to(gland, base)

    # holmium superconductor bus: transformer to containment chamber
    bus_bar(base, mats, "BusBar", (1.44, -1.14, 0.929), (0.80, -0.79, 0.929))


# --------------------------------------------------------------------------
# moving parts

def build_crystal(moving, mats):
    root = bpy.data.objects.new(PREFIX + "Crystal", None)
    root.empty_display_size = 0.2
    root.location = (0, 0, 2.7)
    bpy.context.scene.collection.objects.link(root)
    link_to(root, moving)

    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.5, radius2=0.12, depth=0.75,
                                    location=(0, 0, 0))
    top = bpy.context.object
    top.name = PREFIX + "CrystalTop"
    top.data.materials.append(mats["crystal"])
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.5, radius2=0.08, depth=0.55,
                                    location=(0, 0, 0), rotation=(math.pi, 0, 0))
    bot = bpy.context.object
    bot.name = PREFIX + "CrystalBot"
    bot.data.materials.append(mats["crystal"])
    core = sphere("CrystalCore", 0.22, (0, 0, 0), mats["core"])
    # containment pinch at the waist, in the gap the core shows through
    bpy.ops.mesh.primitive_torus_add(major_radius=0.32, minor_radius=0.022,
                                     major_segments=40, minor_segments=8,
                                     location=(0, 0, 0))
    pinch = bpy.context.object
    pinch.name = PREFIX + "CrystalPinch"
    pinch.data.materials.append(mats["glow"])
    smooth(pinch)

    # The halves are held APART by the field, so the core is visible between
    # them. An emissive core sealed inside an opaque shell renders nothing --
    # the gap is the whole reason it reads as a contained plasma.
    for part, dz in ((top, 0.535), (bot, -0.435), (core, 0.0), (pinch, 0.0)):
        link_to(part, moving)
        part.parent = root
        part.location = (0, 0, dz)
    return root


def ring_with_pods(moving, mats, name, major, minor, tilt, pods, pod_size):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=64, minor_segments=16,
                                     location=(0, 0, 2.7))
    ring = bpy.context.object
    ring.name = PREFIX + name
    ring.data.materials.append(mats["ring"])
    # ZYX euler = spin about the ring's own (tilted) normal axis, so a partial
    # turn maps the ring onto itself and the loop is seamless
    ring.rotation_mode = "ZYX"
    ring.rotation_euler = (tilt, 0, 0)
    ring.scale = (1, 1, 0.7)  # flattened band reads more machined than a pipe
    smooth(ring)
    link_to(ring, moving)

    # thin glow seam embedded in the ring's top surface
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=0.02,
                                     major_segments=64, minor_segments=8,
                                     location=(0, 0, 0))
    seam = bpy.context.object
    seam.name = PREFIX + name + "Seam"
    seam.data.materials.append(mats["glow"])
    smooth(seam)
    link_to(seam, moving)
    seam.parent = ring
    seam.location = (0, 0, minor * 0.9)

    for i in range(pods):
        ang = 2 * math.pi * i / pods
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0,
                                              location=(major * math.cos(ang),
                                                        major * math.sin(ang), 0))
        pod = bpy.context.object
        pod.name = PREFIX + name + "Pod%d" % i
        pod.scale = pod_size
        pod.rotation_euler = (0, 0, ang)
        pod.data.materials.append(mats["holmium"])
        smooth(pod)
        link_to(pod, moving)
        pod.parent = ring

        # clamps flanking each pod: a smooth torus reads as a glass hoop, and
        # the ring has to read as machined hardware. Placing them relative to
        # the pods keeps the ring's n-fold symmetry, so the loop still closes.
        for k, sgn in enumerate((-1, 1)):
            ca = ang + sgn * 0.23
            clamp = cube("%sClamp%d%d" % (name, i, k),
                         (minor * 2.2, minor * 0.9, minor * 2.2),
                         (major * math.cos(ca), major * math.sin(ca), 0),
                         (0, 0, ca), mats["gunmetal"])
            bevel(clamp, width=0.012, segments=2)
            link_to(clamp, moving)
            clamp.parent = ring
    return ring


# --------------------------------------------------------------------------

def build_scene():
    clean()
    base = coll("Base")
    moving = coll("Moving")
    arcs = coll("Arcs")
    deck = coll("Deck")
    footprint = coll("Footprint")

    mats = build_materials()

    build_plinth(base, mats)
    props = build_deck(base, mats, deck)
    build_dish(base, mats)
    build_dish_plant(base, mats)
    build_amphitheater(base, mats)
    build_pylons(base, mats)
    build_sockets(base, mats)
    # Cabling LAST. The feeders route around whatever else is on the deck and
    # the deck survey is how they find out what that is, so every prop, tank
    # and manifold has to exist before they are laid.
    surfaces, runs = build_deck_cables(base, mats)
    build_prop_spurs(base, mats, runs, surfaces)
    props["runs"] = runs
    scatter_greebles(base, mats)

    crystal = build_crystal(moving, mats)
    ring_outer = ring_with_pods(moving, mats, "RingOuter", 1.5, 0.105, 0.0,
                                pods=4, pod_size=(0.17, 0.12, 0.1))
    ring_inner = ring_with_pods(moving, mats, "RingInner", 1.0, 0.085, math.radians(35),
                                pods=3, pod_size=(0.13, 0.1, 0.08))

    build_arcs(arcs, mats)
    build_socket_sprites(mats)

    bpy.ops.mesh.primitive_plane_add(size=5.0, location=(0, 0, 0.001))
    plane = bpy.context.object
    plane.name = PREFIX + "FootprintPlane"
    plane.data.materials.append(mats["footprint"])
    link_to(plane, footprint)

    bpy.context.view_layer.update()
    return {
        "base": base, "moving": moving, "arcs": arcs, "deck": deck,
        "footprint": footprint, "props": props,
        "ring_outer": ring_outer, "ring_inner": ring_inner, "crystal": crystal,
    }


# --------------------------------------------------------------------------
# animation

def bob_z(frame, frames=64):
    # one sine cycle per loop; +-3 source px = 3/64 world units
    return 2.7 + (3.0 / 64.0) * math.sin(2 * math.pi * frame / frames)


def animate(objs, frames=64):
    # Per-frame keys everywhere: no fcurve interpolation to fix up, and it
    # sidesteps the 4.4+ slotted-action API entirely. Frames 0..frames-1
    # render; frame `frames` equals frame 0 one step on, so the loop closes.
    scn = bpy.context.scene
    scn.frame_start = 0
    scn.frame_end = frames - 1
    outer, inner, crystal = objs["ring_outer"], objs["ring_inner"], objs["crystal"]
    tilt = inner.rotation_euler.x
    for f in range(frames + 1):
        t = f / frames
        outer.rotation_euler = (0, 0, math.radians(90) * t)       # 4-fold symmetry
        inner.rotation_euler = (tilt, 0, math.radians(-120) * t)  # 3-fold symmetry
        crystal.location = (0, 0, bob_z(f, frames))
        crystal.rotation_euler = (0, 0, math.radians(60) * t)     # 6-fold facets
        for obj in (outer, inner, crystal):
            obj.keyframe_insert("rotation_euler", frame=f)
        crystal.keyframe_insert("location", frame=f)
    animate_deck(objs["props"], frames)


def _path_at(pts, t):
    f = max(0.0, min(t, 1.0)) * (len(pts) - 1)
    i = min(int(f), len(pts) - 2)
    return Vector(pts[i]).lerp(Vector(pts[i + 1]), f - i)


def _key_value(node, value, frame):
    node.outputs[0].default_value = value
    node.outputs[0].keyframe_insert("default_value", frame=frame)


def animate_deck(props, frames=64):
    # The deck plant runs its own loop at the same length and speed as the
    # rings. Nothing here is keyed off the ring pose -- Factorio draws each
    # animation_list element independently -- but matching 64 frames at
    # animation_speed 0.5 keeps the two compatible, and lets the cable pulses
    # land on the discharge schedule instead of drifting against it.
    holo = bpy.data.materials[PREFIX + "holo_glyph"].node_tree.nodes
    scan_t, flicker = holo["HoloScanT"], holo["HoloFlicker"]
    shard_mat = bpy.data.materials[PREFIX + "shard_core"]
    shard_em = shard_mat.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"]
    mouth = Vector(props["vent_mouth"])

    # which frames a feeder is carrying a charge, from the discharge schedule
    windows = {tag: [(s - PULSE_LEN) % frames for p, s in _beats() if p == pylon]
               for tag, pylon in PULSE_FEEDERS.items()}

    for f in range(frames + 1):
        t = (f % frames) / frames

        # hologram: band sweeps and wraps; flicker at 3 whole cycles per loop
        _key_value(scan_t, t, f)
        _key_value(flicker, 0.90 + 0.10 * math.sin(2 * math.pi * 3 * t), f)

        # cryo vapour: staggered puffs, each rising, spreading and thinning
        for k, puff in enumerate(props["puffs"]):
            ph = ((f % frames) / frames + k / len(props["puffs"])) % 1.0
            puff.location = (mouth.x + 0.045 * math.sin(6.0 * ph + k),
                             mouth.y - 0.02 * ph,
                             mouth.z + 0.02 + 0.43 * ph)
            s = 0.34 + 1.15 * ph
            puff.scale = (s, s, s * 0.86)
            puff.keyframe_insert("location", frame=f)
            puff.keyframe_insert("scale", frame=f)
            fade = puff.data.materials[0].node_tree.nodes["VaporFade"]
            # zero at both ends, so the loop closes with nothing on screen
            _key_value(fade, math.sin(math.pi * ph) ** 0.7, f)

        # cable pulses: a charge runs out the feeder and arrives as its
        # electrode starts to climb
        for tag, bead in props["beads"].items():
            pts = props["runs"][tag][0]
            live = None
            for start in windows[tag]:
                d = (f - start) % frames
                if d <= PULSE_LEN:
                    live = d / PULSE_LEN
                    break
            if live is None:
                bead.scale = (0.0, 0.0, 0.0)
            else:
                u = PULSE_T0 + (PULSE_T1 - PULSE_T0) * live
                p = _path_at(pts, u)
                ahead = _path_at(pts, min(u + 0.02, 1.0))
                bead.location = (p.x, p.y, p.z + 0.010)
                bead.rotation_euler = (0, 0, math.atan2(ahead.y - p.y, ahead.x - p.x))
                s = math.sin(math.pi * live) ** 0.6
                bead.scale = (s * 2.1, s * 0.9, s * 0.9)
                bead.keyframe_insert("location", frame=f)
                bead.keyframe_insert("rotation_euler", frame=f)
            bead.keyframe_insert("scale", frame=f)

        # the shard breathes with the core: two cycles a loop, shallow
        core = props["shard_core"]
        s = 1.0 + 0.10 * math.sin(2 * math.pi * 2 * t)
        core.scale = (s, s, s)
        core.keyframe_insert("scale", frame=f)
        shard_em.default_value = 0.42 * (0.78 + 0.22 * math.sin(2 * math.pi * 2 * t))
        shard_em.keyframe_insert("default_value", frame=f)


def _beats():
    # (pylon, start frame) for every beat in the loop
    return [(p, start) for start, pylons in ARC_BEATS for p in pylons]


def climb_at(pylon, frame):
    # 0..1 progress of the charge climbing this pylon, or None
    for p, start in _beats():
        if p == pylon and start <= frame < start + CLIMB_FRAMES:
            return (frame - start + 1) / CLIMB_FRAMES
    return None


def arc_at(pylon, frame):
    # 0..1 progress through this pylon's discharge, or None
    for p, start in _beats():
        fire = start + CLIMB_FRAMES
        if p == pylon and fire <= frame < fire + ARC_FRAMES:
            return (frame - fire) / (ARC_FRAMES - 1)
    return None


def pylon_radius(t):
    # Matches the taper object in build_pylons: full width at the foot, half
    # at the tip. Shared, so the windings and the climbing bolt sit on the
    # same surface rather than on two guesses at it.
    return PYLON_R0 * (1.0 - 0.5 * t)


def build_socket_sprites(mats):
    # Sprite parts for module_visualisations, rendered through the same
    # camera so the perspective matches the base. One reference socket at
    # SOCKET_POSITIONS[1]; the prototype reuses it per slot with shifted x.
    ref_x, ref_y = SOCKET_POSITIONS[1]
    boxm = coll("SlotBox")
    lights = coll("SlotLights")

    # The tinted layers must be SHADED greyscale, never flat white. The game
    # multiplies the module's beacon_tint over them, so a flat sprite can only
    # produce a flat patch of colour -- which is why an inserted module read as
    # a pastel rectangle pasted into a hole. Vanilla's masks span roughly
    # 26-255 with a mid mean; these render neutral and let the light do it.
    shell = plain("mask_shell", (0.62, 0.62, 0.62), metallic=0.2, rough=0.42)
    lens = plain("mask_lens", (0.80, 0.80, 0.80), metallic=0.0, rough=0.22)

    # No empty-slot sprite at all: the base already draws the whole port, and
    # re-drawing it here painted over 13 rows of the lip above each socket.
    # the module cartridge itself (tinted "primary"): fills the cavity so no
    # dark rim shows around it, with a proud face plate, a grip lip and side
    # rails -- the bevels and their occlusion are what give the tint form
    body = cube("SlotModule", (0.48, 0.13, 0.325), (ref_x, ref_y - 0.155, 0.40),
                material=shell)
    bevel(body, width=0.022, segments=2)
    link_to(body, boxm)
    face = cube("SlotModuleFace", (0.40, 0.035, 0.245), (ref_x, ref_y - 0.225, 0.395),
                material=shell)
    bevel(face, width=0.014, segments=2)
    link_to(face, boxm)
    lip = cube("SlotModuleLip", (0.45, 0.075, 0.045), (ref_x, ref_y - 0.20, 0.545),
               material=shell)
    bevel(lip, width=0.012, segments=2)
    link_to(lip, boxm)
    for i, sx in enumerate((-1, 1)):
        fin = cube("SlotModuleFin%d" % i, (0.035, 0.10, 0.26),
                   (ref_x + sx * 0.225, ref_y - 0.185, 0.385), material=shell)
        bevel(fin, width=0.01, segments=2)
        link_to(fin, boxm)

    # indicator lenses on the cartridge face (tinted "secondary"): capsules
    # rather than flat bars, so they catch a highlight and read as glass
    for i, z in enumerate((0.465, 0.345)):
        capsule = cylinder("SlotLight%d" % i, 0.026, 0.30,
                           (ref_x, ref_y - 0.245, z), (0, math.radians(90), 0),
                           lens, verts=14)
        smooth(capsule)
        link_to(capsule, lights)


# --------------------------------------------------------------------------
# discharge: climbing bolts, tip flashes, tip -> core arcs, sparks
#
# Nothing in the PB_Arcs collection is keyframed. update_arcs() rewrites the
# whole collection for one frame and the render driver calls it per frame,
# which is what lets an arc be re-jittered rather than interpolated -- a
# discharge tweened between two poses reads as a wobbling wire.

SPARK_LIFE = 5

_SPARK_EVENTS = []
_MOTES = []
_SPARK_POOL = 0


def _tangent_frame(ctrl, t):
    # Basis on the pylon surface at t: front faces the camera, side runs
    # around the pipe. Both are perpendicular to the curve.
    tan = bezier_tan(ctrl, t)
    front = VIEW_DIR - tan * VIEW_DIR.dot(tan)
    if front.length < 1e-4:
        front = Vector((0, -1, 0))
    front.normalize()
    return tan, front, tan.cross(front).normalized()


def _climb_points(ctrl, head_t, anchor, phase, rng, n=11):
    # A comet of current hugging the electrode. The swing stays inside 43
    # degrees either side of the camera-facing line, so the bolt never rounds
    # the pipe into the half of it the sprite cannot show.
    #
    # The last stretch converges on `anchor`, the tip electrode: t=1 is only
    # the top of the pipe, so a bolt left on the pipe surface parks short of
    # the tip and the head reads as a second blob beside the flash.
    tail_t = max(CLIMB_T0, head_t - 0.28)
    pts = []
    for k in range(n):
        u = k / (n - 1)
        t = tail_t + (head_t - tail_t) * u
        _, front, side = _tangent_frame(ctrl, t)
        swing = 0.75 * math.sin(2 * math.pi * 1.7 * t + phase)
        r = pylon_radius(t) + 0.045
        j = 0.024 * (1 - abs(2 * u - 1))  # jitter pinched at both ends
        p = (bezier_pt(ctrl, t)
             + (front * math.cos(swing) + side * math.sin(swing)) * r
             + side * rng.uniform(-j, j) + front * rng.uniform(-j, j))
        if t > 0.84:
            p = p.lerp(anchor, min(1.0, (t - 0.84) / 0.16))
        pts.append(p)
    return pts


def _arc_points(start, target, rng, n=13, amp=0.11):
    axis = (target - start).normalized()
    side = axis.cross(Vector((0, 0, 1)))
    if side.length < 0.1:
        side = Vector((1, 0, 0))
    side.normalize()
    up = axis.cross(side)
    pts = []
    for k in range(n):
        t = k / (n - 1)
        p = start.lerp(target, t)
        a = amp * math.sin(math.pi * t)  # pinned at both ends
        pts.append(p + side * rng.uniform(-a, a) + up * rng.uniform(-a, a))
    return pts


def _fork(pts, rng):
    # A short branch dying in mid-air. Real discharges fork, and one extra
    # spline is most of what separates an arc from a drawn line.
    i = rng.randrange(3, len(pts) - 3)
    o = pts[i]
    along = (pts[i + 1] - pts[i - 1]).normalized()
    perp = along.cross(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1),
                               rng.uniform(-1, 1))))
    if perp.length < 1e-3:
        perp = Vector((1, 0, 0))
    perp.normalize()
    step = along * 0.10 + perp * 0.11
    out, radii = [o], [0.8]
    for k in range(1, 5):
        out.append(o + step * k + perp * rng.uniform(-0.03, 0.03))
        radii.append(0.8 * (1 - k / 4.5))
    return out, radii


def _add_spline(curve, pts, radii):
    spl = curve.splines.new("POLY")
    spl.points.add(len(pts) - 1)
    for k, p in enumerate(pts):
        spl.points[k].co = (p.x, p.y, p.z, 1)
        spl.points[k].radius = radii[k]


def _flash_scale(pylon, frame):
    # The tip swells as the charge arrives and decays through the discharge.
    c = climb_at(pylon, frame)
    if c is not None:
        return 0.30 + 1.15 * c ** 3
    a = arc_at(pylon, frame)
    if a is not None:
        return 1.45 * (1.0 - a) ** 1.5
    return 0.0


def _build_spark_events(frames=64):
    # Emission schedule for the whole loop, computed once. Ages wrap, so a
    # spark born at frame 62 is still alive at frame 2 and the loop closes.
    # Depends on TIP_POSITIONS, so it runs after build_pylons.
    global _SPARK_EVENTS, _MOTES
    _SPARK_EVENTS = []
    core = Vector((0, 0, 2.55))
    for p, start in _beats():
        tip = TIP_POSITIONS[p]
        rng = random.Random(4093 + p * 131 + start)
        # thrown off the electrode as the charge lands on it
        for _ in range(3):
            vel = Vector((rng.uniform(-0.045, 0.045), rng.uniform(-0.045, 0.045),
                          rng.uniform(0.015, 0.065)))
            _SPARK_EVENTS.append(((start + CLIMB_FRAMES - 1) % frames, tip.copy(),
                                  vel, SPARK_LIFE, rng.uniform(0.024, 0.038)))
        # shed off the discharge itself, part-way along its path
        for _ in range(2):
            f = (start + CLIMB_FRAMES + rng.randrange(0, ARC_FRAMES - 1)) % frames
            vel = Vector((rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05),
                          rng.uniform(-0.02, 0.05)))
            _SPARK_EVENTS.append((f, tip.lerp(core, rng.uniform(0.2, 0.8)), vel,
                                  SPARK_LIFE - 1, rng.uniform(0.020, 0.030)))

    # Motes adrift in the containment volume, lit the whole time the beacon
    # works. Turn and bob counts are integers so the loop closes on itself.
    _MOTES = []
    for k in range(5):
        rng = random.Random(9001 + k)
        _MOTES.append((rng.uniform(0.55, 1.30),          # orbit radius
                       rng.uniform(2.15, 3.15),          # height
                       rng.choice((-2, -1, 1, 2)),       # turns per loop
                       rng.uniform(0, 2 * math.pi),      # phase
                       rng.uniform(0.06, 0.16),          # bob
                       rng.uniform(0.019, 0.030)))       # radius


def sparks_at(frame, frames=64):
    out = []
    for emit, origin, vel, life, r0 in _SPARK_EVENTS:
        age = (frame - emit) % frames
        if age >= life:
            continue
        p = origin + vel * age - Vector((0, 0, 0.004 * age * age))
        out.append((p, r0 * (1.0 - 0.7 * age / life)))
    t = frame / frames
    for r, z0, turns, phase, bob, rad in _MOTES:
        a = phase + 2 * math.pi * turns * t
        out.append((Vector((r * math.cos(a), r * math.sin(a),
                            z0 + bob * math.sin(2 * math.pi * 2 * t + phase))),
                    rad * (0.7 + 0.3 * math.sin(2 * math.pi * 3 * t + 2 * phase))))
    return out


def build_arcs(arcs_coll, mats):
    global _SPARK_POOL
    arc_mat = mats["arc"]
    for i in range(4):
        for kind, depth in (("Arc", 0.030), ("Climb", 0.032)):
            curve = bpy.data.curves.new(PREFIX + "%sC%d" % (kind, i), "CURVE")
            curve.dimensions = "3D"
            curve.bevel_depth = depth
            curve.bevel_resolution = 2
            obj = bpy.data.objects.new(PREFIX + "%s%d" % (kind, i), curve)
            obj.data.materials.append(arc_mat)
            obj.hide_render = True
            bpy.context.scene.collection.objects.link(obj)
            link_to(obj, arcs_coll)
        for kind, r in (("TipFlash", 0.055), ("ClimbHead", 0.034)):
            ball = sphere("%s%d" % (kind, i), r, TIP_POSITIONS[i], arc_mat)
            smooth(ball)
            ball.hide_render = True
            link_to(ball, arcs_coll)

    # Sparks are one unit-radius sphere each, scaled per frame -- sizing the
    # pool off the busiest frame keeps the object count honest.
    _build_spark_events()
    _SPARK_POOL = max(len(sparks_at(f)) for f in range(64))
    for k in range(_SPARK_POOL):
        s = sphere("Spark%d" % k, 1.0, (0, 0, 0), mats["spark"], subdiv=1)
        s.hide_render = True
        link_to(s, arcs_coll)


def update_arcs(frame, frames=64):
    # Rebuild the discharge for one frame with deterministic per-frame jitter
    # (no wall-clock randomness -- the same frame always renders the same).
    core = Vector((0, 0, bob_z(frame, frames) - 0.25))
    for i in range(4):
        ctrl = PYLON_CURVES[i]
        rng = random.Random(frame * 7919 + i * 131)
        climb, fire = climb_at(i, frame), arc_at(i, frame)

        bolt = bpy.data.objects[PREFIX + "Climb%d" % i]
        head = bpy.data.objects[PREFIX + "ClimbHead%d" % i]
        bolt.hide_render = head.hide_render = climb is None
        if climb is not None:
            pts = _climb_points(ctrl, CLIMB_T0 + (1.0 - CLIMB_T0) * climb,
                                TIP_POSITIONS[i], i * 1.9, rng)
            bolt.data.splines.clear()
            # thin tail, fat head: the comet is what reads as travel. The tail
            # keeps a third of the width -- taper it away entirely and only the
            # head survives the downscale, which reads as a bead, not a bolt.
            _add_spline(bolt.data, pts,
                        [0.45 + 0.55 * (k / (len(pts) - 1)) ** 2
                         for k in range(len(pts))])
            head.location = pts[-1]
            hs = 0.7 + 0.5 * climb
            head.scale = (hs, hs, hs)

        arc = bpy.data.objects[PREFIX + "Arc%d" % i]
        arc.hide_render = fire is None
        if fire is not None:
            # strike hard, thin out as it dies
            arc.data.bevel_depth = 0.017 + 0.017 * math.sin(
                math.pi * (0.14 + 0.86 * fire))
            arc.data.splines.clear()
            pts = _arc_points(TIP_POSITIONS[i], core, rng)
            _add_spline(arc.data, pts, [1.0] * len(pts))
            if rng.random() < 0.65:
                _add_spline(arc.data, *_fork(pts, rng))

        flash = bpy.data.objects[PREFIX + "TipFlash%d" % i]
        s = _flash_scale(i, frame)
        flash.hide_render = s < 0.05
        flash.location = TIP_POSITIONS[i]
        flash.scale = (s, s, s)

    live = sparks_at(frame, frames)
    for k, (p, r) in enumerate(live):
        spark = bpy.data.objects[PREFIX + "Spark%d" % k]
        spark.hide_render = False
        spark.location = p
        spark.scale = (r, r, r)
    for k in range(len(live), _SPARK_POOL):
        bpy.data.objects[PREFIX + "Spark%d" % k].hide_render = True
