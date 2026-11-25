# .ai-support — Assembly Planner

Notes written for the agent, not for the game. Tracked in git, ships nowhere (leading dot:
invisible to Factorio and to `fmtk package`). The rules governing this folder are in the repo
`CLAUDE.md` → *AI support folders*.

**Read `decisions.md` before changing anything here. Read the rest when the table says to.**

| File | Genre | What is in it | Read it when |
|---|---|---|---|
| `decisions.md` | register | what is settled and why — identity, the cell's shape, requests, the quality split, the stock cap, fluids, beacons, power, pickers, the portal presentation, what was rejected | before any design change |
| `deferred.md` | register | parked work, each entry pick-up-able cold — the played session, rows of cells, second fluids, fuelled machines, power between copies | scoping, or answering "why isn't X here?" |
| `journal.md` | journal | dated sessions, newest first | a bug smells familiar, or a choice needs its history |
| `analysis/` | evidence | the engine facts this mod measured for itself — start at its `index.md` | before re-deriving anything about the engine |

Most of the engine facts the mod leans on were measured for Upcycler Planner first and live in
its own `analysis/api.md`; this folder holds only what was new for a mall cell.
