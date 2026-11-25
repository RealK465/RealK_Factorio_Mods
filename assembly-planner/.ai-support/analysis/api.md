---
verified_against: 2.1.23
verified: 2026-11-25
---

# Engine facts measured for Assembly Planner

Measured on 2.1.23 (Space Age set) through a throwaway probe mod (`apl-probe`, run with the
`factorio-testing` runner from the session scratchpad, deleted after), then pinned permanently
by the suite: `tests/blueprint_spec.lua`, `tests/cell_live_spec.lua`, `tests/proto_spec.lua`,
`tests/plan_spec.lua`. Every claim is **Verified** unless it says otherwise.

## 1. A blueprint's `bar` is the number of usable slots — Verified

`BlueprintEntity` documents `bar :: ItemStackIndex` for `container` and `logistic-container`
without saying what it counts. Measured both ways:

| written in the blueprint | `LuaInventory.get_bar` after revive |
|---|---|
| `bar = 2` | 3 |
| `bar = 1` | 2 |
| `bar = 0` | 1 (nothing usable) |
| no `bar` | 49 on a 48-slot passive provider (`#inventory + 1`) |

`LuaInventory.get_bar` is documented as "the index at which the red area starts" — 1-based — so
the blueprint's number is the count of open slots. The reverse holds: `LuaInventory.set_bar`
with 3 on a live chest, captured with `create_blueprint`, reads back `bar = 2`; with 1, `bar = 0`.
Physically: a burner inserter feeding power armour (stack size 1) into a `bar = 2` chest
stopped at exactly 2. The owner's example blueprint `bar = 2` therefore means two slots, and
`cell_live_spec` pins it again with a one-slot cap that holds exactly one stack of 100 gears.

## 2. A nameless normal-quality filter survives and splits — Verified

Upcycler Planner measured nameless quality filters at `rare`; a mall cell needs them at
`normal`, where the engine omits normal elsewhere on read-back (a dropped quality would turn the
filter into "anything"). It does not drop it here: `{quality = "normal", comparator = "="}` and
`{quality = "normal", comparator = ">"}` written into `set_blueprint_entities` read back with
`quality = "normal"` and the comparator intact, revive to `LuaEntity.get_filter` returning the
same, and between a chest of 20 normal and 20 uncommon plates the `=` inserter moved exactly the
20 normal and the `>` one exactly the 20 uncommon. `cell_live_spec` pins it on a machine's
output.

## 3. The pipe row along the back, per machine — Verified

A pipe row along the machine's north face, wider than the machine, fed from its west end by an
infinity pipe, read after 180 ticks:

| machine | direction | fluid in the machine |
|---|---|---|
| assembling machine 3, `electric-engine-unit` | north | lubricant 60 |
| chemical plant, `battery` | north | sulfuric acid 80 (both north-corner inputs on the row) |
| electromagnetic plant, `supercapacitor` | east | electrolyte 400 |
| electromagnetic plant | north | 0 — inputs on the flanks |
| foundry, `big-mining-drill`, Vulcanus-pressure lab | south | molten iron 800 |
| foundry, same | north | 0 — inputs authored south |

The foundry's inputs are authored on its south face and its outputs on the north
(`data/space-age/prototypes/entity/entities.lua:1301`), so it stands at south to put an input on
the row — exactly the owner's example blueprint, a foundry at direction 8. The rotation rule
itself is Upcycler Planner's (its api.md §14); `proto.fluid_rotation` asks it for north instead
of west. `cell_live_spec` pins the row live: two cells stamped side by side, fed from the first
cell's west end, fill both machines through the join.

## 4. Planet-locked recipes take no fluid boxes off-planet — Verified

`big-mining-drill` carries `surface_conditions` of pressure 4000..4000 (Vulcanus). On nauvis a
foundry created with that recipe grew no fluid box at all and took no molten iron whichever way
it faced; on a lab surface with `LuaSurface.set_property` pressure 4000 the same rig filled. So
the plan warns, never refuses, when `LuaRecipePrototype.surface_conditions` or the machine's
`LuaEntityPrototype.surface_conditions` fail on the player's current surface: the blueprint is
still right, just for another planet.

## 5. Beacon reach around a cell — Verified

Vanilla beacons (3x3, supply 3) around an assembling machine 3, membership read from
`LuaEntity.get_beacon_effect_receivers`, unpowered. Positions relative to the machine's
top-left tile:

| beacon | no pipe row | with a one-row pipe gap |
|---|---|---|
| left and right, level with the machine | reaches | reaches |
| left and right, stacked one below | reaches | reaches |
| above-left, above, above-right | reaches | reaches |

All seven reach, corners included, with or without the pipe row between the machine and the row
above. The cell nevertheless offers a side stack only as tall as the machine plus its two rows
(`cell.lua`), so a cell stays one rectangle; on an AM3 that is one beacon a side. Two cells
side by side share nothing: `cell_live_spec` stamps two beaconed AM3 cells flush and every
beacon reaches its own machine only (the edge rule of Upcycler Planner's api.md §25 predicts
it: 2.7 + 3 falls short of the neighbour's collision box).

## 6. Space Age gives several items a second recipe that sorts first — Verified

`iron-gear-wheel` is made by `iron-gear-wheel` and by Space Age's `casting-iron-gear-wheel`
(foundry, molten iron only), and the casting recipe sorts first. A default of "the first
researched recipe" therefore turned a gear cell in an assembler into a foundry cell fed by a
pipe. The plan's default prefers, in order: a researched recipe, one the chosen machine can
craft, the one named like the item. Found by `plan_spec`, pinned by `gui_spec`.
