# Upcycler Planner

**Choose an item and a target quality. The mod designs the whole upcycling loop and hands it to you
as a blueprint for your bots to build.**

Like Mining Patch Planner designs mining outposts, or P.U.M.P. designs oil outposts, Upcycler Planner designs quality upcycling loops.

![Planning a loop and placing it as ghosts](https://files.catbox.moe/thkeot.gif)

## How to use it

1. The mod is only enabled after the **Recycling** tech has been researched. Then this button appears in your shortcut bar:
   ![the Upcycler Planner shortcut button](https://files.catbox.moe/08ae4j.jpg)
2. After clicking it, pick the item you want to upcycle and the quality you are aiming for.
3. You are able to modify some options in the design like belts to use, electric poles, modules... each one defaults to the best researched option and can be built at a quality of your choice. Selectors with only one option are hidden, clicking **Settings** in the title bar brings them all back with **Show all build options**.
4. Press **Place**. The loop arrives as a blueprint in your hand, so you can see it, move it, rotate it and flip it before you commit.
5. Place it like any other blueprint. Shift-click builds through trees and rocks, and control-shift-click clears buildings too. Undo takes the whole loop back in one step, and the blueprint stays in your hand if you want to stamp another.

## What it builds

The loop contains:

- A column for each quality with a crafting machine and recycler with requester chests.
- Belts, filtered inserters, chests, electric poles... already set up and configured by you.

Finished items collect in a passive provider chest at the end.

## Works with your mods

This was the main motivation for creating this mod.

Modded machines, recyclers, modules, poles... can be selected.
Only researched options are offered, and the planner's settings can show everything instead.

![Planning a loop with modded machines and recyclers](https://files.catbox.moe/ulihf9.gif)

## Good to know

- Recipes with two fluids or that return a fluid (like the quantum processor) are not supported yet.
- Items that recycle into themselves (like steel) are not supported.

## Requirements

Factorio with **Space Age**.

Supports both Factorio 2.1 and 2.0. The main development branch is Factorio 2.1.

## Credits

Inspired by kvdveer's [Upcyclers](https://forums.factorio.com/viewtopic.php?t=121438) blueprint book.

Also by two planners that showed how good this kind of mod can feel:

- rimbas' [Mining Patch Planner](https://mods.factorio.com/mod/mining-patch-planner)
- Xcone's [P.U.M.P.](https://mods.factorio.com/mod/pump).

## AI-Assisted Development

The development of this mod was done with help of AI coding assistants.

## License

GPLv3. See [LICENSE](https://github.com/RealK465/RealK_Factorio_Mods/blob/main/upcycler-planner/LICENSE).
