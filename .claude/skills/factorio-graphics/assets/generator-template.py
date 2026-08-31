"""<Entity name> — scene generator.  Copy to assets/<mod>/entity/<subject>/<subject>_gen.py

Run:  blender -b -P <subject>_gen.py -- <out_dir>

This template exists because the repo's first big entity, the Pure beacon, is
4,054 lines: every part was written by hand, so reaching design-language.md's
**8-15 distinct kinds of functional detail** was an afternoon per kind and the
machine ended up dense in a few places and bare everywhere else. With
`factorio_render.parts` a part is one line, so the band is a budget you spend
rather than a target you approach.

**Fill in the design first.** Every section below asks for something the
`<subject>-design.md` written by `factorio-entity-design` already decided. If a
section has no answer, the design is not finished and modelling now is how a
machine ends up a box with pipes on it -- measured the hard way on 2026-08-30,
when four kitbash iterations with no design produced props on a slab, then a
scrap pile, then plumbing hidden behind the mass.
"""

import sys
from pathlib import Path

import bpy

# --- bootstrap ------------------------------------------------------------
# Walk up for the skill scripts rather than counting `..`: this file gets run
# as `blender -b -P`, as plain `python`, and via exec() in Blender's console,
# and only some of those give __file__ a real value.

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

PREFIX = "XX_"            # unique per subject; parts.purge() removes exactly these
FOOTPRINT = (5, 5)        # tiles, from the design's Function & constraints table
CANVAS = (FOOTPRINT[0] * 64 + 64, FOOTPRINT[1] * 64 + 128)

# The deck height everything stands on, and the ceiling the silhouette may
# reach. Keep the tallest part's (y + z) under APEX_LIMIT: at the 45-degree rig
# screen row = centre - 64*(y + z), so that sum -- not height alone -- sets how
# far the sprite draws past the footprint. Vanilla 5x5s overhang 0.52-0.81
# tiles; the beacon shipped at 2.06 and covered the machine behind it.
DECK_Z = 0.75
APEX_LIMIT = FOOTPRINT[1] / 2 + 0.8


def build_materials():
    """4-6 zones, named with colours, from the design's Material zones section.

    Copy `worn_metal()` from a finished generator and retune -- a flat
    Principled BSDF is never acceptable on a shipped sprite, and the wear stack
    is what stops the render reading as CG. See references/materials.md.
    """
    raise NotImplementedError("copy worn_metal() and define this entity's zones")


def build(mats):
    a = parts.Assembly(PREFIX, mats)
    a.purge()

    # -- 1. Hero -----------------------------------------------------------
    # The single working part that does the action. Modelled FIRST and
    # OVERSIZED; the housing is built around it, never the other way round.

    # -- 2. Housing --------------------------------------------------------
    # Break the outline on at least two sides: one tall element and one low
    # one past the footprint. Never ship the bounding box. Show a front
    # elevation -- a near-plan view is the tell that most reliably outs mod art.

    # -- 3. The four flows -------------------------------------------------
    # Every one of these should be visible, and "human service" is the one
    # most often missing -- it is what makes a model read as equipment rather
    # than a prop. `parts.catalogue()` lists what already exists.

    # power in
    # a.place("greeble:junction_box", at=(-1.2, -1.9), z=DECK_Z, size=0.30, mat="conduit")
    # a.run("greeble:cable", (-1.2, -1.9, DECK_Z + 0.2), (0.4, -2.0, DECK_Z + 0.3),
    #       sag=0.18, mat="cable")

    # material through
    # a.run("greeble:pipe_run", [(1.4, 0.3, 1.5), (0.6, -0.9, 1.6), (0.2, -1.8, 1.1)],
    #       radius=0.075, mat="copper")
    # a.place("greeble:flange", at=(0.2, -1.9), z=1.05, size=0.24, mat="iron")

    # heat out
    # a.place("greeble:radiator",    at=(1.5, -1.1), z=DECK_Z, size=0.60, mat="iron")
    # a.place("greeble:louvre_bank", at=(-1.5, -1.1), z=DECK_Z, size=0.55, mat="gunmetal")

    # human service
    # a.run("greeble:ladder", (-2.1, 0.2, 0.0), DECK_Z + 0.6, mat="gunmetal")
    # a.run("greeble:railing", [(-1.0, 1.9, DECK_Z), (1.0, 1.9, DECK_Z)], mat="gunmetal")
    # a.place("greeble:placard", at=(0.9, -2.0), z=DECK_Z + 0.4, size=0.26, mat="steel")
    # a.place("greeble:handwheel", at=(-0.7, -1.85), z=DECK_Z + 0.3, size=0.20, mat="warm")

    # -- 4. Tertiary scatter ----------------------------------------------
    # Modular repetition reads as engineered; one-offs read as noise. Survey
    # first so parts sit on the surface actually under them and avoid anything
    # tall. Read the rejection tally: a shortfall usually means one keep-out is
    # too wide, and raising the budget rarely helps.
    # obstacles, surfaces = a.survey()
    # a.scatter(parts.SCATTERABLE, area=[(-1.9, -2.0, 1.9, -1.2)], z=DECK_Z, n=14,
    #           mat="iron", seed=17, obstacles=obstacles, surfaces=surfaces)

    return a


def _world_points():
    """Every renderable vertex in world space, by object."""
    dg = bpy.context.evaluated_depsgraph_get()
    out = []
    for ob in bpy.context.scene.objects:
        if ob.type not in ("MESH", "CURVE"):
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


def audit(a):
    """Spend the detail budget deliberately, and prove the sprite fits."""
    r = a.report()
    print("[detail] %d objects, %d distinct kinds" % (r["objects"], r["distinct_kinds"]))
    print("[detail] kinds: %s" % ", ".join(r["kinds"]))
    if r["distinct_kinds"] < 8:
        print("[detail] BELOW the audited vanilla band (8-15 on a production "
              "machine). Name the missing flow rather than adding more of what "
              "is already there -- uniform density reads as noise.")

    pts = _world_points()
    if not pts:
        return

    tallest, name = -1e9, "?"
    for nm, vs in pts:
        top = max(p.y + p.z for p in vs)
        if top > tallest:
            tallest, name = top, nm
    over = tallest - FOOTPRINT[1] / 2
    print("[detail] tallest y+z = %.2f (%s) -> overhang %.2f tiles "
          "(vanilla 5x5: 0.52-0.81)" % (tallest, name, over))
    if tallest > APEX_LIMIT:
        print("[detail] OVER the limit -- this will draw over the machine "
              "placed behind it. Lower it, or move it south.")

    # No scanline may cross the sprite edge to edge. Screen row is set by y+z,
    # so a row is full width only when the west extreme and the east extreme
    # both land in it -- give those two to parts whose y ranges are disjoint
    # by more than the hull is thick and the whole failure class goes away.
    # Not one vanilla entity has a full-width row; this repo's beacon shipped
    # with 88% of them. `gates.silhouette` is the same check on the finished
    # PNG; this one is free and runs before the render.
    east = max(max(p.x for p in vs) for _, vs in pts)
    west = min(min(p.x for p in vs) for _, vs in pts)

    def extreme_rows(at_east):
        lo, hi, who = 1e9, -1e9, set()
        for nm, vs in pts:
            for p in vs:
                if (p.x > east - 0.06) if at_east else (p.x < west + 0.06):
                    lo, hi = min(lo, p.y + p.z), max(hi, p.y + p.z)
                    who.add(nm)
        return lo, hi, sorted(who)

    e_lo, e_hi, e_who = extreme_rows(True)
    w_lo, w_hi, w_who = extreme_rows(False)
    print("[silhouette] east %+.2f over rows y+z %.2f..%.2f  %s"
          % (east, e_lo, e_hi, ", ".join(e_who[:3])))
    print("[silhouette] west %+.2f over rows y+z %.2f..%.2f  %s"
          % (west, w_lo, w_hi, ", ".join(w_who[:3])))
    overlap = min(e_hi, w_hi) - max(e_lo, w_lo)
    if overlap > 0:
        print("[silhouette] FAIL: the extremes share %.2f tiles of rows, so every "
              "row in that band is full width. Move one of them." % overlap)
    else:
        print("[silhouette] ok: extremes disjoint by %.2f tiles" % -overlap)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[0] if argv else ".")
    out.mkdir(parents=True, exist_ok=True)

    scene = rig.empty_scene()
    a = build(build_materials())
    audit(a)

    rig.camera(scene, CANVAS)
    rig.lights(scene)
    rig.output(scene, CANVAS)
    rig.cycles(scene, samples=96)
    scene.render.filepath = str(out / "base.png")
    bpy.ops.render.render(write_still=True)

    # Then: post.paint_over per frame, imaging for the sheets, and
    # gates.check_all + gates.wear_mask before calling anything done.


if __name__ == "__main__":
    main()
