# Performance — not costing UPS

A Factorio player's complaint about a mod is almost never "it crashed". It is "my UPS dropped".
The budget is unforgiving and public: **60 UPS is 16.67 ms per tick**, so **1 ms of script time
costs about 3.5 UPS**. Above 1 ms is worth looking at; above 5 ms is a bug report waiting to
happen. The game's own debug overlay breaks time usage down per mod — players do read it, and
"which mod is eating my UPS" threads are a genre.

## The one thing that actually matters

**API calls dominate; Lua does not.** Iterating a table 100,000 times costs single-digit
milliseconds. A single `find_entities_filtered` over a large area can cost more than the loop
that consumes it. So the optimisation that pays is almost always "call the engine less", not
"write tighter Lua".

Ranked by what to fix first:

1. **Don't run at all when there is nothing to do.** An event you can subscribe to beats a poll.
2. **Don't poll every tick.** `on_nth_tick`, or spread work across ticks.
3. **Don't search when you could have remembered.** Your own table keyed by `unit_number`.
4. **Don't call the API inside a loop when one call outside it would do.**
5. Only then, micro-optimise the Lua.

## Prefer an event to a poll

The engine already knows when things happen. Most "check every tick whether X" code is answering a
question some event answers exactly:

- entity appeared/vanished → the build and mine event sets (see `control-stage.md`)
- research done → `on_research_finished`
- item crafted → `on_player_crafted_item`
- setting changed → `on_runtime_mod_setting_changed`
- your specific object destroyed → `script.register_on_object_destroyed`

Add **event filters** where the event supports them (list in `control-stage.md`). Filtering is
done engine-side, so a filtered handler on `on_built_entity` genuinely does not run for the
thousands of belts a player places — an `if entity.name == ... then return end` at the top of the
handler still pays the Lua call.

## When you must poll

**`script.on_nth_tick(n, handler)`** is the engine doing the modulo. Multiple `n` values register
independently.

For work proportional to the number of tracked objects, **spread it** rather than doing all of it
on one tick — a stutter every 60 ticks is more visible than a constant small cost:

```lua
-- process ~1/60th of the machines each tick
script.on_event(defines.events.on_tick, function(e)
  local slice = storage.slices[e.tick % 60 + 1]
  for unit_number, data in pairs(slice) do ... end
end)
```

Or keep a cursor into the table and consume a fixed budget per tick, resuming next tick. Either
way the total work per second is the same and the per-tick cost is bounded.

**Deregister when idle.** `script.on_event(defines.events.on_tick, nil)` removes the handler
entirely — zero cost, not a cheap early return. This is the conditional-registration pattern, and
its price is that `on_load` must re-derive the same decision from `storage` so every client
registers identically (see `control-stage.md` → desync sources). Worth it for a handler that is
usually idle; not worth it for one that is usually busy.

## Remember instead of searching

There is no engine-side lookup of an entity by `unit_number` and Wube has explicitly declined to
add one, because it would be a full scan. Maintain your own:

```lua
storage.machines[entity.unit_number] = { entity = entity, ... }   -- on build
storage.machines[unit_number] = nil                               -- on mine/death
```

`find_entities_filtered` is for the one-off — `on_configuration_changed` rebuilding your index
after a mod update, or a chunk-generated handler. It is not for a tick loop.

When you do call it, narrow it as far as it will go: `area` or `position`+`radius`, `name` or
`type`, `force`, `limit`. Every filter is applied engine-side.

## Table and loop costs, measured

From community benchmarking (Factorio forums; the ratios hold, the absolute numbers are old
hardware) — useful mainly for the hot inner loop, after the four points above are handled:

- `pairs()` iteration is the slowest form (~4.9 ms / 100k), numeric `for` over a sequence ~3.4 ms,
  linked-list traversal ~2.2 ms.
- Later indices in a large array cost more than early ones (~5.3 ms vs ~3.4 ms for the last vs the
  first 1000 of a 10,000-entry array).
- Function call overhead is real and grows with parameter count: ~4.0 ms for none, ~4.3 ms for
  1–2, ~6.1–6.7 ms for 3+.
- **Removing from the end of an array is cheap; removing from the front re-indexes everything.**
  For a queue, use two cursors or flib's `queue.lua` rather than `table.remove(t, 1)`.

Two Factorio-specific notes: `pairs()` here is deterministic and ordered, so there is no
correctness reason to avoid it — only the speed one. And `table_size(t)` is a C++ implementation,
faster than counting in Lua and correct on tables with holes where `#` is not.

Localising hot globals (`local floor = math.floor`) is standard Lua practice and does help in a
tight loop, but it is noise next to a stray API call.

## Data-stage cost

Startup time is a real cost too — it is what players wait through on every launch.

- Sprite atlas is usually the dominant term, not Lua. See `factorio-graphics`.
- Deep-copying large prototypes hundreds of times in a loop is measurable. Copy once outside the
  loop where you can.
- Prototype count matters at runtime as well as startup: every recipe is in the crafting-menu
  index, every item in inventory sorting. Generating a variant for every combination of something
  adds up.
- Custom collision layers are cheap individually but the mask work is on a hot engine path. SE
  defines eight and notes it as a cost.

## Measuring rather than guessing

- **`helpers.create_profiler()`** returns a `LuaProfiler`. `stop()` it and pass it straight into a
  `LocalisedString` (`game.print{"", "took ", profiler}`). It deliberately will not give Lua the
  raw number, because timings are non-deterministic and reading one would desync. `reset`,
  `restart`, `add` and `divide` let you accumulate across calls for an average.
- **The in-game debug overlay** — "Toggle debug settings GUI" (F4 by default) to turn on
  `show-time-usage`, then "Toggle basic debug" (F5) to display it. Gives a live per-mod
  breakdown, which is enough to tell whether the problem is yours.
- **fmtk's debug adapter profiles per-line and per-function** from VS Code. It needs
  `--instrument-mod debugadapter`, and instrument mode disables multiplayer. This is the tool for
  "which of my functions is the 3 ms".
- `/c` commands in a test save let you create a stress scenario (a thousand of your entity) far
  faster than building one.

Measure before optimising and after. A mod that "feels slow" is often slow because of one
`find_entities_filtered` in an `on_tick`, and the rest of the code is fine.
