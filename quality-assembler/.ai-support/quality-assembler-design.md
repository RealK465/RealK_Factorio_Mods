# Quality Assembler entity — design notes

The mod's only entity: an assembling machine that holds its work to a finer tolerance, so a
share of what it builds comes out at a higher quality. Designed 2026-09-13 in a full
`factorio-entity-design` session, before any Lua or art existed.

**No art-direction register governs it — this document is the mod's house style**, the way
`quality-recycler-design.md` is for its sibling. The prototype facts it has to satisfy are
settled in `decisions.md` and are restated below as constraints, not re-opened. Anything this
document leaves open is in `deferred.md` and in *Not settled* at the end.

**`prototype.png` beside this file is the repo owner's own concept sheet, and on anything it
shows it outranks the prose here.** It arrived after the design session and confirms most of it;
where the two differ, the sheet is the decision and the difference is recorded in *The owner's
concept sheet* near the end of this document — read that section together with the sections it
supersedes, which carry inline markers.

**Built 2026-09-13, the same day, on the owner's build brief.** The brief settled the four
questions the sheet had opened (the window and turntable stay; amber is one running lamp, not an
accent; the violet point stays; rime goes back on) and *Built*, near the end, records what the
model actually is, where it departs from the sections above, and what the engine measured. Where
*Built* and an earlier section disagree, *Built* is what shipped.

## Function & constraints

Builds the same recipes an assembling machine 3 does, 60% faster, and everything it makes has a
12% chance of coming out one quality tier higher with no modules fitted.

| | |
|---|---|
| Footprint | **3x3**. `collision_box = {{-1.2,-1.2},{1.2,1.2}}`, `selection_box = {{-1.5,-1.5},{1.5,1.5}}` — the assembling machine 3's exactly |
| Fluid connections | **input north at `{0,-1}`, output south at `{0,1}`**, volume 1000 each, `fluid_boxes_off_when_no_fluid_recipe = true`. Drawn by `pipe_picture`, so the stubs **come and go with the recipe** |
| Rotatable | **prototype yes, art no.** The engine rotates only the fluid pipes; the body is one non-directional animation. See *The single elevation* below |
| Module slots | **5** |
| Energy | electric, **1600 kW**, drain the default thirtieth |
| Tier or act | **post-Aquilo** (`cryogenic-science-pack`) with Space Age; after the rocket without it |

**The single elevation is the largest structural fact in this document.** Verified 2026-09-13
against `data/base/prototypes/entity/assembler-pictures.lua` at base 2.1.17:
`assembler3_graphics_set` is one `animation` with three layers — base (`repeat_count = 64`),
anim (`frame_count = 64`) and shadow (`frame_count = 64`), all at `scale = 0.5` — and there are
no per-direction sheets at all. So this entity has **one front elevation to get right**, not
four, and none of `quality-recycler`'s rotation apparatus applies: no `set_direction()`, no
rotation cone, no per-direction port posing. That is a gift and should be spent on the south
face rather than banked.

**The north and south mid-edges must stay low and flat.** The pipe stubs appear and disappear
with the recipe, so a mass sitting on that centre line leaves a stub buried in geometry on every
fluid recipe and a bare notch on every dry one. This constraint shapes the silhouette below more
than any aesthetic choice does.

### Measured reference numbers

All read off the pinned dev install on 2026-09-13, via
`.claude/skills/factorio-entity-design/scripts/counterpart.py`:

| | assembling machine 3 | electromagnetic plant |
|---|---|---|
| identity paint, % of opaque px | **13.7%** | 0.4% base, 20.6–23.0% on the animated sheets |
| rust substrate | 63.7% | ~45% |
| saturation / value | 0.47 / 0.34 | 0.25 / 0.15 |
| base sprite | 196x192 authored px | 238x252 |
| emissive layers | **none but a 36x44 status light** | five large sheets, 195° cyan dominant |

Two readings that bind this design:

- **The assembling machine 3 is a base-game machine**: its identity lives in *paint*, and it has
  effectively no emissive. The electromagnetic plant is the Space Age model — a dark hull whose
  identity lives in a huge animated glow. This entity is deliberately **the first**, with a
  small cold emissive borrowed from the second. The paint target is AM3's own **13.7%**, spent
  entirely on the west half.
- **The assembling machine 3 barely overhangs its footprint.** 196x192 authored px at
  `scale = 0.5` is **3.06 x 3.00 tiles** against a 3x3. So there is no inherited overhang to
  lean on: every tile this design breaks past the edge is a deliberate escalation, and the
  vanilla 3x3 ceiling to respect is the chemical plant's **0.77 tiles north** (the vanilla
  recycler 0.58, the biochamber ~0.1 — measured for `quality-recycler-design.md`).

Prior art checked: **Krastorio 2's `kr-advanced-assembling-machine`** (5x5 at collision 2.25,
crafting speed 5, 0.925 MW, pipes at `{0,-2}` / `{0,2}`). Useful as the shape of a
tier-above-vanilla assembler, and useful as the documented failure mode to avoid — K2's plants
fill the tile edge to edge on a flat tray base, which is the silhouette rule below.

## Lore anchor

**It is not a new machine.** It is an assembling machine 3 that came back from Aquilo with half
of it replaced. The west half is the same worn blue machine the player has been running since
production science; the east half is cryogenic hardware grafted on, and the seam between them is
visible, bolted and deliberate. Same premise as `quality-recycler`, one planet further on.

**Quality here is tolerance, not selection.** The recycler's hero is a separator because
recycling picks a better fraction out of a mixed input; an assembler builds one thing, so the
only honest reading is that it builds it *more precisely*. Real precision manufacturing gets
tolerance from holding temperature — metrology labs run to ±0.1 °C because thermal expansion
eats a tolerance before anything else does. This machine refrigerates the volume it builds in.

Three readings ruled out:

- **The cold is not a requirement, it is the product.** The machine *makes* cold; it does not
  need it supplied. That distinction is carried by a visible refrigeration cycle — a compressor
  doing work and a condenser rejecting heat outward — and by the deliberate absence of any
  heat-pipe fitting. An Aquilo machine that needs heat shows the interface that takes it in;
  this one shows the pump instead. The entity carries **no `heating_energy`** and the art must
  never imply it does.
- **The frost is not damage.** It is condensate freezing on a cold surface, which is what a cold
  surface does. See the wear map.
- **The turquoise is not a brand colour.** It is the interior lighting of a cold cell, in the
  hue band FFF-432 assigns to cryogenic cold and that the electromagnetic plant's own emissives
  measure at (195° cyan dominant).

## Hero & family

**[the concept sheet drew a lit capped column with no window; the owner's build brief of the
same day put the window and the turntable back, and that is what was built — see *Built*]**

**Hero: the jacketed cold build vessel.** A drum standing on end on the east third, wrapped in
its coil bundle, with a frost-rimed window on its south face. Modelled first and oversized; it
takes the detail budget. Behind the window an **indexing turntable** steps once per craft with
the work clamped to it — an indexer is the real machine that repeats a position exactly, its
motion is mechanical rather than magical (FFF-350), and rotation stays legible at small size
even when the object on it is not.

**Family: the assembling machine 3, salvaged, with Aquilo-grade cryogenic gear grafted on.** It
quotes AM3's worn blue housing, its paint fraction, its proportions and a shrunken version of
its exposed top deck. The grafted half quotes the cryogenic plant: bare insulated steel, coil
bundles, sealed vessels — hardware that looks recovered rather than manufactured.

Its mechanical precedent is the **electromagnetic plant**, whose `effect_receiver =
{ base_effect = { productivity = 0.5 }}` is the exact shape of this entity's `quality = 0.12`.
It is not the size or palette reference: it is 4x4 and it is a Space Age dark-hull machine.

## Silhouette

**Two masses split east–west, with the salvage seam running straight down the single front
elevation.**

```
PLAN 3x3, N up                 SIDE, from S
+------+------+------+
| comp | pipe | cryo |                     __
| skid | line | RISER|                    /||\   riser + expansion vessel
+------+------+------+              _____/ || \____
| AM3  |saddle| COLD |             | AM3  | ||  |####|
| hull | low  |VESSEL|             | deck |_||__|#jkt#|
+------+------+------+             |------'      |####|
|module| pipe | cond |             | mod  |saddle|[==]|  <- frost window
| bay  | line | fins |             | bay  | low  |cond|
+------+------+------+             '------------------'
                                    ^ substantial south wall
   seam: vertical, dead centre       ^ concrete pad, skid feet
   blue west | bare cryo east
```

- **Tall break:** the cryo riser and its expansion vessel, east and off-centre, carrying the
  skyline. Target crown height **~1.6 tiles**, total drawn height ~2.4 tiles including shadow
  reach.
- **Low breaks, two of them:** the compressor skid breaching the **west** edge, and the
  condenser fin bank overhanging **east**. Both at ground level, both on the opposite axis from
  the pipe line.
- **North overhang target ≤ 0.7 tiles**, inside the chemical plant's 0.77 — measured on opaque
  pixels, never on the declared sprite box. (`quality-recycler` learned that one: the vanilla
  recycler's east sheet declares 0.86 tiles of overhang and fills 0.69, the rest being the
  packer's padding.)
- **The saddle between the two masses is structural, not decorative.** It keeps the N–S centre
  line low for the pipe stubs, and it is what makes the west and east extremes land in
  **disjoint y ranges** — which is the geometry that guarantees no horizontal scanline crosses
  the sprite edge to edge. Screen row is `y + z`, so a full-width row only happens when both
  extremes fall in it; separating them by more than the deck thickness removes the entire
  failure class.
- **Front elevation:** substantial, and there is only one of them. The south wall shows the
  module bay and calm blue panelling on the west, the seam bolting at centre, and the frost
  window with the condenser below it on the east. No near-plan-view roof-only reading, which is
  the tell that most reliably outs mod art.
- **Solid, not open-frame.** Open-frame construction is vanilla's language for utility entities
  that tile in rows; an assembler should read solid and productive.
- **Anchored** by a concrete pad under the compressor skid, skid feet along the south, and a
  dirt/AO skirt where the hull meets ground. **[superseded: the concept sheet anchors it on a
  chamfered plinth with yellow-and-black hazard chevrons, which also raises the silhouette risk
  noted in *The owner's concept sheet*]**
- Targets: **fill 0.58–0.88**, **ragged 1.14–2.19**, **zero full-width rows**. `gates.silhouette`
  measures all three; raggedness is bought with *holes* (railing, ladder, the gap under the
  condenser fins) and lost by adding solid parts.

## Component list — the four flows

**16 distinct kinds**, against the audited 8–15 band. Parts marked `catalogue:` are built by
`factorio_render.parts` and cost a line each; everything else is modelled.

| Flow | Parts |
|---|---|
| **Hero** | 1. Jacketed cold vessel — the drum, east third, on end. 2. Jacket coil bundle wrapped around it (`catalogue: run pipe_run`). 3. Frost window on its south face, the machine's lit face. 4. Cryo riser + expansion vessel above — the tall break |
| **Power in** | 5. Transformer / junction box on the blue hull, sized for 1600 kW (`catalogue: place junction_box`). 6. Cable drape with natural sag, hull to compressor (`catalogue: run cable`) |
| **Material through** | 7. Fluid stubs north and south, ending in bolted flanges with a dark open bore (`catalogue: place flange`) — but see *Not settled* on `pipe_picture`. 8. The indexing turntable and its transfer arm, visible through the window — the only material evidence, and it is interior |
| **Heat out** *[re-sited by the concept sheet: a large dark louvre bank centred on the NORTH face, and a large circular fan let into the top deck; no separate west compressor mass]* | 9. Compressor skid breaching west — the low break, and the proof the machine makes its own cold. 10. Condenser fin bank overhanging east, warm side, sooted (`catalogue: place radiator`). 11. Louvre bank on the blue hull (`catalogue: place louvre_bank`) |
| **Human service** | 12. Ladder to the cryo deck (`catalogue: run ladder`). 13. Railing round the deck (`catalogue: run railing`). 14. Handwheel isolation valve on the cryo manifold (`catalogue: place handwheel`). 15. Gauge pod cluster on the cryo line (`catalogue: place gauge_pod`). 16. Stencilled placard on the blue hull (`catalogue: place placard`) |

Not counted as distinct kinds, but modelled: the **five-slot module bay** on the blue hull's
south face (a real prototype field earns a real fitting), **skid feet** (`catalogue: run
skid_feet`) and **rivet rows** bolting the salvage seam (`catalogue: run rivet_row`).

**Cut deliberately:**

- **No item intake port, hopper or chute of any kind.** An assembling machine accepts inserters
  on all four sides, so any named intake promises a direction the machine does not have — the
  FFF-339 rule that got the cables between beacons deleted. The vanilla assembling machine 3
  has none for exactly this reason, and all the material-through evidence therefore lives
  inside the window.
- **No heat-pipe fitting, heat interface or heating radiator.** The entity has no
  `heating_energy` and must not look like it wants one. See *Lore anchor*.
- **No metrology or inspection gear.** It was the runner-up hero and it would now be a second
  explanation of the same mechanic, standing next to the real one.

## Material zones

Six — the top of the audited 4–6 range, which is right for a machine that is visibly two
machines. **Tune every one of these on rendered swatches, never on hex codes**: `swatch.py` and
`measure_swatch.py` in the sibling mod's asset folder are the pattern, and they are what caught
that mod shipping a "bronze" that rendered green-dominant grey.

1. **Worn AM3 blue** — *sampled from `assembling-machine-3-base.png`, not invented.* Housing
   panels on the **west half only**, never on mechanism. Target **13.7% of opaque pixels**, AM3's
   own measured paint fraction, so the machine reads as a base-game machine rather than a Space
   Age one.
2. **Bare / galvanized steel** — the cryo jacket shell, riser, expansion vessel, ducts, frame.
   **The grafted half is unpainted**: salvage does not get repainted, and the contrast with zone
   1 is what makes the seam legible without an outline.
3. **Dark iron / gunmetal** — vessel interior, window bezel, cavities, the turntable, exposed
   mechanism on both decks.
4. **Warm metal — copper / brass** — the coil bundle, cryo fittings, condenser fins. **This zone
   is load-bearing, not trim.** Warm-against-cool pairing is a vanilla habit (brass frame / blue
   glow on the lab, copper / steel on the beacon) and an entirely cold machine renders dead. It
   is also physically right: the condenser is the hot side.
5. **Rubber / hose black** — power cable, compressor flex lines, gaskets round the window.
6. **Frost / rime white** — the cold-side accretion, and the zone that replaces "clean" on the
   east half. Not a material so much as a surface state; see the wear map.
   **[not on the concept sheet, which carries clean pale panelling instead — open in *Not
   settled*]**

**Emissives.** One semantic accent, plus one family tell:

- **Pale turquoise, hue band 180–195°** — the window's interior light and the cryo line's status
  lamps. The band is vanilla's own for cold: FFF-432 assigns pale turquoise to cryogenic, and
  the electromagnetic plant's emissive layers measure **195° cyan dominant**. Keep colour x
  strength near 1.0 — the sibling mod shipped a beacon clipped to pure white by missing that.
- **One violet point, ~280°, on the module bay backlight.** Exactly one, small and local: the
  tell that this is the same mod as `quality-recycler`, whose whole accent is violet. It pays
  the family debt without putting two competing saturated accents on a 64 px sprite.

## Wear map

Three regimes, and the **boundaries between them carry the story**.

- **Cold half (east) — rime, and cleaner than the warm half.** **[the concept sheet keeps the
  "cleaner" half of this and drops the rime — open in *Not settled*]** Frost accretion heaviest at the
  jacket seams, under the coil bundle and at low points where cold pools; scraped clear in bright
  arcs where moving parts sweep and where hands actually touch — the ladder rungs, the handwheel
  rim, the railing top. No rust here: **dirt does not stick to ice**, so the cold half is
  genuinely the cleaner of the two, which is the opposite of what a reader expects and is the
  detail that sells the temperature.
- **Warm half (west) — ordinary physics.** Soot above the condenser and the louvre bank. Oil
  streaks *below* the compressor, never above it. Grime pooling in crevices and panel joins,
  darkening toward the ground. Paint chipped to bare metal on every edge, corner and protruding
  part, and those chips are *cleaner* than the panels around them, because dirt wears off exactly
  where paint does.
- **The seam — the worst corrosion on the machine.** Condensate runs off the cold half onto the
  old painted one and sits there, so the bolted seam line carries heavy rust streaking
  downward from it onto the blue, with paint spalled back in plates either side. This is
  physically true and it does the lore's work: it is what makes the graft look like it happened
  years ago rather than last week.

No surface at 100% clean paint; no uniform wear anywhere.

## Busy / calm

- **Dense hero zone: the cold vessel's south face and the deck above it** — the window and its
  bezel, the coil bundle, the gauge pods, the handwheel, the railing. The east third, and it
  wins the eye because it is taller, lit, and the only thing moving fast.
- **Second dense zone, deliberately subordinate: a shrunken version of AM3's exposed top deck**
  on the west. This is kept because it is the single detail that makes a player say "that is my
  assembler" — vanilla's own assembler tops are jagged with mechanism, not flat lids — but it
  sits lower, is unlit, and moves slowly.
- **Calm: the blue hull's walls below the deck.** Seams, rivets, the placard, the louvre bank and
  wear, nothing else. The two dense zones are separated vertically by this calm band, which is
  what stops them competing.
- **Kept low so the hero is never occluded:** the saddle at centre, the module bay, the
  compressor skid and the whole south-west quarter. Nothing between the viewer and the window.

## State & animation

The premise that drives this section: **a refrigerator holds temperature whether or not you are
using it.** So idle is not "stopped" — it is "cold, and waiting".

| Element | Per loop | Why it loops |
|---|---|---|
| Indexing turntable | one step per craft, behind the window | the tolerance is held by repeating a position exactly; the step is the craft |
| Transfer arm | one in-and-out cycle per craft | puts the work on the fixture and takes it off |
| Condenser fan | continuous, **fast when working, slow when idle** | rejects the heat the compressor makes |
| Compressor | continuous, **fast when working, slow when idle** | never stops — the chamber has to stay cold |
| Frost on the jacket | slow breathe, thickening on the working cycle | condensate freezing as the jacket pulls heat |
| Window interior light | steady turquoise when working, **dim when idle** | the cold cell is lit from inside |
| Cryo line status lamps | slow pulse | small, local status, per FFF-339's cut of the beacon's screen-filling beam |
| Module bay violet point | steady, unchanging | a family tell, not a state read |

**Working against idle, side by side:** working is a fast fan, a fast compressor, a turntable
stepping, an arm cycling and a lit window. Idle is a slow fan, a slow compressor, a still
turntable, a still arm and a dim window. **The slow-to-fast compressor and fan change is the
state read that survives gameplay zoom** — a turntable behind a 30 px window does not.

Two engine facts this section has to respect:

- **An emissive lit in the always-drawn layer lights the IDLE machine.** An assembling machine's
  `graphics_set.animation` is drawn in every state and `working_visualisations` only while
  working. So the bright turquoise goes in `working_visualisations`; the base animation carries
  the dim idle glow alone. `quality-recycler` shipped this wrong once and had to dim its violet
  materials to 0.22 for the base pass.
- **A crafting machine's animation speed is scaled by its crafting speed** unless
  `constant_speed` is set. At `crafting_speed = 2` the authored speed is doubled in game, so
  author the loop against that and check it beside a vanilla assembler rather than in a render.

**Direction:** not applicable. The body is one non-directional animation and the engine rotates
only the pipe stubs.

## The owner's concept sheet (2026-09-13)

`prototype.png`, 1254x1254, beside this file. Git-ignored by `*/.ai-support/*.png`, so it is
**not in a clone** — exactly like `quality-recycler`'s sheet of the same name. It arrived after
the design session above and is the governing visual reference from here.

**What it contains.** A titled sheet in the game's own presentation style — "QUALITY ASSEMBLER
/ Higher quality. Faster production." — carrying a large three-quarter hero render, a stat
panel, an inset on the fluid connections, four orthographic views labelled *Front (south)*,
*Back (north)*, *Side (west)* and *Top view*, a row of five material and detail close-ups, and a
legend keying the two halves to their paint fractions with the 3x3 collision box drawn.

**The four views are a modelling reference, not four sprite directions.** The art stays one
elevation; the orthographics exist so the model can be built, the way any elevation sheet does.

### What it confirms

Everything in the stat panel restates `decisions.md` unchanged — **3x3, 1600 kW, 60% faster, 12%
chance for higher quality, 5 module slots, post-Aquilo (cryogenic science pack)** — and the
fluid inset restates the prototype exactly: input north, output south, **volume 1000 each**,
`fluid_boxes_off_when_no_fluid_recipe = true`, appearing and disappearing with the recipe. The
stubs are drawn low and centred on both the front and back views, below everything else on that
face, which is the keep-out this document asked for.

It also confirms the session's core shape: the **east–west split**, worn blue on the west and
cryogenic hardware on the east, with a visible seam; the legend states **13.7% identity paint**
on the west half and **~0%** on the east, which is the paint budget this document set; and the
accent is the cold cyan it settled on.

### What it changes

Eight things, and the first four are real design changes rather than detail.

1. **The hero is a lit vertical cryo column, not a jacketed drum with a frost window.** The sheet
   shows a capped cylinder with vertical glowing slots, lit cyan from within, standing on the
   east half and reading as the machine's one bright object. **There is no window and no
   turntable.** This supersedes *Hero & family* and the window rows of *State & animation*, and
   it has a consequence named in *Not settled*: with the window gone, the machine has no visible
   material flow at all.
2. **No frost and no rime anywhere.** The cryogenic half is clean pale grey-white panelling. This
   supersedes material zone 6 and most of the cold half of *Wear map*. The session's underlying
   claim survives — the cold half is much the cleaner of the two — but it is carried by clean
   panels rather than by ice.
3. **Heat out is re-sited and much more prominent.** A **large dark vertical louvre bank centred
   on the north face**, and a **large circular fan recessed into the top deck**, roughly centre
   and slightly north, which is the roofline's centrepiece. This supersedes the east-overhanging
   condenser fin bank in *Component list*; the compressor's west skid is not visible as a
   separate mass either.
4. **A hazard-striped base apron** wraps the foot — yellow-and-black chevrons on a chamfered
   plinth, visible on every view. This supersedes the concrete pad, skid feet and dirt skirt in
   *Silhouette*, and it is a family tie worth noticing: hazard chevrons are one of the things
   `quality-recycler` quotes off the vanilla recycler, so both mods now carry them.
5. **Amber is a second emissive**, in quantity — small warm rectangular lit panels on both
   halves, alongside the cyan. The session specified one accent. See *Not settled*.
6. **No violet appears anywhere**, so the one-point family tell to `quality-recycler` is not on
   the sheet. See *Not settled*.
7. **The blue half is rustier than the assembling machine 3.** Heavy oxide streaking over and
   through the paint, concentrated on top edges and panel seams. The paint *fraction* is
   unchanged at the legend's 13.7%; what changed is the substrate's character, which is now
   closer to the sheet's own "Rust substrate" swatch than to AM3's.
8. **Human service is thin.** No ladder, railing or handwheel is visible; service reads as
   hatches, small instrument panels and screens. Of the five human-service parts in *Component
   list*, the sheet draws none directly. This is the flow `design-language.md` says is missing
   most often, so it is worth adding back at modelling time rather than treating the sheet as
   having cut it — a screen is not a thing a person operates.

Also on the sheet and worth building: the riser is a **bronze pipe elbowing over the back with a
cyan-lit section at the bend**, several small green-cyan instrument screens on the east face, and
a small dark radial fan let into the blue half's west face.

### What the build has to measure rather than assume

**The apron is the silhouette risk.** A plinth wrapping the whole footprint is precisely the
"square deck plate" `design-language.md` names as the usual cause of a filled outline, and the
overall mass in the hero render reads more cubic than the two offset masses this document
described. The riser and the two pipe stubs are the outline breaks, and they may not be enough
on their own. Measure with `gates.silhouette` early — targets **fill 0.58–0.88**, **ragged
1.14–2.19**, and **zero full-width rows** — rather than discovering it after a bake. Raggedness
is bought with holes, which is a second reason to put the ladder and railing back.

## Built (2026-09-13)

The model is `../../assets/quality-assembler/entity/quality-assembler/` — `qa_gen.py` (palette,
the validated material stack with a rime term, the bmesh primitives, animation, audit) and
`qa_layout.py` (the machine); `render_entity.py`, `make_sheets.py`, `make_look.py`, `show.py`,
`check_visibility.py`, `render_icon.py` and `make_icons.py` do the rest. Six look-dev rounds and
three engine runs on the day it was designed.

### What was built, west to east

- **The plinth**: a chamfered slab at ±1.40 tiles, deliberately inside both silhouette extremes.
- **The old machine**, x −1.36..−0.12: a chamfered blue skirt on the plinth with three bolted
  panel plates on its south face (the one beside the seam in a rustier paint), the deck rim
  painted, and the top **cut open as a mechanism bay** 0.94 x 0.88 tiles: a bright 20-tooth gear,
  a 9-tooth pinion, a crank driving a connecting rod and a slider along Y, the gearbox's shaft,
  and the assembler's own handwheel on the west rim. A **narrow blue cabinet tower** in the
  south-west corner carries the **module rack** (five stacked slots in a dark recess), the violet
  point at its head and the one amber running lamp; a **low gearbox housing** south of the bay
  carries a louvre grille and the placard. The **compressor** is bolted to the north-west corner
  of the deck: a finned cylinder block with a valve cover, its five-spoke flywheel facing the
  camera, a motor behind it, a gauge, and its mount plate hanging past the hull on a bracket
  with a guard rail — the sprite's west extreme.
- **The seam**, dead centre: a bare-steel strap up the south wall, a bolted joining plate across
  the deck with weld beads either side, and a dark step down from the old deck (z 0.66) to the
  graft's skid (z 0.30). The discharge line runs down the saddle in front of it on three clamps.
- **The graft**, x −0.08..1.42 on a galvanised skid: the **cold build vessel** at (0.68, −0.26),
  r 0.50, foot to boss z 0.30..1.84 — a rimed foot flange with a bolt ring, a lower shell, the
  **window band** (opening −146°..−34°, z 0.72..1.24) with a heavy gunmetal bezel of two arcs and
  two riveted posts, rubber gasket beads and a pane, **sight glasses** on the shoulders either
  side, the upper shell wound with a **three-turn copper coil** on four straps, a bolted cap, an
  insulated dome with a band, four seams, a manway and two lugs, a boss and a relief valve, a
  gauge, a ladder up the south-east flank and the cyan status lamp at the south-west foot. Inside
  the cell: a cold-light ring in the floor, a ceiling lamp hidden under the top lip, the
  **turntable** (a dark disc with a scoured rim, four clamps, four pale workpieces) and the
  transfer arm.
- **The condenser skid**, x 0.46..1.50 at the south-east, z 0.30..0.66: a frame body round a
  real well with a seven-blade pitched fan and a three-bar guard in its top, three louvres and
  eight hazard chevrons on its face, an access panel with a handle — sooted from the top, and
  the sprite's east extreme.
- **The riser**, at (1.20, 0.46): the liquid line up from the condenser through an insulated
  receiver drum with bands, a screen and a gauge, to z 1.59, then west and south into the coil's
  top turn. The skyline, at y+z 2.18.
- **Plumbing**: compressor → condenser (discharge, over the seam and down the saddle),
  condenser → receiver (along the skid's east edge), receiver → coil (the riser), coil →
  a deck flange (the return continues under the deck) and a suction stub off the compressor.
  Two handwheels, two cables from the cabinet's junction box (one across the bay to the
  compressor, one to the skid).
- **The fluid stubs**: a bolted collar at the hull and a 0.5-tile-wide barrel to the tile edge,
  one per direction, rendered with the hull as a holdout.

### Where it departs from the sections above

- **The old half is squat and the graft is tall.** The session's plan had a tall blue cabinet;
  the first render hid the mechanism bay behind it (the camera hides everything behind a mass up
  to its north edge plus its height), so the cabinet became a narrow corner tower and the deck
  opened up. That is also the better story: the old assembler was never tall.
- **The compressor is on the deck at the north-west, not a skid breaching west at ground.**
  Ground hardware past the tiles lies on the neighbour in a row (the recycler shipped that); a
  mount plate at deck height hanging 0.14 past the hull does the silhouette's work without it.
- **The condenser is a skid in front of the vessel, fan in its top**, where the sheet drew the
  fan in the deck centre and the session drew a fin bank overhanging east. The fan over the fins
  is the physics; the south-east corner is where its rows stay clear of the compressor's.
- **The receiver is the expansion vessel**, vertical and insulated, on the riser.
- **No idle loop.** See `decisions.md` → *Art*: the engine freezes a non-working machine, so the
  fan stopping and the window dimming are the idle read, as on every vanilla assembler.
- **The turntable is dark and the workpieces pale**, the reverse of the session's plan: under the
  cyan lamp a pale table blew out to a flat cyan rectangle, and the eye needs dark against the
  glow.

### Measured

Off the packed sheets and the engine, 2026-09-13:

| | this | AM3 | target |
|---|---|---|---|
| base sprite | 198 x 234 src px, drawn 1.01 x 1.20 of the footprint | 196 x 192, 1.02 x 0.94 | — |
| north overhang | **0.67** tiles | ~0 | ≤ 0.70 |
| luminance sd (painted) | **48.7** | 52.0 | 43–56 |
| clipped | 0.0% | — | ≤ 0.05% |
| saturation / ≥0.12 | 0.51 / 90% | 0.47 / 96% | — |
| blue paint | 21.1% | 13.7% (AM3), 17.1% (AM2) | 13.7% |
| silhouette | 0% full-width rows, fill 0.87, ragged 0.80 | 0%, 0.92, 0.89 | 0%, ≤0.90, ≥1.05 |
| objects | 206, of which 19 draw nothing (flanges inside bodies, the hidden lamp) | — | — |

Paint-over: `make_look.POST` — the stock entity preset with form 0.90, contrast 0.55, crevice
0.42, no saturation or value correction. The raw render measures sd 30 and the pass takes it to
49–54 without clipping; the palette was sampled, so colour stays in the materials.

### What the engine settled

- **`idle_animation` does not play** (tick sequence, no change between t+6 and t+18 on a
  `no_recipe` machine; the working machine changed by a mean of 17/255 in the fan region). Cut.
- **`pipe_picture` is drawn centred on the tile outside the connection.** The first stubs drew a
  tile too far out — a floating hook above the north pipe, a spare flange on the south one.
- **The idle window was too bright** with the cell lamp at 0.30 in the base: luminance 88
  against the working 101–125. The base now carries a tenth.
- **The pipe entity's ending sprite carries the joint's flange**, so the stub is a collar and a
  barrel only.

## Not settled

Everything below is a modelling or play judgement rather than a decision that changes the
machine; `deferred.md` owns the list.

- **`animation_speed` 0.5** was chosen so the loop runs at one frame a tick at crafting speed
  2 (64 ticks a loop). Unverified against a vanilla assembler standing beside it in play.
- **Ragged silhouette 0.80** against the gate's 1.05 floor; the vanilla 3x3 assemblers measure
  0.82–0.93. Holes in clear air would buy more.
- **The rime reads at zoom 2 and above, not at zoom 1.** Whether that is enough cold is a play
  call.
- **`thumbnail.png`, the item icon and the technology icon** are built from one 512 render
  turned so the vessel stands in front (`render_icon.py`, yaw −32°, elevation 47°). Not reviewed
  by the owner.
- **Balance.** Nothing here is a balance claim. The stats are in `decisions.md` and are a
  reasoned placement, not a measurement.
