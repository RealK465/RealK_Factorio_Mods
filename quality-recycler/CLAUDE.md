# CLAUDE.md — Quality Recycler

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

A new recycler kind: **12% base quality chance built in (no modules needed), 2.5x the vanilla
crafting speed, five module slots, a 4x4 footprint, unlocked after the first three planets with
Space Age and after the rocket without it.** The verified mechanism
and how that compares to the vanilla recycler are in `.ai-support/decisions.md`. **The entity,
item, recipe and technology exist and the data stage loads clean** (2026-09-10). Nothing has been
played yet, and the balance is a guess rather than a measurement — see `.ai-support/deferred.md`.

The entity's visual design is settled — a salvaged vanilla recycler with planet-tier sorting gear
grafted on, hero an eddy-current sorting rotor. It lives in
`.ai-support/quality-recycler-design.md`, and it also sets the mod's house art style, since there
is no separate art-direction register. **The entity is modelled, animated and rendered** — sources
in `../assets/quality-recycler/entity/quality-recycler/`, sheets in `graphics/entity/`, eight
directions at **six** layers each, plus the item and technology icons, and a `thumbnail.png`
built from the icon render (below).

**The art is built from the output position backwards.** `vector_to_place_result =
{-0.35, -2.3}` is a DIRECT-output position -- the tile past the back edge, where the alt-mode
arrow points and the results appear -- not where a mined machine drops its contents. The port
sits on that line (`PORT_X = -0.29` units); move the value and the art is wrong. The x offset
is the vanilla recycler's own and not a style choice: a 4x4's centre is a tile corner, x 0
would put the result on the seam between two tiles, and -0.15 put the arrow 5 px from it -- a
player with a chest on each tile could not tell which one fed. Reasoning in
`.ai-support/quality-recycler-design.md` -> *v3*, *v4* and *round 8*.

**Keep the output end LOW; a port's height belongs behind the mouth, not over it.** In east
and west a part's height projects up-screen, perpendicular to the output axis, so a tall hood
over the mouth draws the port's mass north of the arrow and reads as a misplaced ejector while
the mouth is exactly on the output position. The roof falls toward the mouth and only the back
step the trough feeds through keeps its height. Reasoning in
`.ai-support/quality-recycler-design.md` → *v4, After play (round 7)*.

**The port is POSED per direction: in east and west its raised parts slide 0.25 units
screen-south.** In those two rotations a part's height and its extent across the output axis
both project up-screen, so the port's block drew 0.6-1.4 tiles north of the arrow while its
foot sat exactly on it, and no geometry fixes that -- the arrow marks ground. It is what
vanilla does with the oil refinery's four models. `qr_layout.port_shift()` runs from
`set_direction()` for every driver, moves everything on the port but the sill, and keys the
ejected chips only while they are out of sight; north and south are untouched, and so is the
audit, which reads the model at north. Do not "fix" the E/W sheets by editing geometry that
looks right in north. Reasoning in `.ai-support/quality-recycler-design.md` → *round 8*.

**The item icon frames the whole machine, from 52 degrees.** Two icons cropped into the rotor
and the owner rejected both. A flat machine's icon gets squarer as the camera goes UP, not
down; the numbers are in `render_icon.py` beside the constants.

**Moving parts translate along an axis or turn about Z; nothing swings about a horizontal
axis.** The camera looks along (0, +y, -z), so a flap dropping out of a north-facing mouth
moves along the view ray and is invisible in north. Horizontal motion is visible in all four
rotations. Reasoning in the design doc -> *v3, The route*.

**Radial slots are a fan; concentric slots are a motor.** The rotor cap has six short curved
vent slots for that reason, and its bright magnet segments are worn steel, not `polished` --
a metallic material inside a bore has only the bore to reflect and renders near-black.

**The hero rotor turns about Z, and that is not a style choice.** This rig scales world Y and
world Z to the same 64 px in the row direction, so a ring about Z *or* Y projects as a true circle
-- but `set_direction()` rotates the model about Z, which turns a Y-axis ring into an X-axis one in
east and west, and an X-axis circle projects to a LINE. A horizontal drum is round in two rotations
and flat in two. **On a rotatable entity a Z-axis rotor is the only radial form that reads in all
four**, and the first build's missing east and west hero is what that costs. Reasoning in
`.ai-support/quality-recycler-design.md` -> *The rotor axis*.

**A recess has to be built as a recess.** A dark box laid over an opening in a solid hull is still
a solid box: the shredder maw shipped that way and all three rollers and all three tooth rings drew
exactly zero pixels in every rotation. Build the hull as spans AROUND the opening, and size the
opening against the depth -- at 45 degrees a ray entering at the lintel drops one tile of z per
tile of y, so a 0.12-deep recess shows only the top 0.12 tiles of its back wall.

**Tune the palette on rendered swatches, never on hex codes.** `swatch.py` renders every material
as a lit stepped block through the entity's own rig and `measure_swatch.py` prints what it became.
That is how `bronze` was caught rendering (113, 115, 78) -- green-dominant grey, because `patina`
(`#39685B`) stayed at 0.52 after zone 2 stopped being verdigris -- and how the olive was caught at
hue 48, red-dominant khaki, where the vanilla recycler's own measures hue ~78.

**The massing is a cone, and it has to stay one.** A rotatable entity has four north edges, so
every vertex must satisfy `max(|x|,|y|) + z <= 2.75` (the 4x4's half-depth plus 0.75) or it
draws over the machine behind it in some rotation — 0.77 tiles of overhang, the chemical
plant's, which is vanilla's ceiling for a rotatable machine. `cone_z()` is the rule, `audit()`
checks it on every build, and `fit_cone()` takes up the last couple of percent with one uniform
scale. Reasoning in `.ai-support/quality-recycler-design.md` → *the rotation cone*.

**The layout is written in the 3x3's units and scaled 1.2x on the root.** `qr_layout.py` kept
its coordinates when the entity became 4x4; `quality_recycler_gen.BASE_SCALE` turns them into
tiles the same way the cone fit is applied. A literal in the layout is therefore 1.2 tiles, the
footprint edge is ±1.667 there, and the audit prints tiles. The note beside `BASE_SCALE` says
why 1.2 and not 4/3.

**Measure opaque pixels, never a declared sprite box.** The vanilla recycler's east sheet
declares 0.86 tiles of overhang and fills 0.69; the other 0.17 is the packer's padding. Trusting
the declared number pushed this entity's budget 0.05 past anything Wube ships.

**But the cone is not what flattens a machine — leaving the footprint is.** At the footprint
edge the cone still allows a 0.97-tile wall. Keep the **hull** inside ±1.32 layout units and
spend the height there; a wall hanging past its own tiles buys nothing and costs the front
elevation.

**Ground-level hardware stays INSIDE the footprint; only the output sill crosses the edge.** The
cone bounds height, not reach, so nothing in the gates sees a low part hanging past the tiles —
and in play it draws over whatever is placed beside the machine. The 3x3 shipped its cabinet
0.36 tiles past the west edge and its apron 0.55 past the south, and the owner's screenshots
of a row of machines showed both lying on the neighbour. Everything at ground level now sits
inside ±1.95 tiles; the sill reaches 0.28 past the north edge because that tile is the output.
Reasoning in `.ai-support/quality-recycler-design.md` → *v4*.

**Two things the numeric gates cannot see, both of which shipped once.** They read the output
PNG, so a sprite can be green on luminance, contrast, saturation and silhouette and still be
the wrong machine — that is exactly what happened here. And `ragged` is alpha perimeter over
bbox perimeter, so raggedness is bought with **holes** (open railings, ladders, cables in clear
air) and *lost* by adding solid parts.

**Never steer the paint-over by luminance sd — split it into form and grain.** Contrast above
12 px against contrast below 3 px: vanilla carries its at ratio 0.61 (recycler) to 1.08 (chem
plant), and raising `form_amount` to hit an sd target buys the number by *smoothing* the
machine. This entity sat inside the sd band through two rejected builds at ratio 1.25.
Settled for v3: `form_amount` 0.28 with `contrast_amount` 0.75 and `crevice_amount` 0.45 --
the v3 palette's raw render already measures sd 39-43, so the pass only sharpens. Reasoning in
`.ai-support/quality-recycler-design.md` → *Built* and the art log.

**This entity rotates, so it has four front elevations.** "A side wall renders as a one-pixel
line" is a fixed-entity rule. The west wall is the front in east, the north wall in south, the
east apron in west — every one of them needs stiles, rails and a focal point, or three
rotations read as blank painted plates.

**Nothing may stand on a deck that is already at the cone limit; spend the detail downward.**
The rear deck tops out at 1.06 where `cone_z` allows 1.07, so a cooler on it measured 2.48 and
`fit_cone()` refused rather than shrink the machine 9% to hide it. A recessed louvre bank reads
the same at 30 px and costs no height.

**An emissive lit in the base sheet lights the IDLE machine.** The base is drawn in every
state; only the glow sheet is working-only. `render_entity.py` therefore dims the violet
materials to 0.22 for the base pass, and any new light goes in the glow layer, never as a
bright emissive in the base. Reasoning in `.ai-support/quality-recycler-design.md` → *v3,
After the engine*.

**Check the glow sheet separately — it hides faults the base sheet cannot show.** Three shipped
at once here: a beacon clipped to pure white (keep colour x strength near 1.0), and a violet
pair buried inside the rear deck so the south view had no field at all. Measure lit pixels and
per-channel maxima per direction, not by eye.

## Layout

```
info.json                  base, quality, recycler, space-age
data.lua                   requires the two prototype files, in order
data-final-fixes.lua       sizes the result inventory to the widest recycling recipe, after
                           every mod has had its say (see Decided)
prototypes/recycler/entity.lua    the furnace, built from scratch (see Decided)
prototypes/recycler/item.lua      item, recipe and technology
prototypes/recycler/pictures.lua  graphics_set and graphics_set_flipped
changelog.txt
LICENSE
README.md
locale/en/quality-recycler.cfg
graphics/entity/quality-recycler/  base, anim (64f), shadow, fx (64f),
                            light (64f) and lamp per direction, for N/E/S/W and
                            the mirrored set, each with the `.lua` sidecar
                            util.sprite_load reads
graphics/icons/            item icon, 120x64 mipmap strip
graphics/technology/       technology icon, 480x256 mipmap strip
thumbnail.png              144x144, portal and in-game mod browser -- the icon render over
                           a dark panel with the title in Titillium Web Bold, built by
                           ../assets/quality-recycler/thumbnail/make_thumbnail.py from
                           renders/icon/icon-raw.png; regenerate, never edit the PNG
.ai-support/index.md       the map -- read it first
.ai-support/decisions.md   what is settled, and why
.ai-support/quality-recycler-design.md   the entity's visual design -- read before any art
.ai-support/deferred.md    open questions and parked work
.ai-support/journal.md     dated sessions, newest first
```

**No sprite numbers live in the Lua.** Every width, height and shift is in the
`.lua` sidecar beside its PNG, written by the generator's `make_sheets.py`, so a
re-render never touches `prototypes/`. Two traps that cost a validate each:
`sounds` and `hit_effects` are globals inside base's own data stage and must be
`require`d by file, and **`frame_count` in a sidecar is ignored** --
`util.sprite_load` reads only width/height/shift/line_length from the file and
takes everything else from its options table.

`assets/quality-recycler/entity/quality-recycler/` at the repo root holds the Blender sources.
Since the 2026-09-11 rebuild they are split by job, and all of them import the first:

| file | what it is |
|---|---|
| `quality_recycler_gen.py` | materials, geometry helpers, the cone rule, the direction transform, `audit()`, `fit_cone()` |
| `qr_rebuild.py` | the curved primitives the above could not make -- `ring()`, `torus()`, `radial_bars()`, `barrel()`, `hood()`, `wall_chevrons()` -- plus the Phase 1 look-dev variants |
| `qr_layout.py` | **the machine** (v4): plinth and coolant step, sealed rotor, looms, the open feed trough with its spout and hood, trough and ejector, the olive half, the power cabinet, walkway and ladder, the operator console |
| `qr_anim.py` | the twelve working systems -- rotor, rollers, feeder ram, ejector ram, doors, the ejected chips, the feed stream, five violet lights -- and the idle |
| `render_entity.py` | headless bake, six layers x eight directions |
| `lookdev.py` | one-frame look-dev at sprite density and 4x |
| `swatch.py` / `measure_swatch.py` | every material as a lit block, and what it measures |
| `show.py` | paint over a look-dev frame, composite on Nauvis, print the four numbers that move this sprite |
| `make_sheets.py` | paint-over per frame, pack, write the sidecars and `sheet_numbers.txt` |
| `make_look.py` | the settled paint-over `POST` dict -- every other tool imports it from here |
| `preview_game.py` | composite the packed sheets the way the engine draws them, on real terrain, beside real vanilla machines, with night and looping GIFs |
| `check_sheets.py` / `check_wear.py` / `check_visibility.py` | the gates, the edge-wear mask, the object-ID pass |
| `versions/` | the pre-rebuild v0 generator and the v2 generators that differ from commit 57acdf1; no `.blend`, they regenerate it |

`assets/quality-recycler/thumbnail/make_thumbnail.py` builds `thumbnail.png` (`--preview`
writes a 4x blowup beside its 512 master): the same icon render and the same paint-over the
item icon gets, so the two match, over a dark panel with a violet cast and the title set in
the game's own Titillium Web Bold, the way Pure Modules' is built. **Re-render the icon
first after any model change** -- `render_icon.py` into `renders/icon/`, then `make_icons.py`
-- since the thumbnail reads that raw render and the shipped icon is cut from it.

Only exported PNGs land in `graphics/`. See the repo `CLAUDE.md` → *Asset sources*.

No `control.lua` is expected for a data-only entity. If the mechanic turns out to need runtime
scripting, that is itself a decision to record in `decisions.md` before writing it, not something
to fall into.

## Dependencies

`["base >= 2.1.0", "quality >= 2.1.0", "recycler >= 2.1.0", "? space-age"]`, and
`quality_required: true`. Space Age is **optional**: `prototypes/recycler/item.lua` picks the
recipe and the technology gate on `mods["space-age"]`, so the mod is two configurations and
**both must validate** (`validate.ps1` plain, then with `-Disable space-age`). Reasons — why
`recycler` is declared explicitly rather than left as `quality`'s transitive dependency, why
`expansion_required` is deliberately not set, why the branch keys on `mods` rather than a
feature flag, and why the optional dependency carries no version — are in
`.ai-support/decisions.md`.

## Working here

- Commit scope is `quality-recycler`. Repo-wide changes use `repo`.
- **Never commit, push or publish unprompted** — repo `CLAUDE.md`, and approval is per request.
- **`.ai-support/` is this mod's local context — start at its `index.md`.**
- **Validate after any prototype edit** — `factorio-validate`, about five seconds. It has already
  caught two things nothing else would have: `hit_effects` needing a `require`, and a
  `frame_count` written into a sidecar where `util.sprite_load` ignores it.
- **Run the object-ID pass before judging any change to the model** —
  `blender -b -P check_visibility.py -- <dir> --dirs N,E,S,W` in the entity's asset folder.
  Every part gets a flat colour off a value lattice and a pixel count. It has caught, twice
  over, faults nothing else can see: the ring gear buried in a wall, the radiator inside the
  rear deck, the whole capacitor bank embedded in a 0.14-tile apron, and a fan "ring" built
  with `cyl()` lidding the hub it was meant to surround. **60 of 213 objects once drew nothing
  at all.** The design's *Built* section says what it found and the two ways the tool lies.
- **`cyl()` makes a solid disc, not a ring** -- which is why `qr_rebuild.py` exists. It carries
  `ring()` (a true annulus or arc on any axis), `torus()`, `radial_bars()`, `barrel()`, `hood()`
  and `wall_chevrons()`. Reach for those rather than stacking `cyl()`s; the old failure mode was
  invisible in a render and obvious only in the object-ID pass.
- **A part the pass calls dead is not always a part to move.** Three here were deleted instead:
  in north the drum occludes them and in south the rear deck does, so no wall could be opened
  to reveal them. Check what the occluder actually is before rebuilding around it.
- **Photograph it in the engine after any art change** -- `scripts/screenshot/shoot.ps1` with
  `-ExtraArgs '--force-opengl'` on this machine, a spec that inserts items so the machines
  WORK, and alt-mode on so the output arrow shows. It is the only check that sees where the
  results actually appear; v2 shipped with its output art on the wrong side of the machine and
  every offline gate green.
- **Balance is still a guess.** Nothing has been played for more than a screenshot.
- **A machine from a save older than 2026-09-11 stands half a tile off the grid.** It was
  placed as a 3x3, at a tile centre; the engine keeps an entity's position when its box
  grows, so the 4x4 now sits at x.5 and its output tile, arrow and mouth are half a tile off
  the chest grid -- the seam-straddling picture all over again, with nothing wrong in the
  mod. Measured 2026-09-12 on the owner's test save, and reproduced the other way round:
  under the owner's full mod set the engine reports `grid 4x4` and snaps a fresh placement
  to whole tiles. Mine and re-place before judging the port on an old save.

## Decided

- Name `quality-recycler`, title "Quality Recycler". `embedded-quality-recycler` and
  `recycler-quality` were the alternatives considered; all three were free on the mod portal.
- Version starts at `0.1.0`, unpublished (`changelog.txt` carries `Date: ????`).
- Dependencies and feature flags as above.
- **The mechanic: `effect_receiver.base_effect.quality = 0.12`, `crafting_speed = 1.25`, five
  module slots, 1 MW, a 4x4 footprint** at `collision_box = {{-1.7,-1.7},{1.7,1.7}}` (3x3,
  speed 1.0, four slots and 600 kW until 2026-09-11). Verified mechanism, the electricity
  reasoning and the vanilla-recycler comparison in `.ai-support/decisions.md`.
- **Unlocked after the first three planets** — metallurgic + electromagnetic + agricultural
  science, no cryogenic — **with Space Age; after the rocket (space science) without it.**
  Reason and the verification in `.ai-support/decisions.md`.
- **Rotatable: four directions plus mirrored**, the full vanilla recycler treatment. This is the
  mod's largest art cost and it was chosen deliberately over the cheaper non-directional option.
- **Art direction settled** — see `.ai-support/quality-recycler-design.md`.

- **Prototype `quality-recycler`, its own technology `quality-recycling`**, 1 MW / 400 health /
  5 module slots / 4 pollution, recipe built on a whole `recycler` and two quality module 3s plus
  one material from each of the three planets (low-density structures and electric engines
  without Space Age). Re-balanced 2026-09-11 — reasoning in `.ai-support/decisions.md`.
- **Built from scratch, not deep-copied from the vanilla recycler.** A deepcopy carries its 2x4
  collision box, circuit connectors, `vector_to_place_result` and frame-synced working sound,
  every one of them positioned for a different machine.
- **`result_inventory_size` is 25 in the prototype -- the owner's floor -- and re-read in
  `data-final-fixes.lua` as the widest recipe in the machine's categories, never lower.** A
  furnace cannot run a recipe with more
  products than it has result slots, and an inserter then silently refuses the ingredient.
  Krastorio 2 Spaced Out adds a 13th result to scrap recycling and widens only the vanilla
  recycler; measured 2026-09-12 in the owner's game as "inserters will not feed it scrap".
  The reason is in `.ai-support/decisions.md`. **Direct output onto a belt stacks**, up to
  the force's belt stack size, exactly as the vanilla recycler's does -- measured in the
  engine, not assumed, since the prototype API has no field for it (`decisions.md`).

Balance is unmeasured, and sounds, `water_reflection`, a circuit connector and a real remnant are
still open. See `.ai-support/deferred.md`.
