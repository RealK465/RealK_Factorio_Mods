# Upcycler Planner

Pick an item and a target quality. Upcycler Planner designs the whole upcycling loop —
machines, recyclers, quality modules, filtered inserters and the belting between them — and
places it in the world as ghosts for your bots to build.

**Unreleased, in development.** The first version works end to end — shortcut, planner
modal, and ghost placement — but it has not yet seen enough real play to call stable, so it
is not on the mod portal yet.

## The idea

Quality loops are the one part of Space Age that players still build by hand or paste from a
shared blueprint book. The layout depends on the recipe, the machine, the module tier, the
quality you are chasing and how you want the rejects handled, so a fixed blueprint is never
quite right and a parameterised one asks the player to answer the same questions every time.

Planning it is a solved shape of problem in this game. [Mining Patch
Planner](https://mods.factorio.com/mod/mining-patch-planner) does it for ore patches and
[P.U.M.P.](https://mods.factorio.com/mod/pump) does it for oil fields: a selection tool, a
small GUI of choices, and a computed layout dropped as ghosts. Upcycler Planner applies that
model to upcycling.

## Requirements

Factorio 2.1 with **Quality** — the mod is meaningless without quality tiers and recyclers.

## License

GPLv3 — see [`LICENSE`](LICENSE).
