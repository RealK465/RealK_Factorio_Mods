# Upcycler Planner

**Choose an item and a target quality. The mod designs the whole upcycling loop and hands it to you
as a blueprint for your bots to build.**

Like Mining Patch Planner designs mining outposts, or P.U.M.P. designs oil outposts, Upcycler Planner designs quality upcycling loops.

![Planning a loop and placing it as ghosts](https://files.catbox.moe/thkeot.gif)

## How to use it

1. The mod is only enabled after the **Recycling** tech has been researched. Then this button appears in your shortcut bar:
   ![the Upcycler Planner shortcut button](https://files.catbox.moe/08ae4j.jpg)
   You can also press **Ctrl+U** (rebindable under Settings → Controls → Mods).
2. After clicking it, pick the item you want to upcycle and the quality you are aiming for.
3. You are able to modify some options in the design like belts to use, electric poles, modules... each one defaults to the best researched option and can be built at a quality of your choice. Selectors with only one option are hidden, and so are the four chests and the beacon, clicking **Settings** in the title bar brings them all back with **Show all build options**.
4. Press **Place**. The loop arrives as a blueprint in your hand, so you can see it, move it, rotate it and flip it before you commit.
5. Place it like any other blueprint. Shift-click builds through trees and rocks, and control-shift-click clears buildings too. Undo takes the whole loop back in one step, and the blueprint stays in your hand if you want to stamp another.

## What it builds

The loop contains:

- A column for each quality with a crafting machine and recycler with requester chests.
- Belts, filtered inserters, chests, electric poles... already set up and configured by you.
- Optionally beacons beside every column: pick one under **Show all build options**, and choose how many stack per tier — extra beacons add no width. Their modules default to efficiency, because speed modules also lower the quality odds of everything they reach.

Finished items collect in a passive provider chest at the end.

Anything the loop rolls above the quality you asked for has nothing left to use it, so it goes into an active provider chest and your bots take it away. Loops aiming at the highest quality don't need one and don't get one.

## Circuit limits

Tick **Circuit limits** in the build options and the loop comes wired: every machine stops once the output chest holds the maximum you set, and starts again when bots take items away. You can also keep a minimum of each lower quality in its chest — the loop only recycles the surplus above it.

The **Limits...** button opens a window with one row per quality: **Min** for the lower tiers, **Max** for your target.

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
