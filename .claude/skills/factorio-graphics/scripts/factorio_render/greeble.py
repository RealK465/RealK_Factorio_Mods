"""The vanilla parts vocabulary, as bmesh builders.

`references/design-language.md` lists what a Factorio machine is made of --
flanged pipe joints, sagging cables, louvres, finned radiators, riveted bands,
handwheel valves, gauge pods, ladders, railings, hazard chevrons, skid feet --
and says to aim for **8-15 distinct kinds** on a production machine. An agent
building from primitives will not reach that by inventing each part twice; it
reaches it by having them.

Import inside Blender only (`bpy`).

Four rules every builder here follows, each of them a bug that cost a render:

* **Everything is bevelled.** The wear stack in `materials.md` reads mesh
  curvature through Geometry > Pointiness. This used to say an unbevelled
  primitive makes the mask find *nothing*; it is the opposite, and the
  correction matters. Pointiness is per-vertex and interpolated across faces,
  so a cube -- 8 vertices, all convex corners -- floods every face and the
  mask marks the whole box. Measured: bare cube 48.6% of the silhouette
  "worn", the same cube with one subdivision 1.8%. A bevel gives the mask a
  crease to sit on; interior vertices are what stop it covering the face.
  `gates.wear_mask()` checks it.
* **Nothing is exactly coplanar.** Two shells sharing an exactly coplanar face
  render OPAQUE BLACK in Cycles -- measured at 64% black over the part, fixed
  by dropping one by 0.004. Builders that stack plates offset them by `EPS`.
* **Bounds are normalised inside the builder.** Writing a symmetric part as
  `rect(u0, u1, sgn*inner, sgn*outer)` runs the polygon backwards for
  `sgn = -1` and inverts every normal on that side.
  `bmesh.ops.recalc_face_normals` is not the escape hatch -- it flips faces on
  the intersecting closed shells a machine built from overlapping boxes is.
* **Detail sits where the camera looks.** At a 45-degree pitch only the top
  deck and the front (-Y) wall are visible; side walls render as a one-pixel
  line. `legibility()` will tell you when a part is too small to be geometry
  at all -- under ~3 px it is texture, and modelling it is wasted work that
  still costs render time.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

EPS = 0.004          # the anti-coplanar offset, in tiles
PX_PER_TILE = 64


# --- infrastructure ------------------------------------------------------

class Kit:
    """A namespace for one subject's parts.

    Everything created carries the prefix so a generator can be idempotent:
    `kit.purge()` removes exactly its own objects and nothing else.
    """

    def __init__(self, prefix, collection=None, bevel=0.006, bevel_segments=2):
        self.prefix = prefix
        self.bevel = bevel
        self.bevel_segments = bevel_segments
        self.collection = collection or bpy.context.scene.collection

    def purge(self):
        for obj in [o for o in bpy.data.objects if o.name.startswith(self.prefix)]:
            bpy.data.objects.remove(obj, do_unlink=True)

    def _emit(self, bm, name, material=None, location=(0, 0, 0),
              rotation=(0, 0, 0), bevel=None):
        mesh = bpy.data.meshes.new(self.prefix + name)
        width = self.bevel if bevel is None else bevel
        if width > 0:
            bmesh.ops.bevel(bm, geom=list(bm.verts) + list(bm.edges),
                            offset=width, segments=self.bevel_segments,
                            profile=0.5, affect="EDGES", clamp_overlap=True)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(self.prefix + name, mesh)
        obj.location = location
        obj.rotation_euler = rotation
        if material:
            obj.data.materials.append(material)
        self.collection.objects.link(obj)
        return obj


def _box(bm, lo, hi):
    """Axis-aligned box from two corners, bounds normalised.

    The normalisation is the point: a caller writing `sgn * inner, sgn * outer`
    for a mirrored part hands this reversed bounds half the time, and building
    the polygon from reversed bounds inverts its normals.
    """
    x0, x1 = sorted((lo[0], hi[0]))
    y0, y1 = sorted((lo[1], hi[1]))
    z0, z1 = sorted((lo[2], hi[2]))
    verts = [bm.verts.new(v) for v in (
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1),
              (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new([verts[i] for i in f])
    return verts


def _cyl(bm, center, radius, height, segments=16, axis="Z"):
    res = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=segments,
        radius1=radius, radius2=radius, depth=height)
    verts = res["verts"]
    if axis != "Z":
        angle = math.radians(90)
        bmesh.ops.rotate(bm, verts=verts, cent=(0, 0, 0),
                         matrix=Matrix.Rotation(angle, 3, "Y" if axis == "X" else "X"))
    bmesh.ops.translate(bm, verts=verts, vec=Vector(center))
    return verts


def legibility(size_tiles, px_per_tile=PX_PER_TILE, zoom=0.5):
    """What a feature of this size will actually be, in pixels.

    `zoom` 0.5 is normal gameplay (a sprite declared at scale 0.5). Measured on
    the beacon's front lip over three passes: below ~3 px a feature is a smudge
    whatever it is, and what survives is silhouette and value -- a raised plate
    with a lit top chamfer and a shadow line under it, not etched line-work.
    """
    src = size_tiles * px_per_tile
    game = src * zoom
    if game < 3:
        verdict = "TOO SMALL -- make this texture, not geometry"
    elif game < 8:
        verdict = "silhouette and value only -- no line-work, no text"
    else:
        verdict = "ok as geometry"
    return {"source_px": round(src, 1), "game_px": round(game, 1), "verdict": verdict}


# --- the vocabulary ------------------------------------------------------

def bolt_ring(kit, center, radius, count=8, head=0.018, height=0.012,
              material=None, name="bolts"):
    """A bolt circle round a lid or flange -- vanilla's most repeated detail.

    Modular repetition reads as engineered; five unique gadgets read as noise.
    Heads are hexagonal because a cylinder at 3 px reads as a dot.
    """
    bm = bmesh.new()
    for i in range(count):
        a = 2 * math.pi * i / count
        p = (center[0] + radius * math.cos(a), center[1] + radius * math.sin(a), center[2])
        _cyl(bm, p, head, height, segments=6)
    return kit._emit(bm, name, material, bevel=head * 0.18)


def rivet_row(kit, start, end, count=8, head=0.014, height=0.008,
              material=None, name="rivets"):
    """A line of rivets along a panel edge. Panels read as assembled plates."""
    bm = bmesh.new()
    a, b = Vector(start), Vector(end)
    for i in range(count):
        t = (i + 0.5) / count
        _cyl(bm, a.lerp(b, t), head, height, segments=6)
    return kit._emit(bm, name, material, bevel=head * 0.18)


def flange(kit, center, radius, thickness=0.03, bolts=8, axis="Z",
           material=None, bolt_material=None, name="flange"):
    """A bolted collar. Every vanilla pipe joint has one.

    Where two parts are *meant* to touch, model the junction -- a uniform gap
    everywhere reads as floating props; a fitting reads as engineering.
    """
    bm = bmesh.new()
    _cyl(bm, center, radius, thickness, segments=20, axis=axis)
    disc = kit._emit(bm, name, material, bevel=thickness * 0.25)
    ring = None
    if bolts:
        up = {"Z": (0, 0, 1), "X": (1, 0, 0), "Y": (0, 1, 0)}[axis]
        c = tuple(center[i] + up[i] * (thickness / 2 + EPS) for i in range(3))
        ring = bolt_ring(kit, c, radius * 0.72, bolts,
                         material=bolt_material or material, name=name + "-bolts")
    return disc, ring


def pipe_run(kit, points, radius=0.05, segments=12, flanges=True,
             material=None, name="pipe"):
    """A pipe through a polyline, with a flange at every bend.

    No straight featureless cylinders: a bend without a fitting is the tell
    that a pipe was extruded rather than plumbed.
    """
    bm = bmesh.new()
    pts = [Vector(p) for p in points]
    for a, b in zip(pts, pts[1:]):
        d = b - a
        length = d.length
        if length < 1e-6:
            continue
        res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False,
                                    segments=segments, radius1=radius,
                                    radius2=radius, depth=length)
        quat = d.to_track_quat("Z", "Y")
        bmesh.ops.rotate(bm, verts=res["verts"], cent=(0, 0, 0),
                         matrix=quat.to_matrix())
        bmesh.ops.translate(bm, verts=res["verts"], vec=(a + b) / 2)
    body = kit._emit(bm, name, material, bevel=radius * 0.12)
    made = [body]
    if flanges:
        for i, p in enumerate(pts):
            disc, ring = flange(kit, tuple(p), radius * 1.65, radius * 0.5,
                                bolts=6, material=material,
                                name="%s-j%d" % (name, i))
            made += [disc, ring]
    return made


def cable(kit, start, end, sag=0.12, radius=0.016, segments=14,
          material=None, name="cable"):
    """A rubber cable with natural catenary sag.

    Vanilla's cheapest "alive" detail and one of the most reliable -- beacon,
    roboport and substation all lean on it. Straight cables read as wire props.
    """
    bm = bmesh.new()
    a, b = Vector(start), Vector(end)
    pts = []
    for i in range(segments + 1):
        t = i / segments
        p = a.lerp(b, t)
        p.z -= sag * math.sin(math.pi * t)      # a parabola is close enough at this size
        pts.append(p)
    for p, q in zip(pts, pts[1:]):
        d = q - p
        if d.length < 1e-6:
            continue
        res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6,
                                    radius1=radius, radius2=radius, depth=d.length)
        bmesh.ops.rotate(bm, verts=res["verts"], cent=(0, 0, 0),
                         matrix=d.to_track_quat("Z", "Y").to_matrix())
        bmesh.ops.translate(bm, verts=res["verts"], vec=(p + q) / 2)
    return kit._emit(bm, name, material, bevel=radius * 0.2)


def louvre_bank(kit, center, size, count=5, angle=32.0, thickness=0.012,
                material=None, name="louvres"):
    """Angled vent blades in a recess. The heat story, and it reads at 64 px
    because each blade catches the key light on its top edge."""
    bm = bmesh.new()
    w, h, d = size
    pitch = h / count
    a = math.radians(angle)
    for i in range(count):
        y = center[1] - h / 2 + pitch * (i + 0.5)
        blade = _box(bm, (center[0] - w / 2, y - pitch * 0.42, center[2] - d / 2),
                     (center[0] + w / 2, y + pitch * 0.42, center[2] + d / 2))
        bmesh.ops.rotate(bm, verts=blade, cent=(center[0], y, center[2]),
                         matrix=Matrix.Rotation(a, 3, "X"))
    return kit._emit(bm, name, material, bevel=thickness * 0.3)


def radiator(kit, center, size, fins=9, material=None, name="radiator"):
    """A finned block. Put soot near it -- the wear map is what makes a heat
    exit read as a heat exit rather than as a comb."""
    bm = bmesh.new()
    w, h, d = size
    _box(bm, (center[0] - w / 2, center[1] - h / 2, center[2] - d / 2),
         (center[0] + w / 2, center[1] + h / 2, center[2] - d / 2 + d * 0.25))
    pitch = w / fins
    for i in range(fins):
        x = center[0] - w / 2 + pitch * (i + 0.5)
        _box(bm, (x - pitch * 0.28, center[1] - h / 2, center[2] - d / 2 + d * 0.25 + EPS),
             (x + pitch * 0.28, center[1] + h / 2, center[2] + d / 2))
    return kit._emit(bm, name, material, bevel=min(pitch * 0.15, 0.006))


def handwheel(kit, center, radius=0.09, spokes=4, tube=0.014, axis="Z",
              material=None, name="handwheel"):
    """The red valve wheel at a pipe junction. The chemical plant carries
    three; one accent colour, used functionally."""
    bm = bmesh.new()
    ring = 24
    for i in range(ring):
        a0 = 2 * math.pi * i / ring
        a1 = 2 * math.pi * (i + 1) / ring
        p = Vector((center[0] + radius * math.cos(a0), center[1] + radius * math.sin(a0), center[2]))
        q = Vector((center[0] + radius * math.cos(a1), center[1] + radius * math.sin(a1), center[2]))
        d = q - p
        res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6,
                                    radius1=tube, radius2=tube, depth=d.length)
        bmesh.ops.rotate(bm, verts=res["verts"], cent=(0, 0, 0),
                         matrix=d.to_track_quat("Z", "Y").to_matrix())
        bmesh.ops.translate(bm, verts=res["verts"], vec=(p + q) / 2)
    for i in range(spokes):
        a = 2 * math.pi * i / spokes
        q = Vector((center[0] + radius * math.cos(a), center[1] + radius * math.sin(a), center[2]))
        c = Vector(center)
        d = q - c
        res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6,
                                    radius1=tube * 0.7, radius2=tube * 0.7, depth=d.length)
        bmesh.ops.rotate(bm, verts=res["verts"], cent=(0, 0, 0),
                         matrix=d.to_track_quat("Z", "Y").to_matrix())
        bmesh.ops.translate(bm, verts=res["verts"], vec=(c + q) / 2)
    _cyl(bm, center, tube * 1.6, tube * 3, segments=10, axis=axis)
    return kit._emit(bm, name, material, bevel=tube * 0.25)


def gauge_pod(kit, center, radius=0.055, depth=0.05, material=None,
              face_material=None, name="gauge"):
    """An instrument pod: a bezel standing proud, with a pale dial inside.

    Raised, not recessed. Measured on a front wall the rig lights with fill
    only: a recess reads as a dark opening however carefully it is framed,
    because no key light reaches into it; a plate standing proud catches the
    key on its top chamfer and reads as a panel.
    """
    bm = bmesh.new()
    _cyl(bm, center, radius, depth, segments=18, axis="Y")
    body = kit._emit(bm, name, material, bevel=radius * 0.16)
    bm = bmesh.new()
    _cyl(bm, (center[0], center[1] - depth / 2 - EPS, center[2]),
         radius * 0.72, 0.006, segments=18, axis="Y")
    face = kit._emit(bm, name + "-dial", face_material or material, bevel=0.001)
    return body, face


def junction_box(kit, center, size=(0.12, 0.09, 0.14), conduit=0.022,
                 material=None, name="junction"):
    """The standardised circuit-connector greeble, plus its conduit stub.
    Vanilla reuses one module on every connectible entity (FFF-210)."""
    bm = bmesh.new()
    w, d, h = size
    _box(bm, (center[0] - w / 2, center[1] - d / 2, center[2]),
         (center[0] + w / 2, center[1] + d / 2, center[2] + h))
    _box(bm, (center[0] - w * 0.34, center[1] - d / 2 - 0.012, center[2] + h * 0.25),
         (center[0] + w * 0.34, center[1] - d / 2 + EPS, center[2] + h * 0.75))
    _cyl(bm, (center[0], center[1], center[2] + h + conduit), conduit, conduit * 3,
         segments=10)
    return kit._emit(bm, name, material, bevel=0.005)


def ladder(kit, bottom, height, width=0.14, rungs=None, stile=0.012,
           material=None, name="ladder"):
    """The human-scale cue. A machine with a ladder is equipment; one without
    is a prop."""
    bm = bmesh.new()
    rungs = rungs or max(2, int(height / 0.11))
    for sx in (-1, 1):
        x = bottom[0] + sx * width / 2
        _box(bm, (x - stile, bottom[1] - stile, bottom[2]),
             (x + stile, bottom[1] + stile, bottom[2] + height))
    for i in range(rungs):
        z = bottom[2] + height * (i + 0.5) / rungs
        _box(bm, (bottom[0] - width / 2, bottom[1] - stile * 0.7, z - stile * 0.7),
             (bottom[0] + width / 2, bottom[1] + stile * 0.7, z + stile * 0.7))
    return kit._emit(bm, name, material, bevel=stile * 0.3)


def railing(kit, points, height=0.16, post=0.012, rail=0.010,
            material=None, name="railing"):
    """Posts and a top rail along a catwalk edge. Open-frame negative space is
    a vanilla signature no solid box has."""
    bm = bmesh.new()
    pts = [Vector(p) for p in points]
    for p in pts:
        _box(bm, (p.x - post, p.y - post, p.z), (p.x + post, p.y + post, p.z + height))
    for a, b in zip(pts, pts[1:]):
        top_a = Vector((a.x, a.y, a.z + height - rail))
        top_b = Vector((b.x, b.y, b.z + height - rail))
        d = top_b - top_a
        if d.length < 1e-6:
            continue
        res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6,
                                    radius1=rail, radius2=rail, depth=d.length)
        bmesh.ops.rotate(bm, verts=res["verts"], cent=(0, 0, 0),
                         matrix=d.to_track_quat("Z", "Y").to_matrix())
        bmesh.ops.translate(bm, verts=res["verts"], vec=(top_a + top_b) / 2)
    return kit._emit(bm, name, material, bevel=post * 0.3)


def skid_feet(kit, corners, size=(0.16, 0.16, 0.05), material=None, name="feet"):
    """The ground anchor. Vanilla anchors everything -- the elevated-rail ramp
    got a concrete base specifically to show where it touches the ground."""
    bm = bmesh.new()
    w, d, h = size
    for c in corners:
        _box(bm, (c[0] - w / 2, c[1] - d / 2, c[2]), (c[0] + w / 2, c[1] + d / 2, c[2] + h))
    return kit._emit(bm, name, material, bevel=0.006)


def placard(kit, center, size=(0.20, 0.10), thickness=0.012, material=None,
            name="placard"):
    """A raised stencil plate. Keep lettering for icons: text is finished below
    roughly 10 px of cap height, and this is 6 px in play."""
    bm = bmesh.new()
    w, h = size
    _box(bm, (center[0] - w / 2, center[1] - thickness, center[2] - h / 2),
         (center[0] + w / 2, center[1], center[2] + h / 2))
    return kit._emit(bm, name, material, bevel=thickness * 0.3)


def bolt_detailed(kit, center, radius=0.03, height=0.03, material=None,
                  name="bolt-hero"):
    """A real threaded bolt via the `boltfactory` extension, for a fitting big
    enough to show thread -- roughly 0.05 tiles and up, i.e. 3 px in play.

    Install it headlessly with
    `blender --command extension install boltfactory --enable`. Falls back to
    the flat hex head if it is not there, because 2736 verts of thread on a
    3 px feature is wasted geometry either way.

    Two traps, both hit here:

    * `rig.empty_scene()` calls `read_factory_settings`, which resets
      preferences and therefore **disables every installed extension**. A
      generator that starts from an empty scene loses the add-on it installed,
      so this re-enables it on demand.
    * `hasattr(bpy.ops.mesh, "bolt_add")` is **always True** -- `bpy.ops`
      resolves lazily and only raises when called. Test membership of `dir()`.
    """
    if "bolt_add" not in dir(bpy.ops.mesh):
        try:
            import addon_utils
            addon_utils.enable("bl_ext.blender_org.boltfactory", default_set=False)
        except Exception:
            pass
    if "bolt_add" not in dir(bpy.ops.mesh):
        return bolt_ring(kit, center, 0.0, count=1, head=radius, height=height,
                         material=material, name=name)
    bpy.ops.mesh.bolt_add(bf_Model_Type="bf_Model_Bolt", bf_Head_Type="bf_Head_Hex",
                          bf_Shank_Length=height, bf_Major_Dia=radius * 2)
    obj = bpy.context.object
    obj.name = kit.prefix + name
    obj.location = center
    if material:
        obj.data.materials.clear()
        obj.data.materials.append(material)
    for coll in list(obj.users_collection):
        coll.objects.unlink(obj)
    kit.collection.objects.link(obj)
    return obj


VOCABULARY = [
    "bolt_ring", "rivet_row", "flange", "pipe_run", "cable", "louvre_bank",
    "radiator", "handwheel", "gauge_pod", "junction_box", "ladder", "railing",
    "skid_feet", "placard", "bolt_detailed",
]
