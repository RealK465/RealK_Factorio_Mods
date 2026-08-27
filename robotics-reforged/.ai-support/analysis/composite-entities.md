---
verified_against: 2.1.16
verified: 2026-08-27
---
# Composite entities — one building made of several prototypes

Read out of the installed `doc-html/prototype-api.json`, the game's own `data/`, and Space
Exploration 0.7.60 as it sits in `exemples/`. Written 2026-08-27 because the question *"can a
roboport burn fuel instead of taking electricity?"* has a hard **no** at the prototype level and
a **yes** one layer up, and the layer up is a general technique this mod will need more than
once if roboports ever come into scope (`../deferred.md` → *Roboports*).

Game-data citations give `file:line` against 2.1.16; prototype-API citations give
`Prototype::property`. Space Exploration paths are given relative to its own folder — that
collection is optional local reference and absent from a fresh clone, so nothing here depends
on it being present.

## 1. The constraint that forces the pattern

`RoboportPrototype::energy_source` is a union of exactly two options: `ElectricEnergySource` and
`VoidEnergySource`. It is **mandatory** and there is no burner or fluid option, so a roboport
cannot be told to eat coal. `VoidEnergySource` is free power, not fuel.

The restriction is deliberate rather than an oversight. Wube's stated reason, on the forum
thread requesting it, is that an electric buffer is refilled wholesale each tick, whereas a
burner source would have to compute and subtract a varying amount from fuel every tick against
varying fuel effectivity — and a roboport's draw is dynamic, rising with the number of robots
charging.

Two consequences worth having in writing:

- **The escape hatch is not scripting the roboport off.** `LuaEntity.disabled_by_script` names
  Roboport among the types that *"need to remain active and will ignore writes"*, so
  "void-powered roboport that a script switches off when the fuel runs out" does not work. Read
  from `doc-html/runtime-api.json`.
- **The equipment version has no such limit.** `RoboportEquipmentPrototype::burner` is a real
  optional `BurnerEnergySource`, documented as *"Add this if the roboport should be fueled
  directly instead of using power from the equipment grid"*, and requires `power` alongside it.
  So a fuel-burning **personal** roboport is a pure data-stage prototype with no script at all.
  `GeneratorEquipmentPrototype::burner` is the same story for grid power.

**Verified.** Read from `doc-html/prototype-api.json` and `doc-html/runtime-api.json` at 2.1.16.

## 2. Space Exploration's construction pylon — the closest analogue that exists

SE ships a building that is *already* a roboport welded to something that is not one, and it is
the cleanest example in the collection because the whole implementation is small.

`se-pylon-construction` is **two prototypes at one position**:

| Part | Type | Where | Role |
|---|---|---|---|
| `se-pylon-construction` | `electric-pole` | `prototypes/phase-1/entity/pylons.lua:304` | the visible, placeable, minable entity — the only one the player ever touches |
| `se-pylon-construction-roboport` | `roboport` | `prototypes/phase-1/entity/pylons.lua:393` | hidden child, created by script, supplies the construction radius |

The pole carries the graphics, the item, the recipe, the health and the wire connections. The
roboport carries only the roboport behaviour. Neither is a modified version of the other.

**The child is powered because the parent is a pole.** This is the load-bearing trick and it is
easy to miss: the hidden roboport has an ordinary electric energy source (`pylons.lua:465`,
`energy_usage = "10kW"`, buffer 100MJ, `secondary-input`), and it joins an electric network the
same way any building does — by standing inside a pole's supply area. The pole it stands inside
is its own parent. No wire, no script, no energy transfer code.

SE scales the same pattern to three parts without changing it: `se-pylon-construction-radar`
(`pylons.lua:524`) is a pole plus a hidden roboport (`pylons.lua:612`) plus a hidden radar
(`pylons.lua:738`).

**Verified.** Read from the mod's own source.

## 3. The child prototype, field by field

Every field below is doing a job. This is the part worth copying verbatim.

```lua
{ -- pylons.lua:393
  type = "roboport",
  name = "se-pylon-construction-roboport",
  subgroup = "composite-entity-parts",     -- an "other"-group subgroup SE defines itself
  order = "a",
  factoriopedia_alternative = "se-pylon-construction",  -- Factoriopedia shows the parent instead
  selectable_in_game = false,              -- clicks fall through to the parent
  hidden = true,                           -- out of Factoriopedia and the search
  collision_mask = {layers={}},            -- no collision, so it can sit inside the parent
  circuit_wire_max_distance = 0,           -- the parent owns the circuit connections
  flags = { "placeable-neutral", "not-blueprintable", "not-deconstructable" },
  logistics_radius = 0,                    -- construction only, no logistics network
  construction_radius = 32,
  material_slots_count = 0,
  robot_slots_count = 0,                   -- no inventory at all
  base = blank_image,                      -- parent draws the building; child draws only the
  door_animation_up = blank_image,         -- roboport animations layered over it
}
```

Four of those deserve naming explicitly:

- **`not-blueprintable` on the child is what makes blueprints work.** The parent is
  blueprintable and the child is not, so a blueprint captures one entity, and the script
  recreates the child when the parent is built from that blueprint. This is far cheaper than
  handling child ghosts, which is the road SE's spaceship clamp had to take instead (997 lines
  in `scripts/spaceship-clamp.lua`, much of it ghost bookkeeping, because that composite's parts
  can legitimately be blueprinted and cloned with a moving ship).
- **`not-deconstructable`** stops the child being marked for deconstruction on its own.
- **`hidden` is a `PrototypeBase` field** (2.0+, default `false`), not an entity flag;
  `selectable_in_game` is an `EntityPrototype` field defaulting to `true`. They are different
  switches and a composite child wants both.
- **`collision_mask = {layers={}}`** is what allows two entities to occupy the same tiles. The
  parent keeps the real collision box.

**Verified.** Field existence and defaults from `doc-html/prototype-api.json`; values from SE's
source.

## 4. The control side is 88 lines

`scripts/composites.lua` is the entire runtime cost of the pylon composites. The shape:

- **On create** — `LuaSurface.find_entity` by child name at the parent's position first, and
  only `LuaSurface.create_entity` if nothing is there. The find-first guard makes the handler
  idempotent, which matters because several of the creation events can fire for one placement.
  The child inherits the parent's `position`, `direction` and `force`, and is then set
  `destructible = false` so it can never be damaged or killed independently.
- **On remove** — `LuaSurface.find_entity` by name and position, then `LuaEntity.destroy`.

Position-plus-name lookup is the whole bookkeeping system: **no `storage` table, no entity
registration, nothing to migrate.** That is only possible because the child sits at exactly the
parent's position and is the only entity of its name there.

The events matter more than the code. SE aggregates them (`scripts/event.lua:67` and `:77`):

| Creation | Removal |
|---|---|
| `on_built_entity` | `on_player_mined_entity` |
| `on_robot_built_entity` | `on_robot_mined_entity` |
| `on_space_platform_built_entity` | `on_space_platform_mined_entity` |
| `script_raised_built` | `on_entity_died` |
| `script_raised_revive` | `script_raised_destroy` |

`script_raised_revive` is the ghost-revival case and `on_space_platform_*` are the 2.0+
platform cases. Missing any one of these produces a building that works when placed by hand and
is silently broken when a construction robot places it.

**Verified.** Read from the mod's own source.

## 5. What this pattern does not handle

- **`on_entity_cloned` is absent from `composites.lua`.** Other SE scripts do listen for it
  (`scripts/beacon.lua:173`, `scripts/capsule.lua:175`, `scripts/delivery-cannon.lua:825`), so
  the omission looks like a real gap rather than a decision: cloning a surface would copy the
  parent and, because the child is not blueprintable but *is* a real entity, produce a composite
  in an inconsistent state. Any composite written here should include it from the start.
- **Undo and fast-replace were not traced.** Not checked in either direction.
- **The child's GUI is unreachable.** `selectable_in_game = false` means the player cannot open
  it. SE gets away with this because its hidden roboport has `robot_slots_count = 0` and
  `material_slots_count = 0` — nothing to open. A composite whose child *does* hold items has to
  answer the access question some other way; see §6.

## 6. Applying it to a fuel-burning roboport

The pylon inverts cleanly. SE's parent is a pole and its child a roboport; a burner roboport
needs a third part, because the fuel has to live somewhere with a fuel inventory.

- **`burner-generator` already exists in vanilla** and is already hidden:
  `data/base/prototypes/entity/entities.lua:10252`, `hidden = true`, `max_power_output = "1MW"`,
  a `chemical` burner at `effectivity = 0.5` with one fuel slot, and an electric energy source
  at `secondary-output`. It is a working template, not something to invent.
- **The roboport is `secondary-input`** (`data/base/prototypes/entity/entities.lua:6802`, buffer
  100MJ, `input_flow_limit = "5MW"`). Generator at `secondary-output` feeding machine at
  `secondary-input` is the ordinary path, so there is no priority puzzle here.
- **A pole with no wire reach is the default.** `ElectricPolePrototype::maximum_wire_distance`
  is optional and defaults to **0** — a pole that cannot connect to any other pole is a normal,
  supported prototype. `supply_area_distance` is independent of it and mandatory. So a hidden
  pole with wire distance 0 and a supply area covering just the footprint is the private network
  the generator and the roboport share, with no route into the player's grid.

That gives a three-part composite on the pylon's own model: one visible parent, plus a hidden
pole and a hidden generator and a hidden roboport as children, all at one position, all created
and destroyed by the eleven events in §4.

**The unresolved part is player access, and it is a design question rather than a technical
one.** The fuel slot and the robot inventory live on two different children, and
`selectable_in_game = false` gives the player exactly one thing to click. Three ways out, none
of them measured:

1. Make the **generator** the visible parent. Player clicks it and gets a fuel slot; inserters
   fuel it normally; the roboport keeps `robot_slots_count = 0` like SE's, and the building is a
   charging-and-construction pylon rather than a robot store.
2. Make the **roboport** the visible parent and give the hidden generator a small selection box
   at one corner as a "fuel port" — two click targets, unambiguous for inserters only if the
   port sits outside the roboport's own footprint.
3. Keep the roboport visible and draw a fuel slot beside its GUI.
   `defines.relative_gui_type.roboport_gui` exists in 2.1.16, so a relative GUI frame backed by
   the hidden generator's burner inventory is possible; inserters would still have no target.

**Partially verified.** The prototype fields, defaults and vanilla values are read from the
install. The composite behaviour is inferred from SE's working example, not built and run — see
§7.

## 7. What is NOT verified

- **UNVERIFIED — that a hidden pole with `maximum_wire_distance = 0` really yields an isolated
  network in play.** The field default is read from the prototype API; that a generator and a
  roboport sharing only that pole's supply area form one network with no route to the player's
  grid was not built and tested.
- **UNVERIFIED — that inserters fuel a hidden child.** The `no-automated-item-insertion` entity
  flag exists specifically to *prevent* inserters inserting, which implies the default is that
  they do, and `selectable_in_game` governs selection rather than inserter targeting. Neither
  was tested, and the ambiguous case — two entities sharing a drop tile — was not tested at all.
- **UNVERIFIED — `on_entity_cloned` behaviour for composites.** Named as a gap in §5 by reading
  SE's source, not by reproducing it.
- **UNVERIFIED — the 100MJ buffer's effect on a burner tier.** A roboport charging a 100MJ
  buffer at up to 5MW from a 1MW generator spends roughly 100 seconds burning fuel before doing
  useful work. The arithmetic follows from the cited values; the in-game feel does not, and the
  buffer almost certainly wants shrinking for a fuel tier.
- **Not surveyed — whether any published mod ships a burner roboport.** A mod-portal search on
  2026-08-27 turned up none, and the overhaul mods that convert everything to burners
  (*Only Burner*, *Burn the World*) exclude roboports explicitly. Absence of evidence only.
