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

The one thing that is still unproven in game is the loop's **long-run behaviour** — above all
whether the recycler's eject stalls politely when its machine rejects a rolled-up ingredient.
The data stage validates, the planner/layout/builder are exercised by a headless harness, and
`gui.lua` has never been run headlessly at all (there is no way to create a player without a
client). Treat harness-green as "the maths is right", not "the loop works".
