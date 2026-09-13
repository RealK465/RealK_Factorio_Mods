# Journal — Quality Assembler

Dated sessions, newest first. Append-only: an entry is history and is never edited once written,
except to repair a moved file path.

## 2026-09-13 — the owner's concept sheet arrived

The owner dropped `prototype.png` into this folder after the design session below and asked for
it to be documented. 1254x1254, git-ignored by `*/.ai-support/*.png` like the recycler's sheet of
the same name, so it does not travel in a clone. It is now the governing visual reference, and
the design document says so in its opening and records the deltas in *The owner's concept sheet*.

**It confirms more than it changes.** The stat panel restates `decisions.md` unaltered, the fluid
inset restates the prototype down to `volume = 1000` and
`fluid_boxes_off_when_no_fluid_recipe = true`, the stubs are drawn low and centred on the north
and south faces exactly where the design asked them to be kept clear, and the legend states the
two paint fractions the design set — **13.7% on the west half, ~0% on the east**. The east-west
split, the worn blue, the cryogenic grey and the cold cyan accent are all there.

**Four real changes.** The hero is a **lit capped column with no window**, not a jacketed drum
with a frost window and an indexing turntable behind it. There is **no frost or rime anywhere** —
the cryogenic half reads clean rather than iced. Heat out is **re-sited and much more prominent**:
a large dark louvre bank centred on the north face and a large circular fan let into the top
deck, in place of an east-overhanging fin bank. And the machine is anchored on a **chamfered
plinth with hazard chevrons**, not the concrete pad and skid feet the session described — which
incidentally gives the two mods a shared quote, since the recycler takes its chevrons from the
vanilla recycler too.

Four smaller ones: **amber appears as a second emissive** in quantity, **violet appears nowhere**,
the blue half is **rustier than the assembling machine 3** (the paint fraction holds; the
substrate's character changed), and **human service is thin** — no ladder, railing or handwheel is
drawn, only hatches, panels and screens.

**Four questions went to `deferred.md` and *Not settled* rather than being decided here**, because
each changes what gets built and none is a modelling judgement: with the window gone the machine
has **no visible material flow at all** (defensible — the electromagnetic plant shows none either
— but it should be chosen, not fallen into); whether amber is a deliberate warm counterweight and
therefore replaces copper in material zone 4, or is incidental; whether the violet family tell to
`quality-recycler` is dropped or merely not drawn at sheet scale; and whether rime goes back on at
modelling time.

One risk logged for the build rather than raised as a question: **the hazard plinth wraps the
footprint**, which is the "square deck plate" `design-language.md` names as the usual cause of a
filled outline, and the hero render's mass reads more cubic than the two offset masses the
session described. `gates.silhouette` measures it — fill 0.58-0.88, ragged 1.14-2.19, zero
full-width rows — and it should be run early rather than after a bake. Putting the ladder and
railing back buys raggedness through holes, which is a second reason to do it.

## 2026-09-13 — the entity designed

A full `factorio-entity-design` session, immediately after the scaffold below. Output is
`quality-assembler-design.md`.

**The session's one real finding: the sibling mod's answer does not transfer.**
`quality-recycler`'s hero is an eddy-current separator, and it is honest there because recycling
picks a better fraction out of a mixed input. An assembler builds one thing, so quality cannot
read as selection without lying about the mechanic. It had to read as **tolerance** — and real
precision manufacturing gets tolerance by holding temperature, because thermal expansion eats a
spec before anything else does. That is what put a refrigerated build chamber at the centre of a
machine that unlocks after Aquilo, and the lore anchor and the hero turned out to be the same
idea rather than two decisions.

The owner's eight answers, in order: hero **cryo-stabilised build chamber** (over a closed-loop
metrology gantry, a vibration-isolated precision head and a laminar-flow clean cell); family
**salvaged AM3 with Aquilo-grade gear grafted on**, mirroring the recycler's premise one planet
further on; silhouette **split east-west with the seam down the single front elevation**, cold
vessel east, blue hull west, a low saddle between them carrying the pipe line; item flow
**interior only, no exterior port**; behind the window **an indexing turntable**; accent
**turquoise with one violet tell**; wear **rime cold, spall at the seam, rust warm**; density
**keep a shrunken AM3 top deck, calm walls below**; state **the compressor never stops, the craft
does**.

Three of those are worth the reasoning being findable later. The **cryo hero carried a real
risk** — a cold machine on Aquilo reads as one that *needs* heat, a mechanic this entity does not
have — and the fix was to make the refrigeration cycle visible: a compressor doing work, a
condenser rejecting heat outward, and no heat-pipe fitting anywhere. **The accent broke family
with the recycler**, deliberately: violet was earned there as steel tempering colour and cold
does not produce violet, so turquoise won the machine and violet was reduced to one small point
on the module bay. And the **compressor running while idle** is not decoration — a refrigerator
holds temperature whether or not you are using it, and the slow-to-fast change is the state read
that survives gameplay zoom where a turntable behind a 30 px window does not.

Measured for the design, all at base 2.1.17 on the pinned install, via the skill's
`counterpart.py`: the assembling machine 3 carries **13.7% identity paint** over a 63.7% rust
substrate with **no emissive but a 36x44 status light**, and its base sprite is 196x192 authored
px — **3.06 x 3.00 tiles at scale 0.5**, so it barely leaves its own footprint and this design
inherits no overhang licence. The electromagnetic plant is the opposite model: 0.4% paint on a
dark base with five large emissive sheets measuring **195 degrees cyan dominant**, which is where
the turquoise band came from. Krastorio 2's `kr-advanced-assembling-machine` was read as prior
art for a tier-above-vanilla assembler: 5x5 at collision 2.25, crafting speed 5, 0.925 MW, pipes
at {0,-2} and {0,2}.

Left open by the design and named in its own *Not settled*: whether to reuse AM3's
`assembler3pipepictures` or author a matched set, the vessel's exact proportions, whether the
window is a true recess or a flush pane behind a bezel, `animation_speed` and the frame count,
and the four vanilla freebies a scratch-built entity does not get.

## 2026-09-13 — scaffolded

The owner asked for a new mod "quality-assembler", "similar to the quality-recycler but this
time is an assembler". Delivered as a scaffold — folders, `info.json`, `changelog.txt`,
`LICENSE`, locale, `README.md`, `CLAUDE.md` and this folder — with no Lua and no art, per the
standing instruction to settle the design in the docs before writing code.

**Read `quality-recycler` first, and that turned out to be the useful part of the session.**
Three of its structural decisions do not carry over, and each would have been copied by
reflex:

- **Assembling machines are not directional.** `assembler3_graphics_set` is one 64-frame
  animation — base, anim, shadow, `scale = 0.5` — and the engine rotates only the fluid pipes.
  The recycler's eight sheets, its `set_direction()` transform, its rotation cone and its
  per-direction port posing are all recycler-specific. This entity has one elevation, and the
  art budget is a fraction of the recycler's.
- **It needs fluid boxes**, which the recycler did not. `crafting-with-fluid` means an input at
  `{0, -1}` and an output at `{0, 1}` with `fluid_boxes_off_when_no_fluid_recipe = true`, and
  that puts a hard constraint on the model: the north and south mid-edge tiles have to stay
  clear.
- **It allows productivity**, which the recycler deliberately forbids. Recycling returns a
  fraction of what went in; assembling does not, so there is nothing to exploit.

A fourth: the recycler's whole `data-final-fixes.lua` exists because a *furnace* picks its own
recipe and silently refuses ingredients when it runs short of result slots. An assembling
machine is given its recipe by the player. Do not port that file.

**Four decisions went to the owner**, each with three or four options. Answers: **3x3, an
assembling machine 3 successor** with vanilla fast replacement, over the electromagnetic plant's
4x4 — the machine should drop into an existing row. **12% quality, crafting speed 2, five module
slots**, matching the recycler's bonus and taking the plant's speed and slots; 1600 kW follows
from pricing electricity by the free bonus at 800 kW per unit of speed, the same method the
recycler used. **Unlocked after Aquilo** — `cryogenic-science-pack` — which was the deepest of
the three gates offered, and deeper than the recycler's three-planet rung. The base-game branch
has no post-Aquilo equivalent, so it keeps the recycler's own no-expansion gate (after the
rocket) and the two branches sit at different relative depths on purpose.

`space-age` stayed optional and `recycler` was dropped from the dependency list — this mod
touches nothing in that package.

Portal name checked the same day: `quality-assembler` returns 404, as do
`quality-assembling-machine`, `quality-crafter` and `quality-assembler-realk`.

Verified against the default dev install at base 2.1.17: `AssemblingMachinePrototype` extends
`CraftingMachinePrototype`, so `effect_receiver.base_effect.quality` is the same field the
recycler's furnace uses and there is no assembler-specific spelling; the assembling machine 3's
own numbers (3x3 at collision 1.2, speed 1.25, 375 kW, four slots, 400 health, 2 pollution, its
three crafting categories, its fluid box positions and `fast_replaceable_group`); the
electromagnetic plant's (4x4, speed 2, 2000 kW, five slots, free +50% productivity); and
`quantum-processor` as the post-Aquilo cost reference at 500 units of all ten packs at 60 s.

Left open, and written into `deferred.md`: the recipe on both branches, `max_health`,
`emissions_per_minute`, the exact technology cost, the entire art job including the design
document, sounds, `water_reflection`, the circuit connector, a remnant, and the `legacy/2.0`
build. Nothing has been validated, because there is nothing to load.
