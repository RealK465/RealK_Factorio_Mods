---
verified_against: 2.0.77
verified: 2026-08-17
---
# Factorio 2.0 — the API surface this mod touches

Checked against the 2.0 SA Stable install's own `doc-html/runtime-api.json`,
`doc-html/prototype-api.json` and `data/*.lua` (base 2.0.77), the day the 2.0 port was made.
`api.md` stays the 2.1 reference; this file records only where 2.0 agrees or differs, so the
forked files on `legacy/2.0` can be maintained without re-deriving any of it. The port's
end-to-end proof is the `--create` harness run of 2026-08-16: 38/38 on 2.0.77 against 37/37 on
2.1.14, with byte-equivalent plans placed and read back on each (`../journal.md`).

## The four real differences

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
4. **`LuaFluidBoxPrototype.volume` is the attribute on 2.0; `get_volume()` arrives with
   2.1.7.** The one seam the 0.2.0 fluid feature added (2026-08-17): `planner.pipe()` scores
   pipes by volume, so the legacy copy reads `box.volume` where `main` calls
   `box.get_volume("normal")`. Everything else the feature reads — `fluidbox_prototypes`,
   `pipe_connections` with `direction` / `positions` / `connection_type`, `production_type`,
   `LuaEntityPrototype.max_underground_distance` — is identical at 2.0.77, checked against
   this install's own `runtime-api.json`.

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

## Measured identical on 2.0.77 — the fluid feature's engine behaviour

The class-3 questions the 0.2.0 port raised were answered by running the suite on this
install (90/90, 2026-08-17), not by assuming: the engine merges a recipe's input boxes into
one live box on 2.0 exactly as `api.md` §14 measures for 2.1 (the unrotated EM plant crafts
from a west-side run), a player-side underground tap through the ring belt feeds the run, a
script ghost keeps its direction beside a fluid recipe, and the placed-revived battery plan
crafts. The machine orientation table (AM west, chem/bio west, foundry/cryo east, EM north)
reads identically from 2.0's data. **The 2.0 track offers 212 upcyclable items** with fluids
admitted, against 2.1's 210 — the forked `planner_spec` pin.

## The 0.3.0 GUI work ports unchanged — verified 2026-08-17

Checked when the settings window, its titlebar button and the six-column grid were built
against 2.1 (`api.md` §17–19), so the backport does not have to discover it: **every mechanism they
rest on exists on 2.0.77, with the same names and the same documented wording.** Nothing in that
feature set needs a forked file beyond the ones already forked.

- **`frame_button` exists, with the same graphical sets** (`data/core/prototypes/style.lua:2744`,
  against 2.1's :2754), and `LuaStyle` carries `minimal_width`, `height`, `padding` and `font` —
  so the captioned Settings button ports verbatim, sizing included.
- **`frame_action_button` inverts its picture on hover here too** —
  `invert_colors_of_picture_when_hovered_or_toggled = true` at
  `data/core/prototypes/style.lua:2787`, inside the block opening at :2783 (2.1: the same property
  at :2797). Nothing here depends on it now that the button is captioned; it is why the close X is
  white, and what an icon button on this track would have to obey.
- **`LuaPlayer::mod_settings` carries the same "can be changed by overwriting" sentence**, so the
  settings window can edit the mod's own per-player settings here as well, rather than needing a
  storage-backed copy on this track alone.
- **`LuaControl::opened` is writable and documented to "ask the existing GUI to close"**, so the
  nesting guard in `control.lua` is load-bearing on 2.0 too, not 2.1 defensiveness.
- **`LuaGuiElement` exposes `column_count` and `location` and no size reads** — the same three
  facts the grid and the window placement are built on, including the constraint that forces the
  centred-location measurement.

**What is verified here is the API surface, not the runtime behaviour.** Three things were
*measured* on 2.1 and are only expected — not observed — on 2.0: that writing a per-player setting
raises `on_runtime_mod_setting_changed`, that `location` reads 0,0 until a frame has been laid out,
and that a hidden child takes no cell in a table. The suite covers the first and third on whichever
track it runs, so pointing it at the 2.0 worktree settles them.

## UNVERIFIED on 2.0

- Whether `set_recipe(recipe, quality)` on a ghost errors or quietly ignores the quality for a
  recipe whose `allow_quality` is false — the bridge exists so the planner never asks.
