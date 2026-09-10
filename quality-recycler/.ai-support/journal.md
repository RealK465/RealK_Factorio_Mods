# Journal — Quality Recycler

Append-only, newest first. What happened, dated.

## 2026-09-10 — the art rebuild, against the concept sheet

The repo owner rejected the first sprites: too far from `prototype.png`, "still a
lot to do". They were right, and the useful part is *why every numeric gate was
green while the sprite was wrong*. Measured on the shipped north sheet before any
change: luminance 68.7 against the vanilla recycler's 67.0, sd 49.1 against 44.5,
saturation in band, zero full-width rows, overhang 0.69. Nothing in the kit reads
**shape**, and shape was the whole fault — a pale flat pancake with a corrugated
panel where the drum should be and a spray of magenta over the middle.

**The cone was blamed for the flatness and was not the cause.** The constraint is
`max(|x|,|y|) + z <= APEX`, and at the footprint edge that leaves `APEX - 1.30`
of wall — 0.95 tiles at the old 2.25. The first build spent it anyway by putting
the south wall *outside* the footprint at y -1.58, where only 0.67 is available,
and got a 29 px front elevation. Keeping the hull inside its own tiles gives 56 px
at the same APEX. A machine cannot both hang past its tiles and be tall.

APEX went 2.25 -> 2.32 -> **2.27**, and the round trip is the lesson. 2.25 came
from the chemical plant's *north* alone, so all four directions were read off the
sidecars, and the vanilla recycler appeared to overhang 0.58 / **0.86** / 0.22 /
0.59 — grounds for raising the budget. Checking the same sheets by **first opaque
row** instead of by declared box: 0.58 / **0.69** / 0.06 / 0.59. The 0.86 was
0.17 tiles of transparent padding. The chemical plant, whose padding is under a
pixel, really does reach 0.77, and that is vanilla's ceiling for a rotatable
machine. APEX 2.27 lands on it exactly. **Measure opaque pixels, never the
declared sprite box** — a packer's margin is not art.

Bringing 2.32 back to 2.27 put seventeen parts over at once, which is what
`fit_cone()` exists for: one uniform scale moves `max(|x|,|y|) + z` by the same
factor for every vertex, where trimming needs a different edit per part (a box is
bound by its corner, a drum by the 45 degree point on its circle, a rib ring by
neither). The model ends 2.0% smaller inside its own footprint — 1.3 px on a
64 px tile — and the function refuses to scale below 0.94 so it cannot quietly
swallow a part left somewhere absurd.

**`audit()` had been checking `y + z`, which is the north overhang, not the cone.**
It passed a railing at `max(|x|,|y|) + z = 2.61` without a word, because that part
was low in *y*. It now ranks every object on the cone itself and names the
offenders. Six were found and fixed the first time it ran.

**The X-axis experiment, and why the design's original choice stands.** The concept
sheet draws the barrel lying east-west, so the drum was swung to X to match it. The
result was a flat striped rectangle with no barrel in it. The rig gotcha "a disc on
the transverse X axis is exactly edge-on" governs **every circular cross-section of
an X-axis cylinder**, not just a thin disc: a circle in the y-z plane projects to
`-(y0+z0) - r*sqrt(2)*sin(theta+45)`, a line segment, so the barrel keeps its
length and loses its roundness *including its silhouette*. Reverted to Y, where the
axis sits at 45 degrees to the view and the drum shows a curved flank plus one end
cap for the copper flange to live on. Recorded because the reasoning that led away
from it was plausible and wrong, and the sheet will tempt the next person the same
way.

What actually closed the gap to the concept, in order of how much it moved:

- **Massing.** Three tiers inside the footprint, 0.86 tiles of south wall.
- **The drum**, 0.92 -> 1.26 tiles across, with nine copper/violet/blue bands, 14
  axial ribs and a copper end flange. Bands alone would have been a mistake: a
  concentric-banded drum is rotationally symmetric and shows *no motion at all*
  when it spins. The ribs are what make the turn visible.
- **The maw**, from a grey grille to a dark box with three bright chrome rollers.
  Three attempts: gunmetal lining with scoured teeth (a grille), a dedicated
  near-black `cavity` material (better), and finally inverting the values —
  **bright rollers with dark teeth, stopping 0.15 tiles short of the opening at
  each end** so the darkness reads as cavity rather than as border.
- **Chevrons on dark backing plates.** They had been yellow-on-olive: two mid-tones
  of one warm hue, invisible at gameplay zoom however correct the geometry. Vanilla
  paints hazard stripes on black. Also genuinely diagonal now, via a new `xz_prism`
  that extrudes a polygon along Y instead of Z — a wall decal needs the other axis
  from a deck decal, and stepping a diagonal out of axis-aligned boxes reads as a
  staircase.
- **The olive palette, measured rather than judged.** The concept render's olive is
  `#584D33` at luminance 78 with a 10th percentile of 11; ours was `#71653F` at 101
  with a p10 of 38 — too bright, and with no dark end at all, which is what made a
  painted steel block read as a card. New base `#605932`, metallic 0.30 -> 0.18
  (this is flat paint, and at 0.30 the whole face carried one broad specular), and
  world ambient 0.15 -> 0.12 to let the shadows reach dark. It now measures
  `#5C4C32` at 78 against the sheet's 78.
- **The magenta went away.** Ten violet pips rode the drum's rim, so an additive
  glow layer swept an arc across the sprite every loop. Replaced with two static
  slots on the housing wall.

**Raggedness is bought with holes, not with parts.** A chunky machine reads smooth:
the rebuilt hull measured 0.97 against the 1.05 floor. The first fix added solid
blocks past the pad and raggedness went *down*, to 0.95 — each one grew the filled
area faster than the outline. `ragged` is alpha perimeter over bbox perimeter, so a
hole counts twice and a block counts against you. Four open railings clear of the
pad, a ladder standing off the west wall and four cables in open air took it to
1.11 without adding a single solid.

## 2026-09-10 — the prototype

Wrote the entity, item, recipe and technology; the data stage loads clean against
2.1.17 with base, elevated-rails, recycler, quality and space-age.

Built from scratch rather than deep-copied from `data.raw["furnace"]["recycler"]`.
A deepcopy would have carried the vanilla recycler's 2x4 collision box, its
circuit connector definitions, its `vector_to_place_result` and its frame-synced
working sound — all positioned for a machine this one is not the shape of, and
all of them the kind of thing that lands in the wrong place with nothing to warn
you. The working-sound *loop* is reused; its `sound_accents` are not, because
they fire on frames 14/20/45/60-63 of a jaw that bites, and this jaw is three
counter-rotating rollers.

The `space-age` dependency question is closed: the gate needs three science packs
that only exist with Space Age, so the dependency moved rather than the gate. It
does narrow the audience — `recycler` and `quality` ship independently of
`space-age` — and that is the cost of a tech gate the repo owner specified.

Sprite numbers stay out of the Lua entirely. `make_sheets.py` now writes a `.lua`
sidecar beside every PNG and `util.sprite_load` reads them, so a re-render changes
the crop and the shift and nothing in `prototypes/` is touched. Two things that
cost a validate each: `sounds` and `hit_effects` are globals inside base's own
data stage and have to be `require`d by file; and **`frame_count` is ignored in a
sidecar** — `util.sprite_load` takes only width, height, shift and line_length
from the file and everything else from its options table, so the anim layer loaded
as a single frame and the engine rejected the mismatched layer counts. A third,
caught by reading rather than by the loader: the light layer's shift has to come
from the full-resolution crop box, not the half-size cell box, or the glow lands
69 px left and 81 px up.

The icon is rendered at elevation 34 rather than `references/icons.md`'s 46. That
figure was tuned on vanilla's modules, which are small cubes; this machine is
squat enough that 46 letterboxed it and it turned to mush at the 32 px an icon is
actually read at.

## 2026-09-10 — animation, shadows, lights, and the rotation problem

Second `factorio-graphics` session: rigged the animation, added the shadow and
light passes, rendered all four directions and packed the sheets. Sixteen files,
4.4 MB total — the vanilla recycler spends 3.7 MB on one direction of its body
alone, because it animates the whole machine where this splits a static body
from a 64-frame overlay.

**The flat-render weakness the last session recorded is fixed, and the fix was
not where I first put it.** The raw frame measured luminance sd 26.5 against the
beacon's 31.6, and I had pushed the paint-over's `form_amount` to 1.85 to cover
it — the paint-over inventing contrast instead of sharpening it. Darkening the
palette did nothing: an absolute sd needs bright highlights as much as dark
crevices, and lowering everything moves the mean and the spread together. A
harder key with less sky fill (6.6 / 0.95 / 0.15 against the rig's validated
5.2 / 1.2 / 0.22) took the raw to sd 30.4, and the stock `form_amount` then
lands 45.7 on the packed sheet.

**The session's real finding: a rotatable entity has four north edges.**
Rotating the model swaps which axis points north, so the overhang for a
direction is `max(axis + z)` and getting north right says nothing about the
other three. North measures 0.69 tiles; east, south and west measure 1.42,
1.50 and 1.50 against a vanilla ceiling of 0.77 across every rotation of every
machine that ships. Worse, the silhouette guarantee is direction-specific too —
the disjoint-extremes massing that makes a full-width scanline impossible in
north leaves west at 23.4% full-width rows. And "put tall things south, height
is free there" turns out to be a north-only trick: rotate 180 degrees and the
cancellation becomes an addition, which is why the exhaust stack is the worst
single offender in the south view.

The condition that covers all four at once is `max(|x|,|y|) + z <= 2.25` — the
machine has to be a cone, tall in the middle and low at every edge, which is
exactly the shape of the chemical plant, the one vanilla 3x3 crafting machine
that rotates. This entity was a slab: 47 of its 105 objects broke the cone.
Put to the repo owner as a choice between re-massing and dropping to one
non-directional sheet, since `decisions.md` records rotatability as their
deliberate call; **they chose the re-mass plus the full eight sheets**.

The machine is now a stepped ziggurat and 0 of 114 objects break the cone, at a
worst-direction overhang of 0.75 against vanilla's 0.77 ceiling. Three things
the re-mass cost. The front elevation became a letterbox — the south wall was
1.06 tiles and the cone allows 0.67 at y -1.58, so the maw is a low slot and
the hopper a loading lip; every vanilla rotatable machine reads this way.
Raggedness collapsed to 0.99, because compact reads smooth — and the first fix
for that failed instructively: five railings and pipes added for perimeter all
sat *over the concrete pad*, drew opaque-on-opaque, and moved ragged from 0.99
to 0.98. Only geometry past the **pad's** outline makes new silhouette edge.
And every extreme has to be re-checked whenever anything moves: pulling the
east side in handed the east extreme to a bracket whose rows overlapped the
west chute's, and a `pipe_run` puts a flange 1.65x its radius past the endpoint
given, which quietly made a stub the west extreme and put 0.8% of scanlines
full width.

`cone_z(x, y)` is now the rule the massing is written against, `audit()` prints
the worst offender on every build, and `check_sheets.py` measures overhang per
direction off the packed sheets.

The cone alone was not enough. The re-massed machine still shipped 4.9%
full-width rows in west, because the disjoint-extremes guarantee is
direction-specific in its own right: a row is full width when the sprite's east
and west extremes fall in it, and *which parts those are* changes with the
rotation — in west they are the model's southernmost and northernmost parts and
the rows are `x + z` rather than `y + z`. `audit()` now projects all four
mappings; mirroring only negates screen x, which swaps the extremes and leaves
the row bands untouched, so the flipped set needs no separate pass. The fix was
to make the out-chute the sole southernmost part, clear of the auger housing
and the drain stub, so its row band sits above the north duct's.

Contrast needed one honest override back. The four rotations measure 39.4 /
44.4 / 46.8 / 49.5 at the preset's `form_amount`, because east presents far
more of its shaded side than west does, and one preset has to serve eight
sheets — 1.70 puts the worst inside the 43 floor and leaves the best under the
56 ceiling. That is a different thing from the 1.85 this file recorded earlier,
which was covering for a flat render; that one was fixed in the lighting.

Four modelling faults the object-ID pass and the layer montage caught, all of
them invisible in a plain render: the maw throat was a solid box whose front
face sat south of the rollers, so the shredder rendered as a 2 px line; the
rollers were then still hidden behind the lintel, because a part set deeper in
a recess appears HIGHER on screen and my three rollers were stacked into the
top of the opening; the fragments were technically rendering at 0.09 tiles and
effectively invisible; and six thin bright ridges on a 10 px drum merged into
one white stripe that strobed frame to frame instead of reading as teeth.

Two library gotchas worth not rediscovering. A freshly created empty has not
been through a depsgraph update, so `pivot.matrix_world` is still the identity
and `matrix_parent_inverse` from it is a no-op — every child silently shifts by
the pivot's position, and the drum moved 0.91 tiles up-screen. And the anim
layer has to render the body as a **holdout** rather than hidden: the anim
sheet composites above the base in game, so a moving part behind the hull would
otherwise be drawn straight over it.

## 2026-09-10 — the entity modelled in Blender

Ran `factorio-graphics` from the design plus a concept sheet the repo owner generated
(`prototype.png`). The scene is `assets/quality-recycler/entity/quality-recycler/`; all three
numeric gates pass and the measurements are in the design's new *Built* section.

The concept sheet and the design disagreed in two places and the sheet won one of them. Its
palette **replaces the design's verdigris green** for the new half with heat-tempered violet,
blue and bronze — which is the design's own heat-tint wear signature promoted to be the colour,
so it keeps the physics and drops the two-greens risk the design had flagged against itself. Its
massing did not win: the sheet draws a solid cube filling its 3x3, which is the one silhouette
this rig cannot ship, and the design's diagonal offset is what makes a full-width scanline
geometrically impossible. Two of the sheet's other decisions were unbuildable as drawn and got
changed with a reason each: the rotor turns about **Y** rather than east-west, because a disc on
the transverse axis is exactly edge-on to this camera and renders as a stripe; and the machine is
**1.56 tiles tall at the hood, not 2.5**, because at 2.5 it would draw 1.6 tiles past its own
footprint against a measured vanilla 3x3 band of 0.58 to 0.77.

The object-ID pass was worth more than every other check combined and should be the first thing
run on any future change. It found, in order: the drum sealed inside its own housing; a junction
box and four cables drawing zero pixels behind a wall; three instrument pods hanging in the
shredder's throat; a rivet row on a side wall, which at this pitch renders as a one-pixel line;
and a seam frame that had quietly grown to 17.9% of the sprite while the hero it joins held 4.9%.
Two traps in the tool itself, both of which produced confidently wrong reports before they were
understood: the legend must be a value lattice rather than a hue wheel (96 objects on a
golden-ratio hue collided so hard the report credited a ladder with 18% of the sprite), and
Blender's output path has to be absolute or the render lands elsewhere and the analysis silently
reads a stale image.

One `parts.py` gotcha cost a render and is worth not rediscovering: the greeble builders bake
their centre into the mesh and leave the object at the origin, so `place(rot=...)` rotates a part
about the **world** origin, not its own. A louvre bank placed at (1.44, -0.30) with `rot=90` flew
to (0.30, 1.44) and became the tallest thing in the sprite.

Still no `.lua`, and no sheets: what exists is one look-dev frame, not the eight directions.

## 2026-09-10 — entity design session

Ran `factorio-entity-design` end to end and wrote `quality-recycler-design.md`. The repo owner
added one constraint the scaffold did not have — unlocked after the first three planets — which
turned out to name a single real rung: `planet-discovery-aquilo` is the only vanilla technology
at metallurgic + electromagnetic + agricultural with no cryogenic pack. That gap between the
vanilla recycler (production science, Nauvis) and this one (three planets later) became the whole
art brief.

The design that came out: a salvaged vanilla recycler with planet-tier sorting gear grafted on,
hero being an eddy-current sorting rotor. Quality read as *separation* rather than
transmutation — a remelt crucible was rejected for implying a mechanic the entity does not have.

Reference numbers were measured rather than recalled, and two corrected assumptions were worth
the trouble. The **electromagnetic plant is 4x4, not 3x3** (collision 3.4 rounds up), so it is
this entity's mechanical precedent but not its size reference — chemical plant and biochamber
are, both at 2.4. And **violet 286 deg is the only quality-ramp colour no vanilla machine's
emissive claims**; legendary amber collides with the foundry. `counterpart.py` gave the palette
fractions: vanilla recycler 7-10% paint over a 45-49% rust substrate, against Space Age's
0.1-1.7%.

Three of the eight stages went against the recommendation, all recorded as chosen with the risk
stated: **four visible graded bins** over a sight-glass manifold (FFF-339 risk that four bins
imply four drawable outputs, mitigated by a common auger to one chute), **verdigris bronze** on
the new half over bare steel (two greens on one sprite, solved by separating them on material
behaviour rather than hue, with the copper seam collar between them), and the **full four
directions plus mirrored** render treatment over the single non-directional sheet every vanilla
3x3 uses — eight base sheets at 64 frames, the mod's largest art cost.

Still no `.lua`. The design fixed the footprint, the rotatability and the collision box, so those
moved into `decisions.md` where prototype work will look for them; `deferred.md` was rewritten
around what is now actually open, including a dependency problem the design created — the tech
gate needs Space Age science packs that `info.json` does not depend on.

## 2026-09-10 — mechanic decided

The repo owner gave concrete numbers for the entity: quality built in at 12% (no modules
needed), crafting speed 2x vanilla (1.0), footprint 3x3. Verified the mechanism against
`prototype-api.json` before recording it as decided rather than taking it on faith —
`effect_receiver.base_effect.quality` is a real, legal field on a `furnace`-type entity's parent
`CraftingMachinePrototype`, not a guess. Also checked the vanilla recycler's actual stats
(`data/recycler/data.lua`): `crafting_speed = 0.5`, `180kW`, `300` health, and a 2x4 — not
square — footprint, so 3x3 turns out to be barely bigger by tile count, mostly a shape change
worth flagging rather than assuming.

Recorded in `decisions.md`; the resolved question removed from `deferred.md`, which now lists
what's still open (name/prefix, recipe/tech placement, energy use, health, art). Still no
`.lua` written — this was a docs-only update, via `/claude-md-management:claude-md-improver`
redirected to this repo's own CLAUDE.md/.ai-support contract instead of that skill's generic
repo-wide audit.

## 2026-09-10 — scaffold

Mod started via `/factorio-mod-setup`. The brief: "a very simple mod... a new recycler kind to
the game, a recycler with embedded quality." Named `quality-recycler` after checking three
candidates against the mod portal API (all free); the repo owner picked it over
`embedded-quality-recycler` and `recycler-quality`.

Scaffolded per the repo's no-Lua-until-asked convention: `info.json`, `changelog.txt` (0.1.0,
open), `LICENSE`, `locale/en/`, `README.md`, this `.ai-support/` tree, and this mod's own
`CLAUDE.md`. Added to the root `CLAUDE.md` → *Mods in this repo* list. No prototype or script
code written.

Dependencies settled as `quality >= 2.1.0` and `recycler >= 2.1.0` (both explicit — see
`decisions.md`), confirmed against the installed `data/quality/info.json` and
`data/recycler/info.json`. `quality_required: true`; `expansion_required` deliberately left
unset after checking `doc-html/auxiliary/mod-structure.html` (it gates belt-stacking properties,
not quality).

The exact "embedded quality" mechanic is the open question in `deferred.md` — the next step is
`factorio-entity-design`, once the repo owner wants to move on it.
