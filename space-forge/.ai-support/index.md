# .ai-support — Space Forge

Notes written for the agent, not for the game. Tracked in git, ships nowhere (leading dot:
invisible to Factorio and to `fmtk package`). The rules governing this folder are in the repo
`CLAUDE.md` → *AI support folders*.

This folder covers **both** mods of the pair. `space-forge-graphics` carries no `.ai-support/`
of its own — it is a pure asset container with no Lua, and a decision about the art is a
decision about this mod.

## The rule for this folder: one file per concept

**Registers here are named for the concept they own, never for their genre**, and there is no
catch-all decisions file. The rule, its reasoning and its three habits are in
`../../.claude/references/ai-support.md` → *Size, and when to split*; this folder is an instance
of it, not a second statement of it.

What that means in practice here: a new concept gets a new file once it has real content,
questions whose concept has no file yet are parked in `identity.md`'s open table, and
`analysis/` and `journal.md` keep their genre names because for those two the lifecycle *is* the
subject.

## What is here

**Read `identity.md` before changing anything. Read `art-direction.md` before drawing anything.**

| File | Genre | Concept it owns | Read it when |
|---|---|---|---|
| `identity.md` | register | **what the mod is** — the Space Age positioning, the overhaul stance, version targeting, what is required but not yet built, the concept map of open questions, and what was rejected | before any design change, and before re-opening a question |
| `art-direction.md` | register | **how the mod looks** — the crude/industrial/exotic visual gradient, the measured paint and emissive targets, the violet rule, the environment-keyed wear map, the complexity ambition, what gets custom art, and the build order | before any sprite, icon, palette or Blender decision, including the design step |
| `journal.md` | journal | dated sessions, newest first — what was decided, what was measured, what was superseded and why | a choice needs the story behind it, or a measurement smells familiar |
| `analysis/` | evidence | measured facts about the game, one file per topic, each with its confidence marker and the version it was checked at. Start at its own `index.md` | before re-deriving anything about vanilla's art or the engine |

**`analysis/` keeps its generic-looking name on purpose.** It is the evidence genre marker, and
`.claude/scripts/check-ai-docs.py` keys the `verified_against` freshness check on that exact
path — renaming it would silently switch off the check that stops a stale measurement being
believed. The concept division happens *inside* it: one file per topic, listed in its own index.

## Which file does this go in?

- It changes **what the mod is** → rewrite the bullet in `identity.md`, then append the session
  to `journal.md`. Both, not either.
- It changes **how the mod looks** → rewrite the rule in `art-direction.md`, then append to
  `journal.md`. Same pair.
- It belongs to **a concept with no file yet** → create the file, name it for the concept, move
  the question out of `identity.md`'s open table, and add a row above.
- It is a **fact about the game**, verified or not → `analysis/`, with its confidence marker and
  the version it was checked at. A colour sampled off a vanilla sprite belongs there, not in the
  art direction — the art direction *cites* it.
- It is a **rule the next agent must follow** → the mod's `../CLAUDE.md`, as one line, pointing
  here for the reason. Never restate the reason there.
- It is **one entity's design** → `<subject>-design.md`, written by the
  `factorio-entity-design` skill.
  `../../pure-modules-realk/.ai-support/pure-beacon-design.md` is the worked example.
- It **generalises past this mod** → a skill under `../../.claude/skills/`, not here. The vanilla
  render conventions already live in `factorio-graphics`; only what is specific to Space Forge
  belongs in `art-direction.md`.

## Standing caution

**The art direction is settled; nothing about the mod's mechanics is, and the gap is wide.**
`art-direction.md` can be built against today — it deliberately depends on nothing that is still
open, which is why the four-act structure was removed from it: that was progression design
wearing an art document's clothes. `identity.md` → *Open* is the real state of the design.

The trap that follows: it is now possible to spend months producing beautiful sprites for
machines whose recipes nobody has designed. The build order in `art-direction.md` exists to stop
exactly that — art is built in the order the player meets it, so whatever is finished at any
moment is a playable opening.

**Nothing has been validated.** The mod has no code, `info.json` does not yet declare the Space
Age dependency the design now requires, and no sprite exists. Nothing here has been seen in game.
