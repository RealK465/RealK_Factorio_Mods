# Upcycler Planner

**Pick an item and a target quality. The mod designs the whole upcycling loop and places it as
ghosts for your bots to build.**

Like Mining Patch Planner for miners, or P.U.M.P. for oil, but for quality loops.

![Planning a loop and placing it as ghosts](https://files.catbox.moe/thkeot.gif)

## How to use it

1. Research **recycling**. A shortcut button appears in your shortcut bar.
2. Click it, then pick the item you want to upcycle and the quality you are aiming for.
3. Change the machine, recycler, belt, module or pole if you want. Each starts on the best you
   have researched, and can be built at a quality of your choice.
4. Press **Place**, then click the ground.

## What it builds

- One crafting machine for every quality step, up to your target.
- A recycler under each machine below the target, feeding the ingredients back in.
- Quality modules below the target, productivity modules in the top machine.
- Belts, filtered inserters and chests, already set up.
- Electric poles covering every building, joined into one network.

Trees and rocks in the way are marked for deconstruction, and your finished items collect in a
passive provider chest at the end of the loop.

## Works with your mods

Modded machines, recyclers, modules, belts, poles and chests are all picked up automatically.
Only researched options are offered, and a setting can show everything instead.

![Planning a loop with modded machines and recyclers](https://files.catbox.moe/ulihf9.gif)

## Good to know

- Build it inside a logistic network. The loop uses requester and provider chests.
- Fluid recipes are not supported yet.
- Items that recycle into themselves, like steel, cannot be looped.
- Legendary is the tidiest target. Below it, an ingredient that rolls too high has nowhere to
  go and keeps riding the belt.

## Requirements

Factorio 2.1 with **Space Age**, which is where quality and recyclers come from.

## Credits

Inspired by kvdveer's [Upcyclers](https://forums.factorio.com/viewtopic.php?t=121438) blueprint
book.

## License

GPLv3. See
[LICENSE](https://github.com/RealK465/RealK_Factorio_Mods/blob/main/upcycler-planner/LICENSE).
