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

# Arc burst schedule over the 64-frame loop: {arc index: frame range}.
# Two opposite pylons fire, then the other two, then all four.
ARC_BURSTS = [
    (range(4, 10), (0, 3)),
    (range(26, 34), (1, 2)),
    (range(50, 56), (0, 1, 2, 3)),
]

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
BARE = (0.34, 0.35, 0.37)


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

    def noise_node(scale, detail=6.0):
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
        rust_noise = noise_node(noise_scale * 0.6, detail=8.0)
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
    val_map = map_range((0.85, 1.15))
    nt.links.new(obj_info.outputs["Random"], val_map.inputs["Value"])
    jitter = nt.nodes.new("ShaderNodeHueSaturation")
    nt.links.new(hue_map.outputs["Result"], jitter.inputs["Hue"])
    nt.links.new(val_map.outputs["Result"], jitter.inputs["Value"])
    nt.links.new(color_out, jitter.inputs["Color"])
    color_out = jitter.outputs["Color"]

    # edge wear: convex edges chip to bare metal, patchy via fine noise
    edge = map_range((0.0, 1.0), fr=(0.53, 0.62))
    nt.links.new(geo.outputs["Pointiness"], edge.inputs["Value"])
    wear_noise = noise_node(noise_scale * 2.4)
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
        sc_noise = noise_node(noise_scale * 6.0, detail=2.0)
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
    facet.inputs["A"].default_value = (*PLASMA_DEEP, 1)
    facet.inputs["B"].default_value = (*PLASMA_LIT, 1)
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
    rim_col.inputs["A"].default_value = (*PLASMA_DEEP, 1)
    rim_col.inputs["B"].default_value = (*PLASMA_HOT, 1)
    nt.links.new(lw.outputs["Facing"], rim_col.inputs["Factor"])
    nt.links.new(rim_col.outputs["Result"], bsdf.inputs["Emission Color"])
    rim_str = nt.nodes.new("ShaderNodeMapRange")
    rim_str.inputs["To Min"].default_value = 0.22
    rim_str.inputs["To Max"].default_value = 0.9
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
PAINT_A, PAINT_B = (0.135, 0.185, 0.19), (0.055, 0.085, 0.09)
DARK_A, DARK_B = (0.095, 0.105, 0.115), (0.065, 0.075, 0.085)
HOLM_A, HOLM_B = (0.30, 0.345, 0.40), (0.20, 0.235, 0.29)


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
    up = map_range((0.0, 1.0), fr=(0.48, 0.86))
    nt.links.new(nrm.outputs["Z"], up.inputs["Value"])
    edge = map_range((0.0, 0.30), fr=(0.555, 0.615))
    nt.links.new(geo.outputs["Pointiness"], edge.inputs["Value"])

    # drifted, not painted on: the noise is what leaves bare metal showing
    # through, and a uniform coat is the tell that reads as a white blob
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 7.0
    noise.inputs["Detail"].default_value = 4.0
    nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
    patch = map_range((0.0, 1.0), fr=(0.44, 0.62))
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
    ao.samples = 8
    # Two separate curves off the same AO, because colour and coverage do not
    # want the same one. Driving both from one made the recesses bare instead
    # of icy: snow does reach a crevice, it just packs down grey there rather
    # than staying white.
    open_sky = map_range((0.0, 1.0), fr=(0.50, 0.95))       # tone: tight
    nt.links.new(ao.outputs["AO"], open_sky.inputs["Value"])
    sheltered = map_range((0.32, 1.0), fr=(0.30, 0.80))     # amount: floored
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
    crisp = map_range((0.0, 1.0), fr=(0.34, 0.46))
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
        "gunmetal": worn_metal("gunmetal", (0.065, 0.072, 0.082), (0.045, 0.05, 0.058),
                               metallic=0.42, rough_lo=0.4, rough_hi=0.55,
                               wear=0.45, rust=0.15, frost=0.12, grain=0.12),
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
        "iron": worn_metal("cast_iron", (0.028, 0.028, 0.032), (0.018, 0.018, 0.022),
                           metallic=0.35, rough_lo=0.5, rough_hi=0.7,
                           wear=0.35, rust=0.2, frost=0.14),
        # copper piping, worn and part-patinated
        "copper": worn_metal("copper_pipe", (0.3, 0.11, 0.05), (0.16, 0.06, 0.03),
                             metallic=0.7, rough_lo=0.35, rough_hi=0.55,
                             wear=0.25, rust=0.3, noise_scale=6.0, frost=0.07),
        # containment coil bodies: worn metal that also carries the field
        "ring": add_energy_sheen(
            worn_metal("coil_ring", (0.055, 0.062, 0.075), (0.038, 0.042, 0.052),
                       metallic=0.28, rough_lo=0.5, rough_hi=0.68,
                       wear=0.4, rust=0.1, frost=0.10),
            color=ARC_OUTER, strength=0.22),
        "hose": rubber("hose_rubber"),
        "cable": rubber("cable_rubber", (0.021, 0.020, 0.019)),
        "crystal": crystal_quantum(),
        "core": plain("crystal_core", PLASMA_HOT, metallic=0.0, rough=0.3,
                      emission=PLASMA_HOT, strength=1.35),
        # emission stays ~1: Standard clips hard and the blue blows to white
        # anywhere above (the hue is the point, not the brightness). Fresnel
        # makes the tips flare at their rim without raising the number.
        "glow": add_energy_sheen(
            plain("glow_plasma", (0.06, 0.12, 0.18), metallic=0.0, rough=0.35),
            color=ARC_OUTER, strength=1.05),
        # the containment well under the core: bright enough to bounce onto
        # the surrounding machinery, dim enough to stay blue instead of white
        "glow_hot": plain("glow_hot", (0.10, 0.24, 0.36), metallic=0.0, rough=0.3,
                          emission=PLASMA_LIT, strength=1.2),
        "arc": arc_plasma(),
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
        "vent_glow": plain("vent_glow", (0.04, 0.09, 0.12), metallic=0.0,
                           rough=0.6, emission=ARC_OUTER, strength=0.34),
        "radiator": plain("radiator_hot", (0.10, 0.045, 0.02), metallic=0.1, rough=0.5,
                          emission=COOLANT_HOT, strength=0.95),
        "led_green": emission_only("led_green", LED_GREEN, 1.0),
        "led_amber": emission_only("led_amber", LED_AMBER, 1.0),
        "led_cyan": emission_only("led_cyan", ARC_OUTER, 1.0),
        "dial": plain("dial_face", (0.34, 0.33, 0.29), metallic=0.0, rough=0.55),
        "socket_dark": plain("socket_dark", (0.012, 0.014, 0.016), metallic=0.2, rough=0.75),
        "footprint": emission_only("footprint_white", (1, 1, 1), 1.0),
    }


# --------------------------------------------------------------------------
# equipment helpers -- the vocabulary the amphitheater is assembled from

def pipe_run(base, mats, name, pts, radius, mat_key="copper", flange_ts=(), rings=0):
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
        fl.data.materials.append(mats["iron"])
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


def build_deck(base, mats):
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

    # rim beams framing the deck
    for i, (sx, sy, sz) in enumerate([(4.7, 0.34, 0.22), (0.34, 4.7, 0.22)]):
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
    dish = cylinder("Dish", 0.95, 0.2, (0, 0, 1.32), material=mats["gunmetal"])
    bevel(dish, width=0.04)
    smooth(dish)
    link_to(dish, base)
    # Containment well, not a lit disc: the glow is recessed under a lipped
    # ring and crossed by aperture bars, so the light reads as coming out of
    # a shaft. A flush emissive circle at this size just looks like a sticker.
    dish_glow = cylinder("DishGlow", 0.64, 0.06, (0, 0, 1.33), material=mats["glow_hot"])
    smooth(dish_glow)
    link_to(dish_glow, base)
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
    for i in range(4):
        bar = cube("DishBar%d" % i, (0.085, 1.34, 0.05), (0, 0, 1.39),
                   (0, 0, math.radians(22.5 + 45 * i)), mats["gunmetal"])
        bevel(bar, width=0.015, segments=2)
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
        def pipe_radius(t, r0=curve.bevel_depth):
            # matches the taper object above: full width at the foot, half at the tip
            return r0 * (1.0 - 0.5 * t)

        helix_on_bezier(base, mats, "PylonCoil%d" % i, ctrl, 0.05, 0.34,
                        turns=4.5, wire=0.036, radius_at=pipe_radius)
        helix_on_bezier(base, mats, "PylonTipCoil%d" % i, ctrl, 0.70, 0.83,
                        turns=3.0, wire=0.024, radius_at=pipe_radius, phase=0.6)
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
    footprint = coll("Footprint")

    mats = build_materials()

    build_plinth(base, mats)
    build_deck(base, mats)
    build_dish(base, mats)
    build_amphitheater(base, mats)
    build_pylons(base, mats)
    build_sockets(base, mats)
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
        "base": base, "moving": moving, "arcs": arcs, "footprint": footprint,
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


def arc_frame_arcs(frame):
    for frames_range, arc_ids in ARC_BURSTS:
        if frame in frames_range:
            return arc_ids
    return ()


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


def build_arcs(arcs_coll, mats):
    arc_mat = mats["arc"]
    for i in range(4):
        curve = bpy.data.curves.new(PREFIX + "ArcC%d" % i, "CURVE")
        curve.dimensions = "3D"
        curve.bevel_depth = 0.030
        curve.bevel_resolution = 2
        obj = bpy.data.objects.new(PREFIX + "Arc%d" % i, curve)
        obj.data.materials.append(arc_mat)
        obj.hide_render = True
        bpy.context.scene.collection.objects.link(obj)
        link_to(obj, arcs_coll)


def update_arcs(frame, frames=64):
    # Rebuild each visible arc's polyline with deterministic per-frame jitter
    # (no wall-clock randomness -- the same frame always renders the same).
    live = arc_frame_arcs(frame)
    target = Vector((0, 0, bob_z(frame, frames) - 0.25))
    for i in range(4):
        obj = bpy.data.objects.get(PREFIX + "Arc%d" % i)
        obj.hide_render = i not in live
        if i not in live:
            continue
        start = TIP_POSITIONS[i]
        rng = random.Random(frame * 7919 + i * 131)
        curve = obj.data
        curve.splines.clear()
        spl = curve.splines.new("POLY")
        n = 9
        spl.points.add(n - 1)
        axis = (target - start).normalized()
        side = axis.cross(Vector((0, 0, 1)))
        if side.length < 0.1:
            side = Vector((1, 0, 0))
        side.normalize()
        up = axis.cross(side)
        for k in range(n):
            t = k / (n - 1)
            p = start.lerp(target, t)
            amp = 0.10 * math.sin(math.pi * t)  # pinned at both ends
            p += side * rng.uniform(-amp, amp) + up * rng.uniform(-amp, amp)
            spl.points[k].co = (p.x, p.y, p.z, 1)
