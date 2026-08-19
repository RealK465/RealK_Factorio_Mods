# Data stage — authoring prototypes

Everything in `data.lua`, `data-updates.lua`, `data-final-fixes.lua` and the files they require.
Field reference is `doc-html/prototype-api.json` for the installed version; `data/base/` is how
Wube actually writes it. Grep both rather than recalling field names.

## Contents

- [Which of the three files](#which-of-the-three-files)
- [Derive, don't rewrite](#derive-dont-rewrite)
- [Requiring from base](#requiring-from-base)
- [Naming and namespacing](#naming-and-namespacing)
- [Organising the files](#organising-the-files)
- [The item / recipe / entity / technology quartet](#the-item--recipe--entity--technology-quartet)
- [Ordering and grouping](#ordering-and-grouping)
- [Modules and quality maths](#modules-and-quality-maths)
- [`data.raw` surgery](#dataraw-surgery)
- [Things that are true but surprising](#things-that-are-true-but-surprising)

## Which of the three files

Every mod's `data.lua` runs before any mod's `data-updates.lua`, which runs before any mod's
`data-final-fixes.lua`. That is the entire coordination mechanism.

| File | For |
|---|---|
| `data.lua` | Your own prototypes. Almost everything belongs here |
| `data-updates.lua` | Modifying prototypes that are not yours — vanilla's or another mod's |
| `data-final-fixes.lua` | Last resort, when you must see the result of everyone else's updates |

Touching another mod's prototype in `data.lua` is a race you lose: it may not exist yet.
`data-final-fixes` is the community's least-favourite stage precisely because everything there
is invisible to everyone else — you get the last word, which also means no one can compensate for
what you did. Reach for it only when the thing you need genuinely does not exist until then (a
sweep over every recipe some other mod generates in `data-updates`, say). Space Exploration's
postprocess mod is the legitimate case: an entire separate mod whose *job* is running last.

Krastorio 2 is a useful calibration — a ~100-building overhaul, and its `data-final-fixes.lua` is
nearly empty.

## Derive, don't rewrite

`table.deepcopy(data.raw[type][name])` is the default move for anything resembling a vanilla
thing. It inherits fluid boxes, pipe pictures, circuit connectors, sounds, remnants, explosions,
collision and hit effects for free; it keeps working when Wube retunes them; and it picks up
whatever other mods already did to that prototype, which nothing else will.

```lua
local pipe = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"])
pipe.name = "kr-legacy-steel-pipe-to-ground"
pipe.placeable_by = { item = "kr-steel-pipe-to-ground", count = 1 }
for _, connection in pairs(pipe.fluid_box.pipe_connections) do
  if connection.connection_type == "underground" then
    connection.max_underground_distance = 30
  end
end
data:extend({ pipe })
```

Change only what differs. Two things a deepcopy carries that you usually must fix:

- **`minable.result` and `placeable_by`** still point at the original item.
- **`working_visualisations` with `draw_as_glow`** are positioned for the *original* shape. On a
  differently-sized entity the glow is off-centre. Re-author or drop it.

Also remember `localised_name` is not copied usefully — the new prototype needs its own
`locale/en/*.cfg` entry, or it shows as `Unknown key`.

## Requiring from base

`require("__base__.prototypes.entity.sounds")` **works** — tested on 2.1.14, and base uses the
same form on itself. Relative requires *inside* the base file resolve against base, not against
your mod, and a file base already loaded comes back from cache rather than re-running (requiring
the `data:extend`-ing `explosions.lua` duplicated nothing).

Use it for base's **pure helper modules** — the ones that build a table and return it:
`prototypes/entity/explosion-animations.lua`, `sounds.lua`, `particle-animations.lua`,
`hit-effects.lua`. Their contents (`big_explosion()`, `large_explosion(0.7, 1.0)`) exist nowhere
in `data.raw`, so copying a prototype cannot reach them. `pure-modules-realk/prototypes/beacon/explosion.lua`
in this repo is the worked example, and Krastorio 2 does the same thing in
`prototypes/buildings/advanced-furnace.lua`.

**Still prefer `table.deepcopy(data.raw[...])` for anything that has a prototype.** Prototype
names are effectively public and stable; base's internal file layout is not, and a require couples
you to a path Wube can rename between versions.

Also always available without a require: `util` (`require("util")` — `table.deepcopy` itself lives
here, along with `merge`), `kg` and `grams` as true globals from `core/lualib/util.lua`, and the
rest of `core/lualib/` (`collision-mask-util`, `circuit-connector-generated-definitions`,
`resource-autoplace`, `math2d`, `meld`).

## Naming and namespacing

Prototype names are **one flat global namespace shared by every mod**. Two mods that both define
`steel-furnace-2` do not coexist.

- Prefix every name with a short mod tag: `kr-`, `se-`, `pm-`. Community convention, and the
  reason `data.raw` surgery on a well-behaved mod is predictable.
- Alphanumerics, dashes and underscores only.
- **Changing a name after release requires a migration** and breaks saves without one — this is
  the change that pairs with a major version bump. Design names as if permanent, because in
  practice they are.
- Keep the item, recipe and entity for one thing on the *same* name where the game permits it.
  That is what vanilla does and it makes `data.raw` lookups obvious.

## Organising the files

Not enforced — the loader does not care where a file is — but this is what `exemples/` converges
on:

- **`prototypes/<category>/<name>.lua`**, one file per thing, where "thing" means the entity plus
  its item plus its recipe plus the tech that unlocks it. Categories follow content, not prototype
  kind: `buildings/`, `items/`, `recipes/`, `technologies/`, `equipment/`. A small mod can skip
  the category layer.
- **The subfolder name says which data-stage file requires it.** `prototypes/updates/` holds what
  `data-updates.lua` requires (often split further: `updates/base/`, `updates/space-age/`);
  `prototypes/final-fixes/` mirrors `data-final-fixes.lua`; `prototypes/compatibility/` holds
  shims required behind a `mods[...]` check.
- **A config table at the top of `data.lua`** that other files read is the standard way to gate
  features from one place:
  ```lua
  KR = { adjust_stack_sizes = true, optimization_tech_card_name = "space-science-pack" }
  ```
- Pick dots for `require` separators and use them mod-wide. (Mixing is untidy but harmless —
  `require` caches by resolved file, tested on 2.1.14.)

## The item / recipe / entity / technology quartet

A new building is four prototypes, and forgetting one fails quietly in a specific way:

| Missing | Symptom |
|---|---|
| `item` | Entity exists but cannot be held or placed |
| `recipe` | Item exists but cannot be made |
| `technology` effect | Recipe exists but is never unlocked (unless `enabled = true`) |
| locale entry | Shows as `Unknown key: "entity-name.foo"` |

The item's `place_result` points at the entity; the entity's `minable.result` points back at the
item; the recipe's `results` produce the item; the technology's `effects` contain
`{ type = "unlock-recipe", recipe = "..." }`.

**2.0 recipe format** — the shorthand is gone:

```lua
{
  type = "recipe",
  name = "pm-smelter",
  energy_required = 2,
  ingredients = {
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "fluid", name = "lubricant", amount = 10 },
  },
  results = { { type = "item", name = "pm-smelter", amount = 1 } },
}
```

`result` / `result_count` and the `{"steel-plate", 20}` array form are 1.1; `normal` / `expensive`
variants no longer exist. **A recipe may not list the same ingredient twice** — easy to hit when
part of the list is conditional and happens to name the same item as a fixed one. Merge amounts
when building the list rather than appending.

Other 2.0 prototype shifts worth knowing when reading old code: `flags = {"hidden"}` became
`hidden = true`; fluid boxes take a single `volume` instead of `base_area`/`height`; crafting
machine `animations` and `working_visualisations` moved inside `graphics_set`; collision layers
are prototypes rather than hardcoded strings; `hr_version` is gone (ship the high-res image and
set `scale = 0.5`).

## Ordering and grouping

`order` is a string sorted lexicographically inside a subgroup; `subgroup` sorts inside an
`item_group`. Without them your item lands wherever alphabetical order puts it, which looks
accidental. The vanilla convention is short strings with room to insert (`"a[smelting]-b[furnace]"`),
and slotting into an existing vanilla subgroup next to the thing you resemble is usually better
than inventing a group — a mod that adds five items and its own tab reads as a mod; five items in
the right place read as content.

Technology `order` works the same way. Prerequisites determine the graph; `order` only determines
display.

`space-science-pack` exists as a technology in both base and Space Age (SA only changes its
research trigger and prerequisites), so it is a safe prerequisite either way.

## Modules and quality maths

Two numbers that are quietly wrong if you assume:

- **Legendary quality is `level = 5`, not 4** — the quality mod skips 4. Module effects scale by
  the quality prototype's `default_multiplier`, `1 + 0.3 * level`, so the legendary factor is
  **2.5**. Assuming 4 gives 2.2 and every derived number is ~14% off. Sanity-check any such sum
  against vanilla: `quality-module-3`'s 0.025 → 6.25%, which is what the game displays.
- **Module penalties don't scale with quality, and that is free.** The `*_quality_multiplier`
  fields on `ModulePrototype` default to 1.0 when their effect is beneficial and 0.0 when it is a
  penalty, judged by the sign. A legendary module gains bonus without gaining cost. Setting those
  fields explicitly overrides the behaviour — leave them unset unless changing it is the intent.

`allowed_module_categories` is set nowhere in base, quality, elevated-rails, recycler or Space Age
(re-audited against 2.1.14), so defining a new module category is safe against vanilla; only
modded recipes or machines that set the field could reject it.

## `data.raw` surgery

Modifying prototypes in place, in `data-updates` or later:

- **Check existence before touching.** `if data.raw.item["titanium-plate"] then ... end`. The
  prototype you expect may belong to a mod that is not installed, or may have been removed by
  another mod's updates.
- **Iterate backwards when removing from an array.** `for i = #list, 1, -1 do` — forward
  iteration with removal skips entries. SE's `data_util.lua` does this throughout.
- **`data.raw[type]` is keyed by name**, and `type` is the prototype's `type` string, not its
  base class. `data.raw["assembling-machine"]` will not contain furnaces.
- Removing a prototype means `data.raw[type][name] = nil` — and then hunting every reference to
  it (recipe ingredients, technology effects, `place_result`, `minable.result`), because a
  dangling reference *does* error at load with the exact path, which is the one loud failure in
  this whole file.
- Helper functions for repeated patterns pay for themselves fast. SE's
  `tech_add_prerequisites`, `replace_or_add_ingredient` and `tech_add_ingredients` are worth
  reading before writing your own (`exemples/space-exploration/space-exploration-postprocess/`).

## Fluid boxes: the two rules that decide a machine's whole layout

FFF-420 records the fusion plant's layout being driven by its connection points rather than the
other way round. Two constraints make that unavoidable, and both are loud rather than silent —
which is the good case, but only if you meet them before the art is rendered.

- **A `position` is a point INSIDE the collision box, not on the tile edge.** The `direction`
  is what projects the connection outward. Give an edge coordinate and the load fails naming the
  exact numbers: *"PipeConnectionDefinition: position must be inside of entity bounding box.
  position={-0.500, 1.500}, leftTop={-0.898, -1.398}…"*. Vanilla's boiler is the model to copy —
  collision box `{{-1.29,-0.79},{1.29,0.79}}` with connections at `{-1, 0.5}`, `{1, 0.5}` and
  `{0, -0.5}`, every one of them inside.
- **No two connections may share a position**, across *all* of the entity's fluid boxes,
  including a `FluidEnergySource`'s. That is a hard cap on how many connections a small footprint
  can carry: a 2-wide entity has exactly **two** tiles in its rear row, so a rear-facing inlet
  plus two rear-corner outlets does not fit however it is written.

The knock-on: connections that must **chain entity-to-entity along a row have to sit at the same
offset down the machine**, or drill A's east connection and drill B's west connection never meet.
Fixing a position clash by moving one of a chaining pair silently breaks the chain — the mod
loads, the pipes just never join.

## Things that are true but surprising

- **Extra properties are silently discarded.** The game ignores keys it is not looking for, so a
  typo'd field name is not an error — it just does nothing. The `check-unused-prototype-data`
  debug setting logs these; use it when a property "isn't working".
- **Missing properties either default or error with a message naming what is missing.** The error
  case is the good one.
- **The settings stage sees `mods` too.** It is built identically to the prototype stage, so a
  setting that would be meaningless under the current mod set can simply not be defined instead of
  sitting in the GUI doing nothing. The catch is on the reading side — see
  `references/compatibility.md`.
- **`feature_flags` gates expansion-only properties**, not `mods["space-age"]`. Same reference.
- **Prototype changes need a full game restart.** Only `control.lua` can be reloaded in-session.
- **Graphics paths are not checked headlessly.** `--dump-data` exits 0 with a misspelled `icon`.
  Only the running game catches it — or `helpers.is_valid_sprite_path` at runtime.
- `data:extend{...}` and `data:extend({...})` are the same call. Vanilla uses both.
