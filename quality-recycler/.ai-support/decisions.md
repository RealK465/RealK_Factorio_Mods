# Decisions — Quality Recycler

What is settled, and why. Rewritten in place when superseded — see the repo `CLAUDE.md` →
*AI support folders*.

## Name

`quality-recycler`, title "Quality Recycler". Chosen over `embedded-quality-recycler` and
`recycler-quality` (both also free) for reading naturally as a search term. Confirmed unclaimed
on the mod portal 2026-09-10 — `GET https://mods.factorio.com/api/mods/<name>` returned 404 for
all three candidates.

## Dependencies

`["base >= 2.1.0", "quality >= 2.1.0", "recycler >= 2.1.0", "space-age >= 2.1.0"]`.

**`space-age` was added 2026-09-10, resolving the conflict the design created.** The technology
gate needs metallurgic, electromagnetic and agricultural science, and those three packs exist
only with Space Age — so of the two things that had to move, the dependency is the one that
moved. The alternative was changing a tech gate that had already been settled from the repo
owner's own brief. It does narrow the audience: `recycler` and `quality` ship independently of
`space-age`, so a player could have had the first two without the third.

`quality >= 2.1.0` alone would pull `recycler` in transitively on Factorio 2.1 — confirmed by
reading the installed `data/quality/info.json`, which itself declares
`"dependencies": ["base >= 2.1.0", "recycler >= 2.1.0"]` — the same shortcut `upcycler-planner`
relies on. This mod declares `recycler` explicitly anyway, because unlike `upcycler-planner`
(which treats the recycler as one of several configurable machines a player may or may not use)
this mod's own data-stage code will directly deep-copy the vanilla recycler prototype
(`data.raw["furnace"]["recycler"]`) to build the new entity from. The dependency should say what
the mod actually touches, not lean on another mod's transitive chain to make that true.

`quality_required: true` is declared for the same reason `upcycler-planner` gives it: the mod
has no purpose without quality tiers, so the flag is an honest declaration rather than a
functional necessity (the hard `quality` dependency already guarantees `feature_flags["quality"]`
is true wherever this mod loads).

`expansion_required` is deliberately **not** set. Checked against
`doc-html/auxiliary/mod-structure.html` on 2026-09-10: the flag gates belt-stacking properties
only (`InserterPrototype::max_belt_stack_size`, `LoaderPrototype::max_belt_stack_size` and
`adjustable_belt_stack_size`, `MiningDrillPrototype::drops_full_belt_stacks`), none of which this
mod has any reason to touch. Wube's own `quality` and `recycler` packages set it on themselves
regardless — that is their own packaging choice, not evidence it belongs here too.

## Version

Starts at `0.1.0`, unpublished (`changelog.txt` carries `Date: ????`, no
`quality-recycler_0.1.0` git tag). Matches the convention in `pure-modules-realk` and
`upcycler-planner`.

## The recycler's mechanic and stats

Settled 2026-09-10, from the repo owner's own numbers. Resolves the question `deferred.md` used
to carry as open.

- **Built-in quality, no modules needed**: `effect_receiver.base_effect.quality = 0.12` on the
  entity prototype. Verified against `prototype-api.json` (2.1.17) before relying on it:
  `CraftingMachinePrototype` (the recycler's parent — `type = "furnace"`) carries
  `effect_receiver: EffectReceiver`, `EffectReceiver.base_effect: Effect`, and
  `Effect.quality: EffectValue` — "Adds a bonus chance to increase a product's quality." Same
  field quality modules use; this entity carries it for free and permanently, on top of whatever
  quality modules a player adds on top.
- **Crafting speed 1.0** — 2x the vanilla recycler's `crafting_speed = 0.5`
  (`data/recycler/data.lua:143`).
- **3x3 footprint.** The vanilla recycler is actually **2x4**, not square
  (`collision_box = {{-0.7, -1.7}, {0.7, 1.7}}`, `data/recycler/data.lua:138`, matching the
  `tile_width`/`tile_height` = 2/4 recorded against its corpse at lines 276-277) — 8 tiles. 3x3
  is 9 tiles, so this is barely bigger by area; the real change is shape, square instead of a
  2-wide slot. Worth knowing before "3x3" reads as a big jump — by tile count it isn't.

**The rest of the numbers, chosen 2026-09-10 when the prototype was written.** None of them had
a right answer waiting; each is placed between the vanilla recycler and the electromagnetic
plant, which are the two machines this one sits between:

| | this | vanilla recycler | EM plant |
|---|---|---|---|
| `energy_usage` | **600kW** | 180kW at half the speed | 2000kW |
| `max_health` | **400** | 300 | 350 |
| `module_slots` | **4** | 4 | 5 |
| pollution/min | **4** | 2 | 4 |

Module slots stay at 4 rather than rising with the tier: the machine already carries a permanent
quality bonus, and more slots on top would compound the one thing it exists to do.

`allowed_effects` is the vanilla recycler's exactly — `consumption`, `speed`, `pollution`,
`quality`, and **no productivity**. Recycling returns a fraction of what went in, so a
productivity bonus on it would be free matter.

**Prototype name: `quality-recycler`**, matching the mod, the item and the recipe, exactly as
vanilla's `recycler` mod names its own. The design's suggestion of a name about the sorting step
rather than the shredding one was not taken — "quality recycler" is what a player would search
for, and the entity is still a recycler.

**Its own technology, `quality-recycling`**, rather than an effect bolted onto `recycling`:
`recycling` is a Nauvis technology and this unlocks three planets later, so sharing it would
mean either moving that gate or unlocking this machine far too early. Prerequisites are
`recycling` plus the three science-pack technologies, which is what actually guarantees the
player has all three planets.

**The recipe eats a whole `recycler`**, plus tungsten plate (Vulcanus), supercapacitors
(Fulgora), carbon fibre (Gleba) and processing units. That is the design's lore made mechanical:
the machine is not new, it is a recycler that came back from three planets with half of it
replaced, and the bill of materials says where it has been.

## The technology gate

Settled 2026-09-10 from the repo owner's brief: **unlocked after the first three planets** —
metallurgic + electromagnetic + agricultural science, no cryogenic pack.

That is a real, singular rung rather than a vague late-game. Verified by scanning every
`type = "technology"` in `data/space-age/prototypes/technology.lua` on 2026-09-10: exactly one
vanilla technology sits at those three sciences without cryogenic, `planet-discovery-aquilo`.
Everything else at that level (`railgun`, `fusion-reactor`, `foundation`, `quantum-processor`,
`captive-biter-spawner`, `stellar-discovery-solar-system-edge`) also requires cryogenic and is
therefore post-Aquilo. So this entity unlocks at the exact moment the player has all three
mid-game planets' industries and nothing from Aquilo yet.

The vanilla recycler by contrast unlocks at `recycling`, which needs only production science
(`data/recycler/data.lua:83`) — it is a Nauvis machine. This one is three planets later, and
the art is built on that gap.

**This creates a dependency problem the design did not have.** The three planet science packs
only exist with Space Age, but `info.json` declares only `base`, `quality` and `recycler`. Either
the dependency set or the gate has to move. Open in `deferred.md`.

## Art direction

Settled 2026-09-10 through a full `factorio-entity-design` session. The entity is a **salvaged
vanilla recycler with planet-tier sorting gear grafted on**, and its hero is an **eddy-current
sorting rotor** — quality read as separation, not as transmutation.

The design, its reasoning and its measured reference numbers are in
`quality-recycler-design.md`. Two decisions from it bind the prototype and belong here because
code will need them before the art exists:

- **Rotatable, four directions plus mirrored** — the full vanilla recycler treatment, chosen
  over the cheaper non-directional option that every vanilla 3x3 uses. This is the mod's largest
  art cost.
- **`collision_box = {{-1.2,-1.2},{1.2,1.2}}`** for the 3x3, matching the vanilla 3x3 convention.
  Measured 2026-09-10: chemical plant and biochamber both collide at 2.4 and round to 3x3. Note
  the electromagnetic plant is **4x4**, not 3x3 — it collides at 3.4 — so it is this entity's
  mechanical precedent (`effect_receiver.base_effect`) but not its size reference.

## Scaffold only, no Lua yet

Set up 2026-09-10 as folders and docs only, per the repo owner's standing instruction to
scaffold a new mod before writing any code — see `journal.md` for the session. The mechanic is
the open question in `deferred.md`; nothing here commits to a reading of "embedded quality"
beyond the user's own phrase.
