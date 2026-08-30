"""Placing parts, so a machine is a parts list instead of four thousand lines.

The ceiling on how complex a Factorio sprite gets in this repo has never been
the renderer, the materials or the gates -- it is that every part costs ~50
lines of Python. `pure-modules-realk`'s beacon is 4,054 lines for one entity,
so "add a fan housing" is an afternoon and `design-language.md`'s "8-15
distinct kinds of functional detail" is aspirational rather than routine.

This module makes adding a part one line. Two sources, one call:

    a = parts.Assembly("PB_", mats)
    a.place("greeble:radiator",                 at=(-0.9, -1.2), size=0.6,  mat="iron")
    a.place("polyhaven:exterior_aircon_unit",   at=( 1.05,-0.75), size=1.1, mat="gunmetal")
    a.scatter(["greeble:gauge_pod", "greeble:bolt_ring"], area=(-1.2, -0.9, 1.2, 0.4),
              z=0.78, n=14, mat="iron", seed=17)

`greeble:*` is the vanilla vocabulary in `greeble.py`, already bevelled and
normal-correct. `polyhaven:*` is a CC0 model, fetched and cached on first use.

**The import recipe is applied for you, and it is not optional.** Measured
2026-08-30, same mask and rig: an imported mesh dropped in raw marks 21.8% of
the silhouette as worn edge, with a bevel 3.0%; a fused mesh loses per-object
colour jitter entirely (sd 0.185 -> 0.002) and gets it back only when split
into loose parts. So `place()` bevels, splits, and re-origins every import.
Skip it and the material stack in `materials.md` quietly stops working --
`gates.wear_mask()` is what catches that.

One thing this module deliberately does not do: decide where parts go.
Four kitbash iterations on 2026-08-30 produced props on a slab, then a scrap
pile, then plumbing hidden behind the mass -- every failure a composition
failure, none of them fixed by better parts. Composition is
`factorio-entity-design`'s job and it happens before this module is imported.
"""

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

from . import greeble


# --- the greeble registry ------------------------------------------------
#
# The builders in greeble.py have honest, part-specific signatures -- radius
# for a handwheel, (w, d) for a louvre bank, points for a cable. A uniform
# place() therefore needs to know which argument `size` means for each one,
# rather than pretending they are the same shape.

# `size` is one number -- the part's dominant dimension in tiles -- and each
# builder wants it in its own shape. The tuple ORDER differs per builder and
# is not guessable: louvre_bank and radiator take (w, h, d), junction_box takes
# (w, d, h), placard takes (w, h). Read from greeble.py, not assumed.
#   name            builder               size shape       proportions
GREEBLE = {
    "bolt_ring":    (greeble.bolt_ring,    "radius",       None),
    "flange":       (greeble.flange,       "radius",       None),
    "louvre_bank":  (greeble.louvre_bank,  "size",         (1.0, 0.70, 0.22)),
    "radiator":     (greeble.radiator,     "size",         (1.0, 0.80, 0.30)),
    "handwheel":    (greeble.handwheel,    "radius",       None),
    "gauge_pod":    (greeble.gauge_pod,    "radius",       None),
    "junction_box": (greeble.junction_box, "size",         (1.0, 0.75, 1.15)),
    "placard":      (greeble.placard,      "size",         (1.0, 0.50)),
    "bolt":         (greeble.bolt_detailed, "radius",      None),
}

# Parts defined by a PATH rather than a centre, so they take run() instead of
# place(). Splitting the two verbs is deliberate: a cable and a gauge pod are
# not the same kind of thing, and pretending they are is how a uniform API
# ends up lying about its arguments.
#   name          builder            path argument(s)
RUNS = {
    "rivet_row":  (greeble.rivet_row,  ("start", "end")),
    "cable":      (greeble.cable,      ("start", "end")),
    "pipe_run":   (greeble.pipe_run,   ("points",)),
    "railing":    (greeble.railing,    ("points",)),
    "skid_feet":  (greeble.skid_feet,  ("corners",)),
    "ladder":     (greeble.ladder,     ("bottom", "height")),
}

# Parts that are worth scattering: small, repeatable, and functional. Vanilla
# reads as engineered because the SAME bolt or vent recurs at plausible
# intervals -- design-language.md, "modular repetition reads as engineered;
# one-offs read as noise".
SCATTERABLE = ["greeble:gauge_pod", "greeble:bolt_ring", "greeble:placard",
               "greeble:junction_box", "greeble:bolt"]


def catalogue():
    """What the two verbs accept. Print it rather than guessing a name."""
    return {
        "place": ["greeble:" + k for k in sorted(GREEBLE)]
                 + ["polyhaven:<slug>  (any CC0 model; `polyhaven.py search"
                    " models --categories industrial`)"],
        "run": ["greeble:" + k for k in sorted(RUNS)],
    }


class Assembly:
    """One machine's parts, sharing a prefix, a collection and a palette.

    `materials` is the dict a generator's build_materials() returns, so `mat=`
    takes the same keys the rest of the generator already uses.
    """

    def __init__(self, prefix, materials, collection=None, bevel=0.006):
        self.prefix = prefix
        self.materials = materials
        self.collection = collection or bpy.context.scene.collection
        self.kit = greeble.Kit(prefix, collection=self.collection, bevel=bevel)
        self.placed = []

    # -- public ----------------------------------------------------------

    def purge(self):
        self.kit.purge()
        self.placed = []

    def place(self, source, at, size=None, z=0.0, rot=0.0, rot_x=0.0,
              mat=None, name=None, **kw):
        """Put one part on the machine.

        `at` is (x, y) in tiles, `z` its base height, `size` its dominant
        dimension in tiles -- diameter for round parts, height for an imported
        model, (w, d) for a panel. `rot` is degrees about Z.
        """
        kind, _, ref = source.partition(":")
        material = self._material(mat)
        if kind == "greeble":
            objs = self._place_greeble(ref, at, size, z, rot, material, name, **kw)
        elif kind == "polyhaven":
            objs = self._place_model(ref, at, size, z, rot, rot_x, material, name)
        else:
            raise ValueError("unknown part source %r -- see parts.catalogue()" % source)
        self.placed.extend(objs)
        return objs

    def run(self, source, *path, mat=None, name=None, **kw):
        """Place a part defined by a path: a cable, a pipe run, a rivet row,
        a railing, a ladder, a set of skid feet.

            a.run("greeble:cable", (0.4, -1.2, 0.6), (-0.5, -1.2, 0.7), sag=0.18)
            a.run("greeble:pipe_run", [(1.0, 0.3, 1.5), (0.4, -0.9, 1.6)])
        """
        kind, _, ref = source.partition(":")
        if kind != "greeble" or ref not in RUNS:
            raise ValueError("run() takes greeble:%s" % "|".join(sorted(RUNS)))
        fn, argnames = RUNS[ref]
        if len(path) != len(argnames):
            raise TypeError("greeble:%s wants %s" % (ref, ", ".join(argnames)))
        kw.setdefault("material", self._material(mat))
        if name:
            kw.setdefault("name", name)
        obj = fn(self.kit, *path, **kw)
        objs = list(obj) if isinstance(obj, (list, tuple)) else [obj]
        self.placed.extend(objs)
        return objs

    def survey(self, collection=None, z_lo=0.86, z_surface=0.76, margin=0.06):
        """Read the deck off the scene: what is an obstacle, what can be stood on.

        Promoted from `pure-modules-realk`'s beacon generator, which had the
        better implementation of this than the first draft of `scatter()` did.
        Two things in it are the reason it works and are easy to leave out:

        * **Sample the surface height, don't assume one.** A part placed at a
          fixed z floats wherever there is no panel under it, and a 2 px gap
          is visible in game.
        * **A traced run gets a keep-out that follows it.** Boxing a cable's
          extents instead covers most of a quadrant and blanks the scatter
          around it -- so a curve with many points contributes one keep-out
          per point, while a coarse 2-4 point curve keeps its bounding box.

        Returns (obstacles, surfaces): rectangles, the second carrying a top z.
        """
        coll = collection or self.collection
        obstacles, surfaces = [], []
        for obj in coll.objects:
            if obj.type not in ("MESH", "CURVE"):
                continue
            if obj.type == "CURVE" and obj.data.bevel_depth:
                pts = [p for spl in obj.data.splines
                       for p in (spl.bezier_points if spl.type == "BEZIER"
                                 else spl.points)]
                if len(pts) >= 10:
                    rad = obj.data.bevel_depth + margin
                    for p in pts:
                        w = obj.matrix_world @ Vector(p.co[:3])
                        top = w.z + obj.data.bevel_depth
                        if top >= z_lo:
                            obstacles.append((w.x - rad, w.y - rad,
                                              w.x + rad, w.y + rad))
                        elif top > z_surface:
                            surfaces.append((w.x - rad, w.y - rad,
                                             w.x + rad, w.y + rad, top))
                    continue
            corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
            top = max(c.z for c in corners)
            xs = [c.x for c in corners]
            ys = [c.y for c in corners]
            if top >= z_lo:
                obstacles.append((min(xs) - margin, min(ys) - margin,
                                  max(xs) + margin, max(ys) + margin))
            elif top > z_surface:
                surfaces.append((min(xs), min(ys), max(xs), max(ys), top))
        return obstacles, surfaces

    @staticmethod
    def surface_z(x, y, surfaces, default=0.0):
        tops = [t for x0, y0, x1, y1, t in surfaces if x0 <= x <= x1 and y0 <= y <= y1]
        return max(tops) if tops else default

    def scatter(self, sources, area, z, n, mat=None, seed=0, min_dist=0.22,
                size=(0.12, 0.20), obstacles=None, surfaces=None, exclude=None,
                keep_clear=None, budget=400):
        """Sprinkle small repeated details over the deck.

        `area` is (x0, y0, x1, y1) in tiles, or a list of such rectangles.
        Rejection sampling with a minimum spacing, so parts do not fuse into a
        blob at sprite scale. Feed it `survey()`'s output and it will also
        avoid anything tall and sit each part on the surface actually beneath
        it; `exclude` adds keep-outs for props too low for the survey's
        obstacle threshold, and `keep_clear=(r_in, r_out)` holds an annulus
        open -- a walkway ring, typically.

        This is what makes "8-15 distinct kinds of functional detail" a
        parameter rather than an afternoon. Modular repetition is the point:
        design-language.md, "the same bolt, vent or connector repeated at
        plausible intervals beats five unique gadgets".

        It only spaces centres, so run the interpenetration audit afterwards --
        it does not know how big each part really is.

        The size default is a floor, not a taste: 0.12 tiles is 7.7 source px
        and 3.8 at gameplay zoom, just above where `greeble.legibility()` says
        a feature stops being geometry and becomes a smudge. Scattering
        anything smaller costs render time to show nothing, so this warns
        rather than doing it quietly.
        """
        smallest = size[0] if isinstance(size, (tuple, list)) else size
        verdict = greeble.legibility(smallest)
        if verdict["game_px"] < 3:
            print("[parts] scatter size %.3f tiles = %.1f game px -- %s"
                  % (smallest, verdict["game_px"], verdict["verdict"]))

        regions = area if isinstance(area[0], (tuple, list)) else [area]
        rng = random.Random(seed)
        done = []
        why = {"walkway": 0, "excluded": 0, "too close": 0, "obstacle": 0}
        # `budget` attempts per requested part. Raising it is NOT usually the
        # fix: the beacon this was promoted from asks for 20 and places 8 at
        # budget 80, and still only 10 at 400. Its deck is simply full --
        # min_dist plus the obstacles plus the walkway annulus leave room for
        # about ten. Getting more detail there is a design change (tighter
        # spacing, a narrower walkway, more regions), not a tuning one, and
        # the rejection tally below is what tells you which.
        for attempt in range(n * budget):
            if len(done) >= n:
                break
            x0, y0, x1, y1 = regions[rng.randrange(len(regions))]
            x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
            if keep_clear:
                r = math.hypot(x, y)
                if keep_clear[0] < r < keep_clear[1]:
                    why["walkway"] += 1
                    continue
            if any(ex0 <= x <= ex1 and ey0 <= y <= ey1
                   for ex0, ey0, ex1, ey1 in (exclude or ())):
                why["excluded"] += 1
                continue
            if any((x - px) ** 2 + (y - py) ** 2 < min_dist ** 2 for px, py in done):
                why["too close"] += 1
                continue
            if any(bx0 <= x <= bx1 and by0 <= y <= by1
                   for bx0, by0, bx1, by1 in (obstacles or ())):
                why["obstacle"] += 1
                continue
            at_z = (self.surface_z(x, y, surfaces, default=z) - 0.004
                    if surfaces else z)
            src = rng.choice(sources)
            name = "scatter%02d" % len(done)
            sz, rot = rng.uniform(*size), rng.uniform(0, 360)
            if callable(src):
                # A mod keeps its own part vocabulary and still gets this
                # sampler. The beacon's bolt/stub/box/clip are not greeble.py
                # parts and there is no reason to force them to be.
                made = src(name, (x, y), at_z, sz, rot)
                self.placed.extend(made if isinstance(made, (list, tuple)) else [made])
            else:
                self.place(src, at=(x, y), z=at_z, size=sz, rot=rot,
                           mat=mat, name=name)
            done.append((x, y))
        # Say WHY when it falls short. A scatter that silently places a third
        # of what was asked reads as "the deck is full" and is usually one
        # over-wide keep-out instead.
        note = "" if len(done) >= n else "  rejected: " + ", ".join(
            "%s %d" % (k, v) for k, v in sorted(why.items(), key=lambda kv: -kv[1]) if v)
        print("  [parts] scattered %d of %d requested%s" % (len(done), n, note))
        return done

    def report(self):
        """Distinct kinds placed, against design-language.md's 8-15 band."""
        kinds = {o.name.rsplit(".", 1)[0].replace(self.prefix, "").rstrip("0123456789")
                 for o in self.placed}
        return {"objects": len(self.placed), "distinct_kinds": len(kinds),
                "kinds": sorted(kinds)}

    # -- internals -------------------------------------------------------

    def _material(self, mat):
        if mat is None:
            return None
        if isinstance(mat, str):
            if mat not in self.materials:
                raise KeyError("no material %r (have: %s)"
                               % (mat, ", ".join(sorted(self.materials))))
            return self.materials[mat]
        return mat                                   # already a datablock

    def _place_greeble(self, ref, at, size, z, rot, material, name, **kw):
        if ref not in GREEBLE:
            raise ValueError("no greeble %r -- have %s" % (ref, ", ".join(sorted(GREEBLE))))
        fn, size_arg, proportions = GREEBLE[ref]
        centre = (at[0], at[1], z)
        args = dict(kw)
        if size is not None:
            if size_arg == "radius":
                args["radius"] = size / 2.0
            elif isinstance(size, (tuple, list)):
                args["size"] = tuple(size)       # caller gave the exact shape
            else:
                args["size"] = tuple(size * p for p in proportions)
        args.setdefault("material", material)
        if name:
            args.setdefault("name", name)
        obj = fn(self.kit, centre, **args)
        objs = obj if isinstance(obj, (list, tuple)) else [obj]
        if rot:
            for o in objs:
                o.rotation_euler = (o.rotation_euler[0], o.rotation_euler[1],
                                    o.rotation_euler[2] + math.radians(rot))
        return list(objs)

    def _place_model(self, slug, at, size, z, rot, rot_x, material, name):
        blend = _model_blend(slug)
        with bpy.data.libraries.load(str(blend), link=False) as (src, dst):
            dst.objects = list(src.objects)
        objs = [o for o in dst.objects if o and o.type == "MESH"]
        if not objs:
            raise RuntimeError("%s carries no mesh" % slug)
        for o in objs:
            self.collection.objects.link(o)

        lo, hi = _bbox(objs)
        k = (size / max(hi.z - lo.z, 1e-6)) if size else 1.0
        centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))

        root = bpy.data.objects.new(
            self.prefix + (name or slug), None)
        self.collection.objects.link(root)
        for o in objs:
            o.parent = root
            o.matrix_parent_inverse = root.matrix_world.inverted()
        root.location = (at[0] - centre.x * k, at[1] - centre.y * k, z - centre.z * k)
        root.scale = (k, k, k)
        root.rotation_euler = (math.radians(rot_x), 0, math.radians(rot))

        for o in objs:
            _apply_import_recipe(o, k, material)
        return [root] + objs


# --- the import recipe ---------------------------------------------------

def _apply_import_recipe(obj, scale, material):
    """Everything an outside mesh needs before the material stack will work.

    Each step is a measured failure, not a precaution:
      bevel    pointiness has no crease to sit on otherwise -- 21.8% of the
               silhouette marked worn without it, 3.0% with
      origin   Texture Coordinate->Object spans the OBJECT, so a shared origin
               gives every part one stretched mapping
      origin   ObjectInfo->Random is per object too; without its own origin a
               part cannot get its own hue/value jitter, and materials.md calls
               that absence the biggest "CG, not hand-painted" tell
    """
    b = obj.modifiers.new("Part_Bevel", "BEVEL")
    b.width = 0.004 / max(scale, 1e-6)      # ~1 px at 64 px/tile after scaling
    b.segments = 2
    b.limit_method = "ANGLE"
    b.angle_limit = math.radians(45)

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    obj.select_set(False)

    obj.data.materials.clear()
    if material:
        obj.data.materials.append(material)


def split_loose(obj):
    """Recover per-part structure from a single fused mesh.

    An AI generator exports one object; Poly Haven usually does not. Measured
    on a fused 31k-vert mesh: jitter sd 0.002 with one object, 0.267 after
    splitting into 195 loose parts. Call this before `_apply_import_recipe`
    runs, i.e. before placing, when a source is known to be fused.
    """
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    return [o for o in bpy.context.selected_objects if o.type == "MESH"]


def _bbox(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for ob in objs:
        for c in ob.bound_box:
            p = ob.matrix_world @ Vector(c)
            lo = Vector((min(lo[i], p[i]) for i in range(3)))
            hi = Vector((max(hi[i], p[i]) for i in range(3)))
    return lo, hi


def _model_blend(slug, res="1k"):
    """Cached path to a CC0 model, fetched on first use.

    Downloads land in assets/third-party/polyhaven/, which is git-ignored --
    so the SLUG in the generator is the tracked source, exactly as it already
    is for textures. Nothing third-party is committed.
    """
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    import polyhaven
    root = polyhaven.DEFAULT_OUT / slug
    cached = root / ("%s_%s.blend" % (slug, res))
    if cached.exists():
        return cached
    return polyhaven.fetch_model(slug, res=res)
