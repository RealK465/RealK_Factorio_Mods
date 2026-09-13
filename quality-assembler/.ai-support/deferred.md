# Deferred — Quality Assembler

Parked and open work. The single owner of this list — `CLAUDE.md` doesn't keep a second copy.

As of 2026-09-13 (evening) the mod is **built and unplayed**: the entity is modelled, animated,
rendered and wired, the icons and thumbnail exist, both configurations validate on both tracks,
and the machine has been photographed working in the 2.1 engine. What is left is play, and the
polish nothing has forced yet.

## Settled, so not here

Name, version, dependency set, footprint, the mechanic and its stats, crafting categories, fluid
boxes, `allowed_effects`, fast replacement, the technology gate and cost, the recipe on both
branches, health, pollution, and the art — see `decisions.md` and the design document's *Built*
section. The four questions the concept sheet opened were settled by the owner's build brief and
are recorded in `decisions.md` → *Art*. Don't reopen them without the owner.

## The `legacy/2.0` build

Ported 2026-09-13, the same day the entity was built — see `decisions.md` → *The 2.0 track*
for the fork. What is open there is the same as here: nothing on the 2.0 track has been played
either, and the machine has not been photographed in the 2.0 engine, only validated against it.

## The entity, as shipped

- **Sounds.** The working loop is the assembling machine 3's `assembling-machine-t3-1.ogg`, at
  its volume. Accents synced to this machine's own animation — the turntable's index step, the
  compressor — would be better and are not written.
- **Corpse and explosion** are the generic `big-remnants` / `big-explosion`. A real remnant is
  its own art job; `factorio-graphics` → *Remnants* is emphatic that a wreck follows almost
  none of the entity's rules.
- **The circuit connector** is the assembling machine's, on the south-east corner. Its placement
  has not been photographed with a wire attached; do that before trusting it.
- **Ragged silhouette 0.80** against the gate's 1.05 floor. The vanilla 3x3 assemblers measure
  0.82–0.93 themselves, so this is the class rather than a defect, but it is the one gate number
  still under its band. Raggedness is bought with holes in clear air — a second guard rail, a
  hoist beam — if it is ever worth the pixels.
- **The window at gameplay zoom** is a lit cyan rectangle with the table's front edge and pale
  workpieces in it; at zoom 4 the turntable reads. The design predicted exactly that and put the
  state read on the fan instead.
- **The dome top** is the largest calm area on the sprite: an insulated cap with a bolted flange,
  four seams, a manway and two lugs. If the machine ever reads too plain from above, that is the
  surface to spend on.
- **Rime** is a material term (foot, sill, coil, cell), heaviest low and in crevices. It reads
  as white patches on the dark sill and foot at zoom 2 and above; it does not read at zoom 1.
  Whether that is enough cold is a play judgement.

## Balance

**Nothing has been played, and nothing has been measured.** The stats in `decisions.md` are a
reasoned placement between two vanilla machines, in the same method `quality-recycler` used, and
that mod's own balance is still a guess too. Two things specific to this machine are worth
watching in play:

- **A free 12% quality is worth far more on an assembler than on a recycler**, because an
  assembler crafts a far larger share of everything a base makes. The owner was offered 8% for
  that reason and chose to keep the pair matched at 12%. If it plays too strong, this is the
  number to move, and moving it costs nothing but a line.
- **Fast replacement makes adoption total.** Because it swaps in over every assembling machine
  3 with one upgrade planner, the machine is either built everywhere or nowhere; there is no
  gradual middle. That sharpens whatever the balance turns out to be.
- **The recipe is a first guess.** Twenty lithium plates and ten superconductors on top of an
  assembling machine 3 and two quality module 3s is priced by analogy with the cryogenic plant,
  not by play.

## Release and tracks

- **Unpublished.** `0.1.0`, `Date: ????`, no git tag. Portal name confirmed free 2026-09-13; the
  mod-portal **license field** must be set to GPLv3 at publish time, since `info.json` has no
  license key.
- **`images/`** — no portal gallery screenshots taken yet. The harness shots in the session
  scratchpad are not gallery material; a gallery shot is a composed scene in a real base.
- **No migrations, and none expected.** A new mod has no old saves. A migration only becomes
  necessary if a prototype is renamed or removed after a release.
