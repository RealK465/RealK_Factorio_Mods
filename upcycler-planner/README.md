# Upcycler Planner

**Pick an item and a target quality. The mod designs the whole upcycling loop and places it as
ghosts for your bots to build.**

Like Mining Patch Planner designs mining outposts, or P.U.M.P. designs oil outposts, Upcycler Planner designs quality upcycling loops.

![Planning a loop and placing it as ghosts](https://files.catbox.moe/thkeot.gif)

## How to use it

1. The mod is only enabled after the **Recycling** tech has been researched. Then this button appears in your shortcut bar:
   ![the Upcycler Planner shortcut button](https://files.catbox.moe/08ae4j.jpg)
2. After clicking it, pick the item you want to upcycle and the quality you are aiming for.
3. You can change things like: the machine, recycler, belt, module or pole if you want. It tries to default to the best item researched, and can be built at a quality of your choice.
4. Press **Place**, then click the ground.

## What it builds

- A column for each quality with a crafting machine and recycler with requester chests.
- Quality modules below the target, productivity modules in the top machine.
- Belts, filtered inserters, chests, electric poles... already set up.

Trees and rocks in the way are marked for deconstruction, and your finished items collect in a
passive provider chest at the end of the loop.

## Works with your mods

This was the main motivation for creating this mod.

Modded machines, recyclers, modules, belts, poles and chests can be selected.
Only researched options are offered, and a setting can show everything instead.

![Planning a loop with modded machines and recyclers](https://files.catbox.moe/ulihf9.gif)

## Good to know

- Build it inside a logistic network. The loop uses requester and provider chests.
- Recipes using fluids are not supported yet, but it's a priority for a future update.
- Items that recycle into themselves, like steel, cannot be looped.

## Requirements

Factorio with **Space Age**, which is where quality and recyclers come from.

The main development/testing branch is Factorio 2.1, though a barely tested port exists for Factorio 2.0.

## Credits

Inspired by kvdveer's [Upcyclers](https://forums.factorio.com/viewtopic.php?t=121438) blueprint
book, and by two planners that showed how good this kind of mod can feel:
rimbas' [Mining Patch Planner](https://mods.factorio.com/mod/mining-patch-planner) and Xcone's
[P.U.M.P.](https://mods.factorio.com/mod/pump).

## License

GPLv3. See
[LICENSE](https://github.com/RealK465/RealK_Factorio_Mods/blob/main/upcycler-planner/LICENSE).
