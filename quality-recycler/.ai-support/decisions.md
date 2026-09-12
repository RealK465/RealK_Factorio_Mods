# Decisions — Quality Recycler

What is settled, and why. Rewritten in place when superseded — see the repo `CLAUDE.md` →
*AI support folders*.

## Name

`quality-recycler`, title "Quality Recycler". Chosen over `embedded-quality-recycler` and
`recycler-quality` (both also free) for reading naturally as a search term. Confirmed unclaimed
on the mod portal 2026-09-10 — `GET https://mods.factorio.com/api/mods/<name>` returned 404 for
all three candidates.

## Dependencies

`["base >= 2.1.0", "quality >= 2.1.0", "recycler >= 2.1.0", "? space-age"]`.

**`space-age` is optional since 2026-09-11** (the owner's balance brief: "balanced for space
age and vanilla"). It had been hard from 2026-09-10 because the technology gate needs the three
planetary science packs, which exist only with the expansion, and that narrowed the audience:
`recycler` and `quality` ship independently of `space-age`. The mod now carries two recipes and
two technology gates, chosen in `prototypes/recycler/item.lua` on `mods["space-age"]` — `mods`
rather than a feature flag because the branch is about which *items and science packs* exist,
which is exactly what `mods` answers (the flag route is for expansion-gated *properties*, see
the `factorio-mod-development` skill's compatibility reference). The optional dependency
carries no version: a version on an optional dependency disables the mod when the other is
present at a lower one, and nothing here needs a particular Space Age version. Both branches
validate: the default install, and the same install with `-Disable space-age`.

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
- **4x4 footprint** (the owner's call, 2026-09-11; it was 3x3 from 2026-09-10 until then).
  The vanilla recycler is actually **2x4**, not square
  (`collision_box = {{-0.7, -1.7}, {0.7, 1.7}}`, `data/recycler/data.lua:138`, matching the
  `tile_width`/`tile_height` = 2/4 recorded against its corpse at lines 276-277) — 8 tiles,
  so 16 tiles is twice the vanilla machine's area, and the same footprint as the
  electromagnetic plant, which is this entity's mechanical precedent. The art was rebuilt to
  the new box in the same session — see `quality-recycler-design.md` → *v4*.

- **Crafting speed 1.25** — 2.5x the vanilla recycler's `crafting_speed = 0.5`
  (`data/recycler/data.lua`), the assembling machine 3's number. The owner's call on 2026-09-11
  (it was 1.0 from 2026-09-10). The animation keeps its tempo: `pictures.lua` plays at 1.6
  frames per tick, which the engine scales by the crafting speed to the recycler's own 2.
- **Five module slots** — the electromagnetic plant's. The owner's call on 2026-09-11; until
  then the register held 4 on the reasoning that a permanent bonus should not be compounded.
  It is compounded now on purpose: this is the top tier, and the electricity pays for it.

**The rest of the numbers, re-balanced 2026-09-11.** Each is placed between the vanilla recycler
and the electromagnetic plant, which are the two machines this one sits between:

| | this | vanilla recycler | EM plant |
|---|---|---|---|
| `crafting_speed` | **1.25** | 0.5 | 2 |
| `energy_usage` | **1000kW** | 180kW | 2000kW |
| kW per unit of speed | **800** | 360 | 1000 |
| `module_slots` | **5** | 4 | 5 |
| free bonus | 12% quality | none | +50% productivity |
| `max_health` | **400** | 300 | 350 |
| pollution/min | **4** | 2 | 4 |

**Electricity is priced by the free bonus.** Per unit of crafting speed the assembling machine 3
pays 300 kW, the vanilla recycler 360, the foundry 625, the cryogenic plant 750 and the
electromagnetic plant 1000 — the plant's free +50% productivity is what the extra buys. A free
12% quality is worth five normal quality module 3s (0.025 each, `data/quality/prototypes/item.lua`),
so this machine sits with the plant: 1 MW at 1.25 is 800 kW per unit of speed. Per item
recycled that is 2.2x the vanilla recycler's electricity (1000/1.25 against 180/0.5), where the
plant charges 3.3x an assembler 3 for the same recipe. Drain is the default thirtieth.

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

**The recipe eats a whole `recycler` and two quality module 3s** — the lore made mechanical
(the machine is not new, it is a recycler that came back with half of it replaced) and the
"quality built in" as an ingredient. The rest depends on the game, re-balanced 2026-09-11:

| | with Space Age | without |
|---|---|---|
| ingredients | recycler 1, quality module 3 x2, tungsten plate 30, supercapacitor 20, carbon fibre 30, processing unit 30 | recycler 1, quality module 3 x2, low-density structure 20, electric engine unit 10, processing unit 30 |
| `energy_required` | 10 (the EM plant's) | 10 |

With Space Age the planet materials say where the machine has been. The bill sits in the
electromagnetic plant's class (150 holmium plate, 50 steel, 50 processing units) once the
supercapacitors' holmium and the modules' circuits are counted, which is where a machine with
the plant's slot count and power draw belongs. Without Space Age the low-density structures are
the base game's own late-game material and the electric engines are the rotor's drive.

## The technology gate

Settled 2026-09-10 from the repo owner's brief: **unlocked after the first three planets** —
metallurgic + electromagnetic + agricultural science, no cryogenic pack. **Since 2026-09-11 that
is the Space Age gate; without the expansion the gate is the base game's own late game — after
`space-science-pack` (a technology in base as well as in Space Age; the expansion only changes
its trigger) with `utility-science-pack` and `quality-module-3` as prerequisites, since the recipe
uses the module.** Cost, both branches: 500 units of every pack the gate implies (seven with
Space Age, six without) at 60 s each — re-balanced from 1000 x 7 x 60, which was a research wall
for a single machine; `planet-discovery-aquilo`, the one vanilla technology at the Space Age
gate's rung, costs 3000 x 9 x 60 and unlocks a planet.

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

The dependency problem this once created — the planet science packs exist only with Space
Age — is resolved the other way round since 2026-09-11: Space Age is optional and the gate has a
base-game twin (*Dependencies* above).

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
- **`collision_box = {{-1.7,-1.7},{1.7,1.7}}`** for the 4x4, matching the vanilla 4x4
  convention: the electromagnetic plant collides at 3.4 and rounds to 4x4, and it carries
  `drawing_box_vertical_extension` for the same reason this entity now does (a sprite taller
  than its box, framed in the entity tooltip). Until 2026-09-11 the box was the 3x3
  convention's 2.4, measured off the chemical plant and the biochamber.
- **`result_inventory_size` is 25 in the prototype and sized in `data-final-fixes.lua` from
  the recipes.** 25 is the owner's floor (2026-09-12), against the vanilla recycler's 12 for
  scrap recycling's twelve results, and the final-fixes stage raises it to the largest result
  count of any recipe in the machine's crafting categories, never lowering it. A furnace cannot craft a recipe with more products
  than result slots, and the failure is silent: an inserter holding the ingredient simply
  never inserts. Krastorio 2 Spaced Out inserts `kr-electronic-components` as a 13th scrap
  result in its data-updates and sets the VANILLA recycler's slots to the new count in its
  final-fixes, leaving every other recycler at 12 — which is what the owner saw on
  2026-09-12: inserters would not feed the quality recycler Fulgora scrap while the vanilla
  one beside it ran. Read off the recipes rather than hard-coded, so any mod that adds
  results is covered; the count is taken in final-fixes because that is the last stage
  other mods write recipes in, and a mod whose final-fixes runs after this one could still
  add a result past it — accepted, since the vanilla recycler carries the same exposure.
  Recipes are read in both the 2.1 plural `categories` and the 2.0 singular `category`
  form, which keeps the file identical on both branches. Verified on the owner's mod set:
  13 slots after the fix against 12 before, and 25 once the floor went in.
- **The direct output stacks on belts, and nothing in the prototype decides that.**
  `CraftingMachinePrototype` has no belt-stacking field -- `max_belt_stack_size` belongs to
  inserters and loaders, `drops_full_belt_stacks` to mining drills -- so the answer had to be
  measured: the screenshot probe's `belt_report` reads every belt lane's contents through
  `LuaTransportLine.get_detailed_contents()`. With low-density structures recycled onto a
  three-tile dead-end belt for ten seconds (every technology researched, so the belt stack
  bonus is at its full 4), both this machine and the vanilla recycler beside it filled every
  belt tile with stacks of 4. So the engine stacks a `vector_to_place_result` drop like an
  inserter drop, up to the force's bonus, and there is nothing to set. Measured 2.1.17,
  2026-09-12.
- **`vector_to_place_result = {-0.35, -2.3}`** — the vanilla recycler's own value, kept
  because it solves the same problem: a 4x4's centre is a tile corner (a 2x4's too), so a
  result placed at x 0 would sit on the boundary between the two centre tiles past the north
  edge, and -0.35 lands well inside the west one (the mirrored machine, the east one). It was
  -0.15 until 2026-09-12: the right tile, but 5 px from the seam, and the owner's screenshot
  of a chest on each centre tile showed the arrow on the seam between them. The art's port is
  built on that line, so the value and the sprite move together or not at all.

## Scaffold only, no Lua yet

Set up 2026-09-10 as folders and docs only, per the repo owner's standing instruction to
scaffold a new mod before writing any code — see `journal.md` for the session. The mechanic is
the open question in `deferred.md`; nothing here commits to a reading of "embedded quality"
beyond the user's own phrase.
