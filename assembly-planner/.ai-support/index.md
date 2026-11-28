# .ai-support — Assembly Planner

Notes written for the agent, not for the game. Tracked in git, ships nowhere (leading dot:
invisible to Factorio and to `fmtk package`). The rules governing this folder are in the repo
`CLAUDE.md` → *AI support folders*.

**Read `decisions.md` before changing anything here. Read the rest when the table says to.**

| File | Genre | What is in it | Read it when |
|---|---|---|---|
| `decisions.md` | register | what is settled and why — identity, the window's layout, the cell's shape and its extra inserters, requests, the quality split, the stock cap, throughput, fluids, beacons, power, pickers, the portal presentation, what was rejected | before any design change |
| `throughput-design.md` | subject design | inserter throughput — the real-rate model, extra inserter-and-chest pairs when inserters cap the cell, and where they go (bottom edge, then the sides); built 2026-11-28 for 0.2.0, with the approaches weighed | before touching the inserter row, request sizing across chests, or the rate line |
| `deferred.md` | register | parked work, each entry pick-up-able cold — the played session, a dark inserter in a beaconed EM plant cell, a robot-delivery warning, a control for the extra inserters, the default inserter by load, rows of cells, second fluids, fuelled machines, power between copies | scoping, or answering "why isn't X here?" |
| `journal.md` | journal | dated sessions, newest first | a bug smells familiar, or a choice needs its history |
| `analysis/` | evidence | the engine facts this mod measured for itself — start at its `index.md` | before re-deriving anything about the engine |

Most of the engine facts the mod leans on were measured for Upcycler Planner first and live in
its own `analysis/api.md`; this folder holds only what was new for a mall cell.
