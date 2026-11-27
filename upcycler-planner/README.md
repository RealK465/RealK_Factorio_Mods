# Upcycler Planner

**Pick an item and a target quality, and get a ready-made upcycling loop blueprint.**

What [Mining Patch Planner](https://mods.factorio.com/mod/mining-patch-planner) does for mining outposts and [P.U.M.P.](https://mods.factorio.com/mod/pump) does for oil, this mod does for quality upcycling. It works with your mods: pick modded machines, recyclers, belts, modules or beacons, and the layout adapts to them.

![Planning a loop and stamping the blueprint](https://files.catbox.moe/u1qoct.gif)

## What you can change

- Every building in the loop, from machines and recyclers to belts, inserters, chests, modules and poles, most at any quality
- How many columns each quality tier gets, for more output from a bigger blueprint
- How much of each ingredient the loop requests
- Beacons, if you want them
- Circuit limits: stop at a maximum, keep a minimum of each lower quality, or count your whole logistic network. The numbers sit on a combinator you can edit later, and lamps show when the loop is done.

The planner works out the best mix of quality and productivity modules for you (see [Quality Math](https://wiki.factorio.com/Tutorial:Quality_upcycling_math)), and recipes with a fluid get their own pipes.

## How to use it

1. Research **Recycling**, or whatever unlocks the recycler first in your mods. This button appears in your shortcut bar, or press **Ctrl+U**:
   ![the Upcycler Planner shortcut button](https://files.catbox.moe/08ae4j.jpg)
2. Pick the item and the quality you are aiming for.
3. Change anything under **Build options**. Chests, beacons and options with only one choice are hidden until you tick **Show all build options** in the planner's **Settings**.
4. Press **Place**. The blueprint is now in your hand: move, rotate or flip it, then build.

## Examples

A loop built from modded machines and recyclers:

![Planning a loop with modded machines and recyclers](https://files.catbox.moe/mlwckl.gif)

When the recipe allows productivity, each tier gets the best mix of modules:

![Best Ratios](https://files.catbox.moe/n1yfnh.jpg)

The footer shows what the loop costs and how fast it runs:

![Stats](https://files.catbox.moe/c48nt7.jpg)

More columns per tier for more output:

![Columns](https://files.catbox.moe/p60d73.jpg)

A loop with beacons and pipes:

![Beaconed Layout](https://files.catbox.moe/heq3zl.jpg)

Setting circuit limits:

![Circuit Conditions Config](https://files.catbox.moe/0cddec.jpg)

## Good to know

- Only researched items are shown unless you tick **Show unresearched items** in the planner's **Settings**.
- Not supported: recipes with more than 10 ingredients, recipes that need two fluids or give back a fluid (like the quantum processor), and items that recycle into themselves (like steel).
- Items that spoil can be planned, but some may rot in the loop before they reach your target.
- With **Count the whole logistic network** ticked, the loop only runs inside roboport range.
- Huge layouts with thousands of columns take seconds to plan, and even bigger ones can crash the game.

## Planned

- Lightning collectors on Fulgora
- Heating pipes on Aquilo
- Exporting the layout as a parametrised blueprint

## Requirements

Factorio 2.1 with **Space Age**.

## Credits

Inspired by kvdveer's [Upcyclers](https://forums.factorio.com/viewtopic.php?t=121438) blueprint book, and by two planners that showed how good this kind of mod can feel: rimbas' [Mining Patch Planner](https://mods.factorio.com/mod/mining-patch-planner) and Xcone's [P.U.M.P.](https://mods.factorio.com/mod/pump).

## Check my other mods

- [Pure Modules](https://mods.factorio.com/mod/pure-modules-realk) — Stronger end-game tiers of modules with reduced penalties. They require a powerful new beacon to work. Optional Quality and Space Age support.
- [Quality Recycler](https://mods.factorio.com/mod/quality-recycler) — A new recycler with quality built right in.
- [Quality Assembler](https://mods.factorio.com/mod/quality-assembler) — A fast assembling machine with built-in quality.
- [Extra Qualities](https://mods.factorio.com/mod/extra-qualities) — Adds two new quality tiers above legendary: Mythic and Celestial. Also reworks vanilla quality progression so Space Age fits well with 6 quality tiers.
- [Robot World Continued (RealK)](https://mods.factorio.com/mod/robotworld-continued-realk) — Tune your robots and roboports, or get robots early. A Factorio 2.1 port of Robot World Continued.
- [Assembly Planner](https://mods.factorio.com/mod/assembly-planner) — Pick an item and get a ready-made bot mall blueprint for it.

## AI-Assisted Development

The development of this mod was done with the help of AI coding assistants.

## License

GPLv3. See [LICENSE](https://github.com/RealK465/RealK_Factorio_Mods/blob/main/upcycler-planner/LICENSE).
