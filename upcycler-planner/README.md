# Upcycler Planner

Pick an item and a target quality, the mod designs a complete upcycling loop blueprint and places it
as ghosts for your bots to build. No blueprints to find, no wiring by hand.

## Why this mod

Quality loops depend on the recipe, machine, module tier and target quality. A fixed
blueprint is never quite right, and a new modset means starting from scratch.

This mod plans the layout for your specific choices, the way
[Mining Patch Planner](https://mods.factorio.com/mod/mining-patch-planner) plans miners and
[P.U.M.P.](https://mods.factorio.com/mod/pump) plans pumpjacks. Modded machines, recyclers
and modules work out of the box — the planner adapts to whatever you have installed.

## How it works

1. Click the shortcut button (appears once you research recycling).
2. Pick the item you want to upcycle and the quality you are aiming for.
3. Choose a crafting machine and a recycler. Each can have its own build quality.
4. Under **Build options**, configure the belt, quality module, electric pole and whether
   chests trash surplus items. Everything defaults to the best you have researched.
5. Hit **Place**, click the ground, done — the full loop appears as ghosts.

Your choices are remembered between uses. More configuration options will be added over
time.

## What it places

- One crafting machine per quality tier, each pinned to that tier.
- A recycler under every machine below the target, feeding ingredients straight back in.
- Quality modules in every machine and recycler below the target. The top machine gets
  productivity modules when the recipe allows it.
- Filtered inserters, belts, requester and provider chests — all wired up.
- Electric poles covering every building, connected into one network.

## Requirements

Factorio 2.1 with the **Space Age** expansion (quality and recyclers are Space Age features).

## Credits

Inspired by kvdveer's
[Upcyclers](https://forums.factorio.com/viewtopic.php?t=121438) blueprint book.

## License

GPLv3 — see [`LICENSE`](LICENSE).
