# Space Forge — decisions

Register: what is settled, and why. **Edited in place** — a decision that changes is rewritten
here rather than annotated, so this file always reads as the present tense. Rules for the folder
are in the repo `CLAUDE.md` → *AI support folders*. Never ships (leading dot).

Started 2026-08-08. **Almost nothing is decided yet** — the mod was scaffolded before its
design, deliberately, so there is a place to put decisions as they are made.

Write a decision down when it is made, with the reason and the alternatives that lost. A
decision whose reason is only in someone's head gets re-litigated every few weeks; one whose
reason is written down can be revisited honestly, or overturned on purpose.

---

## Decided

- **Two mods.** `space-forge` for prototypes and logic, `space-forge-graphics` for art. The
  reasoning and the operational rules are in `../CLAUDE.md` → Two mods, on purpose.
- **Factorio 2.1 only, for now.** No `legacy/2.0` build. Revisit if a release ever warrants it.
- **Names.** `space-forge` / `space-forge-graphics`, titles "Space Forge" / "Space Forge
  Graphics". Both portal names confirmed free on 2026-08-08.

---

## The first question: what is this an overhaul *of*?

Everything else hangs off this and it is untouched. The sub-questions, roughly in the order
they stop being answerable independently:

1. **Base game, alongside Space Age, or built on Space Age?** Decides `dependencies`, whether
   any `*_required` feature flag is declared, how much of the game already exists to build on,
   and how large the art bill is. Nothing else should be settled before this.
2. **What changes?** Production chains, progression pacing, planets, combat, logistics — an
   overhaul does not have to touch all of them, and saying which it *doesn't* is as useful as
   saying which it does.
3. **The hook.** The one sentence a player reads on the portal. If it can't be written, the
   scope is not yet a design.
4. **Where a player starts and where they end.** The shape of the progression, before any
   individual recipe.

## Open, and dependent on the above

- **Art direction.** Undecided. Read the `factorio-graphics` skill before the first sprite —
  the design work happens before Blender, and vanilla's look is specific enough to be worth
  matching deliberately or departing from deliberately.
- **Compatibility stance.** Which other mods are supported, which are declared `!`
  incompatible. Overhauls usually end up with a long list; Space Exploration's `info.json` in
  `exemples/` is the reference for how one is written.
- **Settings.** None yet. An overhaul with too many startup settings is several mods wearing a
  coat; each one should earn its place.
- **Thumbnails.** Neither mod has one. 144x144, per mod, at each mod's own root.

## Rejected

Nothing yet. When something is, record it here with the reason — a rejected idea that is not
written down comes back.
