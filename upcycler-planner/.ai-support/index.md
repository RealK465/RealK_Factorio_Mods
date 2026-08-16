# .ai-support — Upcycler Planner

Notes written for the agent, not for the game. Tracked in git, ships nowhere (leading dot:
invisible to Factorio and to `fmtk package`). The rules governing this folder are in the repo
`CLAUDE.md` → *AI support folders*.

**Read `decisions.md` before changing anything. Read the rest when the table says to.**

| File | Genre | What is in it | Read it when |
|---|---|---|---|
| `decisions.md` | register | what is settled and why — identity, interaction, what gets planned, what is refused, what was rejected | before any design change, and before re-opening a question |
| `deferred.md` | register | parked work, each entry with enough context to pick up cold — circuits, fluids, the bot loop | scoping, or answering "why isn't X here?" |
| `journal.md` | journal | dated sessions, newest first: what was built, what broke, what the harness proved | a bug smells familiar, or a decision needs the story behind it |
| `analysis/` | evidence | the research — decoded blueprints, verified API, layout specs, quality maths, reference mods. Start at its own `index.md` | before re-deriving anything about the engine or the layout |

## Which file does this go in?

- It changes **what the mod does or is** → rewrite the bullet in `decisions.md`, then append the
  session to `journal.md`. Both, not either.
- It was **cut for scope** → `deferred.md`, with enough context to pick up cold.
- It is a **fact about the engine**, verified or not → `analysis/`, with its confidence marker
  and the game version it was checked at.
- It is a **rule the next agent must follow** → the mod's `CLAUDE.md`, as one line, pointing
  here for the reason. Never restate the reason there.
- It **generalises past this mod** → a skill under `.claude/`, not here.

## Standing caution

The old caution — the recycler-eject stall — is **resolved, by measurement** (2026-08-16,
`analysis/api.md` §9.6): a rolled-up ingredient wedges the recycler outright, and the
blacklist relief inserter is what keeps the loop alive; a permanent test now guards it. The
mod carries a 73-test suite (`tests/`, run via the repo's `factorio-testing` skill) covering
planner, layout, poles, builder, state and — since the connected-player discovery of §12 —
`gui.lua` in both headless and real-client runs.

What suite-green still does **not** prove: a multi-tier loop's endurance in a played game,
where quality rolls arrive probabilistically over hours rather than by scripted seeding —
keep half an eye on long sessions — and the `legacy/2.0` build, which the suite has not yet
been pointed at.
