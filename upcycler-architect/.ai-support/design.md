# Upcycler Architect — design record

Decisions and their reasons, recorded as they are made. Never ships (leading dot).

## 2026-08-15 — feasibility investigation

The question was whether a mod can compute an upcycling layout and place it in the world the
way Mining Patch Planner and P.U.M.P. place theirs. **It can.** Both reference mods were
extracted from the local `*.zip` copies and read; every API call below was verified against
`doc-html/runtime-api.json` from the installed 2.1.14, not from memory.

### Placement: ghosts, not blueprint strings

Neither reference mod uses a blueprint string. Both walk their computed layout and call
`surface.create_entity{name = "entity-ghost", inner_name = ...}` one entity at a time:

- `pump_2.2.2/constructor.lua:208` — `create_entity{name = "entity-ghost", ...}`
- `mining-patch-planner/layouts/*.lua` — the same, behind a `builder.create_entity_builder`
  wrapper; `layouts/simple.lua:1968` does tile ghosts the same way.

This is the route to use, and **the blueprint-string route is a dead end**:
`LuaSurface.create_entities_from_blueprint_string` is documented *"This method only works when
used in simulations"* — it exists for menu-background sims, not for mods.
`LuaRecord.build_blueprint` is real and usable, but it needs an actual blueprint record to
exist first, which buys nothing over emitting ghosts directly. Computing ghosts also means the
layout can respond to the player's choices instead of being a stored string.

### Every piece an upcycler specifically needs exists

Verified present in 2.1.14:

| Need | API |
|---|---|
| Place a ghost of any entity | `create_entity` `entity-ghost` group: `inner_name` (req), `tags` |
| Machines that are themselves quality | `create_entity` param `quality`, defaults to `normal` |
| Set the recipe on a planned machine | `create_entity` `assembling-machine` group: `recipe`, `recipe_quality` |
| Request quality modules into the ghosts | `create_entity` `item-request-proxy` group: `modules`, `removal_plan`, `target` |
| Read back what was planned | `LuaEntity.ghost_name` / `ghost_prototype` / `ghost_type` / `item_requests` / `quality` |
| The P.U.M.P. interaction model | `SelectionToolPrototype` + `on_player_selected_area` / `_alt_` / `_reverse_` |

`recipe_quality` is worth noting — the planner can pin both the machine's quality and the
recipe's, which is exactly the axis an upcycler is built around.

### Prior art: the niche is open

No mod generates these layouts. Checked on the portal:

- [`upcycler`](https://mods.factorio.com/mod/upcycler) — unrelated. A machine that converts N
  items into 1 of the next tier. Shares the word only.
- [`quality-cycler`](https://mods.factorio.com/mod/quality-cycler) — shifts quality up/down
  *inside* an existing blueprint. Does not design anything.

Everything else is hand-shared blueprint books — [FactorioBin](https://factoriobin.com/post/8wj94j/6),
[the forums](https://forums.factorio.com/viewtopic.php?t=121438), Factorio Prints. That is the
gap: players answer the same layout questions by hand every time.

## Decided

- **Name: Upcycler Architect**, portal name `upcycler-architect`. Chosen 2026-08-15 over
  *Upcycler Planner*, *Upcycler Generator*, *Quality Loop Planner* and *Quality Casino*.
  "Upcycler" is the word players search for. "Architect" was preferred over the genre's usual
  "Planner" because it avoids two collisions at once: `generator` is Factorio's own prototype
  type for power entities, and the plain `Upcycler` mod already exists and does something else.
  The accepted cost is that "Architect" is not the genre's word, so the mod is a little less
  instantly legible than *… Planner* would have been.
- **Portal name is free.** `GET /api/mods/upcycler-architect` returned 404 on 2026-08-15;
  the method was sanity-checked against `pump`, `mining-patch-planner`, `upcycler` and
  `quality-cycler`, all 200. Worth having done — `pure-modules` was lost to a squat by a
  deleted account, and portal names stay taken after the account goes.
- **Hard dependency on `quality >= 2.1.0`**, not a `quality_required` feature flag. In 2.1
  `recycler` is its own expansion mod and `quality` declares `["base >= 2.1.0",
  "recycler >= 2.1.0"]`, so depending on `quality` pulls the recycler in for free. A hard
  dependency is right because the mod is worthless without quality tiers, and unlike the
  feature flag it also fixes load order. No `*_required` flag is declared.
- **Factorio 2.1 only.** No `legacy/2.0` build. `recycler` is 2.1-only on this machine, and
  there is nothing shipped worth backporting.
- **Version starts at `0.1.0`**, open section, `Date: ????`.

## Open questions

Scope is deliberately undecided — the folder exists, the design does not.

- **What does the player select, and how?** P.U.M.P. selects oil wells and MPP selects an ore
  patch; an upcycler has no world feature to point at. The input is probably *a recipe and a
  target quality* chosen in a GUI, with the selection tool only picking the empty ground to
  build on. This is the first question and most others hang off it.
- **What layout family does it emit?** Single-machine gacha, assembler+recycler pair, full
  five-tier ladder, recycler-only for raw upcycling. Probably several, chosen in the GUI.
- **How are rejects and outputs routed?** Belts, bots, or both. Drives most of the footprint.
- **Does it plan modules, or only request them?** `item-request-proxy` can ask bots to deliver
  quality modules into the ghosts, which is strictly better than asking the player to do it.
- **Module and machine tier selection.** Read from what the force has researched, or let the
  player pick and warn when it is not yet available.
- **Does it support modded quality tiers?** `quality-cycler` reads the active quality chain
  rather than hard-coding names; that is the right precedent if this mod ever hard-codes any.
- **`thumbnail.png` does not exist.** 144x144 at the mod root, needed before release.
  Deliberately not stubbed — a placeholder is the kind of thing that ships by accident.
- **No `data.lua` or `control.lua` yet.** Both arrive with the first real feature, not before.
