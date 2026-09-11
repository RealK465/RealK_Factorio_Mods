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
# **5.4, back down from 6.6, and the reason the hard key stopped being needed
# is that the flatness it was compensating for was never lighting.** The raw
# render measured sd 26.5 because BARE was near-white and every edge on the
# machine wore toward it -- a uniform pale film flattens an image no matter
# how hard the key is, and a harder key only pushes the film further up. At
# 6.6 `scoured` measured luminance 196 and `hazard` 208 on a flat swatch, and
# the maw rollers rendered rgb 241 at saturation 0.03: white plastic. With a
# dark BARE and the roughness spread below, contrast comes from the palette
# instead, which is where materials.md says it belongs.
KEY = float(os.environ.get("QR_KEY", "5.4"))
FILL = float(os.environ.get("QR_FILL", "1.05"))
# 0.18. Was 0.12, on the reasoning that a darker sky digs the crevices the
# paint-over cannot; true, but it was digging against a palette whose lit
# faces were pale for an unrelated reason, so it bought depth by making the
# machine murky. With the palette darkened the crevices have somewhere to go
# on their own, and the brief's "broad soft light rather than harsh point
# reflections" wants the sky doing more of the work, not less.
AMBIENT = float(os.environ.get("QR_AMBIENT", "0.18"))
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
OLIVE_LIT = srgb("#79863E")
OLIVE_DARK = srgb("#2C3116")
TEMPER_VIOLET = srgb("#61506F")     # render-sampled #5B4F6E, nudged warmer
TEMPER_BLUE = srgb("#3B5170")
BRONZE_LIT = srgb("#946844")
BRONZE_DARK = srgb("#452F22")
COPPER_LIT = srgb("#BC6A2C")
COPPER_DARK = srgb("#5E2F13")
# #837B6B, not #948E80: measured on a flat swatch under the rig, the old value
# rendered luminance 146 at saturation 0.07 -- a pale neutral, and vanilla has
# no neutral mass at all. Warmer and a step down, it reads as galvanised steel
# instead of as light grey card.
STEEL_LIT = srgb("#8C7A5E")
STEEL_DARK = srgb("#3E3226")
# materials.md: vanilla has NO neutral mass -- saturation runs inverse to
# value, so the darks carry warm oxide rather than grey.
GUNMETAL_LIT = srgb("#4A3F33")
GUNMETAL_DARK = srgb("#1B1611")
RUBBER = srgb("#141517")
HAZARD = srgb("#E9BE42")
# The pad measured luminance 178 on a swatch and 123 on the machine, which put
# the concrete inside a stop of the olive hull standing on it. A pad is the one
# surface the eye should never notice; it goes under everything.
CONCRETE_LIT = srgb("#6B5E45")
CONCRETE_DARK = srgb("#2E281D")

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
    else:
        # Blender's default grey is BRIGHTER than anything in this palette, so
        # a part with no material reads as a white bullseye and looks
        # deliberate. Two tori shipped that way in the rebuild's first pass.
        print("[mat] %s has NO MATERIAL" % (PREFIX + name))
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
# Chipped paint reveals DARK warm steel, not bright metal. At #9E9890 (lum
# 152) this was the largest single desaturator on the machine. `worn_metal`
# mixes toward BARE wherever pointiness is high, and most of a 241-object
# model IS edge -- a 0.076-tile guard bar is nearly all of it. Measured on the
# N render against the object-ID pass: the bronze guard came out
# rgb(168,151,155) at saturation 0.10, the drum core at luminance 158, and
# every part in the machine sat between 0.08 and 0.20 against vanilla's
# 0.27-0.44. That pale film over every edge is what read as "a strange bright
# reflective highlight" -- it is not a reflection at all, it is paint chipping
# to a colour lighter than the paint. Warm and dark, the chip reads as exposed
# steel and the bevel still catches the key on its own.
BARE = srgb("#6E6459")
# Verdigris: the cool blue-green oxide bronze grows in its recesses. The
# design's second zone is oxidised bronze and the machine had no green in it
# anywhere -- `bronze` rendered terracotta and `temper` sandstone, so the
# palette's secondary was competing with copper instead of contrasting it.
PATINA = srgb("#39685B")
PATINA_DARK = srgb("#1B332C")


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
               scratch=0.0, patina=0.0):
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

    # VERDIGRIS. Bronze grows a cool blue-green oxide, and where it grows is
    # not random: rain and condensate carry it DOWN and it collects in
    # recesses, while anything rubbed or handled stays bare metal. So the mask
    # is the crevice term (low AO) taken together with patchy noise, and the
    # convex edges are deliberately left out -- the edge-wear term below
    # scours them back to metal afterwards, which is what makes the patina
    # read as a film ON bronze rather than as green paint. Two tones, because
    # a single green is the "do not make it flat green" failure: bright cool
    # patina on the open surface, near-black oxidation in the deep recesses.
    if patina > 0:
        pao = nt.nodes.new("ShaderNodeAmbientOcclusion")
        pao.inputs["Distance"].default_value = 0.5
        pao_inv = math_node("SUBTRACT")
        pao_inv.inputs[0].default_value = 1.0
        nt.links.new(pao.outputs["AO"], pao_inv.inputs[1])
        # large slow patches, so the patina reads as chemistry over a whole
        # panel rather than as speckle
        pblotch = map_range((0.0, 1.0), fr=(0.40, 0.62))
        nt.links.new(noise_node(noise_scale * 0.45, detail=3.2).outputs["Fac"],
                     pblotch.inputs["Value"])
        # it runs downward: bias the mask by height so the lower half of any
        # part carries more of it
        pdrip = map_range((1.0, 0.35), fr=(-0.4, 1.2))
        nt.links.new(sep.outputs["Z"], pdrip.inputs["Value"])
        pmix = math_node("MULTIPLY")
        nt.links.new(pblotch.outputs["Result"], pmix.inputs[0])
        nt.links.new(pdrip.outputs["Result"], pmix.inputs[1])
        pseed = math_node("MAXIMUM")
        nt.links.new(pao_inv.outputs["Value"], pseed.inputs[0])
        nt.links.new(pmix.outputs["Value"], pseed.inputs[1])
        # the two oxide tones, selected by depth: deep recesses go near-black
        ptone = mix_color()
        ptone.inputs["A"].default_value = (*PATINA, 1.0)
        ptone.inputs["B"].default_value = (*PATINA_DARK, 1.0)
        nt.links.new(pao_inv.outputs["Value"], ptone.inputs["Factor"])
        pamt = math_node("MULTIPLY", patina)
        nt.links.new(pseed.outputs["Value"], pamt.inputs[0])
        greened = mix_color()
        nt.links.new(color_out, greened.inputs["A"])
        nt.links.new(ptone.outputs["Result"], greened.inputs["B"])
        nt.links.new(pamt.outputs["Value"], greened.inputs["Factor"])
        color_out = greened.outputs["Result"]

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
        # **Violet keeps the first sixth of the ramp, not the first third.**
        # The brief is explicit that purple is a HOT ACCENT concentrated at the
        # rotor, and at 0.30/0.54 it owned half the tempered half -- measured
        # on the N render, `hull-temper` came back rgb(146,129,129), a pink-grey
        # that is neither bronze nor violet and read as the machine's dominant
        # colour at 12% of the sprite. The old objection to squeezing it was
        # that the half then rendered plain orange, which is the vanilla
        # foundry's hue and the one this palette must not be; the verdigris
        # above is what answers that, and it answers it with a colour the
        # design wanted anyway rather than by spreading the accent.
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "EASE"
        e = ramp.color_ramp.elements
        e[0].position, e[0].color = 0.0, (*TEMPER_VIOLET, 1.0)
        e[1].position, e[1].color = 1.0, (*color_a, 1.0)
        for p, c in ((0.16, TEMPER_VIOLET), (0.34, TEMPER_BLUE),
                     (0.58, BRONZE_LIT)):
            el = e.new(p)
            el.color = (*c, 1.0)
        span = map_range((0.0, 1.0), fr=(0.06, 1.30))
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
    # +-30% value per object was too much by a long way and it is the direct
    # cause of the brief's "some components look like individually generated
    # objects rather than parts of one coherent industrial machine": two
    # neighbouring plates cut from the same steel could differ by 1.9x. The
    # jitter is meant to break the CG tell of one flat colour repeated, not to
    # repaint each part. +-12% still does that and the machine holds together.
    obj_info = nt.nodes.new("ShaderNodeObjectInfo")
    hue_map = map_range((0.485, 0.515))
    nt.links.new(obj_info.outputs["Random"], hue_map.inputs["Value"])
    val_map = map_range((0.88, 1.12))
    nt.links.new(obj_info.outputs["Random"], val_map.inputs["Value"])
    jitter = nt.nodes.new("ShaderNodeHueSaturation")
    nt.links.new(hue_map.outputs["Result"], jitter.inputs["Hue"])
    nt.links.new(val_map.outputs["Result"], jitter.inputs["Value"])
    nt.links.new(color_out, jitter.inputs["Color"])
    color_out = jitter.outputs["Color"]

    # edge wear: convex edges chip to bare metal, patchy via fine noise
    edge = map_range((0.0, 1.0), fr=(0.53, 0.62))
    nt.links.new(geo.outputs["Pointiness"], edge.inputs["Value"])
    # floor 0.0, not 0.25. With a floor the patch noise could only ever
    # MODULATE the chipping, never switch it off, so every edge on the machine
    # carried at least a quarter of the wear colour and the result read as a
    # uniform film -- the brief's "avoid uniform grunge", arrived at from the
    # material side. Wear that genuinely stops is what makes the wear that
    # remains read as placed.
    wear_patch = map_range((0.0, 1.0), fr=(0.38, 0.66))
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

    # **A chipped edge is slightly barer, not chromed.** This ramp used to run
    # to 0.75 while the roughness dropped 0.35 at the same mask -- so every
    # worn edge became near-white BARE at metallic 0.75 and roughness 0.35
    # lower than the panel it sat on, which is the recipe for chrome, applied
    # to every bevel on 241 objects at once. That compound was the "mirror
    # reflections / giant white highlights / chrome-like surfaces" the brief
    # rules out, and no lighting change could have reached it.
    met = map_range((metallic, min(0.60, metallic + 0.20)))
    nt.links.new(wear_amt.outputs["Value"], met.inputs["Value"])
    nt.links.new(met.outputs["Result"], bsdf.inputs["Metallic"])

    rmap = map_range((rough_lo, rough_hi))
    nt.links.new(noise_node(noise_scale * 2.1).outputs["Fac"], rmap.inputs["Value"])
    rough_worn = map_range((0.0, -1.0))
    nt.links.new(wear_amt.outputs["Value"], rough_worn.inputs["Value"])
    rough = math_node("MULTIPLY_ADD")
    rough.use_clamp = True
    nt.links.new(rough_worn.outputs["Result"], rough.inputs[0])
    rough.inputs[1].default_value = 0.12
    nt.links.new(rmap.outputs["Result"], rough.inputs[2])
    nt.links.new(rough.outputs["Value"], bsdf.inputs["Roughness"])

    # Restrained specular, per the brief's reflection philosophy. The default
    # dielectric level of 0.5 puts a broad white lobe on every rough painted
    # surface under a sun this size, and a white lobe on a coloured panel is
    # exactly the "materials merge because their specular response is too
    # similar" complaint: it is the same colour on every zone. Painted and
    # oxidised surfaces get less of it; the bare and polished ones keep more,
    # which is what separates them.
    try:
        spec = 0.50 if metallic >= 0.40 else 0.28
        bsdf.inputs["Specular IOR Level"].default_value = spec
    except KeyError:
        pass

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
# **Nine bands of roughly equal width read as a deck-chair stripe, not as a
# wound drum.** Each band was ~0.16 tiles -- 10 px at 64 px/tile -- so the
# drum alternated bright/dark every 10 px across its whole flank and the eye
# resolved a pattern instead of a cylinder. The bands are now unequal: wide
# tempered zones carrying the colour, with NARROW copper binding rings between
# them. Same nine pieces, same materials, and the drum reads as one form with
# rings on it. The winding texture comes from the 14 axial ribs instead, which
# is where it belongs -- a winding runs along a rotor, not around it.
# **The radii TAPER, and that is what makes it read as a barrel.** With every
# band within 0.03 of the same radius the drum had no curvature in its own
# silhouette, so the 12 axial ribs crossing 9 band edges resolved as a window
# pane -- a flat lattice of copper mullions over coloured glass, which is
# roughly the opposite of a heavy spinning rotor. Ends at 0.575 against a
# middle at 0.640 give the flank a visible curve, and it also puts the end
# flanges (0.642 and 0.655) proud of the barrel they cap, which is how a real
# drum is built.
# **The hottest band is the MIDDLE one, and it was the two flanking ones.**
# The drum's windings run hottest at its centre and the heat leaves through
# the bearings at each end, so tempering runs violet at the middle, straw and
# bronze toward the flanges, bare bronze at the collars. The old table had the
# violet on both wide flanking zones with a blue one between them -- two large
# saturated purple areas separated by a teal one, which is neither physical nor
# localized, and it is most of why the drum read as a stained-glass barrel.
# Violet is now a single band across the drum's waist: one accent, at the
# hottest point, exactly where the brief wants it.
ROTOR_BANDS = [
    (-0.73, -0.60, 0.575, "bronze"),    # end collar, out of the heat
    (-0.60, -0.54, 0.600, "copper"),    # binding ring
    (-0.54, -0.26, 0.628, "tempers"),   # straw / bronze temper
    (-0.26, -0.20, 0.612, "copper"),    # binding ring
    (-0.20, 0.14, 0.640, "temperv"),    # the hot waist -- the violet accent
    (0.14, 0.20, 0.612, "copper"),      # binding ring
    (0.20, 0.48, 0.628, "tempers"),     # straw / bronze temper
    (0.48, 0.54, 0.600, "copper"),      # binding ring
    (0.54, 0.73, 0.575, "bronze"),      # end collar
]
# The olive hood's axis, at module scope because animate() needs the fan
# pivot on it and build() needs the barrel there.
HOOD_CENTRE, HOOD_RADIUS = (-0.70, 1.06), 0.30
GEAR_XY = (-0.02, -1.14)
GEAR_Z, GEAR_R = 0.44, 0.26
MAW = (-1.18, -0.42, 0.20, 0.86)                # x0, x1, z0, z1 of the opening
MAW_MID_X, MAW_MID_Y = (MAW[0] + MAW[1]) / 2, -1.25
# Screen row is -(y + z), so a roller set DEEPER in the recess appears HIGHER
# on screen and disappears behind the lintel. The visible band is bounded by
# the opening's own top edge at `y_face + z_top`: here -1.30 + 0.86 = -0.44,
# so a roller at y -1.25 stays visible only while z + r < 0.81.
MAW_ROLLER_Z = (0.345, 0.555, 0.765)
MAW_ROLLER_R = 0.105
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
                "rotor-hub", "rotor-bolts", "rotor-cap", "gear-disc",
                "gear-teeth", "maw-roller", "maw-teeth", "auger-belt",
                "auger-flight", "fan-hub", "fan-blade", "flap-")
FX_KINDS = ("frag", "arc")
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
        # roughness 0.66-0.90, up from 0.52-0.80, and rust 0.40 -> 0.22.
        # This is OLD PAINT and the brief puts it at the matte end of the
        # hierarchy; at 0.52 it shared its specular response with bare steel,
        # which is one of the two ways the zones were merging. The rust came
        # down because a maintained machine is not a rusty one -- at 0.40 the
        # mottling ate the olive and the swatch read dirty grey-green rather
        # than paint. Large calm areas, dirt in the streaks, chips on the
        # edges: the "maintained, not abandoned" the brief asks for.
        # 2026-09-11: rust 0.22 -> 0.10 and grime 0.40 -> 0.26. Measured on a
        # lit swatch, the old settings rendered (73, 67, 45) at luminance 66 and
        # hue 48 -- RED-dominant khaki. The vanilla recycler's own olive-green
        # measures (96, 106, 57) at luminance 101 and is GREEN-dominant by ten
        # points. Rust is a red mix and grime pulls toward OLIVE_DARK, so
        # between them they were turning the identity paint into mud on the
        # machine's largest painted surface.
        "olive": worn_metal("olive", OLIVE_LIT, OLIVE_DARK, 0.16, 0.66, 0.90,
                            grime=0.31, wear=0.46, rust=0.12, grain=0.28,
                            grain_slug="rusty_painted_metal", noise_scale=8.0),
        # 1b. the same paint, lower down and dirtier. Grime pools toward the
        #     ground on a real machine and the camera reads the resulting
        #     vertical gradient as light direction; a uniform hull reads flat
        #     however good the key is.
        "olived": worn_metal("olived", srgb("#4E5729"), srgb("#1C2010"), 0.16,
                             0.70, 0.92, grime=0.52, wear=0.34, rust=0.16,
                             grain=0.30, grain_slug="rusty_painted_metal",
                             noise_scale=8.0),
        # 2. the new half: bronze tempered violet/blue toward the rotor
        # heat 0.62, not 0.92. The ramp is a function of distance from the
        # rotor and the tempered half is ALL near the rotor, so at 0.92 the
        # whole half landed on violet and the machine read grey-mauve. The
        # concept sheet is bronze with the violet concentrated at the drum;
        # 0.62 leaves bronze showing at the extremities, which is what makes
        # the tempering read as a gradient rather than as a paint job.
        # Both carry `patina` now, which is what turns the design's "verdigris
        # bronze" from a label into a colour. Roughness up to 0.54-0.84 and
        # 0.50-0.80: an oxide film is the roughest thing on the machine after
        # the paint, and at 0.30 these two were reading as polished sheet.
        # heat 0.62 -> 0.44 on the hull for the same reason the ramp was
        # tightened -- the tempered half is ALL near the rotor, so the mix
        # factor is what decides how much of it goes mauve.
        "temper": worn_metal("temper", BRONZE_LIT, BRONZE_DARK, 0.38, 0.54, 0.84,
                             grime=0.20, wear=0.40, rust=0.16, heat=0.32,
                             heat_from=ROTOR_XY, grain=0.18, noise_scale=7.0,
                             patina=0.14),
        "bronze": worn_metal("bronze", BRONZE_LIT, BRONZE_DARK, 0.40, 0.50, 0.80,
                             grime=0.22, wear=0.44, rust=0.18, heat=0.30,
                             heat_from=ROTOR_XY, grain=0.16, noise_scale=9.0,
                             # 0.52 -> 0.10. PATINA IS A GREEN (#39685B), and
                             # zone 2 stopped being verdigris when it became
                             # heat-tempered bronze -- but the term stayed. On
                             # a lit swatch `bronze` rendered (113, 115, 78):
                             # green-dominant grey, not bronze at all, on the
                             # rotor well and the seam, which are two of the
                             # three largest curved surfaces in the sprite.
                             patina=0.10),
        # 2b. THE DRUM'S BANDS -- and this is the pair that produced the
        #     defect the brief opens with. `temperv` #6E4A7C and `temperb`
        #     #33506F are saturated purple and teal at roughness 0.26 and
        #     metallic 0.40, laid as wide smooth zones on a 1.26-tile barrel
        #     with copper ribs crossing them. That is stained glass with gold
        #     mullions, and it is what "a strange bright reflective-looking
        #     highlight that reads like an artificial reflection" describes: a
        #     large, smooth, semi-gloss coloured surface, on the one object
        #     that owns 40% of the sprite.
        #
        #     They are replaced by a real tempering SERIES, not two colours.
        #     Steel running hot goes straw -> bronze -> violet -> blue, and an
        #     oxide film is DARK and ROUGH -- it is a few hundred nanometres of
        #     interference colour over grey metal, not enamel. So both tones
        #     sit at half the old luminance, roughness triples, and they are
        #     near enough each other in value that the drum reads as one form
        #     with heat across it. The violet is still there, still physical,
        #     and confined to the drum's hot middle, which is exactly the
        #     brief's "keep the hottest region localized".
        #
        #     `patina` is deliberately absent here: verdigris is a slow wet
        #     oxide and this surface is too hot to grow one. The two zones stay
        #     legible from each other for that reason.
        "temperv": worn_metal("temperv", srgb("#4B3A56"), srgb("#1D1622"), 0.34,
                              0.48, 0.78, grime=0.18, wear=0.34, rust=0.12,
                              grain=0.22, noise_scale=11.0),
        "tempers": worn_metal("tempers", srgb("#5C4B33"), srgb("#241C13"), 0.34,
                              0.48, 0.78, grime=0.18, wear=0.34, rust=0.14,
                              grain=0.22, noise_scale=11.0),
        # 3. bare / galvanised steel: frame, ducts, catwalk, auger housing
        # BARE WORN STEEL is the one zone the brief allows to be moderately
        # reflective, so it keeps the lowest roughness of the structural
        # materials -- that separation is now doing work, because the paint
        # above it went to 0.66 and the oxide beside it to 0.50.
        "steel": worn_metal("steel", STEEL_LIT, STEEL_DARK, 0.40, 0.38, 0.64,
                            grime=0.28, wear=0.46, rust=0.30, grain=0.20,
                            noise_scale=10.0),
        # 4. dark iron / gunmetal: bin mouths, housings, every recess.
        #    Warm, not grey -- vanilla has no neutral mass.
        "gunmetal": worn_metal("gunmetal", GUNMETAL_LIT, GUNMETAL_DARK, 0.34,
                               0.56, 0.86, grime=0.34, wear=0.30, rust=0.34,
                               noise_scale=11.0),
        # 4b. the shredder throat, and only that. The maw is the olive half's
        #     whole identity and it has to read as a HOLE: the first build lined
        #     it in gunmetal and filled it with scoured teeth, so the brightest
        #     thing on the front elevation was the cavity, and it came out as a
        #     grey grille rather than a mouth. Cycles' AO does the rest once the
        #     surface is dark enough to have somewhere to go.
        "cavity": worn_metal("cavity", srgb("#241F19"), srgb("#0A0806"), 0.28,
                             0.72, 0.95, grime=0.46, wear=0.16, rust=0.26,
                             noise_scale=12.0),
        # 4c. THE MAW THROAT, darker still. `cavity` renders luminance 46, and
        #     against it the scoured rollers and their teeth merged into an
        #     evenly striped band -- the maw read as a LOUVRE VENT rather than
        #     as teeth. Teeth need something to cut into, so the back wall and
        #     the jambs go to a near-black that the tooth tips can break.
        "pitch": worn_metal("pitch", srgb("#14110D"), srgb("#050403"), 0.24,
                            0.78, 0.96, grime=0.50, wear=0.10, rust=0.18,
                            noise_scale=12.0),
        # 5. copper: windings, pole faces, the seam collar.
        #    Metallic 0.42, not 0.62: a metal surface has only the dim world to
        #    reflect, so the pole faces rendered near-black at 0.62 and the
        #    hero's one bright material read as grey bars. Tempering is kept
        #    light here for the same reason -- copper that goes violet stops
        #    being copper.
        # roughness 0.32-0.56, up from 0.20-0.42: the brief puts copper at
        # "medium-low", one step BELOW bare steel rather than at the polished
        # end, and at 0.20 the binding rings and ribs were the glossiest thing
        # on the machine. Copper is meant to be the richest accent, and rich
        # is not the same as shiny -- what makes it read as copper is the warm
        # hue holding through both a lit face and a shaded one, which a broad
        # white specular lobe was washing out.
        "copper": worn_metal("copper", COPPER_LIT, COPPER_DARK, 0.44, 0.32, 0.56,
                             grime=0.14, wear=0.34, rust=0.14, heat=0.10,
                             heat_from=ROTOR_XY, noise_scale=14.0),
        # 6. rubber black: cables, hose runs, the auger belt
        "rubber": rubber("rubber"),
        # The material path, polished by what passes through it -- and the
        # single brightest thing in the machine until now. Measured on a flat
        # swatch under the rig it rendered luminance 196 at saturation 0.07,
        # and on the model the maw rollers came back rgb 241 at saturation
        # 0.03: white plastic, on the three parts sitting inside the shredder
        # mouth. #857C6C at roughness 0.30-0.52 still reads as the one surface
        # rubbed clean -- "localized higher reflectivity", which only means
        # anything if it is local. The `scratch` term keeps the directional
        # polish that makes it a material rather than a value.
        "scoured": worn_metal("scoured", srgb("#8E7C62"), STEEL_DARK, 0.42,
                              0.30, 0.52, grime=0.22, wear=0.44, rust=0.16,
                              scratch=0.50, noise_scale=13.0),
        "concrete": worn_metal("concrete", CONCRETE_LIT, CONCRETE_DARK, 0.0,
                               0.82, 0.97, grime=0.36, wear=0.16, rust=0.24,
                               noise_scale=6.0),
        # HAZARD is the brief's one limited yellow, and it rendered luminance
        # 208 -- brighter than anything else including the hero. Paint
        # roughness, and the wear pulled back from 0.72: chevrons scoured to
        # bare metal stop being chevrons.
        "hazard": worn_metal("hazard", HAZARD, srgb("#7A5C1B"), 0.14, 0.60, 0.88,
                             grime=0.24, wear=0.52, rust=0.20, noise_scale=16.0),
        "glass": plain("glass", srgb("#B8C4C0"), metallic=0.1, rough=0.18),
        # strength 1.5, not 2.2. The glow gets its own additive layer, so the
        # only job the slot has in the BASE sheet is to look like a lit slot --
        # and at 2.2 under Standard's hard clip the two pairs became flat
        # magenta bars across the middle of the machine, which is exactly the
        # "giant purple aura" the design rules out.
        "violet": plain("violet", (0.02, 0.01, 0.03), emission=VIOLET_EMIT,
                        strength=1.25),
        # strength 1.2, not 1.9. Standard clips hard, and the rule is that the
        # MAX EMITTED CHANNEL (colour x strength) has to stay near 1.0 or the
        # hue clips out and the lamp goes white. LED_GREEN's top channel is
        # 0.75 linear, so 1.9 landed at 1.4 and the lamp was a white pip.
        # strength 0.65, not 1.2. The lamp is drawn twice -- lit in the base
        # sheet AND added by its own `always_draw` glow layer -- and at 1.2
        # the sum clipped to a white dot on the hazard band, which is the
        # one place a GREEN lamp had to stay green.
        "led": plain("led", (0.02, 0.03, 0.02), emission=LED_GREEN,
                     strength=0.45),
        # the concept sheet's amber beacon, on top of the salvaged half. Kept
        # well clear of the foundry's 15 deg and legendary's 35: this is a
        # running lamp, not a quality tier.
        # strength 1.0, not 1.9, and this was the loudest defect in the glow
        # sheet. #FF8A12 has a full 1.0 red channel, so at 1.9 every pixel of
        # the beacon clipped to pure white and the additive layer put a blown
        # orange egg on the machine in all eight directions -- measured max
        # (255, 255, 255) over the lamp. At 1.0 it stays amber.
        "amber": plain("amber", (0.03, 0.02, 0.005), emission=srgb("#FF8A12"),
                       strength=1.0),
    }
    # The bin lips carry the quality ramp, but as WORN PAINT on a machine, not
    # as UI chips. Vanilla's identity paint is desaturated and confined; the
    # first render put four saturated rectangles at the front of the sprite and
    # they read as sweets, pulling the eye clean off the hero. Mixing each
    # tier two-thirds of the way to the gunmetal keeps the four grades legible
    # by hue while leaving the rotor the brightest thing on the machine.
    for i, c in enumerate(QUALITY_LIP):
        lit = tuple(0.26 * a + 0.74 * b for a, b in zip(c, GUNMETAL_LIT))
        dark = tuple(v * 0.42 for v in lit)
        m["lip%d" % i] = worn_metal("lip%d" % i, lit, dark, 0.18, 0.62, 0.88,
                                    grime=0.30, wear=0.50, rust=0.30,
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
    # FINER, and still copper. Bronze was tried and is wrong here for a reason
    # worth keeping: `bronze` carries heat 0.45 off the rotor and the ribs sit
    # ON the rotor, so they took the ramp at full strength and came out pale
    # lavender -- cream bars on a violet drum, which read as a fairground ride.
    # `copper` carries heat 0.14 precisely so it stays copper this close in.
    # What was actually wrong was the SIZE: At half-width 0.026 in copper these
    # were the brightest thing on the machine and the drum read as gold
    # mullions over coloured glass; the copper belongs to the narrow binding
    # rings and the two end flanges, which is where the eye should go. 16 ribs
    # at 0.017 read as ribbing rather than as bars, and still carry the turn --
    # which is the whole reason they exist, since concentric bands are
    # rotationally symmetric and a banded drum spinning shows no motion at all.
    ribs = []
    for i in range(16):
        ang = 2 * math.pi * i / 16
        px, pz = rx + 0.648 * math.cos(ang), rz + 0.648 * math.sin(ang)
        ribs.append(((px - 0.017, ry - 0.42, pz - 0.017),
                     (px + 0.017, ry + 0.42, pz + 0.017)))
    made.append(boxes("rotor-ribs", ribs, mat="copper", cuts=1, bevel=0.004))
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
    # The NORTH end gets a flange too, and it is not symmetry for its own sake.
    # The drum turns about Y, so in the EAST and WEST rotations its axis lies
    # along the camera's transverse axis and the barrel goes edge-on -- it
    # renders as a flat striped panel with no roundness, which is the same
    # projection fact that ruled the X axis out in the first place and it
    # cannot be avoided for two of four rotations. What CAN be fixed is that
    # the one round feature left, the end flange, existed at one end only, so
    # east and west each showed a bare cut tube on one side. Two ends read as
    # a rotor between two bearings from every direction.
    made.append(cyl("rotor-flange-n", (rx, ry + 0.765, rz), 0.642, 0.05,
                    axis=ROTOR_AXIS, mat="copper", seg=32, rings=1))
    # no hub or bolt circle behind it: both measured zero pixels, for the same
    # reason the north pillow block did.

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
    # The far bearing wall, as TWO PIERS with a window between them. As one
    # slab it was 3.07% of the sprite -- the fourth-largest object on the
    # machine -- and it sealed the drum's north end in: the object-ID pass
    # found `rotor-flange-n`, `rotor-hub-n`, `rotor-bolts-n` and the entire
    # north pillow block drawing ZERO pixels behind it. A wall that carries a
    # bearing is two piers with the bearing between them anyway, so the window
    # is more mechanically legible than the slab was, and it converts the
    # machine's fourth-biggest flat area into an opening onto the hero.
    made.append(boxes("cheek-n", [
        ((-0.24, 0.78, DECK), (0.20, 0.92, 1.30)),
        ((0.72, 0.78, DECK), (0.90, 0.92, 1.30)),
        ((0.90, 0.78, DECK), (1.14, 0.92, 1.14)),
        ((0.20, 0.78, 1.18), (0.72, 0.92, 1.30)),      # lintel over the window
        ((0.20, 0.78, DECK), (0.72, 0.92, 0.30)),      # sill under it
    ], mat="temper", cuts=3))

    # ring-gear drive, half-buried in the salvaged housing so the seam is
    # mechanical rather than cosmetic -- a gear emerging from the olive block
    # and meshing on the drum's lower west quadrant.
    # **The gear was buried and drew nothing.** At y -1.01 it sat inside
    # `rotor-house` (y -1.06..-0.94), so the design's one mechanical link
    # between the salvaged half and the new one -- the thing that makes the
    # seam a drive rather than a paint line -- was invisible in all four
    # rotations. GEAR_XY moved to y -1.14, outboard of that wall, where it
    # meshes on the drum's lower west quadrant in plain sight.
    gx, gy = GEAR_XY
    made.append(cyl("gear-disc", (gx, gy, GEAR_Z), GEAR_R, 0.08, axis="Y",
                    mat="steel", seg=30))
    # its guard: a part-ring shroud over the top of the mesh, open at the front
    made.append(cyl("gear-shroud", (gx, gy, GEAR_Z), GEAR_R + 0.055, 0.05,
                    axis="Y", mat="gunmetal", seg=30))
    teeth = []
    for i in range(18):
        ang = 2 * math.pi * i / 18
        tx = gx + (GEAR_R + 0.022) * math.cos(ang)
        tz = GEAR_Z + (GEAR_R + 0.022) * math.sin(ang)
        teeth.append(((tx - 0.030, gy - 0.048, tz - 0.030),
                      (tx + 0.030, gy + 0.042, tz + 0.030)))
    made.append(boxes("gear-teeth", teeth, mat="steel", cuts=0, bevel=0.005))

    # PILLOW BLOCKS. A drum floating between two flat walls reads as a barrel
    # sitting on a machine; a drum in split bearings reads as a rotor. Each is
    # a pedestal, a split cap with its own bolt pair, and a grease nipple --
    # the same silhouette a real plummer block has, and the detail that says
    # "this spins fast" without a single glowing pixel.
    # ONE pillow block, not two, and the missing one is a measurement rather
    # than an economy: the object-ID pass found the north block drawing zero
    # pixels in all four rotations. In north the drum itself is in front of it;
    # in south the rear deck tops out at 1.06 against the block's 1.05 and
    # covers it. Splitting `cheek-n` into piers to open a window on it did not
    # help, because the occluder is never the wall. The north end still reads:
    # `rotor-flange-n` is outboard of all of it and does show.
    for i, (by, cap_r) in enumerate(((-0.90, 0.19),)):
        made.append(boxes("bearing-ped%d" % i, [
            ((rx - 0.24, by - 0.075, DECK), (rx + 0.24, by + 0.075, rz - 0.02)),
            ((rx - 0.30, by - 0.095, DECK), (rx + 0.30, by + 0.095, 0.28)),
        ], mat="steel", cuts=2, bevel=0.012))
        made.append(cyl("bearing-cap%d" % i, (rx, by, rz), cap_r, 0.15,
                        axis="Y", mat="gunmetal", seg=20, rings=1))
        made.append(boxes("bearing-bolt%d" % i, [
            ((rx - 0.215, by - 0.045, rz - 0.10), (rx - 0.155, by + 0.045, rz + 0.04)),
            ((rx + 0.155, by - 0.045, rz - 0.10), (rx + 0.215, by + 0.045, rz + 0.04)),
        ], mat="scoured", cuts=1, bevel=0.008))
    # grease line to the south bearing, from a small reservoir on the apron
    made.append(cyl("grease-pot", (1.02, -0.62, 0.66), 0.075, 0.16,
                    mat="bronze", seg=16))

    # THE GUARD, over the drum's west shoulder. It cannot go over the crown:
    # for an arc about Y the cone binds at the 45 degree point, x0 + z0 +
    # r*sqrt(2), and at the drum's own 0.63 that is already 2.21 of 2.25. The
    # west shoulder is where |x| is SMALLEST, so an arc has room there and only
    # there -- which happens to be exactly where a guard belongs, between the
    # spinning rotor and the walkway at the seam.
    # It also has to stay off the drum's SOUTH flank. Screen row is -(y + z),
    # so a hoop spanning the drum's length draws straight down the banded face
    # the whole hero read depends on -- the first cut of this part put nine
    # bronze bars across the copper and the drum went grey. Confined to the
    # NORTH third, it appears ABOVE the drum instead and pays for itself in
    # skyline.
    guard = []
    for i in range(9):
        th = math.radians(96.0 + i * 9.5)
        gx_ = rx + 0.70 * math.cos(th)
        gz_ = rz + 0.70 * math.sin(th)
        guard.append(((gx_ - 0.038, 0.30, gz_ - 0.038),
                      (gx_ + 0.038, 0.74, gz_ + 0.038)))
    made.append(boxes("rotor-guard", guard, mat="bronze", cuts=1, bevel=0.008))
    made.append(boxes("guard-stay", [
        ((-0.10, 0.30, 1.06), (0.04, 0.44, 1.30)),
        ((-0.10, 0.62, 1.06), (0.04, 0.76, 1.30)),
    ], mat="bronze", cuts=1, bevel=0.008))

    # The catwalk at the seam, which the design lists and the model never had.
    # A grating deck on two brackets, tucked in the trough between the olive
    # hood and the drum guard where nothing else is competing.
    made.append(boxes("catwalk", [
        ((-0.30, -0.66, 0.99), (-0.13, 0.62, 1.05)),
        ((-0.31, -0.66, 0.94), (-0.28, 0.62, 1.00)),
        ((-0.15, -0.66, 0.94), (-0.12, 0.62, 1.00)),
    ], mat="steel", cuts=2, bevel=0.008))
    grating = []
    for i in range(11):
        gy_ = -0.60 + i * 0.118
        grating.append(((-0.29, gy_, 1.05), (-0.14, gy_ + 0.045, 1.068)))
    made.append(boxes("catwalk-grate", grating, mat="gunmetal", cuts=0,
                      bevel=0.004))

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
        ((-1.32, -0.92, DECK), (-0.24, 0.94, 0.96)),        # T1 body
        ((-1.12, -1.06, 0.96), (-0.30, 0.70, 1.12)),        # T2
    ], mat="olive", cuts=3))

    # T3 WAS a third flat slab and it is now a rounded hood, because the flat
    # slab is what made this machine read as a plan view. Two 0.6-1.5 tile
    # plates stacked with nothing on them is ~2 tiles of dead deck, and the
    # camera sees the deck more than anything else. Vanilla never does it: the
    # chemical plant is vessels and tubes end to end, and the vanilla recycler
    # tops out in rounded tank forms. A barrel reads as machinery at any zoom
    # where a plate reads as a lid.
    #
    # Cone, worked for a cylinder about Y at centre (cx, cz) radius r, which is
    # NOT the same as for a box: on the circle |x| + z = |cx| + cz +
    # r*sqrt(2)*sin(theta - 45), so the binding point is the 45 degree point,
    # 0.424 above the centre here -- and separately |y|max + cz + r must clear
    # it at the ends. 0.70 + 1.06 + 0.424 = 2.18 and 0.88 + 1.06 + 0.30 = 2.24,
    # against APEX 2.25.
    HOOD_C, HOOD_R = HOOD_CENTRE, HOOD_RADIUS
    made.append(cyl("hood", (HOOD_C[0], -0.15, HOOD_C[1]), HOOD_R, 1.46,
                    axis="Y", mat="olive", seg=26, rings=3))
    # End plates, proud of the barrel, with a bolt circle on the south one --
    # the end the camera actually sees. A bare tube end reads as a cut pipe.
    for i, (yy, rr) in enumerate(((-0.90, 0.335), (0.60, 0.325))):
        made.append(cyl("hood-cap%d" % i, (HOOD_C[0], yy, HOOD_C[1]), rr, 0.05,
                        axis="Y", mat="steel", seg=26, rings=1))
    a.place("greeble:bolt_ring", at=(HOOD_C[0], -0.93), z=HOOD_C[1], size=0.50,
            mat="steel", count=10, name="hood-bolts")
    # Two strap bands round the barrel. Repetition that reads as manufactured,
    # and they give the AO a seam to sit in on an otherwise smooth sweep.
    for i, yy in enumerate((-0.52, 0.20)):
        made.append(cyl("hood-strap%d" % i, (HOOD_C[0], yy, HOOD_C[1]),
                        HOOD_R + 0.022, 0.07, axis="Y", mat="steel", seg=26,
                        rings=1))
    # A louvred inspection panel let into the hood's west flank, and a lifting
    # eye on the crown. Both earn their place: the hood covers the shredder
    # drive, so it needs a way in and a way to lift.
    a.place("greeble:louvre_bank", at=(-0.94, -0.62), z=1.14, size=0.30,
            mat="gunmetal", name="hood-vent")
    # FITTINGS along the crown. A bare barrel is the same mistake as a bare
    # plate one scale up -- it swaps a flat fill for a smooth gradient, and the
    # form/grain split says vanilla carries its contrast in the 1-3 px band, not
    # in broad shading. These are all small and hard-edged on purpose.
    a.run("greeble:pipe_run", [(-0.62, -0.80, 1.34), (-0.62, -0.20, 1.36),
                               (-0.58, 0.34, 1.33)],
          radius=0.045, mat="copper", name="hood-main")
    made.append(boxes("hood-clamps", [
        ((-0.70, -0.62, 1.30), (-0.54, -0.57, 1.40)),
        ((-0.70, 0.02, 1.30), (-0.54, 0.07, 1.40)),
    ], mat="steel", cuts=1, bevel=0.006))
    # an inspection plate let into the crown, bolted, with its own lifting eye
    made.append(boxes("hood-plate", [
        ((-0.86, -0.36, 1.31), (-0.72, 0.06, 1.37)),
    ], mat="steel", cuts=1, bevel=0.008))
    a.place("greeble:bolt_ring", at=(-0.79, -0.15), z=1.375, size=0.16,
            mat="steel", count=6, name="hood-plate-bolts")
    a.place("greeble:gauge_pod", at=(-0.86, 0.36), z=1.26, size=0.11,
            mat="steel", face_material=mats["glass"], name="hood-gauge")
    # A COOLING FAN on the hood's south cap -- the end the camera faces in
    # north, and about Y like everything else that turns here, because a disc
    # about X is exactly edge-on to this rig. It is the machine's fourth moving
    # part and the only one that is not in the material path, which is what
    # makes the animation read as several systems rather than one drivetrain.
    made.append(cyl("fan-hub", (HOOD_C[0], -0.945, HOOD_C[1]), 0.052, 0.055,
                    axis="Y", mat="gunmetal", seg=16))
    blades = []
    for i in range(6):
        ang = 2 * math.pi * i / 6
        for t in (0.11, 0.155, 0.20):
            bx = HOOD_C[0] + t * math.cos(ang)
            bz = HOOD_C[1] + t * math.sin(ang)
            blades.append(((bx - 0.030, -0.962, bz - 0.030),
                           (bx + 0.030, -0.930, bz + 0.030)))
    made.append(boxes("fan-blade", blades, mat="steel", cuts=0, bevel=0.005))
    # An annulus built from segments, NOT `cyl` -- cyl makes a solid disc, and
    # the first cut of this put a 0.235 lid straight over the hub it was meant
    # to surround. The object-ID pass caught it; the render would not have.
    rim = []
    for i in range(24):
        ang = 2 * math.pi * i / 24
        px_ = HOOD_C[0] + 0.235 * math.cos(ang)
        pz_ = HOOD_C[1] + 0.235 * math.sin(ang)
        rim.append(((px_ - 0.032, -0.968, pz_ - 0.032),
                    (px_ + 0.032, -0.938, pz_ + 0.032)))
    made.append(boxes("fan-ring", rim, mat="gunmetal", cuts=0, bevel=0.005))
    a.place("greeble:junction_box", at=(-0.50, -0.62), z=1.20, size=0.20,
            mat="gunmetal", name="hood-junction")
    made.append(boxes("maw-frame", [
        ((-1.32, -1.30, DECK), (MAW[0], -0.92, 0.98)),      # west jamb
        ((MAW[1], -1.30, DECK), (-0.24, -0.92, 0.98)),      # east jamb
        ((MAW[0], -1.30, DECK), (MAW[1], -0.92, MAW[2])),   # sill
        ((MAW[0], -1.30, MAW[3]), (MAW[1], -0.92, 0.98)),   # lintel
    ], mat="olive", cuts=3))
    # panel plates on T1's exposed deck, with seams between them
    made.append(boxes("deck-plates", [
        ((-1.26, -1.24, 0.96), (-0.74, -0.98, 1.02)),
        ((-0.66, -1.24, 0.96), (-0.28, -0.98, 1.02)),
        ((-1.28, -0.88, 0.96), (-1.16, 0.62, 1.02)),
        ((-1.28, 0.70, 0.96), (-0.32, 0.90, 1.02)),
    ], mat="olive", cuts=2, bevel=0.010))
    # THE SHREDDER DRIVE, and the thing this machine has never had: the maw
    # rollers turn and nothing on the model turned them. Motor -> gearbox ->
    # drive sprocket -> belt guard down to the roller shafts, all on T2's
    # exposed south deck where the camera looks. Cone at |y| 1.02 allows 1.23.
    #
    # The motor lies about Y, never X: a cylinder about the transverse axis is
    # edge-on to this camera and renders as a stripe whatever its diameter.
    made.append(cyl("drive-motor", (-0.94, -0.86, 1.06), 0.155, 0.42,
                    axis="Y", mat="gunmetal", seg=22, rings=2))
    made.append(cyl("drive-motor-cap", (-0.94, -1.08, 1.06), 0.125, 0.05,
                    axis="Y", mat="steel", seg=22, rings=1))
    # cooling ribs on the motor barrel -- eight axial fins, the read that says
    # "electric motor" rather than "tin can" at 20 px.
    fins = []
    for i in range(10):
        ang = 2 * math.pi * i / 10
        fx = -0.94 + 0.163 * math.cos(ang)
        fz = 1.06 + 0.163 * math.sin(ang)
        fins.append(((fx - 0.017, -1.04, fz - 0.017), (fx + 0.017, -0.68, fz + 0.017)))
    made.append(boxes("drive-fins", fins, mat="gunmetal", cuts=0, bevel=0.004))
    made.append(boxes("gearbox", [
        ((-0.80, -1.04, 0.96), (-0.56, -0.72, 1.20)),
        ((-0.83, -1.00, 1.02), (-0.53, -0.76, 1.10)),      # split-line flange
    ], mat="steel", cuts=2, bevel=0.010))
    a.place("greeble:bolt_ring", at=(-0.665, -0.88), z=1.205, size=0.20,
            mat="steel", count=6, name="gearbox-bolts")
    # the belt guard: a flat-sided sheet-metal cover sloping from the gearbox
    # output down the south wall to the roller shafts inside the maw.
    # y -1.125..-1.075 and a 1.09 top, not -1.155/1.16: at |y| 1.155 the cone
    # allows 1.095, and the first cut of this part alone took fit_cone from
    # 0.972 to 0.949 -- a 2.3% uniform shrink of the WHOLE machine to pay for
    # one bracket 0.06 too far south.
    made.append(xz_prism("belt-guard", [[
        (-0.70, 1.09), (-0.50, 1.09), (-0.44, 0.60), (-0.62, 0.56),
    ]], -1.125, -1.075, mat="steel", cuts=2, bevel=0.008))
    made.append(cyl("drive-sprocket", (-0.60, -1.145, 0.99), 0.105, 0.05,
                    axis="Y", mat="scoured", seg=18, rings=1))
    # Proud panels on the stepped south faces. The camera sees exactly two
    # surfaces of a building -- the deck and the -Y wall -- and this machine's
    # -Y wall is two thirds olive paint with a chevron band on it. A bevelled
    # plate standing 0.02 off the wall costs nothing and gives the AO a seam to
    # sit in, which is what stops a large painted face reading as a flat fill.
    # Proud stiles and recessed panels on the south wall. Real geometry, not a
    # texture: the flat-fill tell is a value problem and only a seam the AO can
    # pool in fixes it. The two rails at 0.30 and 0.92 turn the wall into three
    # bands, which is what the vanilla recycler's own front does.
    made.append(boxes("olive-panels", [
        ((-1.28, -1.325, 0.28), (-1.20, -1.30, 0.94)),     # T1 west stile
        ((-0.40, -1.325, 0.28), (-0.26, -1.30, 0.94)),     # T1 east stile
        ((-1.28, -1.325, 0.28), (-0.26, -1.30, 0.34)),     # bottom rail
        ((-1.28, -1.325, 0.88), (-0.26, -1.30, 0.94)),     # top rail
    ], mat="olive", cuts=1, bevel=0.008))
    # THE OTHER THREE WALLS. "A side wall renders as a one-pixel line" is true
    # of a FIXED entity; this one rotates, so the west wall IS the front
    # elevation in east, the north wall is in south, and the east apron is in
    # west. Only the south wall had ever been treated, and the other three
    # rotations were reading as blank painted plates because of it. Same stile
    # and rail language, so the machine looks like one piece of equipment from
    # every side.
    made.append(boxes("olive-panels-w", [
        ((-1.345, -0.86, 0.28), (-1.32, -0.72, 0.90)),     # west stile
        ((-1.345, 0.74, 0.28), (-1.32, 0.88, 0.90)),       # west stile
        ((-1.345, -0.86, 0.28), (-1.32, 0.88, 0.34)),      # bottom rail
        ((-1.345, -0.86, 0.84), (-1.32, 0.88, 0.90)),      # top rail
        ((-1.345, -0.16, 0.38), (-1.32, 0.02, 0.80)),      # centre mullion
    ], mat="olive", cuts=1, bevel=0.008))
    made.append(boxes("olive-panels-n", [
        ((-1.28, 0.94, 0.28), (-1.14, 0.965, 0.90)),       # north stile
        ((-0.44, 0.94, 0.28), (-0.30, 0.965, 0.90)),       # north stile
        ((-1.28, 0.94, 0.28), (-0.30, 0.965, 0.34)),       # bottom rail
        ((-1.28, 0.94, 0.84), (-0.30, 0.965, 0.90)),       # top rail
    ], mat="olive", cuts=1, bevel=0.008))
    a.run("greeble:rivet_row", (-1.35, -0.60, 0.60), (-1.35, 0.62, 0.60),
          count=7, mat="olive", name="rivets-west")
    a.run("greeble:rivet_row", (-1.20, 0.972, 0.60), (-0.38, 0.972, 0.60),
          count=6, mat="olive", name="rivets-north")
    # and a service hatch on the west wall, so that elevation has a focal point
    # rather than only a grid -- the same job the maw does in the south view.
    made.append(boxes("hatch-w", [
        ((-1.36, 0.14, 0.40), (-1.33, 0.62, 0.78)),
    ], mat="steel", cuts=1, bevel=0.008))
    a.place("greeble:bolt_ring", at=(-1.35, 0.38), z=0.59, size=0.30,
            mat="steel", count=8, name="hatch-w-bolts")

    # a bolted access hatch on T2's south face, with its own handwheel
    made.append(boxes("hatch", [
        ((-0.50, -1.085, 0.99), (-0.33, -1.055, 1.10)),
    ], mat="steel", cuts=1, bevel=0.008))
    a.place("greeble:handwheel", at=(-0.415, -1.11), z=1.045, size=0.10,
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
    # The tempered half's own two outward walls, for the same reason the olive
    # half just gained three: the north wall is the front elevation in the
    # south view and the east apron is in the west view. Bronze stiles rather
    # than olive ones -- the seam has to survive rotation too.
    made.append(boxes("temper-panels-n", [
        ((0.14, 1.24, 0.26), (0.28, 1.265, 0.92)),
        ((0.98, 1.24, 0.26), (1.12, 1.265, 0.92)),
        ((0.14, 1.24, 0.26), (1.12, 1.265, 0.32)),
        ((0.14, 1.24, 0.86), (1.12, 1.265, 0.92)),
    ], mat="bronze", cuts=1, bevel=0.008))
    made.append(boxes("temper-panels-e", [
        ((1.30, -1.04, 0.26), (1.325, -0.90, 0.88)),
        ((1.30, 0.82, 0.26), (1.325, 0.96, 0.88)),
        ((1.30, -1.04, 0.26), (1.325, 0.96, 0.32)),
        ((1.30, -1.04, 0.82), (1.325, 0.96, 0.88)),
        ((1.30, -0.14, 0.36), (1.325, 0.04, 0.78)),
    ], mat="bronze", cuts=1, bevel=0.008))
    a.run("greeble:rivet_row", (0.30, 1.272, 0.60), (0.96, 1.272, 0.60),
          count=5, mat="bronze", name="rivets-rear")
    a.run("greeble:rivet_row", (1.332, -0.76, 0.58), (1.332, 0.68, 0.58),
          count=8, mat="bronze", name="rivets-east")
    # A vent grille in the rear deck. In the SOUTH view this deck is the
    # nearest thing on the machine and it was flat bronze -- but nothing can
    # STAND on it: the deck already tops out at 1.06 where the cone allows 1.07,
    # so a finned cooler on top measured 2.48 and fit_cone refused to scale it
    # away. The fix is to spend the detail DOWNWARD. Recessed louvres cost no
    # height at all and read the same at 30 px.
    # The fins stand PROUD of their frame, not recessed under it: the first cut
    # put them at z 0.99..1.055 inside a frame topping at 1.065 and the
    # object-ID pass measured the whole bank at zero. Cone at |y| 1.16 allows
    # 1.09, which is what sets the top here.
    made.append(boxes("rear-vent-frame", [
        ((0.28, 1.02, 1.040), (0.88, 1.20, 1.060)),
    ], mat="steel", cuts=2, bevel=0.008))
    rf = []
    for i in range(7):
        fx = 0.32 + i * 0.078
        rf.append(((fx, 1.04, 1.00), (fx + 0.038, 1.16, 1.088)))
    made.append(boxes("rear-fins", rf, mat="gunmetal", cuts=0, bevel=0.005))

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
    # THE AUGER DRIVE. The auger turned on a keyframe with no motor anywhere
    # near it -- the same fault the maw rollers had. Gearmotor on top of the
    # housing at the west end, chain guard, and a sprocket on the auger shaft.
    made.append(boxes("auger-motor", [
        ((0.16, -1.42, 0.32), (0.38, -1.28, 0.52)),
        ((0.13, -1.38, 0.36), (0.41, -1.32, 0.46)),        # end bells
    ], mat="gunmetal", cuts=2, bevel=0.010))
    made.append(xz_prism("auger-chain-guard", [[
        (0.38, 0.50), (0.50, 0.50), (0.52, 0.26), (0.40, 0.26),
    ]], -1.43, -1.39, mat="steel", cuts=1, bevel=0.006))
    made.append(cyl("auger-sprocket", (0.46, -1.455, 0.30), 0.075, 0.045,
                    axis="Y", mat="scoured", seg=16))
    a.place("greeble:bolt_ring", at=(0.27, -1.35), z=0.525, size=0.16,
            mat="steel", count=6, name="auger-motor-bolts")
    # a rivet row on the housing, so it is not a bare box. An inspection door
    # went here too and measured zero: `chevron-out` already owns that face at
    # z 0.16..0.30, and two things cannot both be the outermost layer.
    a.run("greeble:rivet_row", (0.60, -1.462, 0.31), (1.14, -1.462, 0.31),
          count=6, mat="steel", name="auger-rivets")

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

    # **THE ROTOR-HOUSE ROOF IS THE BEST REAL ESTATE ON THIS MACHINE AND WAS
    # EMPTY.** It is up-facing, so it reads in all four rotations; it is at
    # |y| ~1.00 where the cone still allows 1.25; and it sits directly over the
    # hero. Everything below used to be somewhere the object-ID pass found it
    # drawing ZERO pixels -- the capacitor bank embedded in the 0.14-tile apron
    # wall, three more cans inside the rear deck, three gauge pods inside the
    # apron, the grease pot under the drum, and all three power cables threaded
    # through the gap between the bins and the wall.
    #
    # Cone at the can tops: |y| 1.055 + z 1.26 = 2.315, inside the machine's
    # existing 2.33 worst, so none of this costs the uniform fit.
    for i in range(3):
        cx_ = -0.12 + i * 0.14
        made.append(cyl("capcan%d" % i, (cx_, -1.00, 1.13), 0.055, 0.26,
                        mat="bronze", seg=14))
        made.append(cyl("capcan-top%d" % i, (cx_, -1.00, 1.255), 0.065, 0.03,
                        mat="copper", seg=14))
    made.append(boxes("capbar", [
        ((-0.18, -1.02, 1.262), (0.22, -0.98, 1.292)),
    ], mat="copper", cuts=1, bevel=0.006))

    # The slip-ring end of the rotor: brush gear, and the reason the drum has
    # any electricity at all. An eddy-current separator is a driven wound drum
    # and this is where the current crosses onto it, so it belongs at a shaft
    # end and nowhere else.
    made.append(boxes("slipring", [
        ((0.46, -1.05, 1.00), (0.70, -0.95, 1.18)),
        ((0.44, -1.06, 1.04), (0.72, -0.94, 1.10)),        # cover band
    ], mat="gunmetal", cuts=2, bevel=0.010))
    made.append(boxes("brushblock", [
        ((0.49, -1.075, 1.11), (0.545, -1.045, 1.165)),
        ((0.575, -1.075, 1.11), (0.63, -1.045, 1.165)),
    ], mat="copper", cuts=1, bevel=0.006))
    a.place("greeble:bolt_ring", at=(0.58, -1.00), z=1.185, size=0.16,
            mat="steel", count=6, name="slipring-bolts")

    # gauge cluster, up-facing so it reads in every rotation
    for i, gx_ in enumerate((-0.20, 0.30)):
        a.place("greeble:gauge_pod", at=(gx_, -1.00), z=1.00, size=0.13,
                mat="steel", face_material=mats["glass"], name="gauge%d" % i)
    # the oil-mist lubricator, on the roof's lower step where it can be seen
    # ON the wall's east step (which tops at 0.92), not in front of it: at
    # y -1.13 the pot was in the crowded band the hazard chevrons and the bin
    # chutes already own, and measured zero twice running.
    made.append(cyl("grease-pot", (1.02, -1.00, 1.00), 0.072, 0.16,
                    mat="bronze", seg=16))
    a.run("greeble:pipe_run", [(1.02, -1.02, 1.08), (0.86, -1.04, 1.06),
                               (0.70, -1.02, 1.04)],
          radius=0.030, mat="copper", name="grease-line")

    # power across the roof: busbar to slip ring, and busbar down to the box
    a.run("greeble:cable", (0.22, -1.00, 1.28), (0.46, -1.00, 1.14),
          sag=0.06, mat="rubber", name="cable0")
    a.run("greeble:cable", (0.66, -1.02, 1.16), (1.16, -0.90, 0.74),
          sag=0.10, mat="rubber", name="cable1")
    a.run("greeble:cable", (0.62, -0.96, 1.16), (1.12, -0.80, 0.74),
          sag=0.12, mat="rubber", name="cable2")

    # **DISCHARGE CHUTES, on the OUTSIDE of the wall.** These began as guide
    # plates inside the sorting gap, at y -0.92 under the drum -- where the
    # object-ID pass measured them at 0, 0, 2 and 7 pixels, because the drum is
    # over them and the bearing wall is in front of them. The gap is not a
    # place a viewer can see into on this machine. Told on the south face
    # instead, one short sloped chute per bin, the same causal story reads: the
    # rotor throws, the wall discharges here, this bin catches it.
    for i in range(4):
        gx0 = BIN_X[i]
        made.append(xz_prism("chute%d" % i, [[
            (gx0 + 0.01, 0.74), (gx0 + 0.19, 0.74),
            (gx0 + 0.19, 0.62), (gx0 + 0.01, 0.56),
        ]], -1.115, -1.055, mat="scoured", cuts=1, bevel=0.006))
        made.append(boxes("chute-cheek%d" % i, [
            ((gx0 - 0.005, -1.12, 0.56), (gx0 + 0.015, -1.05, 0.76)),
            ((gx0 + 0.185, -1.12, 0.56), (gx0 + 0.205, -1.05, 0.76)),
        ], mat="gunmetal", cuts=1, bevel=0.005))
    # the splitter ridge they hang from, running under the drum
    made.append(boxes("gap-ridge", [
        ((0.18, -0.90, 0.58), (1.14, -0.80, 0.66)),
        ((0.18, -0.86, 0.66), (1.14, -0.84, 0.74)),
    ], mat="gunmetal", cuts=2, bevel=0.008))

    # -- 7. heat out ------------------------------------------------------
    # Earned, not decorative: eddy currents genuinely make heat.
    #
    # No `rot=` on a greeble: the builders bake their centre into the mesh and
    # leave the object at the origin, so parts.place()'s rot spins the part
    # about the WORLD origin. A louvre bank at (1.44, -0.30) with rot=90 flew
    # to (0.30, 1.44) and became the tallest thing in the sprite.
    # NOT at (0.62, 1.00, 0.80): the rear deck spans y 0.92..1.24 up to z 1.06,
    # so the radiator was inside it and the object-ID pass measured it at zero
    # pixels in all four rotations. It now stands on the pad north-east of the
    # deck, in clear air, where `ne-cooler` used to be a plain box -- same
    # space, same purpose, an order of magnitude more read.
    a.place("greeble:louvre_bank", at=(-0.58, 1.02), z=0.60, size=0.42,
            mat="gunmetal", name="louvres")
    a.place("greeble:louvre_bank", at=(-0.70, 1.28), z=0.48, size=0.34,
            mat="gunmetal", name="louvres-n")
    # The stack rides the hood's EAST flank rather than its crown, and the
    # offset is forced rather than styled: a cap's RADIUS counts toward |xy| as
    # much as its centre does, so a 0.145 cowl on the crown at x -0.70 reads as
    # |xy| 0.845 and the cone leaves it 1.41 -- 0.05 above the hood it stands
    # on. At x -0.55 there is 0.30 of stack to see. It leans toward the seam,
    # which is where the heat comes from, so the asymmetry is also correct.
    made.append(cyl("stack", (-0.55, 0.34, 1.34), 0.115, 0.36, mat="steel",
                    seg=20))
    made.append(cyl("stack-cowl", (-0.55, 0.34, 1.50), 0.145, 0.08,
                    mat="gunmetal", seg=20))
    # a soot-stained bracket tying the stack back to the hood
    made.append(boxes("stack-stay", [
        ((-0.69, 0.32, 1.335), (-0.56, 0.36, 1.375)),
    ], mat="steel", cuts=1, bevel=0.006))

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
    # On the hood's east flank, where the coolant line leaves it -- the design
    # asks for a handwheel "at the coolant line" and the old one hung in air
    # over a tier that no longer exists.
    a.place("greeble:handwheel", at=(-0.44, 0.20), z=1.21, size=0.17,
            mat="hazard", name="handwheel")
    a.place("greeble:placard", at=(-0.24, -1.31), z=0.56, size=0.20,
            mat="steel", name="placard")

    # hazard chevrons, quoting the vanilla recycler's own. GENUINELY DIAGONAL
    # and big: the first build's were 0.125 x 0.16 slivers on a wall the camera
    # barely sees, and they simply were not there in the sprite. Three bands up
    # the stepped front, one along the output, sized so each stripe is 8-14 px.
    # A band across the tempered half's bearing wall, right under the drum.
    # This is the sorting-gap lip -- the one edge on the machine a hand should
    # not be near while the rotor turns -- so the warning is earned, and it
    # puts the concept sheet's hazard yellow on BOTH halves rather than only on
    # the olive one.
    made.extend(chevrons("chevron-seamwall", -0.18, 0.16, 0.755, 0.850, -1.062,
                         count=2))
    made.extend(chevrons("chevron-lintel", -1.14, -0.38, 0.905, 0.972, -1.30,
                         count=6))
    made.extend(chevrons("chevron-out", 0.26, 1.14, 0.16, 0.30, -1.44,
                         count=6))

    # -- 9. structure -----------------------------------------------------
    # a tachometer on the drum's south bearing, cabled back to the slip ring
    made.append(cyl("tacho", (0.14, -1.105, 0.70), 0.055, 0.055, axis="Y",
                    mat="gunmetal", seg=16))
    a.run("greeble:cable", (0.14, -1.10, 0.75), (0.50, -1.07, 1.06),
          sag=0.05, mat="rubber", name="tacho-lead")
    # A SPARES CRATE on the pad. Vanilla machines carry clutter that is nobody's
    # subsystem -- it is what stops a machine reading as a rendering rather than
    # a thing standing in a factory.
    made.append(boxes("crate", [
        ((-1.28, 1.02, DECK), (-1.06, 1.24, 0.28)),
        ((-1.30, 1.00, 0.28), (-1.04, 1.26, 0.32)),        # lid, overhanging
    ], mat="steel", cuts=2, bevel=0.012))
    made.append(boxes("crate-strap", [
        ((-1.22, 0.99, DECK), (-1.18, 1.27, 0.33)),
        ((-1.14, 0.99, DECK), (-1.10, 1.27, 0.33)),
    ], mat="gunmetal", cuts=1, bevel=0.005))
    # hydraulic line, gearbox down to the maw lintel
    a.run("greeble:pipe_run", [(-0.66, -1.06, 1.02), (-0.72, -1.22, 0.96),
                               (-0.80, -1.29, 0.90)],
          radius=0.038, mat="copper", name="hyd-line")
    # coolant return, rotor-house roof across to the seam post
    a.run("greeble:pipe_run", [(0.30, -1.06, 1.02), (0.02, -1.12, 0.99),
                               (-0.26, -1.16, 0.96)],
          radius=0.044, mat="copper", name="coolant-return")

    a.run("greeble:skid_feet",
          [(-1.24, -1.24, -0.02), (-1.24, 1.20, -0.02),
           (1.22, -1.24, -0.02), (1.22, 1.20, -0.02)],
          mat="gunmetal", name="feet")
    # z 0.60, not 0.30: the panel bottom rail runs 0.28..0.34 on the same wall
    # and swallowed the whole row.
    a.run("greeble:rivet_row", (-1.24, -1.315, 0.60), (-0.30, -1.315, 0.60),
          count=8, mat="olive", name="rivets-front")
    # On the deck, not the west wall: at this pitch a side wall renders as a
    # one-pixel line, and the west rivet row drew literally nothing there.
    a.run("greeble:rivet_row", (-1.26, -1.075, 1.055), (-0.88, -1.075, 1.055),
          count=4, mat="olive", name="rivets-deck")

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
    a.run("greeble:pipe_run", [(-1.34, -0.28, 0.52), (-1.50, -0.28, 0.52)],
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
        ((0.86, 1.28, DECK), (1.20, 1.34, 0.52)),
        ((0.86, 1.46, DECK), (1.20, 1.52, 0.52)),
    ], mat="steel", cuts=2))
    a.place("greeble:radiator", at=(1.03, 1.40), z=0.34, size=0.34,
            mat="steel", name="radiator")
    # header and return, so the radiator is plumbed to the machine it cools
    a.run("greeble:pipe_run", [(0.90, 1.40, 0.52), (0.78, 1.30, 0.60),
                               (0.72, 1.12, 0.66)],
          radius=0.042, mat="copper", name="rad-header")
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
        ((0.30, -1.070, 0.885), (0.42, -1.060, 0.945)),
        ((0.74, -1.070, 0.885), (0.86, -1.060, 0.945)),
        # ROOF of the same housing, and this is the one that carries the other
        # rotations. A south-facing emissive points AWAY from the camera once
        # the machine faces south and renders as a one-pixel line east and
        # west -- the first build's light sheet measured 45x60 px in north
        # against 17x8 in flipped-south. An up-facing slot is visible in all
        # four, because the deck is the one surface this camera always sees.
        ((0.28, -1.03, 0.998), (0.44, -0.97, 1.012)),
        ((0.74, -1.03, 0.998), (0.90, -0.97, 1.012)),
        # For the south view -- and NOT on the bearing cheek at y 0.92, where
        # this pair used to be. The rear deck spans y 0.92..1.24 up to z 1.06,
        # so both slots sat inside solid geometry and the south glow sheet
        # measured ZERO violet pixels: the machine had no field at all in one
        # of its four rotations, and no gate reads that. The cowl's north face
        # is the first surface north of the rotor that is actually exposed,
        # because the rear deck stops below it at 1.06.
        ((0.06, 1.040, 1.12), (0.24, 1.050, 1.18)),
        ((0.52, 1.040, 1.12), (0.70, 1.050, 1.18)),
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
    # the concept sheet's amber beacon, now on the hood's crown
    made.append(cyl("beacon-base", (-0.68, -0.52, 1.38), 0.080, 0.06,
                    mat="gunmetal", seg=16))
    made.append(cyl("beacon-lamp", (-0.68, -0.52, 1.455), 0.066, 0.09,
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

    # The cooling fan: 5 turns a loop against the rotor's 1, so the two never
    # look geared together. A whole number, like everything else here, or the
    # sheet jumps on the wrap once a second forever.
    fan = _pivot("piv-fan", (HOOD_CENTRE[0], -0.945, HOOD_CENTRE[1]))
    _attach(fan, ("fan-hub", "fan-blade"))
    _key(fan, "rotation_euler", [(0, 0.0), (frames, 5.0 * tau)], index=1)

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
