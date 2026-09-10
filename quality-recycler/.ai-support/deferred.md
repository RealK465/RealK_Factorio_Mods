# Deferred — Quality Recycler

Parked and open work. The single owner of this list — `CLAUDE.md` doesn't keep a second copy.

## The entity

**The prototype exists and the data stage loads clean.** Name, dependency set, stats, recipe and
technology are all settled — see `decisions.md`. What is left:

- **Nothing has been played.** A clean data stage says nothing about whether the machine is worth
  building. 12% quality at 2x speed for a recycler plus three planets' worth of parts is a guess
  at the balance, not a measurement.
- **Sounds.** The vanilla recycler's loop is reused; its `sound_accents` deliberately are not.
  They are frame-synced to a jaw that bites on frames 14/20/45/60-63, and this entity's jaw is
  three counter-rotating rollers with no bite at all. Accents synced to this animation would be
  better than none.
- **No `water_reflection`.** Free when deriving from a vanilla entity, absent on one built from
  scratch. Worth adding.
- **No circuit connector.** The vanilla recycler has one; this does not, because
  `circuit_connector_definitions["recycler"]` is positioned for a 2x4 body.
- **`corpse` and `dying_explosion` are the generic `big-remnants` / `big-explosion`.** The
  vanilla recycler has bespoke ones. A real remnant is its own art job — see
  `factorio-graphics` → *Remnants*, which is emphatic that a wreck follows almost none of the
  entity's rules.

## Art — rendered, not yet wired

Sources in `assets/quality-recycler/entity/quality-recycler/`, sheets in
`quality-recycler/graphics/entity/quality-recycler/`. Eight directions —
N/E/S/W plus the mirrored set for `use_mirroring` — at four layers each.

- **The icon is serviceable, not vanilla-grade.** Rendered at elevation 34
  rather than the 46 in `references/icons.md` — that figure was tuned on
  vanilla's modules, which are small cubes, and this machine is squat enough
  that 46 letterboxed it into a 64 px square and turned to mush at the 32 px it
  is actually read at. It is legible now; it is not as strong as the vanilla
  recycler's, which fills its frame. Cropping tighter on the rotor half — the
  machine's identity — would probably beat showing the whole machine.
- **`thumbnail.png`.** Still not created.
- **No dust puff at the maw.** The last of the design's seven animated
  elements, and the only one not built.
- **The concept sheet's barrel lies east-west and this one stands north-south**,
  and that gap does not close. An X-axis cylinder has every circular
  cross-section edge-on at this rig, so it renders as a flat striped rectangle
  with no roundness in its silhouette at all — built and measured, not assumed.
  See `quality-recycler-design.md` → *Built*. Nothing to do here; recorded so it
  is not re-attempted.
- **Frozen layer for Aquilo.** Deliberately skipped. Nothing breaks; the entity
  renders unfrosted beside vanilla entities that do freeze. At eight directions
  it is eight more sprites later, not one.
- **Skid feet render zero pixels**, hidden under the concrete pad. Kept because
  they still matter to the shadow pass — but if the pad shrinks, they should
  reappear at its corners where vanilla puts its anchors.
- **The gear no longer visibly meshes with the drum.** It is half-buried in the
  olive block's south wall and reads as a drive gear on the shredder, which is
  honest, but the design's "ring-gear drive taken off the salvaged half, so the
  seam is mechanical" wanted it engaging the rotor. On the Y axis the drum's
  west edge sits at x -0.18 and the olive block's east face at -0.24, so there
  is no gap between the halves to put a meshing gear in. A toothed ring band on
  the drum itself would say the same thing and stay inside the cone.
- **In-engine photography.** Nothing here has been seen in the renderer. Module
  tint, `draw_as_light`, render-layer order and shadow blending only resolve
  there, and a rotation-specific fault is invisible to an offline check — which
  is exactly the class of problem this entity turned out to have.
