---
verified_against: 2.1.16
verified: 2026-08-27
---
# Vanilla's robots — the measured baseline

Every number a tier will be argued against, read out of the installed game's own `data/` and
`doc-html/prototype-api.json` rather than recalled. Written 2026-08-27, before any prototype
existed, because two of the findings below constrain the design rather than merely inform it.

Game-data citations give `file:line`; prototype-API citations give `Prototype::property`. Line
numbers shift on every game update, which is exactly why they are cited — the repo's
`check-ai-docs.py` fails the day this file's install is replaced.

## 1. The two robots

`data/base/prototypes/entity/flying-robots.lua:615` (construction) and
`data/base/prototypes/entity/flying-robots.lua:677` (logistic). Both are 2.1.16 base; neither is
touched by Space Age.

| Field | construction-robot | logistic-robot |
|---|---|---|
| `speed` (tiles/tick) | 0.06 | 0.05 |
| `max_speed` | *unset* | *unset* |
| `max_payload_size` | 1 | 1 |
| `max_payload_size_after_bonus` | *unset* | *unset* |
| `max_energy` | 3MJ | 1.5MJ |
| `energy_per_tick` | 0.05kJ | 0.05kJ |
| `energy_per_move` | 5kJ | 5kJ |
| `speed_multiplier_when_out_of_energy` | 0.2 | 0.2 |
| `min_to_charge` / `max_to_charge` | 0.2 / 0.95 | 0.2 / 0.95 |
| `max_health` | 100 | 100 |
| resistances | fire 85%, electric 50% | fire 85% |

Two differences carry the whole distinction between them: the construction robot is **20%
faster** and carries **twice the battery**, which is what lets it range further from a roboport
before it has to charge. Everything else is identical.

`is_military_target = false` is set on the logistic robot and **not** on the construction robot —
biters shoot construction robots and ignore logistic ones. Easy to lose when copying a prototype
across kinds.

**Verified.** Read directly from the cited lines.

## 2. The two caps, and why they decide the design

`FlyingRobotPrototype::max_speed` — doc verbatim: *"The maximum flying speed of the robot,
including bonuses, in tiles/tick. Useful to limit the impact of worker robot speed research."*

`RobotWithLogisticInterfacePrototype::max_payload_size_after_bonus` — *"The robot's maximum
possible cargo carrying capacity, including bonuses. Useful to limit the impact of worker robot
cargo size research."*

**Neither is set on either vanilla robot**, so vanilla's robots are uncapped and research lifts
them without limit.

This is the constraint the tier design hangs off, because of §3: research is force-wide, so a
tier whose only distinction is a higher *base* number converges with every other tier as
research accumulates. The caps are the only per-prototype fields that resist that. A tier
system that means to stay legible at maxed research either sets them, or accepts that its tiers
matter early and stop mattering later.

**Verified.** Property descriptions read from `doc-html/prototype-api.json`;
absence from the prototypes confirmed against the two cited definitions.

## 3. Research is force-wide, and Space Age moves the infinite tech

Both robot bonuses are force modifiers with no per-prototype targeting: `worker-robot-speed` and
`worker-robot-storage`. Every robot the force owns gets them.

**Speed** — `worker-robots-speed-1` at `data/base/prototypes/technology.lua:4032`, six levels in
base:

| Level | modifier | science |
|---|---|---|
| 1 | +0.35 | red/green, 50 |
| 2 | +0.40 | red/green, 100 |
| 3 | +0.45 | + utility, 150 |
| 4 | +0.55 | 250 |
| 5 | +0.65 | + production, 500 |
| 6 | +0.65 | + space, 1000 |

Levels 1–5 total **+2.4**, i.e. 340% of base speed before the infinite tech starts.

**The infinite tech is a different technology depending on the expansion set**, which is easy to
get wrong when pricing a tier:

- **Base alone:** `worker-robots-speed-6` is `max_level = "infinite"` with
  `count_formula = "2^(L-6)*1000"` (`data/base/prototypes/technology.lua:4185`).
- **With Space Age:** `data/space-age/base-data-updates.lua:601-605` rewrites speed-6 into a
  *finite* technology (`max_level = nil`, flat `count = 1000`), and
  `data/space-age/prototypes/technology.lua:516` adds `worker-robots-speed-7` behind the
  electromagnetic science pack as the new infinite one, +0.65 per level.

**Storage** — `worker-robots-storage-1` at `data/base/prototypes/technology.lua:4190`, three
levels, `modifier = 1` each, ending at `worker-robots-storage-3`
(`data/base/prototypes/technology.lua:4241`). Total **+3**, so a fully-researched vanilla robot
carries 4. Finite, and Space Age does not touch it — grepped, no override.

**Verified.** All values read from the cited lines.

## 4. Recipes

- `logistic-robot` (`data/base/prototypes/recipe.lua:2123`) — 1 flying-robot-frame +
  2 advanced-circuit.
- `construction-robot` (`data/base/prototypes/recipe.lua:2134`) — 1 flying-robot-frame +
  2 electronic-circuit.

Both `enabled = false`, unlocked by their technologies. The logistic robot is the more expensive
of the two by exactly one circuit tier — a small gap worth preserving or deliberately breaking,
not accidentally flattening.

**Verified.**

## 5. Prototype inheritance, for a tier that copies

```
EntityWithOwnerPrototype
  └─ FlyingRobotPrototype                        speed, max_speed, max_energy,
     │                                           energy_per_tick, energy_per_move,
     │                                           speed_multiplier_when_out_of_energy,
     │                                           min_to_charge, max_to_charge, is_military_target
     └─ RobotWithLogisticInterfacePrototype      max_payload_size,
        │                                        max_payload_size_after_bonus, draw_cargo,
        │                                        destroy_action, require_charge_to_mine,
        │                                        idle / in_motion / shadow_* animations
        ├─ LogisticRobotPrototype                *_with_cargo animation variants
        └─ ConstructionRobotPrototype            working, shadow_working, working_light,
                                                 construction_vector, repairing_sound, smoke,
                                                 sparks, mined_sound_volume_modifier
```

Both leaf types require `collision_box` to be **size zero** — doc verbatim: *"Must have a
collision box size of zero."*

The animation surface is why copying a vanilla prototype is the cheap path to a new tier: eight
to twelve animation fields plus shadows, a `dying_explosion` and remnants all come along, and
only the numbers in §1 need writing.

**Verified.** Read from `doc-html/prototype-api.json`.

## 6. Roboports, in one line

`data/base/prototypes/entity/entities.lua:6803`, `max_health = 500`. Not surveyed further —
roboports are parked (`../deferred.md`), and this line exists only so the next session knows
where the prototype is.

**Partially read.** Only the location and health were checked.

## 7. What is NOT verified

Listed explicitly so it is probed rather than trusted:

- **UNVERIFIED — what Space Age quality scales on a flying robot.** A robot is an item that
  becomes an entity, so a legendary construction robot presumably exists, but whether quality
  lifts health only, or also speed and payload, was not checked. If it lifts the same numbers a
  tier would, quality and tiers compete for the same design space. `../deferred.md` → *Quality*
  carries the consequence.
- **UNVERIFIED — roboport charging as the real throughput ceiling.** Stated as received wisdom
  in `../deferred.md` → *Roboports*, not measured here. The pad count and charging rate are on
  the roboport prototype and were not read.
- **UNVERIFIED — how `max_speed` interacts with an already-researched force.** The doc says the
  cap includes bonuses; whether a robot at the cap displays its capped speed in Factoriopedia,
  or its uncapped one, was not checked and is a UI question a player will notice.
- **Not surveyed — the existing robot-tier mods on the portal.** No reference-mods note exists
  yet; see `../deferred.md` → *Compatibility with existing robot mods*.
