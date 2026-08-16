# .ai-support — Space Forge

Notes written for the agent, not for the game. Tracked in git, ships nowhere (leading dot:
invisible to Factorio and to `fmtk package`). The rules governing this folder are in the repo
`CLAUDE.md` → *AI support folders*.

This folder covers **both** mods of the pair. `space-forge-graphics` carries no `.ai-support/`
of its own — it is a pure asset container with no Lua, and a decision about the art is a
decision about this mod.

| File | Genre | What is in it | Read it when |
|---|---|---|---|
| `decisions.md` | register | what is settled and why, what is still open and what each open question gates, and what has been rejected | before any design work — which, at this stage, is nearly everything |

**Nothing else exists yet, on purpose.** An overhaul this early has no journal worth keeping and
no evidence to file. Add them when there is something to put in them, and index them here in the
same change:

- `journal.md` — the first time a session produces something worth not re-deriving. Append-only,
  newest first.
- `analysis/` + its own `index.md` — the first time an engine fact has to be verified rather
  than recalled. One file per topic, every claim carrying its confidence and the game version.
- `deferred.md` — the first time something is cut for scope rather than left undecided. The
  open questions in `decisions.md` are *undecided*, which is a different state.
- `<subject>-design.md` — the first entity or feature that needs its own design write-up.
  `pure-modules-realk/.ai-support/pure-beacon-design.md` is the worked example.

## Standing caution

**The first question gates the rest**: is this an overhaul of the base game, alongside Space
Age, or built on Space Age? It decides `dependencies`, whether any `*_required` feature flag is
declared, how much of the game already exists to build on, and how large the art bill is. Do not
settle art direction, compatibility or scope ahead of it — `decisions.md` says why.
