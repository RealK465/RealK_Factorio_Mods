# .ai-support index — Quality Assembler

Read this first. One line per file: what is in it, and when to read it.

As of 2026-09-13 the mod is **built and unplayed**: entity, art, icons, thumbnail and prototype,
validated in both configurations and photographed in the engine; the `legacy/2.0` track is a
scaffold only. The design was decided before the code, and the design document now carries a
*Built* section saying what shipped.

- **`quality-assembler-design.md`** — the entity's visual design and, in its *Built* section,
  what was actually modelled: lore anchor, hero, family, silhouette, the components by flow,
  material zones, wear map, busy/calm and animation, then the build's departures, its measured
  numbers against the assembling machine 3, **the animation system** (seven sheets in three
  engine slots, the 64-frame timeline, the step-per-frame rule for every wheel), **the Aquilo
  pass** (the graft's palette sampled off the cryogenic plant and the fusion reactor, and what
  the "futuristic" brief became) and the engine
  facts (`idle_animation` is frozen but `always_draw` + `constant_speed` plays in every state;
  the animation is not scaled by crafting speed; `pipe_picture` draws on the outside tile).
  **Read before touching the model, the render scripts or the prototype's graphics.** It also
  sets the mod's house art style, since there is no separate art-direction register.
- **`prototype.png`** — the repo owner's own concept sheet for the entity: a three-quarter hero
  render, a stat panel, a fluid-connection inset, four orthographic views (front/back/side/top),
  five material and detail close-ups, and a legend keying both halves to their paint fractions.
  **Read it alongside the design document before any art work — on anything it shows, it
  outranks the prose**, and the design document's *The owner's concept sheet* section records
  where the two differ. Git-ignored (reference images stay local), so it is not in a clone.
- **`decisions.md`** — what is settled and why. Read before touching anything already decided:
  the name, the dependency set, the starting version, the entity's mechanic and stats, its
  crafting categories, its fluid boxes, fast replacement, and the technology gate. Also the
  three facts about assembling machines that differ from `../quality-recycler` and will mislead
  anyone who copies from it.
- **`deferred.md`** — open questions and parked work: the `legacy/2.0` port of the animation
  and text passes, sounds, the remnant, the connector check, the gate number still under its
  band, what the animation pass left out on purpose, the gallery, balance. Read before
  starting any of those.
- **`journal.md`** — dated sessions, newest first. Read to catch up on what happened and why.
