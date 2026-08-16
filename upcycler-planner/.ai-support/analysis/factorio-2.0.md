---
verified_against: 2.0.77
verified: 2026-08-16
---
# Factorio 2.0 — the API surface this mod touches

Checked against the 2.0 SA Stable install's own `doc-html/runtime-api.json`,
`doc-html/prototype-api.json` and `data/*.lua` (base 2.0.77), the day the 2.0 port was made.
`api.md` stays the 2.1 reference; this file records only where 2.0 agrees or differs, so the
forked files on `legacy/2.0` can be maintained without re-deriving any of it. The port's
end-to-end proof is the `--create` harness run of 2026-08-16: 38/38 on 2.0.77 against 37/37 on
2.1.14, with byte-equivalent plans placed and read back on each (`../journal.md`).

## The three real differences

1. **`LuaRecipePrototype` has no `categories` attribute on 2.0** — the shape is one `category`
   string plus `additional_categories` (an array; guarded with `or {}` since its optionality
   was not pinned down). Both `LuaRecipe` and `LuaRecipePrototype` carry the pair. Reading a
   `LuaObject` attribute the running version lacks is a **hard error, not nil** — which is why
   the branches fork `planner.lua` outright: `main` reads `categories`, the legacy copy reads
   the 2.0 pair, and a cherry-pick must not carry either read across.
2. **`can_set_quality` does not exist anywhere in the 2.0 runtime API**, and the data-stage
   `allow_quality` (present on 2.0's `RecipePrototype`, default true) has no runtime mirror.
   The bridge: the legacy-only `data-final-fixes.lua` writes a `mod-data` prototype
   (`upl-no-quality-recipes`) listing every recipe with `allow_quality == false`, and the
   legacy `planner.lua` reads it via `prototypes.mod_data[...].get(name)` — 2.0.77's
   `LuaModData` exposes `get(key)` ("partial access", no full-table deserialisation per
   lookup). `mod-data` itself exists since 2.0.58, so 2.0.77 is safely above the floor.
   Vanilla 2.0 sets the flag on the oil-cracking pair, `lubricant`, the oil-processing recipes
   and one base catalyst recipe — all of which the fluid gate refuses anyway, so the bridge's
   real audience is modded games.
   **Known gap, accepted:** a mod whose own `data-final-fixes` runs after ours (load order)
   and sets `allow_quality = false` is missed by the bridge; 2.1's runtime read has no such
   gap.
3. **`util.contains_value` is not in 2.0's `core/lualib/util.lua`** (2.1 added it at line
   809). The legacy `gui.lua` carries a local copy with identical semantics; `main` keeps
   calling util's. `util.list_to_map` exists in both.

## Identical on 2.0.77 — verified, nothing to port

- **`defines.inventory.crafter_modules` already exists in 2.0**; `assembling_machine_modules`
  / `furnace_modules` are present but marked *"Deprecated, replaced by crafter_modules"* in
  2.0's own docs. The 2.1 removal completed a 2.0-era deprecation, so the unified define is
  the right spelling on both.
- **`LuaEntity.insert_plan`**: read *and* write, subclasses `["EntityGhost","ItemRequestProxy"]`
  — same contract as 2.1.
- **The logistic-request machinery**: `get_logistic_point`,
  `defines.logistic_member_index.logistic_container`, `sections` / `add_section` /
  `is_manual` / `set_slot`, `trash_not_requested`, `request_from_buffers` — all present. The
  quality-mandatory-with-min rule on `SignalFilter` is 2.0 behaviour too (quality requests are
  engine-exact on both).
- **Ghost plumbing**: `set_recipe(recipe, quality)`, `use_filters`, `set_filter` with
  `{name, quality, comparator}`, `inserter_filter_mode`,
  `get_wire_connector(defines.wire_connector_id.pole_copper, true).connect_to(...)`,
  `connection_count` / `connections`, `create_entity` with `quality` / `raise_built` /
  `player`, `defines.build_check_type.manual_ghost` with `forced`.
- **Quality-parameterised getters**: `get_crafting_speed(quality?)`,
  `get_inventory_size(index, quality?)`, `get_supply_area_distance`, `get_max_wire_distance`,
  `get_inserter_rotation_speed` — same signatures.
- **Prototype attributes the planner scans**: `allowed_effects` on entity **and** recipe,
  `allowed_module_categories`, `module_inventory_size`, `items_to_place_this`, `filter_count`,
  `bulk`, `inserter_pickup_position` / `inserter_drop_position`, `vector_to_place_result`,
  energy-source prototypes, `hidden_from_player_crafting`, `hidden_in_factoriopedia`,
  `module_effects`, `LuaForce.is_quality_unlocked`, `prototypes.quality` with `next` /
  `level`.
- **GUI**: elem types `entity-with-quality` / `item-with-quality`; `ItemPrototypeFilter` /
  `EntityPrototypeFilter` `name` filters accept arrays ("The prototype name, or list of
  acceptable names"); the `crafting-category` entity filter exists.
- **Events**: `on_player_selected_area` payload has the same fields (`item` is a plain string
  in both); every other event the mod registers predates 2.0.
- **Data stage**: `SelectionModeData` with `select` / `alt_select` and `"any-tile"`; shortcut
  `technology_to_unlock` + `unavailable_until_unlocked` + `style` + layered `icons` /
  `small_icons`; the same item flags; `IconData::scale` expected sizes are **32 / 24** for a
  shortcut's `icons` / `small_icons` on 2.0 too, so `icons.lua`'s fraction maths is
  version-independent.

## 2.0 recycler ground truth

`data/quality/prototypes/entity/entity.lua` (the recycler lives in `quality` on 2.0 — there is
no `recycler` mod):

- `type = "furnace"`, name `"recycler"`, **`vector_to_place_result = {-0.5, -2.3}`** (2.1 has
  `{-0.35, -2.3}`; `recycler_orientation` computes north / 2x4 / `eject_col = 0` from both, so
  the layout is unchanged).
- `crafting_categories = {"recycling", "recycling-or-hand-crafting"}` — the extra category is
  harmless to `planner.recyclers()`, which tests membership of `"recycling"`.
- `module_slots = 4` (flat field, as on 2.1), `allowed_effects` includes `"quality"`, electric
  energy source.
- Icon: `__quality__/graphics/icons/recycler.png`, the **same 120x64 mipmapped strip** as
  2.1's `__recycler__` copy — why `icons.lua` only swaps the mod prefix.
- The `recycling` **technology** is `data/quality/prototypes/technology.lua:148`, same name as
  2.1's, so the shortcut gate carries over.
- Recycling recipes are generated in `data/quality/prototypes/recycling.lua` with
  `category = "recycling"`, named `<item>-recycling`, skipping recipes already in the
  category — the same three-bucket scheme `api.md` §8 describes for 2.1.

## Version-scale differences that deliberately do not matter here

Marked so nobody ports a fix for them: **quality effect values are ×10 on 2.0** (real chance =
`effect.quality * next_probability`, with `next_probability = 0.1`) — this mod only *ranks*
modules by effect size and never converts to a chance, so the scale cancels; and the
`ModulePrototype::*_quality_multiplier` family is 2.1-only — this mod ships no modules, so
nothing to gate. If an expected-output display ever lands (`../deferred.md`), **that** feature
must handle the scale seam, ideally via `get_roll_chances()`, which is 2.1.13-only — the
display would need its own 2.0 answer.

## UNVERIFIED on 2.0

- Whether `set_recipe(recipe, quality)` on a ghost errors or quietly ignores the quality for a
  recipe whose `allow_quality` is false — the bridge exists so the planner never asks.
- The GUI (`gui.lua`) has not been opened on 2.0 any more than on 2.1 — no headless path to a
  player exists on either. The 2.0 fork adds no GUI-side code beyond the `contains_value`
  local, so the standing first-open checklist in `../journal.md` applies unchanged.
