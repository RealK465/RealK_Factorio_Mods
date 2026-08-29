# Upcycler Planner

**Choose an item and a target quality, the mod designs and gives you an entirely configurable
upcycling loop blueprint.**

Like [Mining Patch Planner](https://mods.factorio.com/mod/mining-patch-planner) designs mining outposts, or [P.U.M.P.](https://mods.factorio.com/mod/pump) designs oil outposts, Upcycler Planner designs quality upcycling loops.

You can entirely configure the Upcycling Loop elements and let the mod design it:

![Planning a loop and stamping the blueprint](https://files.catbox.moe/u1qoct.gif)

Some configuration options are:

- You can **configure every entity** you want to use (assembling machine, recycler, modules, poles, inserters, chest...)
- Supports **beaconed layouts (enable "Show All Build Options" setting)** (usefull for modded beacons like Maraxis quality beacon)
- Supports **recipes with fluids**
- You can define **circuit conditions** so the upcycling loop stops after a certain target amount is reached or a minimum amount of lower quality tiers to keep in the logistics network.
- Automatically proposes the **best ratio of modules** (considering modded machines/modules), see: [Quality Math](https://wiki.factorio.com/Tutorial:Quality_upcycling_math). 
- You can **configure the number of columns** for each quality tiers to boost output

## Works with your mods

This is the main advantage of it, no matter what mods you're using, you don't have to create new blueprints, mod is enterlily configurable,
You can choose modded machines, recyclers, belts, modules, beacons... they can all be picked, and the layout adapt's itself to whatever you choose.
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

- Layout processing algoritm is quite demanding in layouts with lot of columns, version 1.0 of the mod benchmarked 5s processing a 8000 column layout (this means like 8000 quality tiers or having 1000+ columns for each quality tiers, it requires crazy mods to reach those numbers). Higher durations can cause game to crash.
- Recipes with more than 5 ingredients are not supported (limited to the inserter max item filter)
- Recipes with spoillable items are not supported.
- Recipes that need two different fluids, or that give back a fluid (like the quantum processor), are not supported.
- Items that recycle into themselves (like steel) are not supported.

## Highlighted Features

### Best Ratios + Stats

If the recipe you chose supports productivity modules, the mod is able to mix quality/productivity modules with the best ratio:

![Best Ratios](https://files.catbox.moe/n1yfnh.jpg)

You can always take a look at the footer to the expected production stats so it can help you to tweak your settings

![Stats](https://files.catbox.moe/c48nt7.jpg)

### Quality Tiers Column Count

You can configure the column count per each quality tiers in a way to increase the output of your upcycler at a cost of a bigger blueprint

![Columns](https://files.catbox.moe/p60d73.jpg)

### Pipes + Beaconed Layouts

The mod fully supports layouts that require usage of pipes and beacons (**enable "Show All Build Options" to see beacon config settings**):

![Beaconed Layout](https://files.catbox.moe/heq3zl.jpg)

### Circuit Conditions

You can define a minimum amount of the lower quality tiers items to keep as reserve in the logistics network,
And also a maximum amount for the target quality item that stops the loop after the target amount is reached

![Circuit Conditions Config](https://files.catbox.moe/0cddec.jpg)

## Road Map

- Automatic placement of Lightning Collectors at Fulgora
- Automatic placement of Heating Pipes at Aquilo
- Possibility of export layout as parametrized blueprint
- Check possibility of add more inserters/chests to overcome limitation of 5 ingredients (is the maximum allowed to filter inserters)
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
