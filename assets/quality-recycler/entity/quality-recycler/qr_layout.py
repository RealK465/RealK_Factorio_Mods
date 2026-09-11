"""v3: the machine built around where the game actually puts its output.

`vector_to_place_result = {0, -1.8}` on the prototype is the tile north of the
footprint, centred -- the yellow alt-mode arrow leaves the machine there, and
v2 had nothing there but the rotor housing. Photographed in the engine
2026-09-11 (four machines facing outward, chests on the output tiles): the
arrow points straight out of the rotor cowl in every rotation. A recycler whose
output appears from nowhere looks broken, so v3 is laid out from the port
backwards.

Coordinates: +y is north (screen up), +x east, z up; screen row is -(y + z).
Factorio's {0, -1.8} is therefore Blender (0, +1.8): the mouth sits on the
north edge at x = 0 and the chips leave through it.

## The route, south to north

    maw (S wall, olive, hazard collar)  ->  three shredder rollers
      -> transfer duct east across the seam  ->  the rotor (sorting, NE)
      -> discharge notch through the cowl's WEST, down a dark chute
      -> collection trough, north  ->  hydraulic pusher ram
      -> the open throat in the port's hood (chips drop in, seen from above)
      -> the mouth on the N edge, doors part  ->  sill  ->  the next tile.

The trough runs due north along x -0.46..-0.10, so the pusher's stroke is a
straight line in y -- screen-vertical in north and south, screen-horizontal
in east and west. Horizontal model motion is visible in all four rotations;
the only motion this camera cannot see is a slope descending away from it,
and that is exactly what a flap dropping out of a north-facing mouth would
be. So: a ram, not a flap.

## Why the port can be seen from behind

In north the port is on the far side. Two things read from above, which is
the one direction every rotation shares: the hood's open THROAT -- a dark
rectangle with a violet rim that the chips visibly drop into -- and the
riser's top face with the painted grade squares. Rows y + z of 2.13..2.23
clear the cowl's north rim (1.76 at x 0, 2.06 at x 0.44).

## The two size rules, unchanged from v2

`cone_z()` bounds HEIGHT (`max(|x|,|y|) + z <= APEX`), so low hardware may
hang out to +-2.25 at ground level and vanilla spends exactly that; the hull
itself stays inside +-1.32 for the front elevation. The port hopper hangs to
y 1.74 at z < 0.50, the sill to 1.90 at z 0.10, the apron to y -2.05.

## The silhouette guarantee, worked out for v3

A row is full width only when both screen extremes fall in it, and `audit()`
collects every vertex within 0.06 of an extreme into that extreme's row band:

    N  rows y+z    east x 1.32 rotor cowl 0.66..1.62 | west x -1.85 cabinet -1.07..-0.36
    E  rows -x+z   max y 1.90 sill -0.17..0.31       | min y -2.04 apron 0.50..1.28
    S  rows -y+z   max x 1.32 cowl -0.26..0.71       | min x -1.85 cabinet 0.80..1.40
    W  rows x+z    max -y 2.04 apron -1.15..-0.38    | min -y -1.90 sill -0.17..0.31

The sill is a deliberately small, low, narrow plate standing 0.12 clear of
everything else so that it -- and nothing wider -- owns max-y. The apron lost
its rails and moved 0.06 west for the same reason: in west its rows had to
stay under the sill's. The cabinet's feet sit at its south end because a foot
at y -0.78 shared the cowl's rows in south.
"""
import math

import bpy

import quality_recycler_gen as gen
import qr_rebuild as rb
from qr_rebuild import radial_bars, ring, torus, wall_chevrons, yz_prism

from factorio_render import parts

PREFIX = gen.PREFIX
DECK = gen.DECK
box, boxes, cyl, prism = gen.box, gen.boxes, gen.cyl, gen.prism

# ---- the layout -----------------------------------------------------------

ROTOR = (0.60, 0.46)
R_COWL = 0.72                       # armoured stator cowl, outer
R_WELL = 0.70                       # tempered well wall, outer
R_STATOR_IN = 0.50                  # the cowl's inner radius: the bore
R_CAP = 0.47                        # the slotted rotor cap, outer
R_HUB = 0.28
ROTOR_Z = 0.80                      # centre height of the magnet ring
POLES = 12
CAP_SLOTS = 6                       # 60 deg symmetry = 2 pole pitches
NOTCH = (170.0, 190.0)              # the discharge notch through the cowl

HULL_E = -0.44                      # the olive hull's east face
SHRED_E = -0.36                     # the skirt's east face
DECK_W = -0.16                      # the plinth's west edge

MAW = (-1.14, -0.46, 0.18, 0.74)    # x0, x1, z0, z1 of the opening
MAW_Y = -1.14
MAW_ROLLER_Z = (0.25, 0.41, 0.57)
MAW_ROLLER_R = 0.078

TROUGH_X = (-0.46, -0.10)           # the collection trough, running north
TROUGH_Y = (0.30, 1.16)
TROUGH_Z = 0.62                     # floor top
TROUGH_TOP = 0.92
RAM_X = -0.28
RAM_Z = 0.78
RAM_STROKE = 0.72                   # the pusher's travel, 46 source px

PORT_Y = (1.14, 1.70)               # the hopper, footprint edge at 1.50
PORT_W = 0.44                       # half-width
MOUTH_W = 0.30                      # half-width of the mouth
THROAT = (-0.44, -0.06, 1.20, 1.50) # x0, x1, y0, y1 of the open throat
SILL = (0.22, 1.75, 1.90)           # half-width, y0, y1 -- owns max-y

QUALITY = rb.QUALITY

# The tempering ramp radiates from the rotor; tell the generator where it is
# before build_materials() bakes `heat_from` into the materials.
gen.ROTOR_XY = ROTOR

# Parts that move. `organise()` sorts objects into collections by name prefix,
# and the render driver draws QR_Moving as the anim sheet.
gen.MOVING_KINDS = ("rotor-poles", "rotor-ring", "rotor-cap", "maw-roller",
                    "maw-teeth", "flap-", "ram-head", "ram-rod", "door-")
gen.FX_KINDS = ("frag", "arc")


def _cone(label, x, y, z):
    v = max(abs(x), abs(y)) + z
    if v > gen.APEX + 1e-6:
        print("[layout] %-18s cone %.3f > APEX %.2f" % (label, v, gen.APEX))
    return v


def rounded_rect(x0, y0, x1, y1, r, n=5):
    """A rectangle with quarter-round corners, as a polygon for prism()."""
    pts = []
    corners = [((x1 - r, y1 - r), 0.0), ((x0 + r, y1 - r), 90.0),
               ((x0 + r, y0 + r), 180.0), ((x1 - r, y0 + r), 270.0)]
    for (cx, cy), a0 in corners:
        for i in range(n + 1):
            a = math.radians(a0 + 90.0 * i / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# ---- materials the v3 look adds --------------------------------------------


def v3_materials():
    """The lighter panel family, in two values, and the machined metal.

    `composite` is the bright skin -- the rotor cap, the cowl, the port riser
    and hood: cool bone, satin, so it carries a soft broad highlight rather
    than the matte plaster the first pass rendered. `compdark` is the same
    family a step darker for the structural panels -- fairing, pockets, feed
    collar, armour plates, cabinet -- so the bright value is reserved for the
    two hero zones. Both are cool against the warm olive and copper, which is
    the two-technologies contrast told through temperature as well as hue.
    `polished` is the machined hub, the ram and the doors: metallic, smooth,
    small areas only.
    """
    m = gen._MATS
    m["composite"] = gen.worn_metal(
        "composite", gen.srgb("#A9A89E"), gen.srgb("#484C49"), 0.10, 0.34,
        0.54, grime=0.22, wear=0.10, rust=0.05, noise_scale=5.0)
    m["compdark"] = gen.worn_metal(
        "compdark", gen.srgb("#737874"), gen.srgb("#2A2E30"), 0.12, 0.36,
        0.56, grime=0.26, wear=0.12, rust=0.06, noise_scale=6.0)
    m["polished"] = gen.worn_metal(
        "polished", gen.srgb("#C4BDAE"), gen.srgb("#4A443C"), 0.55, 0.20,
        0.42, grime=0.10, wear=0.16, rust=0.04, scratch=0.55,
        noise_scale=14.0)
    m["seamdark"] = gen.plain("seamdark", gen.srgb("#17140F"), metallic=0.1,
                              rough=0.85)
    m["hose"] = gen.rubber("hose", color=gen.srgb("#3B3E44"))
    # The five grades as PAINT: matte, chipped at the edges, on a dark plate.
    # Colour may name a grade; light never does (FFF-339 discipline, and the
    # design doc's own rule). Mixed half way toward a neutral so they read as
    # painted squares rather than as UI chips.
    grey = (0.16, 0.15, 0.13)
    for i, hexcol in enumerate(QUALITY):
        q = gen.srgb(hexcol)
        lit = tuple(0.55 * a + 0.45 * b for a, b in zip(q, grey))
        dark = tuple(v * 0.40 for v in lit)
        m["paintq%d" % i] = gen.worn_metal(
            "paintq%d" % i, lit, dark, 0.08, 0.62, 0.88, grime=0.18,
            wear=0.30, rust=0.10, noise_scale=18.0)
    # Two more violets, so the scanner and the ejector lamp can be keyed
    # independently of the field ring.
    for name, strength in (("violet2", 0.6), ("violet3", 0.6)):
        m[name] = gen.plain(name, (0.02, 0.01, 0.03),
                            emission=gen.VIOLET_EMIT, strength=strength)
    return m


# ---- 0. the pad -----------------------------------------------------------


def pad():
    """Concrete, inside every extreme. Under the port hopper it reaches y 1.30
    so the hopper stands on something; the hopper's far end hangs on feet."""
    poly = [(-1.24, -1.40), (-0.50, -1.40), (-0.40, -1.26), (0.04, -1.38),
            (1.14, -1.38), (1.24, -1.24), (1.24, 1.02), (1.06, 1.22),
            (0.50, 1.22), (0.50, 1.30), (-0.50, 1.30), (-0.50, 1.20),
            (-1.10, 1.20), (-1.24, 0.98), (-1.24, 0.54)]
    return prism("pad", poly, 0.0, DECK, mat="concrete", cuts=1, bevel=0.02)


# ---- 1. the new half's plinth ---------------------------------------------


def plinth(a):
    """A rounded tempered-bronze slab the rotor stands in: big, clean, curved.

    Corner radius 0.26 is 17 source px -- a real rounded shoulder at gameplay
    zoom, not a chamfer. The slab is thin (0.28) so the rotor reads as sitting
    IN it. Dark, so the pale cowl on top is the brightest large form.
    """
    out = []
    out.append(prism("deck", rounded_rect(DECK_W, -0.64, 1.24, 1.10, 0.26),
                     DECK - 0.01, 0.40, mat="tempers", cuts=1, bevel=0.035))
    out.append(boxes("deck-seam",
                     [((0.46, -0.62, 0.392), (0.49, -0.30, 0.404)),
                      ((DECK_W + 0.06, -0.36, 0.392), (0.50, -0.33, 0.404))],
                     mat="seamdark", cuts=0, bevel=0.003))
    # human service: one inspection hatch with a handwheel
    out.append(cyl("deck-hatch", (1.02, -0.50, 0.42), 0.11, 0.05,
                   mat="polished", seg=20))
    a.place("greeble:handwheel", at=(1.02, -0.50), z=0.45, size=0.13,
            mat="copper", name="deck-wheel")
    # power in: the junction box the looms leave from
    a.place("greeble:junction_box", at=(0.24, -0.50), z=0.40, size=0.22,
            mat="gunmetal", name="deck-jbox")
    # heat out: the coolant's radiator on the east end of the strip
    a.place("greeble:radiator", at=(0.74, -0.52), z=0.40, size=0.30,
            mat="tempers", name="deck-rad")
    return out


# ---- 2. HERO: the sealed magnetic rotor -----------------------------------


def _cowl_arcs():
    """The four composite arcs, with the west one split round the notch."""
    arcs = []
    for i in range(4):
        a0 = 56.0 + i * 90.0
        a1 = a0 + 68.0
        if a0 < NOTCH[0] < a1:
            arcs.append((a0, NOTCH[0]))
            arcs.append((NOTCH[1], a1))
        else:
            arcs.append((a0, a1))
    return arcs


def rotor(a):
    """Not a fan: a segmented ring of magnet poles turning under a slotted
    composite cap, inside a stator of copper windings under an armoured cowl
    with four windows, a thin violet field gap between cap and cowl, and a
    machined spindle through the middle.

    The cap is what makes it SEALED. It turns with the rotor -- six slots, so
    a 60 degree turn closes the loop exactly as the twelve poles do -- and
    through the slots the alternating pole faces and the copper retaining
    ring show. A ring of blocks around a hub under a lid is a rotor; tapered
    blades from a hub in the open is a fan.
    """
    rx, ry = ROTOR
    out = []
    # the well: a thin tempered wall, heat-tinted, and a dark floor
    out.append(ring("rotor-well", (rx, ry, 0.55), R_WELL, R_WELL - 0.045,
                    0.34, mat="temper", seg=48))
    out.append(cyl("rotor-floor", (rx, ry, 0.46), R_WELL - 0.03, 0.16,
                   mat="cavity", seg=40))
    # a shadow line under the cowl's overhang
    out.append(ring("cowl-shade", (rx, ry, 0.705), R_COWL + 0.006, R_WELL - 0.04,
                    0.02, mat="seamdark", seg=48, cuts=0, bevel=0.0))
    # the stator: 12 copper winding bundles around the bore, under the cowl,
    # rising to 0.055 under its rim so they show through the windows
    out.append(radial_bars("stator-coil", (rx, ry, 0.72), 0.525, 0.685, 0.058,
                           0.26, POLES, mat="copper", phase=15.0, taper=1.25))
    out.append(ring("stator-band", (rx, ry, 0.56), 0.69, 0.51, 0.06,
                    mat="gunmetal", seg=44))
    # the armoured cowl: composite arcs, windows between them, and the
    # discharge notch cut through the west arc
    for i, (a0, a1) in enumerate(_cowl_arcs()):
        out.append(ring("cowl-arc%d" % i, (rx, ry, 0.81), R_COWL, R_STATOR_IN,
                        0.19, mat="composite", a0=a0, a1=a1, seg=52,
                        bevel=0.012))
    out.append(ring("cowl-rim", (rx, ry, 0.905), R_COWL + 0.005, R_COWL - 0.05,
                    0.025, mat="polished", seg=52, cuts=0, bevel=0.004))
    out.append(ring("cowl-bore", (rx, ry, 0.905), R_STATOR_IN + 0.045,
                    R_STATOR_IN - 0.005, 0.025, mat="seamdark", seg=48, cuts=0,
                    bevel=0.0))
    for i in range(4):
        ang = math.radians(90.0 + i * 90.0)
        cx, cy = rx + 0.61 * math.cos(ang), ry + 0.61 * math.sin(ang)
        out.append(box("cowl-clamp%d" % i, (cx - 0.07, cy - 0.09, 0.90),
                       (cx + 0.07, cy + 0.09, 0.95), mat="polished",
                       bevel=0.008))
        a.place("greeble:bolt_ring", at=(cx, cy), z=0.95, size=0.09, count=4,
                mat="gunmetal", name="cowl-lug%d" % i)
        out.append(radial_bars("cowl-groove%d" % i, (rx, ry, 0.906),
                               R_STATOR_IN + 0.05, R_COWL - 0.05, 0.012, 0.012,
                               1, mat="seamdark", phase=68.0 + i * 90.0, cuts=0,
                               bevel=0.0))
    # the window sills: a dark frame under each window
    for i in range(4):
        a0 = 34.0 + i * 90.0
        out.append(ring("cowl-window%d" % i, (rx, ry, 0.725), R_COWL - 0.01,
                        R_STATOR_IN + 0.01, 0.025, mat="cavity", a0=a0,
                        a1=a0 + 22.0, seg=52, cuts=0, bevel=0.0))
    # THE FIELD GAP: a thin violet ring between the cap and the cowl
    out.append(ring("field", (rx, ry, 0.865), 0.498, 0.478, 0.05, mat="violet",
                    seg=48, cuts=0, bevel=0.0))
    # the rotor: 12 magnet segments, alternating gunmetal and worn bright
    # steel (NOT polished: a metal with only a dim world to reflect renders
    # near-black inside a bore), in a copper retaining ring
    out.append(radial_bars("rotor-poles-a", (rx, ry, ROTOR_Z), 0.30, 0.455,
                           0.062, 0.12, POLES // 2, mat="gunmetal", phase=0.0,
                           taper=1.5))
    out.append(radial_bars("rotor-poles-b", (rx, ry, ROTOR_Z), 0.30, 0.455,
                           0.062, 0.12, POLES // 2, mat="scoured",
                           phase=360.0 / POLES, taper=1.5))
    out.append(ring("rotor-ring", (rx, ry, ROTOR_Z + 0.01), 0.474, 0.452,
                    0.14, mat="copper", seg=44))
    # THE CAP: a motor end-cap, not a spoked disc. A solid outer annulus and
    # a solid inner one, with six short CURVED vent slots between them --
    # concentric dashes, the vocabulary of a ventilated end shield -- and a
    # bolt circle. Radial slots read as spokes, which is the fan again.
    pitch = 360.0 / CAP_SLOTS
    out.append(ring("rotor-cap-outer", (rx, ry, 0.895), R_CAP, 0.405, 0.05,
                    mat="composite", seg=48, bevel=0.006))
    out.append(ring("rotor-cap-inner", (rx, ry, 0.895), 0.315, 0.12, 0.05,
                    mat="composite", seg=40, bevel=0.006))
    for i in range(CAP_SLOTS):
        a0 = i * pitch + 15.0
        out.append(ring("rotor-cap-web%d" % i, (rx, ry, 0.895), 0.41, 0.31, 0.05,
                        mat="composite", a0=a0, a1=a0 + 30.0, seg=48,
                        bevel=0.006))
    out.append(ring("rotor-cap-rim", (rx, ry, 0.90), R_CAP + 0.004, R_CAP - 0.03,
                    0.06, mat="polished", seg=48, cuts=0, bevel=0.004))
    out.append(torus("rotor-cap-groove", (rx, ry, 0.921), 0.20, 0.008,
                     mat="seamdark", seg=32, mseg=6))
    a.place("greeble:bolt_ring", at=(rx, ry), z=0.92, size=0.86, count=6,
            mat="gunmetal", name="rotor-cap-bolts")
    # the machined spindle through the cap
    out.append(cyl("hub", (rx, ry, 0.74), R_HUB + 0.01, 0.30, mat="polished",
                   seg=32))
    out.append(cyl("hub-cap", (rx, ry, 0.96), 0.085, 0.16, mat="polished",
                   seg=18))
    out.append(torus("hub-cap-ring", (rx, ry, 1.03), 0.07, 0.018, mat="copper",
                     seg=18, mseg=8))
    # THE DISCHARGE: a dark chute from the bore through the notch, down into
    # the trough, with a violet edge on the cowl at the cut
    nx = rx - R_STATOR_IN                       # 0.10, the bore's west edge
    tx = TROUGH_X[1] - 0.20                     # -0.30, over the trough
    out.append(gen.xz_prism("disc-chute",
                            [[(nx + 0.02, 0.905), (nx + 0.02, 0.84),
                              (tx, TROUGH_Z + 0.06), (tx, TROUGH_Z + 0.12)]],
                            ry - 0.10, ry + 0.10, mat="pitch"))
    out.append(boxes("disc-chute-wall",
                     [((tx, ry - 0.13, TROUGH_Z), (nx + 0.02, ry - 0.10, 0.92)),
                      ((tx, ry + 0.10, TROUGH_Z), (nx + 0.02, ry + 0.13, 0.92))],
                     mat="compdark", bevel=0.006))
    out.append(boxes("disc-edge",
                     [((nx - 0.02, ry - 0.135, 0.905), (nx + 0.16, ry - 0.115, 0.915)),
                      ((nx - 0.02, ry + 0.115, 0.905), (nx + 0.16, ry + 0.135, 0.915))],
                     mat="violet", cuts=0, bevel=0.0))
    # two arcs across the field gap, keyed on and off irregularly
    for i, ang in enumerate((70.0, 250.0)):
        out.append(radial_bars("arc%d" % i, (rx, ry, 0.875), 0.435, 0.515, 0.02,
                               0.03, 1, mat="arcmat", phase=ang, cuts=0,
                               bevel=0.0))
    _cone("cowl east clamp", rx + 0.68, ry, 0.95)
    _cone("hub cap", rx, ry, 1.05)
    return out


def looms(a):
    """Coolant and power arriving in neat runs, each with a fitting at both
    ends and a ferrule mid-run. Two hoses from the coolant tank to the cowl;
    two cables from the deck's junction box to the stator; two from the deck
    box across the seam into the old hull -- the new half plugging into the
    old. Thin and dark grey, not black: the loom must not out-contrast the
    hero.
    """
    rx, ry = ROTOR
    out = []
    tx, ty = -1.02, 0.52
    out.append(cyl("tank", (tx, ty, 0.42), 0.20, 0.60, mat="tempers", seg=28))
    out.append(torus("tank-band", (tx, ty, 0.30), 0.205, 0.02, mat="gunmetal",
                     seg=28, mseg=8))
    out.append(cyl("tank-cap", (tx, ty, 0.73), 0.14, 0.04, mat="compdark",
                   seg=24))
    a.place("greeble:flange", at=(tx, ty), z=0.75, size=0.16, mat="copper",
            name="tank-fit")
    for k, (ang, mid) in enumerate(((128.0, [(-0.76, 0.84, 0.80),
                                              (-0.50, 1.00, 0.96),
                                              (-0.20, 1.04, 0.97)]),
                                    (206.0, [(-0.74, 0.20, 0.80),
                                             (-0.46, 0.06, 0.94),
                                             (-0.20, 0.06, 0.97)]))):
        ex = rx + 0.60 * math.cos(math.radians(ang))
        ey = ry + 0.60 * math.sin(math.radians(ang))
        a.run("greeble:pipe_run", [(tx, ty, 0.78)] + mid + [(ex, ey, 0.95)],
              radius=0.022, flanges=False, mat="hose", name="hose%d" % k)
        a.place("greeble:flange", at=(ex, ey), z=0.905, size=0.12,
                mat="copper", name="hose%d-fit" % k)
        fx, fy, fz = mid[1]
        out.append(torus("hose%d-ferrule" % k, (fx, fy, fz), 0.028, 0.012,
                         axis="X", mat="copper", seg=10, mseg=6))
    # power: two cables from the deck junction box up onto the south cowl
    a.run("greeble:cable", (0.26, -0.46, 0.60), (0.50, -0.20, 0.90), sag=0.05,
          mat="rubber", name="loom0")
    a.run("greeble:cable", (0.30, -0.50, 0.60), (0.66, -0.22, 0.90), sag=0.05,
          mat="rubber", name="loom1")
    # ...and two across the seam into the old hull's junction box, south of
    # the ram cylinder and north of the duct, where the slot is clear
    a.place("greeble:junction_box", at=(HULL_E + 0.04, -0.52), z=0.66,
            size=0.18, mat="gunmetal", name="hull-jbox")
    a.run("greeble:cable", (0.20, -0.46, 0.60), (HULL_E + 0.05, -0.50, 0.86),
          sag=0.08, mat="rubber", name="seam-cable0")
    a.run("greeble:cable", (0.16, -0.54, 0.58), (HULL_E + 0.05, -0.56, 0.84),
          sag=0.10, mat="rubber", name="seam-cable1")
    return out


# ---- 3. material through: the transfer duct, the trough, the ejector ------


def transfer(a):
    """A fat flanged duct from the shredder's east face into the rotor well:
    the one enclosed leg of the route, drawn as a duct so the eye can follow
    it across the seam."""
    out = []
    out.append(box("gap-floor", (HULL_E, -0.90, DECK - 0.01),
                   (DECK_W + 0.02, 0.30, 0.19), mat="cavity"))
    a.run("greeble:pipe_run",
          [(HULL_E - 0.02, -0.66, 0.60), (0.02, -0.66, 0.60),
           (0.17, -0.22, 0.60)],
          radius=0.10, mat="steel", name="duct")
    return out


def ejector(a):
    """The trough, the pusher, the scanner and the port. Hero zone two.

    The trough runs north from the discharge chute at z 0.62..0.92 -- raised,
    so that in EAST, where the rotor stands between it and the camera, its top
    0.36 tiles still show above the cowl. Its floor is dark: a channel, with a
    bright ram head travelling along it. The ram is a hydraulic cylinder in
    the seam slot, driven off the old half; its head travels RAM_STROKE north
    and the chips go with it, off the trough's end and down into the throat.
    """
    x0, x1 = TROUGH_X
    y0, y1 = TROUGH_Y
    ry = ROTOR[1]
    out = []
    # the block the trough stands on, and the sweeping composite fairing that
    # closes its west side -- an arc in the X-Z plane swept along Y, with two
    # dark seam grooves round it
    out.append(box("trough-base", (-0.80, y0, DECK - 0.01), (x0 + 0.02, y1, 0.63),
                   mat="tempers", bevel=0.02))
    out.append(ring("trough-fairing", (x0 - 0.02, 0.5 * (y0 + y1), TROUGH_Z),
                    0.30, 0.255, y1 - y0, axis="Y", mat="compdark", a0=90.0,
                    a1=180.0, seg=36, bevel=0.0))
    for k, yy in enumerate((y0 + 0.28, y1 - 0.28)):
        out.append(ring("fairing-seam%d" % k, (x0 - 0.02, yy, TROUGH_Z), 0.306,
                        0.29, 0.02, axis="Y", mat="seamdark", a0=92.0, a1=178.0,
                        seg=36, cuts=0, bevel=0.0))
    out.append(box("trough-floor", (x0, y0, TROUGH_Z - 0.06), (x1, y1 + 0.02,
                                                              TROUGH_Z),
                   mat="cavity"))
    # the east wall is two spans: the discharge chute lands through it
    out.append(boxes("trough-wall",
                     [((x0 - 0.04, y0, TROUGH_Z - 0.06), (x0, y1 + 0.02, TROUGH_TOP)),
                      ((x1, y0, TROUGH_Z - 0.06), (x1 + 0.04, ry - 0.13, TROUGH_TOP)),
                      ((x1, ry + 0.13, TROUGH_Z - 0.06), (x1 + 0.04, y1 + 0.02, TROUGH_TOP))],
                     mat="steel"))
    # the pusher: cylinder in the slot, gland, rod, head
    out.append(cyl("ram-cyl", (RAM_X, -0.06, RAM_Z), 0.10, 0.76, axis="Y",
                   mat="polished", seg=20))
    out.append(ring("ram-gland", (RAM_X, 0.31, RAM_Z), 0.125, 0.05, 0.06,
                    axis="Y", mat="gunmetal", seg=20))
    out.append(cyl("ram-rear", (RAM_X, -0.43, RAM_Z), 0.115, 0.06, axis="Y",
                   mat="gunmetal", seg=20))
    out.append(boxes("ram-saddle",
                     [((RAM_X - 0.12, -0.38, 0.18), (RAM_X + 0.12, -0.24, 0.70)),
                      ((RAM_X - 0.12, 0.08, 0.18), (RAM_X + 0.12, 0.22, 0.70))],
                     mat="gunmetal"))
    a.place("greeble:bolt_ring", at=(RAM_X, -0.43), z=RAM_Z, size=0.17,
            mat="gunmetal", name="ram-bolts", count=6)
    out.append(cyl("ram-rod", (RAM_X, -0.04, RAM_Z), 0.045, 0.80, axis="Y",
                   mat="polished", seg=12))
    out.append(box("ram-head", (x0 + 0.005, y0 + 0.06, TROUGH_Z),
                   (x1 - 0.005, y0 + 0.14, TROUGH_TOP - 0.02), mat="scoured"))
    # the scanner: a bridge over the trough with an up-facing violet strip
    out.append(box("scan-bridge", (x0 - 0.06, 0.70, TROUGH_TOP),
                   (x1 + 0.06, 0.78, TROUGH_TOP + 0.08), mat="polished"))
    out.append(box("scan-lamp", (x0 + 0.03, 0.725, TROUGH_TOP + 0.08),
                   (x1 - 0.03, 0.755, TROUGH_TOP + 0.092), mat="violet2",
                   cuts=0, bevel=0.0))
    # THE PORT. A dark body on the pad, a pale riser at the back with the
    # trough feeding through, a hood falling away to the mouth -- and the
    # hood's west half OPEN: the throat, a dark well the chips drop into,
    # rimmed in violet, which is what every rotation sees from above.
    py0, py1 = PORT_Y
    w = PORT_W
    tx0, tx1, ty0, ty1 = THROAT
    # The mouth is a real recess in the body's north end, not a dark plate on
    # its face: two bright door plates over a flat face read as a steel chest
    # with a latch in the final review. The recess holds a violet strip that
    # shows only when the doors part -- an open-state cue in any frame.
    out.append(boxes("port-body",
                     [((tx1, py0, DECK - 0.01), (w, py1 - 0.12, TROUGH_Z - 0.02)),
                      ((-w, py0, DECK - 0.01), (tx1, py1 - 0.12, 0.40)),
                      ((-w, py1 - 0.14, DECK - 0.01), (-MOUTH_W - 0.02, py1 + 0.02, 0.48)),
                      ((MOUTH_W + 0.02, py1 - 0.14, DECK - 0.01), (w, py1 + 0.02, 0.48)),
                      ((-MOUTH_W - 0.02, py1 - 0.14, DECK - 0.01), (MOUTH_W + 0.02, py1 + 0.02, 0.14)),
                      ((-MOUTH_W - 0.02, py1 - 0.14, 0.44), (MOUTH_W + 0.02, py1 + 0.02, 0.48))],
                     mat="tempers", bevel=0.02))
    out.append(box("throat-floor", (tx0, ty0 - 0.06, 0.40), (tx1, ty1, 0.42),
                   mat="pitch", cuts=0, bevel=0.0))
    # the riser: back step (y 1.14..1.24) to 0.99 carrying the grade paint,
    # front step (1.24..1.32) to 0.92 on the east half only; the trough feeds
    # through an opening in the back step's west half
    out.append(boxes("port-riser",
                     [((-w, py0, TROUGH_TOP - 0.02), (w, py0 + 0.10, 0.99)),
                      ((x1 + 0.02, py0, TROUGH_Z - 0.04), (w, py0 + 0.10, TROUGH_TOP)),
                      ((tx1, py0 + 0.10, TROUGH_Z - 0.04), (w, py0 + 0.18, 0.92))],
                     mat="composite", bevel=0.015))
    out.append(yz_prism("port-roof",
                        [[(py0 + 0.17, 0.58), (py0 + 0.17, 0.92),
                          (py1 + 0.02, 0.52), (py1 + 0.02, 0.46)]],
                        tx1, w, mat="composite", bevel=0.015))
    out.append(yz_prism("port-roof-seam",
                        [[(1.44, 0.795), (1.44, 0.81), (1.47, 0.78), (1.47, 0.765)],
                         [(1.58, 0.65), (1.58, 0.665), (1.61, 0.635), (1.61, 0.62)]],
                        tx1 - 0.002, w + 0.002, mat="seamdark", cuts=0, bevel=0.0))
    # the throat's own walls: west, and north (which is the hood's west end)
    out.append(boxes("throat-wall",
                     [((tx0 - 0.04, py0 + 0.08, 0.40), (tx0, ty1 + 0.06, 0.66)),
                      ((tx0 - 0.04, ty1, 0.40), (tx1 + 0.02, ty1 + 0.06, 0.66))],
                     mat="composite", bevel=0.01))
    # the ejector lamp: violet along the throat's rim, pulsing with each batch
    out.append(boxes("eject-lamp",
                     [((tx0 - 0.03, ty1 + 0.02, 0.66), (tx1 + 0.01, ty1 + 0.05, 0.672)),
                      ((tx0 - 0.03, py0 + 0.10, 0.66), (tx0, ty1 + 0.05, 0.672))],
                     mat="violet3", cuts=0, bevel=0.0))
    _cone("throat rim", tx0 - 0.03, ty1 + 0.05, 0.672)
    out.append(box("port-mouth", (-MOUTH_W - 0.02, py1 - 0.14, 0.14),
                   (MOUTH_W + 0.02, py1 - 0.12, 0.44), mat="pitch"))
    out.append(box("mouth-glow", (-MOUTH_W + 0.04, py1 - 0.12, 0.22),
                   (MOUTH_W - 0.04, py1 - 0.10, 0.36), mat="violet3", cuts=0,
                   bevel=0.0))
    out.append(box("door-l", (-MOUTH_W - 0.01, py1 + 0.006, 0.13),
                   (-0.004, py1 + 0.034, 0.45), mat="gunmetal", bevel=0.005))
    out.append(box("door-r", (0.004, py1 + 0.006, 0.13),
                   (MOUTH_W + 0.01, py1 + 0.034, 0.45), mat="gunmetal",
                   bevel=0.005))
    # hazard on the OUTPUT end, where the review found the intake's chevrons
    # were the only ones that read: a plate on each pocket lid (up-facing, so
    # every rotation sees it) beside the sill's own. An eave band over the
    # mouth was tried and sat over the cone at the footprint's far edge.
    for sx in (-1.0, 1.0):
        x0 = sx * (w + 0.03) if sx < 0 else sx * (w + 0.03)
        lo, hi = (x0 - 0.18, x0) if sx < 0 else (x0, x0 + 0.18)
        out.append(prism("pocket-chev-back%d" % (sx > 0),
                         [(lo, py1 - 0.06), (hi, py1 - 0.06), (hi, py1 + 0.02), (lo, py1 + 0.02)],
                         0.468, 0.474, mat="cavity", cuts=1, bevel=0.002))
        for j in range(2):
            xx = lo + 0.02 + j * 0.08
            out.append(prism("pocket-chev%d%d" % (sx > 0, j),
                             [(xx, py1 - 0.05), (xx + 0.035, py1 - 0.05),
                              (xx + 0.07, py1 + 0.01), (xx + 0.035, py1 + 0.01)],
                             0.472, 0.482, mat="hazard", cuts=0, bevel=0.002))
    out.append(boxes("port-pocket",
                     [((-w - 0.24, py1 - 0.08, 0.11), (-w, py1 + 0.04, 0.47)),
                      ((w, py1 - 0.08, 0.11), (w + 0.24, py1 + 0.04, 0.47))],
                     mat="compdark", bevel=0.01))
    out.append(boxes("pocket-seam",
                     [((-w - 0.245, py1 - 0.02, 0.13), (-w + 0.005, py1 - 0.005, 0.45)),
                      ((w - 0.005, py1 - 0.02, 0.13), (w + 0.245, py1 - 0.005, 0.45))],
                     mat="seamdark", cuts=0, bevel=0.0))
    # the sill, with hazard chevrons painted on it: chevrons in, chevrons out.
    # A bridge plate on two short legs with daylight under it, flanked by a
    # guide post at each pocket corner: in SOUTH the port faces the camera as
    # one compact block and the silhouette's raggedness fell to 0.93 against
    # the 0.95 floor -- raggedness is bought with holes, not with parts.
    out.append(box("port-sill", (-SILL[0], SILL[1], 0.09), (SILL[0], SILL[2], 0.13),
                   mat="scoured"))
    out.append(boxes("port-sill-legs",
                     [((-0.20, SILL[1] + 0.02, 0.0), (-0.15, SILL[2] - 0.02, 0.10)),
                      ((0.15, SILL[1] + 0.02, 0.0), (0.20, SILL[2] - 0.02, 0.10))],
                     mat="gunmetal"))
    out.append(prism("sill-chev-back", [(-0.18, SILL[1] + 0.02), (0.18, SILL[1] + 0.02),
                                        (0.18, SILL[2] - 0.02), (-0.18, SILL[2] - 0.02)],
                     0.128, 0.134, mat="cavity", cuts=1, bevel=0.003))
    for j in range(3):
        x = -0.16 + j * 0.115
        out.append(prism("sill-chev%d" % j,
                         [(x, SILL[1] + 0.03), (x + 0.05, SILL[1] + 0.03),
                          (x + 0.105, SILL[2] - 0.03), (x + 0.055, SILL[2] - 0.03)],
                         0.132, 0.142, mat="hazard", cuts=0, bevel=0.003))
    out.append(boxes("port-bollard",
                     [((-w - 0.22, py1 + 0.04, 0.10), (-w - 0.16, py1 + 0.10, 0.40)),
                      ((w + 0.16, py1 + 0.04, 0.10), (w + 0.22, py1 + 0.10, 0.40))],
                     mat="polished", bevel=0.006))
    out.append(boxes("port-bollard-cap",
                     [((-w - 0.23, py1 + 0.03, 0.40), (-w - 0.15, py1 + 0.11, 0.43)),
                      ((w + 0.15, py1 + 0.03, 0.40), (w + 0.23, py1 + 0.11, 0.43))],
                     mat="hazard", cuts=0, bevel=0.003))
    a.run("greeble:skid_feet", [(-0.34, 1.60, 0.06), (0.34, 1.60, 0.06)],
          mat="gunmetal", name="port-feet")
    # the grade scale, as PAINT on the riser's top face: five squares on a
    # dark plate, up-facing so every rotation sees them
    out.append(box("grade-plate", (-0.40, py0 + 0.012, 0.99),
                   (0.40, py0 + 0.088, 0.996), mat="seamdark", cuts=0,
                   bevel=0.0))
    for i in range(5):
        x = -0.35 + i * 0.16
        out.append(box("grade-paint%d" % i, (x, py0 + 0.02, 0.995),
                       (x + 0.11, py0 + 0.08, 1.003), mat="paintq%d" % i,
                       cuts=0, bevel=0.002))
    # THE HYDRAULIC POWER UNIT that drives the ram, in the south-east corner
    # the review found bare: a tank on Z (a circle in every rotation), a
    # motor block, and a pressure hose to the cylinder's rear.
    out.append(cyl("hpu-tank", (0.94, -1.08, 0.31), 0.15, 0.38, mat="tempers",
                   seg=24))
    out.append(torus("hpu-band", (0.94, -1.08, 0.24), 0.155, 0.018, mat="gunmetal",
                     seg=24, mseg=8))
    out.append(cyl("hpu-cap", (0.94, -1.08, 0.51), 0.10, 0.04, mat="polished",
                   seg=20))
    out.append(box("hpu-motor", (0.56, -1.20, DECK - 0.01), (0.78, -0.96, 0.36),
                   mat="gunmetal", bevel=0.01))
    out.append(cyl("hpu-shaft", (0.78, -1.08, 0.24), 0.05, 0.06, axis="X",
                   mat="polished", seg=12))
    a.run("greeble:pipe_run", [(0.94, -1.08, 0.53), (0.30, -1.02, 0.42),
                               (-0.22, -0.84, 0.52), (RAM_X, -0.54, 0.70)],
          radius=0.03, flanges=False, mat="hose", name="hpu-hose")
    a.place("greeble:flange", at=(0.94, -1.08), z=0.53, size=0.12,
            mat="copper", name="hpu-fit")
    _cone("hpu", 1.09, -1.23, 0.55)
    _cone("riser back", w, py0 + 0.10, 1.003)
    _cone("roof mouth end", w, py1 + 0.02, 0.52)
    _cone("pocket", w + 0.24, py1 + 0.04, 0.47)
    return out


# ---- 4. the salvaged olive half -------------------------------------------


def shredder(a):
    """The vanilla lineage: olive, hazard chevrons, the maw with its rollers
    -- retrofitted. A composite feed collar frames the maw, armour plates are
    bolted to two walls, and the old stack moved onto the crown."""
    out = []
    x0, x1, z0, z1 = MAW
    # THE SKIRT IN THREE SPANS, cut back from the maw so the collar has room
    out.append(boxes("shred-skirt",
                     [((-1.30, -1.38, DECK), (x0 - 0.14, 0.14, 0.50)),
                      ((x1 + 0.14, -1.38, DECK), (SHRED_E, 0.14, 0.50)),
                      ((-1.30, -1.02, DECK), (SHRED_E, 0.14, 0.50))],
                     mat="olived"))
    # THE HULL IS BUILT AROUND THE MAW, not through it (five spans)
    mx0, mx1 = x0 - 0.06, x1 + 0.06
    mz0, mz1 = z0 - 0.04, z1 + 0.05
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
    # the intake hood: this half's one curved primary, kept from v2
    out.append(rb.hood("shred-hood", -0.96, -0.60, (-0.60, 1.08), 0.20,
                       mat="olive", thick=0.050, a0=-7.0, a1=187.0))
    for i, x in enumerate((-0.94, -0.62)):
        out.append(ring("shred-hood-rib%d" % i, (x, -0.60, 1.08), 0.225, 0.175,
                        0.045, axis="X", mat="steel", a0=-7.0, a1=187.0))
    out.append(box("shred-hood-hatch", (-0.90, -0.74, 1.24), (-0.66, -0.46, 1.30),
                   mat="gunmetal"))
    a.place("greeble:handwheel", at=(-0.78, -0.60), z=1.30, size=0.12,
            mat="copper", name="shred-hood-wheel")
    # THE STACK, on the crown where v2 had the fan. The old machine had a
    # chimney; the retrofit kept it.
    out.append(cyl("stack", (-0.64, -0.22, 1.26), 0.09, 0.36, mat="gunmetal",
                   seg=16))
    out.append(ring("stack-cowl", (-0.64, -0.22, 1.42), 0.13, 0.09, 0.08,
                    mat="scoured", seg=16))
    out.append(torus("stack-band", (-0.64, -0.22, 1.16), 0.105, 0.022,
                     mat="bronze", seg=16, mseg=8))
    _cone("stack cowl", -0.77, -0.22, 1.46)
    # THE MAW: back wall and floor, open air in front, three toothed rollers.
    # 0.56 tall so the top roller clears the lintel's 45-degree sight line.
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
    # THE FEED COLLAR: the retrofit, framing the maw in composite with a
    # rivet row and a seam groove down each side. Proud of the skirt.
    cw = 0.12
    out.append(boxes("feed-collar",
                     [((x0 - cw - 0.02, -1.40, DECK), (x0 - 0.02, -1.28, z1 + 0.12)),
                      ((x1 + 0.02, -1.40, DECK), (x1 + cw + 0.02, -1.28, z1 + 0.12)),
                      ((x0 - cw - 0.02, -1.40, z1 + 0.04), (x1 + cw + 0.02, -1.28, z1 + 0.12))],
                     mat="compdark", bevel=0.012))
    out.append(boxes("collar-seam",
                     [((x0 - cw - 0.02, -1.405, 0.46), (x0 - 0.02, -1.395, 0.48)),
                      ((x1 + 0.02, -1.405, 0.46), (x1 + cw + 0.02, -1.395, 0.48))],
                     mat="seamdark", cuts=0, bevel=0.0))
    a.run("greeble:rivet_row", (x0 - cw / 2 - 0.02, -1.405, 0.26),
          (x0 - cw / 2 - 0.02, -1.405, z1 + 0.08), count=5, mat="gunmetal",
          name="collar-rivets-w")
    a.run("greeble:rivet_row", (x1 + cw / 2 + 0.02, -1.405, 0.26),
          (x1 + cw / 2 + 0.02, -1.405, z1 + 0.08), count=5, mat="gunmetal",
          name="collar-rivets-e")
    # THE LOADING APRON, narrowed and moved west so its rows in the west view
    # stay clear of the sill's (see the module docstring). No rails.
    out.append(prism("apron", [(-1.18, -1.30), (-0.48, -1.30), (-0.58, -2.05),
                               (-1.08, -2.05)], 0.06, 0.20, mat="gunmetal",
                     cuts=1))
    out.append(prism("apron-track", [(-1.02, -1.32), (-0.64, -1.32),
                                     (-0.70, -1.98), (-0.96, -1.98)],
                     0.195, 0.215, mat="scoured", cuts=1))
    out.append(prism("apron-chev-back", [(-1.09, -2.00), (-0.65, -2.00),
                                         (-0.59, -1.78), (-1.03, -1.78)],
                     0.198, 0.206, mat="cavity", cuts=1, bevel=0.004))
    for j in range(4):
        x = -1.06 + j * 0.098
        out.append(prism("apron-chev%d" % j,
                         [(x, -1.98), (x + 0.046, -1.98),
                          (x + 0.098, -1.80), (x + 0.052, -1.80)],
                         0.204, 0.216, mat="hazard", cuts=0, bevel=0.004))
    a.run("greeble:skid_feet", [(-1.10, -1.96, 0.02), (-0.56, -1.96, 0.02)],
          mat="gunmetal", name="apron-feet")
    # THE FEEDER RAM: the apron's reason to exist
    out.append(box("flap-ram", (-0.98, -1.84, 0.19), (-0.68, -1.60, 0.33),
                   mat="gunmetal"))
    out.append(boxes("flap-ram-head",
                     [((-1.01, -1.63, 0.18), (-0.65, -1.56, 0.35))],
                     mat="scoured"))
    out.append(cyl("flap-ram-rod", (-0.83, -1.86, 0.24), 0.035, 0.18, axis="Y",
                   mat="steel", seg=10))
    # hazard chevrons on the south AND west walls
    out += wall_chevrons("shred-chev-s", "S", -1.16, -0.44, 0.86, 0.94, -1.26,
                         count=5)
    out += wall_chevrons("shred-chev-w", "W", -1.14, -0.22, 0.54, 0.80, -1.22,
                         count=6)
    # ARMOUR PLATES bolted on: a kick plate on the west skirt under the
    # chevrons, and a plate on the north wall (the front elevation in south)
    out.append(box("armour-w", (-1.34, -0.98, 0.14), (-1.29, -0.36, 0.50),
                   mat="compdark", bevel=0.01))
    a.run("greeble:rivet_row", (-1.345, -0.94, 0.44), (-1.345, -0.40, 0.44),
          count=5, mat="gunmetal", name="armour-w-rivets")
    out.append(box("armour-n", (-1.10, 0.05, 0.28), (-0.58, 0.12, 0.82),
                   mat="compdark", bevel=0.01))
    out.append(box("armour-n-seam", (-1.08, 0.12, 0.54), (-0.60, 0.125, 0.56),
                   mat="seamdark", cuts=0, bevel=0.0))
    a.run("greeble:rivet_row", (-1.06, 0.125, 0.76), (-0.62, 0.125, 0.76),
          count=5, mat="gunmetal", name="armour-n-rivets")
    return out


# ---- 5. power in: the west cabinet ----------------------------------------


def cabinet(a):
    """A low switch cabinet hanging past the west edge: the machine's power
    inlet, and the sprite's west extreme -- its rows are disjoint from the
    rotor's in north and south (see the module docstring)."""
    out = []
    out.append(box("cabinet", (-1.86, -1.06, 0.08), (-1.26, -0.72, 0.36),
                   mat="compdark", bevel=0.012))
    out.append(box("cabinet-seam", (-1.865, -0.895, 0.10), (-1.255, -0.875, 0.34),
                   mat="seamdark", cuts=0, bevel=0.0))
    for i, x in enumerate((-1.70, -1.50)):
        out.append(cyl("cabinet-ins%d" % i, (x, -0.82, 0.44), 0.035, 0.16,
                       mat="copper", seg=10))
        out.append(torus("cabinet-ins%d-ring" % i, (x, -0.82, 0.40), 0.045,
                         0.014, mat="gunmetal", seg=10, mseg=6))
    a.run("greeble:pipe_run", [(-1.50, -0.82, 0.52), (-1.36, -0.82, 0.58),
                               (-1.26, -0.82, 0.58)],
          radius=0.025, mat="steel", name="cabinet-conduit")
    # feet at the cabinet's south end only: a foot at y -0.78 sat within 0.06
    # of the west extreme and its rows collided with the cowl's in south
    a.run("greeble:skid_feet", [(-1.76, -1.00, 0.0), (-1.62, -0.86, 0.0)],
          mat="gunmetal", name="cabinet-feet")
    _cone("cabinet insulator", -1.70, -0.82, 0.52)
    return out


# ---- 6. structure and service ---------------------------------------------


def structure(a):
    out = []
    out.append(boxes("shred-stile-s",
                     [((-1.24, -1.29, 0.50), (-1.18, -1.26, 0.98)),
                      ((-0.50, -1.29, 0.50), (-0.44, -1.26, 0.98))],
                     mat="steel"))
    out.append(boxes("shred-stile-w",
                     [((-1.25, -1.20, 0.14), (-1.22, -1.08, 0.96)),
                      ((-1.25, -0.12, 0.14), (-1.22, 0.00, 0.96))],
                     mat="steel"))
    a.run("greeble:rivet_row", (-1.20, 0.09, 0.90), (-0.46, 0.09, 0.90),
          mat="steel", name="shred-rivets-n")
    a.run("greeble:skid_feet", [(-1.18, -1.32, 0.0), (-0.50, -1.32, 0.0),
                                (-1.18, 0.08, 0.0), (-0.50, 0.08, 0.0)],
          mat="gunmetal", name="shred-feet")
    a.run("greeble:ladder", (-1.20, -0.24, DECK), 0.86, mat="steel",
          name="shred-ladder")
    # the seam strap up the hull's east face: the join, made visible
    out.append(boxes("seam-strap",
                     [((HULL_E - 0.02, -1.10, 0.22), (HULL_E + 0.05, -0.94, 0.94)),
                      ((HULL_E - 0.02, -1.12, 0.86), (HULL_E + 0.05, -0.12, 0.94))],
                     mat="scoured"))
    a.run("greeble:rivet_row", (HULL_E + 0.045, -1.06, 0.60),
          (HULL_E + 0.045, -0.50, 0.60), count=5, mat="gunmetal",
          name="seam-rivets")
    # status lamp: green, the only thing lit when the machine is idle
    out.append(cyl("lamp", (-0.62, -0.96, 1.16), 0.058, 0.05, mat="led",
                   seg=12))
    out.append(ring("lamp-hood", (-0.62, -0.96, 1.150), 0.090, 0.058, 0.09,
                    mat="scoured", seg=12))
    out.append(cyl("lamp-stem", (-0.62, -0.96, 1.10), 0.030, 0.09,
                   mat="gunmetal", seg=8))
    return out


# ---- 7. the fragments -----------------------------------------------------


def fragments():
    """Three chips of neutral scrap. They sit in the trough, ride the ram to
    its end, drop into the throat, come out of the mouth, and are thrown back
    down the discharge chute by the rotor. The only things whose silhouette
    travels, so they live in their own overlay and never in the shadow pass."""
    out = []
    for i in range(3):
        out.append(box("frag%d" % i, (-0.065, -0.05, -0.045),
                       (0.065, 0.05, 0.045), mat="scoured", cuts=0,
                       bevel=0.014))
    return out


# ---- assembly -------------------------------------------------------------


def build(mats):
    rb.extra_materials()
    v3_materials()
    # build_materials() returns a COPY of its dict; the Assembly looks parts'
    # materials up in what it was handed, so it has to see the v3 additions
    mats.update(gen._MATS)
    a = parts.Assembly(PREFIX, mats)
    a.purge()
    for obj in [o for o in bpy.data.objects if o.name.startswith(PREFIX)]:
        bpy.data.objects.remove(obj, do_unlink=True)
    for c in [c for c in bpy.data.collections if c.name in gen.COLL_NAMES]:
        bpy.data.collections.remove(c)

    made = [pad()]
    made += plinth(a)
    made += rotor(a)
    made += looms(a)
    made += transfer(a)
    made += ejector(a)
    made += shredder(a)
    made += cabinet(a)
    made += structure(a)
    made += fragments()
    a.placed.extend([o for o in made if o])
    gen.organise()
    return a
