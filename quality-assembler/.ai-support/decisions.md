# Decisions — Quality Assembler

What is settled, and why. Rewritten in place when superseded — see the repo `CLAUDE.md` →
*AI support folders*.

Everything below was settled on 2026-09-13, in the session that scaffolded the mod. Where a
number came from the game's own data it names the file; everything checked that day was checked
against the default dev install at **base 2.1.17**.

## Name

`quality-assembler`, title "Quality Assembler". Confirmed unclaimed on the mod portal
2026-09-13 — `GET https://mods.factorio.com/api/mods/<name>` returned 404 for it and for the
three alternatives considered (`quality-assembling-machine`, `quality-crafter`,
`quality-assembler-realk`). Chosen for the same reason `quality-recycler` was: it is what a
player would type into the portal search. The pair reads as a family.

The prototype, the item and the recipe all take the mod's own name, as vanilla does. The
technology is **`quality-assembly`** — a separate name, because a technology reads as a subject
rather than as a thing ("Quality assembly", matching the recycler mod's "Quality recycling").

## Version

Starts at `0.1.0`, unpublished. `changelog.txt` carries `Date: ????` and no
`quality-assembler_0.1.0` git tag exists. Matches the convention in `pure-modules-realk`,
`upcycler-planner` and `quality-recycler`.

## Dependencies

`["base >= 2.1.0", "quality >= 2.1.0", "? space-age"]`, with `quality_required: true`.

**No `recycler` dependency.** `quality-recycler` declares one because its data stage reads
`data.raw["furnace"]["recycler"]`; this mod touches nothing in the recycler package. The
dependency list should say what the mod actually touches.

**`space-age` is optional**, copying the shape `quality-recycler` settled on 2026-09-11. The
technology gate wants `cryogenic-science-pack`, which exists only with the expansion, so the mod
carries two recipes and two technology gates chosen on `mods["space-age"]` in
`prototypes/assembler/item.lua`. `mods` rather than a feature flag because the branch is about
which *items and science packs* exist, which is exactly what `mods` answers; the feature-flag
route is for expansion-gated *properties*. The optional dependency carries no version — a
version on an optional dependency disables the mod when the other is present at a lower one, and
nothing here needs a particular Space Age version.

**`quality_required: true`** is an honest declaration rather than a functional necessity: the
hard `quality` dependency already guarantees `feature_flags["quality"]` is true wherever this
mod loads, but the mod has no purpose without quality tiers. Same reasoning
`upcycler-planner` and `quality-recycler` give.

`expansion_required` is deliberately **not** set. It gates belt-stacking properties only
(`InserterPrototype::max_belt_stack_size`, `LoaderPrototype::max_belt_stack_size` and
`adjustable_belt_stack_size`, `MiningDrillPrototype::drops_full_belt_stacks`), none of which this
mod touches — checked against `doc-html/auxiliary/mod-structure.html` for `quality-recycler` on
2026-09-10 and unchanged since.

## The assembler's mechanic and stats

The repo owner's calls, 2026-09-13, from three options each.

- **Built-in quality, no modules needed**: `effect_receiver.base_effect.quality = 0.12` on the
  entity prototype. The same number `quality-recycler` carries, deliberately — the two machines
  are a matched pair and a player should not have to remember two figures.
- **Crafting speed 2** — the electromagnetic plant's, and **1.6x** the assembling machine 3's
  1.25.
- **Five module slots** — the electromagnetic plant's, against the assembling machine 3's four.
- **3x3 footprint**, `collision_box = {{-1.2, -1.2}, {1.2, 1.2}}` and `selection_box`
  `{{-1.5, -1.5}, {1.5, 1.5}}` — the assembling machine 3's exactly
  (`data/base/prototypes/entity/entities.lua`, the `assembling-machine-3` block). Chosen over
  the electromagnetic plant's 4x4 so the machine drops into an existing assembler row and bus
  spacing without a rebuild.

**`effect_receiver` is inherited, not assembler-specific.** Verified in
`doc-html/prototype-api.json` (2.1.17): `AssemblingMachinePrototype` has parent
`CraftingMachinePrototype`, and `CraftingMachinePrototype` is where `effect_receiver:
EffectReceiver` lives — the identical field `quality-recycler`'s furnace uses. `EffectReceiver
.base_effect: Effect` and `Effect.quality: EffectValue` were verified for that mod on
2026-09-10 and are the same fields here.

### Where the numbers sit

The two reference machines are the assembling machine 3 (what this replaces) and the
electromagnetic plant (the tier this joins). Both read out of the game's own data on 2026-09-13:

| | this | assembling machine 3 | EM plant |
|---|---|---|---|
| `crafting_speed` | **2** | 1.25 | 2 |
| `energy_usage` | **1600kW** | 375kW | 2000kW |
| kW per unit of speed | **800** | 300 | 1000 |
| `module_slots` | **5** | 4 | 5 |
| free bonus | 12% quality | none | +50% productivity |
| `collision_box` | **1.2 (3x3)** | 1.2 (3x3) | 1.7 (4x4) |
| `max_health` | **400** | 400 | 350 |
| pollution/min | **3** | 2 | 4 |

**Electricity is priced by the free bonus**, exactly as it was for `quality-recycler`. Per unit
of crafting speed the assembling machine 3 pays 300 kW, the vanilla recycler 360, the foundry
625, the cryogenic plant 750 and the electromagnetic plant 1000 — the plant's free +50%
productivity is what the extra buys. A free 12% quality is worth five normal quality module 3s
(0.025 each, `data/quality/prototypes/item.lua`), so this machine sits where the recycler sits:
**800 kW per unit of speed, so 1600 kW at speed 2.** Per item crafted that is 2.7x an assembling
machine 3's electricity (1600/2 against 375/1.25). Drain is the default thirtieth.

**`max_health` 400 and `emissions_per_minute` 3**, chosen 2026-09-13 when the prototype was
written: the health is the assembling machine 3's and the recycler's; the pollution sits between
the assembling machine 3's 2 and the electromagnetic plant's 4, which is where 1.6x an
assembler 3's work at 800 kW per unit of speed puts it.

### The recipe

Chosen 2026-09-13 with the prototype, in `quality-recycler`'s shape: a whole machine of the tier
below plus two quality module 3s (the "quality built in" as an ingredient), then materials that
say where the machine has been.

- **With Space Age:** `assembling-machine-3` x1, `quality-module-3` x2, `lithium-plate` x20,
  `superconductor` x10, `processing-unit` x20. Lithium plate is Aquilo's own material and the
  cryogenic plant's recipe carries the same 20; the superconductors are the cold cell's drive.
- **Without it:** `assembling-machine-3` x1, `quality-module-3` x2, `low-density-structure`
  x20, `electric-engine-unit` x10, `processing-unit` x20 — the base game's late materials, the
  engines being the compressor's drive.
- `energy_required` 10, the electromagnetic plant's, on both.

**The technology's cost** is `quantum-processor`'s exactly on the Space Age branch: 500 units of
all ten packs at 60 s, prerequisites `cryogenic-science-pack` and `quality-module-3`. Without
Space Age it is 500 units of the six base packs at 60 s after `space-science-pack`,
`utility-science-pack` and `quality-module-3` — the recycler's own gate.

Nothing here is a balance claim; see `deferred.md`.

### Crafting categories

**The assembling machine 3's three exactly** — `crafting`, `advanced-crafting`,
`crafting-with-fluid`. Not `electromagnetics`, `metallurgy`, `cryogenics` or `organic`: each of
those belongs to one expansion machine whose whole identity is that it is the only thing that
can run the category, and a machine that took all of them would delete four machines from the
game. This one is an *assembler*, at the top of the assembler line.

### Fluid boxes

Required, because `crafting-with-fluid` is in the list. The vanilla shape, from the
`assembling-machine-3` block: an input box connecting **north at `{0, -1}`** and an output box
connecting **south at `{0, 1}`**, `volume = 1000` each, with
**`fluid_boxes_off_when_no_fluid_recipe = true`** so both disappear on a dry recipe.

This is a constraint on the art as much as on the prototype: those two tiles are pipe attachment
points in every rotation, so the model may not stand anything over the north or south mid-edge.
`quality-recycler` had no fluid boxes and therefore no such rule.

### `allowed_effects`

The assembling machine 3's exactly — `consumption`, `speed`, `productivity`, `pollution`,
`quality`. **Productivity is allowed here and is not on the recycler**: recycling returns a
fraction of what went in, so a productivity bonus on it would be free matter. Assembling has no
such problem, and an assembler that refused productivity modules would be unusable in the part
of the game it unlocks in.

### Fast replacement

**`fast_replaceable_group = "assembling-machine"`** — the vanilla group, so an upgrade planner
swaps an assembling machine 3 for this one in place and keeps the recipe, the modules and the
inserters. That is half the reason the footprint is 3x3; the two decisions stand or fall
together.

The owner was offered a variant with a separate group (so an upgrade planner could not sweep a
whole base into it) and did not take it. Drop-in replacement is the point.

## The technology gate

**After Aquilo.** The owner's call on 2026-09-13, chosen over the recycler's three-planet rung
and over an early Nauvis one.

- **With Space Age**: prerequisite `cryogenic-science-pack`, which is the technology that marks
  Aquilo done. That puts this machine alongside `quantum-processor`, `fusion-reactor`,
  `railgun` and `foundation` — the endgame shelf. Verified 2026-09-13 by reading
  `data/space-age/prototypes/technology.lua`: `quantum-processor` takes exactly
  `prerequisites = {"cryogenic-science-pack"}` and costs **500 units of all ten science packs at
  60 s**, which is the cost class this technology should copy.
- **Without Space Age**: the deepest real rung the base game has, and the same one
  `quality-recycler` uses — after `space-science-pack` (a technology in base as well as in
  Space Age; the expansion only changes its trigger), with `utility-science-pack` and
  `quality-module-3` as prerequisites, since the recipe will use the module. Cost 500 units of
  every pack the gate implies at 60 s.

**The two branches are not at the same relative depth, and that is accepted.** The base game
simply has no post-Aquilo equivalent — past space science there is nothing but infinite
research — so the no-expansion build unlocks its top machine at the top of its own tree, which
is the honest translation.

## Art

**Designed 2026-09-13** through a full `factorio-entity-design` session, **and built the same
day** through `factorio-graphics`. The design, its reasoning and its measured reference numbers
are in `quality-assembler-design.md`, which is also the mod's house art style since there is no
separate art-direction register; its *Built* section records what the model actually is. The
headline decisions: it is **an assembling machine 3 that came back from Aquilo with half of it
replaced**, its hero is a **jacketed cold build vessel** with an indexing turntable behind a
window, and **quality reads as tolerance rather than selection** — an assembler builds one thing,
so the only honest reading is that it builds it more precisely, and real precision is held by
holding temperature. The accent is **pale turquoise (180–195°)** with one small violet point as
the family tell to `quality-recycler`.

**The four questions the concept sheet opened were settled by the owner's build brief of
2026-09-13**, which asked for the graphics to be implemented and spelt out each one:

- **The window stays, with the indexing turntable behind it.** The brief calls for "a
  south-facing viewing window, a heavy window bezel" with the turntable visible behind the glass,
  so the sheet's windowless column is superseded. The material-through evidence is interior,
  as the design session wanted.
- **Amber is not a second accent.** The brief lists copper/brass as the warm zone and allows
  "restrained warm highlights"; the machine carries one small amber running lamp on the
  cabinet. Copper and bronze do the warm-against-cold work.
- **The violet family tell survives**, as exactly one point at the head of the module rack —
  "one tiny violet family cue on the module bay", the brief's words.
- **Rime goes back on.** Frost, rime and ice accumulation are named in the brief for the cold
  half; the model carries it as a material term on the vessel's foot, the window sill and the
  coil, heaviest low and in crevices.

**Paint fraction as built: 21.1% blue over the opaque pixels of the base sheet** (the design's
target was AM3's 13.7%; the AM2, whose blue this is, measures 17.1%). Accepted: the hull is
squat and the deck rim is painted, and at 32 px the split needs the blue to hold.

**No idle loop.** The design wanted the condenser fan and the compressor flywheel turning slowly
while the machine idles. Measured in the engine on 2026-09-13 with a tick sequence: an
assembling machine that is not working is *frozen* — `idle_animation` is drawn at the frame the
working animation stopped on and never advances (which is why the API requires it to have the
same frame count). A second sheet with different fan angles would jump the instant the machine
stopped, so it was cut. The machine freezes when idle exactly as every vanilla assembler does; the
state read is the window going dim (the base carries only a tenth of the cell lamp) and the fan
stopping.

**`pipe_picture` is drawn centred on the tile OUTSIDE the connection**, the same origin
`pipe_covers` use, not on the entity. Measured 2026-09-13: with entity-relative shifts the north
stub drew a full tile past the pipe as a floating hook. `make_sheets.py` writes the stub sidecars
against that origin. The stubs are a bolted collar at the hull and a short barrel to the tile
edge, nothing more — the pipe entity's own ending sprite carries the flange at the joint, and a
flange on the stub doubled it.

**The circuit connector and `water_reflection` are the assembling machine's own**, required from
`assembler-pictures.lua`. Same 3x3, and the connector's corner is the condenser skid's top.

Three constraints from that session bind the prototype and belong here because code will need
them before the art exists:

- **No `heating_energy`, ever.** The machine *makes* cold and does not need it supplied; the
  whole design turns on that distinction, and the art carries no heat-pipe fitting. Adding the
  field later would make the machine stop on Aquilo without heat — a balance change, and it
  would also make the art a lie.
- **The bright turquoise belongs in `working_visualisations`, not in `graphics_set.animation`.**
  The animation layer is drawn in every state, so an emissive lit there lights the idle machine.
  `quality-recycler` shipped that fault once.
- **No item intake port of any kind on the model.** An assembling machine accepts inserters on
  all four sides, so a named intake promises a direction the entity does not have.

What was already fixed before the session, and still binds:

- **One direction, not eight.** Verified 2026-09-13 in
  `data/base/prototypes/entity/assembler-pictures.lua`: `assembler3_graphics_set` is a single
  `animation` with three layers — base (`repeat_count = 64`), anim (`frame_count = 64`) and
  shadow (`frame_count = 64`), all at `scale = 0.5` — and no per-direction sheets at all. The
  engine rotates only the fluid pipe graphics. `quality-recycler`'s eight directions are a
  recycler convention, not a crafting-machine one, and none of its `set_direction()`,
  rotation-cone or port-posing apparatus applies here.
- **3x3, so the sprite budget is the assembling machine 3's**, not the electromagnetic plant's.
- **The north and south mid-edge tiles are pipe attachment points** and must stay clear — see
  *Fluid boxes* above.
- `drawing_box_vertical_extension = 0.2` is the assembling machine 3's value and the starting
  point for a sprite taller than its box.

The rig lessons in `../quality-recycler/CLAUDE.md` — palette on rendered swatches, form/grain
split in the paint-over, the object-ID visibility pass, `cyl()` making a disc rather than a ring
— are general and should be carried over. Its *entity* decisions should not.

## The 2.0 track

`legacy/2.0` carries the same mod with **two forked files**, `info.json` and
`prototypes/assembler/entity.lua`; everything else, sheets included, is identical. Measured
2026-09-13 by validating against the 2.0 install (base 2.0.77, with and without Space Age),
`entity.lua` differs in three things, and every one of them loads clean when got wrong on the
other track:

- **`quality = 1.2`** where main has `0.12` — quality effect values are ten times larger on 2.0,
  which `quality-recycler` learned first.
- **The connector is `circuit_connector_definitions["assembling-machine"]`**, a data-stage
  global. `__base__/prototypes/entity/assembler-pictures.lua`, which main requires it from, is a
  2.1 file; on 2.0 the assembling machine's graphics live inline in `entities.lua` and the
  require is a hard error.
- **No `water_reflection`**: the assembling machine has none on 2.0.

`pipe_picture`, `secondary_draw_orders`, `draw_as_glow` and `fadeout` all exist on 2.0, so
`pictures.lua` is shared. The version stays `0.1.0` on both tracks until the first release, for
the reason the scaffold gave.

## Built, not played

Set up 2026-09-13 as a scaffold, then — later the same day, on the owner's build brief — the
entity was designed, modelled, animated, rendered, wired into `data.lua` and validated in both
configurations, and photographed in the engine. The prototype is written from scratch (not a
deepcopy of `assembling-machine-3`), for the reason `quality-recycler` gives: a deepcopy carries
a working sound, a status light and a connector positioned for a different machine. **Nothing has
been played beyond screenshots**; see `deferred.md`.
