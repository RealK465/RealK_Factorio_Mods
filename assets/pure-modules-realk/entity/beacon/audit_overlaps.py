# Reports mesh interpenetration between the beacon's static parts.
#
#   blender -b -P audit_overlaps.py -- [--clearance 0.06] [--top 40]
#
# Props that share volume read as one fused blob at sprite scale, so this
# checks every pair with a real triangle-level test (BVH overlap) rather than
# bounding boxes, which a curved hose would fail against half the deck.
#
# Two things are NOT violations and are filtered out:
#   - parts of the same prop (a tank and its own end caps, a pipe and its own
#     flanges) -- these are named <prop><suffix> by the builders
#   - deliberate contact listed in INTENTIONAL, where a junction piece already
#     sells the connection
# Everything else is reported worst-first, with the clearance check run
# separately so parts that merely touch are also caught.
import os
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

# (pattern, pattern) pairs whose contact is the point of the geometry
INTENTIONAL = [
    # deck plant: a spur is meant to meet both the feeder it leaves and the
    # device it feeds, and every run enters the pedestal wall through a gland
    # a service cable is MEANT to land on the device it feeds, and to leave
    # through a gland in the pedestal wall or the bus bar lug
    ("DeckFeed", "Holo"), ("DeckFeed", "Cryo"), ("DeckFeed", "Sensor"),
    ("DeckFeed", "Shard"), ("DeckFeed", "BusBar"), ("DeckFeed", "Grate"),
    ("Spur", "Holo"), ("Spur", "Cryo"), ("Spur", "Shard"), ("Spur", "Panel"),
    ("Spur", "Plinth"), ("Spur", "DeckRing"), ("DeckFeed", "Pedestal"),
    ("DeckFeed", "DeckRing"), ("DeckFeed", "Plinth"), ("DeckFeed", "Panel"),
    ("DeckFeed", "Corner"), ("Shard", "Panel"), ("Cryo", "Panel"),
    ("Cryo", "DeckRing"), ("Holo", "Panel"), ("Holo", "DeckRing"),
    ("Sensor", "Panel"), ("Shard", "DeckRing"), ("Sensor", "Plinth"),
    ("Greeble", "Panel"), ("Greeble", "DeckRing"), ("Greeble", "Plinth"),
    ("Riv", "Panel"), ("Riv", "Rim"), ("Riv", "Plinth"),
    ("Seam", "DeckRing"), ("Mark", "Panel"), ("Label", "Rim"),
    ("Panel", "Plinth"), ("Panel", "DeckRing"), ("DeckRing", "Plinth"),
    ("Bolt", "Hatch"), ("Bolt", "Plinth"), ("Bolt", "Panel"),
    ("Socket", "Plinth"), ("Hazard", "Rim"), ("Corner", "Plinth"),
    ("Pylon", "Corner"), ("Rim", "Plinth"), ("Deckplate", "Plinth"),
    ("Grate", "Panel"), ("Grate", "Plinth"), ("Strip", "Panel"),
    ("Dish", "Pedestal"), ("Collar", "Pedestal"), ("Cav", "Socket"),
    ("Corner", "Rim"), ("Grate", "DeckRing"), ("Strut", "DeckRing"),
    ("Rim", "Rim"), ("Manifold", "ChamberHose"), ("Manifold", "PipeManPed"),
    ("DishClamp", "DishCollar"), ("ChamberGland", "Pedestal"),
    ("ChamberHose", "ChamberGland"), ("Cap", "PowerCable"),
    ("HoseBack", "SiloBR"), ("ChamberHose", "CoolPump"),
    ("ChamberGland", "CoolPump"), ("ChamberGland", "CoolPipe"),
    ("CoolPipe", "Radiator"), ("Corner", "Panel"), ("Cable", "Pedestal"),
    ("CoolHose", "FloorPort"), ("ChamberHose", "Dish"), ("ChamberGland", "Dish"),
    ("Manifold", "DeckRing"), ("Silo", "DeckRing"), ("Tank", "DeckRing"),
    ("Pedestal", "Plinth"), ("FloorPort", "Panel"), ("ChamberHose", "Pedestal"),
    ("ChamberGland", "Manifold"), ("ChamberGland", "CanSkid"),
    ("Panel", "Pedestal"), ("HoseBack", "Corner"), ("HoseBack", "CornerCap"),
    ("PipeCanDish", "Can"), ("PipeCanDish", "Dish"), ("PipeSiloDown", "Silo"),
    ("Silo", "Panel"), ("Radiator", "Panel"), ("Can", "Panel"),
    ("Strut", "Panel"), ("Tray", "Panel"), ("Inspect", "Panel"),
    ("HeatPipe", "Panel"), ("Saddle", "Panel"), ("Foot", "DeckRing"),
    ("Stencil", "Panel"), ("Console", "Panel"), ("Cap", "Panel"),
    ("Can", "CanSkid"), ("Busbar", "Cap"), ("Fin", "Transformer"),
    # 2026-08-06 layout pass: seated indicators, bus bar, rear/flank ties
    ("RimLamp", "Rim"), ("RimGauge", "Rim"), ("DishLed", "Pedestal"),
    ("BusBar", "DeckRing"), ("BusBar", "Pedestal"), ("BusBar", "Transformer"),
    ("BusBar", "Panel"), ("BusBar", "Plinth"),
    ("PipeTankMan", "Manifold"), ("PipeTankMan", "Tank"),
    ("HoseTB", "TankBack"), ("HoseTB", "SiloBR"),
    ("Sump", "Plinth"), ("WinchBox", "Plinth"), ("WinchHose", "CanSkid"),
    ("WinchHose", "CanRes"),
    ("PipeRimL", "Plinth"), ("PipeRimL", "WinchBox"),
    ("FuelBay", "Panel"), ("ChamberHose", "CanRes"), ("ChamberGland", "CanRes"),
    ("Console", "FuelBay"),
]


def family(name):
    return name[3:] if name.startswith("PB_") else name


def same_prop(a, b):
    # Sub-parts are named <prop><Suffix><n> by the builders, so a shared
    # prefix that ends on a word boundary in BOTH names means one assembly:
    # TankRCap1/TankRStrap1 share "TankR" and split at C/S -> same tank.
    # PylonCable3/PylonCoil3 share "PylonC" but split mid-word -> two props.
    a, b = family(a), family(b)
    n = 0
    while n < min(len(a), len(b)) and a[n] == b[n]:
        n += 1
    if n < 4:
        return False
    return all(len(s) == n or s[n].isupper() or s[n].isdigit() for s in (a, b))


def intentional(a, b):
    a, b = family(a), family(b)
    for pa, pb in INTENTIONAL:
        if (a.startswith(pa) and b.startswith(pb)) or (a.startswith(pb) and b.startswith(pa)):
            return True
    return False


def world_bvh(obj, deps):
    # BVHTree.FromObject builds in the object's LOCAL space, so every
    # primitive centred on its own origin overlaps every other one and the
    # report is noise. Feed world-space polygons instead.
    ev = obj.evaluated_get(deps)
    try:
        mesh = ev.to_mesh()
    except RuntimeError:
        return None
    if mesh is None or not mesh.polygons:
        ev.to_mesh_clear()
        return None
    mw = obj.matrix_world
    verts = [mw @ v.co for v in mesh.vertices]
    polys = [tuple(poly.vertices) for poly in mesh.polygons]
    tree = BVHTree.FromPolygons(verts, polys, all_triangles=False, epsilon=0.0)
    ev.to_mesh_clear()
    return tree


def world_bbox(obj):
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    xs = [c.x for c in corners]
    ys = [c.y for c in corners]
    zs = [c.z for c in corners]
    return (min(xs), min(ys), min(zs), max(xs), max(ys), max(zs))


def boxes_apart(a, b, gap):
    return (a[3] + gap < b[0] or b[3] + gap < a[0] or
            a[4] + gap < b[1] or b[4] + gap < a[1] or
            a[5] + gap < b[2] or b[5] + gap < a[2])


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    clearance = float(argv[argv.index("--clearance") + 1]) if "--clearance" in argv else 0.06
    top = int(argv[argv.index("--top") + 1]) if "--top" in argv else 40

    bpy.ops.wm.read_factory_settings(use_empty=True)
    import beacon_gen
    beacon_gen.build_scene()
    deps = bpy.context.evaluated_depsgraph_get()

    base = bpy.data.collections["PB_Base"]
    objs = [o for o in base.objects if o.type in ("MESH", "CURVE")]
    trees, boxes = {}, {}
    for o in objs:
        tree = world_bvh(o, deps)
        if tree is None:
            continue
        trees[o.name] = tree
        boxes[o.name] = world_bbox(o)

    hits, near = [], []
    names = sorted(trees)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            if same_prop(a, b) or intentional(a, b):
                continue
            if boxes_apart(boxes[a], boxes[b], clearance):
                continue
            pairs = trees[a].overlap(trees[b])
            if pairs:
                hits.append((len(pairs), a, b))
            else:
                near.append((a, b))

    print("\n=== INTERPENETRATION (%d pairs) ===" % len(hits))
    for n, a, b in sorted(hits, reverse=True)[:top]:
        print("  %5d tris  %-26s %s" % (n, family(a), family(b)))
    print("\n=== CLOSER THAN %.3f BUT NOT OVERLAPPING (%d pairs) ===" % (clearance, len(near)))
    for a, b in near[:top]:
        print("  %-26s %s" % (family(a), family(b)))

    # nothing may drop below the deck slab or push through the front lip
    under, through = [], []
    for name, (x0, y0, z0, x1, y1, z1) in boxes.items():
        if z0 < -0.01:
            under.append((family(name), round(z0, 3)))
        if y0 < -2.40 and not family(name).startswith(("RimGauge", "RimLamp", "Label", "Lip")):
            through.append((family(name), round(y0, 3)))
    print("\n=== BELOW THE SLAB === %s" % (under or "none"))
    print("=== PAST THE FRONT LIP === %s" % (through or "none"))
    print("\nTOTAL PARTS AUDITED: %d" % len(trees))


main()
