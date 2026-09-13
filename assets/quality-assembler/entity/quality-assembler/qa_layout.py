"""The Quality Assembler: an assembling machine that came back from Aquilo with
half of it replaced.

Coordinates: 1 unit = 1 tile, +y north (screen up), +x east, z up. Screen row
is -(y + z); only the top deck and the SOUTH wall are ever seen, and the
sprite's top edge is set by the largest y + z (qa_gen.APEX = 2.20).

## The massing, west to east

    WEST -- the old machine.  A chamfered blue skirt on the plinth, the same
    shape as every vanilla assembler's, with its top deck cut open as a
    mechanism bay (gear, pinion, a gearbox, the handwheel). A narrow blue
    cabinet tower stands in the south-west corner carrying the five-slot
    MODULE RACK; a low gearbox housing with a louvre grille sits south of the
    bay. The retrofit's COMPRESSOR is bolted to the north-west corner of the
    deck, its flywheel facing the camera, its mount plate hanging past the
    hull on a bracket -- the sprite's west extreme.

    THE SEAM -- a bare-steel strap up the south wall and a bolted joining
    plate across the deck, dead centre, rustier than anything else on the
    machine because condensate off the cold half runs onto the old paint.

    EAST -- the graft. A galvanised skid plate with the COLD BUILD VESSEL on
    it: a jacketed cylinder with a heavy dark-bezelled window on its south
    face and the indexing TURNTABLE behind the glass, lit from a ceiling lamp
    the bezel hides; a copper coil bundle round its upper shell; a bolted cap
    and an insulated dome. In front of it, low, the CONDENSER skid with its
    fan in the top, louvres on its face and chevrons at its foot -- the east
    extreme. Behind it, north-east, the RISER: the liquid line up through an
    insulated receiver drum and over into the coil -- the skyline.

    The refrigeration circuit is one loop of four pipe runs, each joining two
    real pieces of equipment: compressor -> condenser, condenser -> receiver,
    receiver -> coil, coil -> compressor.

## Why the west is low and the east is tall

The camera hides everything behind a mass up to that mass's (north edge +
height). The first build put a tall cabinet in front of the mechanism bay
and the bay rendered as a black slot. So the old half is SQUAT -- skirt,
open deck, one corner tower -- and the graft is what stands up. That is also
the story: the old assembler was never tall; what came back from Aquilo is.

## The silhouette guarantee

A row is full width only when the east and west screen extremes both fall in
it. West: the compressor's mount plate and rail (x -1.50, rows about
1.0..1.9). East: the condenser skid (x +1.50, rows about -1.0..0.0). Disjoint
by a tile; qa_gen.audit() checks it before a render is paid for.
"""
import math

import bpy

import qa_gen as gen
from qa_gen import (box, boxes, cyl, prism, ring, torus, helix, radial_bars,
                    fan_blades, chamfer_rect, chevrons, wall_louvres, PLINTH)  # noqa: F401

from factorio_render import parts

PREFIX = gen.PREFIX
EPS = 0.004

# ---- the layout ----------------------------------------------------------

HULL = (-1.36, -1.36, -0.12, 1.10)          # the old skirt: x0, y0, x1, y1
SKIRT_TOP = 0.60
DECK_TOP = SKIRT_TOP + 0.06
BAY = (-1.20, -0.52, -0.26, 0.36)           # the mechanism opening in the deck
BAY_FLOOR = 0.40
CAB = (-1.28, -1.28, -0.80, -0.60)          # the cabinet tower, plan
CAB_TOP = 1.02
GBOX = (-0.72, -1.22, -0.22, -0.62)         # the old gearbox housing, plan
GBOX_TOP = 0.84

GEAR = (-0.84, -0.06, 0.46)                 # centre; z is the disc's bottom
GEAR_R = 0.30
PINION = (-0.46, 0.12, 0.46)
PINION_R = 0.12
CRANK_R = 0.14                              # the crank pin's radius on the gear
ROD_L = 0.28                                # the connecting rod

COMP = (-1.06, 0.72, 0.84)                  # compressor cylinder centre (axis Y)
COMP_R = 0.21
COMP_Y = (0.48, 0.96)
FLYWHEEL_Y = 0.45
MOUNT = (-1.50, 0.40, -0.60, 1.02)          # the compressor mount plate, plan

SKID = (-0.08, -1.34, 1.42, 1.10)           # the galvanised graft floor, plan
SKID_TOP = 0.30
VESSEL = (0.68, -0.26)                      # the cold build vessel, plan centre
R_SHELL = 0.50
R_LINER = 0.455
R_CELL = 0.40
Z_FOOT = (SKID_TOP, 0.46)
Z_LOWER = (0.46, 0.72)
Z_WINDOW = (0.72, 1.24)
Z_UPPER = (1.24, 1.52)
Z_CAP = (1.52, 1.60)
Z_DOME = (1.60, 1.74)
WINDOW = (-146.0, -34.0)                    # the opening, degrees from +x (south is -90)
TABLE_R = 0.31
TABLE_Z = 0.70                              # the disc's bottom

COND = (0.46, -1.34, 1.50, -0.76)           # the condenser skid, plan
COND_Z = (SKID_TOP, 0.66)
FAN = (1.00, -1.05)
FAN_R = 0.25

RISER = (1.20, 0.46)
RISER_R = 0.07
RECEIVER_Z = (0.92, 1.48)
RECEIVER_R = 0.20
RISER_TOP = 1.59

STUB_R = 0.19                               # vanilla's pipe barrel, 0.52 tiles across
STUB_Z = 0.28


def _polys_frame(outer, hole):
    """The octagon minus a rectangular hole, as four polygons in plan --
    the deck around the mechanism bay, extruded as ONE mesh so the strips'
    shared interior faces never fight."""
    x0, y0, x1, y1 = outer[:4]
    c = outer[4]
    hx0, hy0, hx1, hy1 = hole
    south = [(x0, y0 + c), (x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, hy0), (x0, hy0)]
    north = [(x0, hy1), (x1, hy1), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c)]
    west = [(x0, hy0), (hx0, hy0), (hx0, hy1), (x0, hy1)]
    east = [(hx1, hy0), (x1, hy0), (x1, hy1), (hx1, hy1)]
    return [south, north, west, east]


def prisms(name, polys, z0, z1, mat=None, **kw):
    import bmesh
    bm = bmesh.new()
    for poly in polys:
        lower = [bm.verts.new((x, y, z0)) for x, y in poly]
        upper = [bm.verts.new((x, y, z1)) for x, y in poly]
        bm.faces.new(lower[::-1])
        bm.faces.new(upper)
        n = len(poly)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((lower[i], lower[j], upper[j], upper[i]))
    return gen._emit(bm, name, gen._MATS.get(mat), **kw)


def _on_vessel(angle_deg, r, z=0.0):
    t = math.radians(angle_deg)
    return (VESSEL[0] + r * math.cos(t), VESSEL[1] + r * math.sin(t), z)


def gauge(a, name, at, z, size=0.14):
    """An instrument pod facing south with a NEEDLE on its dial. The needle
    is built pointing up and pivots about Y at the dial's centre; animate()
    swings it. Named `needle-<name>` so the classifier files it: the
    compressor's needle runs always, the others react to the craft."""
    depth = 0.05
    a.place("greeble:gauge_pod", at=at, z=z, size=size, mat="steel",
            face_material=gen._MATS["dial"], name="gauge-" + name)
    # the dial sits at y - depth/2 - EPS and is 0.006 thick; the needle
    # rides just in front of it
    fy = at[1] - depth / 2 - 0.004 - 0.003
    r = size / 2 * 0.72
    # a whole source pixel wide and the dial's full radius long: at 0.008
    # wide the object-ID pass measured every needle at 2-3 px, texture
    out = [box("needle-" + name, (at[0] - 0.008, fy - 0.010, z - 0.014), (at[0] + 0.008, fy - 0.002, z + r * 0.96),
               mat="gunmetal", cuts=0, bevel=0.001)]
    gen.PIVOTS["needle-" + name] = (at[0], fy - 0.005, z)
    return out


def slats(name, x0, x1, z0, z1, y_wall, count=3, depth=0.06, mat="gunmetal", back="cavity"):
    """wall_louvres, but one object per slat with its pivot recorded, so the
    bank can open under load. The recess stays one static part."""
    import bmesh
    from mathutils import Matrix
    pad = 0.015
    out = [boxes(name + "-back",
                 [((x0 - pad, y_wall - 0.004, z0 - pad), (x1 + pad, y_wall + depth, z1 + pad))],
                 mat=back, cuts=1, bevel=0.004)]
    pitch = (z1 - z0) / count
    for i in range(count):
        z = z0 + pitch * (i + 0.5)
        bm = bmesh.new()
        blade = gen._bm_box(bm, (x0, y_wall - 0.012, z - pitch * 0.34),
                            (x1, y_wall + depth * 0.7, z + pitch * 0.34))
        bmesh.ops.rotate(bm, verts=blade, cent=(0, y_wall, z),
                         matrix=Matrix.Rotation(math.radians(-34), 3, "X"))
        out.append(gen._emit(bm, "louvre-%s-%d" % (name.replace("cond-louvres", "cond"), i),
                             gen._MATS.get(mat), cuts=1, bevel=0.003))
        gen.PIVOTS["louvre-cond-%d" % i] = ((x0 + x1) / 2, y_wall, z)
    return out


# ---- sections ------------------------------------------------------------

def plinth():
    return [prism("plinth", chamfer_rect(-1.40, -1.40, 1.40, 1.40, 0.34), 0.0, PLINTH,
                  mat="plinth", cuts=2, bevel=0.018)]


def west_hull(a):
    """The old assembling machine: chamfered skirt, open mechanism bay, the
    corner cabinet with the module rack, the gearbox housing, and the
    compressor bolted on at the north-west."""
    out = []
    x0, y0, x1, y1 = HULL
    c = 0.18
    out.append(prism("skirt-low", chamfer_rect(x0, y0, x1, y1, c), PLINTH + EPS,
                     BAY_FLOOR, mat="bluelow", cuts=2, bevel=0.012))
    out.append(prisms("skirt", _polys_frame((x0, y0, x1, y1, c), BAY),
                      BAY_FLOOR + EPS, SKIRT_TOP, mat="bluelow", cuts=2, bevel=0.012))
    # the deck rim: the painted top plate, its opening a little wider so the
    # skirt shows a lip inside it
    out.append(prisms("deck", _polys_frame((x0 + 0.02, y0 + 0.02, x1 - 0.02, y1 - 0.02, c),
                                           (BAY[0] - 0.03, BAY[1] - 0.03, BAY[2] + 0.03, BAY[3] + 0.03)),
                      SKIRT_TOP + EPS, DECK_TOP, mat="blue", cuts=2, bevel=0.010))
    bx0, by0, bx1, by1 = BAY
    out.append(box("bay-floor", (bx0, by0, BAY_FLOOR + EPS), (bx1, by1, BAY_FLOOR + 0.02),
                   mat="pitch", cuts=2, bevel=0.004))
    out.append(boxes("bay-liner",
                     [((bx0, by0, BAY_FLOOR + 0.02), (bx0 + 0.02, by1, SKIRT_TOP - 0.01)),
                      ((bx1 - 0.02, by0, BAY_FLOOR + 0.02), (bx1, by1, SKIRT_TOP - 0.01)),
                      ((bx0, by0, BAY_FLOOR + 0.02), (bx1, by0 + 0.02, SKIRT_TOP - 0.01)),
                      ((bx0, by1 - 0.02, BAY_FLOOR + 0.02), (bx1, by1, SKIRT_TOP - 0.01))],
                     mat="pitch", cuts=1, bevel=0.003))
    # a rim of bolt heads round the opening -- the assembler's bay is bolted
    for (sx, sy, ex, ey) in ((bx0 - 0.06, by0 - 0.05, bx1 + 0.06, by0 - 0.05),
                             (bx0 - 0.06, by1 + 0.05, bx1 + 0.06, by1 + 0.05)):
        a.run("greeble:rivet_row", (sx, sy, DECK_TOP + EPS), (ex, ey, DECK_TOP + EPS), count=7,
              head=0.016, mat="gunmetal", name="bay-rim-rivets")

    # -- the skirt's south face: bolted panel plates, the assembler quote.
    #    The plate beside the seam carries the seam's rust.
    for i, (px0, px1, m) in enumerate(((-1.26, -0.96, "blue"), (-0.92, -0.62, "blue"),
                                       (-0.58, -0.28, "bluerust"))):
        out.append(box("panel%d" % i, (px0, y0 - 0.020, PLINTH + 0.06), (px1, y0 - 0.004, SKIRT_TOP - 0.05),
                       mat=m, cuts=2, bevel=0.010))
        for z in (SKIRT_TOP - 0.09, PLINTH + 0.10):
            a.run("greeble:rivet_row", (px0 + 0.035, y0 - 0.028, z), (px1 - 0.035, y0 - 0.028, z),
                  count=4, head=0.016, mat="gunmetal", name="panel%d-rivets" % i)

    # -- the cabinet tower in the south-west corner: the old machine's
    #    electrical housing, blue, with the module rack on its face
    cx0, cy0, cx1, cy1 = CAB
    out.append(box("cabinet", (cx0, cy0, DECK_TOP + EPS), (cx1, cy1, CAB_TOP),
                   mat="blue", cuts=3, bevel=0.016))
    out.append(box("cab-lid", (cx0 + 0.05, cy0 + 0.05, CAB_TOP + EPS), (cx1 - 0.05, cy1 - 0.05, CAB_TOP + 0.03),
                   mat="blue", cuts=2, bevel=0.008))
    a.place("greeble:bolt_ring", at=((cx0 + cx1) / 2, (cy0 + cy1) / 2), z=CAB_TOP + 0.03 + EPS,
            size=0.28, count=6, head=0.015, mat="gunmetal", name="cab-lid-bolts")
    # the cabinet's own cooling fan, in the lid's north-west corner: the
    # module bay's tiny mechanical cue, turning always, slowly
    fx, fy, fz = cx0 + 0.13, cy1 - 0.17, CAB_TOP + 0.03
    out.append(ring("cab-fan-well", (fx, fy, fz + 0.012), 0.098, 0.080, 0.028, mat="gunmetal", seg=24))
    out.append(cyl("cab-fan-floor", (fx, fy, fz - 0.006), 0.080, 0.012, mat="pitch", seg=24, cuts=1))
    out.append(fan_blades("cabfan-blades", (fx, fy, fz + 0.010), 0.022, 0.072, 5, 0.010, mat="steel"))
    out.append(cyl("cabfan-hub", (fx, fy, fz + 0.012), 0.022, 0.024, mat="scoured", seg=12))
    out.append(radial_bars("cab-fan-guard", (fx, fy, fz + 0.030), 0.02, 0.092, 0.008, 0.008, 2,
                           mat="steel", phase=30.0, cuts=0, bevel=0.002))
    gen.PIVOTS["cabfan"] = (fx, fy, fz + 0.010)
    out.append(boxes("cab-handle",
                     [((cx0 + 0.14, cy0 + 0.30, CAB_TOP + 0.03), (cx0 + 0.18, cy0 + 0.34, CAB_TOP + 0.08)),
                      ((cx0 + 0.30, cy0 + 0.30, CAB_TOP + 0.03), (cx0 + 0.34, cy0 + 0.34, CAB_TOP + 0.08)),
                      ((cx0 + 0.12, cy0 + 0.29, CAB_TOP + 0.08), (cx0 + 0.36, cy0 + 0.35, CAB_TOP + 0.11))],
                     mat="steel", cuts=1, bevel=0.004))
    # the module rack: five slots stacked in a dark recess, the family's one
    # violet point at its head
    fy = cy0
    out.append(box("modrack-back", (cx0 + 0.07, fy - 0.016, DECK_TOP + 0.05), (cx1 - 0.07, fy - 0.004, CAB_TOP - 0.12),
                   mat="cavity", cuts=2, bevel=0.004))
    slots, glassy = [], []
    pitch = (CAB_TOP - 0.12 - DECK_TOP - 0.05 - 0.04) / 5.0
    for i in range(5):
        z = DECK_TOP + 0.07 + pitch * i
        slots.append(((cx0 + 0.10, fy - 0.030, z), (cx1 - 0.10, fy - 0.016, z + pitch * 0.72)))
        glassy.append(((cx0 + 0.13, fy - 0.034, z + 0.012), (cx1 - 0.13, fy - 0.030, z + pitch * 0.72 - 0.012)))
    out.append(boxes("modrack-bezels", slots, mat="gunmetal", cuts=1, bevel=0.004))
    out.append(boxes("modrack-glass", glassy, mat="cell", cuts=1, bevel=0.002))
    out.append(box("modrack-violet", (cx0 + 0.10, fy - 0.026, CAB_TOP - 0.10), (cx0 + 0.17, fy - 0.010, CAB_TOP - 0.08),
                   mat="violet", cuts=0, bevel=0.002))
    # the amber running lamp beside it
    out.append(box("amber-housing", (cx1 - 0.19, fy - 0.05, CAB_TOP - 0.11), (cx1 - 0.08, fy + 0.02, CAB_TOP - 0.03),
                   mat="gunmetal", cuts=1, bevel=0.005))
    out.append(box("amber-lamp", (cx1 - 0.17, fy - 0.054, CAB_TOP - 0.095), (cx1 - 0.10, fy - 0.048, CAB_TOP - 0.045),
                   mat="amber", cuts=0, bevel=0.002))

    # -- the gearbox housing: low, south of the bay, with its louvre grille
    #    facing the camera and the placard on it
    gx0, gy0, gx1, gy1 = GBOX
    out.append(box("gearbox", (gx0, gy0, DECK_TOP + EPS), (gx1, gy1, GBOX_TOP), mat="blue", cuts=3, bevel=0.014))
    out += list(wall_louvres("gearbox-louvres", gx0 + 0.08, gx1 - 0.16, DECK_TOP + 0.05, GBOX_TOP - 0.05, gy0,
                             count=3, depth=0.05))
    out.append(box("placard", (gx1 - 0.14, gy0 - 0.016, GBOX_TOP - 0.13), (gx1 - 0.03, gy0 - 0.004, GBOX_TOP - 0.05),
                   mat="cryo", cuts=1, bevel=0.004))
    out.append(box("gearbox-lid", (gx0 + 0.05, gy0 + 0.08, GBOX_TOP + EPS), (gx1 - 0.05, gy1 - 0.05, GBOX_TOP + 0.025),
                   mat="bluerust", cuts=2, bevel=0.006))
    a.place("greeble:bolt_ring", at=((gx0 + gx1) / 2, (gy0 + gy1) / 2 + 0.02), z=GBOX_TOP + 0.025 + EPS,
            size=0.34, count=6, head=0.014, mat="gunmetal", name="gearbox-bolts")

    # -- the mechanism bay: the assembler's own drive, in the open
    gx, gy, gz = GEAR
    out.append(cyl("gear-disc", (gx, gy, gz + 0.03), GEAR_R, 0.06, mat="steel", seg=36))
    # 18 teeth against the pinion's 9: an exact 2:1, so one turn of the gear
    # is two of the pinion and the mesh closes on the loop
    out.append(radial_bars("gear-teeth", (gx, gy, gz + 0.03), GEAR_R - 0.01, GEAR_R + 0.05, 0.024, 0.06, 18,
                           mat="scoured", taper=0.7))
    out.append(ring("gear-web", (gx, gy, gz + 0.065), GEAR_R - 0.04, GEAR_R - 0.10, 0.012, mat="scoured", seg=36))
    out.append(cyl("gear-hub", (gx, gy, gz + 0.09), 0.08, 0.07, mat="steel", seg=18))
    a.place("greeble:bolt_ring", at=(gx, gy), z=gz + 0.06 + EPS, size=0.34, count=6, head=0.015,
            mat="steel", name="gear-bolts")
    px, py, pz = PINION
    out.append(cyl("pinion-disc", (px, py, pz + 0.03), PINION_R, 0.06, mat="steel", seg=24))
    out.append(radial_bars("pinion-teeth", (px, py, pz + 0.03), PINION_R - 0.01, PINION_R + 0.04, 0.020, 0.06, 9,
                           mat="scoured", taper=0.7))
    out.append(cyl("pinion-hub", (px, py, pz + 0.08), 0.04, 0.05, mat="steel", seg=12))
    # the gearbox's output shaft into the bay, under the pinion, and a
    # crank arm on the gear driving a slider at the bay's north wall
    out.append(cyl("bay-shaft", (px, py - 0.30, pz + 0.02), 0.035, 0.36, axis="Y", mat="steel", seg=10))
    out.append(box("gear-crank", (gx - 0.03, gy - 0.025, gz + 0.16), (gx + CRANK_R + 0.03, gy + 0.025, gz + 0.20),
                   mat="steel", cuts=1, bevel=0.004))
    out.append(cyl("gear-crankpin", (gx + CRANK_R, gy, gz + 0.22), 0.028, 0.06, mat="scoured", seg=10))
    # the connecting rod and its slider: built at the ORIGIN and posed by
    # animate() every frame, the assembler's piston cue
    out.append(cyl("bay-rod", (0.0, 0.0, 0.0), 0.022, ROD_L, axis="X", mat="steel", seg=10))
    out.append(boxes("bay-slider",
                     [((gx - 0.06, gy + CRANK_R + 0.10, gz + 0.14), (gx + 0.06, gy + CRANK_R + 0.22, gz + 0.26)),
                      ((gx - 0.02, gy + CRANK_R + 0.12, gz + 0.26), (gx + 0.02, gy + CRANK_R + 0.20, gz + 0.29))],
                     mat="gunmetal", cuts=1, bevel=0.004))
    out.append(box("bay-rail", (gx - 0.035, gy - 0.02, gz + 0.10), (gx + 0.035, BAY[3] - 0.03, gz + 0.14),
                   mat="steel", cuts=1, bevel=0.003))
    # the handwheel on the bay's west rim -- the assembler's own quote
    a.place("greeble:handwheel", at=(HULL[0] + 0.10, -0.06), z=DECK_TOP + 0.14, size=0.17,
            axis="Y", mat="bronze", name="bay-wheel")
    out.append(cyl("bay-wheel-stem", (HULL[0] + 0.10, -0.02, DECK_TOP + 0.05), 0.02, 0.16,
                   mat="steel", seg=8))

    # -- the compressor: the retrofit's own machine, bolted onto the old deck
    #    at the north-west. A finned cylinder block with its flywheel facing
    #    the camera; its mount plate hangs past the hull on a bracket and is
    #    the sprite's west extreme.
    mx0, my0, mx1, my1 = MOUNT
    out.append(box("comp-mount", (mx0, my0, DECK_TOP + EPS), (mx1, my1, DECK_TOP + 0.06),
                   mat="steel", cuts=2, bevel=0.008))
    out.append(boxes("comp-bracket",
                     [((mx0 + 0.02, my0 + 0.08, 0.32), (HULL[0] + 0.02, my0 + 0.14, DECK_TOP)),
                      ((mx0 + 0.02, my1 - 0.14, 0.32), (HULL[0] + 0.02, my1 - 0.08, DECK_TOP)),
                      ((mx0 + 0.02, my0 + 0.08, 0.32), (mx0 + 0.06, my1 - 0.08, DECK_TOP))],
                     mat="steel", cuts=1, bevel=0.004))
    cx, cy, cz = COMP
    out.append(cyl("comp-body", (cx, (COMP_Y[0] + COMP_Y[1]) / 2, cz), COMP_R - 0.015,
                   COMP_Y[1] - COMP_Y[0], axis="Y", mat="gunmetal", seg=28))
    for i in range(4):
        y = COMP_Y[0] + 0.09 + i * 0.10
        out.append(ring("comp-fin%d" % i, (cx, y, cz), COMP_R + 0.035, COMP_R - 0.03, 0.034, axis="Y",
                        mat="gunmetal", seg=28))
    # the valve cover on top of the head, and its two bolted caps
    out.append(box("comp-head", (cx - 0.11, COMP_Y[0] + 0.06, cz + COMP_R - 0.06), (cx + 0.11, COMP_Y[1] - 0.06, cz + COMP_R + 0.05),
                   mat="steel", cuts=2, bevel=0.010))
    out.append(cyl("comp-cap0", (cx - 0.05, COMP_Y[0] + 0.16, cz + COMP_R + 0.05), 0.035, 0.05, mat="bronze", seg=12))
    out.append(cyl("comp-cap1", (cx + 0.05, COMP_Y[1] - 0.16, cz + COMP_R + 0.05), 0.035, 0.05, mat="bronze", seg=12))
    out.append(box("comp-cradle", (cx - 0.17, COMP_Y[0] + 0.02, DECK_TOP + 0.06), (cx + 0.17, COMP_Y[1] - 0.02, cz - 0.12),
                   mat="steel", cuts=2, bevel=0.008))
    # the flywheel: rim, spokes and hub about Y, turning
    out.append(ring("flywheel-rim", (cx, FLYWHEEL_Y, cz), 0.21, 0.165, 0.045, axis="Y", mat="scoured", seg=36))
    out.append(radial_bars("flywheel-spokes", (cx, FLYWHEEL_Y, cz), 0.045, 0.17, 0.017, 0.03, 5, axis="Y",
                           mat="gunmetal"))
    out.append(cyl("flywheel-hub", (cx, FLYWHEEL_Y, cz), 0.055, 0.07, axis="Y", mat="steel", seg=12))
    # the motor behind the block, east of it, and its drive-end bell
    out.append(box("comp-motor", (cx + 0.18, COMP_Y[0] + 0.06, DECK_TOP + 0.06), (mx1 + 0.06, COMP_Y[1] - 0.04, cz + 0.02),
                   mat="bluerust", cuts=2, bevel=0.012))
    out.append(cyl("comp-motor-end", (mx1 - 0.08, COMP_Y[0] + 0.05, cz - 0.12), 0.11, 0.05, axis="Y",
                   mat="gunmetal", seg=20))
    # the belt drive: the motor's pulley on a stub shaft, in the flywheel's
    # plane, and the belt round both. Half the flywheel's radius, so the
    # pulley turns twice for each turn of the wheel.
    px, pz = mx1 - 0.08, cz - 0.12
    PULLEY_R = 0.105
    out.append(cyl("motor-shaft", (px, FLYWHEEL_Y + 0.045, pz), 0.028, 0.06, axis="Y", mat="steel", seg=10))
    out.append(ring("pulley-rim", (px, FLYWHEEL_Y, pz), PULLEY_R, PULLEY_R - 0.03, 0.05, axis="Y",
                    mat="scoured", seg=28))
    out.append(radial_bars("pulley-spokes", (px, FLYWHEEL_Y, pz), 0.03, PULLEY_R - 0.025, 0.014, 0.03, 3,
                           axis="Y", mat="gunmetal", phase=90.0))
    out.append(cyl("pulley-hub", (px, FLYWHEEL_Y, pz), 0.036, 0.06, axis="Y", mat="steel", seg=12))
    out.append(gen.belt("drive-belt", (cx, cz), 0.21, (px, pz), PULLEY_R, FLYWHEEL_Y, 0.034, 0.014,
                        mat="rubber"))
    gen.PIVOTS["pulley"] = (px, FLYWHEEL_Y, pz)
    # a guard rail on the mount plate's outer edge: the west extreme, in clear
    # air, and the human-scale cue on that side
    a.run("greeble:railing", [(mx0 + 0.02, my0 + 0.04, DECK_TOP + 0.06), (mx0 + 0.02, my1 - 0.04, DECK_TOP + 0.06)],
          height=0.20, mat="steel", name="comp-rail")
    # the discharge pressure gauge on a stand at the plate's front-west
    # corner, beside the flywheel: its needle flicks with every stroke
    out.append(box("comp-gauge-stand", (mx0 + 0.10, my0 + 0.03, DECK_TOP + 0.06), (mx0 + 0.15, my0 + 0.08, 0.80),
                   mat="steel", cuts=1, bevel=0.004))
    out += gauge(a, "comp", (mx0 + 0.125, my0 + 0.04), 0.83, size=0.15)

    # -- power in: the junction box on the cabinet top, and its cables
    a.place("greeble:junction_box", at=(cx1 - 0.13, cy1 - 0.13), z=CAB_TOP + 0.03, size=0.15,
            mat="gunmetal", name="jbox")
    a.run("greeble:cable", (cx1 - 0.13, cy1 - 0.10, CAB_TOP + 0.26), (cx + 0.10, COMP_Y[0] + 0.02, cz + 0.06),
          sag=0.22, mat="rubber", name="cable-comp")
    a.run("greeble:cable", (cx1 - 0.09, cy1 - 0.11, CAB_TOP + 0.25), (0.02, 0.98, SKID_TOP + 0.18),
          sag=0.26, mat="rubber", name="cable-skid")
    a.place("greeble:junction_box", at=(0.02, 1.00), z=SKID_TOP + EPS, size=0.15,
            mat="gunmetal", name="jbox-skid")
    return out


def seam(a):
    """The graft line, dead centre: a bare-steel strap up the south wall and a
    bolted plate across the deck, carrying the worst corrosion on the
    machine."""
    out = []
    y0 = HULL[1]
    out.append(box("seam-strap", (-0.22, y0 - 0.034, PLINTH + EPS), (-0.02, y0 - 0.004, DECK_TOP + 0.06),
                   mat="seamsteel", cuts=3, bevel=0.008))
    a.run("greeble:rivet_row", (-0.12, y0 - 0.042, PLINTH + 0.08), (-0.12, y0 - 0.042, DECK_TOP),
          count=5, head=0.018, mat="gunmetal", name="seam-strap-rivets")
    out.append(box("seam-plate", (-0.24, y0 + 0.02, DECK_TOP + EPS), (0.00, HULL[3] - 0.02, DECK_TOP + 0.07),
                   mat="seamsteel", cuts=3, bevel=0.008))
    for x in (-0.19, -0.05):
        a.run("greeble:rivet_row", (x, y0 + 0.10, DECK_TOP + 0.07 + EPS), (x, HULL[3] - 0.10, DECK_TOP + 0.07 + EPS),
              count=9, head=0.016, mat="gunmetal", name="seam-rivets")
    out.append(boxes("seam-weld",
                     [((-0.26, y0 + 0.02, DECK_TOP + 2 * EPS), (-0.24, HULL[3] - 0.02, DECK_TOP + 0.025)),
                      ((0.00, y0 + 0.02, SKID_TOP + 2 * EPS), (0.02, HULL[3] - 0.02, SKID_TOP + 0.025))],
                     mat="cavity", cuts=1, bevel=0.003))
    # the step down from the old deck to the graft's skid: a dark riser face
    out.append(box("seam-step", (-0.12, y0 + 0.02, SKID_TOP + EPS), (-0.08, HULL[3] - 0.02, DECK_TOP),
                   mat="cavity", cuts=1, bevel=0.003))
    # two angle brackets tying the graft's skid to the old deck: a leg
    # standing on the skid up the step, a flange bolted over the joining
    # plate. The retrofit hangs off the assembler's own structure.
    for k, y in enumerate((-0.98, 0.72)):
        out.append(boxes("seam-bracket%d" % k,
                         [((-0.08, y - 0.06, SKID_TOP + EPS), (0.00, y + 0.06, DECK_TOP + 0.11)),
                          ((-0.23, y - 0.06, DECK_TOP + 0.07 + EPS), (0.00, y + 0.06, DECK_TOP + 0.11))],
                         mat="steel", cuts=2, bevel=0.006))
        a.run("greeble:rivet_row", (-0.19, y, DECK_TOP + 0.11 + EPS), (-0.05, y, DECK_TOP + 0.11 + EPS),
              count=3, head=0.016, mat="gunmetal", name="seam-bracket%d-bolts" % k)
        a.run("greeble:rivet_row", (-0.04, y - 0.068, SKID_TOP + 0.08), (-0.04, y - 0.068, DECK_TOP - 0.02),
              count=3, head=0.014, mat="gunmetal", name="seam-bracket%d-rivets" % k)
    return out


def east_skid(a):
    """The graft's floor: a galvanised skid plate the vessel, the condenser
    and the riser stand on, with the operator's console at its south-west
    corner and the cable loom that ties the console to the machine."""
    out = []
    x0, y0, x1, y1 = SKID
    out.append(prism("skid", chamfer_rect(x0, y0, x1, y1, 0.12), PLINTH + EPS, SKID_TOP,
                     mat="steel", cuts=3, bevel=0.012))
    out.append(box("skid-lip", (x0 + 0.06, y0 - 0.02, SKID_TOP + EPS), (x1 - 0.06, y0 + 0.06, SKID_TOP + 0.03),
                   mat="gunmetal", cuts=1, bevel=0.004))
    # the console: a composite pedestal with a cream fascia, a tilted screen
    # and two status points, facing the camera -- the human service cue on
    # the graft, where the old half has its handwheel
    kx0, kx1 = 0.10, 0.40
    ky0, ky1 = -1.30, -1.06
    kz = 0.62
    out.append(box("console", (kx0, ky0, SKID_TOP + EPS), (kx1, ky1, kz), mat="composite", cuts=2, bevel=0.008))
    out.append(box("console-fascia", (kx0 + 0.03, ky0 - 0.016, SKID_TOP + 0.08), (kx1 - 0.03, ky0 - 0.004, kz - 0.04),
                   mat="cream", cuts=1, bevel=0.004))
    out.append(box("console-screen", (kx0 + 0.06, ky0 - 0.022, kz - 0.20), (kx1 - 0.06, ky0 - 0.016, kz - 0.07),
                   mat="screen", cuts=0, bevel=0.002))
    for k, x in enumerate((kx0 + 0.07, kx0 + 0.15)):
        out.append(box("console-lamp%d" % k, (x, ky0 - 0.022, SKID_TOP + 0.11), (x + 0.05, ky0 - 0.016, SKID_TOP + 0.15),
                       mat="cyanlamp", cuts=0, bevel=0.001))
    out.append(box("console-top", (kx0 - 0.01, ky0 - 0.01, kz), (kx1 + 0.01, ky1 + 0.01, kz + 0.025),
                   mat="composite", cuts=1, bevel=0.005))
    a.run("greeble:cable", (kx1 - 0.06, ky1 - 0.04, kz + 0.02), (0.36, -0.70, Z_LOWER[0] + 0.19),
          sag=0.05, mat="rubber", name="cable-console")
    a.run("greeble:cable", (kx1 - 0.02, ky0 + 0.10, kz - 0.02), (COND[0] + 0.06, -1.20, COND_Z[1] + 0.02),
          sag=0.04, mat="rubber", name="cable-cond")
    return out


def vessel(a):
    """The hero: the jacketed cold build vessel in Aquilo teal, cream
    insulation flanges between its segments, a composite-ribbed cream dome
    with a sight dome on top, the window with its light line, and the
    turntable behind the glass."""
    out = []
    vx, vy = VESSEL
    # foot flange and the lower shell -- where the cold pools, so the rime
    out.append(ring("vessel-foot", (vx, vy, (Z_FOOT[0] + Z_FOOT[1]) / 2), R_SHELL + 0.05, R_CELL,
                    Z_FOOT[1] - Z_FOOT[0] - EPS, mat="cryofoot", seg=48))
    a.place("greeble:bolt_ring", at=(vx, vy), z=Z_FOOT[1] + EPS, size=2 * (R_SHELL + 0.01), count=12,
            head=0.016, mat="gunmetal", name="vessel-foot-bolts")
    out.append(ring("vessel-lower", (vx, vy, (Z_LOWER[0] + Z_LOWER[1]) / 2), R_SHELL, R_LINER,
                    Z_LOWER[1] - Z_LOWER[0] - EPS, mat="teal", seg=48))
    # the cradle: two composite saddles either side of the foot, bolted to the
    # skid -- the vessel is carried, not set down
    for tag, x0, x1 in (("w", vx - 0.66, vx - 0.55), ("e", vx + 0.55, vx + 0.68)):
        out.append(box("cradle-" + tag, (x0, vy - 0.17, SKID_TOP + EPS), (x1, vy + 0.17, 0.52),
                       mat="composite", cuts=2, bevel=0.008))
        a.run("greeble:rivet_row", ((x0 + x1) / 2, vy - 0.12, 0.52 + EPS), ((x0 + x1) / 2, vy + 0.12, 0.52 + EPS),
              count=3, head=0.016, mat="gunmetal", name="cradle-%s-bolts" % tag)
    # the window band: shell and liner as arcs, the south 112 degrees open
    a0, a1 = WINDOW
    zl, zh = Z_WINDOW
    out.append(ring("vessel-band", (vx, vy, (zl + zh) / 2), R_SHELL, R_LINER, zh - zl - EPS,
                    mat="teal", seg=48, a0=a1, a1=a0 + 360.0))
    out.append(ring("vessel-liner", (vx, vy, (zl + zh) / 2), R_LINER - EPS, R_CELL,
                    zh - zl - EPS, mat="cell", seg=48, a0=a1, a1=a0 + 360.0))
    # cream insulation flanges where the jacket's segments meet, standing a
    # little proud of the shell and stopping short of the window's posts
    # (one flange only: the upper one measured 3 px in the object-ID pass,
    # hidden behind the top bezel and under the coil)
    out.append(ring("jacket-flange0", (vx, vy, Z_LOWER[1] - 0.004), R_SHELL + 0.035, R_LINER, 0.05, mat="cream",
                    seg=48, a0=a1 + 7, a1=a0 + 360.0 - 7))
    # the cell floor and its cold-light ring round the table
    out.append(cyl("cell-floor", (vx, vy, zl - 0.03), R_CELL - EPS, 0.05, mat="cell", seg=44))
    out.append(ring("cell-light", (vx, vy, zl - 0.004), R_CELL - 0.01, TABLE_R + 0.02, 0.008,
                    mat="cyanfloor", seg=44, cuts=0, bevel=0))
    # the ceiling lamp: a disc up under the top lip, hidden by the bezel.
    # What the window shows is what it lights.
    out.append(cyl("cell-lamp", (vx, vy, zh - 0.05), R_CELL - 0.03, 0.02, mat="celllamp", seg=32, cuts=0, bevel=0))
    # the turntable: a dark disc with a steel rim, four clamps, four pale
    # workpieces. Steps a quarter turn per craft.
    out.append(cyl("table-disc", (vx, vy, TABLE_Z + 0.022), TABLE_R, 0.044, mat="gunmetal", seg=40))
    # the rim in steel, not the polished scoured: under the key light through
    # the opening a pale rim blazed into one bright arc that outshone the
    # pieces and the arm, and the window read as a lit shape, not a cell
    out.append(ring("table-rim", (vx, vy, TABLE_Z + 0.05), TABLE_R, TABLE_R - 0.035, 0.012, mat="steel", seg=40))
    clamps, works = [], []
    for k in range(4):
        t = math.radians(45 + 90 * k)
        cxk, cyk = vx + 0.19 * math.cos(t), vy + 0.19 * math.sin(t)
        clamps.append(((cxk - 0.035, cyk - 0.03, TABLE_Z + 0.044), (cxk + 0.035, cyk + 0.03, TABLE_Z + 0.085)))
        t2 = math.radians(90 * k - 90)
        wxk, wyk = vx + 0.19 * math.cos(t2), vy + 0.19 * math.sin(t2)
        works.append(((wxk - 0.07, wyk - 0.06, TABLE_Z + 0.044), (wxk + 0.07, wyk + 0.06, TABLE_Z + 0.10)))
    out.append(boxes("table-clamps", clamps, mat="gunmetal", cuts=1, bevel=0.004))
    out.append(boxes("work-pieces", works, mat="cryo", cuts=1, bevel=0.006))
    out.append(cyl("table-hub", (vx, vy, TABLE_Z + 0.044), 0.05, 0.05, mat="steel", seg=12))
    # the lock pin at the table's front edge: lifts before the index, drops
    # onto the stop after it -- the mechanical full stop of the cycle
    out.append(box("lock-base", (vx - 0.045, vy - TABLE_R - 0.085, TABLE_Z), (vx + 0.045, vy - TABLE_R - 0.02, TABLE_Z + 0.03),
                   mat="gunmetal", cuts=1, bevel=0.003))
    out.append(box("lock-pin", (vx - 0.028, vy - TABLE_R - 0.07, TABLE_Z + 0.03), (vx + 0.028, vy - TABLE_R - 0.012, TABLE_Z + 0.075),
                   mat="scoured", cuts=1, bevel=0.003))
    # the transfer arm: a static rail down the cell's centre line (Y --
    # vertical on screen), a carriage riding under it from the back station
    # to the front one, a head hanging off the carriage that drops onto the
    # workpiece, and two fingers that close on it. Parked over the back
    # station; animate() runs it out to the front and home again.
    T = TABLE_Z
    out.append(box("cell-rail", (vx - 0.022, vy - 0.27, T + 0.21), (vx + 0.022, vy + 0.37, T + 0.245),
                   mat="steel", cuts=1, bevel=0.003))
    out.append(boxes("arm-carriage",
                     [((vx - 0.055, vy + 0.05, T + 0.155), (vx + 0.055, vy + 0.15, T + 0.21)),
                      ((vx - 0.03, vy + 0.08, T + 0.14), (vx + 0.03, vy + 0.12, T + 0.155))],
                     mat="steel", cuts=1, bevel=0.004))
    out.append(box("arm-head", (vx - 0.065, vy + 0.04, T + 0.125), (vx + 0.065, vy + 0.16, T + 0.14),
                   mat="gunmetal", cuts=1, bevel=0.004))
    for k, sgn in ((0, -1.0), (1, 1.0)):
        xa, xb = sorted((vx + sgn * 0.075, vx + sgn * 0.095))
        out.append(box("arm-finger%d" % k, (xa, vy + 0.06, T + 0.07), (xb, vy + 0.14, T + 0.125),
                       mat="scoured", cuts=1, bevel=0.003))
    gen.PIVOTS["arm"] = (vx, vy + 0.10, T + 0.155)
    gen.PIVOTS["arm_reach"] = 0.29
    # the window: a heavy DARK bezel -- two arcs and two posts -- the gasket,
    # and the pane set into it
    for name, z in (("bezel-top", zh), ("bezel-bottom", zl)):
        out.append(ring(name, (vx, vy, z), R_SHELL + 0.045, R_LINER - 0.01, 0.09,
                        mat="coldiron" if name == "bezel-bottom" else "gunmetal", seg=48, a0=a0 - 8, a1=a1 + 8))
    # the light line along the top bezel's face: the cell's own lamp seen
    # from outside, bright only while the machine works
    out.append(ring("bezel-strip", (vx, vy, zh + 0.012), R_SHELL + 0.058, R_SHELL + 0.040, 0.016,
                    mat="strip", seg=48, a0=a0 - 5, a1=a1 + 5, cuts=0, bevel=0))
    for k, ang in enumerate(WINDOW):
        px, py, _ = _on_vessel(ang, R_SHELL - 0.005)
        out.append(cyl("bezel-post%d" % k, (px, py, (zl + zh) / 2), 0.05, zh - zl + 0.07, mat="gunmetal", seg=12))
        a.run("greeble:rivet_row", (px, py - 0.05, zl + 0.08), (px, py - 0.05, zh - 0.08),
              count=4, head=0.014, mat="steel", name="bezel-post%d-rivets" % k)
    for k, z in enumerate((zl + 0.045, zh - 0.045)):
        out.append(ring("window-gasket%d" % k, (vx, vy, z), R_LINER + 0.014, R_LINER - 0.006, 0.022,
                        mat="rubber", seg=48, a0=a0 - 2, a1=a1 + 2, cuts=0, bevel=0.002))
    out.append(ring("window-glass", (vx, vy, (zl + zh) / 2), R_LINER + 0.002, R_LINER - 0.004, zh - zl - 0.08,
                    mat="glass", seg=48, a0=a0, a1=a1, cuts=0, bevel=0))
    # sight glasses flanking the window, on the band's shoulders
    for k, ang in enumerate((a0 - 15, a1 + 15)):
        px, py, _ = _on_vessel(ang, R_SHELL + 0.012)
        out.append(box("sight-frame%d" % k, (px - 0.035, py - 0.018, zl + 0.10), (px + 0.035, py + 0.018, zh - 0.10),
                       mat="composite", cuts=1, bevel=0.004))
        out.append(box("sight-glass%d" % k, (px - 0.018, py - 0.026, zl + 0.13), (px + 0.018, py - 0.016, zh - 0.13),
                       mat="cyan", cuts=0, bevel=0.002))
    # upper shell in dark composite so the copper coil wound round it pops
    out.append(ring("vessel-upper", (vx, vy, (Z_UPPER[0] + Z_UPPER[1]) / 2), R_SHELL, R_CELL,
                    Z_UPPER[1] - Z_UPPER[0] - EPS, mat="composite", seg=48))
    out.append(helix("coil", (vx, vy, 0.0), R_SHELL + 0.032, 0.028, Z_UPPER[0] + 0.045, Z_UPPER[1] - 0.045, 3.0,
                     mat="copper", bevel=0))
    for k in range(4):
        px, py, _ = _on_vessel(45 + 90 * k, R_SHELL + 0.03)
        out.append(box("coil-strap%d" % k, (px - 0.03, py - 0.03, Z_UPPER[0] + 0.02), (px + 0.03, py + 0.03, Z_UPPER[1] - 0.02),
                       mat="composite", cuts=1, bevel=0.004))
    # the cap: a bolted composite flange, the cream dome with six composite
    # ribs, the boss and its relief valve, the manway, the sight dome
    out.append(ring("vessel-cap", (vx, vy, (Z_CAP[0] + Z_CAP[1]) / 2), R_SHELL + 0.05, 0.20,
                    Z_CAP[1] - Z_CAP[0] - EPS, mat="composite", seg=48))
    a.place("greeble:bolt_ring", at=(vx, vy), z=Z_CAP[1] + EPS, size=2 * (R_SHELL + 0.01), count=14,
            head=0.016, mat="gunmetal", name="vessel-cap-bolts")
    # the dome in Aquilo teal, like the cryogenic plant's own rounded tops --
    # in cream it rendered as one blank white disc that owned the sprite --
    # with six composite ribs and a cream cap plate between them
    out.append(cyl("vessel-dome", (vx, vy, (Z_DOME[0] + Z_DOME[1]) / 2), 0.44, Z_DOME[1] - Z_DOME[0] - EPS,
                   mat="teal", seg=48, r2=0.26))
    out.append(ring("dome-band", (vx, vy, Z_DOME[0] + 0.045), 0.435, 0.385, 0.03, mat="composite", seg=48))
    out.append(radial_bars("dome-ribs", (vx, vy, Z_DOME[1] - 0.015), 0.13, 0.42, 0.024, 0.05, 6,
                           mat="composite", phase=15.0, cuts=0, bevel=0.002))
    out.append(ring("dome-plate", (vx, vy, Z_DOME[1] + 0.006), 0.25, 0.13, 0.012, mat="cream", seg=40,
                    cuts=0, bevel=0.002))
    out.append(cyl("vessel-boss", (vx, vy, Z_DOME[1] + 0.05), 0.12, 0.10, mat="composite", seg=20))
    out.append(cyl("relief-valve", (vx, vy, Z_DOME[1] + 0.16), 0.04, 0.12, mat="bronze", seg=12))
    out.append(cyl("relief-cap", (vx, vy, Z_DOME[1] + 0.24), 0.06, 0.04, mat="bronze", seg=12))
    out.append(cyl("dome-manway", (vx + 0.16, vy + 0.14, Z_DOME[1] - 0.05), 0.13, 0.05, mat="composite", seg=24))
    a.place("greeble:bolt_ring", at=(vx + 0.16, vy + 0.14), z=Z_DOME[1] - 0.025 + EPS, size=0.22, count=8,
            head=0.013, mat="gunmetal", name="dome-manway-bolts")
    # the sight dome: a glass bubble over a cyan lamp on the cap's shoulder,
    # the machine's one light that reads from across a base
    sx, sy = vx - 0.19, vy + 0.15
    out.append(ring("sight-collar", (sx, sy, Z_DOME[1] - 0.045), 0.135, 0.105, 0.05, mat="composite", seg=24))
    out.append(cyl("sight-lamp", (sx, sy, Z_DOME[1] - 0.02), 0.09, 0.02, mat="sightlamp", seg=20, cuts=0, bevel=0))
    out.append(gen.sphere("sight-dome", (sx, sy, Z_DOME[1] - 0.02), 0.105, mat="glass"))
    out.append(boxes("dome-lugs",
                     [((vx - 0.30, vy - 0.03, Z_DOME[0] + 0.02), (vx - 0.22, vy + 0.03, Z_DOME[0] + 0.16)),
                      ((vx + 0.22, vy - 0.03, Z_DOME[0] + 0.02), (vx + 0.30, vy + 0.03, Z_DOME[0] + 0.16))],
                     mat="composite", cuts=1, bevel=0.005))
    # the chamber's temperature gauge, standing on the cap flange's south
    # edge, face to the camera: slow to rise, slow to settle
    out.append(box("dome-gauge-stand", (vx - 0.23, vy - 0.52, Z_CAP[1] + EPS), (vx - 0.17, vy - 0.46, Z_CAP[1] + 0.06),
                   mat="steel", cuts=1, bevel=0.003))
    out += gauge(a, "dome", (vx - 0.20, vy - 0.50), Z_CAP[1] + 0.11, size=0.14)
    # the vent puff off the relief valve: glow pass only, keyed by animate()
    out.append(gen.sphere("vapour-plume", (vx, vy, Z_DOME[1] + 0.33), 0.09, mat="vapour"))
    # the ladder up the vessel's south-east flank, from the condenser top to
    # the cap -- a person services the coil and the cap from here
    lx, ly, _ = _on_vessel(-30.0, R_SHELL + 0.10)
    a.run("greeble:ladder", (lx, ly, COND_Z[1] + 0.02), Z_CAP[0] - COND_Z[1] - 0.02, width=0.15,
          rungs=7, mat="steel", name="ladder")
    out.append(boxes("ladder-brackets",
                     [((lx - 0.06, ly - 0.01, COND_Z[1] + 0.18), (lx + 0.06, ly + 0.11, COND_Z[1] + 0.21)),
                      ((lx - 0.06, ly - 0.01, Z_CAP[0] - 0.16), (lx + 0.06, ly + 0.11, Z_CAP[0] - 0.13))],
                     mat="steel", cuts=1, bevel=0.003))
    # the status lamp on the vessel's south-west foot: small, cold, always on
    sx, sy, _ = _on_vessel(-130.0, R_SHELL + 0.02)
    out.append(box("lamp-housing", (sx - 0.05, sy - 0.05, Z_LOWER[0] + 0.06), (sx + 0.05, sy + 0.06, Z_LOWER[0] + 0.18),
                   mat="gunmetal", cuts=1, bevel=0.005))
    out.append(box("lamp-face", (sx - 0.03, sy - 0.056, Z_LOWER[0] + 0.09), (sx + 0.03, sy - 0.05, Z_LOWER[0] + 0.15),
                   mat="cyanlamp", cuts=0, bevel=0.002))
    gen.PIVOTS["table"] = (vx, vy, TABLE_Z)
    return out


def condenser(a):
    """Heat out: the air-cooled condenser skid in front of the vessel, TWO
    fans in its top under teal cowls, louvres on its face, sooted on top,
    chevrons at its foot. The sprite's east extreme."""
    out = []
    x0, y0, x1, y1 = COND
    z0, z1 = COND_Z
    fy = FAN[1]
    r = 0.19
    h = r + 0.03
    # collars reach 0.31 from each centre; 1.19 keeps the east one inside the
    # skid's edge at 1.50 (at 1.24 it stood 0.05 past the tiles)
    fans = ((0.70, "fan", ""), (1.19, "fan2", "2"))
    # The body is a frame round the two wells, not a solid box: the first
    # build put the fan inside a solid and the object-ID pass measured it at
    # zero pixels. A collar in the body's own material fills each square
    # opening's corners so the wells read round.
    fa, fb = fans[0][0], fans[1][0]
    polys = [[(x0, y0), (x1, y0), (x1, fy - h), (x0, fy - h)],
             [(x0, fy + h), (x1, fy + h), (x1, y1), (x0, y1)],
             [(x0, fy - h), (fa - h, fy - h), (fa - h, fy + h), (x0, fy + h)],
             [(fa + h, fy - h), (fb - h, fy - h), (fb - h, fy + h), (fa + h, fy + h)],
             [(fb + h, fy - h), (x1, fy - h), (x1, fy + h), (fb + h, fy + h)]]
    out.append(prisms("cond-body", polys, z0 + EPS, z1, mat="condenser", cuts=2, bevel=0.012))
    for k, (fx, key, sfx) in enumerate(fans):
        out.append(ring("cond-collar" + sfx, (fx, fy, (z0 + z1) / 2), h * 1.42, r + 0.005, z1 - z0 - 0.008,
                        mat="condenser", seg=36))
        out.append(ring("cond-well" + sfx, (fx, fy, z1 - 0.10), r + 0.008, r - 0.008, 0.20, mat="cavity", seg=36))
        out.append(cyl("cond-well-floor" + sfx, (fx, fy, z1 - 0.19), r, 0.02, mat="pitch", seg=36, cuts=1))
        out.append(ring("cond-ring" + sfx, (fx, fy, z1 + 0.03), r + 0.065, r - 0.005, 0.06, mat="teal", seg=36))
        a.place("greeble:bolt_ring", at=(fx, fy), z=z1 + 0.06 + EPS, size=2 * (r + 0.035), count=8,
                head=0.013, mat="gunmetal", name="cond-ring%s-bolts" % sfx)
        # FIVE blades: the fast loop steps a fan 28 degrees a frame, and past
        # 0.4 of the blade period it strobes backwards (measured with seven)
        prefix = "fan-" if k == 0 else "fan2-"
        out.append(fan_blades(prefix + "blades", (fx, fy, z1 - 0.05), 0.05, r - 0.025, 5, 0.016, mat="steel"))
        out.append(cyl(prefix + "hub", (fx, fy, z1 - 0.045), 0.05, 0.07, mat="scoured", seg=16))
        out.append(radial_bars("cond-guard" + sfx, (fx, fy, z1 + 0.062), 0.04, r + 0.02, 0.011, 0.011, 3,
                               mat="steel", phase=90.0 + 30.0 * k, cuts=0, bevel=0.002))
        gen.PIVOTS[key] = (fx, fy, z1 - 0.05)
    out += slats("cond-louvres", x0 + 0.10, x1 - 0.10, 0.40, 0.60, y0, count=3, depth=0.06)
    out += list(chevrons("cond-chevrons", x0 + 0.10, x1 - 0.14, z0 + 0.03, 0.38, y0, count=8))
    # a cream nameplate between the cowls on the body's north strip, and the
    # bar between the wells carries a lifting eye
    out.append(box("cond-plate", (fa + 0.02, y1 - 0.075, z1 + EPS), (fb - 0.02, y1 - 0.02, z1 + 0.018),
                   mat="cream", cuts=1, bevel=0.003))
    out.append(ring("cond-eye", ((fa + fb) / 2, fy, z1 + 0.06), 0.035, 0.018, 0.02, axis="Y", mat="steel", seg=12))
    return out


def riser(a):
    """The skyline: the liquid line up from the condenser through a cream
    insulated receiver drum, elbowing over into the vessel's coil. The
    condenser feeds the drum through a ribbed flexible hose up the skid's
    east edge -- the cryogenic plant's own fitting."""
    out = []
    rx, ry = RISER
    a.run("greeble:pipe_run", [(rx, ry, SKID_TOP + 0.04), (rx, ry, RECEIVER_Z[0] + 0.02)],
          radius=RISER_R, flanges=True, mat="bronze", name="riser-lo")
    out.append(cyl("receiver", (rx, ry, (RECEIVER_Z[0] + RECEIVER_Z[1]) / 2), RECEIVER_R,
                   RECEIVER_Z[1] - RECEIVER_Z[0], mat="cream", seg=32))
    for k, z in enumerate((RECEIVER_Z[0] + 0.07, (RECEIVER_Z[0] + RECEIVER_Z[1]) / 2 + 0.02, RECEIVER_Z[1] - 0.07)):
        out.append(ring("receiver-band%d" % k, (rx, ry, z), RECEIVER_R + 0.02, RECEIVER_R - 0.01, 0.035,
                        mat="composite", seg=32))
    out.append(cyl("receiver-cap", (rx, ry, RECEIVER_Z[1] + 0.02), RECEIVER_R - 0.01, 0.04, mat="composite", seg=32))
    a.place("greeble:bolt_ring", at=(rx, ry), z=RECEIVER_Z[1] + 0.04 + EPS, size=2 * (RECEIVER_R - 0.05), count=6,
            head=0.012, mat="gunmetal", name="receiver-cap-bolts")
    out.append(cyl("receiver-foot", (rx, ry, RECEIVER_Z[0] - 0.02), RECEIVER_R - 0.01, 0.04, mat="composite", seg=32))
    out.append(box("receiver-screen-housing", (rx - 0.075, ry - RECEIVER_R - 0.03, RECEIVER_Z[0] + 0.16),
                   (rx + 0.075, ry - RECEIVER_R + 0.03, RECEIVER_Z[0] + 0.27), mat="gunmetal", cuts=1, bevel=0.004))
    out.append(box("receiver-screen", (rx - 0.055, ry - RECEIVER_R - 0.034, RECEIVER_Z[0] + 0.18),
                   (rx + 0.055, ry - RECEIVER_R - 0.03, RECEIVER_Z[0] + 0.25), mat="screen", cuts=0, bevel=0.002))
    # the receiver's pressure gauge: rises later than the chamber's and
    # settles sooner
    out += gauge(a, "recv", (rx - 0.02, ry - RECEIVER_R - 0.02), RECEIVER_Z[1] - 0.13, size=0.13)
    # the top run: up out of the receiver, west, then south and down into
    # the coil's top turn. Every bend flanged.
    vx, vy = VESSEL
    coil_r = R_SHELL + 0.032
    cx_end = rx - 0.18
    cy_end = vy + math.sqrt(max(coil_r ** 2 - (cx_end - vx) ** 2, 0.0))
    top_z = Z_UPPER[1] - 0.045
    a.run("greeble:pipe_run", [(rx, ry, RECEIVER_Z[1] + 0.03), (rx, ry, RISER_TOP),
                               (cx_end, ry, RISER_TOP), (cx_end, cy_end + 0.02, RISER_TOP),
                               (cx_end, cy_end + 0.02, top_z)],
          radius=RISER_R, flanges=True, mat="bronze", name="riser-hi")
    # the liquid line: a ribbed hose from the condenser's top-east corner up
    # the skid's east edge into the drum's south face, with a flange at each
    # end where it meets rigid metal
    # x 1.37 at most: at 1.43 the hose's ribs sat inside the east extreme's
    # band and its rows overlapped the compressor's, which is a full-width
    # scanline. It enters the drum below the screen housing, not behind it.
    hose = [(COND[2] - 0.12, COND[3] - 0.03, COND_Z[1] - 0.01), (1.37, -0.50, 0.60), (1.37, 0.02, 0.70),
            (1.30, 0.22, 0.90), (rx + 0.02, ry - RECEIVER_R + 0.02, 1.00)]
    out.append(gen.bellows("liquid-hose", hose, 0.052, pitch=0.05, rib=0.013, mat="hose"))
    a.place("greeble:flange", at=(hose[0][0], hose[0][1]), z=hose[0][2], size=0.16, thickness=0.03, bolts=6,
            mat="bronze", name="liquid-hose-j0")
    a.place("greeble:flange", at=(hose[-1][0], hose[-1][1] - 0.02), z=hose[-1][2], size=0.16, thickness=0.03,
            bolts=6, axis="Y", mat="bronze", name="liquid-hose-j1")
    # the liquid-line valve: three spokes, so a quarter turn shows
    a.place("greeble:handwheel", at=(rx, ry - RISER_R - 0.07), z=SKID_TOP + 0.34, size=0.14, axis="Y",
            spokes=3, mat="bronze", name="valve-riser")
    gen.PIVOTS["valve-riser"] = (rx, ry - RISER_R - 0.07, SKID_TOP + 0.34)
    return out


def plumbing(a):
    """The rest of the circuit: compressor -> condenser (the discharge line,
    a ribbed flex section off the head, then rigid across the seam and down
    the saddle), and coil -> compressor (the return, up the saddle's other
    lane). The liquid line lives in riser()."""
    out = []
    cx, cy, cz = COMP
    # discharge: a ribbed flexible section off the top of the block -- the
    # vibration break every compressor has -- then rigid east over the seam
    # plate, south down the saddle at z 0.90, then east into the condenser
    out.append(gen.bellows("discharge-hose", gen.sag_path((cx + 0.12, 0.86, cz + 0.14), (0.02, 0.86, 0.92), -0.06, 6),
                           0.05, pitch=0.048, rib=0.013, mat="hose"))
    a.place("greeble:flange", at=(cx + 0.12, 0.86), z=cz + 0.14, size=0.15, thickness=0.03, bolts=6, axis="X",
            mat="bronze", name="discharge-hose-j0")
    a.run("greeble:pipe_run", [(0.02, 0.86, 0.92), (0.06, 0.86, 0.90),
                               (0.06, -1.06, 0.90), (0.06, -1.06, 0.60), (COND[0] + 0.02, -1.06, 0.60)],
          radius=0.05, flanges=True, mat="bronze", name="line-discharge")
    # return: from the coil's west point down the saddle at z 0.74, north,
    # then west across the seam to the compressor's suction
    vx, vy = VESSEL
    coil_r = R_SHELL + 0.032
    # ...it drops to a flange on the skid and continues under the deck: one
    # run down the saddle reads as plumbing, two read as spaghetti
    a.run("greeble:pipe_run", [(vx - coil_r + 0.02, vy, Z_UPPER[0] + 0.06), (0.18, vy, Z_UPPER[0] + 0.06),
                               (0.18, vy, SKID_TOP + 0.03)],
          radius=0.045, flanges=True, mat="bronze", name="line-return")
    # the suction side re-emerges at the compressor: a short flanged stub
    # off its block, down through the mount plate
    a.run("greeble:pipe_run", [(cx + 0.02, 0.58, cz - 0.02), (cx + 0.02, 0.58, DECK_TOP + 0.04)],
          radius=0.045, flanges=True, mat="bronze", name="line-suction")
    # the discharge valve on the saddle run, turned under load
    a.place("greeble:handwheel", at=(0.06, -0.50), z=0.90 + 0.10, size=0.14, spokes=3,
            mat="bronze", name="valve-saddle")
    gen.PIVOTS["valve-saddle"] = (0.06, -0.50, 1.00)
    # the actuated valve on the return drop: a body on the pipe and a lever
    # pointing west over the saddle lane, thrown open for the index
    out.append(box("valve-body", (0.11, vy - 0.07, 1.06), (0.25, vy + 0.07, 1.18), mat="gunmetal", cuts=2, bevel=0.006))
    out.append(cyl("valve-stem", (0.18, vy - 0.10, 1.12), 0.025, 0.06, axis="Y", mat="steel", seg=10))
    out.append(box("valve-lever", (0.04, vy - 0.145, 1.105), (0.19, vy - 0.115, 1.135), mat="scoured", cuts=1, bevel=0.003))
    gen.PIVOTS["valve-lever"] = (0.18, vy - 0.13, 1.12)
    for k, y in enumerate((0.30, -0.30, -0.80)):
        out.append(boxes("pipe-clamp%d" % k,
                         [((0.00, y - 0.035, 0.84), (0.12, y + 0.035, 0.96)),
                          ((0.02, y - 0.02, SKID_TOP + 0.02), (0.10, y + 0.02, 0.86))],
                         mat="steel", cuts=1, bevel=0.004))
    return out


def stubs(a):
    """The fluid connection pictures, one per direction, each rendered on its
    own. A collar at the hull and a short barrel to the tile edge, and nothing
    more: the PIPE entity's own ending sprite carries the flange at the joint,
    so a flange here doubled it (photographed 2026-09-13, and it read as a
    spare flange on the far end of the pipe). Vanilla's assembler pictures are
    the same shape: a collar where the pipe meets the machine.

    The engine draws these centred on the tile OUTSIDE the connection, not on
    the entity -- make_sheets.py writes the sidecar shifts against that.
    """
    out = []
    r = STUB_R
    z = STUB_Z
    for key, pts, axis in (("N", [(0.0, 1.04, z), (0.0, 1.52, z)], "Y"),
                           ("S", [(0.0, -1.52, z), (0.0, -1.28, z)], "Y"),
                           ("E", [(1.36, 0.0, z), (1.52, 0.0, z)], "X"),
                           ("W", [(-1.52, 0.0, z), (-1.30, 0.0, z)], "X")):
        a.run("greeble:pipe_run", pts, radius=r, flanges=False, mat="steel", name="stub-%s" % key)
        inner = (pts[0] if key in ("N", "E") else pts[1])
        a.place("greeble:flange", at=(inner[0], inner[1]), z=inner[2], size=2 * (r + 0.06), thickness=0.06,
                bolts=8, axis=axis, mat="gunmetal", name="stub-%s-collar" % key)
    return out


# ---- assembly ------------------------------------------------------------

def build(mats):
    a = parts.Assembly(PREFIX, mats, bevel=0.005)
    a.purge()
    for obj in [o for o in bpy.data.objects if o.name.startswith(PREFIX)]:
        bpy.data.objects.remove(obj, do_unlink=True)
    gen.PIVOTS.clear()
    made = []
    made += plinth()
    made += west_hull(a)
    made += seam(a)
    made += east_skid(a)
    made += vessel(a)
    made += condenser(a)
    made += riser(a)
    made += plumbing(a)
    made += stubs(a)
    gen.PIVOTS["flywheel"] = (COMP[0], FLYWHEEL_Y, COMP[2])
    gen.PIVOTS["gear"] = GEAR
    gen.PIVOTS["pinion"] = PINION
    gen.PIVOTS["crank"] = (GEAR[0], GEAR[1], GEAR[2] + 0.22, CRANK_R, ROD_L)
    a.placed.extend(made)
    # flange() returns (disc, None) when bolts=0; report() cannot take a None
    a.placed = [o for o in a.placed if o is not None]
    return a
