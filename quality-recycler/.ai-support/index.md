# .ai-support index — Quality Recycler

Read this first. One line per file: what is in it, and when to read it.

- **`decisions.md`** — what is settled and why. Read before touching anything already decided:
  the name, the dependency set, the starting version, the entity's mechanic and stats, and the
  technology gate.
- **`quality-recycler-design.md`** — the entity's visual design: hero, family, silhouette,
  components, materials, wear, animation. Read before any modelling, rendering or icon work,
  and before writing the entity prototype — it fixes the footprint, the rotatability and the
  render budget. It also sets the mod's house art style, since there is no separate
  art-direction register yet.
- **`prototype.png`** — the repo owner's concept sheet for the entity: hero render, five
  elevations, silhouette study and a labelled colour palette. Read alongside the design doc
  before any art work. Git-ignored (reference images stay local), so it is not in a clone.
- **`ingame-v2-closeup.png`, `ingame-v2-altmode.png`** — v2 in the engine (idle, as it turned
  out: the probe was unpowered), zoom 2 alt-mode and the zoom 1 overview. The baseline the v3
  brief was written against.
- **`ingame-v3-working.png`, `ingame-v3-mirrored.png`, `ingame-v3-idle.png`,
  `ingame-v3-night.png`, `ingame-v3-altmode.png`** — v3 in the engine: four machines facing
  outward with chests on their output tiles, powered and working (status logged), at zoom 2 in
  alt-mode so the output arrow shows; the mirrored set; idle; midnight; the zoom 1 overview.
  Read beside the design doc's v3 section. All git-ignored like `prototype.png`; the tracked,
  smaller study sheets are in `docs/art/quality-recycler/previews/`.
- **`ingame-v4-working.png`, `ingame-v4-mirrored.png`, `ingame-v4-idle.png`,
  `ingame-v4-night.png`, `ingame-v4-altmode.png`, `ingame-v4-row.png`** — v4 (the 4x4) in
  the engine, the same rig as the v3 set with a chest on both candidate output tiles, plus the
  owner's own scenario: a row of abutting machines beside a vanilla recycler and an EM plant.
  Read beside the design doc's v4 section. Git-ignored like the rest.
- **`deferred.md`** — open design questions and parked work. Read before the first prototype.
- **`journal.md`** — dated sessions, newest first. Read to catch up on what happened and why.
