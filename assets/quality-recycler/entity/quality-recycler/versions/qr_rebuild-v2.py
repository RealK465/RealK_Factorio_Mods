"""The rebuilt Quality Recycler: new curved primitives, and the Phase 1 blockouts.

This module owns the geometry the original generator could not make. It imports
`quality_recycler_gen` for everything that already works -- materials, the
cone rule, the direction transform, the audit -- and adds what the rebuild
needs on top. Nothing here changes the render rig.

**The one geometric fact that drives the rebuild.** The camera looks along
`(0, cos45, -sin45)`, and this rig scales world Y and world Z to the same
64 px in the row direction, so screen row is `-(y + z)` and screen column is
`x`. Feed a circle through that:

    axis Z, circle at (x0, y0, z0):  col = x0 + r cos t,  row = -(y0 + z0 + r sin t)
    axis Y, circle at (x0, y0, z0):  col = x0 + r cos t,  row = -(y0 + z0 + r sin t)
    axis X, circle at (x0, y0, z0):  col = x0,            row = -(y0 + z0 + r*sqrt2*sin(t+45))

So a ring about Z **or** about Y projects as a true circle on screen, and a
ring about X projects as a line. `quality_recycler_gen` already knew the last
of those. What it did not use is the consequence for a ROTATABLE entity:

    set_direction() spins the model about Z, so a Y-axis ring becomes an
    X-axis ring in east and west -- round in two rotations, flat in two.
    A Z-AXIS RING IS THE ONLY RADIAL FORM THAT SURVIVES ALL FOUR.

That is why every variant below puts at least one large Z-axis circle over the
rotor, and it is the single highest-impact change available to this sprite.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import quality_recycler_gen as gen                              # noqa: E402

sys.path.insert(0, gen._skill_scripts())
from factorio_render import parts                               # noqa: E402

PREFIX = gen.PREFIX
DECK = gen.DECK
cone_z = gen.cone_z


# --------------------------------------------------------------------------
# curved primitives
#
# `cyl()` makes a solid disc, which is why the original build kept lidding the
# hubs it meant to surround. Everything below is a genuine annulus.


def _axis_rot(bm, verts, axis):
    """Match `cyl()`: local Z is the part's axis, rotated into place."""
    if axis == "Z":
        return
    bmesh.ops.rotate(bm, verts=verts, cent=(0, 0, 0),
                     matrix=Matrix.Rotation(math.radians(90), 3,
                                            "Y" if axis == "X" else "X"))


def _angles(a0, a1, seg):
    full = abs(a1 - a0) >= 359.9
    if full:
        n = seg
        return [math.radians(a0 + 360.0 * i / n) for i in range(n)], True
    n = max(3, int(round(seg * abs(a1 - a0) / 360.0)) + 1)
    return [math.radians(a0 + (a1 - a0) * i / (n - 1)) for i in range(n)], False


def ring(name, centre, r_out, r_in, length, axis="Z", mat=None, seg=40,
         a0=0.0, a1=360.0, **kw):
    """A true annulus (or an arc of one), extruded along its own axis.

    Windings are written out by hand rather than left to
    `recalc_face_normals`, which flips faces on intersecting closed shells --
    and a machine assembled from overlapping solids in one mesh is exactly
    that.
    """
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
    return gen._emit(bm, name, gen._MATS.get(mat), **kw)


def torus(name, centre, major, minor, axis="Z", mat=None, seg=40, mseg=10,
          a0=0.0, a1=360.0, **kw):
    """A round-section hoop -- a field coil, a guard hoop, a coupling collar."""
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
    return gen._emit(bm, name, gen._MATS.get(mat), **kw)


def radial_bars(name, centre, r0, r1, half_w, thick, count, axis="Z", mat=None,
                phase=0.0, taper=1.0, **kw):
    """`count` bars radiating from r0 to r1 -- rotor poles, fan blades, spokes.

    One object, so the parts share a colour jitter and read as one fabricated
    rotor rather than as a pile of separate bars. `taper` narrows the outer
    end: a pole piece is wider at its root.
    """
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
    return gen._emit(bm, name, gen._MATS.get(mat), **kw)


def barrel(name, centre, radius, length, axis="Y", mat=None, seg=32,
           bulge=0.0, **kw):
    """A cylinder whose flank can bow outward -- `bulge` in tiles at the waist.

    A dead-straight cylinder reads as pipe; a slight barrel reads as a machined
    drum. The bulge is a cosine along the axis so the end radii are exact and
    the end flanges still sit flush.
    """
    bm = bmesh.new()
    rings = max(3, int(length / 0.10) + 1)
    cols = []
    for i in range(rings):
        u = i / (rings - 1.0)
        z = (u - 0.5) * length
        r = radius + bulge * math.cos(math.pi * (u - 0.5)) ** 2
        cols.append([bm.verts.new((r * math.cos(2 * math.pi * k / seg),
                                   r * math.sin(2 * math.pi * k / seg), z))
                     for k in range(seg)])
    for i in range(rings - 1):
        for k in range(seg):
            l = (k + 1) % seg
            bm.faces.new((cols[i][k], cols[i + 1][k], cols[i + 1][l], cols[i][l]))
    bm.faces.new(cols[0][::-1])
    bm.faces.new(cols[-1])
    _axis_rot(bm, bm.verts[:], axis)
    bmesh.ops.translate(bm, verts=bm.verts[:], vec=Vector(centre))
    kw.setdefault("cuts", 1)
    return gen._emit(bm, name, gen._MATS.get(mat), **kw)


def hood(name, x0, x1, centre_yz, radius, mat=None, seg=20, a0=0.0, a1=180.0,
         thick=0.05, **kw):
    """A curved cowling over a deck: an arc in the Y-Z plane swept along X.

    Swept along X on purpose. The curvature then lies in the plane the view
    direction sits in, so the shading runs the full length of the arc and the
    cowl reads as round rather than as a folded plate.
    """
    bm = bmesh.new()
    angs, _ = _angles(a0, a1, seg * 2)
    cy, cz = centre_yz
    outer = [(cy + radius * math.cos(t), cz + radius * math.sin(t)) for t in angs]
    inner = [(cy + (radius - thick) * math.cos(t),
              cz + (radius - thick) * math.sin(t)) for t in angs]
    for xs in ((x0, x1),):
        lo_o = [bm.verts.new((xs[0], y, z)) for y, z in outer]
        hi_o = [bm.verts.new((xs[1], y, z)) for y, z in outer]
        lo_i = [bm.verts.new((xs[0], y, z)) for y, z in inner]
        hi_i = [bm.verts.new((xs[1], y, z)) for y, z in inner]
    for i in range(len(angs) - 1):
        bm.faces.new((lo_o[i], lo_o[i + 1], hi_o[i + 1], hi_o[i]))
        bm.faces.new((hi_i[i], hi_i[i + 1], lo_i[i + 1], lo_i[i]))
        bm.faces.new((lo_i[i], lo_i[i + 1], lo_o[i + 1], lo_o[i]))
        bm.faces.new((hi_o[i], hi_o[i + 1], hi_i[i + 1], hi_i[i]))
    # Close BOTH ends with a full plate across the chord, not just the shell's
    # rim. A hollow arc shows its concave inside once the machine rotates and
    # the end faces the camera, and reads as a trough rather than a cowling.
    ch_lo = [bm.verts.new((x0, cy + radius * math.cos(t),
                           cz + radius * math.sin(t))) for t in (angs[0], angs[-1])]
    ch_hi = [bm.verts.new((x1, cy + radius * math.cos(t),
                           cz + radius * math.sin(t))) for t in (angs[0], angs[-1])]
    bm.faces.new([lo_o[i] for i in range(len(angs))][::-1] + [ch_lo[1], ch_lo[0]])
    bm.faces.new([hi_o[i] for i in range(len(angs))] + [ch_hi[1], ch_hi[0]][::-1])
    bm.faces.new((ch_lo[0], ch_lo[1], ch_hi[1], ch_hi[0]))
    kw.setdefault("cuts", 1)
    return gen._emit(bm, name, gen._MATS.get(mat), **kw)


# --------------------------------------------------------------------------
# the layout
#
# Two masses on a diagonal with an open gap, which is what the concept sheet
# asks for and what the shipped build lost. The shredder owns the SOUTH-WEST,
# the rotor the NORTH-EAST, and the gap runs between them. Every number is
# checked against cone_z() at its own outermost corner; `audit()` prints the
# worst offender on every build and `fit_cone()` takes up the last couple of
# percent.

ROTOR = (0.60, 0.42)                # centre of the hero, north-east
ROTOR_Z = 0.80
SHRED = (-0.70, -0.52)              # centre of the salvaged half, south-west
GRADE = (0.74, -1.00)               # the grading pod, south-east
SEAM = (-0.04, -0.10)               # the coupling collar, on the diagonal

# Five lenses in the vanilla quality colours, read out of the prototypes:
# normal 178,178,178 / uncommon 43,165,61 / rare 25,104,178 / epic 137,0,178 /
# legendary 178,104,0. Five, not four -- the bins the shipped build used carry
# only the four above normal, and the row reads as a scale when the neutral
# one anchors it.
QUALITY = ["#B2B2B2", "#2BA53D", "#1968B2", "#8900B2", "#B26800"]

# The base colours the LENSES are painted, which are not the quality colours --
# they are pre-compensated so the RENDERED pixel lands on them.
#
# A 4 px lit dielectric under this rig carries a whitening floor of roughly
# +105 per channel from the key, the sky and the paint-over's value and
# contrast terms, and no base colour can undercut it: painted the true
# prototype values, the row measured
#
#     normal    (214,212,210)   want (178,178,178)
#     uncommon  (133,217,155)   want ( 43,165, 61)
#     rare      ( 90,184,213)   want ( 25,104,178)   -- cyan, not navy
#     epic      (140, 95,123)   want (137,  0,178)   -- mauve, blue lost
#     legendary (218,191, 77)   want (178,104,  0)   -- yellow, not amber
#
# The lift is not uniform, so the correction is per channel: whichever channel
# renders furthest above its target is pulled furthest down. The five have to
# read as five DIFFERENT colours in the right order before they have to match a
# hex code, and rare reading cyan was the one that broke that.
LENS_BASE = ["#8E8E90", "#00BE12", "#0028C8", "#5000FF", "#C83C00"]

# Filled by extra_materials(); qr_anim reads it so the scan sweep lights each
# lens to the same ceiling rather than driving the saturated ones into clip.
LENS_STRENGTH = []


def extra_materials():
    """The five quality lenses, added to whatever `build_materials()` made.

    **The base sheet carries the true colour, the glow sheet carries the
    light.** An emission shader washes its own hue toward white under this rig:
    at strength ~1.3 the `rare` lens rendered (56, 127, 204) against the
    prototype's (25, 104, 178), and `normal` came back lavender rather than
    neutral. Five 12 px discs whose whole job is to name five quality tiers
    cannot afford that. So the disc is a lit dielectric in the quality colour
    with just enough emission to read as a lens rather than as a painted dot,
    and the additive light sheet supplies the brightness.
    """
    # THE ALBEDO AND THE EMISSION ARE DIFFERENT COLOURS, and they have different
    # jobs. The albedo is `LENS_BASE`, pre-compensated so the LIT disc lands on
    # the prototype value. The emission is the prototype value itself, because
    # the glow sheet is added over the base and vanilla's own ramp is what the
    # sum should look like.
    #
    # Strength is per lens, and the reason is physics rather than taste. A
    # saturated blue or purple cannot emit as much luminance as a green without
    # being desaturated -- vanilla's own ladder is uneven for exactly that
    # reason: normal luma 178, uncommon 129, rare 95, epic 48, legendary 122.
    # So the rule is not "equalise", it is "cap": no channel may exceed ~0.95
    # (Standard clips hard, and a clipped lens takes its hue with it), and no
    # lens may emit more luminance than 0.55. The first bound binds rare, epic
    # and legendary; the second binds normal and uncommon, which is what stops
    # the LOWEST tier being the brightest lamp on the machine.
    for i, hexcol in enumerate(LENS_BASE):
        alb = gen.srgb(hexcol)
        emit = gen.srgb(QUALITY[i])
        peak = max(emit)
        lum = 0.2126 * emit[0] + 0.7152 * emit[1] + 0.0722 * emit[2]
        strength = min(0.95 / max(peak, 1e-3), 0.55 / max(lum, 1e-3))
        LENS_STRENGTH.append(strength)
        # roughness 0.52, not 0.26: a tight specular lobe on a 4 px disc is a
        # white pixel in the middle of it, which is most of the whitening.
        gen._MATS["q%d" % i] = gen.plain(
            "q%d" % i, alb, metallic=0.0, rough=0.52,
            # 0.10, not 0.22: at 0.22 the row got BRIGHTER than the flat
            # 0.16 it replaced and the five pips merged into one bar at
            # gameplay zoom. 0.10 keeps the row's total where it was and
            # spends the change on its SHAPE -- normal down, the three
            # saturated tiers up.
            emission=emit, strength=0.10 * strength)
    # The arcs need their OWN material. They flicker irregularly while the
    # field pulses on the rotor's beat, and two objects sharing one material
    # share its keyframes -- so on `violet` the arcs would have pulsed in time
    # with the field, which is exactly the periodic blink Fulgora is not.
    gen._MATS["arcmat"] = gen.plain(
        "arcmat", (0.02, 0.01, 0.03), metallic=0.0, rough=0.30,
        emission=gen.srgb("#C46BFF"), strength=1.9)


def yz_prism(name, polys, x0, x1, mat=None, **kw):
    """Polygons in the Y-Z plane extruded along X -- a decal on a WEST or EAST
    wall. `gen.xz_prism` only does north and south; this entity rotates, so
    every wall is somebody's front elevation."""
    bm = bmesh.new()
    for poly in polys:
        near = [bm.verts.new((x0, y, z)) for y, z in poly]
        far = [bm.verts.new((x1, y, z)) for y, z in poly]
        bm.faces.new(near[::-1])
        bm.faces.new(far)
        n = len(poly)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((near[i], near[j], far[j], far[i]))
    return gen._emit(bm, name, gen._MATS.get(mat), **kw)


def wall_chevrons(name, wall, u0, u1, z0, z1, at, count=6, lean=0.62,
                  mat="hazard"):
    """A hazard band on any of the four walls, on a dark backing plate.

    Vanilla paints hazard stripes on black. Yellow straight onto olive is two
    mid-tones of one warm hue and disappears at gameplay zoom, which is what
    happened to the shipped build's chevrons.
    """
    span, skew = u1 - u0, (z1 - z0) * lean
    pitch = (span - skew) / count
    w = pitch * 0.52
    polys = [[(u0 + j * pitch, z0), (u0 + j * pitch + w, z0),
              (u0 + j * pitch + w + skew, z1), (u0 + j * pitch + skew, z1)]
             for j in range(count)]
    pad, out = 0.03, []
    sgn = -1.0 if wall in ("S", "W") else 1.0
    lo, hi = at + sgn * 0.030, at + sgn * 0.014
    plate = (at + sgn * 0.016, at + sgn * 0.006)
    if wall in ("S", "N"):
        out.append(gen.boxes(name + "-back",
                             [((u0 - pad, min(plate), z0 - pad),
                               (u1 + skew + pad, max(plate), z1 + pad))],
                             mat="cavity", cuts=1, bevel=0.006))
        out.append(gen.xz_prism(name, polys, min(lo, hi), max(lo, hi), mat=mat,
                                cuts=0, bevel=0.004))
    else:
        out.append(gen.boxes(name + "-back",
                             [((min(plate), u0 - pad, z0 - pad),
                               (max(plate), u1 + skew + pad, z1 + pad))],
                             mat="cavity", cuts=1, bevel=0.006))
        out.append(yz_prism(name, polys, min(lo, hi), max(lo, hi), mat=mat,
                            cuts=0, bevel=0.004))
    return out


def _pad():
    """Octagonal, and NOTCHED on the gap diagonal so ground shows through it.

    A gap between two masses is only a gap if the sprite has alpha in it. The
    shipped build's gap sat over a continuous pad, so it was a dark seam on a
    solid silhouette and the eye read one block.
    """
    c = 0.40
    poly = [(-1.36 + c, -1.42), (0.30, -1.42), (0.62, -1.20), (1.00, -1.34),
            (1.34, -1.34), (1.34, -1.42 + c), (1.34, 1.30 - c), (1.34 - c, 1.30),
            (-0.32, 1.30), (-0.62, 1.06), (-0.96, 1.26), (-1.36 + c, 1.26),
            (-1.36, 1.26 - c), (-1.36, -1.42 + c)]
    return gen.prism("pad", poly, 0.0, DECK, mat="concrete", cuts=1, bevel=0.02)


def _shredder(a):
    """The salvaged olive half: chunky, stepped, with a curved cowl and a maw.

    Kept boxy on purpose -- the brief's futurism gradient puts the refinement
    at the rotor end and leaves this one grounded in vanilla. What it gets is
    one curved primary form (the cowl), cleaner steps, and a maw big enough to
    survive gameplay zoom.
    """
    sx, sy = SHRED
    out = []
    # skirt, then the block: two steps, both inside the footprint
    out.append(gen.box("shred-skirt", (-1.32, -1.34, DECK), (-0.06, 0.30, 0.58),
                       mat="olive"))
    out.append(gen.box("shred-hull", (-1.20, -1.22, DECK), (-0.16, 0.20, 1.00),
                       mat="olive"))
    # the cowl -- the olive half's one curved primary form
    out.append(hood("shred-cowl", -1.02, -0.20, (sy + 0.04, 0.96), 0.30,
                    mat="olive", thick=0.06, a0=-8.0, a1=188.0))
    out.append(ring("shred-cowl-rib0", (-0.98, sy + 0.04, 0.96), 0.32, 0.26,
                    0.05, axis="X", mat="steel", a0=-8.0, a1=188.0))
    out.append(ring("shred-cowl-rib1", (-0.24, sy + 0.04, 0.96), 0.32, 0.26,
                    0.05, axis="X", mat="steel", a0=-8.0, a1=188.0))
    # THE MAW. Wide and deep, in the south wall, with the rollers visible.
    # The shipped build's opening was 0.40 tiles of slot; at gameplay zoom
    # that is 6 px and the teeth inside it were 1.
    out.append(gen.box("maw-cav", (-1.06, -1.30, 0.20), (-0.30, -1.02, 0.70),
                       mat="cavity"))
    for i, z in enumerate((0.30, 0.46, 0.62)):
        out.append(gen.cyl("maw-roller%d" % i, (-0.68, -1.14, z), 0.075, 0.70,
                           axis="X", mat="gunmetal", seg=16))
        out.append(radial_bars("maw-teeth%d" % i, (-0.68, -1.14, z), 0.055,
                               0.105, 0.020, 0.66, 9, axis="X", mat="scoured"))
    # hazard chevrons flanking the maw on the south wall, and on the west wall
    # too: west is the front elevation in the east rotation.
    out += wall_chevrons("shred-chev-s", "S", -1.16, -0.22, 0.72, 0.96, -1.22,
                         count=7)
    out += wall_chevrons("shred-chev-w", "W", -1.10, 0.10, 0.62, 0.88, -1.20,
                         count=7)
    return out


def _grading(a):
    """The grading unit: five up-facing lenses in the quality colours.

    UP-facing, and that is the whole design. An emissive on a wall is face-on
    in one rotation, a bright streak in two and invisible in the fourth; the
    deck is the one surface this camera always sees. The lenses sit on a panel
    tilted 18 degrees so they catch a highlight as well.
    """
    gx, gy = GRADE
    out = []
    out.append(gen.box("grade-body", (0.16, -1.30, DECK), (1.32, -0.54, 0.50),
                       mat="steel"))
    out.append(gen.box("grade-face", (0.20, -1.26, 0.48), (1.28, -0.62, 0.56),
                       mat="gunmetal"))
    # the scan window: a dark glass strip the sweep runs along
    out.append(gen.box("grade-window", (0.26, -1.14, 0.545), (1.22, -0.94, 0.575),
                       mat="cavity"))
    for i, hexcol in enumerate(QUALITY):
        x = 0.30 + i * 0.225
        out.append(gen.cyl("grade-lens%d" % i, (x, -1.20, 0.575), 0.062, 0.05,
                           axis="Z", mat="q%d" % i, seg=14))
        out.append(ring("grade-bezel%d" % i, (x, -1.20, 0.572), 0.082, 0.062,
                        0.055, axis="Z", mat="gunmetal", seg=14))
    out.append(gen.box("grade-chute", (0.86, -1.44, 0.16), (1.22, -1.16, 0.44),
                       mat="gunmetal"))
    return out


def _junction(a):
    """The seam: a machined coupling collar plus swept conduits over the gap.

    The collar is a Z-axis torus, so it stays a circle in all four rotations
    and marks the join from every side. Vanilla reads a join as a FITTING, not
    as a gap -- a uniform gap everywhere is what makes props look like props.
    """
    jx, jy = SEAM
    out = []
    out.append(torus("seam-collar", (jx, jy, 0.62), 0.30, 0.075, axis="Z",
                     mat="copper", seg=32))
    out.append(ring("seam-plate", (jx, jy, 0.40), 0.34, 0.20, 0.44, axis="Z",
                    mat="bronze", seg=28))
    for i, dz in enumerate((0.0, 0.10, 0.20)):
        out.append(torus("seam-clamp%d" % i, (jx, jy, 0.30 + dz), 0.23, 0.030,
                         axis="Z", mat="gunmetal", seg=20, mseg=8))
    return out


def _stack():
    """Exhaust stack, central. Height is free in the middle of the cone and
    costs overhang at the edges, which is why it is not on the olive half."""
    out = [gen.cyl("stack", (-0.10, 0.44, 1.10), 0.115, 0.70, axis="Z",
                   mat="gunmetal", seg=18),
           ring("stack-cowl", (-0.10, 0.44, 1.46), 0.175, 0.115, 0.10,
                axis="Z", mat="steel", seg=18),
           torus("stack-band", (-0.10, 0.44, 1.06), 0.135, 0.028, axis="Z",
                 mat="bronze", seg=18, mseg=8)]
    return out


# --------------------------------------------------------------------------
# the three hero variants


def hero_A(a):
    """A -- CAGED DRUM. The design doc's rotor, exposed under an open cage.

    Drum about Y with a copper pole face at BOTH ends, three arc ribs standing
    over it with daylight between them, and one Z-axis guard ring so something
    radial survives the east and west rotations.
    """
    rx, ry = ROTOR
    rz = ROTOR_Z
    out = [barrel("rotor-drum", (rx, ry, rz), 0.36, 0.86, axis="Y",
                  mat="temper", bulge=0.022)]
    for s in (-1, 1):
        y = ry + s * 0.44
        out.append(ring("rotor-flange%s" % ("n" if s > 0 else "s"),
                        (rx, y, rz), 0.40, 0.155, 0.06, axis="Y", mat="copper"))
        out.append(radial_bars("rotor-hub%s" % ("n" if s > 0 else "s"),
                               (rx, y + s * 0.035, rz), 0.16, 0.385, 0.055,
                               0.05, 12, axis="Y", mat="copper", taper=0.7))
        out.append(gen.cyl("rotor-bolts%s" % ("n" if s > 0 else "s"),
                           (rx, y + s * 0.045, rz), 0.135, 0.05, axis="Y",
                           mat="gunmetal", seg=16))
    for i, ang in enumerate((-4.0, 62.0, 128.0)):
        out.append(ring("cage-arc%d" % i, (rx, ry - 0.30 + i * 0.30, rz),
                        0.50, 0.43, 0.075, axis="Y", mat="bronze",
                        a0=ang, a1=ang + 52.0))
    out.append(torus("cage-hoop", (rx, ry, rz + 0.44), 0.50, 0.055, axis="Z",
                     mat="steel", seg=32))
    out.append(ring("rotor-band", (rx, ry, rz), 0.375, 0.34, 0.09, axis="Y",
                    mat="copper"))
    return out


def hero_B(a):
    """B -- VERTICAL ROTOR DISC. Rotation-invariant, and the least literal.

    The separator becomes a wide Z-axis disc: copper pole pieces radiating
    from a hub, recessed in a bronze ring housing under a segmented guard
    ring. It projects as a circle with spokes in EVERY rotation, which is the
    strongest radial read available at this camera -- at the price of the
    design doc's horizontal eddy drum.
    """
    rx, ry = ROTOR
    rz = 0.70
    out = [ring("rotor-well", (rx, ry, 0.40), 0.72, 0.60, 0.56, axis="Z",
                mat="bronze", seg=36),
           gen.cyl("rotor-floor", (rx, ry, 0.24), 0.62, 0.10, axis="Z",
                   mat="cavity", seg=32),
           gen.cyl("rotor-drum", (rx, ry, rz), 0.20, 0.30, axis="Z",
                   mat="temper", seg=24),
           radial_bars("rotor-hub", (rx, ry, rz - 0.02), 0.19, 0.58, 0.075,
                       0.11, 14, axis="Z", mat="copper", taper=0.62),
           ring("rotor-band", (rx, ry, rz - 0.03), 0.60, 0.53, 0.10, axis="Z",
                mat="copper", seg=32),
           torus("rotor-cap", (rx, ry, rz + 0.16), 0.16, 0.055, axis="Z",
                 mat="steel", seg=20)]
    for i in range(4):
        out.append(ring("cage-arc%d" % i, (rx, ry, rz + 0.26), 0.74, 0.62,
                        0.07, axis="Z", mat="steel",
                        a0=14.0 + i * 90.0, a1=76.0 + i * 90.0))
        ang = math.radians(-4.0 + i * 90.0)
        out.append(gen.cyl("cage-post%d" % i,
                           (rx + 0.68 * math.cos(ang), ry + 0.68 * math.sin(ang),
                            0.46), 0.045, 0.62, axis="Z", mat="steel", seg=10))
    return out


def hero_C(a):
    """C -- DRUM IN A FIELD COIL. The doc's drum, with a Z-axis coil over it.

    Keeps the copper-wound horizontal drum the lore anchor needs, and hands
    the rotation-invariant circle to a large toroidal field coil lying flat
    around it. The drum's crown rises THROUGH the coil plane, so the two read
    as one assembly rather than a hoop parked beside a barrel.
    """
    rx, ry = ROTOR
    rz = 0.74
    out = [barrel("rotor-drum", (rx, ry, rz), 0.34, 0.80, axis="Y",
                  mat="temper", bulge=0.02),
           ring("rotor-band", (rx, ry, rz), 0.355, 0.32, 0.10, axis="Y",
                mat="copper")]
    for s in (-1, 1):
        y = ry + s * 0.41
        out.append(ring("rotor-flange%s" % ("n" if s > 0 else "s"),
                        (rx, y, rz), 0.38, 0.15, 0.055, axis="Y", mat="copper"))
        out.append(radial_bars("rotor-hub%s" % ("n" if s > 0 else "s"),
                               (rx, y + s * 0.03, rz), 0.15, 0.365, 0.05,
                               0.045, 12, axis="Z" if False else "Y",
                               mat="copper", taper=0.7))
    # the field coil: two concentric Z-axis hoops with the windings between
    out.append(torus("coil-outer", (rx, ry, 0.96), 0.58, 0.085, axis="Z",
                     mat="bronze", seg=36))
    out.append(torus("coil-inner", (rx, ry, 0.92), 0.44, 0.055, axis="Z",
                     mat="bronze", seg=32))
    for k in range(16):
        ang = 2 * math.pi * k / 16
        out.append(gen.box("coil-wind%d" % k,
                           (rx + 0.42 * math.cos(ang) - 0.035,
                            ry + 0.42 * math.sin(ang) - 0.035, 0.86),
                           (rx + 0.62 * math.cos(ang) + 0.035,
                            ry + 0.62 * math.sin(ang) + 0.035, 0.99),
                           mat="copper", cuts=1))
    for i in range(3):
        ang = math.radians(30.0 + i * 120.0)
        out.append(gen.cyl("coil-post%d" % i,
                           (rx + 0.58 * math.cos(ang), ry + 0.58 * math.sin(ang),
                            0.54), 0.05, 0.84, axis="Z", mat="steel", seg=10))
    return out


HEROES = {"A": hero_A, "B": hero_B, "C": hero_C}


def blockout(mats, variant="C"):
    """Primary masses, the hero, the junction and the grading unit. No
    tertiary hardware and no surface pass -- this is what Phase 1 judges."""
    extra_materials()
    a = parts.Assembly(PREFIX, mats)
    a.purge()
    for obj in [o for o in bpy.data.objects if o.name.startswith(PREFIX)]:
        bpy.data.objects.remove(obj, do_unlink=True)
    for c in [c for c in bpy.data.collections if c.name in gen.COLL_NAMES]:
        bpy.data.collections.remove(c)

    made = [_pad()]
    made += _shredder(a)
    made += HEROES[variant](a)
    made += _junction(a)
    made += _grading(a)
    made += _stack()
    # rotor deck under the hero, so it is not floating on the pad
    made.append(gen.box("rot-deck", (0.08, -0.30, DECK), (1.30, 1.26, 0.42),
                        mat="tempers"))
    made.append(gen.box("rot-step", (0.20, -0.18, 0.42), (1.20, 1.14, 0.56),
                        mat="temperv"))
    a.placed.extend([o for o in made if o])
    gen.organise()
    return a
