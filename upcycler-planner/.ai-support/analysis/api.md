# Verified API reference

Checked against the installed 2.1.14's own `doc-html/runtime-api.json`,
`doc-html/prototype-api.json` and `data/*.lua`. The JSON files are minified, so citations are
`Class::member` rather than line numbers; game-data citations give file:line.

**This supersedes the API table in `../design.md`, which had two errors** — both corrected in
§3 below.

## 1. Shortcut

`ShortcutPrototype`:

- `action` (mandatory) — `"lua"` raises `on_lua_shortcut`. (`"spawn-item"` + `item_to_spawn`
  puts an item in the cursor and does **not** raise the event.)
- `technology_to_unlock` — doc verbatim: *"Once a shortcut is unlocked in one save file, it is
  unlocked for all future save files."*
- `unavailable_until_unlocked` (default false) — *"the shortcut will not be available until its
  technology_to_unlock is researched, even if it was already researched in a different game."*
  **Set both** for a real per-save gate.
- `icon_size` / `small_icon_size` — schema default is 64, but vanilla uses **32 and 24**. Set
  them explicitly.
- `toggleable`, `associated_control_input`, `style` (`default|blue|red|green`), `order`.

`on_lua_shortcut` payload: `name`, `player_index`, `prototype_name`, `tick`.
Runtime: `LuaPlayer.set_shortcut_available / is_shortcut_available / set_shortcut_toggled /
is_shortcut_toggled`.

Gate tech is **`"recycling"`** (`data/recycler/data.lua:71-96`). The quality techs, if ever
needed, are `quality-module`, `quality-module-2`, `quality-module-3`, `epic-quality`,
`legendary-quality` (`data/quality/prototypes/technology.lua:3-145`).

## 2. Selection tool

`SelectionToolPrototype` — `select` and `alt_select` are **required**.
`SelectionModeData` requires `mode`, `border_color`, `cursor_box_type`.
Item flags used: `"only-in-cursor"` (Q deletes it, nothing lands in inventory), `"spawnable"`,
`"not-stackable"`.

`on_player_selected_area` payload: `area`, `entities`, `tiles`, `item`, `quality`, `surface`,
`player_index`, `name`, `tick`. The two **reverse** variants carry no `quality` field.

Use `mode = {"any-tile"}` — it guarantees a non-empty selection so the event fires.
Whether `{"nothing"}` still fires is UNVERIFIED (§9).

## 3. Ghosts — the load-bearing block, and two corrections

`LuaSurface.create_entity` variant groups are keyed by the `name` argument. Verified directly:

```
GROUP entity-ghost        -> inner_name, tags
GROUP assembling-machine  -> control_behavior, recipe, recipe_quality
GROUP item-request-proxy  -> modules, removal_plan, target
```

**Correction 1 — `create_entity` cannot set a ghost's recipe.** With `name = "entity-ghost"`
only `inner_name` and `tags` apply; `recipe`/`recipe_quality` belong to the
`assembling-machine` group and are silently irrelevant. The route is to create the ghost and
then call:

```
LuaEntity.set_recipe(recipe, quality)   -- positional, both optional, recipe FIRST (verified order)
```

Supported on ghosts per changelog v0.11.0 (recipe r/w on ghosts) and v2.0.30 (crash fix for
exactly this workflow).

**`quality` is a COMMON parameter, and does apply to a ghost.** Verified live 2026-08-16:
`create_entity{name = "entity-ghost", inner_name = "assembling-machine-3", quality =
"legendary"}` produces a legendary ghost, read back as `ghost.quality.name`. The variant-group
keying above excludes parameters belonging to a *different* group — `recipe` among them — not
everything that is not `inner_name` or `tags`. `insert_plan`'s `id.quality` likewise carries a
chosen module quality onto the ghost, and `LuaEntityPrototype.get_inventory_size(
defines.inventory.crafter_modules, quality)` is the documented way to size a module inventory at
a quality (`module_inventory_size` is the normal-quality figure only).

**Correction 2 — modules go through `insert_plan`, not `item-request-proxy`.** Verified:
`LuaEntity.insert_plan` is **read *and* write**, subclasses `["EntityGhost","ItemRequestProxy"]`;
`LuaEntity.item_requests` has **no write type** — read-only in 2.1. Both reference planner mods
use `insert_plan`. The proxy needs the ghost to exist first anyway, so it buys nothing.

```lua
ghost.insert_plan = { {
  id    = { name = module_name, quality = "normal" },
  items = { in_inventory = { { inventory = defines.inventory.crafter_modules, stack = 0 } } },
} }
```

`defines.inventory.crafter_modules` is the module inventory for **both** assembling machines and
the furnace-type recycler — `assembling_machine_modules` / `furnace_modules` do not exist, and
the recycler's own data uses `crafter_modules` (`data/recycler/data.lua:156`). **Stack indices
are 0-based.** The decoded blueprints show `"inventory": 4`, which is this define's value.

Class-level note in the docs: *"Most functions on LuaEntity also work when the entity is
contained in a ghost."*

## 4. Inserters, chests, belts on ghosts

- `set_filter(index, filter)` / `get_filter(index)`; `ItemFilter` is a string or
  `{name?, quality?, comparator?}`.
- `inserter_filter_mode` r/w `"whitelist"|"blacklist"`; `use_filters` r/w bool.
- **`get_requester_point()` does not exist.** Use `LuaEntity.get_logistic_point(index?)` ->
  `LuaLogisticPoint`, then `add_section()` -> `LuaLogisticSection`, then
  `set_slot(index, LogisticFilter)`. Ghost support is explicit in changelog v2.0.29 / v2.0.32.
- `LogisticFilter {value :: SignalFilter, min, max, minimum_delivery_count, import_from,
  request_from}`.

**Quality on logistic requests is engine-enforced.** From `SignalFilter`:

> When the LogisticFilter that this is used in has a non-zero `min` value then `comparator` must
> be `"="` (the default when writing) and `quality` is **mandatory**.

So a real request can never mean "any quality". This is what keeps the upcycler's higher tiers
hermetically separated from the rest of the player's logistic network — nothing above normal can
leak out or be stolen. Only normal quality is shared ground with the base.

Circuit (for the deferred belt-ring throttles — `../deferred.md`):

- `get_or_create_control_behavior()` — works on script-created ghosts since changelog 2.1.7.
- Belt read mode enum:
  `defines.control_behavior.transport_belt.content_read_mode.entire_belt_hold` (= the decoded
  `circuit_contents_read_mode: 2`).
- **`circuit_condition`, `logistic_condition`, `connect_to_logistic_network` are inherited from
  `LuaGenericOnOffControlBehavior`** — only findable via the JSON's `parent` key, easy to miss.
- Wires: `get_wire_connector(defines.wire_connector_id.circuit_green, true).connect_to(other)`.
  Ghost-to-ghost wiring is first-class. Use the default `wire_origin.player` —
  `script`-origin wires are **invisible to players**.

## 5. Placement

**Corrected 2026-08-15 by measurement.** The obvious call — `name = "entity-ghost"` with an
`inner_name`, checked as `script_ghost` — is wrong twice over, and both failures are silent.
Use the **real prototype name** with **`manual_ghost`**:

```lua
surface.can_place_entity{ name = proto, position = p, direction = d, force = f,
  build_check_type = defines.build_check_type.manual_ghost, forced = true }
```

Measured on 2.1.14, on generated ground with nothing on it, and again with a stone furnace
placed in the way:

| call | clear ground | occupied ground |
|---|---|---|
| real name + `manual_ghost` | true for every entity | **false** — correct |
| real name + `script_ghost` | true | **true** — does not test for obstructions at all |
| real name + `script` | true | **true** — likewise |
| `entity-ghost` + `inner_name` + any check type | **false for transport belts**, true for everything else | true |

Two separate traps:

- **`script_ghost` never rejects anything.** A whole layout can be checked against a spot with
  a building standing on it and every entity answers yes, so the check silently does nothing.
- **The `entity-ghost` + `inner_name` form answers false for transport belts on clear ground**,
  while the same belt places fine with `create_entity` and every other entity type answers
  true. In a belt-heavy layout that reads as "there is never enough room here", anywhere.

`inner_name` is still a real parameter (*"Only used if name is entity-ghost"*) — it is simply
not the right way to ask this question. The enum members are `script`, `manual`,
`manual_ghost`, `script_ghost`, `blueprint_ghost`, `ghost_revive`; `ghost_place` does not
exist. `forced = true` ignores entities marked for deconstruction, which is what makes the
tree-clearing pass work.

**Logistic sections on a fresh chest start at one, empty.** `point.add_section()` therefore
returns section **2** and leaves a blank section 1 above it in the chest's GUI. Fill
`point.sections[1]` when it is manual and empty, and only add a section otherwise. Reading back
via `point.sections[1]` after `add_section()` reads the *empty* one, which looks exactly like a
failed write and is not.

Clearing: `LuaEntity.order_deconstruction(force, player?)`, or
`LuaSurface.deconstruct_area{area, force, player, item?}`.

`create_entity` accepts `raise_built = true` (equivalent to raising the event manually, and
shorter) and `player` (sets `last_user` and feeds the undo queue).

## 6. Prototype queries for the planner

- `prototypes.get_entity_filtered(...)`, `prototypes.get_recipe_filtered(...)`; plus the plain
  `prototypes.entity / recipe / quality` dictionaries.
- `EntityPrototypeFilter`: `crafting-machine` (flag), `crafting-category`
  (`crafting_category = "recycling"` finds recyclers), `name`/`type` — **`name` accepts an
  array**, so one filter entry carries a computed whitelist.
- `LuaEntityPrototype`: `tile_width`, `tile_height`, `collision_box`, `module_inventory_size`,
  `allowed_effects`, `allowed_module_categories`, `crafting_categories`, `fluidbox_prototypes`,
  `items_to_place_this`. **`crafting_speed` is not an attribute** — it is the method
  `get_crafting_speed(quality?)`. Same trap one over: an inserter's speed is the method
  `get_inserter_rotation_speed(quality)`; a `rotation_speed` ATTRIBUTE exists but belongs to
  cars and turrets and reads nil on an inserter — verified the hard way, arithmetic crash in
  a live game 2026-08-15. Energy sources: `burner_prototype`,
  `electric_energy_source_prototype`, `fluid_energy_source_prototype` etc., nil when not that
  kind — how the planner refuses fuelled inserters. **`inserter_pickup_position` /
  `inserter_drop_position`** (Vector, Inserter subclass, optional) are how the planner requires
  one-tile reach — necessary because **the `automation` technology, the first in the game,
  unlocks the long-handed inserter** (`data/base/prototypes/technology.lua:1925`), which is
  electric, filterable and faster-rotating than the plain inserter, and would otherwise win the
  pick for the whole early game and grab from the wrong row at every position in the layout.
- `LuaRecipePrototype`: **`categories` is an array in 2.1** (singular `category` does not
  exist); `ingredients`, `products`, `main_product`, `energy`, `maximum_productivity`,
  **`can_set_quality`** (the runtime mirror of the data-stage `allow_quality`; a bare
  `allow_quality` is absent at runtime). `hidden_from_player_crafting`,
  `hidden_from_flow_stats` are its own; **`hidden` and `hidden_in_factoriopedia` exist too but
  sit on `LuaPrototypeBase`** — the same parent-key trap as the control behaviours (§4), and a
  search of the class's own attributes misses them. An earlier revision of this file claimed
  there was no bare `hidden` for exactly that reason. `hidden_in_factoriopedia` was verified
  in game 2026-08-15: it is how the planner tells a cheat tool's free recipe (Editor
  Extensions' `ee-testing-tool` category ships them all with it) from a real progression
  recipe.
- `ItemProduct`: `independent_probability` / `shared_probability` — a bare `probability` does
  not exist in 2.1.
- `LuaFluidBoxPrototype.pipe_connections[].positions` — *"the 4 cardinal direction connection
  points"*, pre-computed per direction, so no hand-rolled rotation maths is needed.

## 7. Quality enumeration

`prototypes.quality` is a `LuaCustomTable`. `LuaQualityPrototype` has `next`, `previous`,
`level`, `next_probability`, `color`, `hidden`, `localised_name`. **No `icon` at runtime** —
render with rich text `[quality=<name>]` or the `-with-quality` GUI widgets.

Walk `prototypes.quality["normal"]` -> `.next`, skipping `hidden` (`"quality-unknown"` is
hidden and must be skipped). The schema marks `next` non-optional but the top tier logically
ends the chain — **nil-check it anyway** (§9).

`LuaForce.is_quality_unlocked(q)`, `unlock_quality`, `lock_quality`.
2.1.12 added `LuaQualityPrototype.roll_quality()`, 2.1.13 `get_roll_chances()` — engine-supplied
odds, better than any hardcoded table for a future "expected output" display.

## 8. Recycler and recycling-recipe ground truth

`data/recycler/data.lua`: `type = "furnace"`, name `"recycler"` (:99);
**`vector_to_place_result = {-0.35, -2.3}`** (:109);
`collision_box = {{-0.7,-1.7},{0.7,1.7}}` -> 2x4 (:138); `crafting_categories = {"recycling"}`
(:140); `crafting_speed = 0.5` (:143); **`module_slots = 4`** as a flat field (:152 —
`module_specification` does not exist anywhere in 2.1);
**`allowed_effects = {"consumption","speed","pollution","quality"}`** (:158 — no productivity).

Recycling recipes are generated at data-updates by the recycler mod
(`data/recycler/recycling.lua`, `data-updates.lua`). Three buckets:

1. **Ingredient reversal** — `<item>-recycling`, generated per recipe with exactly one
   fixed-amount item product, not already category `recycling`, not `auto_recycle = false`, and
   whose name does not contain both "science" and "pack" (a literal substring test,
   `recycling.lua:162-180`). Returns `floor(amount / (4 * result_count))` per item ingredient
   plus a fractional top-up via `extra_count_fraction` — exactly 25% on average. **Fluids are
   never returned.** `recycle_to_ingredients_of` (`recycling.lua:78`) can redirect which recipe
   gets reversed, which is how Wube pins multi-recipe products to one canonical reversal.
2. **Lossy self-recycle** — for items with no reversal: 25% chance of *itself*
   (`independent_probability = 0.25`). A quality re-roll shredder with no material recovery.
3. **True dead ends** — `auto_recycle = false` items, `-barrel` names, parameter items.

**Implication for the recipe picker:** requiring `prototypes.recipe[product .. "-recycling"]` to
exist *and* its results to equal the chosen recipe's item-ingredient set collapses all three
buckets into one correct gate — it rejects self-recyclers, dead ends, and the case where the
player picked a different recipe for the same product than the one the reversal was generated
from.

Recycle energy is `energy_required / 16 / result_count` (floored at 0.0011), and the formula
changed again in 2.1.13 — **read the generated recipe from `prototypes.recipe`, never
re-derive it.**

**Every generated recycling recipe is unlocked by the `recycling` technology at once**
(`add_recipe_unlock` appends an `unlock-recipe` effect per recipe, `recycling.lua`), including
recipes for items the force cannot craft. Two consequences, both verified in game 2026-08-15:

- **A recycling recipe must never count as evidence an item is buildable.** Reversal recipes
  *produce* every ingredient of the item they grind (`quality-module-3-recycling` produces
  quality-module-2), and self-recycling recipes produce the item itself — so with nothing but
  `recycling` researched, a producer scan that includes them reports unresearched module tiers
  and cheat items as unlocked. This shipped as two real bugs (see `../design.md`).
- **Cheat mods' items get self-recycling recipes too.** Editor Extensions never sets
  `auto_recycle = false`, and its only real recipes are disabled `ee-testing-tool` ones with
  empty ingredients (no reversal possible), so every EE chest and module self-recycles.

## 9. UNVERIFIED — probe these in game, do not assume

1. ~~`LuaLogisticPoint.trash_not_requested` writability on a ghost.~~ **Resolved 2026-08-15:
   writable on a ghost, and it survives being built.** So is `request_from_buffers`, which lives
   on **`LuaEntity`, not on the logistic point** — and reading it on a chest without request
   slots (a passive provider, say) is a hard error, *"Callable only on entities that have
   request slots"*, so only touch it on requesters.
2. ~~`LuaForce.is_quality_unlocked` return type~~ — the JSON's return_values array is empty,
   a doc-gen gap it shares with `is_space_location_unlocked`. **Resolved 2026-08-15: behaves
   as a boolean** — the researched-only quality list is driven by it, and the live harness saw
   that list shrink and grow correctly across research states.
3. `SelectionModeData mode = {"nothing"}` — whether `on_player_selected_area` still fires. The
   design uses `{"any-tile"}` to avoid needing the answer.
4. `PipeConnectionDefinition.positions` index-to-direction mapping (N/E/S/W order is a reading,
   not a documented guarantee). Only matters when fluids land.
5. ~~Filter slots per inserter prototype.~~ **Resolved 2026-08-15: it is a planner
   validation.** The runtime attribute is `LuaEntityPrototype.filter_count` (nil on
   non-filtering kinds); `planner.inserter(force, filters_needed)` requires it, and validate
   answers `too-many-ingredients` when no researched inserter has enough slots.
6. **The recycler eject's runtime stall-and-resume semantics** when the target machine rejects
   the front item. Assumed from mining-drill behaviour; the reference designs ship widely and
   depend on it. This is the one to watch in the first in-game test.
7. `LuaQualityPrototype.next` nil-ability at the top of the chain.
