# Art lessons

One lesson per entry, updated rather than duplicated, deleted if it turns out wrong. These
generalise past the entity they were learned on; anything specific to one machine stays in that
entity's own log and in the mod's `.ai-support/`.

---

## A Z-axis circle is the only radial form that reads in all four rotations

At this rig screen row is `-(y + z)` and screen column is `x`, so a ring about **Z** projects as a
true circle and so does a ring about **Y** — but `set_direction()` spins the model about Z, which
turns a Y-axis ring into an X-axis one in east and west, and an X-axis circle projects to a *line*.
So a Y-axis drum is round in two rotations and flat in two. On any rotatable entity, put the hero's
radial form on Z.

Learned on the Quality Recycler, whose east and west views lost their hero entirely because the
drum was on Y. The reasoning that put it there compared X against Y only, because the rotation
constraint was worked out afterwards.

## Vanilla concentrates chroma into one hue band; scattered chroma integrates to grey

Measured over opaque pixels, the share of chromatic pixels (saturation >= 0.18) falling in the
single dominant 15-degree hue band: vanilla recycler **44%**, chemical plant **48%**, EM plant
**54%**. A sprite with olive, copper, bronze, violet and blue at comparable weights measured 22% on
the same statistic and read as grey mush, while its *mean saturation* was already in vanilla's
range.

So "the sprite looks desaturated" is usually not a saturation problem. Check the hue histogram
before touching a saturation knob: each vanilla machine is one colour with accents, not a palette.

## Every numeric gate can pass while the sprite is the wrong machine

Contrast sd, clipping, fill, raggedness, full-width rows, shadow purity and overhang were all green
on a sprite its own author called unusable. The gates read the output PNG; they cannot see
composition, hero legibility or story. Put the sprite beside real vanilla art on real terrain and
look at it — that comparison has found, in one image, things seven numeric gates could not.

## A part with no material renders brighter than anything in the palette

Blender's default grey is lighter than a worn-industrial palette's lit faces, so a part whose
material argument was forgotten reads as a deliberate white highlight rather than as a bug. Two
tori shipped that way on the Quality Recycler and looked like designed bullseyes. Make the mesh
emitter print a warning when it is handed no material; nothing downstream can catch it.

## A hollow swept arc shows its inside the moment the entity rotates

A cowling or hood built as a thin shell looks correct from the direction it was authored in, and
reads as a trough or a gutter from the rotation that puts an open end toward the camera. Close both
ends with a plate across the chord, not just the shell's rim.

## Check what stands in front of an opening before trusting the model

A skirt, apron or kerb at the machine's own perimeter sits nearer the camera than a recess cut into
the wall behind it, and will hide that recess completely. This is invisible in the 3D scene and
fatal in the sprite — the Quality Recycler's shredder maw was rendered for two builds and never once
appeared. The object-ID visibility pass catches it; reasoning about the scene does not.

## A recess has to be built as a recess; a dark block is still a block

A cavity modelled as a solid box of dark material, laid over an opening in a solid hull, hides
whatever is inside it completely. The Quality Recycler's shredder maw shipped that way twice: three
rollers and three tooth rings drawing exactly zero pixels in all four rotations, with nothing in
the render to say so, because a dark rectangle where a dark mouth belongs looks correct. Build the
hull as spans *around* the opening and put a back wall behind it.

## The visible depth of a recess equals its opening's drop, at this camera

A ray entering at the lintel travels one tile of z down per tile of y in, so a recess 0.12 tiles
deep shows only the top 0.12 tiles of its back wall. Anything lower is behind the lintel. Size the
opening against the depth before placing anything inside it — the Quality Recycler's top shredder
roller sat 0.01 tiles below the line and measured 1 pixel.

## Noise lives in the model; the paint-over cannot take it out

Sweeping `crevice_amount` across 0.95 → 0.40 moved local 5 px luminance sd only 33.9 → 31.3 against
a vanilla band of 27–29, while whole-sprite luminance sd fell with it. Excess high-frequency
contrast comes from having too many small parts, and the fix is to delete the ones the object-ID
pass measures below ~6 px, not to turn a knob down.

## `form_amount` improves every number and can make the sprite worse

`form_contrast` has radius 11, so raising it lifts whole faces toward each other: at 0.55 the
Quality Recycler scored its best local-sd and luminance-sd figures of the whole session and
rendered bleached and milky. Use the statistics as a floor to clear, not a target to maximise, and
settle the value by looking at the image.

## A part within 0.06 of an extreme inherits that extreme's entire row band

`audit()` collects every vertex in that band into the extreme, so one 0.07-tile boss at the
machine's northernmost point pulled in a deck, a capacitor bank and two cable runs and handed one
rotation a 0.96-tile band of full-width rows. When an extreme has to be owned, give it to a single
part standing at least 0.12 clear of everything else, and choose its row band deliberately against
the opposite extreme's — in all four rotations, because which parts those are changes with each.

## The cone bounds height, not reach — and vanilla spends the difference

`max(|x|,|y|) + z <= APEX` allows a part at ground level to sit three quarters of a tile outside a
3×3's footprint, and vanilla does exactly that: the chemical plant's sprite is 145 screen px tall
against a 96 px footprint, almost all of the excess in pipe stubs at z ≈ 0. A machine that keeps
everything inside its tiles is leaving a quarter of its sprite height unused. Keep the *hull* inside
the footprint for the front elevation, and hang low hardware past it.

## Check that a loop's wrap sits inside the loop's own range, not against one step

Comparing |last → first| with |first → second| calls a flicker layer seamless or seamed depending
on which frame you happened to pick, because a flicker's typical step *is* a discontinuity. Take
all N adjacent-frame differences and check the wrap is inside their distribution.

## Composite both sides of an A/B at the same density, and verify it

A comparison sheet that drew our sprite at `scale = 0.5` and vanilla's source frames 1:1 made every
vanilla machine look twice its true size, and the conclusion drawn from it — "grow the sprite" —
was wrong by a factor of two. Any compositor that handles two sources differently needs one measured
check (a known entity's footprint in screen pixels) before its output is trusted.

## A saturated hue cannot be as bright as a desaturated one — vanilla's own ramps are uneven

Factorio's quality colours measure luminance 178 / 129 / 95 / 48 / 122, because a pure blue or
purple simply has less luminance available than a green at the same saturation. A brief to
"equalise the indicator lamps" therefore cannot be met without abandoning the hues. What can be
done is bound them from both ends: cap every channel below the clip point, and cap the *brightest*
lamps so the lowest tier is not the loudest thing on the machine.

## An emissive drawn in both the base and the glow sheet clips at their sum, not at either

`draw_as_glow` with `blend_mode = "additive"` adds over a base sheet that already contains the lit
surface, so a lamp measured as safe in each sheet on its own can still saturate in game. Give the
material headroom in the base, and let the additive layer supply the brightness. The Quality
Recycler's five quality lenses and its green status lamp all rendered **white** this way while both
sheets measured clean.

## Give the albedo and the emission different colours when a small lit part must read as one hue

A 4 px lit dielectric under this rig carries a whitening floor of roughly +105 per channel, so no
albedo lands the rendered pixel on a dark saturated target. Paint the albedo pre-compensated for
that floor, and set the *emission* to the true colour — the glow sheet is added over the base, so
the sum is what the player sees and the emission is the half that survives the lighting unchanged.

## The one motion this camera cannot see is a slope descending away from it

The view direction is (0, +y, -z) at 45 degrees, so a part moving north while dropping at the
same rate stays on the same screen row: a flap hinged at the top of a north-facing mouth,
swinging down and out, is invisible in the north rotation and a line in east and west. Any
purely horizontal motion (along x or y) is visible in all four rotations, because it is
screen-horizontal in two and screen-vertical in the other two. Ejectors, feeders and shutters
should therefore translate along an axis of the machine, or rotate about Z, never swing about a
horizontal axis. Learned designing the Quality Recycler's ejector: a pusher ram along the
trough, not a flap.

## Radial slots are a fan; concentric slots are a motor

A pale disc with six radial slots reads as a spoked wheel however it is lit, and so does a ring
of tapered blades. The same disc with six short curved slots following the circumference reads
as a ventilated motor end-cap. On the Quality Recycler's rotor cap both were rendered at
gameplay zoom in the same session; only the second stopped the "fan" reading.

## A metallic material inside a bore renders near-black, whatever its albedo

A polished (metallic 0.55) material for the magnet segments came out as a dark annulus under a
cowl, because a metal reflects the world and the world inside a bore is the bore. Worn bright
steel at metallic 0.42 with roughness 0.30-0.52 read as bright segments in the same spot. Put
metallic materials where the sky can reach them; use a diffuse-leaning bright material anywhere
sunk into the machine.

## A screenshot of a machine is not a screenshot of a WORKING machine

Three separate things kept the probe's machines idle while every shot looked plausible: the
recipes were locked (a fresh map has researched nothing), nothing had been inserted, and the
power was a big pole 24 tiles away whose supply area is 4x4. The tell was a tick sequence in
which the rotor never moved. The probe now researches everything, inserts a slow item, powers
each group from a substation at its centre, and logs `status working` per machine before it
shoots. Read that line before believing a working-state screenshot; and shoot a tick sequence,
never one frame, to judge motion. The benchmark renderer produces a new frame only every few
ticks, so sample eight ticks apart across a loop rather than expecting per-tick samples.

## The screenshot harness needs a display, and a sleeping monitor is not one

`--benchmark-graphics` on the Direct3D path dies at adapter-output enumeration when no display
output is attached to the session (monitor asleep, or a remote session), and then spins forever
trying to go fullscreen. `--force-opengl` plus `[graphics] full-screen=false` in the scratch
config renders the same screenshots.

## A profile-wide file search hydrates OneDrive

`find` over the user's profile root walked into the OneDrive folder and Files On-Demand began
downloading the whole cloud, even with stat-only predicates. Search the repo, the dev installs,
Downloads and the scratchpad; if a named file is not there, it is missing -- say so.
