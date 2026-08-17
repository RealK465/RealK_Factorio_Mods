---
verified_against: 2.1.14
verified: 2026-08-17
---
# Verified API reference

Checked against the installed 2.1.14's own `doc-html/runtime-api.json`,
`doc-html/prototype-api.json` and `data/*.lua`. The JSON files are minified, so citations are
`Class::member` rather than line numbers; game-data citations give file:line.

**This supersedes the API table in `../journal.md`** (2026-08-15, feasibility investigation),
**which had two errors** — both corrected in §3 below.

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
  them explicitly. A layered `icons` table needs more than that — see §11.
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
  **`inserter_max_belt_stack_size`** (Inserter subclass, optional uint8) is the belt-stacking
  tell: above 1 the prototype can build belt stacks, and the planner excludes such inserters
  outright (the reason — community-documented stalls in quality loops — is in
  `../decisions.md`). The exclusion cannot ride on `bulk`, because vanilla's bulk-inserter and
  Space Age's stack-inserter tie the pick exactly: both `bulk = true`
  (`data/base/prototypes/entity/entities.lua:5480`,
  `data/space-age/prototypes/entity/entities.lua:2682`), both `rotation_speed = 0.04`
  (base :5507, space-age :2714), and only the stack-inserter carries
  `max_belt_stack_size = 4` (space-age :2686).
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
2.1.7 added the `chain_probability` / `previous_probability` read family (the roll rework's
runtime mirror — `quality-math.md` §1); 2.1.12 added `LuaQualityPrototype.roll_quality()`,
2.1.13 `get_roll_chances()` — engine-supplied odds, better than any hardcoded table for a
future "expected output" display. All three versions confirmed against the installed
`data/changelog.txt` (2026-08-17).

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
  and cheat items as unlocked. This shipped as two real bugs (see `../journal.md`, 2026-08-15,
  building materials are gated by real research).
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
4. ~~`PipeConnectionDefinition.positions` index-to-direction mapping.~~ **Resolved 2026-08-17,
   measured: `positions` IS the [N, E, S, W] rotation orbit** — AM2's input reads back
   `{0,-1} {1,0} {0,1} {-1,0}`, the clockwise `(x,y) → (-y,x)` sequence. Full fluid-box
   findings in §14; a loud premise assert in `tests/fluid_spec.lua` guards it.
5. ~~Filter slots per inserter prototype.~~ **Resolved 2026-08-15: it is a planner
   validation.** The runtime attribute is `LuaEntityPrototype.filter_count` (nil on
   non-filtering kinds); `planner.inserter(force, filters_needed)` requires it, and validate
   answers `too-many-ingredients` when no researched inserter has enough slots.
6. ~~The recycler eject's runtime stall-and-resume semantics when the target machine rejects
   the front item.~~ **Resolved 2026-08-16, measured by the permanent suite**
   (`tests/loop_spec.lua`: real revived machine + tangent recycler, powered, 40 gears, 900
   ticks). Worse than the polite stall that was assumed: an above-tier item in the recycler's
   **output wedges the recycler entirely** — furnace output semantics, the next result cannot
   merge with the differently-qualitied stack, so no craft ever starts (`products_finished`
   stayed 0 on both buildings) and the eject never gets a chance to bypass it. **The blacklist
   relief inserter is therefore load-bearing, not a safety net**: with it present the stuck
   item drained to the chest, the recycler processed all 40 gears and the machine crafted on.
   In both arrangements nothing was lost and nothing wrong-quality reached the pinned machine.
   Deterministic seeding for the suite: a script `insert` into
   `defines.inventory.crafter_output` works on a recycler (2.1.14) and stands in for a lucky
   roll.
7. `LuaQualityPrototype.next` nil-ability at the top of the chain.

## 10. Electric poles and wires — verified 2026-08-16

All measured with the pole-placement harness (real game via `--create`, full research, real
entities and ghosts on real ground, 28/28). Numbered after §9 so the section references
elsewhere stay stable; §9 remains the running unverified list.

1. **The powering rule is collision-box OVERLAP with the supply square.** With a medium
   pole's 7x7 area, an assembling machine placed so its collision box straddles the area's
   edge — centre *outside* — reads the pole's own `electric_network_id`. Fully outside reads
   nil, as does an inserter whose collision box sits just past the edge. Any positive overlap
   powers the consumer; `poles.lua`'s `covers()` implements exactly this, shrinking each
   consumer's tile rect by its own prototype's collision-box inset on the larger axis
   (vanilla machines and the recycler 0.3, inserters 0.35), so the stand-in is a subset of
   the real box and can only under-promise.
2. **`supply_area_distance` is a radius from the pole's centre** (area `2d x 2d`, the
   substation's 9 giving 18x18), and **quality scales it unconditionally**: `+level` supply,
   `+2*level` wire reach (levels: uncommon 1, rare 2, epic 3, legendary 5 — 4 is skipped).
   Read via `LuaEntityPrototype.get_supply_area_distance(quality)` /
   `get_max_wire_distance(quality)` — the same quality-parameterised-getter family as
   `get_crafting_speed`. A legendary medium pole covers 17x17: one powers the whole rare
   belt ring where normal quality needs five.
3. **Revived pole ghosts auto-connect to poles within wire reach.** Two bare ghosts with no
   ghost wire, revived, came back wired. The explicit ghost wires the builder draws are for
   the preview and for pinning the intended spanning tree, not load-bearing against vanilla.
4. **Ghost-to-ghost copper wiring works, but `connect_to` RETURNS FALSE while creating the
   wire.** `get_wire_connector(defines.wire_connector_id.pole_copper, true).connect_to(other)`
   between two pole ghosts: return value false, yet the connector's `connections` gains the
   ghost wire and it turns into a `real_connections` entry once both revive. Do not branch on
   the return value for ghost wires; `builder.lua` ignores it on purpose.

## 11. Icon layers scale against the PROTOTYPE, not the file — verified 2026-08-16

`IconData::scale` doc verbatim: *"Defaults to `(expected_icon_size / 2) / icon_size`"*, and the
expected sizes it lists are **`32` for `ShortcutPrototype::icons`, `24` for `small_icons`, `256`
for technologies, `128` for achievements and item groups, `64` for everything else**.
`IconData::shift` is measured in the same space: *"the overall icon is assumed to be
`expected_icon_size / 2` pixels in width and height"*.

So an explicit `scale` or `shift` means **different things on different prototypes**, and one
layer table cannot be shared between an item and a shortcut. This mod shared one from its first prototypes:
`scale = 0.28`, `shift = {8, 8}` on the quality pip read as 56% of the icon at the corner on the
selection tool (expected 64) and as **wider than the entire button, shifted half an icon out of
frame**, on the shortcut (expected 32). Confirmed by dumping both:

```
factorio.exe --config <scratch>\config.ini --dump-icon-sprites --mod-directory <staged copy>
```

which writes the **engine's own composition** to `script-output/<prototype-type>/<name>.png` —
`shortcut/upl-open.png` and `item/upl-planner.png` here. It needs a graphical run (not
`--dump-data`), takes about 50 s, and is the only way to see a layered icon without opening the
game. Vanilla shortcuts dump at 24x24; a broken one dumps far larger, so the file size alone is
a smell.

**The composed bounding box is what gets fitted to the button**, so an oversized or far-shifted
layer does not merely overhang — it shrinks every other layer. That is why the old shortcut drew
the recycler at about half the button: the pip had grown the box to 121x121 where a vanilla
shortcut dumps 24x24.

**And the box only grows one way.** A POSITIVE shift extends it; a NEGATIVE shift pushes the
layer off the canvas and the overhang is **clipped**. Measured 2026-08-16: two layers leaning
away from each other (`-0.20` and `+0.2125` of the icon) dumped 102x102 with content ending at
(86, 88) — empty margin bottom-right, and the recycler cut down to a sliver top-left. Sliding
the same arrangement so the lower shift is 0 kept both symbols whole. So compose from a corner,
never symmetrically about the centre.

The fix in `prototypes/planner/icons.lua`: write the composition once as fractions of one icon,
then resolve per consumer — `unit = expected / 2` shift units to the icon, `base = unit / 64` for
a 64px file's scale. Keeping both layers inside the icon is what keeps the box tight.

## 12. Headless runs have a connected player — verified 2026-08-16

**A singleplayer save's player stays flagged connected under `--benchmark`.** No client
attaches, yet `#game.connected_players == 1`, and that player's `gui.screen`, `cursor_stack`,
`mod_settings` and `clear_cursor()` all behave — the whole `gui_spec` suite (modal built,
handlers driven through the dispatcher, Confirm arming the tool into the cursor) passes in a
headless run of the factorio-test CLI's bundled save. Measured 2.1.14, factorio-test 3.1.0.

This overturns the long-standing working assumption here that *"there is no way to create a
player without a client"* — still true for `--create` (which joins nobody), but a save that
already **carries** a player is enough, and headless GUI testing follows. The one caveat: the
player comes from the framework's bundled save, an external artifact — the specs'
`before_all` asserts a connected player exists and says what to do when it does not.


## 13. Space Age feature flags — the set forks between 2.0 and 2.1, verified 2026-08-16

**`expansion_required` does not exist in Factorio 2.0.** The flag set is not the same on both
tracks, which matters because a flag the game does not know is *silently ignored* rather than
rejected — it would sit in `info.json` looking like a gate and enforcing nothing.

The engine enumerates its flags at startup, and the two versions disagree by exactly one:

| Install | Flags logged by `ModManager.cpp` |
|---|---|
| 2.1.14 | `expansion`, `expansion-shaders`, `freezing`, `quality`, `rail-bridges`, `segmented-units`, `space-travel`, `spoiling` — **eight** |
| 2.0.77 | the same **minus `expansion`** — **seven** |

Vanilla's own `quality/info.json` matches: 2.1's declares `expansion_required` **and**
`quality_required`, 2.0's declares only `quality_required`.

**Measured, not inferred.** Four one-file probe mods (`info.json` only, a single flag, no
`quality` dependency) run through `validate.ps1` against the no-expansion installs:

| Probe | 2.1 Vanilla | 2.0 Vanilla |
|---|---|---|
| `quality_required` | **refused** — `ModManager::enterMinimalMode` | **refused** — `ModManager::loadData` |
| `expansion_required` | — | **loaded clean, exit 0** |

Controls: the same `quality_required` probe loads clean on the 2.1 SA install (`Checksum of
ff-probe: 0`), so the probes are well-formed and ownership is the only variable. A refusal
surfaces as a *crash* under `--dump-data`, not a tidy message — there is no GUI to fall back
to — so read the stack trace, not the exit code alone.

Two consequences worth not re-deriving:

- **Any one expansion flag makes the expansion mandatory**, and no flag is needed for the mod
  to *consume* quality at runtime. This mod declares none of the prototype properties the
  flags unlock; the flags are here as an ownership gate and a portal marker.
- **The mod portal's "Space Age" tag keys off the expansion flags in the uploaded
  `info.json`, not the dependency list** — so a mod depending on `quality` alone is *not*
  tagged. Wube's statement names the flags collectively ("*the expansion flags (eg,
  `space_travel_required`)*", forum `p=698604`), with `quality_required` among the DLC's own
  set. **Confirmed for this mod on 2026-08-16**: after uploading 0.1.4/0.1.5 the public page
  carries a **"Space Age Mod"** label, so `quality_required` alone is enough to earn the tag —
  `space_travel_required` is not required for it, and would be a false claim here since it
  unlocks planet and space-platform prototypes this mod never touches. Note the tag is visible
  only on the **HTML page**: no endpoint of the JSON API exposes a feature-flag or tag field,
  which is why this could not be checked before the upload.

## 14. Fluid boxes, pipe connections and the rotation rule — measured 2026-08-17

Everything the fluid feature stands on, measured with an in-game probe spec (headless suite,
full research, real entities and ticks) plus the installed `prototype-api.json` /
`runtime-api.json` and `data/*.lua`. The functional halves are guarded permanently by
`tests/fluid_spec.lua`.

1. **`LuaFluidBoxPrototype.pipe_connections[].positions` is the [N, E, S, W] rotation orbit**
   (§9.4 resolved). Each runtime connection also carries `direction` — the authored compass
   point, equal in meaning to `positions[1]` — and `connection_type` / `max_underground_distance`.
2. **A connection authored pointing `dir` points `(dir + entity_direction) % 16` once the
   entity is rotated.** That makes the machine-orientation question pure direction arithmetic:
   a rotation serves the pipe run iff some input connection satisfies
   `(dir + rotation) % 16 == defines.direction.west`. `planner.machine_fluid_orientation()`
   implements exactly this, trying north first.
3. **The engine merges the input boxes a recipe needs into ONE live fluid box exposing ALL
   their connection points, and feeding ANY of them feeds the machine.** Measured twice: a
   west-facing chemical plant with `battery` set shows `fluids_count == 1` with both west-face
   corner connections on the one box; an UNROTATED electromagnetic plant (inputs authored on
   OPPOSITE flanks, west dir=12 and east dir=4) crafted supercapacitors from a west-side pipe
   run alone. Output boxes did not materialise at all for a fluid-input-only recipe — even on
   the chemical plant, the one vanilla machine without `fluid_boxes_off_when_no_fluid_recipe`.
4. **Vanilla input authoring, and the rotation each machine gets**: AM2/AM3 north-centre → face
   west; chemical plant and biochamber north corners → west; foundry and cryogenic plant
   author their inputs on the SOUTH face → face EAST; the EM plant already has a west input →
   stays north. `IngredientPrototype.fluidbox_index` exists in the schema but is nil on every
   vanilla fluid recipe checked — the merge rule above is what carries the day instead.
5. **Pipe-to-ground**: 1x1; the surface opening faces the entity's `direction` and the
   underground run extends the opposite way (`pipe_connections`: normal north + underground
   south, `max_underground_distance = 10`, readable at runtime as
   `LuaEntityPrototype.max_underground_distance`). A pair with openings facing AWAY from each
   other joins underground, and a lone stub is simply an offered connection until a partner
   appears — the layout's outward stubs beneath the ring belts lean on exactly that, proven
   live: a player-side underground pipe one tile outside the ring fed a rotated chemical
   plant through the plan's stub and it crafted.
6. **A script ghost keeps its `direction` alongside a fluid recipe** — `create_entity` with
   `direction = west` plus `set_recipe("battery")` reads back facing west — and a placed
   battery plan revived whole crafts from an outside tap on one stub, which pins the
   planner→layout→builder chain end to end.

## 15. Quality on inserters and chests, and what a picker may offer — measured 2026-08-17

Everything here was read from the installed 2.1.14's own files or from its `--dump-data` output;
nothing is recalled.

**Quality bonuses have a documented exception list, and it is short.**
`data/quality/locale/en/quality.cfg` → `tips-and-tricks-item-description.quality-bonus-exceptions`
names exactly three: transport belt, pipe, straight rail. Everything else *"gets its own unique
bonus"*. **Confidence: verified** — it is the game's own player-facing text, and it matches the
one belt fact this mod already measured (`belt_speed` has no quality variant).

**A chest's bonus is inventory size, and it is on by default.**
`ContainerPrototype::quality_affects_inventory_size` has `"default": true` in
`prototype-api.json`, and `LogisticContainerPrototype` inherits it. Base never sets it — the only
`quality_affects_*` assignments in `data/quality/prototypes/base-data-updates.lua` are the cargo
wagon's inventory and the fluid wagon's capacity — so vanilla chests carry the bonus *because of
the default*, not because anyone opted in. Read it per quality with
`get_inventory_size(defines.inventory.chest, quality)`. **Confidence: verified from the property
default; the resulting slot count per tier was not measured**, and does not matter here — the
default pick ranks chests at normal, which is quality-invariant when every chest scales alike.

**An inserter's bonus is swing speed**, read with `get_inserter_rotation_speed(quality)` (the
method takes an optional quality; the `rotation_speed` *attribute* is for cars and turrets and
reads nil on an inserter). **Confidence: verified that the API is quality-aware and that
inserters are not on the exception list; the per-tier multiplier was not measured.**

**Filter slots do not scale with quality.** `filter_count` is a plain `InserterPrototype`
property, default 0, and **every one of the six vanilla inserters sets it to 5** (base
`entities.lua`, space-age `transport-belts.lua`). So the loop's one-slot-per-ingredient
requirement can only be outrun by a recipe, never fixed by a better quality.

**Exactly one vanilla upcyclable recipe needs more than five filter slots.** Counted over the
whole `data-raw-dump.json`: recipes with ≥ 6 *item* ingredients, a single fixed item product, and
a `<product>-recycling` recipe whose products are exactly that ingredient set — one hit,
`fusion-reactor-equipment` (6: fission reactor equipment, fusion power cell, tungsten plate,
carbon fiber, supercapacitor, quantum processor). **Confidence: verified against the dump**, and
it is what `planner_spec` uses to reach the filter-slot refusal without a fixture mod.

**Base ships 1x1 containers no item can place.** `red-chest`, `blue-chest`, `crash-site-chest-1`
and `crash-site-chest-2` are `type = "container"` with a 0.7x0.7 collision box and **no
`place_result` item anywhere in the dump** (the logo and spaceship-wreck containers are the same
but are larger than one tile, so a footprint test already excludes them). A 1x1 test alone
therefore admits scenery: the picker lists gate on `items_to_place_this ~= nil`, which is the
same gate `is_upcycling_machine` has always used. **Confidence: verified against the dump.**

## 16. What a machine or recipe accepts a module for — measured 2026-08-17

The question: `allowed_effects` lists the effects a machine permits, and a module carries several
at once — a productivity module 3 is `productivity +0.1, consumption +0.8, pollution +0.1,
speed -0.15`. Is a module refused when **any** of its effects is missing from the list, or only
some of them? The two readings disagree about real vanilla pairs, so it was measured rather than
reasoned: a throwaway spec created each holder, called
`get_module_inventory().can_insert()` and then actually inserted, and read the result back.

| holder | allows | speed-3 | productivity-3 | quality-3 | efficiency-3 |
|---|---|---|---|---|---|
| `oil-refinery` | consumption, pollution, productivity, speed | **yes** | yes | **no** | yes |
| `recycler` | consumption, pollution, quality, speed | yes | **no** | yes | yes |
| `assembling-machine-3` | + quality + productivity | yes | yes | yes | yes |
| `electric-furnace` | same as AM3 | yes | yes | yes | yes |

**The rule is: every effect the module applies with a POSITIVE value must be allowed; a negative
component on a disallowed effect is ignored.** The refinery takes a speed module whose
`quality` component is `-0.025` while refusing a quality module whose `quality` is `+0.025`, and
the recycler refuses productivity for the same reason. `can_insert` and the actual insert agreed
in all sixteen cases. **Confidence: verified by measurement on 2.1.14**, headless.

A second reading fits the same sixteen results — "the effect named by the module's *category*
must be allowed" — and vanilla cannot separate the two, because no vanilla module has a positive
effect outside its own category. The positive-effect rule is implemented because it needs no
category-to-effect name mapping (vanilla's `efficiency` category has no matching effect name at
all, and a modded category could be called anything), and because where the two disagree it is
the **conservative** one: it declines to offer a module the engine might refuse, rather than
planning an insert plan that can never be filled.

Two facts worth having beside it, both from the same dump:

- **No vanilla recipe restricts anything.** Zero of them set `allowed_effects` or
  `allowed_module_categories`; the recipe-side restriction is a modded-only concern. What recipes
  *do* set is `allow_productivity`, which lands in `allowed_effects` — false by default, which is
  why the top machine is planned empty for most recipes.
- **No vanilla crafting machine restricts categories** either — every `allowed_module_categories`
  is nil, i.e. all allowed. So in a vanilla game the category half of the rule never fires, and
  the effect half does all the work.

## 17. Per-player settings a mod may write, and who owns `player.opened` — measured 2026-08-17

Three questions the settings window rests on, each settled by a throwaway spec run against the
real engine rather than by reading the docs twice. All three **measured**, headless, 2.1.14.

- **A mod can write its own per-player setting at runtime.** `LuaPlayer::mod_settings` is marked
  read-only, and its own description says the exception out loud: *"individual settings can be
  changed by overwriting their ModSetting table. Mods can only change their own settings."*
  `player.mod_settings["upcycler-planner-show-all"] = { value = true }` takes effect immediately
  and reads back changed. This is what lets a GUI edit a setting instead of shadowing it in
  `storage`.
- **That write raises `on_runtime_mod_setting_changed`**, identically to a change made in the
  game's own settings menu. Measured through the effect rather than by registering a second
  handler — which would have *replaced* the mod's own, silently: with the modal open, writing the
  setting destroyed the frame, i.e. the mod's existing handler had run and rebuilt it. So a
  checkbox handler should write the setting and stop; one repaint path then serves both surfaces.
- **Assigning `player.opened` a second frame asks the first one to close, and that reaches
  `on_gui_closed`.** The docs say *"If this attribute is non-nil, then writing `nil` or a new GUI
  to it will ask the existing GUI to close"*; what they do not say is that a handler destroying
  its frame on that event will therefore destroy it when a *nested* window opens. Measured: with
  the modal owning `opened`, handing `opened` to another frame left the modal destroyed. Any
  nested window therefore needs a guard on the parent's close handler. The engine also **nils
  `opened`** when a window closes, so focus has to be handed back explicitly or Esc stops working
  — Factory Planner's `modal_dialog.lua` carries that exact comment beside the exact same line.

## 18. A frame action button inverts its own glyph on hover — game data, 2026-08-17

**The mod no longer ships a titlebar icon** — the settings button is captioned (`decisions.md`),
and the `upl-preferences` sprite this was measured on was deleted with it on 2026-08-17. Kept
because the finding is about the *style*, not about that sprite: it is the answer for the next
icon button anyone puts in a frame's titlebar here, and it explains why vanilla's own are white.

**Verified in game data, and by a real-client run.** `frame_action_button` sets
`invert_colors_of_picture_when_hovered_or_toggled = true`
(`data/core/prototypes/style.lua:2797`; the property is `ButtonStyleSpecification::
invert_colors_of_picture_when_hovered_or_toggled`). So the style, not the sprite, supplies the
second state — which decides what a titlebar glyph has to look like at rest:

- **The glyph must be WHITE.** `core/graphics/icons/close.png` is a white X, and the style darkens
  it on hover. Hand the same button a *black* glyph and it reads exactly backwards: dark at rest,
  white under the cursor. `core/graphics/icons/mip/preset.png` — the settings sliders, and the
  nearest thing to a gear the base game ships — is black, which is how this was found.
- **`invert_colors` on a sprite prototype is the cheap fix**, and the loader really does read it:
  a `--check-unused-prototype-data` run reported **zero** unused properties for the sprite it was
  measured on, which is the check that separates "applied" from "silently ignored" for any
  property. It inverts RGB and leaves alpha alone, so a black glyph on
  transparency becomes a white one (checked against the file itself, both mip levels).
- **A bare prototype name is a legal `SpritePath`** — *"either the name of a SpritePrototype
  defined in the data stage, or a path in form type/name"* — so a `sprite` naming one directly needed
  no prefix. Proven in a real client while the mod shipped one: every GUI spec built that
  titlebar, and the sprite resolved.

**The trap this cost an error to learn, and it is a dev-loop trap, not a mod bug.** Prototypes are
read **once, at process startup**; loading a save re-runs `control.lua` from disk but never the
data stage. So a running game that picks up new control code while keeping its old prototype set
fails with `Unknown sprite "<name>"` on a sprite the data stage plainly defines. **Restart the game
after adding any prototype** — reloading the save is not enough, and no player can ever hit this
because their code and prototypes always come from one startup.

## 19. GUI geometry: what can be read, when, and how a table treats a hidden child — measured 2026-08-17

**Measured in a real client** (graphics tier, 2560x1440 at display_scale 1.25), because none of it
is observable headless: a headless run never lays a frame out.

- **Nothing reads an element's rendered size.** `LuaGuiElement` offers `location` and `anchor` and
  no dimensions at all, and `anchor` only pins a `gui.relative` element to one of the game's own
  windows — it cannot align to another mod's frame. Factory Planner tracks its own dimensions for
  exactly this reason.
- **An auto-centered frame's `location` IS its size**, which is the way out: auto_center puts a
  frame at `(resolution - size) / 2`, so `size = resolution - 2 * location`. Locale-proof, unlike
  a hardcoded width.
- **`location` reads 0,0 until the frame has been laid out**, which is the tick *after* it is
  built. Measured: a frame read in the same handler that created it gave `0,0`; five ticks later
  the same frame gave `1087,415`. So a position can only be measured off a frame already on
  screen — reading it during a rebuild yields zero, and a width computed from that puts the
  neighbour off the screen (which is exactly what happened before the guard went in).
- **A hidden child takes no cell in a `table`.** The build-options grid is `column_count = 6` with
  nine pickers, three of them `visible = false` in a vanilla modset. Frame heights, from the
  centred-location measurement: **six visible = 610px, all nine = 720px**. The 110px is one extra
  strip row plus the recycler row returning — if hidden children held their cells both states
  would have been two rows and identical. Confirmed by screenshot: one row of six, no gaps, and
  6 + 3 when all nine show. `visible`'s documented *"taking no space in the layout"* extends to a
  table cell, so a grid needs no filtering to stay dense.
- **`game.take_screenshot{show_gui = true}` works in the graphics test tier** and is the only way
  to *see* a GUI, but two overlays sit on top of it: the framework prints every result to the
  console, and `research_all_technologies()` raises a long queue of achievement toasts that draw
  over the middle of the screen and outlast a 600-tick wait. `player.clear_console()` handles the
  first; the second only clears by running the screenshot spec on its own, with no research.

## 20. A click on a choose-elem-button reaches the handler before the chooser opens — measured 2026-08-17

**Measured in a real client, by breaking it.** `control.lua` routes `on_gui_click` and
`on_gui_elem_changed` to one dispatcher, so a picker's handler runs for both — and the click
arrives *while the engine is opening the element's own chooser window*.

- **The click carries the value already in the button**, not a new one. A handler that cannot tell
  a click from a pick will therefore re-apply the current value on every click.
- **Destroying the element during that click destroys the chooser with it.** The modal's recipe
  and machine handlers were changed to rebuild the modal rather than repaint widgets by hand; the
  rebuild destroys the button, and the picker then flashes open and vanishes in the same frame.
  Reported from the game as *"it opens and closes instantly"* — there is no error and nothing in
  the log.
- **The fix that keeps both properties is an equality guard**: do nothing unless the value
  actually changed. It needs no event-name test, so the specs can still drive the dispatcher with
  a hand-shaped event. Compare against the *normalised* stored value — the button always reports a
  quality, and the stored one is nil until the player picks a tier, so a raw comparison reads
  every first click as a change.

**A frame's width can only be inferred while it is centred, and the player can drag it.** §19's
`size = resolution - 2 * location` is exact for an auto-centred frame and silently wrong for a
moved one: dragged left it overshoots, dragged right it goes negative. Neither is detectable
directly, but both leave the range a real frame can occupy — so the mod keeps the last
*plausible* measurement per player and reuses it, rather than trusting each reading.
