---
verified_against: 2.0.77
verified: 2026-08-28
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

## The roll shim — this track's answer to `get_roll_chances` (2026-08-28)

The module mix, the yield and the pace all stand on one engine call that is 2.1.13-only, so
the legacy planner computes the distribution itself (`roll_chances_for`, exported as
`planner.roll_chances_for` for the premise spec). The model, from the 2.1 changelog's own
wording plus this file's scale note:

- **The one-step chance is `raw_effect x next_probability` of the FROM tier** — 2.0 stores
  quality effects x10 (0.25 for a normal q3; both versions display 2.5%) and every vanilla
  tier carries `next_probability = 0.1`, so the x0.1 conversion happens exactly once, inside
  the walk. No other code converts scale: raw 2.0 effects flow through `quality_math.solve`,
  the beacon transmission and the recycler sum untouched, and the coherence holds because
  the solve only ever turns an effect into a chance through this one function.
- **Each further transition multiplies by the reached tier's own `next_probability`**, the
  top absorbing the remainder. For vanilla's uniform 0.1 this reproduces the 2.1 engine's
  measured distributions digit for digit (0.975 / 0.0225 / 0.00225 / 0.000225 / 0.000025 for
  one normal q3 — pinned by the forked `planner_spec` premises, same numbers as api.md §30's
  engine measurements). Per-tier `next_probability` for modded chains is the documented
  reading of the 2.0 mechanic, [not measured entity-side — no oracle exists here].
- **A step chance above 1 clamps to certainty**, matching 2.1's "100% effect guarantees an
  increase"; the top tier rolls nowhere; force-free by construction, matching main's
  deliberate stance.

**One measured surprise:** `get_module_effects("legendary")` on quality-module-3 reads
**0.62** here (x10 scale), not a curve's 0.625 — the wiki's "6.2%" was never a rounding, it
is 2.0's real value, and 2.1 is what changed it to the exact 0.0625. Both premises are
pinned, one per track. Downstream the 0.5% difference moves no optimum the suite checks:
the whole 304-test suite — EM 1q+4p, the 2161 items-per-legendary crosscheck, the beacon
both-sides cases — passes identically on 2.0.77 through the shim.

## Version-scale differences that deliberately do not matter here

Marked so nobody ports a fix for them: the `ModulePrototype::*_quality_multiplier` family is
2.1-only — this mod ships no modules, so nothing to gate. The quality-effect x10 scale DOES
matter since the mix landed and is owned entirely by the roll shim above; module *ranking*
(`module_candidates`) stays scale-free as before.

## Measured identical on 2.0.77 — the fluid feature's engine behaviour

The class-3 questions the 0.2.0 port raised were answered by running the suite on this
install (90/90, 2026-08-17), not by assuming: the engine merges a recipe's input boxes into
one live box on 2.0 exactly as `api.md` §14 measures for 2.1 (the unrotated EM plant crafts
from a west-side run), a player-side underground tap through the ring belt feeds the run, a
script ghost keeps its direction beside a fluid recipe, and the placed-revived battery plan
crafts. The machine orientation table (AM west, chem/bio west, foundry/cryo east, EM north)
reads identically from 2.0's data. **The 2.0 track offers 212 upcyclable items** with fluids
admitted, against 2.1's 210 — the forked `planner_spec` pin.

## Quality comparators on inserter filters behave identically — measured 2026-08-20

The overflow tap rests entirely on a filter naming a **quality and no item** meaning "anything
above this tier" (`api.md` §24). 2.0.77's `runtime-api.json` carries `ItemFilter`,
`BlueprintItemFilter` and `ComparatorString` field-for-field identical to 2.1.14's — same nine
accepted spellings, same five canonical — but the docs agreeing proves nothing about the engine
acting on them, which is the class-3 trap this file exists for.

Answered by running the whole suite on this install (163/163, 2026-08-20), not by assuming. The
live ring test drains every above-target item out of **both** belt lanes here exactly as on 2.1,
and the blueprint round-trip keeps both the nameless `">"` and the catcher's `">="` through
build and revive — including 2.0 normalising `">="` to the glyph inside the blueprint the same
way. **Nothing about the tap is forked**: `layout.lua` and `blueprint.lua` carry it identically
on both branches, and the divergence stays the six declared files.

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

## The circuit stack ports unchanged — measured 2026-09-07

The 1.1.0 combinator, lamps and display panel (`api.md` §32) reached this track as a plain
cherry-pick: only `info.json` conflicted, `planner.lua` and `gui.lua` took their hunks onto
the forked copies without a touch, and `git diff main` still lists exactly the declared set.
Measured on 2.0.77, not inferred: the whole suite (the same count as `main`) passes
from the legacy worktree, which covers the live combinator-carried cap pausing, resuming
and stopping when switched off, the lamps' `always_on` gating at noon, and the stamped
stack's `is_on`, `color`, `combinator_description` and panel rows surviving a revive. The
static tier is clean against the 2.0.77 typedefs, so `LuaEntity.always_on`,
`combinator_description` and `LuaConstantCombinatorControlBehavior.enabled` all exist here.

**One runtime rename, spec-side only:** the display panel's row list is
`LuaDisplayPanelControlBehavior.messages` (with `get_message`/`set_message`) on 2.0.77 and
`.records` (with `get_record`, `add_record`, `set_record`, `move_record`, `remove_record`)
on 2.1.17 — read out of both installs' `runtime-api.json`, and a hard "doesn't contain key"
error whichever way round. The mod never reads it (it writes the blueprint `parameters`,
identical on both), so no fork: `tests/blueprint_spec.lua` reads a revived panel back
through `create_blueprint` instead, the one shape both engines share.

## The hand-size fix ports unchanged — measured 2026-09-07

The raised reserve threshold and the pinned hand (`api.md` §33) reached this track as the
working-tree diff applied with `git apply --3way` and no conflict — the `planner.lua` and
`gui.lua` hunks sit clear of the 2.0 seams — and `git diff main` still lists exactly the
declared set. Every field the fix uses is in the 2.0.77 `runtime-api.json`, read before the
run: `LuaEntity.inserter_stack_size_override` and `inserter_target_pickup_count`,
`LuaEntityPrototype.bulk`, `inserter_stack_size_bonus` and `uses_inserter_stack_size_bonus`,
`LuaForce.inserter_stack_size_bonus` and `bulk_inserter_capacity_bonus`, the inserter
group's `override_stack_size`, and `ComparatorString`'s same read-back rule (`>=` written,
the one-character sign returned). Measured on 2.0.77, not inferred: the whole suite (the
same count as `main`) passes from the legacy worktree — the live pinned-and-gated
inserter leaving exactly the floor, the pin and the raised M rows read back off stamped
ghosts, and the Hand size field's researched default and commit rules — and the static tier
is clean against the 2.0.77 typedefs.

## UNVERIFIED on 2.0

- Whether `set_recipe(recipe, quality)` on a ghost errors or quietly ignores the quality for a
  recipe whose `allow_quality` is false — the bridge exists so the planner never asks.
