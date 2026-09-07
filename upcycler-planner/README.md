# Upcycler Planner

**Choose an item and a target quality, the mod designs and gives you an entirely configurable
upcycling loop blueprint.**

Like [Mining Patch Planner](https://mods.factorio.com/mod/mining-patch-planner) designs mining outposts, or [P.U.M.P.](https://mods.factorio.com/mod/pump) designs oil outposts, Upcycler Planner designs quality upcycling loops.

You can entirely configure the Upcycling Loop elements and let the mod design it:

![Planning a loop and stamping the blueprint](https://files.catbox.moe/u1qoct.gif)

Some configuration options are:

- You can **configure every entity** you want to use (assembling machine, recycler, modules, poles, inserters, chests...)
- Supports **beaconed layouts (enable "Show All Build Options" setting)** (useful for modded beacons like Maraxis quality beacon)
- Supports **recipes with fluids**
- You can define **circuit conditions** so the upcycling loop stops after a certain target amount is reached or a minimum amount of lower quality items to keep in the logistics network. The limits sit on a **constant combinator** you can edit in place, and **lamps** show when the loop is done.
- Automatically proposes the **best ratio of modules** (considering modded machines/modules), see: [Quality Math](https://wiki.factorio.com/Tutorial:Quality_upcycling_math).
- You can **configure the number of columns** for each quality tier to boost output

## Works with your mods

This is the main advantage of it, no matter what mods you're using, you don't have to create new blueprints. The mod is entirely configurable.
You can choose modded machines, recyclers, belts, modules, beacons... they can all be picked, and the layout adapts itself to whatever you choose.
By default only researched options are offered, but it can be changed in the planner/mod settings.

![Planning a loop with modded machines and recyclers](https://files.catbox.moe/mlwckl.gif)

## How to use it

1. The mod is only enabled after the **Recycling** tech has been researched. Then this button appears in your shortcut bar:
   ![the Upcycler Planner shortcut button](https://files.catbox.moe/08ae4j.jpg)
   You can also press **Ctrl+U** (rebindable under Settings → Controls → Mods).
2. After clicking it, pick the item you want to upcycle and the quality you are aiming for.
3. Under **Build options** you can change what the loop is made of: belts, inserters, chests, modules, electric poles and more. Each one defaults to the best you have researched, and each can be built at a quality of your choice. The **Edit...** buttons there let you set how many of each ingredient the loop requests, and how many columns each quality builds. Options with only one choice are hidden, and so are the five chests and the beacons. Click **Settings** in the title bar and tick **Show all build options** to bring them all back.
4. Press **Place**. The loop arrives as a blueprint in your hand, so you can look it over, move it, rotate it and flip it before you commit.

## Good to know

- Layout processing algorithm is quite demanding in layouts with lots of columns, version 1.0 of the mod benchmarked 5s processing an 8000 column layout (this means like 8000 quality tiers or having 1000+ columns for each quality tier, it requires crazy mods to reach those numbers). Higher durations can cause the game to crash.
- Recipes with more than 5 ingredients are not supported (limited to the inserter max item filter).
- Recipes with spoilable items are not supported.
- Recipes that need two different fluids, or that give back a fluid (like the quantum processor), are not supported.
- Items that recycle into themselves (like steel) are not supported.

## Highlighted Features

### Best Ratios + Stats

If the recipe you chose supports productivity modules, the mod is able to mix quality/productivity modules with the best ratio:

![Best Ratios](https://files.catbox.moe/n1yfnh.jpg)

You can always take a look at the footer for the expected production stats so it can help you to tweak your settings.

![Stats](https://files.catbox.moe/c48nt7.jpg)

### Quality Tiers Column Count

You can configure the column count for each quality tier in a way to increase the output of your upcycler at a cost of a bigger blueprint.

![Columns](https://files.catbox.moe/p60d73.jpg)

### Pipes + Beaconed Layouts

The mod fully supports layouts that require usage of pipes and beacons (**enable "Show All Build Options" to see beacon config settings**):

![Beaconed Layout](https://files.catbox.moe/heq3zl.jpg)

### Circuit Conditions

You can define a minimum amount of the lower quality items to keep as reserve in the logistics network,
and also a maximum amount for the target quality item that stops the loop after the target amount is reached.

The numbers live on a constant combinator inside the loop, so you can change them in place without a new blueprint.
Switch the combinator off to pause the whole loop, or tick **Start paused** to place it switched off while your bots are still bringing the modules.
Two lamps and a display panel show what the loop is doing: blue while it runs, green when the output chest is full, and the panel's icon is visible on the map.

![Circuit Conditions Config](https://files.catbox.moe/0cddec.jpg)

## Road Map

- Automatic placement of Lightning Collectors at Fulgora
- Automatic placement of Heating Pipes at Aquilo
- Possibility of exporting the layout as a parametrized blueprint
- Check possibility of adding more inserters/chests to overcome limitation of 5 ingredients (is the maximum allowed to filter inserters)
- Small improvements

## Requirements

Factorio with **Space Age**.
Both Factorio 2.1 and 2.0 are supported.

## Credits

Inspired by kvdveer's [Upcyclers](https://forums.factorio.com/viewtopic.php?t=121438) blueprint book.

Also by two planners that showed how good this kind of mod can feel:

- rimbas' [Mining Patch Planner](https://mods.factorio.com/mod/mining-patch-planner)
- Xcone's [P.U.M.P.](https://mods.factorio.com/mod/pump).

## AI-Assisted Development

The development of this mod was done with the help of AI coding assistants.

## License

GPLv3. See [LICENSE](https://github.com/RealK465/RealK_Factorio_Mods/blob/main/upcycler-planner/LICENSE).
