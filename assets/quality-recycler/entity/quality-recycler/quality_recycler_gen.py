# Scene generator for the Quality Recycler. Built from bmesh primitives, so
# the whole model rebuilds deterministically and is idempotent: it deletes its
# own QR_* objects and rebuilds. 1 Blender unit = 1 Factorio tile.
#
# The design is .ai-support/quality-recycler-design.md; the repo owner's
# concept sheet is .ai-support/prototype.png. Where the two disagree, the
# reasons are recorded next to the constant that settles it -- there are three,
# and all three are measurements rather than taste.
#
# Run:  blender -b -P quality_recycler_gen.py -- <out_dir>

import math
import os
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

PREFIX = "QR_"
FOOTPRINT = (3, 3)
CANVAS = (320, 384)                 # ortho_scale 5.0 -> 64 px/tile
REPO_ROOT = Path(__file__).resolve().parents[4]
POLYHAVEN_DIR = REPO_ROOT / "assets" / "third-party" / "polyhaven"


def _skill_scripts(start=None):
    import os
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
from factorio_render import rig, parts, greeble          # noqa: E402


# --------------------------------------------------------------------------
# The three places this model departs from one of its two sources, and why.
#
# 1. HEIGHT. The design says "rotor tower ... roughly 2.5 tiles" at the north
#    -east. Screen row is -(y + z), so a 2.5-tile mass at y = +0.6 draws 1.6
#    tiles past the footprint and covers the machine behind it. Measured off
#    the shipped 2.1 sprites: chemical plant overhangs 0.77 tiles north,
#    biochamber ~0.1, vanilla recycler 0.58. APEX is that band, not the doc's
#    number, and the height the design wanted is bought back by the exhaust
#    stack instead -- a tall part in the SOUTH costs nothing, because its y is
#    negative by as much as its z is positive.
#
# 2. PALETTE. The design's second zone is "verdigris bronze ~168 deg" and it
#    flags the two-greens risk in the same paragraph. The concept sheet solves
#    it by not having a second green: it promotes the design's own heat-tint
#    WEAR signature to be the new half's COLOUR -- tempered purple and blue
#    over bronze. Same physical story, one less risk, and the sheet's purple
#    chip measures hue 290 against the design's violet 286, so the accent the
#    design chose survives intact.
#
# 3. DRUM AXIS. The concept draws the rotor's bands wrapping an east-west
#    barrel. A disc on the transverse (X) axis is exactly edge-on to this
#    camera and renders as a stripe. The drum runs north-south (Y) instead,
#    which presents its face to the camera, is where an eddy-current
#    separator's drum actually sits relative to west-to-east material flow,
#    and gives the copper pole faces somewhere to be seen.
# 0.77 tiles of overhang in the worst direction -- the chemical plant's north,
# which is the largest any rotatable vanilla machine draws past its own tiles.
#
# **Measure OPAQUE PIXELS, not the declared sprite box.** Read off the sidecars
# alone the vanilla recycler appears to overhang 0.58/0.86/0.22/0.59 and this
# was briefly set to 2.32 on the strength of that 0.86. Its east sheet carries
# 0.17 tiles of transparent padding at the top: the opaque figures are
# 0.58/0.69/0.06/0.59, and the chemical plant's 0.77/0.61/0.38/0.30 (its
# padding is under a pixel). So vanilla's real ceiling is 0.77, and the sprite
# box overstates it by however much the packer left on.
#
# The cone is NOT what flattens a machine, which is the mistake this constant
# was blamed for. At the footprint edge it allows `APEX - 1.30` = 0.97 tiles of
# wall; the first build spent that by putting its south wall OUTSIDE the
# footprint at y -1.58, where only 0.69 is available, and shipped a 29 px front
# elevation. Inside the footprint the same APEX gives 55 px.
# 2.25 rather than the 2.27 the arithmetic alone allows: measured on the packed
# sheets, a fitted 2.27 lands the SOUTH view at 0.781 -- a hair over the ceiling,
# because the cone bounds vertices and the gate counts antialiased pixels. 2.25
# puts every one of the eight directions under 0.77 with room to spare.
APEX = 2.25


# Lighting. The rig's validated set is key 5.2 / fill 1.2 / ambient 0.22,
# approved in game on the Pure beacon; these deviate and the reason is
# measured. That set left this machine's RAW render at luminance sd 26.5
# against vanilla's post-processed 43-52, and simply darkening the palette
# moved the mean without widening the spread -- an absolute sd needs bright
# highlights as much as dark crevices. A harder key with less sky fill widens
# the range in the render, which is where contrast belongs; the paint-over
# should sharpen what is there, not invent it. Overridable so the sweep that
# picked them is repeatable.
KEY = float(os.environ.get("QR_KEY", "6.6"))
FILL = float(os.environ.get("QR_FILL", "0.95"))
# 0.12, not 0.15: the olive hull's 10th-percentile luminance sat at 38 against
# the concept render's 11, and a shadow that never gets dark is sky fill, not
# palette. Lowering it deepens the crevices in the RENDER, which is where
# contrast belongs -- the paint-over sharpens what is there, it cannot dig.
AMBIENT = float(os.environ.get("QR_AMBIENT", "0.12"))
DECK = 0.12                         # top of the pad, everything stands on it


def srgb(hex_str):
    h = hex_str.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


# Sampled, not picked. The olive is the concept sheet's own chip (#6E6E41,
# hue 60 sat 0.41) pulled toward the vanilla recycler's body (#735F47, hue 33)
# so the salvaged half reads as the machine the player already owns. The
# tempered tones are sampled off the concept render, which sits far below its
# own chips -- a chip at sat 0.48 painted over a whole half is a toy.
# The DARK end of each pair was pulled down after the first look-dev pass: the
# raw render measured luminance sd 26.5 where the Pure beacon's measured 31.6
# and vanilla's own sprites sit at 43-52 after their paint-over. A flat render
# forces the paint-over to invent the contrast, and an unsharp-driven sd is not
# the same thing as a machine with dark crevices. Widening the mottle pairs is
# the cheapest honest way to put it back in the render.
# Sampled off the concept sheet's hero render, not off its chips. The render's
# olive measures mean #584D33 at luminance 78 with a 10th percentile of 11;
# the first build's measured #71653F at 101 with a p10 of 38 -- 29% too bright
# and, more damaging, with no dark end at all, which is what made a painted
# steel block read as a flat card. The chip (#6F6F42) is not the target: a chip
# is a flat swatch and a hull is a lit surface.
#
# The base is warmer than the render it has to produce -- grime and the key
# shift hue about 10 degrees toward yellow-green on the way through, so a base
# at hue 51 lands near the concept's 43.
OLIVE_LIT = srgb("#605932")
OLIVE_DARK = srgb("#211E11")
TEMPER_VIOLET = srgb("#61506F")     # render-sampled #5B4F6E, nudged warmer
TEMPER_BLUE = srgb("#3B5170")
BRONZE_LIT = srgb("#946844")
BRONZE_DARK = srgb("#452F22")
COPPER_LIT = srgb("#BC6A2C")
COPPER_DARK = srgb("#5E2F13")
STEEL_LIT = srgb("#948E80")
STEEL_DARK = srgb("#464137")
# materials.md: vanilla has NO neutral mass -- saturation runs inverse to
# value, so the darks carry warm oxide rather than grey.
GUNMETAL_LIT = srgb("#4A3F33")
GUNMETAL_DARK = srgb("#1B1611")
RUBBER = srgb("#141517")
HAZARD = srgb("#DFAE3E")
CONCRETE_LIT = srgb("#75705F")
CONCRETE_DARK = srgb("#37342D")

VIOLET_EMIT = srgb("#8900B2")       # epic quality {137, 0, 178}
LED_GREEN = srgb("#5CE07A")

# Bin lips are PAINTED in the quality ramp, never lit -- a sprite sheet cannot
# know what grade actually came out, so a lit bin would claim one on a loop.
QUALITY_LIP = [srgb("#2BA53D"), srgb("#1968B2"), srgb("#8900B2"), srgb("#B26800")]


# --------------------------------------------------------------------------
# geometry helpers
#
# Every solid is subdivided before it is bevelled. materials.md: pointiness is
# per-vertex and interpolated, so a bare 8-vertex cube floods the whole face
# (48.6% of the silhouette marked worn) where the same cube subdivided marks
# 1.8%. The bevel gives the mask a crease; the interior vertices are what stop
# it covering the panel.

_MATS = {}


def _emit(bm, name, material=None, cuts=2, bevel=0.008, angle=40.0):
    if cuts:
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts,
                                  use_grid_fill=True)
    me = bpy.data.meshes.new(PREFIX + name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(PREFIX + name, me)
    bpy.context.scene.collection.objects.link(obj)
    if material:
        obj.data.materials.append(material)
    if bevel:
        b = obj.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(angle)
    return obj


def _bm_box(bm, lo, hi):
    x0, x1 = sorted((lo[0], hi[0]))
    y0, y1 = sorted((lo[1], hi[1]))
    z0, z1 = sorted((lo[2], hi[2]))
    v = [bm.verts.new(p) for p in (
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1),
              (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new([v[i] for i in f])
    return v


def box(name, lo, hi, mat=None, **kw):
    bm = bmesh.new()
    _bm_box(bm, lo, hi)
    return _emit(bm, name, _MATS.get(mat), **kw)


def boxes(name, spans, mat=None, **kw):
    """Several boxes as ONE object, so they share a per-object colour jitter
    and read as one fabricated part rather than a pile."""
    bm = bmesh.new()
    for lo, hi in spans:
        _bm_box(bm, lo, hi)
    return _emit(bm, name, _MATS.get(mat), **kw)


def cyl(name, centre, radius, length, axis="Z", mat=None, seg=28, rings=3, **kw):
    bm = bmesh.new()
    res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                                radius1=radius, radius2=radius, depth=length)
    verts = res["verts"]
    if axis != "Z":
        bmesh.ops.rotate(bm, verts=verts, cent=(0, 0, 0),
                         matrix=Matrix.Rotation(math.radians(90), 3,
                                                "Y" if axis == "X" else "X"))
    bmesh.ops.translate(bm, verts=verts, vec=Vector(centre))
    kw.setdefault("cuts", rings)
    return _emit(bm, name, _MATS.get(mat), **kw)


def prism(name, poly, z0, z1, mat=None, **kw):
    """An extruded polygon -- the pad, so the base is not a square that
    projects to a filled square and owns the whole outline."""
    bm = bmesh.new()
    lower = [bm.verts.new((x, y, z0)) for x, y in poly]
    upper = [bm.verts.new((x, y, z1)) for x, y in poly]
    bm.faces.new(lower[::-1])
    bm.faces.new(upper)
    n = len(poly)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lower[i], lower[j], upper[j], upper[i]))
    return _emit(bm, name, _MATS.get(mat), **kw)


def xz_prism(name, polys, y0, y1, mat=None, **kw):
    """Polygons in the XZ plane, extruded along Y -- a decal on a SOUTH wall.

    `prism()` extrudes in Z, which can only decorate a deck. A hazard chevron
    is a slanted stripe on a vertical face, and stepping one out of axis-aligned
    boxes costs four boxes per stripe and still reads as a staircase. Vanilla's
    chevrons are the loudest thing on a recycler's front; they have to be
    genuinely diagonal.
    """
    bm = bmesh.new()
    for poly in polys:
        near = [bm.verts.new((x, y0, z)) for x, z in poly]
        far = [bm.verts.new((x, y1, z)) for x, z in poly]
        bm.faces.new(near)
        bm.faces.new(far[::-1])
        n = len(poly)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((near[j], near[i], far[i], far[j]))
    return _emit(bm, name, _MATS.get(mat), **kw)


def chevrons(name, x0, x1, z0, z1, y_wall, mat="hazard", count=6, lean=0.62,
             **kw):
    """A hazard band on a south wall: `count` leaning stripes on a DARK plate.

    Returns (backing, stripes). The backing is what makes the band read.
    Vanilla's hazard stripes are yellow against black -- painting them straight
    onto the olive gives yellow against olive, which at gameplay zoom is two
    mid-tones of the same warm hue and simply disappears. The first build's
    chevrons measured fine as geometry and were invisible in the sprite.

    `y_wall` is the wall's own face; the plate stands 0.008 proud of it and the
    stripes 0.010 proud of the plate, so the AO has a step to sit in at both.
    """
    span = x1 - x0
    skew = (z1 - z0) * lean
    pitch = (span - skew) / count
    w = pitch * 0.52
    polys = []
    for j in range(count):
        x = x0 + j * pitch
        polys.append([(x, z0), (x + w, z0), (x + w + skew, z1), (x + skew, z1)])
    kw.setdefault("cuts", 0)
    kw.setdefault("bevel", 0.004)
    pad = 0.025
    back = boxes(name + "-back",
                 [((x0 - pad, y_wall - 0.016, z0 - pad),
                   (x1 + skew + pad, y_wall - 0.008, z1 + pad))],
                 mat="cavity", cuts=1, bevel=0.006)
    strp = xz_prism(name, polys, y_wall - 0.028, y_wall - 0.014, mat=mat, **kw)
    return back, strp


# --------------------------------------------------------------------------
# materials -- the validated stack from references/materials.md, adapted from
# assets/pure-modules-realk/entity/beacon/beacon_gen.py's worn_metal().

_IMG_CACHE = {}
RUST = (0.14, 0.055, 0.025)
BARE = srgb("#9E9890")


def photo_map(slug, kind):
    key = (slug, kind)
    if key in _IMG_CACHE:
        return _IMG_CACHE[key]
    d = POLYHAVEN_DIR / slug
    hits = (sorted(d.glob("*_%s_*.jpg" % kind)) + sorted(d.glob("*_%s_*.png" % kind))
            if d.is_dir() else [])
    img = None
    if hits:
        img = bpy.data.images.load(str(hits[0]), check_existing=True)
        img.colorspace_settings.name = "sRGB" if kind == "diff" else "Non-Color"
    else:
        print("  [texture] %s/%s not cached; procedural only" % (slug, kind))
    _IMG_CACHE[key] = img
    return img


def _reset_nodes(m):
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    return nt, nt.nodes.new("ShaderNodeOutputMaterial")


def _get_mat(name):
    m = bpy.data.materials.get(PREFIX + name)
    return m or bpy.data.materials.new(PREFIX + name)


def worn_metal(name, color_a, color_b, metallic, rough_lo, rough_hi,
               grime=0.0, noise_scale=9.0, wear=0.5, rust=0.35,
               heat=0.0, heat_from=None, grain=0.0, grain_slug="metal_plate",
               scratch=0.0):
    """Painted worn metal. `heat` is this entity's own addition: a tempering
    ramp radiating from the rotor, straw -> bronze -> purple -> blue as the
    surface gets closer to it. That is where the violet accent comes from --
    it has a physical cause before it has a semantic one."""
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

    # photo grain as LUMINANCE only -- a photo's own tint would drag the
    # chassis colour off the value sampled from vanilla
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

    # vertical grime streaks: object coords squashed in Z, so noise smears down
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
        dark = mix_color("MULTIPLY")
        dark.inputs["Factor"].default_value = 1.0
        nt.links.new(color_out, dark.inputs["A"])
        nt.links.new(grey_of(ramp.outputs["Result"]), dark.inputs["B"])
        color_out = dark.outputs["Result"]

    # rust: crevices (low AO) MAX'd with patchy noise
    if rust > 0:
        ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = 0.35
        ao_inv = math_node("SUBTRACT")
        ao_inv.inputs[0].default_value = 1.0
        nt.links.new(ao.outputs["AO"], ao_inv.inputs[1])
        rust_patch = map_range((0.0, 1.0), fr=(0.52, 0.68))
        nt.links.new(noise_node(noise_scale * 0.6, detail=3.0).outputs["Fac"],
                     rust_patch.inputs["Value"])
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

    # heat tempering, radiating from the rotor. Steel runs straw -> bronze ->
    # purple -> blue as it gets hotter, so the ramp is read nearest-first and
    # the hottest band is the one the design picked as the accent.
    if heat > 0 and heat_from:
        pos = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Position"], pos.inputs["Vector"])
        flat = nt.nodes.new("ShaderNodeCombineXYZ")
        nt.links.new(pos.outputs["X"], flat.inputs["X"])
        nt.links.new(pos.outputs["Y"], flat.inputs["Y"])
        dist = nt.nodes.new("ShaderNodeVectorMath")
        dist.operation = "DISTANCE"
        dist.inputs[1].default_value = (*heat_from, 0.0)
        nt.links.new(flat.outputs["Vector"], dist.inputs[0])
        _HEAT_NODES.append(dist.inputs[1])
        # patchy, so the tempering follows the metal rather than a clean radius
        blotch = map_range((-0.22, 0.22), fr=(0.3, 0.7))
        nt.links.new(noise_node(noise_scale * 0.8, detail=3.5).outputs["Fac"],
                     blotch.inputs["Value"])
        wobble = math_node("ADD")
        wobble.use_clamp = False
        nt.links.new(dist.outputs["Value"], wobble.inputs[0])
        nt.links.new(blotch.outputs["Result"], wobble.inputs[1])
        # Violet and blue own most of the ramp, bronze only its far end. With
        # the hot band squeezed into the first fifth, everything but the drum
        # itself came out bronze and the new half rendered orange -- which is
        # the vanilla FOUNDRY's colour, the one hue this palette must not be.
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "EASE"
        e = ramp.color_ramp.elements
        e[0].position, e[0].color = 0.0, (*TEMPER_VIOLET, 1.0)
        e[1].position, e[1].color = 1.0, (*color_a, 1.0)
        for p, c in ((0.30, TEMPER_VIOLET), (0.54, TEMPER_BLUE),
                     (0.80, BRONZE_LIT)):
            el = e.new(p)
            el.color = (*c, 1.0)
        span = map_range((0.0, 1.0), fr=(0.10, 1.60))
        nt.links.new(wobble.outputs["Value"], span.inputs["Value"])
        nt.links.new(span.outputs["Result"], ramp.inputs["Fac"])
        # only where the surface is not already worn back to bare metal
        tempered = mix_color()
        nt.links.new(color_out, tempered.inputs["A"])
        nt.links.new(ramp.outputs["Color"], tempered.inputs["B"])
        # A FLAT mix, not one that fades with distance. Fading it meant only
        # the few surfaces nearest the rotor took any tempering at all and the
        # whole new half rendered plain brown; the ramp's last stop is already
        # the base colour, so distance returns the surface to bronze on its own.
        tempered.inputs["Factor"].default_value = heat
        color_out = tempered.outputs["Result"]

    # per-object hue/value jitter -- the single biggest hand-painted tell
    obj_info = nt.nodes.new("ShaderNodeObjectInfo")
    hue_map = map_range((0.47, 0.53))
    nt.links.new(obj_info.outputs["Random"], hue_map.inputs["Value"])
    val_map = map_range((0.70, 1.30))
    nt.links.new(obj_info.outputs["Random"], val_map.inputs["Value"])
    jitter = nt.nodes.new("ShaderNodeHueSaturation")
    nt.links.new(hue_map.outputs["Result"], jitter.inputs["Hue"])
    nt.links.new(val_map.outputs["Result"], jitter.inputs["Value"])
    nt.links.new(color_out, jitter.inputs["Color"])
    color_out = jitter.outputs["Color"]

    # edge wear: convex edges chip to bare metal, patchy via fine noise
    edge = map_range((0.0, 1.0), fr=(0.53, 0.62))
    nt.links.new(geo.outputs["Pointiness"], edge.inputs["Value"])
    wear_patch = map_range((0.25, 1.0), fr=(0.35, 0.65))
    nt.links.new(noise_node(noise_scale * 1.5).outputs["Fac"],
                 wear_patch.inputs["Value"])
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

    # scour polish: the material path is worn mirror-bright along its length,
    # so the noise is stretched on one axis and masked to up-facing faces
    if scratch > 0:
        nrm = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Normal"], nrm.inputs["Vector"])
        walked = map_range((0.0, 1.0), fr=(0.55, 0.95))
        nt.links.new(nrm.outputs["Z"], walked.inputs["Value"])
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
        polished = mix_color()
        polished.inputs["B"].default_value = (*BARE, 1.0)
        nt.links.new(color_out, polished.inputs["A"])
        nt.links.new(sc_scale.outputs["Value"], polished.inputs["Factor"])
        color_out = polished.outputs["Result"]

    nt.links.new(color_out, bsdf.inputs["Base Color"])

    met = map_range((metallic, 0.75))
    nt.links.new(wear_amt.outputs["Value"], met.inputs["Value"])
    nt.links.new(met.outputs["Result"], bsdf.inputs["Metallic"])

    rmap = map_range((rough_lo, rough_hi))
    nt.links.new(noise_node(noise_scale * 2.1).outputs["Fac"], rmap.inputs["Value"])
    rough_worn = map_range((0.0, -1.0))
    nt.links.new(wear_amt.outputs["Value"], rough_worn.inputs["Value"])
    rough = math_node("MULTIPLY_ADD")
    rough.use_clamp = True
    nt.links.new(rough_worn.outputs["Result"], rough.inputs[0])
    rough.inputs[1].default_value = 0.35
    nt.links.new(rmap.outputs["Result"], rough.inputs[2])
    nt.links.new(rough.outputs["Value"], bsdf.inputs["Roughness"])

    if normal_out is not None:
        nt.links.new(normal_out, bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def plain(name, color, metallic=0.2, rough=0.6, emission=None, strength=2.2):
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


def rubber(name, color=RUBBER):
    m = _get_mat(name)
    nt, out = _reset_nodes(m)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.0
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.3
    r = nt.nodes.new("ShaderNodeMapRange")
    r.inputs["To Min"].default_value = 0.82
    r.inputs["To Max"].default_value = 0.34
    nt.links.new(lw.outputs["Facing"], r.inputs["Value"])
    nt.links.new(r.outputs["Result"], bsdf.inputs["Roughness"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


# The rotor's world XY, so every tempering ramp radiates from the same point.
#
# The drum carries this machine's identity and the first build made it too
# small to do it: 0.92 tiles across is 59 source px, and after the bands and
# ribs that gives each feature 6 px. The cone's real limit for a cylinder about
# Y is `x0 + z0 + r*sqrt(2) <= APEX` -- the 45 degree point on the circle, not
# its top -- which at x0 0.46 / z0 0.86 leaves r 0.63 rather than 0.46.
ROTOR_XY = (0.46, 0.00)
ROTOR_Z, ROTOR_R = 0.86, 0.63
ROTOR_LEN = 1.46
# **The drum turns about Y, north-south, and this was tested the other way.**
# The concept sheet draws the barrel lying east-west, so the axis was swung to
# X to match it -- and the result was a flat striped rectangle with no barrel
# in it at all.
#
# The reason is the rig gotcha, applied one level further than it is usually
# stated. "A disc on the transverse X axis is exactly edge-on" is true of every
# circular cross-section of an X-axis CYLINDER, not just of a thin disc: the
# camera looks along (0, cos45, -sin45), so a circle in the y-z plane projects
# to `-(y0+z0) - r*sqrt(2)*sin(theta+45)` -- a line segment. The barrel keeps
# its length and loses its roundness entirely, silhouette included, and no
# amount of shading puts it back.
#
# On Y the axis sits at 45 degrees to the view, so the drum shows both its
# flank and one end cap: a curved silhouette, and somewhere for the copper end
# flange and its bolt circle to be seen. It reads as a wound rotor. That the
# concept sheet draws it the other way is a limit of this projection, not a
# choice still open.
ROTOR_AXIS = "Y"
# Nine bands along the drum, alternating copper winding against tempered steel.
# This is the concept sheet's one unmistakable feature and the reason the drum
# reads as a drum: concentric bands say "wound cylinder" where a bare tube says
# "pipe". Offsets are along the AXIS, from the drum's centre.
ROTOR_BANDS = [
    (-0.73, -0.62, 0.630, "bronze"),
    (-0.62, -0.44, 0.612, "copper"),
    (-0.44, -0.29, 0.636, "temperv"),
    (-0.29, -0.11, 0.612, "copper"),
    (-0.11, 0.07, 0.638, "temperb"),
    (0.07, 0.25, 0.612, "copper"),
    (0.25, 0.40, 0.636, "temperv"),
    (0.40, 0.60, 0.612, "copper"),
    (0.60, 0.73, 0.630, "bronze"),
]
GEAR_XY = (-0.06, -1.01)
GEAR_Z, GEAR_R = 0.44, 0.26
MAW = (-1.18, -0.42, 0.20, 0.86)                # x0, x1, z0, z1 of the opening
MAW_MID_X, MAW_MID_Y = (MAW[0] + MAW[1]) / 2, -1.25
# Screen row is -(y + z), so a roller set DEEPER in the recess appears HIGHER
# on screen and disappears behind the lintel. The visible band is bounded by
# the opening's own top edge at `y_face + z_top`: here -1.30 + 0.86 = -0.44,
# so a roller at y -1.25 stays visible only while z + r < 0.81.
MAW_ROLLER_Z = (0.35, 0.545, 0.74)
MAW_ROLLER_R = 0.085
AUGER = (0.70, -1.38, 0.30)                     # centre of the common auger
BIN_X = [0.26 + i * 0.23 for i in range(4)]


def cone_z(x, y):
    """The tallest a part may be at this footprint position.

    See the design's *rotation cone* section. A rotatable entity has four north
    edges: rotating swaps which axis points north, so the overhang for a
    direction is max(axis + z) and getting north right says nothing about the
    other three. One condition covers all four (and both mirrorings):

        max(|x|, |y|) + z  <=  APEX

    which makes the machine a cone -- tall in the middle, low at every edge.
    That is the chemical plant's shape, and it is the shape of every vanilla
    machine that rotates. The first build of this entity was a slab 1.4-1.9
    tiles tall at its own perimeter and measured 1.42/1.50/1.50 tiles of
    overhang in east/south/west against a vanilla ceiling of 0.77.
    """
    return APEX - max(abs(x), abs(y))

# Parts that turn in place. Their silhouette does not change as they turn, so
# they belong in the SHADOW pass as well as the animation -- unlike anything
# that travels, which would leave a frozen blob on the ground.
MOVING_KINDS = ("rotor-drum", "rotor-band", "rotor-ribs", "rotor-flange",
                "rotor-hub", "rotor-bolts", "gear-disc", "gear-teeth",
                "maw-roller", "maw-teeth", "auger-belt", "auger-flight")
FX_KINDS = ("frag",)
COLL_NAMES = ("QR_Base", "QR_Moving", "QR_Fx")

# The uniform cone fit, filled in by fit_cone() and applied by set_direction().
# A list so both can reach it without a `global`; see fit_cone() for why one
# scale beats trimming the parts individually.
_FIT = [1.0]

# The heat ramp reads WORLD position, so it has to be told where the rotor is
# once the machine is rotated for east/south/west. Every other term in the
# material stack is object-space or geometric and rotates for free.
_HEAT_NODES = []


def build_materials():
    """Six zones plus the accents, per the design's Material zones section --
    with zone 2 taken from the concept sheet rather than the doc (see note 2).

    Cleared here rather than in build(): Python evaluates build_materials()
    before build() is entered, so clearing there would wipe the very list the
    materials had just filled and every direction after north would temper
    toward wherever the rotor used to be.
    """
    _HEAT_NODES.clear()
    m = {
        # 1. salvaged olive: flat chipped paint, warm and dark, hard edge wear
        # metallic 0.18, not 0.30: this is FLAT PAINT on steel, and the olive
        # half is the machine's one large uninterrupted surface. At 0.30 under
        # a 6.6 key the whole face carried one broad specular sheen and read as
        # a card rather than as a panel -- the tell design-language.md calls
        # "flat single colours", arrived at from the other direction. More
        # grime and a rougher floor put the variation back.
        "olive": worn_metal("olive", OLIVE_LIT, OLIVE_DARK, 0.18, 0.52, 0.80,
                            grime=0.46, wear=0.62, rust=0.40, grain=0.28,
                            grain_slug="rusty_painted_metal", noise_scale=8.0),
        # 2. the new half: bronze tempered violet/blue toward the rotor
        "temper": worn_metal("temper", BRONZE_LIT, BRONZE_DARK, 0.42, 0.30, 0.60,
                             grime=0.16, wear=0.44, rust=0.20, heat=0.92,
                             heat_from=ROTOR_XY, grain=0.18, noise_scale=7.0),
        "bronze": worn_metal("bronze", BRONZE_LIT, BRONZE_DARK, 0.45, 0.28, 0.56,
                             grime=0.18, wear=0.50, rust=0.24, heat=0.45,
                             heat_from=ROTOR_XY, grain=0.16, noise_scale=9.0),
        # 2b. the drum's own bands. The heat ramp is a function of distance
        #     from the rotor, so on the rotor itself every band would land on
        #     the same tint -- these carry the tempering colours as their BASE
        #     instead, which is what makes the drum read banded rather than
        #     uniformly violet. Straight off the concept sheet's chips:
        #     purple #9654A3 (hue 290) and blue #517DA7 (hue 209), taken to
        #     roughly a third toward the metal they are an oxide film on.
        "temperv": worn_metal("temperv", srgb("#6E4A7C"), srgb("#2C1B33"), 0.40,
                              0.26, 0.52, grime=0.12, wear=0.46, rust=0.14,
                              grain=0.14, noise_scale=13.0),
        "temperb": worn_metal("temperb", srgb("#3F6288"), srgb("#182838"), 0.40,
                              0.26, 0.52, grime=0.12, wear=0.46, rust=0.14,
                              grain=0.14, noise_scale=13.0),
        # 3. bare / galvanised steel: frame, ducts, catwalk, auger housing
        "steel": worn_metal("steel", STEEL_LIT, STEEL_DARK, 0.44, 0.34, 0.64,
                            grime=0.26, wear=0.52, rust=0.34, grain=0.20,
                            noise_scale=10.0),
        # 4. dark iron / gunmetal: bin mouths, housings, every recess.
        #    Warm, not grey -- vanilla has no neutral mass.
        "gunmetal": worn_metal("gunmetal", GUNMETAL_LIT, GUNMETAL_DARK, 0.38,
                               0.42, 0.74, grime=0.34, wear=0.34, rust=0.44,
                               noise_scale=11.0),
        # 4b. the shredder throat, and only that. The maw is the olive half's
        #     whole identity and it has to read as a HOLE: the first build lined
        #     it in gunmetal and filled it with scoured teeth, so the brightest
        #     thing on the front elevation was the cavity, and it came out as a
        #     grey grille rather than a mouth. Cycles' AO does the rest once the
        #     surface is dark enough to have somewhere to go.
        "cavity": worn_metal("cavity", srgb("#2A241D"), srgb("#0C0A07"), 0.34,
                             0.56, 0.86, grime=0.46, wear=0.20, rust=0.30,
                             noise_scale=12.0),
        # 5. copper: windings, pole faces, the seam collar.
        #    Metallic 0.42, not 0.62: a metal surface has only the dim world to
        #    reflect, so the pole faces rendered near-black at 0.62 and the
        #    hero's one bright material read as grey bars. Tempering is kept
        #    light here for the same reason -- copper that goes violet stops
        #    being copper.
        "copper": worn_metal("copper", COPPER_LIT, COPPER_DARK, 0.42, 0.20, 0.42,
                             grime=0.08, wear=0.40, rust=0.12, heat=0.14,
                             heat_from=ROTOR_XY, noise_scale=14.0),
        # 6. rubber black: cables, hose runs, the auger belt
        "rubber": rubber("rubber"),
        # the material path, scoured mirror-bright by what passes through it
        "scoured": worn_metal("scoured", srgb("#A39B8C"), STEEL_DARK, 0.40,
                              0.14, 0.38, grime=0.16, wear=0.55, rust=0.16,
                              scratch=0.55, noise_scale=13.0),
        "concrete": worn_metal("concrete", CONCRETE_LIT, CONCRETE_DARK, 0.05,
                               0.72, 0.92, grime=0.34, wear=0.22, rust=0.26,
                               noise_scale=6.0),
        "hazard": worn_metal("hazard", HAZARD, srgb("#8A6A20"), 0.18, 0.44, 0.70,
                             grime=0.24, wear=0.72, rust=0.30, noise_scale=16.0),
        "glass": plain("glass", srgb("#B8C4C0"), metallic=0.1, rough=0.18),
        "violet": plain("violet", (0.02, 0.01, 0.03), emission=VIOLET_EMIT,
                        strength=2.2),
        "led": plain("led", (0.02, 0.03, 0.02), emission=LED_GREEN, strength=1.9),
        # the concept sheet's amber beacon, on top of the salvaged half. Kept
        # well clear of the foundry's 15 deg and legendary's 35: this is a
        # running lamp, not a quality tier.
        "amber": plain("amber", (0.03, 0.02, 0.005), emission=srgb("#FF8A12"),
                       strength=1.9),
    }
    # The bin lips carry the quality ramp, but as WORN PAINT on a machine, not
    # as UI chips. Vanilla's identity paint is desaturated and confined; the
    # first render put four saturated rectangles at the front of the sprite and
    # they read as sweets, pulling the eye clean off the hero. Mixing each
    # tier two-thirds of the way to the gunmetal keeps the four grades legible
    # by hue while leaving the rotor the brightest thing on the machine.
    for i, c in enumerate(QUALITY_LIP):
        lit = tuple(0.34 * a + 0.66 * b for a, b in zip(c, GUNMETAL_LIT))
        dark = tuple(v * 0.42 for v in lit)
        m["lip%d" % i] = worn_metal("lip%d" % i, lit, dark, 0.24, 0.44, 0.72,
                                    grime=0.30, wear=0.74, rust=0.38,
                                    noise_scale=18.0)
    _MATS.clear()
    _MATS.update(m)
    return m


# --------------------------------------------------------------------------
# the machine


def build(mats):
    """The machine, massed as a CONE that still fills its own tiles.

    Two rules, and the first build honoured only one of them:

    1. `max(|x|, |y|) + z <= APEX`, because a rotatable entity has four north
       edges. That is a cone -- tall in the middle, low at the rim.
    2. **The hull stays inside the footprint.** The cone's allowance at the
       footprint edge is `APEX - 1.30 = 1.02` tiles of wall; at y -1.58, where
       the first build put its south wall, it is 0.67. Spending the budget on
       parts that hang past the tiles is what turned this machine into a plan
       view with a 29 px front elevation, and no camera or material work
       recovers that.

    Heights available at APEX 2.32, for reading the numbers below:
        |xy| 0.60 -> 1.72    1.10 -> 1.22
             0.86 -> 1.46    1.32 -> 1.00
             1.00 -> 1.32    1.46 -> 0.86
    """
    a = parts.Assembly(PREFIX, mats)
    a.purge()
    for obj in [o for o in bpy.data.objects if o.name.startswith(PREFIX)]:
        bpy.data.objects.remove(obj, do_unlink=True)
    for c in [c for c in bpy.data.collections if c.name in COLL_NAMES]:
        bpy.data.collections.remove(c)

    # Parts built here are registered with the Assembly at the end; parts
    # placed through a.place()/a.run() register themselves, so keeping the two
    # lists apart is what stops report() double-counting.
    made = []

    # -- 0. the pad ------------------------------------------------------
    # Octagonal, not square: a square deck plate projects to a filled square
    # at this rig and one object then owns the whole outline.
    c = 0.42
    poly = [(-1.36 + c, -1.42), (1.34 - c, -1.42), (1.34, -1.42 + c),
            (1.34, 1.38 - c), (1.34 - c, 1.38), (-1.36 + c, 1.38),
            (-1.36, 1.38 - c), (-1.36, -1.42 + c)]
    made.append(prism("pad", poly, -0.02, DECK, mat="concrete", cuts=3))

    # -- 1. HERO: the eddy-current sorting rotor --------------------------
    # Axis Y: a disc on the transverse X axis is exactly edge-on to this
    # camera and renders as a stripe whatever its diameter. Y is also where an
    # eddy separator's drum sits relative to west-to-east flow, and it puts
    # the copper pole faces where the camera can see them.
    rx, ry = ROTOR_XY
    rz, rr = ROTOR_Z, ROTOR_R
    # core tube, under the bands
    made.append(cyl("rotor-drum", (rx, ry, rz), rr - 0.03, ROTOR_LEN,
                    axis=ROTOR_AXIS, mat="scoured", seg=32, rings=4))
    # nine bands. Built as separate short cylinders rather than as rings on one
    # mesh so each carries its own material -- the alternation of copper
    # against tempered steel is the whole read, and one mesh can only take one.
    for i, (a0, a1, brad, bmat) in enumerate(ROTOR_BANDS):
        made.append(cyl("rotor-band%d" % i, (rx, ry + (a0 + a1) / 2, rz), brad,
                        a1 - a0, axis=ROTOR_AXIS, mat=bmat, seg=32, rings=1))
    # 14 axial ribs riding proud of the bands. Concentric bands are
    # rotationally symmetric, so a banded drum spinning shows NO motion at all;
    # the ribs are what make the turn visible, and they are the design's pole
    # faces doing a second job.
    ribs = []
    for i in range(14):
        ang = 2 * math.pi * i / 14
        px, pz = rx + 0.655 * math.cos(ang), rz + 0.655 * math.sin(ang)
        ribs.append(((px - 0.026, ry - 0.50, pz - 0.026),
                     (px + 0.026, ry + 0.50, pz + 0.026)))
    made.append(boxes("rotor-ribs", ribs, mat="copper", cuts=1, bevel=0.005))
    # the bright copper end flange and its bolt circle -- the concept sheet's
    # rotor crop is mostly this. r 0.655 at y -0.765, not 0.68 at -0.78: on a
    # disc about Y the cone's binding point is the TOP of the circle, where |y|
    # beats |x|, not the 45 degree point that binds the drum itself.
    made.append(cyl("rotor-flange", (rx, ry - 0.765, rz), 0.655, 0.055,
                    axis=ROTOR_AXIS, mat="copper", seg=32, rings=1))
    made.append(cyl("rotor-hub", (rx, ry - 0.83, rz), 0.20, 0.09,
                    axis=ROTOR_AXIS, mat="bronze", seg=24))
    a.place("greeble:bolt_ring", at=(rx, ry - 0.84), z=rz, size=0.56,
            mat="steel", count=12, name="rotor-bolts")

    # The tempered half's south wall, carrying the drum's near bearing. This is
    # the front elevation on the east half: without it the camera sees straight
    # under the drum to the pad, and that half loses the substantial south face
    # the design insists on. Stepped down past |x| 0.90, where the cone drops
    # from 1.42 to 1.16.
    made.append(boxes("rotor-house", [
        ((-0.24, -1.06, DECK), (0.90, -0.94, 1.00)),
        ((0.90, -1.06, DECK), (1.14, -0.94, 0.92)),
    ], mat="temper", cuts=3))
    # A bronze access plate with a scoured frame on it. Everything below the
    # drum on this side -- housing, bins, auger -- is dark, and a machine whose
    # whole lower right is one value reads as a hole rather than as structure.
    made.append(boxes("cheek-plate", [
        ((0.20, -1.072, 0.40), (0.96, -1.058, 0.84)),
    ], mat="bronze", cuts=2, bevel=0.010))
    made.append(boxes("cheek-frame", [
        ((0.17, -1.078, 0.37), (0.99, -1.064, 0.41)),
        ((0.17, -1.078, 0.83), (0.99, -1.064, 0.87)),
        ((0.17, -1.078, 0.37), (0.21, -1.064, 0.87)),
        ((0.95, -1.078, 0.37), (0.99, -1.064, 0.87)),
    ], mat="scoured", cuts=1, bevel=0.005))
    a.place("greeble:bolt_ring", at=(0.58, -1.08), z=0.62, size=0.17,
            mat="steel", count=8, name="cheek-bolts")
    # the far bearing wall
    made.append(boxes("cheek-n", [
        ((-0.24, 0.78, DECK), (0.90, 0.92, 1.30)),
        ((0.90, 0.78, DECK), (1.14, 0.92, 1.14)),
    ], mat="temper", cuts=3))

    # ring-gear drive, half-buried in the salvaged housing so the seam is
    # mechanical rather than cosmetic -- a gear emerging from the olive block
    # and meshing on the drum's lower west quadrant.
    gx, gy = GEAR_XY
    made.append(cyl("gear-disc", (gx, gy, GEAR_Z), GEAR_R, 0.08, axis="Y",
                    mat="steel", seg=30))
    teeth = []
    for i in range(18):
        ang = 2 * math.pi * i / 18
        tx = gx + (GEAR_R + 0.022) * math.cos(ang)
        tz = GEAR_Z + (GEAR_R + 0.022) * math.sin(ang)
        teeth.append(((tx - 0.030, gy - 0.048, tz - 0.030),
                      (tx + 0.030, gy + 0.042, tz + 0.030)))
    made.append(boxes("gear-teeth", teeth, mat="steel", cuts=0, bevel=0.005))

    # -- 2. the salvaged olive half: a chunky stepped block ----------------
    # Three tiers, each sized against cone_z at its own outermost corner and
    # each INSIDE the footprint:
    #   T1  |xy| 1.32 -> 1.00 available, built to 0.98  (0.86 tiles of wall)
    #   T2  |xy| 1.10 -> 1.22 available, built to 1.20
    #   T3  |xy| 0.86 -> 1.46 available, built to 1.44
    # The south wall is 0.86 tiles -- 55 source px, 28 in play. The first build
    # gave it 0.46, which is where "it reads as a plan view" came from.
    #
    # T1 is built as a BLOCK plus a four-piece south wall rather than as one
    # box, because the maw has to be a hole in that wall. A solid box with the
    # shredder modelled inside it shows a flat green face and nothing else.
    made.append(boxes("hull-olive", [
        ((-1.32, -0.92, DECK), (-0.24, 0.94, 0.98)),        # T1 body
        ((-1.10, -1.06, 0.98), (-0.28, 0.70, 1.20)),        # T2
        ((-0.86, -0.74, 1.20), (-0.30, 0.40, 1.44)),        # T3
    ], mat="olive", cuts=3))
    made.append(boxes("maw-frame", [
        ((-1.32, -1.30, DECK), (MAW[0], -0.92, 0.98)),      # west jamb
        ((MAW[1], -1.30, DECK), (-0.24, -0.92, 0.98)),      # east jamb
        ((MAW[0], -1.30, DECK), (MAW[1], -0.92, MAW[2])),   # sill
        ((MAW[0], -1.30, MAW[3]), (MAW[1], -0.92, 0.98)),   # lintel
    ], mat="olive", cuts=3))
    # panel plates on T1's exposed deck, with seams between them
    made.append(boxes("deck-plates", [
        ((-1.26, -1.24, 0.98), (-0.74, -0.98, 1.04)),
        ((-0.66, -1.24, 0.98), (-0.28, -0.98, 1.04)),
        ((-1.26, -0.90, 0.98), (-1.14, 0.62, 1.04)),
    ], mat="olive", cuts=2, bevel=0.010))
    # Proud panels on the stepped south faces. The camera sees exactly two
    # surfaces of a building -- the deck and the -Y wall -- and this machine's
    # -Y wall is two thirds olive paint with a chevron band on it. A bevelled
    # plate standing 0.02 off the wall costs nothing and gives the AO a seam to
    # sit in, which is what stops a large painted face reading as a flat fill.
    made.append(boxes("olive-panels", [
        ((-1.28, -1.32, 0.30), (-1.20, -1.30, 0.92)),      # T1 west stile
        ((-0.40, -1.32, 0.30), (-0.26, -1.30, 0.92)),      # T1 east stile
        ((-1.04, -1.08, 1.02), (-0.64, -1.06, 1.17)),      # T2, under the band
        ((-0.84, -0.76, 1.24), (-0.34, -0.74, 1.41)),      # T3 face plate
    ], mat="olive", cuts=1, bevel=0.008))
    # a bolted access hatch where the chevron band stops, with its own handwheel
    made.append(boxes("hatch", [
        ((-0.60, -1.09, 1.00), (-0.32, -1.06, 1.19)),
    ], mat="steel", cuts=1, bevel=0.008))
    a.place("greeble:handwheel", at=(-0.46, -1.12), z=1.10, size=0.13,
            mat="hazard", name="hatch-wheel")

    # the shredder itself, in the opening. The throat is a BACK PLATE and two
    # cheeks, not a filled box -- as a solid volume its front face occluded the
    # rollers entirely.
    made.append(boxes("maw-throat", [
        ((MAW[0], -0.98, MAW[2]), (MAW[1], -0.92, MAW[3])),
        ((MAW[0], -1.30, MAW[2]), (MAW[0] + 0.05, -0.92, MAW[3])),
        ((MAW[1] - 0.05, -1.30, MAW[2]), (MAW[1], -0.92, MAW[3])),
        ((MAW[0], -1.30, MAW[2] - 0.04), (MAW[1], -0.92, MAW[2] + 0.02)),
    ], mat="cavity", cuts=3))
    # A scoured lip round the opening: bare metal polished by everything that
    # has been fed through it, and the value step that makes the hole read as a
    # hole. Wear placed by physics -- this is exactly where a real shredder's
    # paint goes first.
    made.append(boxes("maw-lip", [
        ((MAW[0] - 0.045, -1.316, MAW[2] - 0.045), (MAW[1] + 0.045, -1.286, MAW[2])),
        ((MAW[0] - 0.045, -1.316, MAW[3]), (MAW[1] + 0.045, -1.286, MAW[3] + 0.045)),
        ((MAW[0] - 0.045, -1.316, MAW[2]), (MAW[0], -1.286, MAW[3])),
        ((MAW[1], -1.316, MAW[2]), (MAW[1] + 0.045, -1.286, MAW[3])),
    ], mat="scoured", cuts=1, bevel=0.006))
    # Bright chrome rollers in a dark box, which is what the concept sheet's
    # shredder crop actually shows -- and the inverse of the first two attempts.
    # The rollers are SHORT of the opening at both ends (0.15 tiles of cavity
    # each side) so the darkness reads as a cavity rather than as a border: a
    # roller spanning the full width made the mouth a grille, whatever material
    # it wore. Teeth go dark on a bright drum, not bright on a dark one.
    for i, z in enumerate(MAW_ROLLER_Z):
        made.append(cyl("maw-roller%d" % i, (MAW_MID_X, MAW_MID_Y, z),
                        MAW_ROLLER_R, MAW[1] - MAW[0] - 0.30, axis="X",
                        mat="scoured", seg=20, rings=2))
        ridges = []
        for j in range(4):
            ang = 2 * math.pi * j / 4 + 0.4
            ry_ = (MAW_ROLLER_R + 0.016) * math.cos(ang)
            rz_ = (MAW_ROLLER_R + 0.016) * math.sin(ang)
            ridges.append(((MAW[0] + 0.21, MAW_MID_Y + ry_ - 0.034,
                            z + rz_ - 0.034),
                           (MAW[1] - 0.21, MAW_MID_Y + ry_ + 0.034,
                            z + rz_ + 0.034)))
        made.append(boxes("maw-teeth%d" % i, ridges, mat="gunmetal", cuts=0,
                          bevel=0.008))

    # hopper lip, breaching the south edge low, where the cone still allows it.
    # Stops at y -1.46: the SOUTH extreme belongs to the out-chute alone, and
    # `audit()` collects every vertex within 0.06 of an extreme into that
    # extreme's row band -- so a second part reaching the same 0.06 hands its
    # whole row range to the band and puts full-width scanlines back.
    made.append(boxes("hopper", [
        ((-1.10, -1.46, 0.20), (-0.42, -1.26, 0.34)),
        ((-1.14, -1.40, 0.13), (-0.38, -1.30, 0.24)),
    ], mat="scoured", cuts=2))

    # scrap chute past the WEST edge. This owns the WEST extreme, and it sits
    # SOUTH of whatever owns the east one. The audit takes every vertex within
    # 0.06 of an extreme, so the two extremes' row bands have to be disjoint --
    # that is what makes a full-width scanline geometrically impossible rather
    # than something to fix in post.
    made.append(boxes("chute", [
        ((-1.62, -0.96, 0.18), (-1.34, -0.52, 0.46)),
        ((-1.70, -0.90, 0.12), (-1.58, -0.58, 0.24)),
    ], mat="scoured", cuts=2))

    # -- 3. the tempered half ---------------------------------------------
    made.append(boxes("hull-temper", [
        ((1.16, -1.10, DECK), (1.30, 1.02, 0.98)),          # east apron wall
        ((0.10, 0.92, DECK), (1.16, 1.24, 1.06)),           # rear deck
    ], mat="temper", cuts=3))
    # the rear cowl, BEHIND the drum rather than over it: a roof across the
    # hero put a bronze lid on the machine's one identifying part, and being
    # north its height reads above the drum anyway (screen row is -(y + z)).
    made.append(boxes("cowl", [
        ((-0.06, 0.88, 1.06), (0.86, 1.04, 1.26)),
    ], mat="bronze", cuts=2))

    # the seam: copper posts either side of the drum plus a beam over the top,
    # the warm divider between the two technologies. Posts rather than a wall,
    # because a wall spanning the depth stands straight in front of the hero.
    made.append(boxes("seam-frame", [
        ((-0.34, -1.28, DECK), (-0.20, -1.02, 1.04)),
        ((-0.34, 0.78, DECK), (-0.20, 1.00, 1.14)),
    ], mat="copper", cuts=2))
    a.run("greeble:rivet_row", (-0.27, -1.24, 1.05), (-0.27, -1.06, 1.05),
          count=3, mat="steel", name="seam-rivets")

    # -- 4. material through: bins and the common auger --------------------
    # four graded bins, open-topped with the grade colour on the RIM only.
    # A solid coloured lid is a swatch, not a bin.
    for i in range(4):
        x0 = BIN_X[i]
        made.append(boxes("bin%d" % i, [
            ((x0, -1.28, DECK), (x0 + 0.20, -0.98, 0.50)),
        ], mat="gunmetal", cuts=2))
        rim = 0.034
        made.append(boxes("binlip%d" % i, [
            ((x0 - 0.012, -1.30, 0.50), (x0 + 0.212, -1.30 + rim, 0.56)),
            ((x0 - 0.012, -1.00 - rim, 0.50), (x0 + 0.212, -0.96, 0.56)),
            ((x0 - 0.012, -1.30, 0.50), (x0 + rim, -0.96, 0.56)),
            ((x0 + 0.212 - rim, -1.30, 0.50), (x0 + 0.212, -0.96, 0.56)),
        ], mat="lip%d" % i, cuts=1, bevel=0.005))

    # ONE common auger under all four, running to a single chute. The entity
    # has one output inventory, so four bins could imply four drawable outputs
    # (FFF-339); the auger is what keeps the single output on screen.
    made.append(boxes("auger-housing", [
        ((0.20, -1.44, DECK), (1.20, -1.26, 0.32)),
    ], mat="steel", cuts=2))
    made.append(cyl("auger-belt", AUGER, 0.058, 0.94, axis="X",
                    mat="gunmetal", seg=14))
    flights = []
    for j in range(14):
        t = j / 14.0
        ang = 2 * math.pi * 2.0 * t
        fx = AUGER[0] - 0.45 + 0.90 * t
        fy = AUGER[1] + 0.078 * math.cos(ang)
        fz = AUGER[2] + 0.078 * math.sin(ang)
        flights.append(((fx - 0.028, fy - 0.024, fz - 0.024),
                        (fx + 0.028, fy + 0.024, fz + 0.024)))
    made.append(boxes("auger-flight", flights, mat="steel", cuts=0, bevel=0.004))
    # the single output, and the machine's SOLE southernmost part -- see the
    # note on the hopper. Its east edge stops at 1.36 for the same reason at
    # the other end: at 1.44 it fell inside the east bracket's 0.06 band and
    # handed its own rows (-1.38 up) to the east extreme, which overlapped the
    # scrap chute's and made 0.43 tiles of rows full width.
    made.append(boxes("out-chute", [
        ((1.16, -1.58, 0.12), (1.36, -1.32, 0.34)),
    ], mat="scoured", cuts=2))

    # -- 5. the chunky pipework -------------------------------------------
    # The concept sheet's pipes are its second-loudest feature and the first
    # build's were radius 0.044 -- 3 source px, gone by the time the sprite is
    # halved. These are 0.075-0.095, which is 10-12 px of source and reads.
    # A pipe_run's endpoint flange is a disc of 1.65x the radius PERPENDICULAR
    # to the run, so it adds most of that to z at a shallow start -- the top
    # here is 1.36 + 0.14, not 1.36.
    a.run("greeble:pipe_run",
          [(-0.62, -0.30, 1.36), (-0.30, -0.62, 1.22), (0.06, -0.98, 1.06)],
          radius=0.090, mat="copper", name="crossover")
    a.run("greeble:pipe_run", [(-1.24, -1.36, 0.18), (-0.32, -1.36, 0.18)],
          radius=0.075, mat="copper", name="front-main")
    a.run("greeble:pipe_run",
          [(1.24, 0.56, 0.86), (1.24, 0.02, 0.68), (1.24, -0.54, 0.50)],
          radius=0.085, mat="bronze", name="apron-riser")
    a.run("greeble:pipe_run", [(-0.13, -1.16, 0.94), (-0.13, -1.16, 0.26)],
          radius=0.080, mat="copper", name="seam-downcomer")

    # -- 6. power in ------------------------------------------------------
    a.place("greeble:junction_box", at=(1.22, -0.84), z=0.62, size=0.28,
            mat="gunmetal", name="junction")
    for i, (sx, sy, ex, ey) in enumerate([
            (1.18, -0.86, 0.86, -1.18), (1.26, -0.86, 0.98, -1.18),
            (1.10, -0.86, 0.74, -1.18)]):
        a.run("greeble:cable", (sx, sy, 0.66), (ex, ey, 0.42),
              sag=0.12, mat="rubber", name="cable%d" % i)
    for i in range(3):
        made.append(cyl("cap%d" % i, (0.36 + i * 0.22, 1.08, 0.72), 0.086, 0.34,
                        mat="steel", seg=16))

    # -- 7. heat out ------------------------------------------------------
    # Earned, not decorative: eddy currents genuinely make heat.
    #
    # No `rot=` on a greeble: the builders bake their centre into the mesh and
    # leave the object at the origin, so parts.place()'s rot spins the part
    # about the WORLD origin. A louvre bank at (1.44, -0.30) with rot=90 flew
    # to (0.30, 1.44) and became the tallest thing in the sprite.
    a.place("greeble:radiator", at=(0.62, 1.00), z=0.80, size=0.40,
            mat="steel", name="radiator")
    a.place("greeble:louvre_bank", at=(-0.58, 1.02), z=0.60, size=0.42,
            mat="gunmetal", name="louvres")
    a.place("greeble:louvre_bank", at=(-0.70, 1.28), z=0.48, size=0.34,
            mat="gunmetal", name="louvres-n")
    # The stack rides the olive block's top tier, pulled in to x -0.46: a cap's
    # RADIUS counts toward |xy| as much as its centre does, so the 0.165 cowl
    # on a stack at x -0.58 reads as |xy| 0.745, not 0.58.
    made.append(cyl("stack", (-0.46, 0.10, 1.32), 0.13, 0.40, mat="steel",
                    seg=20))
    made.append(cyl("stack-cowl", (-0.46, 0.10, 1.56), 0.165, 0.10,
                    mat="gunmetal", seg=20))

    # -- 8. human service --------------------------------------------------
    a.run("greeble:ladder", (1.26, -1.02, DECK), 0.62, mat="steel",
          name="ladder")
    # Railings sit on the PAD, not on a deck. A railing adds ~0.17 above the z
    # it is given, and at the |xy| where a rim deck actually is the cone has
    # 1.02-1.08 left -- so a rail on any deck of this machine is over budget
    # before its first post. On the pad's north and west edges they clear the
    # pad's own outline instead, which is where new silhouette comes from.
    # Clear of the pad's outline (y 1.38, x -1.36), not level with it: a post
    # standing ON the pad draws opaque-on-opaque and the daylight between posts
    # -- the entire point of a railing here -- never becomes alpha.
    a.run("greeble:railing", [(-1.04, 1.52, DECK), (-0.76, 1.52, DECK),
                              (-0.48, 1.52, DECK), (-0.20, 1.52, DECK)],
          mat="steel", height=0.17, name="railing-n")
    a.run("greeble:railing", [(-1.50, 0.12, DECK), (-1.50, 0.40, DECK),
                              (-1.50, 0.68, DECK), (-1.50, 0.96, DECK)],
          mat="steel", height=0.17, name="railing-w")
    a.run("greeble:railing", [(0.24, -1.48, DECK), (0.52, -1.48, DECK),
                              (0.80, -1.48, DECK), (1.08, -1.48, DECK)],
          mat="steel", height=0.17, name="railing-s")
    a.run("greeble:railing", [(1.40, -0.40, DECK), (1.40, -0.12, DECK),
                              (1.40, 0.16, DECK)], mat="steel",
          height=0.17, name="railing-e")
    a.place("greeble:handwheel", at=(-0.20, 0.60), z=1.24, size=0.20,
            mat="hazard", name="handwheel")
    for i, (px, py, pz) in enumerate([(1.22, -0.52, 0.74), (1.22, -0.30, 0.74),
                                      (1.22, -0.52, 0.56)]):
        a.place("greeble:gauge_pod", at=(px, py), z=pz, size=0.13,
                mat="steel", face_material=mats["glass"], name="gauge%d" % i)
    a.place("greeble:placard", at=(-0.24, -1.31), z=0.56, size=0.20,
            mat="steel", name="placard")

    # hazard chevrons, quoting the vanilla recycler's own. GENUINELY DIAGONAL
    # and big: the first build's were 0.125 x 0.16 slivers on a wall the camera
    # barely sees, and they simply were not there in the sprite. Three bands up
    # the stepped front, one along the output, sized so each stripe is 8-14 px.
    made.extend(chevrons("chevron-top", -0.82, -0.36, 1.25, 1.41, -0.74,
                         count=3))
    made.extend(chevrons("chevron-mid", -1.04, -0.64, 1.03, 1.16, -1.06,
                         count=3))
    made.extend(chevrons("chevron-lintel", -1.14, -0.38, 0.905, 0.972, -1.30,
                         count=6))
    made.extend(chevrons("chevron-out", 0.26, 1.14, 0.16, 0.30, -1.44,
                         count=6))

    # -- 9. structure -----------------------------------------------------
    a.run("greeble:skid_feet",
          [(-1.24, -1.24, -0.02), (-1.24, 1.20, -0.02),
           (1.22, -1.24, -0.02), (1.22, 1.20, -0.02)],
          mat="gunmetal", name="feet")
    a.run("greeble:rivet_row", (-1.26, -1.31, 0.30), (-0.22, -1.31, 0.30),
          count=9, mat="olive", name="rivets-front")
    # On the deck, not the west wall: at this pitch a side wall renders as a
    # one-pixel line, and the west rivet row drew literally nothing there.
    a.run("greeble:rivet_row", (-1.24, -1.10, 1.06), (-0.24, -1.10, 1.06),
          count=8, mat="olive", name="rivets-deck")

    # Things that BREAK the outline. The gate measures perimeter against the
    # bounding box, and vanilla's 1.14-2.19 comes from pipes, cables and rails
    # poking past the hull rather than from a smaller footprint. Every one of
    # these has to clear the PAD's own outline (x -1.36..1.34, y -1.42..1.38)
    # or it draws opaque-on-opaque and contributes no alpha boundary at all.
    # Narrow, because it sets the sprite's north edge in the bounding box that
    # `ragged` divides by. It has to exist -- it owns the north extreme, which
    # is what keeps east and west free of full-width rows -- but every pixel of
    # width it carries is bbox this machine then has to fill raggedly.
    made.append(boxes("north-duct", [
        ((-0.26, 1.26, 0.14), (0.06, 1.56, 0.48)),
        ((-0.20, 1.56, 0.20), (0.00, 1.66, 0.40)),
    ], mat="steel", cuts=2))
    made.append(boxes("corner-post", [
        ((-1.48, 1.10, DECK), (-1.32, 1.38, 0.52)),
    ], mat="gunmetal", cuts=2))
    made.append(boxes("drain-stub", [
        ((-0.16, -1.46, 0.14), (0.12, -1.34, 0.32)),
    ], mat="gunmetal", cuts=2))
    # Ends at -1.44, not -1.56: a pipe_run puts a flange of 1.65x its radius at
    # every endpoint, so the drawn extreme is 0.083 further out than the point
    # given. At -1.56 that flange reached -1.643, took the WEST extreme off the
    # scrap chute, and dragged its rows up beside the east bracket's -- which
    # puts full-width scanlines back.
    a.run("greeble:pipe_run", [(-1.30, 0.24, 0.46), (-1.44, 0.24, 0.46)],
          radius=0.050, mat="copper", name="west-stub")
    # This bracket owns the EAST extreme, and its row band sits clear of the
    # scrap chute's -- the disjointness the silhouette depends on has to be
    # re-checked every time an extreme moves.
    made.append(boxes("east-bracket", [
        ((1.30, 0.34, 0.30), (1.48, 0.62, 0.54)),
    ], mat="steel", cuts=2))
    # More outline, and all of it past the PAD (x -1.36..1.34, y -1.42..1.38).
    # Massing the machine as a chunky block is what the concept asked for and
    # what the first pass lacked -- but chunky reads smooth, and raggedness fell
    # to 0.97 against a 1.05 floor and a vanilla spread of 1.14-2.19. Each of
    # these also stays clear of the two extremes' 0.06 bands, or it inherits
    # their row range and puts full-width scanlines back.
    # Stops at 1.54, not 1.62: the north-duct owns the NORTH extreme at 1.66
    # and audit()'s band is 0.06, so a second part at 1.62 joins it and hands
    # the extreme its own rows -- which broke west by 0.21 tiles.
    made.append(boxes("ne-cooler", [
        ((0.86, 1.30, DECK), (1.20, 1.54, 0.46)),
    ], mat="steel", cuts=2))
    made.append(boxes("west-lugs", [
        ((-1.48, -0.26, 0.38), (-1.34, -0.10, 0.54)),
        ((-1.48, 0.16, 0.38), (-1.34, 0.32, 0.54)),
        ((-1.48, 0.58, 0.38), (-1.34, 0.74, 0.54)),
    ], mat="gunmetal", cuts=1))
    # `ragged` is alpha PERIMETER over bounding-box perimeter, so what raises
    # it is edge, not bulk -- and a hole counts twice over, once for each side.
    # The first attempt at this added solid blocks past the pad and raggedness
    # went DOWN (0.97 -> 0.95), because each one grew the filled area faster
    # than the outline. Open frames in clear air are the opposite trade: a
    # ladder standing off the west wall is almost all edge.
    a.run("greeble:ladder", (-1.42, -0.60, DECK), 0.58, mat="steel",
          name="ladder-w")
    a.run("greeble:cable", (1.26, -0.30, 0.90), (1.40, 0.16, 0.28),
          sag=0.16, mat="rubber", name="cable-drop")
    a.run("greeble:cable", (-1.34, 0.86, 0.62), (-1.50, 1.18, 0.24),
          sag=0.14, mat="rubber", name="cable-w")
    a.run("greeble:cable", (0.20, 1.30, 0.94), (-0.30, 1.48, 0.30),
          sag=0.16, mat="rubber", name="cable-n")
    a.run("greeble:cable", (-1.28, -1.34, 0.42), (-0.72, -1.46, 0.22),
          sag=0.12, mat="rubber", name="cable-s")

    # -- 10. the emissives ------------------------------------------------
    # The field gap, on the SOUTH face of the bearing cheek. The first build
    # put ten violet pips on the drum's rim: they turned with it, so an
    # additive glow layer swept a magenta arc across the middle of the sprite
    # every loop and read as glitter rather than as a machine working. Two
    # static slots high on the cheek are what the design asked for --  "small
    # and local" -- and they sit above the bins and clear of the gear, which is
    # the only band of that face nothing else draws over.
    made.append(boxes("field-glow", [
        # south face: the reading in north, and a sliver in east and west
        ((0.26, -1.070, 0.88), (0.44, -1.060, 0.96)),
        ((0.72, -1.070, 0.88), (0.90, -1.060, 0.96)),
        # ROOF of the same housing, and this is the one that carries the other
        # rotations. A south-facing emissive points AWAY from the camera once
        # the machine faces south and renders as a one-pixel line east and
        # west -- the first build's light sheet measured 45x60 px in north
        # against 17x8 in flipped-south. An up-facing slot is visible in all
        # four, because the deck is the one surface this camera always sees.
        ((0.24, -1.04, 0.998), (0.46, -0.96, 1.012)),
        ((0.70, -1.04, 0.998), (0.92, -0.96, 1.012)),
        # and the north face, for the south view
        ((0.26, 0.920, 0.88), (0.44, 0.930, 0.96)),
        ((0.72, 0.920, 0.88), (0.90, 0.930, 0.96)),
    ], mat="violet", cuts=0, bevel=0.004))
    # Green status lamp per the vanilla convention: idle shows this and nothing
    # else, so idle and working read apart at a glance without zooming.
    made.append(boxes("status-lamp", [
        ((-0.44, -1.310, 0.74), (-0.34, -1.300, 0.84)),
        # a second lamp lying on the olive deck, up-facing, for the same reason
        # the field gap gained a roof slot: idle and working have to read apart
        # at a glance in every rotation, not only in north.
        ((-0.62, -1.20, 0.972), (-0.50, -1.08, 0.988)),
    ], mat="led", cuts=0, bevel=0.003))
    # the concept sheet's amber beacon on top of the salvaged half
    made.append(cyl("beacon-base", (-0.66, -0.52, 1.44), 0.085, 0.06,
                    mat="gunmetal", seg=16))
    made.append(cyl("beacon-lamp", (-0.66, -0.52, 1.50), 0.070, 0.09,
                    mat="amber", seg=16))

    # -- 11. the fragments the rotor throws -------------------------------
    # One chip per bin, so the SEPARATION is what the animation shows. They
    # travel, so they are the only parts kept out of the shadow pass: a baked
    # shadow of something in flight lands displaced and then sits frozen.
    for i in range(4):
        made.append(boxes("frag%d" % i, [
            ((-0.055, -0.055, -0.034), (0.055, 0.055, 0.034)),
        ], mat="scoured", cuts=1, bevel=0.008))

    a.placed.extend([o for o in made if o is not None and hasattr(o, "name")])
    organise()
    return a


# --------------------------------------------------------------------------
# collections, pivots, animation
#
# Layers are collections, and what goes where is decided by one rule: does the
# part's SILHOUETTE change? A drum spinning on its own axis keeps its outline,
# so it belongs in the shadow pass with the rest of the machine. A chip flying
# through the air does not, so it is excluded -- a baked shadow of a moving
# part reads in game as a wrong dark blob that never moves.


def _classify(name):
    stem = name[len(PREFIX):]
    if any(stem.startswith(k) for k in FX_KINDS):
        return "QR_Fx"
    if any(stem.startswith(k) for k in MOVING_KINDS):
        return "QR_Moving"
    return "QR_Base"


def organise():
    scene = bpy.context.scene
    linked = {c.name for c in scene.collection.children}
    colls = {}
    for n in COLL_NAMES:
        c = bpy.data.collections.get(n) or bpy.data.collections.new(n)
        if n not in linked:
            scene.collection.children.link(c)
        colls[n] = c
    for obj in [o for o in bpy.data.objects if o.name.startswith(PREFIX)]:
        target = colls[_classify(obj.name)]
        for c in list(obj.users_collection):
            c.objects.unlink(obj)
        target.objects.link(obj)
    return colls


def _pivot(name, location, collection="QR_Moving"):
    e = bpy.data.objects.new(PREFIX + name, None)
    e.empty_display_size = 0.15
    e.location = location
    bpy.data.collections[collection].objects.link(e)
    return e


def _attach(pivot, names):
    """Parent by name prefix, preserving each part's world transform.

    The meshes here are built with their coordinates baked in and their origin
    at the world origin, so rotating an object rotates it about (0,0,0) --
    the drum would orbit the machine instead of spinning. A pivot at the axis
    with matrix_parent_inverse set is what makes rotation local.
    """
    # Built from the pivot's LOCATION, not from pivot.matrix_world: a freshly
    # created empty has not been through a depsgraph update, so its
    # matrix_world is still the identity and the inverse is a no-op. That
    # silently offsets every child by the pivot's position -- the drum moved
    # 0.91 tiles up-screen and the north overhang went from 0.68 to 1.42.
    inv = Matrix.Translation(pivot.location).inverted()
    got = []
    for obj in bpy.data.objects:
        if not obj.name.startswith(PREFIX) or obj is pivot:
            continue
        stem = obj.name[len(PREFIX):]
        if any(stem.startswith(n) for n in names):
            obj.parent = pivot
            obj.matrix_parent_inverse = inv
            got.append(obj)
    return got


def _key(obj, path, frames_values, index=None, interp="LINEAR"):
    for f, v in frames_values:
        if index is None:
            setattr(obj, path, v)
            obj.keyframe_insert(path, frame=f)
        else:
            getattr(obj, path)[index] = v
            obj.keyframe_insert(path, index=index, frame=f)
    ad = obj.animation_data
    if not ad:
        return
    # Blender 4.4+ moved fcurves behind action slots: layers > strips >
    # channelbag. `action.fcurves` is gone, and reaching for it raises.
    curves = []
    act = ad.action
    if hasattr(act, "fcurves"):
        curves = list(act.fcurves)
    else:
        for layer in act.layers:
            for strip in layer.strips:
                bag = strip.channelbag(ad.action_slot)
                if bag:
                    curves.extend(bag.fcurves)
    for fc in curves:
        for kp in fc.keyframe_points:
            kp.interpolation = interp


def animate(frames=64):
    """Seven looping elements, every one of them closing exactly on `frames`.

    A loop that does not close is the animation equivalent of a seam: the
    sprite jumps on the wrap, once a second, forever. Every rotation below is
    a whole number of turns for that reason, and the gear's 2:1 against the
    drum is chosen to close rather than to be geometrically exact (the true
    ratio from the radii is 1.61).
    """
    tau = 2 * math.pi

    rotor = _pivot("piv-rotor", (ROTOR_XY[0], ROTOR_XY[1], ROTOR_Z))
    _attach(rotor, ("rotor-drum", "rotor-band", "rotor-ribs", "rotor-flange",
                    "rotor-hub", "rotor-bolts"))
    _key(rotor, "rotation_euler", [(0, 0.0), (frames, tau)], index=1)

    gear = _pivot("piv-gear", (GEAR_XY[0], GEAR_XY[1], GEAR_Z))
    _attach(gear, ("gear-disc", "gear-teeth"))
    _key(gear, "rotation_euler", [(0, 0.0), (frames, -2 * tau)], index=1)

    # Counter-rotating rollers -- a shredder that turned both ways the same
    # way would be feeding material back out of its own mouth.
    for i, z in enumerate(MAW_ROLLER_Z):
        piv = _pivot("piv-maw%d" % i, (MAW_MID_X, MAW_MID_Y, z))
        _attach(piv, ("maw-roller%d" % i, "maw-teeth%d" % i))
        turns = 3 * tau * (1 if i % 2 == 0 else -1)
        _key(piv, "rotation_euler", [(0, 0.0), (frames, turns)], index=0)

    auger = _pivot("piv-auger", AUGER)
    _attach(auger, ("auger-belt", "auger-flight"))
    _key(auger, "rotation_euler", [(0, 0.0), (frames, -2 * tau)], index=0)

    # Fragments: one per bin, evenly phased, on a ballistic arc from the
    # rotor's south-west shoulder. Scale keys with CONSTANT interpolation
    # switch each chip on and off -- it exists only while it is in flight.
    # Launched from the drum's south-west shoulder, ahead of the cheek plate so
    # the chip is not born inside it, and landing in each bin's mouth.
    launch = (ROTOR_XY[0] - 0.34, -0.98, ROTOR_Z + 0.28)
    flight = frames // 4 - 2
    for i in range(4):
        obj = bpy.data.objects.get(PREFIX + "frag%d" % i)
        if obj is None:
            continue
        start = i * (frames // 4)
        land = (BIN_X[i] + 0.10, -1.14, 0.52)
        keys = []
        for s in range(flight + 1):
            t = s / flight
            x = launch[0] + (land[0] - launch[0]) * t
            y = launch[1] + (land[1] - launch[1]) * t
            z = launch[2] + (land[2] - launch[2]) * t + 0.30 * math.sin(math.pi * t)
            keys.append(((start + s) % frames, (x, y, z)))
        for f, loc in keys:
            obj.location = loc
            obj.keyframe_insert("location", frame=f)
        _key(obj, "scale", [(0, 0.0), (start, 0.0), (start + 1, 1.0),
                            (start + flight, 1.0), (start + flight + 1, 0.0)],
             index=0, interp="CONSTANT")
        for idx in (1, 2):
            _key(obj, "scale", [(0, 0.0), (start, 0.0), (start + 1, 1.0),
                                (start + flight, 1.0), (start + flight + 1, 0.0)],
                 index=idx, interp="CONSTANT")

    # The field glow pulses with the rotor: two beats per loop, and it is the
    # only emissive that moves at all. Keep the peak at 2.2 -- Standard clips
    # hard and a violet past that turns white and takes its hue with it.
    mat = bpy.data.materials.get(PREFIX + "violet")
    if mat:
        bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        sock = bsdf.inputs["Emission Strength"]
        for f, v in ((0, 2.20), (frames // 4, 1.35), (frames // 2, 2.20),
                     (3 * frames // 4, 1.35), (frames, 2.20)):
            sock.default_value = v
            sock.keyframe_insert("default_value", frame=f)


def set_direction(deg, mirror=False):
    """Rotate the MACHINE, not the camera.

    Factorio's light is world-fixed: shadows fall the same screen direction
    whichever way a machine faces, which is why the oil refinery ships as four
    separate models rather than one orbited one. Orbiting the camera instead
    would rotate the shadow with the view and every direction but north would
    be lit wrong.
    """
    root = bpy.data.objects.get(PREFIX + "root")
    if root is None:
        root = bpy.data.objects.new(PREFIX + "root", None)
        # the master collection, not QR_Base: the render driver hides whole
        # collections per layer, and the root must survive every one of them
        bpy.context.scene.collection.objects.link(root)
        for obj in [o for o in bpy.data.objects
                    if o.name.startswith(PREFIX) and o.parent is None
                    and o is not root]:
            obj.parent = root
            obj.matrix_parent_inverse = root.matrix_world.inverted()
    root.rotation_euler = (0, 0, math.radians(deg))
    f = _FIT[0]
    # `use_mirroring` needs real mirrored art, not a flipped sprite: the light
    # is world-fixed, so flipping the PNG would carry the highlights to the
    # wrong side. Scaling the model instead keeps the key upper-left, which is
    # why vanilla ships recycler-flipped-* as its own renders.
    root.scale = (-f if mirror else f, f, f)
    # and move the heat source with it, or the tempering ramp stays pointing
    # at wherever the rotor used to be
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    hx = ROTOR_XY[0] * c - ROTOR_XY[1] * s
    hy = ROTOR_XY[0] * s + ROTOR_XY[1] * c
    for sock in _HEAT_NODES:
        sock.default_value = (-hx if mirror else hx, hy, 0.0)
    bpy.context.view_layer.update()
    return root


# --------------------------------------------------------------------------
# audit -- spend the budget deliberately and prove the sprite fits


def _world_points():
    dg = bpy.context.evaluated_depsgraph_get()
    out = []
    for ob in bpy.context.scene.objects:
        if ob.type not in ("MESH", "CURVE") or not ob.name.startswith(PREFIX):
            continue
        try:
            me = ob.evaluated_get(dg).to_mesh()
        except Exception:
            continue
        if me is None or not me.vertices:
            continue
        m = ob.matrix_world
        out.append((ob.name, [m @ v.co for v in me.vertices]))
        ob.evaluated_get(dg).to_mesh_clear()
    return out


def fit_cone(limit=None, floor=0.94):
    """Scale the whole model so its worst cone value lands exactly on APEX.

    The alternative is trimming every part that pokes out, and a 0.05 change in
    APEX put seventeen of them over at once -- each needing a different edit,
    because what binds a box is its corner, what binds a drum is the 45 degree
    point on its circle, and what binds a rib ring is neither. A uniform scale
    moves `max(|x|,|y|) + z` by exactly the same factor for every vertex, so one
    number fixes all of them and nothing changes proportion.

    `floor` is the guard that stops this becoming a way to hide a design error:
    a part left somewhere absurd would otherwise shrink the whole machine
    quietly. Below 6% the model is wrong, not oversized -- say so and do nothing.
    """
    limit = APEX if limit is None else limit
    pts = _world_points()
    if not pts:
        return 1.0
    worst = max(max(max(abs(p.x), abs(p.y)) + p.z for p in vs) for _, vs in pts)
    if worst <= limit:
        return 1.0
    s = limit / worst
    if s < floor:
        print("[fit] worst %.2f needs scale %.3f -- BELOW the %.2f floor. Not "
              "scaling: something is in the wrong place, and shrinking the "
              "machine would only hide it." % (worst, s, floor))
        return 1.0
    print("[fit] worst %.2f -> APEX %.2f by scaling the model %.4f (%.1f%% "
          "smaller inside its own footprint)" % (worst, limit, s, 100 * (1 - s)))
    return s


def audit(a):
    r = a.report()
    print("[detail] %d objects, %d distinct kinds" % (r["objects"], r["distinct_kinds"]))
    print("[detail] kinds: %s" % ", ".join(r["kinds"]))
    if r["distinct_kinds"] < 8:
        print("[detail] BELOW the audited vanilla band (8-15).")

    pts = _world_points()
    if not pts:
        return
    tallest, name = -1e9, "?"
    for nm, vs in pts:
        top = max(p.y + p.z for p in vs)
        if top > tallest:
            tallest, name = top, nm
    over = tallest - FOOTPRINT[1] / 2
    print("[detail] tallest y+z = %.2f (%s) -> north overhang %.2f tiles"
          % (tallest, name, over))
    print("[detail]   measured vanilla: chemical plant 0.77, recycler(2x4) 0.86")

    # The cone, which is NOT the line above. `y + z` is the north overhang
    # only; the constraint that covers all four rotations is
    # `max(|x|, |y|) + z`, and a part far WEST at height breaks east/west while
    # leaving the north figure untouched. This audit checked y+z alone and
    # passed a railing at max(|x|,|y|)+z = 2.61 without a word.
    worst, wname = -1e9, "?"
    offenders = []
    for nm, vs in pts:
        v = max(max(abs(p.x), abs(p.y)) + p.z for p in vs)
        if v > worst:
            worst, wname = v, nm
        if v > APEX:
            offenders.append((v, nm))
    print("[cone] worst max(|x|,|y|)+z = %.2f (%s), APEX %.2f -> overhang "
          "%.2f tiles in the worst rotation" % (worst, wname, APEX, worst - 1.5))
    if offenders:
        offenders.sort(reverse=True)
        print("[cone] %d object(s) OVER APEX -- these draw over the machine "
              "behind them in some rotation:" % len(offenders))
        for v, nm in offenders[:12]:
            print("[cone]   %.2f  %s" % (v, nm))

    # --- the silhouette, in ALL FOUR rotations ---------------------------
    # A row is full width only when the sprite's east extreme and its west
    # extreme both fall in it, so the fix is to give those two to parts whose
    # ROW ranges are disjoint. But WHICH parts those are changes with the
    # rotation: in west the extremes are the model's southernmost and
    # northernmost parts, and the rows are x + z rather than y + z. Checking
    # north alone passed this machine while west shipped 4.9% full-width rows.
    #
    # Mirroring negates screen x, which swaps the two extremes and leaves every
    # row band untouched -- so the flipped set needs no separate pass.
    MAPS = (
        ("N", lambda p: (p.x, p.y + p.z)),
        ("E", lambda p: (p.y, -p.x + p.z)),
        ("S", lambda p: (-p.x, -p.y + p.z)),
        ("W", lambda p: (-p.y, p.x + p.z)),
    )
    worst_overlap, worst_dir = -1e9, "?"
    for label, fn in MAPS:
        proj = [(nm, [fn(p) for p in vs]) for nm, vs in pts]
        east = max(max(sx for sx, _ in q) for _, q in proj)
        west = min(min(sx for sx, _ in q) for _, q in proj)

        def band(at_east, east=east, west=west, proj=proj):
            lo, hi, who = 1e9, -1e9, set()
            for nm, q in proj:
                for sx, row in q:
                    if (sx > east - 0.06) if at_east else (sx < west + 0.06):
                        lo, hi = min(lo, row), max(hi, row)
                        who.add(nm)
            return lo, hi, sorted(who)

        e_lo, e_hi, e_who = band(True)
        w_lo, w_hi, w_who = band(False)
        overlap = min(e_hi, w_hi) - max(e_lo, w_lo)
        if overlap > worst_overlap:
            worst_overlap, worst_dir = overlap, label
        verdict = ("FAIL by %.2f" % overlap) if overlap > 0 else                   ("ok by %.2f" % -overlap)
        print("[silhouette] %s  east %+.2f rows %.2f..%.2f (%s) | west %+.2f "
              "rows %.2f..%.2f (%s) -> %s"
              % (label, east, e_lo, e_hi, e_who[0] if e_who else "-",
                 west, w_lo, w_hi, w_who[0] if w_who else "-", verdict))
    if worst_overlap > 0:
        print("[silhouette] WORST %s: extremes share %.2f tiles of rows -- every "
              "row in that band is full width." % (worst_dir, worst_overlap))
    else:
        print("[silhouette] ok in all four rotations (and both mirrorings); "
              "worst margin %.2f tiles" % -worst_overlap)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[0] if argv else ".")
    out.mkdir(parents=True, exist_ok=True)

    scene = rig.empty_scene()
    a = build(build_materials())
    # Always pose, even for a one-frame look: the fragments are keyed off and
    # an unanimated frame 0 leaves all four stacked on the launch point.
    animate(frames=64)
    # Parent everything under the root, measure the cone on the real geometry,
    # then re-pose with the fitted scale. fit_cone() needs the root to exist
    # (it reads matrix_world), which is why this is two calls and not one.
    set_direction(0)
    _FIT[0] = fit_cone()
    set_direction(0)
    audit(a)

    rig.camera(scene, CANVAS)
    # ambient 0.17, not the validated 0.22. The rig's set was approved on the
    # Pure beacon; on this machine it left the raw render at luminance sd 26.5
    # against vanilla's post-processed 43-52, and a flat render makes the
    # paint-over invent contrast instead of sharpening it. Lowering the sky
    # fill deepens the crevices in the RENDER, which is where they belong.
    # Key and fill are untouched.
    rig.lights(scene, key=KEY, fill=FILL, ambient=AMBIENT)
    rig.output(scene, CANVAS)
    rig.cycles(scene, samples=96)
    scene.render.filepath = str(out / "look.png")
    bpy.ops.render.render(write_still=True)
    print("[render] %s" % (out / "look.png"))

    blend = Path(__file__).resolve().parent / "quality-recycler.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    print("[blend] %s" % blend)


if __name__ == "__main__":
    main()
