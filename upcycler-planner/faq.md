## Why can't I see my machines?

The planner only shows what you've researched. A modded machine appears as soon as you research the technology that unlocks it.

To see everything, tick **Show unresearched items** in the planner's **Settings** (title bar button). It's also in Settings → Mod settings → Per player.

## Why are some build options missing?

A build option with only one choice is hidden.
Options like recycler and pipe are always hidden since vanilla only adds 1, if mods adds alternatives they will be displayed.

Some options like chests or beacon are always hidden to make UI more concise,
But you can enable **Show all build options** to see all options, include beaconed options.

## Why do some machines get productivity modules?

Mixing a few productivity modules in with the quality modules often makes the loop cheaper per finished item, see: [Quality Math](https://wiki.factorio.com/Tutorial:Quality_upcycling_math). The planner calculates out the best rations for the machines and modules you picked.

## How do I change how many ingredients the loop requests?

Press **Edit...** beside **Ingredient amounts** in the planner. You get one field per ingredient of the recipe, and each tier's chest requests that many.

## What is the active provider chest for?

Machines and recyclers sometimes roll an item above the quality you asked for. Nothing left in the loop can use it, so it would ride the belt forever and slowly fill it up. The planner taps it into an active provider chest instead, and your bots carry it away.

## Why is my fluid recipe refused?

Only recipes with one fluid ingredient are supported. Two kinds can't be looped: recipes needing two different fluids (only ammonia rocket fuel in vanilla), and recipes that return a fluid alongside the item (like the quantum processor).
