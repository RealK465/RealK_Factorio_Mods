# Porting 2.0 code to 2.1: what breaks

Extracted from the game's own `data/changelog.txt` (2.1.14 install, extended to 2.1.22 on
2026-10-16), Modding and Scripting sections only. Regenerate against a newer install rather
than trusting this copy:

```bash
grep -A2000 "Version: 2.1" "<install>/data/changelog.txt"
```

**Read it whenever 2.0-era code is the source**: forking or porting another author's mod
(`robotworld-continued-realk` was one), or lifting a pattern from `exemples/`, whose mods were
written for 2.0. Code written for 2.0 uses the left-hand names below; 2.1 needs the right-hand
ones. Anything still using `global` or `game.*_prototypes` is older again — see `SKILL.md` →
*The globals, and the 2.0 renames*.

**Most of it is in 2.1.7**, the first public experimental build: 149 Modding and 150
Scripting entries, against 23 across 2.1.8–2.1.14 which are purely additive. 2.1.15–2.1.22
add 66 more, and those are **not** all additive: the rows tagged with a version below are
removals and renames from that stretch, each checked against the 2.0.77 and 2.1.22 API files.
Code written against an earlier 2.1 build can break on them too.

---

## Silent behaviour changes — read these first

Nothing errors, nothing shows in a dump diff, and ported code is quietly wrong.

- **Module quality multipliers.** `ModulePrototype::consumption_quality_multiplier`,
  `speed_`, `productivity_`, `pollution_`, `quality_quality_multiplier` are new in 2.1, and
  default to 1.0 for beneficial effects and **0.0 for detrimental ones**. A module's penalties
  stay flat across quality levels on 2.1 by default, where 2.0 scaled them with the bonuses.
- **Quality effect values divided by 10** in prototype definitions, and GUI percentages no
  longer multiplied by `next_probability`. Any quality number written for 2.0 is ten times too
  strong on 2.1. The mechanism: on 2.0 the real chance is `effect.quality * next_probability`,
  and every quality's `next_probability` is `0.1`; on 2.1 `next_probability` is `1`, so the
  effect value *is* the chance. Verified against vanilla `quality-module-3` — `quality = 0.25`
  on 2.0, `0.025` on 2.1, both displaying 2.5%. Nothing errors and the dump looks fine; only
  the arithmetic says so.
- **`next_probability` values multiplied by 10** (to 1). 100% quality effect now guarantees a
  quality increase. A 2.0 quality prototype's `next_probability` is a tenth of what 2.1 means
  by the same odds.
- **Recipe categories.** `RecipePrototype::category` and `additional_categories` are removed
  and silently ignored: a recipe that sets only `category` falls back to the default
  `categories = {"crafting"}`. 2.1.7 also removed the combined categories — `basic-crafting`,
  `recycling-or-hand-crafting`, `chemistry-or-cryogenics`, `pressing`,
  `crafting-with-fluid-or-metallurgy`, `metallurgy-or-assembling`, `organic-or-hand-crafting`,
  `organic-or-assembling`, `organic-or-chemistry`, `electronics-or-assembling`, `electronics`,
  `electronics-with-fluid`, `cryogenics-or-assembling` — and added `hand-crafting`, listing
  several categories per recipe instead. Vanilla 2.0 Space Age put every module and beacon
  recipe in `category = "electronics"`; the 2.1 equivalent is
  `categories = {"crafting", "electromagnetics"}`. Port a 2.0 `category = X` to
  `categories = {X}`, and a removed combined category to the list it stood for.
- **The `quality` mod un-hides `normal` on 2.1** but not on 2.0, so the count of *shown*
  qualities differs by one between the two for the same set of tiers — which matters to
  anything sizing `quality_selector_dropdown_threshold` (measured off two dumps, 2026-09-10).
- **`QualityPrototype::beacon_power_usage_multiplier` must be ≥ 0.01** in 2.1.
- **Module effects resolve to 0.01%** in 2.1. Finer-grained effect values round.
- **Selection flags** `blueprint`, `deconstruct`, `cancel-deconstruct`, `upgrade`,
  `cancel-upgrade`, `downgrade` no longer imply `any-entity` or `any-tile` in 2.1.
- **Reactors** no longer connect to neighbours by touching edges — 2.1 uses
  `ReactorPrototype::neighbour_connectable`.
- **The `recycling` recipe category moved from base to the recycler mod** in 2.1, and the
  recycler's files moved with it. 2.0 has no `recycler` mod: its recycler, sounds and recycling
  library live in `quality`. So a 2.0 `__quality__/sound/recycler/*.ogg` is
  `__recycler__/sound/recycler/*.ogg` on 2.1, and `__quality__.prototypes.recycling` is
  `__recycler__.recycling`. A wrong sound or sprite path passes `--dump-data` and stops the
  real game — `factorio-validate` → `-FullLoad` is the check.
- **Flying robot energy usage** no longer derives from gravity/pressure; 2.1 uses a
  `"robot-energy-usage"` surface property.
- **`feature_flags["expansion"]` is 2.1-only** (added with belt stacking). Reads as `nil` on
  2.0, so other people's mods use it as a version probe; on 2.1 the 2.0 side of such a branch
  is dead code to delete when porting. The same goes for `mods["base"]` version-string
  matching and `script.active_mods["base"]` at runtime.
- **`AmbientSound::planet` → `planets`** plus `surface_names`, `play_on_all_surfaces`,
  `exclude_planets`, `exclude_surface_names`. This one *did* error — it crashed planet mods on
  2.1.13.
- **Circuit connector render layers** (2.1.15). Inserter, train stop, asteroid collector and
  rocket silo connectors no longer default to their special layers or draw order; the layer
  now lives on `CircuitConnectorSprites::render_layer` / `secondary_draw_order`. A connector
  relying on the old default draws on a different layer.
- **`FluidEnergySource::maximum_temperature`: "unlimited" is `nil`, not `0`** (2.1.22), and
  `LuaFluidEnergySourcePrototype::maximum_temperature` reads `nil` rather than `0`. A `0`
  written to mean unlimited, or a runtime check comparing against `0`, no longer means that.
- **Boiler fluid filters cannot be changed at runtime** (2.1.21), and a `target_temperature`
  outside the output fluid's range is now a prototype error.
- **`LuaEntity::set_fluid_filter`, `get_fluid_filter`, `get_fluid_segment_filter` take and
  return a `FluidID`** (2.1.22), no longer a `FluidFilter`. A within-2.1 change: these methods
  replaced `LuaFluidBox` in 2.1.7, so 2.0 code has neither shape.

---

## Data stage — removed, renamed, moved

| 2.0 | 2.1 |
|---|---|
| `RecipePrototype::category`, `additional_categories` | `categories` |
| `RecipePrototype::always_show_products`, `show_amount_in_title` | removed |
| `RecipePrototype::result_is_always_fresh` | `ItemProductPrototype::always_fresh` |
| `RecipePrototype::reset_freshness_on_craft` | `ItemProductPrototype::reset_freshness_on_craft` |
| `AssemblingMachinePrototype::enable_logistic_control_behavior` | `"no-logistic-connection"` entity flag |
| `CraftingMachinePrototype::forced_symmetry` | `use_mirroring` |
| assembling-machine graphics inline in `__base__/prototypes/entity/entities.lua`, the connector from the `circuit_connector_definitions["assembling-machine"]` global | `__base__/prototypes/entity/assembler-pictures.lua`, required by file |
| `EntityPrototype::build_base_evolution_requirement` | removed |
| `GeneratorPrototype::horizontal_animation`, `vertical_animation`, `horizontal_frozen_patch`, `vertical_frozen_patch` | `GeneratorPrototype::pictures` |
| `MiningDrillPrototype::base_picture`, `base_render_layer` | `working_visualisations` |
| `CargoLandingPadPrototype::robot_animation`, `robot_landing_location_offset`, `robot_opened_duration`, `robot_animation_sound` | `robot_door` |
| `LogisticContainerPrototype::animation`, `landing_location_offset`, `opened_duration`, `animation_sound` | `robot_door` |
| `VehiclePrototype::braking_power`, `friction` | `braking_force`, `friction_force` |
| `MapSettings::steering` | `UnitPrototype::steering`, `SpiderUnitPrototype::steering` |
| `StateSteeringSettings::force_unit_fuzzy_goto_behavior`, `SteeringSettings::moving`/`default` | removed |
| `AsteroidPrototype::mass` | `damage_per_hp` |
| `SpacePlatformHubPrototype::dump_container` | removed |
| `FluidBox::hide_connection_info` | removed |
| `UtilityConstants::max_fluid_flow` | removed — derived from FluidBox volume |
| `UtilityConstants::rocket_lift_weight` | `default_rocket_lift_weight` |
| `CustomInputPrototype` deprecated/undocumented key names | removed |
| `CraftingMachineGraphicsSet::circuit_connector_layer`, `circuit_connector_secondary_draw_order`; the same pair on `MiningDrillGraphicsSet`; `LoaderPrototype::circuit_connector_layer`; `RailSignalPictureSet::circuit_connector_render_layer` | `CircuitConnectorSprites::render_layer`, `secondary_draw_order` (2.1.15) |
| `PollutionSettings::max_pollution_to_restore_trees` | removed (2.1.18) |
| `ItemPrototype::fuel_category` | `fuel_categories` (2.1.20) |
| `UtilityConstants::zoom_to_world_can_use_nightvision`, `zoom_to_world_effect_strength`, `zoom_to_world_daytime_color_lookup` | removed (2.1.20) |
| `ProxyContainerPrototype::circuit_connector` (single) | an array, plus `direction_count` (2.1.21) |
| `FluidBox::minimum_temperature`, `maximum_temperature` | removed — `minimum_input_temperature` / `maximum_input_temperature` on `FluidEnergySource`, `BoilerPrototype`, `GeneratorPrototype`, `FusionGeneratorPrototype`, `FusionReactorPrototype`, `MiningDrillPrototype`; fuel and oxidizer pairs on `ThrusterPrototype` (2.1.22) |
| `UtilityConstants::building_buildable_tint`, `building_buildable_too_far_tint`, `building_ignorable_tint`, `building_not_buildable_tint` | `build_preview_tints` (2.1.22) |
| `WaterTileEffectParameters::textures`, `texture_variations_rows`/`columns`, `secondary_texture_variations_rows`/`columns` | `noise_textures`, `image_textures`; the counts are derived (2.1.22) |

---

## Runtime — removed, renamed, moved

| 2.0 | 2.1 |
|---|---|
| **`LuaEntity::fluidbox`, the whole `LuaFluidBox` class** | gone — fluid access is directly on `LuaEntity` |
| `LuaEntity::remove_fluid()` | `extract_fluid()` |
| `LuaEntity::set_fluid()` | second argument mandatory; returns `FluidAmount`, not `Fluid` |
| `LuaEntity::neighbors` | `fluidbox_neighbours`, `underground_belt_neighbour`, `wall_neighbours`, `cliff_neighbours`, `neighbour_connectable_connections` (plus existing `belt_neighbours`, `heat_neighbours`) |
| `LuaEntity::pump_rail_target` | `pump_input_rail_targets`, `pump_output_rail_targets` |
| `LuaEntity::active` (write) | `disabled_by_script` |
| `LuaEntity::minable` (write) | `minable_flag` |
| `LuaEntity::mining_progress` | moved to `LuaControl`, now read/write |
| `LuaEntity::display_panel_text` | plain string only, no LocalisedString |
| `LuaEntity::inserter_spoil_priority` | dashes instead of underscores in the return value |
| `LuaEntityPrototype::fluid_usage_per_tick` | `get_fluid_usage_per_tick()` |
| `LuaEntityPrototype::max_power_output` | `get_max_power_output()` |
| `LuaEntityPrototype::pumping_speed` | `get_pumping_speed()` |
| `LuaEntityPrototype::fixed_recipe` | returns a `LuaRecipePrototype`, not a string |
| `LuaEntityPrototype::build_base_evolution_requirement` | removed |
| `LuaFluidBoxPrototype::volume` | `get_volume()` |
| `LuaItemPrototype::inventory_size` | `get_inventory_size()` |
| `LuaItemPrototype::tile_filter_slots`, `entity_filter_slots` | removed |
| `LuaRecipe::category`, `additional_categories` | `categories` |
| `LuaRecipePrototype::category`, `additional_categories` | `categories` |
| `LuaRecipePrototype::is_parameter` | `LuaPrototypeBase::parameter` |
| `LuaRecipePrototype::show_amount_in_title`, `result_is_always_fresh`, `reset_freshness_on_craft`, `always_show_products` | removed |
| `LuaRecord::is_blueprint_preview` | `is_preview` |
| `LuaGameScript::create_profiler()` | `LuaHelpers::create_profiler()` |
| `LuaPlayer::pipette_entity()` | `pipette()` |
| `LuaPlayer::teleport()` | no longer implicitly exits remote view |
| `LuaLogisticContainerControlBehavior::circuit_exclusive_mode_of_operation` | `set_requests`, `read_contents` |
| `LuaAssemblingMachineControlBehavior::include_fuel`, `LuaFurnaceControlBehavior::include_fuel` | `read_fuel` |
| `LuaDisplayPanelControlBehavior::messages`, `get_message`, `set_message` | `records`, `get_record`, `add_record`, `set_record`, `move_record`, `remove_record` |
| `LuaGroup` | `LuaItemGroup`, `LuaItemSubGroup` (2.1.15) |
| `LuaSimulation::get_widget_position()` with `data`/`data2` strings | reworked, 1-based indexing (2.1.15) |
| `LuaPlayer::spectator` | removed (2.1.20) |
| `LuaItemPrototype::fuel_category` | `fuel_categories` (2.1.20) |
| `LuaEntityPrototype::building_grid_bit_shift` | `build_grid_size` (2.1.21) |

### defines

| 2.0 | 2.1 |
|---|---|
| `defines.inventory.assembling_machine_input`, `furnace_source`, `rocket_silo_input` | `defines.inventory.crafter_input` |
| `defines.inventory.assembling_machine_output`, `furnace_result`, `rocket_silo_output` | `crafter_output` |
| `defines.inventory.assembling_machine_modules`, `furnace_modules`, `rocket_silo_modules` | `crafter_modules` |
| `defines.inventory.assembling_machine_trash`, `furnace_trash` | `crafter_trash` |
| `defines.default_icon_size` | `defines.constant.default_icon_size` |
| `defines.control_behavior.type.storage_tank` | `single_fluid_box` |
| `defines.control_behavior.logistic_container.exclusive_mode` | removed |
| `defines.control_behavior.cargo_landing_pad.exclusive_mode` | removed |
| `defines.relative_gui_type.storage_tank_gui` | removed |

---

## 2.1-only additions worth knowing

What 2.0 code had no way to use, and often worked around. A port can replace the workaround.

- `ModulePrototype::*_quality_multiplier` (see silent changes above)
- `EffectReceiver::consumption_limits`, `speed_limits`, `productivity_limits`,
  `pollution_limits`, `quality_limits`; `uses_local_effect` (2.1.13)
- `QualityPrototype::chain_probability`, `previous`, `previous_probability`,
  `previous_chain_probability`, `module_*_multiplier`, `spoil_ticks_multiplier`,
  `cargo_wagon_inventory_size_multiplier`, `locomotive_power_multiplier`,
  `rolling_stock_max_speed_multiplier`
- `ItemIngredientPrototype` / `ItemProductPrototype` `quality_min`, `quality_max`,
  `quality_change`, `affected_by_quality`
- `RecipePrototype::requires_ingredients_to_unlock_results`, `sort_item_ingredients`,
  `can_set_quality`, `raise_on_crafted` (2.1.12)
- Module support on agricultural towers
- The `+` dependency prefix (recommended, auto-enabled)
- `[space-age]` `expansion` feature flag; `ItemPrototype::spoil_quality_min`/`max`/`change`
- Runtime: `LuaPin` and `LuaPlayer::get_pins()`/`clear_pins()` (2.1.10),
  `LuaQualityPrototype::roll_quality()` (2.1.12), `get_roll_chances()` (2.1.13),
  `LuaForce::get_space_platforms()`, `LuaEntity::local_effect` (2.1.13),
  `on_player_super_forced_selected_area` (2.1.13), `LuaBootstrap::get_event_name()` (2.1.12),
  `LuaForce::unlock_logistic_network` and the `unlock-logistic-network` technology modifier
  (2.1.7)
- `info.json` `migrates_from` (2.1.18) — takes over a removed mod's storage, inventories, GUI
  and render objects
- `ItemPrototype::science_capacity`, `quality_affects_spoil_ticks`,
  `QualityPrototype::science_capacity_multiplier` (2.1.18);
  `CraftingMachinePrototype::animation_random_start_frame` (2.1.21)
- Selection tool preselection events `on_player_start_selected_area`,
  `on_player_change_selected_area`, `on_player_cancel_selected_area`, opted into per tool with
  `SelectionToolPrototype::send_pre_selection_events`; `selection_mode`, `position` and
  `cursor_position` on area selection events (2.1.22). The 2.1.22 prototype docs link these
  under the wrong names (`..._select_area`)
