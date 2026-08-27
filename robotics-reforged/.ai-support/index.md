# .ai-support — Robotics Reforged

Notes written for the agent, not for the game. Tracked in git, ships nowhere (leading dot:
invisible to Factorio and to `fmtk package`). The rules governing this folder are in the repo
`CLAUDE.md` → *AI support folders*.

**Read `decisions.md` before changing anything. Read the rest when the table says to.**

| File | Genre | What is in it | Read it when |
|---|---|---|---|
| `decisions.md` | register | what is settled and why — today that is identity, packaging and the two-track question, and nothing about the design | before any design change, and before re-opening a question |
| `deferred.md` | register | the open work: every design question the mod has, each with enough context to pick up cold | scoping, or answering "what has actually been decided here?" |
| `journal.md` | journal | dated sessions, newest first: what was built, what broke, what was measured | a decision needs the story behind it |
| `analysis/` | evidence | the research — the measured vanilla robot baseline the design will be argued against. Start at its own `index.md` | before quoting a robot number from memory |

## Which file does this go in?

- It changes **what the mod does or is** → rewrite the bullet in `decisions.md`, then append the
  session to `journal.md`. Both, not either.
- It is **open, or cut for scope** → `deferred.md`, with enough context to pick up cold.
- It is a **fact about the engine**, verified or not → `analysis/`, with its confidence marker
  and the game version it was checked at.
- It is a **rule the next agent must follow** → the mod's `CLAUDE.md`, as one line, pointing
  here for the reason. Never restate the reason there.
- It **generalises past this mod** → a skill under `.claude/`, not here.

## Standing caution

**This mod is a scaffold with no code in it.** Nothing here describes behaviour that exists —
`decisions.md` is deliberately thin, and everything about the design lives in `deferred.md` as
an open question. The trap is reading the folder's shape as evidence that the mod is further
along than it is; it is not. The first session that writes Lua is also the session that starts
moving entries from `deferred.md` into `decisions.md`.

The one substantive finding so far is in `analysis/vanilla-robots.md`: worker-robot research is
force-wide, so **research cannot distinguish tiers** and a late-game force flattens any design
that does not use `max_speed` and `max_payload_size_after_bonus`. That constrains the design
before it starts, which is why it was measured first.
