# Reference mods — what to copy, what to avoid

Both planner mods were cloned from source and read (they are not in this workspace; clone again
to a scratch directory if a detail needs re-checking — other authors' work, reference only,
never edited or redistributed):

- **P.U.M.P. 2.2.2** by Xcone — `github.com/Xcone/factorio_pump`, mod lives in `mod/`.
- **Mining Patch Planner 1.7.20** by Rimbas — `github.com/rimbas/mining-patch-planner`.
- **flib 0.17.2** — in this workspace at `exemples/flib_0.17.2/`.

P.U.M.P. is the closer shape (small, synchronous, tool -> plan -> ghosts). MPP is the richer
structural model (layout classes, grid abstraction, a 1,700-line production GUI) but most of its
machinery exists for a problem we do not have.

## P.U.M.P. — take

- **Prototype shapes.** The selection tool is deep-copied from vanilla's own template item
  `data.raw["selection-tool"]["selection-tool"]` (`data.lua:2-20`) — that template exists
  expressly for mods. Flags `{"only-in-cursor","spawnable","not-stackable"}` (:7).
- **`linked_game_control` custom inputs** (`data.lua:42-50`): one linked to `"confirm-gui"`
  (Enter), one to `"toggle-menu"` (Esc), with empty `key_sequence`. GUI confirm/cancel on the
  vanilla keys **without claiming keybind slots**. Handled at `control.lua:83-99`.
- **Synchronous planning.** The entire pipeline — survey, A*, plan, ghost emission — runs inside
  one event call (`control.lua:101-188`). There is no `on_tick` and no coroutine anywhere in the
  mod. Proof that a bounded plan needs no tick machinery.
- **Ghost emission** (`constructor.lua:208-217`): `create_entity{name="entity-ghost", inner_name,
  position, direction, mirror, force, player, quality}`. It then raises the built event manually
  (:242) — passing `raise_built = true` is equivalent and shorter.
- **Module requests on ghosts** (`constructor.lua:220-237`) via `insert_plan`, sized to
  `ghost.ghost_prototype.module_inventory_size`.
- **Obstacles** (`constructor.lua:183-194`): per-footprint `find_entities_filtered` with the
  target's collision layers, then `order_deconstruction(force, player)`.
- **"Best researched" picks** (`toolbox.lua:89-113`): a candidate entity counts as unlocked if
  any recipe with `has-product-item` for it is `force.recipes[..].enabled`. Reuse for the
  default machine, belt tier and module tier.
- **GUI**: screen frame with `auto_center`, `player.opened = frame`, `on_gui_closed` = cancel
  (`toolshop.lua:249-256`, `control.lua:53-59`); the frame is **re-found by name in every
  handler, never cached** (`toolshop.lua:335-443`).

## P.U.M.P. — avoid

- `storage.toolpicker_config` and `storage.current_action` are **single global tables** — two
  players in multiplayer stomp each other. Key everything by `player_index` from day one.
- Reachable bare `error()` calls with no `pcall` (`planner-assistant.lua:22,193,200,279`;
  `plib.lua:249,272`; `plumber-pro.lua:532,647,889`) alongside its own perfectly good graceful
  `current_action.failure = {locale-key}` convention (`control.lua:120-187`). Route every
  failure through a message.
- Unconditional debug JSON writes to script-output on **every** tool use
  (`control.lua:156,175,258-261`), and dead dev-harness code shipped in the release.
- Hardcoded `"pipe"` / `"pipe-to-ground"` names inside an otherwise prototype-driven survey
  (`prospector.lua:66-73,92-100`).
- One file `require`d from **both** stages (`toolbox.lua` from data-final-fixes and from
  control), relying on discipline about which functions run where. Split per stage.

## Mining Patch Planner — take

- **The builder closure** (`mpp/builder.lua:37-128`) is the highest-value single file: a ghost
  spec `{name, quality, grid_x, grid_y, direction, ...}` mutated into the `create_entity` call,
  with `raise_built = true` (:58), name-to-`inner_name` swap (:62-63), direction remap (:67),
  quality nil'd when the quality feature flag is off (:7,69), and an optional
  `can_place_entity` pre-check (:82-93).
- **Quality as a plain string end to end** — GUI choice -> player data -> job state
  (`algorithm.lua:138-141`) -> ghost spec -> builder. Also `configuration.lua:190-255` resets
  choices that point at removed or locked qualities: that is the `on_configuration_changed`
  prune to imitate.
- **Footprint caching**: `entity_struct` (`mpp_util.lua:130-163`) derives width/height/extents
  from `collision_box`, cached per `(quality, name)` — several prototype getters are
  quality-parameterised (`get_crafting_speed(quality)`,
  `get_supply_area_distance(quality)`), so the cache genuinely needs the quality key.
- `inserter_struct` / `inserter_hand_locations` (:598-644) precompute pickup and drop for all
  four directions; `coord_convert` / `coord_revert` (:22-47) let a layout be written once and
  rotated on output — the pattern to reach for if layout rotation is ever added.
- **Quality GUI widgets**: `choose-elem-button` with `elem_type = "item-with-quality"` /
  `"entity-with-quality"` bundles item and quality in one native widget
  (`gui/gui.lua:1069-1078, 1113-1121`); `quality_list()` (`mpp_util.lua:1125-1145`) enumerates
  `prototypes.quality` skipping hidden.
- **Tag-based GUI dispatch**: every element carries `tags = {mpp_action = ...}`; handlers branch
  on which tag key is present (`gui/gui.lua:1437-1694`), and appearance is always repainted from
  the persisted choice strings, never trusted (`:1379-1394`).
- **Layout declares its capabilities**: a `layout.restrictions` table gates which GUI sections
  even get built (`layouts/base.lua:20-45`). Worth remembering when the second layout family
  (bot loop) arrives.

## Mining Patch Planner — avoid (and why it exists there)

- **The multi-tick budgeted step machine** — `state._callback` step-name strings dispatched by
  `layout:tick` (`layouts/base.lua:96-99`), per-step budgets (`layouts/simple.lua:294`), one
  task per tick off `storage.tasks` (`control.lua:27-53`). It exists because MPP scans unbounded
  irregular terrain. Our plan is a bounded formula of a few dozen entities; MPP's own
  `belt_planner.lua:131` places synchronously too.
- **The save/load metatable dance that machinery drags in** — hand `setmetatable`
  reattachment in `on_load` for grids and blueprint caches (`control.lua:197-222`,
  `layouts/simple.lua:94-102`). Avoided entirely by never persisting a mid-flight plan.
- `grid_mt` / `pole_grid_mt` (~30 methods of convolution and occupancy) — terrain-scan tooling.
- `blueprintmeta.lua` and the blueprint layout modes — they parse *user-supplied* blueprints,
  a different feature.
- The belt-planner "disguised blueprint in cursor, intercept `on_built_entity`, delete and
  reroute" UX hack (`control.lua:285-350`).
- Subclassing whole layout classes by `table.deepcopy` — fine at MPP's scale; plain modules
  suffice for two families.

## flib — verdict: copy the pattern, skip the dependency

The save/load-safe core of `gui.lua` is about 43 lines:

- `add_handlers` (`gui.lua:131-150`) maps function-to-name and name-to-function in module-local
  tables;
- `gui.add` writes **only the name string** into `element.tags["__<mod>_handler"]` (:8, 86-99);
- `dispatch` (:156-178) reads the tag and calls through the lookup.

**Nothing but strings ever reaches saved state.** That is the whole trick, and it is worth
reproducing in ~40 lines rather than taking a second hard portal dependency for one small
frame — flib 0.17.0 was a genuinely breaking release, and flib has **nothing** for shortcuts.

A hand-rolled dispatcher must keep all five properties:

1. only name strings in tags and in `storage`;
2. the handler table and `script.on_event` registration at `control.lua` **top level** (so they
   are rebuilt identically on every load);
3. never capture a `LuaGuiElement` in a closure — re-derive from `event.element`;
4. guard `event.element and event.element.valid` before reading `.tags` (flib itself skips the
   `.valid` check — be stricter);
5. namespace the tag key with the mod name.

Also compatible with Wube's own `__core__/lualib/event_handler`, which re-registers on both
`on_init` and `on_load` automatically.

Other flib modules: `position.lua` and `bounding-box.lua` are on-target for layout maths but
each function is small — copy ideas, not the dependency. `dictionary` is unnecessary (native
`LocalisedString` handles the GUI). `migration` was removed in 0.17.

One erratum found while reading flib's own `CLAUDE.md` in this workspace: its claim that
`math.mean` errors on an empty array is wrong — it returns NaN, because the sum returns 0 and
then 0/0. Noted in case that file is ever trusted verbatim.
