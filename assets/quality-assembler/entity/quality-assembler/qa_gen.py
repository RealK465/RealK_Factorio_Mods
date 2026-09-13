# Scene generator core for the Quality Assembler: palette, the validated
# material stack, the bmesh primitives, the collections and animation wiring,
# and the audit. The machine itself is qa_layout.py; every driver imports both.
#
# The design is quality-assembler/.ai-support/quality-assembler-design.md and
# the repo owner's concept sheet beside it (prototype.png). Where this file
# departs from either, the reason is written next to the constant.
#
# Coordinates: 1 Blender unit = 1 Factorio tile. +y is NORTH (screen up),
# +x is east, z is up. The rig looks along (0, +y, -z) at 45 degrees, so the
# screen row of a point is -(y + z) and its column is x. Two consequences
# drive everything in qa_layout.py:
#
#   * only the TOP DECK and the SOUTH (-y) wall are ever seen. Side walls are
#     one-pixel lines and the north wall does not exist for the camera.
#   * the sprite's top edge is set by the largest y + z, not by height alone:
#     a part far north raises it as much as a tall one does.
#
# Run:  blender -b -P qa_gen.py -- <ABSOLUTE out_dir>      (one look frame + .blend)

import math
import os
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

PREFIX = "QA_"
FOOTPRINT = (3, 3)
# ortho_scale 5.0 -> 64 px/tile; 5 tiles wide, 5.5 tiles of rows. The
# shadow falls east to about x +2.3 (vanilla AM3's reaches 2.3), which is
# why the canvas is wider than the 3x3 needs.
CANVAS = (320, 352)
REPO_ROOT = Path(__file__).resolve().parents[4]
POLYHAVEN_DIR = REPO_ROOT / "assets" / "third-party" / "polyhaven"


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
from factorio_render import rig, parts, greeble          # noqa: E402


# --------------------------------------------------------------------------
# The one number that bounds the massing.
#
# The sprite's top edge is max(y + z). The footprint's north edge is 1.5, and
# the design budgets 0.7 tiles of overhang past it -- inside the chemical
# plant's 0.77, the largest any vanilla 3x3 draws past its own tiles. So no
# vertex may exceed y + z = 2.2. The entity does not rotate, so unlike the
# recycler there is no cone: only the north matters, and the south may be
# as tall as it likes (its y is negative by as much as its z is positive).
APEX = 2.20

# Lighting. The recycler's settled set (its CLAUDE.md records why it left the
# rig's validated 5.2 / 1.2 / 0.22): a slightly harder key and less sky fill
# put the contrast in the render rather than leaving it to the paint-over.
# Overridable so a sweep is repeatable.
KEY = float(os.environ.get("QA_KEY", "5.4"))
FILL = float(os.environ.get("QA_FILL", "1.05"))
AMBIENT = float(os.environ.get("QA_AMBIENT", "0.18"))

PLINTH = 0.10                       # top of the plinth; the hull stands on it


def srgb(hex_str):
    h = hex_str.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


# --------------------------------------------------------------------------
# Palette. Sampled, not picked.
#
# THE BLUE. The concept sheet's "worn blue paint" swatch measures (78, 99, 123)
# at hue 212, and its legend chip (80, 130, 169). The vanilla family colour it
# is quoting is the assembling machine 2's -- measured off
# assembling-machine-2-base.png: 17% of its opaque pixels are blue, median
# (28, 50, 68) at hue ~205. (The assembling machine 3 is yellow-green, median
# (54, 61, 18); the design's "worn AM3 blue" is the AM2's blue, and the lore
# reads "an old assembler" either way.) A hull renders about a stop below its
# base colour once grime and the key are through it, so the lit tone sits
# between the sheet's chip and its swatch, and the dark end near the AM2's.
BLUE_LIT = srgb("#6E92B8")
BLUE_DARK = srgb("#213649")
# The same paint lower down, dirtier, for the skirt: grime pools toward the
# ground and the camera reads the resulting gradient as light direction.
BLUE_LOW_LIT = srgb("#48678A")
BLUE_LOW_DARK = srgb("#182837")

# THE CRYO STEEL. The sheet's legend chip is (166, 172, 184): pale, cool,
# sat 0.10. Vanilla has no neutral mass, so the tint is kept (hue ~215) and
# the dark end is warm oxide rather than grey -- the crevices of the cold half
# still carry rust where condensate has run.
CRYO_LIT = srgb("#8E98A6")
CRYO_DARK = srgb("#4A4E58")
# The vessel's inner cell and every cold cavity: dark, cool, not black.
CELL_LIT = srgb("#2A3038")
CELL_DARK = srgb("#0C0E12")

# Galvanised bare steel (condenser skid, frame, seam) -- the recycler's,
# warm and a step darker than grey card.
STEEL_LIT = srgb("#8C7A5E")
STEEL_DARK = srgb("#3E3226")
# Dark iron / gunmetal: mechanism, mouths, recesses. Warm, never grey.
GUNMETAL_LIT = srgb("#4A3F33")
GUNMETAL_DARK = srgb("#1B1611")
# Warm metals. Bronze for the refrigerant line and the riser (the sheet's
# elbow is bronze); copper for the coil bundle on the vessel.
BRONZE_LIT = srgb("#946844")
BRONZE_DARK = srgb("#452F22")
COPPER_LIT = srgb("#BC6A2C")
COPPER_DARK = srgb("#5E2F13")
RUBBER = srgb("#141517")
HAZARD = srgb("#E9BE42")
CONCRETE_LIT = srgb("#5E5443")
CONCRETE_DARK = srgb("#2A251C")
RUST = (0.14, 0.055, 0.025)
# Chipped paint reveals DARK warm steel, not bright metal (the recycler
# measured a pale BARE as its single largest desaturator).
BARE = srgb("#6E6459")
# Rime: pale blue-white, kept well below where the 5.4 key would clip it.
FROST = srgb("#C2CDD8")

# Emissives. Max emitted channel (colour x strength) must stay near 1.0 or
# Standard clips the hue to white. Cyan is the cryogenic band FFF-432 assigns
# to cold and the electromagnetic plant measures at (195 deg dominant).
CYAN_EMIT = srgb("#4FE0F2")
AMBER_EMIT = srgb("#FF9A2A")
VIOLET_EMIT = srgb("#8900B2")       # epic quality {137, 0, 178}: the family tell


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
        # a part with no material reads as a white bullseye.
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


def _axis_rot(bm, verts, axis):
    if axis == "Z":
        return
    bmesh.ops.rotate(bm, verts=verts, cent=(0, 0, 0),
                     matrix=Matrix.Rotation(math.radians(90), 3,
                                            "Y" if axis == "X" else "X"))


def cyl(name, centre, radius, length, axis="Z", mat=None, seg=28, rings=3,
        r2=None, **kw):
    """A solid cylinder (a DISC, not a ring -- see ring() for an annulus).
    `r2` makes it a frustum: radius at the +axis end."""
    bm = bmesh.new()
    res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                                radius1=radius, radius2=radius if r2 is None else r2,
                                depth=length)
    verts = res["verts"]
    _axis_rot(bm, verts, axis)
    bmesh.ops.translate(bm, verts=verts, vec=Vector(centre))
    kw.setdefault("cuts", rings)
    return _emit(bm, name, _MATS.get(mat), **kw)


def prism(name, poly, z0, z1, mat=None, **kw):
    """An extruded polygon in plan -- the chamfered hulls and the plinth."""
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
    """Polygons in the XZ plane extruded along Y -- a decal on a SOUTH wall."""
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


def _angles(a0, a1, seg):
    full = abs(a1 - a0) >= 359.9
    if full:
        return [math.radians(a0 + 360.0 * i / seg) for i in range(seg)], True
    n = max(3, int(round(seg * abs(a1 - a0) / 360.0)) + 1)
    return [math.radians(a0 + (a1 - a0) * i / (n - 1)) for i in range(n)], False


def ring(name, centre, r_out, r_in, length, axis="Z", mat=None, seg=40,
         a0=0.0, a1=360.0, **kw):
    """A true annulus, or an arc of one, extruded along its own axis.
    Angles in degrees from +x toward +y, so SOUTH is -90."""
    bm = bmesh.new()
    angs, full = _angles(a0, a1, seg)
    zl, zh = -length / 2.0, length / 2.0
    olo = [bm.verts.new((r_out * math.cos(t), r_out * math.sin(t), zl)) for t in angs]
    ohi = [bm.verts.new((r_out * math.cos(t), r_out * math.sin(t), zh)) for t in angs]
    ilo = [bm.verts.new((r_in * math.cos(t), r_in * math.sin(t), zl)) for t in angs]
    ihi = [bm.verts.new((r_in * math.cos(t), r_in * math.sin(t), zh)) for t in angs]
    n = len(angs)
    last = n if full else n - 1
    for i in range(last):
        j = (i + 1) % n
        bm.faces.new((olo[i], olo[j], ohi[j], ohi[i]))
        bm.faces.new((ilo[j], ilo[i], ihi[i], ihi[j]))
        bm.faces.new((ihi[i], ohi[i], ohi[j], ihi[j]))
        bm.faces.new((ilo[j], olo[j], olo[i], ilo[i]))
    if not full:
        bm.faces.new((olo[0], ohi[0], ihi[0], ilo[0]))
        bm.faces.new((ilo[-1], ihi[-1], ohi[-1], olo[-1]))
    _axis_rot(bm, bm.verts[:], axis)
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=Vector(centre))
    kw.setdefault("cuts", 1)
    return _emit(bm, name, _MATS.get(mat), **kw)


def torus(name, centre, major, minor, axis="Z", mat=None, seg=40, mseg=10,
          a0=0.0, a1=360.0, **kw):
    """A round-section hoop: a coil turn, a guard hoop, a collar."""
    bm = bmesh.new()
    angs, full = _angles(a0, a1, seg)
    rows = []
    for t in angs:
        row = []
        for k in range(mseg):
            p = 2 * math.pi * k / mseg
            rr = major + minor * math.cos(p)
            row.append(bm.verts.new((rr * math.cos(t), rr * math.sin(t),
                                     minor * math.sin(p))))
        rows.append(row)
    n = len(rows)
    last = n if full else n - 1
    for i in range(last):
        j = (i + 1) % n
        for k in range(mseg):
            l = (k + 1) % mseg
            bm.faces.new((rows[i][k], rows[j][k], rows[j][l], rows[i][l]))
    if not full:
        bm.faces.new(rows[0][::-1])
        bm.faces.new(rows[-1])
    _axis_rot(bm, bm.verts[:], axis)
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=Vector(centre))
    kw.setdefault("cuts", 0)
    return _emit(bm, name, _MATS.get(mat), **kw)


def helix(name, centre, major, minor, z0, z1, turns, axis="Z", mat=None,
          seg_per_turn=36, mseg=8, **kw):
    """A helical tube: the coil bundle wrapped round the vessel jacket. One
    object, so the turns share a jitter and read as one wound coil."""
    bm = bmesh.new()
    n = int(turns * seg_per_turn) + 1
    rows = []
    for i in range(n):
        u = i / (n - 1.0)
        t = 2 * math.pi * turns * u
        z = z0 + (z1 - z0) * u
        # the local frame: radial, tangential, vertical
        cx, cy = math.cos(t), math.sin(t)
        row = []
        for k in range(mseg):
            p = 2 * math.pi * k / mseg
            rr = major + minor * math.cos(p)
            row.append(bm.verts.new((rr * cx, rr * cy, z + minor * math.sin(p))))
        rows.append(row)
    for i in range(n - 1):
        for k in range(mseg):
            l = (k + 1) % mseg
            bm.faces.new((rows[i][k], rows[i + 1][k], rows[i + 1][l], rows[i][l]))
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    _axis_rot(bm, bm.verts[:], axis)
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=Vector(centre))
    kw.setdefault("cuts", 0)
    return _emit(bm, name, _MATS.get(mat), **kw)


def radial_bars(name, centre, r0, r1, half_w, thick, count, axis="Z", mat=None,
                phase=0.0, taper=1.0, **kw):
    """`count` bars radiating from r0 to r1 -- fan blades, gear teeth, spokes.
    One object, so the parts share a colour jitter."""
    bm = bmesh.new()
    zl, zh = -thick / 2.0, thick / 2.0
    for k in range(count):
        a = math.radians(phase) + 2 * math.pi * k / count
        d0, d1 = half_w / max(r0, 1e-3), half_w * taper / max(r1, 1e-3)
        quad = [(r0, -d0), (r0, d0), (r1, d1), (r1, -d1)]
        pts = [(r * math.cos(a + d), r * math.sin(a + d)) for r, d in quad]
        lo = [bm.verts.new((x, y, zl)) for x, y in pts]
        hi = [bm.verts.new((x, y, zh)) for x, y in pts]
        bm.faces.new(lo[::-1])
        bm.faces.new(hi)
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    _axis_rot(bm, bm.verts[:], axis)
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=Vector(centre))
    kw.setdefault("cuts", 1)
    return _emit(bm, name, _MATS.get(mat), **kw)


def fan_blades(name, centre, r0, r1, count, thick, pitch_deg=28.0, axis="Z",
               mat=None, **kw):
    """Fan blades that are actually PITCHED, so the key catches each one on a
    different facet and the disc reads as a fan rather than as a star."""
    bm = bmesh.new()
    for k in range(count):
        a = 2 * math.pi * k / count
        w0, w1 = 0.30 * r0, 0.38 * r1
        quad = [(r0, -w0), (r0, w0), (r1, w1), (r1, -w1)]
        pts = [(r * math.cos(a) - d * math.sin(a), r * math.sin(a) + d * math.cos(a))
               for r, d in quad]
        lo = [bm.verts.new((x, y, -thick / 2)) for x, y in pts]
        hi = [bm.verts.new((x, y, thick / 2)) for x, y in pts]
        bm.faces.new(lo[::-1])
        bm.faces.new(hi)
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
        # pitch the blade about its own radial axis
        verts = lo + hi
        bmesh.ops.rotate(bm, verts=verts, cent=(0, 0, 0),
                         matrix=Matrix.Rotation(math.radians(pitch_deg), 3,
                                                Vector((math.cos(a), math.sin(a), 0))))
    _axis_rot(bm, bm.verts[:], axis)
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=Vector(centre))
    kw.setdefault("cuts", 1)
    return _emit(bm, name, _MATS.get(mat), **kw)


def belt(name, c1, r1, c2, r2, y, width, thick, mat=None, seg=14, **kw):
    """A drive belt round two pulleys in the XZ plane at depth `y`: the two
    external tangents and the arcs they leave, swept as a flat band. `c1`
    and `c2` are (x, z) centres; the band rides on radius r and stands
    `thick` proud of it."""
    x1, z1 = c1
    x2, z2 = c2
    d = math.hypot(x2 - x1, z2 - z1)
    base = math.atan2(z2 - z1, x2 - x1)
    off = math.acos(max(-1.0, min(1.0, (r1 - r2) / d)))

    def arc(cx, cz, r, a0, a1, n):
        return [(cx + r * math.cos(a0 + (a1 - a0) * i / n),
                 cz + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]

    def loop(extra):
        pts = arc(x1, z1, r1 + extra, base + off, base - off + 2 * math.pi, 2 * seg)
        pts += arc(x2, z2, r2 + extra, base - off, base + off, seg)
        return pts

    inner, outer = loop(0.0), loop(thick)
    bm = bmesh.new()
    y0, y1 = y - width / 2, y + width / 2
    vi0 = [bm.verts.new((px, y0, pz)) for px, pz in inner]
    vi1 = [bm.verts.new((px, y1, pz)) for px, pz in inner]
    vo0 = [bm.verts.new((px, y0, pz)) for px, pz in outer]
    vo1 = [bm.verts.new((px, y1, pz)) for px, pz in outer]
    n = len(inner)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((vo0[i], vo0[j], vo1[j], vo1[i]))
        bm.faces.new((vi1[i], vi1[j], vi0[j], vi0[i]))
        bm.faces.new((vi0[i], vi0[j], vo0[j], vo0[i]))
        bm.faces.new((vo1[i], vo1[j], vi1[j], vi1[i]))
    # one clean closed shell, so recalc is safe here (it is NOT on a machine
    # assembled from intersecting boxes in one mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    kw.setdefault("cuts", 0)
    kw.setdefault("bevel", 0)
    return _emit(bm, name, _MATS.get(mat), **kw)


def bellows(name, points, r, pitch=0.05, rib=0.014, mat=None, seg=12, **kw):
    """A ribbed flexible hose along a polyline: a core tube with a fat ring
    every `pitch` along it -- the cryogenic plant's and the fusion reactor's
    signature fitting. One mesh, no bevel: the ribs are a pixel high."""
    bm = bmesh.new()
    pts = [Vector(p) for p in points]
    for a, b in zip(pts, pts[1:]):
        d = b - a
        L = d.length
        if L < 1e-6:
            continue
        quat = d.to_track_quat("Z", "Y").to_matrix()
        res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                                    radius1=r, radius2=r, depth=L)
        bmesh.ops.rotate(bm, verts=res["verts"], cent=(0, 0, 0), matrix=quat)
        bmesh.ops.translate(bm, verts=res["verts"], vec=(a + b) / 2)
        n = max(1, int(round(L / pitch)))
        for i in range(n):
            c = a.lerp(b, (i + 0.5) / n)
            res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg,
                                        radius1=r + rib, radius2=r + rib, depth=pitch * 0.48)
            bmesh.ops.rotate(bm, verts=res["verts"], cent=(0, 0, 0), matrix=quat)
            bmesh.ops.translate(bm, verts=res["verts"], vec=c)
    kw.setdefault("cuts", 0)
    kw.setdefault("bevel", 0)
    return _emit(bm, name, _MATS.get(mat), **kw)


def sag_path(a, b, sag, n=8):
    """A polyline from a to b hanging by `sag` at the middle, for bellows()."""
    a, b = Vector(a), Vector(b)
    out = []
    for i in range(n + 1):
        t = i / n
        p = a.lerp(b, t)
        p.z -= sag * math.sin(math.pi * t)
        out.append(tuple(p))
    return out


def sphere(name, centre, r, mat=None, seg=16, **kw):
    bm = bmesh.new()
    res = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=r)
    bmesh.ops.translate(bm, verts=res["verts"], vec=Vector(centre))
    kw.setdefault("cuts", 0)
    kw.setdefault("bevel", 0)
    return _emit(bm, name, _MATS.get(mat), **kw)


def chamfer_rect(x0, y0, x1, y1, c):
    """An octagon: a rectangle with its corners cut at 45 degrees by `c`."""
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c),
            (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def chevrons(name, x0, x1, z0, z1, y_wall, mat="hazard", count=5, lean=0.62,
             **kw):
    """A hazard band on a south wall: leaning stripes on a DARK plate.
    Yellow straight onto paint is two mid-tones and vanishes at 32 px."""
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
    pad = 0.02
    back = boxes(name + "-back",
                 [((x0 - pad, y_wall - 0.016, z0 - pad),
                   (x1 + skew + pad, y_wall - 0.006, z1 + pad))],
                 mat="cavity", cuts=1, bevel=0.005)
    strp = xz_prism(name, polys, y_wall - 0.028, y_wall - 0.014, mat=mat, **kw)
    return back, strp


def wall_louvres(name, x0, x1, z0, z1, y_wall, count=4, depth=0.05, mat="gunmetal",
                 back="cavity"):
    """Angled slats stacked in Z on a south wall, in a dark recess. The heat
    story on a face the camera actually sees -- greeble.louvre_bank lays its
    blades along a deck, which is the wrong axis for a wall."""
    pad = 0.015
    rec = boxes(name + "-back",
                [((x0 - pad, y_wall - 0.004, z0 - pad), (x1 + pad, y_wall + depth, z1 + pad))],
                mat=back, cuts=1, bevel=0.004)
    bm = bmesh.new()
    pitch = (z1 - z0) / count
    for i in range(count):
        z = z0 + pitch * (i + 0.5)
        blade = _bm_box(bm, (x0, y_wall - 0.012, z - pitch * 0.34),
                        (x1, y_wall + depth * 0.7, z + pitch * 0.34))
        bmesh.ops.rotate(bm, verts=blade, cent=(0, y_wall, z),
                         matrix=Matrix.Rotation(math.radians(-34), 3, "X"))
    slats = _emit(bm, name, _MATS.get(mat), cuts=1, bevel=0.003)
    return rec, slats


# --------------------------------------------------------------------------
# materials -- the validated stack from references/materials.md, carried over
# from the recycler's worn_metal() with its heat and patina terms dropped and a
# RIME term added for the cold half.

_IMG_CACHE = {}


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
               grain=0.0, grain_slug="metal_plate", scratch=0.0, rime=0.0,
               soot=0.0, streak=0.35):
    """Painted worn metal.

    `rime` is this entity's own term: condensate frozen onto a cold surface.
    It is a MAP, not a coat -- up-facing faces and crevices, patchy, capped
    low (materials.md: 0.08-0.14 reads as cold at 64 px/tile; 0.3 buries the
    identity colour). `soot` darkens the top of a part from above: the
    condenser's exhaust side. `streak` is how dark the vertical grime runs.
    """
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

    # photo grain as LUMINANCE only
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
    streak_mask = map_range((0.0, streak), fr=(0.42, 0.62))
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

    # soot: darkening that sits on the TOP of a part and thins downward,
    # keyed on world Z so a whole heat exit blackens together
    if soot > 0:
        pos = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Position"], pos.inputs["Vector"])
        sramp = map_range((1.0, 1.0 - soot), fr=(0.15, 0.62))
        nt.links.new(pos.outputs["Z"], sramp.inputs["Value"])
        spatch = map_range((0.55, 1.0), fr=(0.35, 0.65))
        nt.links.new(noise_node(noise_scale * 0.9, detail=3.0).outputs["Fac"],
                     spatch.inputs["Value"])
        smix = math_node("MULTIPLY")
        nt.links.new(sramp.outputs["Result"], smix.inputs[0])
        nt.links.new(spatch.outputs["Result"], smix.inputs[1])
        sooted = mix_color("MULTIPLY")
        sooted.inputs["Factor"].default_value = 1.0
        nt.links.new(color_out, sooted.inputs["A"])
        # the multiplier: 1 where clean, (1 - soot) where sooted -- built as
        # max(1 - soot, ramp*patch) so the patch can only lighten toward clean
        smax = math_node("MAXIMUM", 1.0 - soot)
        nt.links.new(smix.outputs["Value"], smax.inputs[0])
        nt.links.new(grey_of(smax.outputs["Value"]), sooted.inputs["B"])
        color_out = sooted.outputs["Result"]

    # rust: crevices (low AO) MAX'd with patchy noise
    ao_inv_out = None
    if rust > 0 or rime > 0:
        ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = 0.35
        ao_inv = math_node("SUBTRACT")
        ao_inv.inputs[0].default_value = 1.0
        nt.links.new(ao.outputs["AO"], ao_inv.inputs[1])
        ao_inv_out = ao_inv.outputs["Value"]
    if rust > 0:
        rust_patch = map_range((0.0, 1.0), fr=(0.52, 0.68))
        nt.links.new(noise_node(noise_scale * 0.6, detail=3.0).outputs["Fac"],
                     rust_patch.inputs["Value"])
        seed = math_node("MAXIMUM")
        nt.links.new(ao_inv_out, seed.inputs[0])
        nt.links.new(rust_patch.outputs["Result"], seed.inputs[1])
        rust_amt = math_node("MULTIPLY", rust)
        nt.links.new(seed.outputs["Value"], rust_amt.inputs[0])
        rusted = mix_color()
        rusted.inputs["B"].default_value = (*RUST, 1.0)
        nt.links.new(color_out, rusted.inputs["A"])
        nt.links.new(rust_amt.outputs["Value"], rusted.inputs["Factor"])
        color_out = rusted.outputs["Result"]

    # per-object hue/value jitter -- the single biggest hand-painted tell.
    # +-12%: enough to break the CG tell of one flat colour repeated, not
    # enough to make two plates cut from the same steel read as two metals.
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

    # edge wear: convex edges chip to bare metal, patchy via fine noise.
    # Floor 0.0: wear that genuinely stops is what makes the wear that
    # remains read as placed.
    edge = map_range((0.0, 1.0), fr=(0.53, 0.62))
    nt.links.new(geo.outputs["Pointiness"], edge.inputs["Value"])
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

    # scour polish: worn bright along one axis, up-facing faces only
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

    # RIME. Condensate freezes where cold pools: on up-facing faces, in the
    # crevices, patchy. Never on the walls' open faces, never uniform, and
    # capped -- a mask, not a coat of paint. The frost is also ROUGH, which is
    # what stops a pale patch reading as a specular.
    rime_amt_out = None
    if rime > 0:
        nrm2 = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Normal"], nrm2.inputs["Vector"])
        up = map_range((0.0, 1.0), fr=(0.25, 0.90))
        nt.links.new(nrm2.outputs["Z"], up.inputs["Value"])
        blotch = map_range((0.0, 1.0), fr=(0.44, 0.66))
        nt.links.new(noise_node(noise_scale * 0.8, detail=3.2).outputs["Fac"],
                     blotch.inputs["Value"])
        on_top = math_node("MULTIPLY")
        nt.links.new(up.outputs["Result"], on_top.inputs[0])
        nt.links.new(blotch.outputs["Result"], on_top.inputs[1])
        in_crevice = math_node("MULTIPLY", 0.85)
        nt.links.new(ao_inv_out, in_crevice.inputs[0])
        crev = math_node("MULTIPLY")
        nt.links.new(in_crevice.outputs["Value"], crev.inputs[0])
        nt.links.new(blotch.outputs["Result"], crev.inputs[1])
        seed2 = math_node("MAXIMUM")
        nt.links.new(on_top.outputs["Value"], seed2.inputs[0])
        nt.links.new(crev.outputs["Value"], seed2.inputs[1])
        # convex edges rime first -- the rims of every ring and flange
        redge = map_range((0.0, 1.0), fr=(0.54, 0.64))
        nt.links.new(geo.outputs["Pointiness"], redge.inputs["Value"])
        redge_p = math_node("MULTIPLY", 0.9)
        nt.links.new(redge.outputs["Result"], redge_p.inputs[0])
        seed3 = math_node("MAXIMUM")
        nt.links.new(seed2.outputs["Value"], seed3.inputs[0])
        nt.links.new(redge_p.outputs["Value"], seed3.inputs[1])
        # and the cold pools LOW: full strength at the foot, a third at the cap
        pos_r = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Position"], pos_r.inputs["Vector"])
        fall = map_range((1.0, 0.35), fr=(0.30, 1.70))
        nt.links.new(pos_r.outputs["Z"], fall.inputs["Value"])
        seed4 = math_node("MULTIPLY")
        nt.links.new(seed3.outputs["Value"], seed4.inputs[0])
        nt.links.new(fall.outputs["Result"], seed4.inputs[1])
        rime_amt = math_node("MULTIPLY", rime)
        nt.links.new(seed4.outputs["Value"], rime_amt.inputs[0])
        frosted = mix_color()
        frosted.inputs["B"].default_value = (*FROST, 1.0)
        nt.links.new(color_out, frosted.inputs["A"])
        nt.links.new(rime_amt.outputs["Value"], frosted.inputs["Factor"])
        color_out = frosted.outputs["Result"]
        rime_amt_out = rime_amt.outputs["Value"]

    nt.links.new(color_out, bsdf.inputs["Base Color"])

    # A chipped edge is slightly barer, not chromed: metallic rises a little
    # with the wear mask, roughness drops a little. Both bounded.
    met = map_range((metallic, min(0.60, metallic + 0.20)))
    nt.links.new(wear_amt.outputs["Value"], met.inputs["Value"])
    met_out = met.outputs["Result"]
    if rime_amt_out is not None:
        # frost is dielectric
        dm = math_node("MULTIPLY")
        inv = math_node("SUBTRACT")
        inv.inputs[0].default_value = 1.0
        nt.links.new(rime_amt_out, inv.inputs[1])
        nt.links.new(met_out, dm.inputs[0])
        nt.links.new(inv.outputs["Value"], dm.inputs[1])
        met_out = dm.outputs["Value"]
    nt.links.new(met_out, bsdf.inputs["Metallic"])

    rmap = map_range((rough_lo, rough_hi))
    nt.links.new(noise_node(noise_scale * 2.1).outputs["Fac"], rmap.inputs["Value"])
    rough_worn = map_range((0.0, -1.0))
    nt.links.new(wear_amt.outputs["Value"], rough_worn.inputs["Value"])
    rough = math_node("MULTIPLY_ADD")
    rough.use_clamp = True
    nt.links.new(rough_worn.outputs["Result"], rough.inputs[0])
    rough.inputs[1].default_value = 0.12
    nt.links.new(rmap.outputs["Result"], rough.inputs[2])
    rough_out = rough.outputs["Value"]
    if rime_amt_out is not None:
        rr = math_node("MULTIPLY_ADD")
        rr.use_clamp = True
        nt.links.new(rime_amt_out, rr.inputs[0])
        rr.inputs[1].default_value = 0.5
        nt.links.new(rough_out, rr.inputs[2])
        rough_out = rr.outputs["Value"]
    nt.links.new(rough_out, bsdf.inputs["Roughness"])

    # Restrained specular: painted and oxidised surfaces get less of it, the
    # bare and polished ones keep more, which is what separates the zones.
    try:
        bsdf.inputs["Specular IOR Level"].default_value = 0.50 if metallic >= 0.40 else 0.28
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


def vapour(name, color=(0.80, 0.94, 1.0)):
    """A vent puff: emission where the surface faces the camera, transparent
    at the rim, so a sphere reads as a soft blob. Drawn in the glow pass
    only; its strength and size are keyed by animate()."""
    m = _get_mat(name)
    nt, out = _reset_nodes(m)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*color, 1.0)
    em.inputs["Strength"].default_value = 0.0
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.55
    mix = nt.nodes.new("ShaderNodeMixShader")
    # Layer Weight's "Facing" is 0 head-on and 1 at the grazing rim, so the
    # emission goes in the FIRST slot: solid at the centre, gone at the edge.
    # The other way round renders a ring.
    nt.links.new(lw.outputs["Facing"], mix.inputs["Fac"])
    nt.links.new(em.outputs["Emission"], mix.inputs[1])
    nt.links.new(tr.outputs["BSDF"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return m


def glass(name, tint=(0.50, 0.72, 0.80), alpha=0.22):
    """The window pane: a thin, slightly cold-tinted, mostly transparent
    dielectric with a real specular, so the cell behind it reads as BEHIND
    glass. Alpha rather than transmission: at sprite scale refraction does
    nothing but cost bounces."""
    m = _get_mat(name)
    nt, out = _reset_nodes(m)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*tint, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.10
    bsdf.inputs["Alpha"].default_value = alpha
    try:
        bsdf.inputs["Specular IOR Level"].default_value = 0.6
    except KeyError:
        pass
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    m.blend_method = "BLEND"
    return m


def build_materials():
    """Six zones plus the accents, per the design's Material zones section."""
    m = {
        # 1. WORN ASSEMBLER BLUE -- the west half's housing only, never on
        #    mechanism. Flat old paint: low metallic, rough, real chipping, and
        #    the photo grain of rusty painted metal under it.
        "blue": worn_metal("blue", BLUE_LIT, BLUE_DARK, 0.16, 0.62, 0.88,
                           grime=0.30, wear=0.48, rust=0.20, grain=0.28,
                           grain_slug="rusty_painted_metal", noise_scale=8.0),
        # 1b. the skirt: the same paint lower down and dirtier
        "bluelow": worn_metal("bluelow", BLUE_LOW_LIT, BLUE_LOW_DARK, 0.16, 0.66, 0.90,
                              grime=0.46, wear=0.40, rust=0.26, grain=0.30,
                              grain_slug="rusty_painted_metal", noise_scale=8.0),
        # 1c. the panels nearest the seam: condensate off the cold half runs
        #     onto them and sits there, so they carry the worst corrosion on
        #     the machine and the paint has spalled back in plates
        "bluerust": worn_metal("bluerust", BLUE_LOW_LIT, srgb("#1A2330"), 0.18, 0.62, 0.90,
                               grime=0.40, wear=0.62, rust=0.72, grain=0.30,
                               grain_slug="rusty_painted_metal", noise_scale=6.0,
                               streak=0.75),
        # 2. BARE CRYO STEEL -- the grafted half is unpainted, and carries the
        #    rime. Cleaner than the warm half: less grime, less rust -- dirt
        #    does not stick to ice.
        "cryo": worn_metal("cryo", CRYO_LIT, CRYO_DARK, 0.34, 0.44, 0.74,
                           grime=0.16, wear=0.36, rust=0.12, grain=0.16,
                           noise_scale=9.0, rime=0.10),
        # 2b. the vessel's foot and jacket seams: where the cold pools
        "cryofoot": worn_metal("cryofoot", srgb("#5E6674"), srgb("#262A32"), 0.36, 0.46, 0.76,
                               grime=0.18, wear=0.30, rust=0.14, grain=0.16,
                               noise_scale=9.0, rime=0.60),
        # 2d. AQUILO PAINT -- the graft's own identity colour, sampled off the
        #     cryogenic plant's sprite (2026-09-13: lit (133,168,161), shaded
        #     (48,68,72), hue 175, 3% of that sprite). The vessel's shells, the
        #     condenser cowls and the receiver wear it; the west half never does.
        "teal": worn_metal("teal", srgb("#85A8A1"), srgb("#304448"), 0.18, 0.55, 0.85,
                           grime=0.22, wear=0.42, rust=0.16, grain=0.22,
                           grain_slug="rusty_painted_metal", noise_scale=8.0, rime=0.12),
        # 2e. CREAM insulation panels -- a tenth of the cryogenic plant and the
        #     fusion reactor is this pale neutral (182,180,170); it is what makes
        #     a Space Age machine read as late-game against the dark frames
        "cream": worn_metal("cream", srgb("#ACA99E"), srgb("#56544E"), 0.08, 0.58, 0.90,
                            grime=0.26, wear=0.26, rust=0.12, noise_scale=9.0, rime=0.16),
        # 2f. dark composite frames and ribs the cream sits in
        "composite": worn_metal("composite", srgb("#4A5058"), srgb("#181B20"), 0.30, 0.44, 0.76,
                                grime=0.26, wear=0.30, rust=0.10, noise_scale=11.0),
        # 2g. the ribbed hoses: khaki, as the fusion reactor's and the
        #     cryogenic plant's are -- in black rubber they read as shadow
        "hose": worn_metal("hose", srgb("#8E8872"), srgb("#3A362A"), 0.04, 0.66, 0.92,
                           grime=0.30, wear=0.22, rust=0.10, noise_scale=12.0),
        # 2c. insulated sections: matte, no rime -- insulation stays dry
        "lagging": worn_metal("lagging", srgb("#6E757E"), srgb("#30343A"), 0.08, 0.80, 0.96,
                              grime=0.20, wear=0.20, rust=0.10, noise_scale=10.0),
        # 3. galvanised steel: condenser skid, frame, brackets; the seam strap
        #    is the same metal with the rust turned up
        "steel": worn_metal("steel", STEEL_LIT, STEEL_DARK, 0.40, 0.38, 0.64,
                            grime=0.28, wear=0.46, rust=0.30, grain=0.20,
                            noise_scale=10.0),
        "seamsteel": worn_metal("seamsteel", srgb("#7C6A50"), srgb("#2E2419"), 0.38, 0.42, 0.70,
                                grime=0.34, wear=0.50, rust=0.62, grain=0.22,
                                noise_scale=8.0, streak=0.60),
        # the condenser: galvanised, and SOOTED from the top -- the hot side
        "condenser": worn_metal("condenser", STEEL_LIT, STEEL_DARK, 0.40, 0.42, 0.70,
                                grime=0.30, wear=0.42, rust=0.26, grain=0.20,
                                noise_scale=10.0, soot=0.42),
        # 4. dark iron / gunmetal: mechanism, mouths, every recess. Warm.
        "gunmetal": worn_metal("gunmetal", GUNMETAL_LIT, GUNMETAL_DARK, 0.34,
                               0.56, 0.86, grime=0.34, wear=0.30, rust=0.34,
                               noise_scale=11.0),
        # dark iron that is COLD: the window sill, where frost gathers on a
        # ledge the eye can see it against
        "coldiron": worn_metal("coldiron", GUNMETAL_LIT, GUNMETAL_DARK, 0.34,
                               0.56, 0.86, grime=0.20, wear=0.30, rust=0.10,
                               noise_scale=11.0, rime=0.55),
        "cavity": worn_metal("cavity", srgb("#241F19"), srgb("#0A0806"), 0.28,
                             0.72, 0.95, grime=0.46, wear=0.16, rust=0.26,
                             noise_scale=12.0),
        # the cold cell: dark and COOL, the one dark material that is not warm,
        # because it is lit from inside by the cyan
        "pitch": worn_metal("pitch", srgb("#14110D"), srgb("#050403"), 0.24, 0.78, 0.96,
                            grime=0.50, wear=0.10, rust=0.18, noise_scale=12.0),
        # rime 0.10, down from 0.22: the frosted floor round the table caught
        # the key through the opening and the whole window bottom read as
        # one white arc, which is not where the eye should go
        "cell": worn_metal("cell", CELL_LIT, CELL_DARK, 0.30, 0.50, 0.80,
                           grime=0.20, wear=0.20, rust=0.06, noise_scale=12.0,
                           rime=0.10),
        # 5. warm metal: the refrigerant line and riser in bronze, the coil
        #    bundle in copper. Metallic 0.42-0.44 -- higher renders near-black
        #    under a dim world.
        "bronze": worn_metal("bronze", BRONZE_LIT, BRONZE_DARK, 0.42, 0.42, 0.72,
                             grime=0.22, wear=0.44, rust=0.20, grain=0.16,
                             noise_scale=9.0),
        "copper": worn_metal("copper", COPPER_LIT, COPPER_DARK, 0.44, 0.32, 0.56,
                             grime=0.14, wear=0.34, rust=0.14, noise_scale=14.0,
                             rime=0.26),
        # 6. rubber black: cables, hoses, the window gasket
        "rubber": rubber("rubber"),
        # the turntable and anything rubbed by use: polished along its travel
        "scoured": worn_metal("scoured", srgb("#C2AE8E"), srgb("#4E4234"), 0.46,
                              0.22, 0.44, grime=0.16, wear=0.40, rust=0.12,
                              scratch=0.55, noise_scale=13.0),
        "plinth": worn_metal("plinth", CONCRETE_LIT, CONCRETE_DARK, 0.10,
                             0.78, 0.96, grime=0.40, wear=0.20, rust=0.28,
                             noise_scale=6.0),
        "hazard": worn_metal("hazard", HAZARD, srgb("#7A5C1B"), 0.14, 0.60, 0.88,
                             grime=0.24, wear=0.52, rust=0.20, noise_scale=16.0),
        # alpha 0.16: at 0.22 the pane's veil flattened the cell behind it
        # into one pale shape
        "glass": glass("glass", alpha=0.16),
        # Emissives. Strength keeps colour x strength near 1.0 so the hue
        # survives Standard's clip. The render driver DIMS these for the base
        # pass -- the base is drawn in every state and a bright emissive there
        # lights the idle machine -- and the glow layer carries them in full.
        "cyan": plain("cyan", (0.02, 0.05, 0.06), emission=CYAN_EMIT, strength=1.05),
        # the cell's ceiling lamp: hidden behind the bezel, so it may be as
        # bright as the cell needs -- what the window shows is what it lights
        "celllamp": plain("celllamp", (0.02, 0.05, 0.06), emission=CYAN_EMIT, strength=1.25),
        # the floor ring round the table: lit, but under the lamp, so dimmer
        "cyanfloor": plain("cyanfloor", (0.02, 0.05, 0.06), emission=CYAN_EMIT, strength=0.26),
        "cyanlamp": plain("cyanlamp", (0.02, 0.05, 0.06), emission=CYAN_EMIT, strength=0.9),
        "amber": plain("amber", (0.03, 0.02, 0.005), emission=AMBER_EMIT, strength=0.9),
        "violet": plain("violet", (0.02, 0.01, 0.03), emission=VIOLET_EMIT, strength=1.1),
        # the small instrument screens on the cryo half: dark glass, faint green-cyan
        "screen": plain("screen", (0.01, 0.03, 0.03), emission=srgb("#3FBFA0"), strength=0.6),
        # the light line along the window bezel and the sight dome's lamp:
        # cyan, bright only in the glow pass
        # 0.6: at 0.9 the line bloomed into a second window above the window
        "strip": plain("strip", (0.02, 0.05, 0.06), emission=CYAN_EMIT, strength=0.6),
        "sightlamp": plain("sightlamp", (0.02, 0.05, 0.06), emission=CYAN_EMIT, strength=1.0),
        # the relief valve's vent puff at the end of each cycle: glow pass only
        "vapour": vapour("vapour"),
        # gauge dials: pale, so a dark needle reads against them
        "dial": plain("dial", srgb("#B8BFC6"), metallic=0.0, rough=0.5),
    }
    _MATS.clear()
    _MATS.update(m)
    return m


# --------------------------------------------------------------------------
# collections and animation
#
# Three kinds of moving part, because the engine plays them differently
# (measured 2026-09-13 with a tick sequence on an unpowered and a working
# machine):
#
#   CRAFT  the working loop -- graphics_set.animation. Plays only while the
#          machine crafts, at the crafting speed, and freezes where it stops.
#          The old drive train, the turntable and its lock, the transfer arm,
#          the valves, the reacting gauges, the condenser louvres.
#   RUN    the refrigeration -- a working_visualisation with always_draw AND
#          constant_speed, which the engine animates in every state, at the
#          declared speed, even with no power. The condenser fan, the
#          compressor flywheel and its motor pulley, the cabinet fan, the
#          compressor's own pressure needle. A refrigerator holds temperature
#          whether or not you are using it.
#   FAST   the same fan, flywheel and pulley keyed faster, drawn as an opaque
#          disc over the slow ones while the machine works (fadeout on stop).
#          "Slow when idle, fast when working" is a working-only layer that
#          covers the always-on one; make_sheets.py builds the opaque backing
#          from the base sprite.
#
# Silhouettes do not change as these turn, so every one of them belongs in
# the shadow pass too; the arm and the rod travel only inside the hull.
CRAFT_KINDS = ("gear-", "pinion-", "bay-rod", "bay-slider", "table-", "work-",
               "lock-", "arm-", "valve-", "needle-dome", "needle-recv", "louvre-")
RUN_KINDS = ("fan-hub", "fan-blade", "fan2-", "flywheel-", "pulley-", "cabfan-", "needle-comp")
# the FAST layer is the subset of RUN that gets an opaque backing
FAST_KINDS = ("fan-hub", "fan-blade", "fan2-", "flywheel-", "pulley-")
# drawn in the glow pass only: the vent puff is light, not a thing
GLOW_KINDS = ("vapour-",)
# The engine-drawn pipe stubs: rendered on their own, one picture each, and
# hidden from every other layer.
PIPE_KINDS = ("stub-",)
COLL_NAMES = ("QA_Base", "QA_Craft", "QA_Run", "QA_Glow", "QA_Pipe")


def _classify(name):
    stem = name[len(PREFIX):]
    for kinds, coll in ((PIPE_KINDS, "QA_Pipe"), (GLOW_KINDS, "QA_Glow"),
                        (CRAFT_KINDS, "QA_Craft"), (RUN_KINDS, "QA_Run")):
        if any(stem.startswith(k) for k in kinds):
            return coll
    return "QA_Base"


def is_kind(obj, kinds):
    return any(obj.name.startswith(PREFIX + k) for k in kinds)


# every part's built transform, so animate() can start from the rest pose
# however many times it is called (once per layer: craft, run, fast)
REST = {}


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
    REST.clear()
    for o in bpy.data.objects:
        if o.name.startswith(PREFIX) and o.type in ("MESH", "CURVE"):
            REST[o.name] = (o.location.copy(), o.rotation_euler.copy(), o.scale.copy())
    return colls


def _pivot(name, location, collection="QA_Craft", parent=None):
    e = bpy.data.objects.new(PREFIX + name, None)
    e.empty_display_size = 0.15
    e.location = location
    bpy.data.collections[collection].objects.link(e)
    if parent is not None:
        e.parent = parent
        e.matrix_parent_inverse = Matrix.Translation(parent.location).inverted()
    return e


def _attach(pivot, names, world_of_pivot=None):
    """Parent by name prefix, preserving each part's world transform. Built
    from the pivot's LOCATION, not matrix_world: a fresh empty has not been
    through a depsgraph update and its matrix_world is still the identity.
    A pivot that is itself parented passes its world location explicitly."""
    loc = world_of_pivot if world_of_pivot is not None else pivot.location
    inv = Matrix.Translation(loc).inverted()
    got = []
    for obj in bpy.data.objects:
        if not obj.name.startswith(PREFIX) or obj is pivot or obj.type == "EMPTY":
            continue
        stem = obj.name[len(PREFIX):]
        if any(stem.startswith(n) for n in names):
            obj.parent = pivot
            obj.matrix_parent_inverse = inv
            got.append(obj)
    return got


def _fcurves(ad):
    act = ad.action if ad else None
    if act is None:
        return []
    if hasattr(act, "fcurves"):
        return list(act.fcurves)
    curves = []
    # Blender 4.4+: layers > strips > channelbag
    for layer in act.layers:
        for strip in layer.strips:
            bag = strip.channelbag(ad.action_slot)
            if bag:
                curves.extend(bag.fcurves)
    return curves


def _key(obj, path, frames_values, index=None, interp="LINEAR"):
    for f, v in frames_values:
        if index is None:
            setattr(obj, path, v)
            obj.keyframe_insert(path, frame=f)
        else:
            getattr(obj, path)[index] = v
            obj.keyframe_insert(path, index=index, frame=f)
    for fc in _fcurves(obj.animation_data):
        for kp in fc.keyframe_points:
            kp.interpolation = interp


def _clear_animation():
    for obj in bpy.data.objects:
        if obj.name.startswith(PREFIX) and obj.animation_data:
            obj.animation_data_clear()
    for mat in bpy.data.materials:
        if mat.name.startswith(PREFIX) and mat.node_tree and mat.node_tree.animation_data:
            mat.node_tree.animation_data_clear()


def _rest_pose():
    """Remove every pivot (a child returns to its own baked transform) and
    put every directly-keyed part back where it was built."""
    _clear_animation()
    for e in [o for o in bpy.data.objects if o.name.startswith(PREFIX + "piv-")]:
        bpy.data.objects.remove(e, do_unlink=True)
    for name, (loc, rot, scl) in REST.items():
        o = bpy.data.objects.get(name)
        if o is None:
            continue
        o.parent = None
        o.matrix_parent_inverse = Matrix.Identity(4)
        o.location, o.rotation_euler, o.scale = loc.copy(), rot.copy(), scl.copy()


def _smooth(t):
    return t * t * (3.0 - 2.0 * t)


_EASE = {"smooth": _smooth, "in": lambda u: u * u, "out": lambda u: 1.0 - (1.0 - u) ** 2,
         "lin": lambda u: u}


def track(segs, frames):
    """Per-frame values from chronological (f0, f1, v0, v1, ease) segments,
    holding v1 between them. Keyed LINEAR every frame, so the eases are
    exactly what is written here and a heavy part can be given real inertia
    instead of Blender's one-size bezier."""
    vals = []
    v = segs[0][2]
    for f in range(frames + 1):
        for f0, f1, v0, v1, ease in segs:
            if f0 <= f <= f1:
                t = (f - f0) / max(f1 - f0, 1)
                v = v0 + (v1 - v0) * _EASE[ease](t)
                break
            if f > f1:
                v = v1
        vals.append((f, v))
    return vals


def _emission_socket(matname):
    mat = bpy.data.materials.get(PREFIX + matname)
    if not mat or not mat.node_tree:
        return None
    for n in mat.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            return n.inputs["Emission Strength"]
        if n.type == "EMISSION":
            return n.inputs["Strength"]
    return None


def _key_emission(matname, frames_values):
    sock = _emission_socket(matname)
    if sock is None:
        return
    for f, v in frames_values:
        sock.default_value = v
        sock.keyframe_insert("default_value", frame=f)


def _key_sine(matname, frames, lo, hi, cycles=1.0, phase=0.0, step=2):
    vals = []
    for f in range(0, frames + 1, step):
        s = 0.5 + 0.5 * math.sin(2 * math.pi * cycles * f / frames + phase)
        vals.append((f, lo + (hi - lo) * s))
    _key_emission(matname, vals)


# The pivots' world positions, filled in by qa_layout.build() so animate()
# does not have to know the layout's numbers.
PIVOTS = {}

# The craft loop's timeline, in frames of 64. One craft: prepare, transfer
# in, hold, transfer out, index, settle. Nothing shares an edge with anything
# else on purpose -- a machine whose systems all start and stop together
# reads as one animation, not as a machine.
T = dict(
    valve_riser=((2, 10), (52, 60)),      # liquid line opens, closes
    arm_out=(4, 14), head_down=(14, 18), grip=(18, 20),
    head_up=(26, 30), arm_back=(30, 38), release=(38, 40),
    valve_saddle=((20, 26), (44, 50)),    # discharge valve, under load
    louvres=((10, 22), (44, 58)),         # condenser opens under load
    needle_dome=((6, 30), (40, 62)),      # chamber, slow to react
    needle_recv=((14, 34), (44, 62)),     # receiver pressure, later and shorter
    lock_up=(35, 38), index=(38, 49), settle=(49, 53), lock_down=(53, 55),
    valve_lever=((39, 42), (52, 55)),     # the actuated valve, with the index
    vent=(50, 63),                        # the relief valve blows
)


def animate(frames=64, run="slow"):
    """Key the whole machine for one 64-frame loop. `run` picks the speed of
    the RUN parts: "slow" for the always-on layer, "fast" for the working
    overlay. Every rotation is a whole number of turns so the sheet closes
    on the wrap, and every event returns to its rest value by frame 64."""
    _rest_pose()
    tau = 2 * math.pi
    P = PIVOTS
    fast = run == "fast"

    # -- RUN: the refrigeration, continuous ----------------------------------
    # Slow is the idle hum; fast is under load. Different counts per part so
    # nothing strobes in step: fan 7 blades, flywheel 5 spokes, pulley 3.
    fan = _pivot("piv-fan", P["fan"], "QA_Run")
    _attach(fan, ("fan-hub", "fan-blade"))
    _key(fan, "rotation_euler", [(0, 0.0), (frames, (5.0 if fast else 2.0) * tau)], index=2)
    if "fan2" in P:
        # the twin fan turns the other way, a turn slower: two rhythms in one
        # cowl, and the pair never strobes in step
        fan2 = _pivot("piv-fan2", P["fan2"], "QA_Run")
        _attach(fan2, ("fan2-",))
        _key(fan2, "rotation_euler", [(0, 0.0), (frames, (4.0 if fast else 1.0) * -tau)], index=2)
    fly = _pivot("piv-flywheel", P["flywheel"], "QA_Run")
    _attach(fly, ("flywheel-",))
    _key(fly, "rotation_euler", [(0, 0.0), (frames, (4.0 if fast else 2.0) * -tau)], index=1)
    if "pulley" in P:
        pul = _pivot("piv-pulley", P["pulley"], "QA_Run")
        _attach(pul, ("pulley-",))
        # belt ratio 2:1 -- the pulley is half the flywheel's radius
        _key(pul, "rotation_euler", [(0, 0.0), (frames, (8.0 if fast else 4.0) * -tau)], index=1)
    if "cabfan" in P:
        cf = _pivot("piv-cabfan", P["cabfan"], "QA_Run")
        _attach(cf, ("cabfan-",))
        _key(cf, "rotation_euler", [(0, 0.0), (frames, 3.0 * tau)], index=2)
    if "needle-comp" in P:
        nd = _pivot("piv-needle-comp", P["needle-comp"], "QA_Run")
        _attach(nd, ("needle-comp",))
        # discharge pressure: a flick on every stroke, two strokes a turn
        vals = [(f, -0.55 + 0.08 * math.sin(tau * 4 * f / frames)) for f in range(frames + 1)]
        _key(nd, "rotation_euler", vals, index=1)

    # -- CRAFT: the old drive train ------------------------------------------
    gear = _pivot("piv-gear", P["gear"])
    _attach(gear, ("gear-",))
    pinion = _pivot("piv-pinion", P["pinion"])
    _attach(pinion, ("pinion-",))
    _key(gear, "rotation_euler", [(0, 0.0), (frames, -tau)], index=2)
    _key(pinion, "rotation_euler", [(0, 0.0), (frames, 2 * tau)], index=2)   # 18:9 teeth
    rod = bpy.data.objects.get(PREFIX + "bay-rod")
    slider = bpy.data.objects.get(PREFIX + "bay-slider")
    if rod is not None and slider is not None and "crank" in P:
        gx, gy, gz, cr, L = P["crank"]
        s_base = slider.location.copy()
        rest_y = gy + cr + 0.16          # where the slider was built
        for f in range(frames + 1):
            th = -tau * f / frames
            px, py = gx + cr * math.cos(th), gy + cr * math.sin(th)
            sy = py + math.sqrt(max(L * L - (px - gx) ** 2, 0.0))
            rod.location = ((px + gx) / 2, (py + sy) / 2, gz)
            rod.rotation_euler = (0.0, 0.0, math.atan2(sy - py, gx - px))
            rod.keyframe_insert("location", frame=f)
            rod.keyframe_insert("rotation_euler", index=2, frame=f)
            slider.location = (s_base.x, s_base.y + (sy - rest_y), s_base.z)
            slider.keyframe_insert("location", index=1, frame=f)
        for o in (rod, slider):
            for fc in _fcurves(o.animation_data):
                for kp in fc.keyframe_points:
                    kp.interpolation = "LINEAR"

    # -- CRAFT: the indexing turntable ---------------------------------------
    # Locked until the arm is clear; the pin lifts, the table eases through
    # a quarter turn, overshoots two degrees, settles back onto the stop,
    # and the pin drops with a small bounce. Four identical stations, so 90
    # degrees maps the table onto itself and the loop closes.
    table = _pivot("piv-table", P["table"])
    _attach(table, ("table-", "work-"))
    step = tau / 4
    over = math.radians(2.2)
    _key(table, "rotation_euler",
         track([(T["index"][0], T["index"][1], 0.0, step + over, "smooth"),
                (T["settle"][0], T["settle"][1], step + over, step, "smooth")], frames), index=2)
    lock = bpy.data.objects.get(PREFIX + "lock-pin")
    if lock is not None:
        z0 = lock.location.z
        _key(lock, "location",
             track([(T["lock_up"][0], T["lock_up"][1], z0, z0 + 0.035, "smooth"),
                    (T["lock_down"][0], T["lock_down"][1], z0 + 0.035, z0 - 0.004, "in"),
                    (T["lock_down"][1], T["lock_down"][1] + 2, z0 - 0.004, z0, "out")], frames),
             index=2)

    # -- CRAFT: the transfer arm ---------------------------------------------
    # A carriage along the cell's rail (Y, vertical on screen), a head that
    # drops onto the workpiece, two fingers that close on it. Out, down,
    # grip, hold, up, back, release: seven moves, none of them together.
    if "arm" in P:
        ax, ay, az = P["arm"]
        reach = P["arm_reach"]
        arm = _pivot("piv-arm", (ax, ay, az))
        _attach(arm, ("arm-carriage", "arm-head", "arm-finger"))
        head = _pivot("piv-armhead", (ax, ay, az), parent=arm)
        _attach(head, ("arm-head", "arm-finger"), world_of_pivot=(ax, ay, az))
        _key(arm, "location",
             track([(T["arm_out"][0], T["arm_out"][1], ay, ay - reach, "smooth"),
                    (T["arm_back"][0], T["arm_back"][1], ay - reach, ay, "smooth")], frames),
             index=1)
        drop = 0.024
        _key(head, "location",
             track([(T["head_down"][0], T["head_down"][1], az, az - drop, "smooth"),
                    (T["head_up"][0], T["head_up"][1], az - drop, az, "out")], frames),
             index=2)
        for k, sgn in ((0, 1.0), (1, -1.0)):
            fng = bpy.data.objects.get(PREFIX + "arm-finger%d" % k)
            if fng is None:
                continue
            x0 = fng.location.x
            _key(fng, "location",
                 track([(T["grip"][0], T["grip"][1], x0, x0 + sgn * 0.012, "out"),
                        (T["release"][0], T["release"][1], x0 + sgn * 0.012, x0, "out")], frames),
                 index=0)

    # -- CRAFT: valves, gauges, louvres --------------------------------------
    def swing(name, axis, amount, when, ease="smooth"):
        if name not in P:
            return
        piv = _pivot("piv-" + name, P[name][:3])
        _attach(piv, (name,))
        (a0, a1), (b0, b1) = when
        _key(piv, "rotation_euler",
             track([(a0, a1, 0.0, amount, ease), (b0, b1, amount, 0.0, "smooth")], frames),
             index=axis)

    swing("valve-riser", 1, -tau / 4, T["valve_riser"])          # a quarter turn open
    swing("valve-saddle", 2, -tau / 6, T["valve_saddle"])        # a sixth, under load
    swing("valve-lever", 1, 0.85, T["valve_lever"], ease="out")  # the actuator snaps open
    swing("needle-dome", 1, -1.0, T["needle_dome"])
    swing("needle-recv", 1, -0.7, T["needle_recv"])
    for k in range(3):
        swing("louvre-cond-%d" % k, 0, -0.26, T["louvres"])

    # -- GLOW: what the cell throws ------------------------------------------
    # The window: up as the cycle starts, steady through the transfer and the
    # hold, a dip while the table moves, back up, easing off to the wrap.
    # The values multiply each material's built strength.
    curve = track([(0, 6, 0.90, 1.0, "smooth"), (T["index"][0], T["index"][0] + 6, 1.0, 0.82, "smooth"),
                   (T["settle"][0] + 2, T["settle"][1] + 4, 0.82, 1.0, "smooth"),
                   (58, 64, 1.0, 0.90, "smooth")], frames)
    for matname, base in (("celllamp", 1.25), ("cyanfloor", 0.26), ("strip", 0.6)):
        _key_emission(matname, [(f, base * v) for f, v in curve])
    # the sight dome on the cap: a slow breath, out of phase with the lamp
    _key_sine("sightlamp", frames, 0.55, 1.0, cycles=1.0, phase=1.2)
    # the sight glasses: refrigerant flow, two beats a loop, off the window's
    # phase. Peak 1.05 -- Standard clips hard and a cyan past that turns white.
    _key_sine("cyan", frames, 0.80, 1.05, cycles=2.0, phase=-0.9)
    # the receiver's screen: a slow flicker the other way
    _key_sine("screen", frames, 0.45, 0.65, cycles=3.0, phase=1.7, step=4)
    # the vent puff: swells from the relief valve, drifts up, fades
    plume = bpy.data.objects.get(PREFIX + "vapour-plume")
    if plume is not None:
        v0, v1 = T["vent"]
        z0 = plume.location.z
        _key_emission("vapour", [(0, 0.0), (v0, 0.0), (v0 + 3, 1.0), (v1 - 4, 0.55), (v1, 0.0), (frames, 0.0)])
        # scaled to nothing outside its window, so no dark sphere sits on the
        # dome in the frames where the emission is off
        for axis, top in ((0, 1.9), (1, 1.9), (2, 1.6)):
            _key(plume, "scale", track([(v0, v0 + 4, 0.02, 1.0, "out"), (v0 + 4, v1, 1.0, top, "lin"),
                                        (v1, v1 + 1, top, 0.02, "lin")], frames), index=axis)
        _key(plume, "location", track([(v0, v1, z0, z0 + 0.22, "out")], frames), index=2)

    # -- LAMP: the always-on points, at constant speed -----------------------
    # Three lamps, three rhythms. The cyan status lamp breathes once a loop;
    # the amber running lamp holds and flashes twice, unevenly; the violet
    # family point never changes.
    _key_sine("cyanlamp", frames, 0.55, 0.95, cycles=1.0, phase=-math.pi / 2)
    _key_emission("amber", [(0, 0.45), (17, 0.45), (19, 1.0), (24, 0.45),
                            (49, 0.45), (51, 1.0), (54, 0.55), (58, 1.0), (61, 0.45), (frames, 0.45)])
    _key_emission("violet", [(0, 1.1), (frames, 1.1)])

# --------------------------------------------------------------------------
# audit -- spend the budget deliberately and prove the sprite fits


def _world_points():
    dg = bpy.context.evaluated_depsgraph_get()
    out = []
    for ob in bpy.context.scene.objects:
        if ob.type not in ("MESH", "CURVE") or not ob.name.startswith(PREFIX):
            continue
        if ob.name.startswith(PREFIX + "stub-"):
            continue                    # the engine draws these, not the base
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


def audit(a):
    r = a.report()
    print("[detail] %d objects, %d distinct kinds" % (r["objects"], r["distinct_kinds"]))
    print("[detail] kinds: %s" % ", ".join(r["kinds"]))

    pts = _world_points()
    if not pts:
        return
    tallest, name = -1e9, "?"
    offenders = []
    for nm, vs in pts:
        top = max(p.y + p.z for p in vs)
        if top > tallest:
            tallest, name = top, nm
        if top > APEX + 1e-3:
            offenders.append((top, nm))
    print("[apex] tallest y+z = %.2f (%s) -> north overhang %.2f tiles "
          "(budget 0.70; chemical plant 0.77, AM3 ~0.0)"
          % (tallest, name, tallest - FOOTPRINT[1] / 2))
    if offenders:
        offenders.sort(reverse=True)
        print("[apex] %d object(s) OVER %.2f:" % (len(offenders), APEX))
        for v, nm in offenders[:12]:
            print("[apex]   %.2f  %s" % (v, nm))

    # the silhouette: a row is full width only when the east and west
    # extremes both fall in it, so the two must own disjoint row bands
    east = max(max(p.x for p in vs) for _, vs in pts)
    west = min(min(p.x for p in vs) for _, vs in pts)

    def band(at_east):
        lo, hi, who = 1e9, -1e9, set()
        for nm, vs in pts:
            for p in vs:
                if (p.x > east - 0.06) if at_east else (p.x < west + 0.06):
                    lo, hi = min(lo, p.y + p.z), max(hi, p.y + p.z)
                    who.add(nm)
        return lo, hi, sorted(who)

    e_lo, e_hi, e_who = band(True)
    w_lo, w_hi, w_who = band(False)
    overlap = min(e_hi, w_hi) - max(e_lo, w_lo)
    print("[silhouette] east %+.2f rows %.2f..%.2f (%s) | west %+.2f rows %.2f..%.2f (%s)"
          % (east, e_lo, e_hi, ", ".join(e_who[:3]), west, w_lo, w_hi, ", ".join(w_who[:3])))
    if overlap > 0:
        print("[silhouette] FAIL: the extremes share %.2f tiles of rows -- every row "
              "in that band is full width. Move one of them." % overlap)
    else:
        print("[silhouette] ok: extremes disjoint by %.2f tiles" % -overlap)

    # ground reach: nothing at ground level past the tiles, or it lies on the
    # neighbour in a row of machines (the recycler shipped that once)
    low = [(nm, max(max(abs(p.x), abs(p.y)) for p in vs if p.z < 0.30))
           for nm, vs in pts if any(p.z < 0.30 for p in vs)]
    worst = max(low, key=lambda t: t[1]) if low else ("-", 0)
    print("[reach] lowest 0.30 tiles reach %.2f (%s); footprint edge 1.50" % (worst[1], worst[0]))


def main():
    import qa_layout
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[0] if argv else ".")
    out.mkdir(parents=True, exist_ok=True)
    frame = int(argv[argv.index("--frame") + 1]) if "--frame" in argv else 0

    scene = rig.empty_scene()
    a = qa_layout.build(build_materials())
    organise()
    animate(frames=64)
    bpy.context.view_layer.update()
    audit(a)

    rig.camera(scene, CANVAS)
    rig.lights(scene, key=KEY, fill=FILL, ambient=AMBIENT)
    rig.output(scene, CANVAS)
    rig.cycles(scene, samples=96)
    for c in bpy.data.collections:
        if c.name in ("QA_Pipe", "QA_Glow"):
            c.hide_render = True
    scene.frame_set(frame)
    scene.render.filepath = str(out / "look.png")
    bpy.ops.render.render(write_still=True)
    print("[render] %s" % (out / "look.png"))

    blend = Path(__file__).resolve().parent / "quality-assembler.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    print("[blend] %s" % blend)


if __name__ == "__main__":
    # qa_layout does `import qa_gen`; without this alias that would be a
    # SECOND copy of this module with an empty _MATS, and every part would
    # render in Blender's default grey.
    sys.modules["qa_gen"] = sys.modules[__name__]
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    main()
