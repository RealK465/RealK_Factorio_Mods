## Why can't I see my machines?

The planner only shows what you've researched. A modded machine appears as soon as you research the technology that unlocks it.

To see everything, tick **Show unresearched items** in the planner's **Settings** (the button in its title bar). It's also in the game's **Mod settings**, under **Per player**.

## Belts or Bots?

**Belts** builds a belt ring between the tiers: your robots only fill its chests and take the finished items away. **Bots** builds no belts and far fewer buildings: your robots carry everything between tiers. So a bot loop always upcycles what your network holds of the item, and the finished items from its lower tiers go to your storage chests. Give it a logistic network of its own if you want to keep your stock out of it.

## Why did an option disappear?

The planner only hides what your loop won't build. **Bots** has no belt and no relay chest, and its chests always request, so those rows go away. A **Belts** loop to your highest quality has no **Overflow chest**, since nothing can roll above it. **Pipe** shows only for a recipe with a fluid, **Beacon module** and **Beacons per tier** only once you pick a beacon, and **Mix productivity modules** only when the recipe and the machine allow productivity.

## Why do some machines get productivity modules?

Mixing a few productivity modules in with the quality modules often makes the loop cheaper per finished item (see [Quality Math](https://wiki.factorio.com/Tutorial:Quality_upcycling_math)). The planner works out the best ratio for your machines and modules. To change it, open the **Modules** tab: each lower tier has a field for how many of its slots get a productivity module. Untick **Mix productivity modules** for quality modules only.

## How do I get more output?

Raise **Columns per tier** in the **Buildings** tab. Each lower tier repeats its column that many times, up to 64. The final machine always stays at one.

## How do I change how many ingredients the loop requests?

Open the **Chests** tab. Under **Ingredient amounts**, **Minutes** sizes every amount at once: each ingredient is requested for that many minutes of crafting, two by default. Below it, each ingredient has its own field. The planner warns you if the amounts need more slots than the ingredient chest has.

## The loop used up my own stock of the item. How do I stop that?

The stock chests request the item from your logistic network, so the loop also upcycles what you already have. Untick **Upcycle items from the network** in the **Chests** tab and it only recycles what it makes. A **Bots** loop can't do this, since robots are how its own items travel, so give it a logistic network of its own instead.

## Why does the final machine take my high quality ingredients?

Its ingredient chest requests at your target quality, like every other tier. If you recycle the finished items for their ingredients, untick **Final machine requests ingredients**: the planner places a plain chest there instead, and the machine still gets its ingredients off the belt. Bots don't tidy a plain chest, so on a recipe with several ingredients it can slowly fill with one of them. In a **Bots** loop that chest is the final machine's only supply, so it always requests.

## What is the overflow chest for?

Machines and recyclers sometimes roll an item above the quality you asked for. Nothing left in the loop can use it, so it would ride the belt forever and slowly fill it up. The planner taps it into the overflow chest, an active provider, and your bots carry it away. With **Bots**, the overflow chests are also where each lower tier hands its items to your robots.

## Why isn't my loop running?

Look at the constant combinator under the final machine. If it's switched off, a loop with a maximum is paused: switch it on. The planner places it switched off when **Start paused** is ticked in the **Circuits** tab, so a freshly built loop waits for its modules. The lamps below it show the state: blue while running, green when done or paused. A loop with no maximum has nothing to pause: switching its combinator off only removes the reserves, so keep it on.

If the combinator is on and the loop still sits idle, check its **C** row: 0 stops the loop rather than lifting the cap.

With **Count the whole logistic network** ticked, every machine and recycler must stand inside roboport range, or it stays switched off. A **Bots** loop needs roboport range anyway, since robots bring everything it uses. It also stops when its chests fill with items nobody asked for, so keep a storage chest in its network.

## How do I change the limits after building?

Open the same combinator. The **M** rows are the minimum kept of each quality plus the inserter's hand size for every column of that quality, so a full hand never dips below your minimum: keep 20 with a 12-item hand and one column, and M reads 32. **C** is the maximum in the output chest. Edit the numbers, no new blueprint needed. To lift the maximum, type a big number: a C at 0 stops the loop. If you raise a minimum above what the stock chest requests while **Trash unrequested items** is on, raise the chest's request too, or that tier stops recycling.

With **Count the whole logistic network** ticked, **C** is the maximum across your logistic network. Edit it the same way: every machine and recycler picks up the new number. Set C to 0 or switch the combinator off to pause.

## Why is my fluid recipe refused?

Only recipes with one fluid ingredient are supported. Two kinds can't be looped: recipes that need two different fluids (only ammonia rocket fuel in vanilla), and recipes that give back a fluid with the item (like the quantum processor).
