## Why can't I see my machines?

The planner only shows what you've researched. A modded machine appears as soon as you research the technology that unlocks it.

To see everything, tick **Show unresearched items** in the planner's **Settings** (title bar button). It's also in Settings → Mod settings → Per player.

## Why are some build options missing?

Build options pickers with only one option are hidden. In vanilla, the recycler and the pipe have no alternatives, so they don't appear. They come back when a mod adds another option. The five chest pickers are always hidden: the planner uses the biggest chest you have researched.

To show them anyway (for example, to pick their quality), tick **Show all build options** in the planner's settings.

The beacon pickers are hidden too: beacons are optional and the loop plans none unless you pick one. Tick **Show all build options** to pick a beacon; once one is chosen, its pickers stay visible. A small drop-down beside them sets how many beacons stack per tier — extra ones add no width.

## What is the active provider chest for?

Machines and recyclers sometimes roll an item above the quality you asked for. Nothing left in the loop can use it, so it would ride the belt forever and slowly fill it up. The planner taps it into an active provider chest instead, and your bots carry it away.

Loops aiming at the highest quality can't roll past it, so they don't get one.

## Why are bots taking items out of the loop?

Each quality's items wait in buffer chests, so your logistic requests and construction bots can use them — handy when you want a few of a lower quality without visiting the loop. If you'd rather keep every item in, untick **Use buffer chests** in the build options and place the loop again.

## Why did the machines stop working?

If you built the loop with **Circuit limits** on, that's the limits doing their job: every machine pauses once the output chest holds your maximum. Take items out of the chest and the loop starts again. To change the numbers, reopen the planner and press **Limits...**; to run without limits, untick the checkbox and place the loop again.

## Why is my fluid recipe refused?

Only recipes with one fluid ingredient are supported. Two kinds can't be looped: recipes needing two different fluids (only ammonia rocket fuel in vanilla), and recipes that return a fluid alongside the item (like the quantum processor).
