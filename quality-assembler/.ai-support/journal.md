# Journal — Quality Assembler

Dated sessions, newest first. Append-only: an entry is history and is never edited once written,
except to repair a moved file path.

## 2026-09-13 (late) — verified in the running engine, both configurations

The owner asked that everything work and be properly balanced with and without Space Age.
Rather than reason from the prototype, the screenshot harness's probe gained a `report` group
that reads the running machine back — crafting speed, the effects in force, the module
inventory, `can_fast_replace`, and the force's view of named technologies and recipes — and
`shoot.ps1` gained `-Disable`, so the same spec ran with Space Age on and then off. Six
machines, four of them quality assemblers with nothing, five quality module 3s, five
productivity module 3s and five speed module 3s: every number came back as declared, fast
replacement is true over both vanilla assemblers, the two technology gates and both recipes
read as written, no `Unknown key`, no changelog error. One measurement worth having: five
speed module 3s cancel the built-in 12% to exactly zero. The data dumps of both branches were
read for the vanilla comparables (`decisions.md` → *Where the numbers sit* already carried the
Space Age ones; the no-expansion branch's automation-3 is 150 units and quality-module-3 300,
against this technology's 500 of six packs after the rocket). Balance itself is a play
judgement and stays in `deferred.md`. The probe's first recipe report crashed on
`LuaRecipe.category`, which is `categories` in 2.1 — fixed.

## 2026-09-13 (night) — the Aquilo pass: more complex, more beautiful, more futuristic

The owner asked for exactly that, with the animations kept. Rather than guess what futuristic
means in this game, the two Space Age machines that carry the word were measured: the cryogenic
plant and the fusion reactor are teal and blue-grey pressure vessels with a tenth of cream panel,
khaki ribbed hoses, riveted domes, and almost no cyan. The graft was repainted in the cryogenic
plant's sampled teal with cream flanges and dark composite frames, and grew a twin-fan
condenser, two ribbed hoses (a new `bellows()` primitive), a sight dome on the cap, a light line
over the window, a console on the skid with its cable loom, dome ribs and a cap plate. The old
half was left in its Nauvis blue on purpose.

Three look rounds. The first cream dome was a blank white disc that owned the sprite and went
teal; the black rubber hoses read as shadow and went khaki; the liquid hose's ribs landed inside
the east extreme's band and failed the silhouette audit until it moved in 0.06; the east cowl's
collar stood 0.05 past the tiles until the well moved to 1.19. The object-ID pass retired a
jacket flange hidden under the coil and widened the console's lamps. The second fan
counter-rotates a turn slower than the first, so the pair never strobes in step.

## 2026-09-13 (evening) — the player-facing package: text and gallery

The owner asked to "improve assembler content". Read as what a player sees of the mod: the
portal page, the in-game descriptions and a gallery. The README grew from three paragraphs to a
page with a comparison table against the assembling machine 3, both research paths with their
recipes, a "Using it" section (the upgrade-planner swap, module stacking, productivity, fluids)
and compatibility; the one-line descriptions now name the two numbers that matter (60% faster,
12%); and the entity got a `factoriopedia_description` — the `[factoriopedia-description]`
locale section Space Age uses for the fusion reactor — with two mechanical sentences and one
of flavour.

**The gallery is shot by the harness, not by hand.** Two probe options were added for it: a
belt takes `belt_items` so a composed line of machines between two belts reads as live (shot
24 ticks after the build, before the items run to the belt ends), and a group with
`factoriopedia = "<entity>"` opens the page for the run's player and shoots the screen with the
GUI — the benchmark save does have a player. Four images in `images/`: the Factoriopedia panel,
a five-machine line with an assembling machine 3 at its end by day and by night, and a close-up
at zoom 3. `package.ignore` already carried `images/**`. A shot of the machine in the owner's
own base would still be better than the composed line, and `deferred.md` says so.

## 2026-09-13 (later) — the animation pass: a machine that operates

The owner's second brief of the day asked for "a machine that operates": layered motion with
different rhythms, an idle that is not dead, a working state that visibly escalates, and the art
tightened with it — and, again, no routine questions.

**One measurement first, because the whole plan turned on it.** The morning had found that
`idle_animation` is frozen, and the brief wanted the compressor and the condenser running while
idle. A scratch copy of the mod put the anim sheet into three slots at once — the base animation,
a plain `always_draw` visualisation and an `always_draw` + `constant_speed` one — and was shot at
five ticks on an unpowered machine. The first two did not change a pixel; the third moved every
shot and closed its loop after exactly 128 ticks. That is the slot the refrigeration now lives in.

**The rebuild.** The moving parts were split three ways (craft / run / fast) with a timeline of
twenty-odd events that share no edge: the turntable now eases through its quarter turn, overshoots
two degrees and settles onto a lock pin that lifts before and drops after; the arm became a
carriage, a head and two fingers on a static rail, running out, down, closed, up and home; three
valves turn at three different moments; three gauges got needles with three different curves; the
condenser louvres open under load; the relief valve blows a vent puff at the end of each cycle;
the lamps breathe, flash and hold. The compressor got a belt drive to a motor pulley, the cabinet
a small cooling fan, the seam two bolted angle brackets, the vessel a cradle. "Slow when idle,
fast when working" was built as opaque working-only overlays over the slow always-on layer.

**What the renders and the engine caught.** The window read as one cyan shape until the
polished table rim, the frosted cell floor and the glow's bloom were all pulled back; the vent
puff rendered as a *ring* because Layer Weight's "Facing" is 0 head-on, not 1; the fast layer's
opaque mask swallowed the whole window through the pane's holdout ghost and would have drawn the
empty cell over the turntable; a service port on the lower shell measured 2 px because the
condenser stands in front of it, and was deleted; the needles measured 2–3 px and were widened
to a whole pixel. The engine run then showed the working fan changing *less* between shots than
the idle one — seven blades at 28° a frame strobe backwards — and it has five now. The same run
settled that the animation is not scaled by crafting speed (every layer closes at 128 ticks at
speed 2) and that working visualisations draw in list order.

**Not done, deliberately:** mechanical vibration (sub-pixel at gameplay zoom, and the paint-over
would turn it into flicker) and frost growth (the base is one frame by design). Recorded in
`deferred.md`. The `legacy/2.0` track still carries the morning's build; the port is a
cherry-pick once this is committed, and `pictures.lua` uses nothing 2.0 lacks.

## 2026-09-13 — built: modelled, animated, rendered, in the engine

The owner asked for the graphics to be implemented from the design document and the concept
sheet, with a long brief on the bar: iterate on renders until the machine "finally looks like a
machine that belongs in Factorio", and decide routine art questions without asking. The brief
also answered the four questions the sheet had opened — window and turntable back, amber only
as a running lamp, the violet point kept, rime on — and `decisions.md` → *Art* records that.

**Six look-dev rounds.** The first render drew 2.8 tiles on a 3-tile footprint and hid the
mechanism bay behind a tall cabinet; the hull was widened to fill its tiles and the old half made
squat, with the cabinet a corner tower, which is also the better story. The window was black for
two rounds: the "gasket" had been built as a full curved shell across the opening. The dome
rendered as a white blob until it became insulated lagging with a band, seams, a manway and lugs.
Rime was invisible on pale steel and reads only once the foot and the window sill went dark. The
turntable was reversed to dark-with-pale-pieces because a pale table under the cyan lamp blew out
to a flat rectangle. The object-ID pass caught the condenser fan buried inside a solid body (the
"well" was a solid disc over the blades) and confirmed the cell interior only after the glass was
hidden for the pass.

**Two engine runs, both decisive.** `idle_animation` does not play: a machine that is not working
is frozen, and the sheet is only drawn at the stopped frame — so the design's slow-idle fan was
cut rather than shipped as a jump. And `pipe_picture` is drawn centred on the tile outside the
connection: the first stubs floated a tile past the pipes, and the owner saw it ("improve the
pipe placement graphics, it looks weird"). The stubs became a collar and a short barrel, and
their sidecars are written against the outside tile.

Also written today: the prototype (`entity.lua`, `item.lua`, `pictures.lua`, `data.lua`), the
recipe and technology on both branches, health 400 and pollution 3, the icons and the thumbnail,
and the 0.1.0 changelog entries. Both configurations validate.

**Ported to `legacy/2.0` the same evening**, on the owner's commit request. A scratch copy
validated against the 2.0 install found `entity.lua` a hard error there — `assembler-pictures.lua`
is a 2.1 file — so the 2.0 fork takes its connector from the `circuit_connector_definitions`
global, drops the reflection the 2.0 assembler does not have, and carries `quality = 1.2` for the
2.0 scaling. Validated clean in both configurations before it was committed.

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
