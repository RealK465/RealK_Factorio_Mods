# .ai-support — <Mod Name>

Notes written for the agent, not for the game. Tracked in git, ships nowhere (leading dot:
invisible to Factorio and to `fmtk package`). The rules governing this folder are in the repo
`CLAUDE.md` → *AI support folders*.

**Read `decisions.md` before changing anything here. Read the rest when the table says to.**

| File | Genre | What is in it | Read it when |
|---|---|---|---|
| `decisions.md` | register | what is settled, and why | before any design change |
| `deferred.md` | register | parked work, each entry pick-up-able cold | scoping, or answering "why isn't X here?" |
| `journal.md` | journal | dated sessions, newest first | a bug smells familiar, or a choice needs its history |
| `analysis/` | evidence | verified API, layouts, maths — start at its `index.md` | before re-deriving anything about the engine |

<!--
Delete the rows this mod does not have; add the ones it does. Every file in the folder gets a
row — an unindexed file is an incomplete change.

Genres, and the lifecycle each one carries:
  register  edited in place; supersede by rewriting, never by annotating
  journal   append-only, newest first; never edit an old entry
  evidence  every claim carries Verified / Decoded / UNVERIFIED and the game version
  subject   <subject>-design.md — one entity or feature, edited freely
-->
