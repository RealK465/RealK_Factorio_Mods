# .ai-support — Pure Modules

Notes written for the agent, not for the game. Tracked in git, ships nowhere (leading dot:
invisible to Factorio and to `fmtk package`). The rules governing this folder are in the repo
`CLAUDE.md` → *AI support folders*.

This mod is **published on both tracks** — Factorio 2.1 from `main`, 2.0 from `legacy/2.0` — and
everything in this folder is kept identical on both branches, like the `CLAUDE.md` files. Where
a figure genuinely differs between the two, say so at the figure rather than forking the file.

| File | Genre | What is in it | Read it when |
|---|---|---|---|
| `balance.md` | register | why the numbers are what they are — recipe shape, research gate, the three-beacon transmission cap and its arithmetic, power and pollution rates, the Space Age recipe | **before changing any balance value** |
| `pure-beacon-design.md` | subject design | the beacon as an object: lore, silhouette, materials and wear, state animation, the Blender plants, palette, frost overlay, render pipeline, remnants and dying explosion | before touching the beacon's art, or re-rendering any part of it |

## Which file does this go in?

- A **number changed, or the reason behind one did** → rewrite that paragraph in `balance.md`.
  It is a register: it describes the shipped build, so it is edited rather than appended to.
- **How the beacon looks or is rendered** → `pure-beacon-design.md`.
- A **rule to follow, or a trap that fails silently** → the mod's `CLAUDE.md` (*Gotchas
  specific to this design*, *Settings*), as one line. Never restate the reason there — point
  here for it.
- Something **verified against the game** — a prototype value, an engine behaviour → cite the
  installed `data/` or `doc-html/` with file:line and name the version it was checked at.
- It **generalises past this mod** → a skill under `.claude/`. The vanilla render conventions
  measured for this beacon already live in `factorio-graphics` rather than here.

## Standing caution

**Nothing is in game yet.** Every number below the data stage is verified from a `-KeepDump` run
and nothing else — the animation, socket tints, frost patch, the radius-10 supply overlay and
the alt-mode icon row have never been looked at on a real map. The open list in the mod's
`CLAUDE.md` says what to check first, and `draw_animation_when_idle` is top of it: on the bad
reading of that undocumented flag the idle beacon is *invisible*.
