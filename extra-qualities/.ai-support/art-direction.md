# Art direction — Extra Qualities

The two icon families and the rules they follow. Edited in place. Generators live in
`assets/extra-qualities/icons/`; only the exported PNGs go into `graphics/`.

## The mod redraws all seven glyphs, and all four dies

Not just its own two. A tier drawn to different rules is exactly what a player notices, and
the first build proved it: mythic as a die's six face — two columns of three — sat in a
tooltip list as a tall narrow block among square ones, and its pips were visibly smaller than
the five above it. **Consistency across the set beats fidelity to any one icon**, so one
generator now produces all seven glyphs and one Blender model produces all four technology
icons, vanilla's included.

## The pip language

Vanilla's quality glyph is **pips in a heavy black ring, counted by tier**: normal one, uncommon
two, rare three, epic four, legendary five. Colour identifies the tier and the count confirms
it.

- **Six is a hexagonal ring.** **Seven is that ring with the middle filled.** Identical
  footprint, identical pip size, and the seventh pip is drawn on top of the ring exactly as
  vanilla's fifth is drawn on top of its four corners — so the two new tiers inherit the
  language rather than inventing one.
- Six and seven **cannot** use vanilla's 11 px pip: six centres 27 px apart do not fit in a
  64 px canvas in any arrangement. They drop to 8.6 px and take the overlap the five-pip
  quincunx already uses. That size step is the one deliberate break in the set, and it reads
  as density rather than as a different icon.

## Measured vanilla geometry

Off `data/quality/prototypes/quality.lua`'s icons at 2.1.17, and reproduced by
`assets/extra-qualities/icons/make_quality_icons.py`:

| | one to five pips | six and seven |
|---|---|---|
| canvas | 64x64, anchored bottom-left | same |
| fill radius | 11 px (vanilla's) | 8.6 px |
| outer black radius | 1.45 x fill | same ratio |
| centre pitch | 2.45 x fill | 2.25 x fill — the hexagon needs the overlap |
| shading | none; the mid-tones are antialiasing | same |

Bounding boxes come out within 1–2 px of vanilla's for all five redrawn tiers, and six and
seven share one box exactly.

**The overlapping pip is drawn last, ring and all.** Draw every ring and then every fill and
the five-pip centre loses its outline under the corner fills — vanilla's quincunx becomes an
orange blob. Two layers, base then top.

**The prototype's `color` is the icon fill times 0.7.** Base's `normal` is written literally as
`255 * 0.7`, and every vanilla quality icon matches its prototype colour at 1/0.7. So the fills
are `(255, 42, 58)` and `(0, 232, 255)`, and the `color` fields follow from them — not the other
way round.

## Colours

Crimson and cyan. Both hues are unused by the five vanilla tiers (grey, green, blue, purple,
amber), which is the whole requirement: a seventh tier that reads as a sixth at a glance is
worse than no colour at all. Cyan sits nearest rare's blue and is distinguished by being far
lighter, plus two more pips.

## The technology dies

Vanilla's `epic-quality` and `legendary-quality` icons are **one worn white die photographed
corner-on**, its top face carrying the tier being unlocked and the two visible side faces the
two tiers below it. All four icons are that same die, continuing the sequence: epic shows four
purple over uncommon and rare, and so on up to celestial's seven cyan over legendary and mythic.

**Nothing distinguishes the celestial die but its pips.** An earlier pass split it open with a
jagged fracture lit from inside, on the grounds that no die has a seven face. It shipped and
was rejected on sight: the glow read as stray blue lines across the icon, and a fourth die that
does not match the other three undoes the whole reason for redrawing vanilla's two. Colour and
pip count carry the tier; the die stays the die.

**Pip size on a die follows the count too, and there the constraint is a boolean rather than a
canvas.** The sockets are cut out as one joined cutter, so any two that intersect make the
exact solver discard the whole die body — which renders as gems floating in mid-air with no die
behind them, and looks like a material bug. The five-pip quincunx is where it bites: its centre
socket overlaps the four corners at the spacing the four-pip face uses. `METRICS` in
`die_gen.py` gives every count its own inset and socket radius, and `_check_clearance` refuses
to build a face whose sockets would touch.

Measured off the two vanilla PNGs at 2.1.17, and what the generator targets:

| | vanilla | ours, across all four |
|---|---|---|
| die within the 256 box | x 28..235, y 24..255 | 12 px inset, 224 px subject |
| body mean RGB | (165,145,161) and (159,149,129) | (136,131,130) to (171,131,130) |
| luminance sd | 51.9 and 56.1 | 54.3 to 57.5 |
| clipped to white | 0.04% | 0.00% |
| drop shadow | mean alpha 120, RGB (23,21,20) | offset (11,13), blur 7, cap 150 |

Four things the first passes got wrong, all of which look like something else:

- **A boolean leaves an empty material slot 0 behind** and points every polygon at it, so the
  die renders in Blender's default grey however good the material is. Clear the list and
  re-seat it after every boolean.
- **A die is convex, so ambient occlusion does nothing to it.** Vanilla's grime is painted, not
  occluded — it has to come from noise and pointiness. AO only earns its place inside the pip
  sockets.
- **The pip sockets are cylinders, not dimples.** The dark ring round each gem is the socket
  wall seen edge-on; a shallow spherical cap has no wall, and the gem then reads as a sweet
  stuck on the face.
- **Overlapping socket cutters delete the die.** See the note above `METRICS`; the guard is
  `_check_clearance`, and it exists because this shipped once as four dies with no bodies.

## No .blend is kept

Against the repo's usual habit of committing the `.blend` beside its renders. Both generators
are self-contained Python with no external assets and no hand-edited state, so the `.blend`
would carry nothing the scripts do not, and re-rendering from source takes under a minute. If
anything ever gets posed or sculpted by hand, that stops being true and the `.blend` has to
start being saved.
