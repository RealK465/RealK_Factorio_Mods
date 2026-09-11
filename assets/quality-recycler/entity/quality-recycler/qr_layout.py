"""The rebuilt machine: masses, hero, junction, grading unit, tertiary hardware.

Direction B from the Phase 1 look-dev, approved by the repo owner 2026-09-11.
The hero is a VERTICAL-AXIS eddy rotor -- a copper-poled disc in a bronze well
under a segmented guard ring -- and the reason is measured, not stylistic:

    set_direction() spins the model about Z. A ring about Y is a true circle
    in north and south and an edge-on LINE in east and west. A ring about Z
    is a true circle in all four. On a rotatable entity, a Z-axis rotor is
    the only radial form that reads in every rotation.

The shipped build's drum was on Y, which is why its east and west views lost
the hero entirely and read as a striped box. `qr_rebuild` carries the
projection arithmetic and the three variants this one was chosen from.

## The two size rules, and why they are not the same rule

`cone_z()` bounds HEIGHT: `max(|x|, |y|) + z <= APEX`. At ground level it
therefore allows a part to reach |x| or |y| = 2.25 -- three quarters of a tile
outside the footprint -- and vanilla spends exactly that. The chemical plant's
sprite is 145 screen px tall against a 96 px footprint, and it gets the extra
from pipe stubs hanging south at z ~ 0.

The design doc's separate rule, "no hull crosses +-1.32", is about the front
elevation: height spent outside the footprint buys nothing and costs wall. Both
rules are kept here. The HULL stays inside +-1.32; LOW hardware -- the loading
apron, the scrap chute, the output chute -- hangs out to +-2.05 at z < 0.35,
which is what takes this sprite from 86 x 112 screen px to roughly 102 x 131
against the chemical plant's 100 x 145.

## The silhouette guarantee

A row is full width only when the sprite's east and west extremes both fall in
it, so the extremes must belong to parts whose row bands are disjoint -- and
which parts those are changes with the rotation (`audit()` projects all four).
Worked out here rather than discovered afterwards:

    N  rows y+z   east x 1.32 rotor well+cage 0.58..1.39 | west x -1.86 scrap chute -0.88..-0.20
    E  rows -x+z  max y 1.18 cage arcs 0.24..0.33        | min y -2.05 apron 0.46..1.28
    S  rows -y+z  max x 1.32 rotor -0.34..0.47           | min x -1.86 scrap chute 0.62..1.30
    W  rows x+z   max -y 2.05 apron -1.04..-0.22         | min -y -1.18 cage arcs 1.44..1.53

Nothing else may come within 0.06 of x = +-1.32/-1.86 or y = 1.18/-2.05, or
`audit()` hands that extreme's whole row span to the newcomer.
"""
import math

import bpy

import quality_recycler_gen as gen
import qr_rebuild as rb
from qr_rebuild import barrel, radial_bars, ring, torus, wall_chevrons

from factorio_render import parts

PREFIX = gen.PREFIX
DECK = gen.DECK
box, boxes, cyl, prism = gen.box, gen.boxes, gen.cyl, gen.prism

# ---- the layout -----------------------------------------------------------

ROTOR = (0.60, 0.46)
R_OUT = 0.72                        # rotor well / guard outer radius
R_DISC = 0.58                       # the poled disc
ROTOR_Z = 0.70

GEAR = (-0.12, 0.40)                # the driven wheel that links the halves
GEAR_R = 0.26

SHRED_E = -0.36                     # the shredder skirt's east face
HULL_E = -0.44                      # the shredder hull's east face
GAP = (SHRED_E, ROTOR[0] - R_OUT)   # 0.24 tiles of slot, 8 screen px

MAW = (-1.14, -0.46, 0.18, 0.70)    # x0, x1, z0, z1 of the opening
MAW_Y = -1.14                       # the roller axis, in the open recess
MAW_ROLLER_Z = (0.25, 0.41, 0.57)
MAW_ROLLER_R = 0.078

GRADE_Z = 0.50
QUALITY = rb.QUALITY


def _cone(label, x, y, z, quiet=True):
    v = max(abs(x), abs(y)) + z
    if v > gen.APEX + 1e-6:
        print("[layout] %-18s cone %.3f > APEX %.2f" % (label, v, gen.APEX))
    elif not quiet:
        print("[layout] %-18s cone %.3f" % (label, v))
    return v


# ---- 0. the pad -----------------------------------------------------------


def pad():
    """Octagonal, cut away on the gap and at the north-west, and kept INSIDE
    the hardware that hangs off it.

    Two jobs. A gap between two masses is only a gap if the sprite has alpha in
    it, and the shipped build's gap sat over a continuous pad -- a dark seam on
    a solid outline, which the eye reads as one block. And a pad that reaches
    the sprite's own extremes owns both of them at once, which is the condition
    for a full-width scanline; this one stops well short on every side.
    """
    poly = [(-1.24, -1.40), (-0.50, -1.40), (-0.40, -1.24), (0.04, -1.38),
            (1.16, -1.38), (1.26, -1.24), (1.26, 1.00), (1.08, 1.20),
            (0.06, 1.20), (-0.06, 0.96), (-0.34, 0.96), (-0.46, 0.72),
            (-1.12, 0.72), (-1.24, 0.54)]
    return prism("pad", poly, 0.0, DECK, mat="concrete", cuts=1, bevel=0.02)


# ---- 1. HERO: the vertical eddy rotor -------------------------------------


def rotor(a):
    """Built first, oversized, and it keeps the detail budget.

    Screen diameter 2 * R_OUT = 1.44 tiles = 92 source px = 46 px at gameplay
    zoom, in a sprite about 102 px wide. Nothing else is allowed near that.

    The disc sits over an open bore rather than on a plate -- a dark cavity
    behind the copper is what stops it reading as a wheel bolted to a wall.
    """
    rx, ry = ROTOR
    out = []
    # the well, and the bore under the disc
    # `temper`, not `bronze`: it carries the heat ramp, and the well is the
    # new half's largest curved surface. Putting the violet on a flat deck
    # panel instead read as a purple carpet, which is the opposite of a
    # tempering colour -- an oxide film belongs where the heat is.
    out.append(ring("rotor-well", (rx, ry, 0.39), R_OUT, 0.56, 0.54,
                    mat="temper", seg=44))
    out.append(ring("rotor-well-lip", (rx, ry, 0.665), R_OUT + 0.025, 0.54,
                    0.06, mat="temperv", seg=44))
    out.append(cyl("rotor-bore", (rx, ry, 0.26), 0.555, 0.26, mat="cavity",
                   seg=34))
    out.append(ring("rotor-stator", (rx, ry, 0.30), 0.555, 0.475, 0.30,
                    mat="gunmetal", seg=34))
    # 18 stator slots inside the bore: visible through the gaps between poles,
    # and they are what makes the cavity read as a machine rather than a hole
    out.append(radial_bars("rotor-slot", (rx, ry, 0.34), 0.475, 0.552, 0.022,
                           0.26, 18, mat="cavity"))
    # the disc: 14 copper poles on a tempered carrier
    out.append(cyl("rotor-drum", (rx, ry, ROTOR_Z - 0.06), 0.245, 0.30,
                   mat="temper", seg=28))
    out.append(radial_bars("rotor-hub", (rx, ry, ROTOR_Z), 0.225, R_DISC,
                           0.070, 0.125, 14, mat="copper", taper=0.58))
    out.append(ring("rotor-band", (rx, ry, ROTOR_Z - 0.02), R_DISC + 0.042,
                    R_DISC - 0.030, 0.105, mat="copper", seg=38))
    out.append(ring("rotor-ribs", (rx, ry, ROTOR_Z + 0.045), R_DISC + 0.046,
                    R_DISC + 0.014, 0.05, mat="tempers", seg=38))
    out.append(radial_bars("rotor-bolts", (rx, ry, ROTOR_Z + 0.085), 0.105,
                           0.215, 0.032, 0.058, 7, mat="gunmetal", phase=12.0))
    out.append(torus("rotor-flange", (rx, ry, ROTOR_Z + 0.15), 0.160, 0.052,
                     mat="scoured", seg=24))
    out.append(cyl("rotor-cap", (rx, ry, ROTOR_Z + 0.19), 0.088, 0.10,
                   mat="scoured", seg=14))
    # the guard: four arcs with daylight between them, so the disc shows
    for i in range(4):
        a0 = 17.0 + i * 90.0
        out.append(ring("cage-arc%d" % i, (rx, ry, 0.88), R_OUT, R_OUT - 0.115,
                        0.09, mat="steel", a0=a0, a1=a0 + 56.0))
        ang = math.radians(-4.0 + i * 90.0)
        px, py = rx + (R_OUT - 0.06) * math.cos(ang), ry + (R_OUT - 0.06) * math.sin(ang)
        out.append(cyl("cage-post%d" % i, (px, py, 0.76), 0.050, 0.30,
                       mat="steel", seg=10))
        out.append(torus("cage-boss%d" % i, (px, py, 0.915), 0.068, 0.028,
                         mat="gunmetal", seg=12, mseg=8))
        a.place("greeble:bolt_ring", at=(px, py), z=0.695, size=0.16,
                mat="gunmetal", name="cage-foot%d" % i)
    # the field coil over the hub. Small radius, so its height is cheap on the
    # cone, and it is a Z-axis circle so it survives every rotation.
    out.append(torus("coil-outer", (rx, ry, 1.10), 0.345, 0.062, mat="bronze",
                     seg=32))
    out.append(torus("coil-inner", (rx, ry, 1.045), 0.240, 0.040, mat="bronze",
                     seg=26))
    for k in range(14):
        ang = 2 * math.pi * k / 14
        out.append(box("coil-wind%d" % k,
                       (rx + 0.222 * math.cos(ang) - 0.033,
                        ry + 0.222 * math.sin(ang) - 0.033, 1.010),
                       (rx + 0.382 * math.cos(ang) + 0.033,
                        ry + 0.382 * math.sin(ang) + 0.033, 1.135),
                       mat="copper", cuts=1))
    for i in range(3):
        ang = math.radians(48.0 + i * 120.0)
        out.append(cyl("coil-leg%d" % i,
                       (rx + 0.340 * math.cos(ang), ry + 0.340 * math.sin(ang),
                        0.92), 0.044, 0.42, mat="steel", seg=8))
    # THE LIFTING GANTRY. The sprite's top edge is set by max(y + z) and sat
    # at 2.08 where the cone allows 2.25 -- 11 source px of skyline going
    # unused. A davit north of the rotor takes it, and it is the part that
    # would actually be there: something has to lift the disc out for service.
    out.append(cyl("gantry-post", (0.60, 1.02, 0.78), 0.052, 0.78,
                   mat="scoured", seg=10))
    out.append(cyl("gantry-arm", (0.60, 0.86, 1.15), 0.042, 0.34, axis="Y",
                   mat="scoured", seg=8))
    out.append(torus("gantry-eye", (0.60, 0.70, 1.14), 0.062, 0.024,
                     mat="gunmetal", seg=12, mseg=8))
    out.append(box("gantry-foot", (0.50, 0.92, 0.38), (0.70, 1.12, 0.46),
                   mat="tempers"))
    _cone("gantry", 0.60, 1.02, 1.19)
    _cone("cage-arc east", rx + R_OUT, ry, 0.925)
    _cone("coil", rx + 0.407, ry, 1.162)
    return out


def drive(a):
    """The ring gear that links the salvaged half to the new one.

    The design doc's one mechanical statement about the seam, and the shipped
    build buried it inside a bearing wall. Here it stands in the slot between
    the two masses at 36% of the hero's diameter, on Z like the rotor, so the
    two wheels read as geared together in every rotation.
    """
    gx, gy = GEAR
    out = [cyl("gear-disc", (gx, gy, 0.60), GEAR_R - 0.055, 0.13,
               mat="tempers", seg=24),
           radial_bars("gear-teeth", (gx, gy, 0.60), GEAR_R - 0.060, GEAR_R,
                       0.030, 0.125, 20, mat="scoured"),

           cyl("gear-shaft", (gx, gy, 0.56), 0.052, 0.30, mat="steel", seg=12),
           torus("gear-collar", (gx, gy, 0.70), 0.078, 0.030, mat="copper",
                 seg=14)]
    out.append(boxes("gear-pier", [((gx - 0.13, gy - 0.15, DECK),
                                    (gx + 0.13, gy + 0.15, 0.50))],
                     mat="bronze"))
    a.place("greeble:bolt_ring", at=(gx, gy - 0.19), z=0.52, size=0.20,
            mat="gunmetal", name="gear-bolts")
    return out


# ---- 2. the salvaged olive half -------------------------------------------


def shredder(a):
    """Chunky, stepped, olive, and grounded in vanilla on purpose.

    The brief's futurism gradient puts the refinement at the rotor end. This
    half gets one curved primary form -- the intake hood -- cleaner steps, and
    a maw 0.68 x 0.48 tiles, which is 22 x 15 px in game against the shipped
    build's 13 x 6.
    """
    out = []
    x0, x1, z0, z1 = MAW
    # THE SKIRT IN THREE SPANS. One box stands in front of the maw and hides it
    # completely -- the opening is at y -1.34..-1.00 and a skirt face at -1.36
    # is nearer the camera. Invisible in the model, fatal in the sprite.
    out.append(boxes("shred-skirt",
                     [((-1.30, -1.38, DECK), (x0 - 0.02, 0.14, 0.50)),
                      ((x1 + 0.02, -1.38, DECK), (SHRED_E, 0.14, 0.50)),
                      ((-1.30, -1.02, DECK), (SHRED_E, 0.14, 0.50))],
                     mat="olived"))
    # THE HULL IS BUILT AROUND THE MAW, not through it. A single box with a
    # dark "cavity" block laid over the opening is a SOLID block, and the three
    # rollers inside it drew exactly zero pixels in all four rotations -- the
    # shredder's whole identity, invisible, with nothing in the render to say
    # so. Five spans leave a genuine 0.22-tile recess instead.
    #
    # The recess depth is chosen against the camera: at 45 degrees a ray
    # entering at the lintel drops one tile of z per tile of y, so a 0.22-deep
    # recess under a 0.52-tall opening shows everything from the lintel down to
    # z 0.47 at the back wall -- which is where all three rollers sit.
    mx0, mx1 = MAW[0] - 0.06, MAW[1] + 0.06
    mz0, mz1 = MAW[2] - 0.04, MAW[3] + 0.05
    out.append(boxes("shred-hull",
                     [((-1.22, -1.26, DECK), (mx0, 0.06, 0.98)),
                      ((mx1, -1.26, DECK), (HULL_E, 0.06, 0.98)),
                      ((mx0, -1.26, mz1), (mx1, 0.06, 0.98)),
                      ((mx0, -1.26, DECK), (mx1, 0.06, mz0)),
                      ((mx0, -1.04, mz0), (mx1, 0.06, mz1))],
                     mat="olive"))
    out.append(box("shred-crown", (-1.06, -1.10, 0.96), (-0.54, -0.10, 1.10),
                   mat="olive"))
    out.append(box("shred-cap", (-1.10, -1.14, 1.06), (-0.50, -0.06, 1.13),
                   mat="scoured"))
    # the intake hood: an arc swept along X, this half's one curved primary.
    # 0.96 wide and crowning at 1.28 -- the cone allows 2.25 and the binding
    # vertex is the hood's own west end at |x| 0.96.
    out.append(rb.hood("shred-hood", -0.96, -0.60, (-0.60, 1.08), 0.20,
                       mat="olive", thick=0.050, a0=-7.0, a1=187.0))
    for i, x in enumerate((-0.94, -0.62)):
        out.append(ring("shred-hood-rib%d" % i, (x, -0.60, 1.08), 0.225, 0.175,
                        0.045, axis="X", mat="steel", a0=-7.0, a1=187.0))
    out.append(box("shred-hood-hatch", (-0.90, -0.74, 1.24), (-0.66, -0.46,
                                                              1.30),
                   mat="gunmetal"))
    a.place("greeble:handwheel", at=(-0.78, -0.60), z=1.30, size=0.12,
            mat="copper", name="shred-hood-wheel")
    # THE COOLING FAN on the crown, north of the hood. A Z-axis fan, because a
    # Y-axis one is edge-on in east and west -- the same rule that moved the
    # hero. 5 blades, so one loop only has to cover 72 degrees.
    out.append(ring("fan-ring", (-0.80, -0.24, 1.14), 0.190, 0.160, 0.07,
                    mat="steel", seg=20))
    out.append(cyl("fan-hub", (-0.80, -0.24, 1.13), 0.048, 0.07, mat="gunmetal",
                   seg=12))
    out.append(radial_bars("fan-blade", (-0.80, -0.24, 1.12), 0.048, 0.163,
                           0.048, 0.030, 5, mat="steel", taper=1.6))
    out.append(radial_bars("fan-grille", (-0.80, -0.24, 1.165), 0.050, 0.162,
                           0.013, 0.022, 8, mat="gunmetal"))
    # THE MAW: a back wall and a floor, with open air between them and the
    # opening. The dark is the recess itself plus Cycles' own AO, which is what
    # makes a mouth read as a mouth rather than as a painted black rectangle.
    out.append(boxes("maw-cav",
                     [((x0, -1.08, z0 - 0.03), (x1, -1.04, z1 + 0.04)),
                      ((x0, -1.26, z0 - 0.03), (x1, -1.04, z0 + 0.02)),
                      ((x0 - 0.02, -1.26, z0), (x0 + 0.02, -1.04, z1)),
                      ((x1 - 0.02, -1.26, z0), (x1 + 0.02, -1.04, z1))],
                     mat="pitch"))
    out.append(boxes("maw-jamb",
                     [((x0 - 0.06, -1.30, z0 - 0.04), (x0, -1.02, z1 + 0.05)),
                      ((x1, -1.30, z0 - 0.04), (x1 + 0.06, -1.02, z1 + 0.05)),
                      ((x0 - 0.06, -1.30, z1), (x1 + 0.06, -1.04, z1 + 0.05))],
                     mat="steel"))
    for i, z in enumerate(MAW_ROLLER_Z):
        out.append(cyl("maw-roller%d" % i, (0.5 * (x0 + x1), MAW_Y, z),
                       MAW_ROLLER_R, x1 - x0 - 0.06, axis="X", mat="scoured",
                       seg=18))
        out.append(radial_bars("maw-teeth%d" % i, (0.5 * (x0 + x1), MAW_Y, z),
                               MAW_ROLLER_R - 0.022, MAW_ROLLER_R + 0.028,
                               0.020, x1 - x0 - 0.10, 9, axis="X",
                               mat="scoured"))
    # THE LOADING APRON, hanging 0.55 tiles south of the footprint at z < 0.25.
    # This is where the sprite's height comes from: the cone bounds height, not
    # reach, so low hardware outside the tiles is free. Vanilla's chemical
    # plant spends 0.76 tiles the same way on its pipe stubs.
    out.append(prism("apron", [(-1.12, -1.30), (-0.42, -1.30), (-0.52, -2.05),
                               (-1.02, -2.05)], 0.06, 0.20, mat="gunmetal",
                     cuts=1))
    out.append(boxes("apron-rail",
                     [((-1.14, -1.96, 0.18), (-1.00, -1.30, 0.28)),
                      ((-0.54, -1.96, 0.18), (-0.40, -1.30, 0.28))],
                     mat="gunmetal"))
    # a scoured wear track down the middle: the route material actually takes,
    # told in value contrast, which is what survives gameplay zoom
    out.append(prism("apron-track", [(-0.96, -1.32), (-0.58, -1.32),
                                     (-0.64, -1.98), (-0.90, -1.98)],
                     0.195, 0.215, mat="scoured", cuts=1))
    # Hazard stripes PAINTED ON THE APRON DECK, not standing on a south face.
    # As a wall band they floated above the 0.20 deck and their backing plate
    # reached max(|x|,|y|) + z = 2.34 against APEX 2.25 -- and fit_cone()
    # answers an overrun by shrinking the whole machine, so a decal nobody
    # would miss was costing every other part 3.6% of its size.
    out.append(prism("apron-chev-back", [(-1.03, -2.00), (-0.59, -2.00),
                                         (-0.53, -1.78), (-0.97, -1.78)],
                     0.198, 0.206, mat="cavity", cuts=1, bevel=0.004))
    for j in range(4):
        x = -1.00 + j * 0.098
        out.append(prism("apron-chev%d" % j,
                         [(x, -1.98), (x + 0.046, -1.98),
                          (x + 0.098, -1.80), (x + 0.052, -1.80)],
                         0.204, 0.216, mat="hazard", cuts=0, bevel=0.004))
    a.run("greeble:skid_feet", [(-1.04, -1.96, 0.02), (-0.50, -1.96, 0.02)],
          mat="gunmetal", name="apron-feet")
    # THE FEEDER RAM: the apron's reason to exist, and the machine's secondary
    # mechanical motion. 0.30 x 0.24 tiles sliding 0.30 north into the maw and
    # back -- 19 x 15 source px travelling 19, which reads at gameplay zoom
    # where a flap inside the 0.24-tile slot would have been 15 px wide and
    # invisible.
    out.append(box("flap-ram", (-0.92, -1.84, 0.19), (-0.62, -1.60, 0.33),
                   mat="gunmetal"))
    out.append(boxes("flap-ram-head",
                     [((-0.95, -1.63, 0.18), (-0.59, -1.56, 0.37))],
                     mat="scoured"))
    # y -1.86 with a 0.18 barrel, not -1.95 with 0.24: at 0.035 radius the
    # rod reached max(|x|,|y|) + z = 2.36 against an APEX of 2.25, and
    # fit_cone() answered by shrinking the ENTIRE MACHINE 4.5%. One 11 px rod
    # is not worth 4.5% of every other part.
    out.append(cyl("flap-ram-rod", (-0.77, -1.86, 0.24), 0.035, 0.18, axis="Y",
                   mat="steel", seg=10))
    # THE SCRAP CHUTE, hanging west. Its row band is chosen to be disjoint from
    # the rotor's in every rotation -- see the module docstring.
    out.append(prism("chute-w", [(-1.24, -1.00), (-1.24, -0.50), (-1.86, -0.60),
                                 (-1.86, -0.92)], 0.12, 0.30, mat="gunmetal",
                     cuts=1))
    out.append(box("chute-w-lip", (-1.90, -0.92, 0.10), (-1.76, -0.58, 0.34),
                   mat="gunmetal"))
    out.append(torus("chute-w-collar", (-1.22, -0.75, 0.32), 0.15, 0.042,
                     axis="X", mat="copper", seg=16, mseg=8))
    # hazard chevrons: the concept sheet's loudest feature, and the shipped
    # build had none that survived. South wall AND west wall -- west is the
    # front elevation once the machine faces east.
    out += wall_chevrons("shred-chev-s", "S", -1.16, -0.44, 0.79, 0.96, -1.26,
                         count=5)
    out += wall_chevrons("shred-chev-w", "W", -1.14, -0.22, 0.54, 0.80, -1.22,
                         count=6)
    return out


# ---- 3. the junction ------------------------------------------------------


def junction(a):
    """A machined coupling collar, swept conduits, and the slot itself.

    Vanilla reads a join as a FITTING, not as a gap -- a uniform gap everywhere
    is what makes assembled props look like props. The slot is 0.24 tiles of
    dark floor with the drive shaft and two conduits crossing it.
    """
    jx = 0.5 * (GAP[0] + GAP[1])
    out = []
    out.append(box("gap-floor", (GAP[0], -0.90, DECK), (GAP[1], 0.58, 0.19),
                   mat="cavity"))
    out.append(box("seam-plinth", (GAP[0] - 0.05, -0.80, DECK),
                   (GAP[1] + 0.05, -0.34, 0.58), mat="bronze"))
    out.append(torus("seam-collar", (jx, -0.57, 0.62), 0.235, 0.058,
                     mat="copper", seg=28))
    out.append(ring("seam-ring", (jx, -0.57, 0.50), 0.190, 0.122, 0.20,
                    mat="tempers", seg=24))
    out.append(radial_bars("seam-bolts", (jx, -0.57, 0.695), 0.075, 0.220,
                           0.028, 0.05, 8, mat="gunmetal"))
    # A BOLTED STRAP up the shredder's east face, which IS the seam plane. One
    # collar at one y is a fitting; a strap running the height of the join is
    # what says the two halves were bolted together -- and "no visible joint"
    # was the standing criticism of every build so far.
    out.append(boxes("seam-strap",
                     [((HULL_E - 0.02, -1.10, 0.22), (HULL_E + 0.05, -0.94, 0.94)),
                      ((HULL_E - 0.02, -0.30, 0.22), (HULL_E + 0.05, -0.14, 0.94)),
                      ((HULL_E - 0.02, -1.12, 0.86), (HULL_E + 0.05, -0.12, 0.94))],
                     mat="scoured"))
    a.run("greeble:rivet_row", (HULL_E + 0.045, -1.06, 0.60),
          (HULL_E + 0.045, -0.18, 0.60), mat="gunmetal", name="seam-rivets")
    # swept conduits bridging the slot, with sag
    a.run("greeble:pipe_run",
          [(-0.40, -0.98, 0.84), (-0.10, -1.02, 0.76), (0.14, -0.96, 0.66),
           (0.34, -0.86, 0.58)], radius=0.052, mat="bronze", name="seam-pipe0")
    a.run("greeble:pipe_run",
          [(-0.58, 0.26, 0.88), (-0.22, 0.34, 0.80), (0.16, 0.40, 0.66)],
          radius=0.044, mat="tempers", name="seam-pipe1")
    a.run("greeble:cable", (-0.52, -0.36, 0.92), (0.02, -0.30, 0.70),
          sag=0.12, mat="rubber", name="seam-cable0")
    a.run("greeble:cable", (-0.50, -0.18, 0.90), (0.04, -0.12, 0.66),
          sag=0.14, mat="rubber", name="seam-cable1")
    return out


# ---- 4. the grading unit --------------------------------------------------


def grading(a):
    """Five up-facing lenses in the vanilla quality colours, on a tilted panel.

    UP-facing is the whole design. An emissive on a wall is face-on in one
    rotation, a bright streak in two and invisible in the fourth; the deck is
    the one surface this camera always sees. Pitch 0.22 tiles = 14 source px =
    7 px in game, comfortably over the ~3-4 px legibility floor.

    The lenses are NOT emissive in the base sheet. An emission shader washes
    its own hue toward white under this rig -- rare rendered cyan rather than
    navy -- so the base carries the true colour as a lit dielectric and the
    glow layer carries the light.
    """
    out = []
    out.append(box("grade-body", (0.04, -1.34, DECK), (1.22, -0.66, 0.42),
                   mat="steel"))
    out.append(box("grade-face", (0.08, -1.30, 0.40), (1.18, -0.70, GRADE_Z),
                   mat="gunmetal"))
    out.append(box("grade-window", (0.16, -1.06, GRADE_Z - 0.015),
                   (1.12, -0.84, GRADE_Z + 0.03), mat="cavity"))
    out.append(boxes("grade-rail",
                     [((0.12, -1.32, GRADE_Z - 0.02), (1.16, -1.28, GRADE_Z + 0.07)),
                      ((0.12, -0.74, GRADE_Z - 0.02), (1.16, -0.70, GRADE_Z + 0.07))],
                     mat="scoured"))
    for i in range(5):
        x = 0.26 + i * 0.22
        out.append(ring("grade-bezel%d" % i, (x, -1.18, GRADE_Z + 0.02), 0.085,
                        0.060, 0.08, mat="gunmetal", seg=16))
        out.append(cyl("grade-lens%d" % i, (x, -1.18, GRADE_Z + 0.042), 0.061,
                       0.05, mat="q%d" % i, seg=16))
    # the single output: one chute, hanging south-east, so the five grades
    # visibly leave by one door. The design doc's four bins implied four
    # separately drawable outputs, which the entity does not have.
    out.append(prism("chute-out", [(0.94, -1.30), (1.24, -1.30), (1.20, -1.92),
                                   (0.98, -1.92)], 0.10, 0.34, mat="gunmetal",
                     cuts=1))
    out.append(box("chute-out-lip", (0.92, -1.96, 0.08), (1.26, -1.84, 0.26),
                   mat="tempers"))
    a.place("greeble:placard", at=(0.42, -1.36), z=0.30, size=0.20,
            mat="hazard", name="grade-placard")
    a.place("greeble:gauge_pod", at=(1.00, -0.80), z=GRADE_Z, size=0.115,
            mat="steel", name="grade-gauge0")
    return out


# ---- 5. the quiet north-west, power in, heat out --------------------------


def service(a):
    """The north-west kept LOW, which is what makes the diagonal read.

    A machine with all four quadrants at the same height is a block however the
    detail is arranged. This corner carries the human-service and power-in
    flows at ankle height.
    """
    out = []
    out.append(box("nw-deck", (-1.10, 0.18, DECK), (-0.52, 0.68, 0.30),
                   mat="steel"))
    out.append(barrel("nw-drum", (-0.88, 0.44, 0.50), 0.19, 0.36, axis="Y",
                      mat="gunmetal", bulge=0.012, seg=20))
    out.append(ring("nw-drum-cheek", (-0.88, 0.25, 0.50), 0.205, 0.055, 0.05,
                    axis="Y", mat="steel", seg=20))
    out.append(box("nw-crate", (-0.66, 0.20, 0.28), (-0.54, 0.52, 0.46),
                   mat="olive"))
    a.place("greeble:junction_box", at=(-1.02, 0.26), z=0.30, size=0.19,
            mat="gunmetal", name="nw-jbox")
    a.run("greeble:cable", (-1.02, 0.26, 0.50), (-0.62, -0.02, 0.32),
          sag=0.10, mat="rubber", name="nw-cable0")
    a.run("greeble:ladder", (-1.20, -0.30, DECK), 0.86, mat="steel",
          name="shred-ladder")
    return out


def power(a):
    """Power in: a junction box on the rotor deck, a capacitor row, and cable
    runs that go somewhere. The rotor draws hard and that should show."""
    out = []
    out.append(boxes("cap-bank", [((0.10, 0.86, 0.30), (0.52, 1.14, 0.36))],
                     mat="gunmetal"))
    for i in range(3):
        x = 0.18 + i * 0.14
        out.append(cyl("cap-can%d" % i, (x, 1.00, 0.50), 0.100, 0.30,
                       mat="tempers", seg=16))
        out.append(torus("cap-top%d" % i, (x, 1.00, 0.66), 0.082, 0.028,
                         mat="copper", seg=14, mseg=8))
    out.append(boxes("cap-bus", [((0.12, 0.96, 0.66), (0.50, 1.04, 0.705))],
                     mat="copper"))
    a.place("greeble:junction_box", at=(0.16, 0.72), z=0.38, size=0.26,
            mat="gunmetal", name="rot-jbox")
    a.run("greeble:cable", (0.20, 1.14, 0.44), (0.44, 1.12, 0.64), sag=0.07,
          mat="rubber", name="rot-cable0")
    a.run("greeble:cable", (0.52, 1.14, 0.66), (0.30, 1.16, 0.44), sag=0.07,
          mat="rubber", name="rot-cable1")
    a.run("greeble:cable", (1.06, 1.16, 0.44), (1.22, 0.86, 0.38), sag=0.08,
          mat="rubber", name="rot-cable2")
    return out


def heat(a):
    """Heat out. Earned rather than decorative: eddy currents genuinely make
    heat, and this is the machine's stated reason for a tempered half."""
    out = []
    # Clear of the rotor bore: (0.86, -0.44) is 0.94 tiles from the rotor
    # centre, outside R_OUT. The obvious spot inside the well would have put
    # the whole radiator in the cavity, which is how the shipped build lost
    # one entirely.
    a.place("greeble:radiator", at=(0.98, 1.00), z=0.34, size=0.44, rot=90.0,
            mat="tempers", name="rot-rad")
    a.place("greeble:louvre_bank", at=(-0.80, 0.00), z=0.62, size=0.30,
            mat="steel", name="shred-louvre")
    # On the east apron's outward face, where the camera reaches it in the
    # west rotation. The first cut lay flat in the rotor deck at z 0.40 with
    # the deck's own step in front of it, and every fin drew zero pixels.
    out.append(boxes("rot-vent", [((1.19, -0.34, 0.36), (1.27, 0.12, 0.54))],
                     mat="cavity"))
    for i in range(4):
        y = -0.30 + i * 0.115
        out.append(box("rot-vent-fin%d" % i, (1.18, y, 0.37), (1.28, y + 0.070,
                                                               0.52),
                       mat="gunmetal", cuts=1))
    return out


def stack(a):
    """Exhaust, central. Height is free in the middle of the cone and costs
    overhang at the edges, which is why it is not on the olive half."""
    out = [cyl("stack", (-0.26, 0.50, 1.02), 0.102, 0.80, mat="gunmetal",
               seg=16),
           ring("stack-cowl", (-0.26, 0.50, 1.42), 0.162, 0.102, 0.11,
                mat="scoured", seg=16),
           torus("stack-band", (-0.26, 0.50, 0.98), 0.122, 0.026, mat="bronze",
                 seg=16, mseg=8),
           box("stack-foot", (-0.40, 0.34, 0.56), (-0.12, 0.66, 0.68),
               mat="tempers"),
           boxes("stack-stay", [((-0.62, 0.40, 0.86), (-0.28, 0.46, 0.92)),
                                ((-0.62, 0.36, 0.30), (-0.54, 0.46, 0.90))],
                 mat="steel")]
    return out


def rotor_deck(a):
    """The plinth the hero stands on, stepped so the rotor is RAISED above the
    olive half rather than beside it -- the diagonal is in height as well as in
    plan."""
    out = [prism("rot-deck", [(0.00, -0.62), (1.24, -0.62), (1.24, 0.98),
                              (1.04, 1.18), (0.08, 1.18), (0.00, 0.94)],
                 DECK, 0.28, mat="tempers", cuts=1),
           prism("rot-step", [(0.06, -0.50), (1.18, -0.50), (1.18, 0.90),
                              (0.98, 1.10), (0.14, 1.10), (0.06, 0.84)],
                 0.28, 0.38, mat="tempers", cuts=1)]
    # Panel seams on the step, because a 1.1 x 1.4-tile deck is the largest
    # uninterrupted surface on the machine and the camera sees the deck more
    # than any other face. Flat violet there read as a carpet.
    out.append(boxes("rot-plate",
                     [((0.12, -0.44, 0.38), (0.60, 0.24, 0.415)),
                      ((0.12, 0.30, 0.38), (0.60, 0.80, 0.415))],
                     mat="tempers", cuts=1))
    out.append(boxes("rot-seam",
                     [((0.62, -0.46, 0.38), (0.66, 0.84, 0.405)),
                      ((0.10, 0.26, 0.38), (0.62, 0.29, 0.405))],
                     mat="gunmetal", cuts=1))
    a.run("greeble:rivet_row", (0.08, -0.58, 0.28), (1.18, -0.58, 0.28),
          mat="steel", name="rot-rivets0")
    return out


def structure(a):
    """Rivet rows, stiles and rails on all four walls, skid feet, placards.

    ALL FOUR WALLS, not just the south one. This entity rotates, so the west
    wall is the front elevation in east, the north wall in south and the east
    apron in west; treating only the south wall left three rotations reading as
    blank painted plates.
    """
    out = []
    # proud stiles on the shredder's south and west walls: real geometry, so
    # the bevel catches a highlight and the seam has a dark line under it
    out.append(boxes("shred-stile-s",
                     [((-1.24, -1.29, 0.50), (-1.14, -1.26, 0.98)),
                      ((-0.56, -1.29, 0.50), (-0.46, -1.26, 0.98))],
                     mat="steel"))
    out.append(boxes("shred-stile-w",
                     [((-1.25, -1.20, 0.14), (-1.22, -1.08, 0.96)),
                      ((-1.25, -0.12, 0.14), (-1.22, 0.00, 0.96))],
                     mat="steel"))
    out.append(boxes("shred-rail-n",
                     [((-1.22, 0.02, 0.72), (-0.44, 0.09, 0.80)),
                      ((-1.22, 0.02, 0.34), (-0.44, 0.09, 0.42))],
                     mat="steel"))
    a.run("greeble:rivet_row", (-1.20, 0.09, 0.88), (-0.46, 0.09, 0.88),
          mat="steel", name="shred-rivets-n")
    a.run("greeble:rivet_row", (-1.25, -1.02, 0.62), (-1.25, -0.02, 0.62),
          mat="steel", name="shred-rivets-w")
    a.run("greeble:skid_feet", [(-1.18, -1.32, 0.0), (-0.50, -1.32, 0.0),
                                (-1.18, 0.08, 0.0), (-0.50, 0.08, 0.0)],
          mat="gunmetal", name="shred-feet")
    a.place("greeble:placard", at=(-1.24, -0.70), z=0.60, size=0.20,
            mat="steel", name="shred-placard")
    a.place("greeble:gauge_pod", at=(-0.60, -1.28), z=0.62, size=0.08,
            mat="steel", name="shred-gauge")
    # the east apron -- the front elevation in the west rotation
    out.append(boxes("rot-apron",
                     [((1.18, -0.40, 0.16), (1.26, 0.84, 0.34)),
                      ((1.14, -0.44, 0.34), (1.26, -0.10, 0.52))],
                     mat="tempers"))
    # THE NORTH TIE BRACKET, and it exists for the silhouette as much as for
    # the machine. `audit()` collects every vertex within 0.06 of an extreme
    # into that extreme's row band, and the northernmost part was a 0.07-tile
    # cage boss at y 1.12 -- which pulled in the rotor step, the capacitor bank
    # and two cable runs and handed east a 0.96-tile band of full-width rows.
    # One bracket standing 0.12 proud of everything else owns max-y alone, and
    # its rows (-1.06..-0.75 in east) miss the apron's (0.43..1.38) entirely.
    out.append(boxes("rot-tie",
                     [((1.02, 1.16, 0.14), (1.20, 1.31, 0.30)),
                      ((1.05, 1.19, 0.30), (1.17, 1.28, 0.38))],
                     mat="tempers"))
    a.place("greeble:bolt_ring", at=(1.11, 1.235), z=0.375, size=0.13,
            mat="gunmetal", name="rot-tie-bolts")
    a.place("greeble:gauge_pod", at=(1.22, -0.52), z=0.48, size=0.11,
            mat="steel", name="rot-apron-gauge")
    return out


# ---- 6. emissives ---------------------------------------------------------


def emissives(a):
    """Small, local, and each one says something.

    One emissive family for the rotor energy (violet, epic quality's 286 deg,
    the only hue in the quality ramp no vanilla machine's emissive claims), the
    five quality lenses, and one green status lamp. Nothing else.
    """
    rx, ry = ROTOR
    out = []
    # The field gap: TWO ARCS between the coil's inner and outer hoops, not a
    # ring of separate boxes. Six discrete emitters read at gameplay zoom as
    # exactly what the owner called them on the shipped build -- "scattered
    # magenta dots that don't communicate what the machine is doing". A
    # continuous arc reads as one energised gap, and it is still a Z-axis
    # circle, so it survives every rotation.
    for i, a0 in enumerate((28.0, 208.0)):
        out.append(ring("field%d" % i, (rx, ry, 0.985), 0.320, 0.262, 0.05,
                        mat="violet", a0=a0, a1=a0 + 104.0, seg=30))
    # Arc contacts: a spark jumping RADIALLY from the disc rim to the guard,
    # in the gaps between the guard arcs and 10 degrees clear of the posts.
    #
    # The first cut put them at radius 0.60 and z 0.79, directly under the
    # guard arcs -- and the fx layer came back 51 frames out of 64 with almost
    # nothing in it. Neither the render nor any gate says so; the object-ID
    # pass and a strip of the raw frames do.
    for i in range(4):
        out.append(radial_bars("arc%d" % i, (rx, ry, 0.858), 0.520, 0.645,
                               0.030, 0.052, 1, mat="arcmat",
                               phase=6.0 + i * 90.0))
    # the scan bar over the grading window
    out.append(box("scan", (0.20, -1.02, GRADE_Z + 0.018),
                   (0.30, -0.88, GRADE_Z + 0.042), mat="violet", cuts=1))
    # status lamp: green, and it is the only thing lit when the machine is idle
    out.append(cyl("lamp", (-0.62, -0.96, 1.16), 0.058, 0.05, mat="led",
                   seg=12))
    out.append(ring("lamp-hood", (-0.62, -0.96, 1.150), 0.090, 0.058, 0.09,
                    mat="scoured", seg=12))
    out.append(cyl("lamp-stem", (-0.62, -0.96, 1.10), 0.030, 0.09,
                   mat="gunmetal", seg=8))
    return out


# ---- 7. the fragments the rotor throws ------------------------------------


def fragments():
    """Four chips in flight across the slot into the output chute. They are the
    only thing on the machine whose SILHOUETTE travels, which is why they go in
    their own overlay and never into the shadow pass."""
    out = []
    for i in range(4):
        out.append(box("frag%d" % i, (-0.075, -0.062, -0.055),
                       (0.075, 0.062, 0.055), mat="scoured", cuts=0,
                       bevel=0.018))
    return out


# ---- assembly -------------------------------------------------------------


def build(mats):
    rb.extra_materials()
    a = parts.Assembly(PREFIX, mats)
    a.purge()
    for obj in [o for o in bpy.data.objects if o.name.startswith(PREFIX)]:
        bpy.data.objects.remove(obj, do_unlink=True)
    for c in [c for c in bpy.data.collections if c.name in gen.COLL_NAMES]:
        bpy.data.collections.remove(c)

    made = [pad()]
    made += rotor_deck(a)
    made += rotor(a)
    made += drive(a)
    made += shredder(a)
    made += junction(a)
    made += grading(a)
    made += service(a)
    made += power(a)
    made += heat(a)
    made += stack(a)
    made += structure(a)
    made += emissives(a)
    made += fragments()
    a.placed.extend([o for o in made if o])
    gen.organise()
    return a
