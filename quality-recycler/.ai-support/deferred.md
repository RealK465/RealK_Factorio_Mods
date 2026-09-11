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

## Art — rebuilt 2026-09-11

Sources in `assets/quality-recycler/entity/quality-recycler/`, sheets in
`quality-recycler/graphics/entity/quality-recycler/`. Eight directions —
N/E/S/W plus the mirrored set for `use_mirroring` — at **six** layers each:
base, anim (64f), shadow, fx (64f), light (64f), lamp.

- **In-engine photography.** Nothing has been seen in the renderer. Render-layer
  order, `draw_as_glow` blending, `fadeout`, shadow compositing and the
  `always_draw` status lamp only resolve there, and a rotation-specific fault is
  invisible to an offline check — which is exactly the class of problem this
  entity turned out to have. `scripts/screenshot/shoot.ps1` is the harness.
- **The rotor's apparent speed is unverified in game.** `animation_speed = 2`
  was chosen because a crafting machine's animation is scaled by crafting speed
  unless `constant_speed` is set, and this machine runs at 1.0 against the
  vanilla recycler's 0.5. The exact scaling law was not confirmed against a
  running game; if the rotor reads frantic or sluggish beside a vanilla
  recycler, this is the one number to change, and it needs no re-render.
- **`thumbnail.png`.** Still not created.
- **No dust puff at the maw.** The one element of the original seven never
  built. Eight systems ship without it.
- **Frozen layer for Aquilo.** Deliberately skipped, and the reason is now a
  gameplay one: the patch only ever shows if the entity carries
  `heating_energy`, which the vanilla recycler gets from Space Age's
  `base-data-updates.lua` and this one does not. Adding it would make the
  machine stop on Aquilo without heat — a balance change, not an art change.
  At eight directions it is eight more sprites when it happens.
- **The icon is serviceable, not vanilla-grade.** Rendered at elevation 34
  rather than the 46 in `references/icons.md` — that figure was tuned on
  vanilla's modules, which are small cubes, and this machine is squat enough
  that 46 letterboxed it. Cropping tighter on the rotor — the machine's
  identity — would probably beat showing the whole machine.
- **The east–west barrel the concept sheet draws is impossible and this is
  settled.** Every circular cross-section of an X-axis cylinder is edge-on at
  this rig. The rebuild went further and put the rotor on **Z**, because a
  Y-axis one is edge-on in east and west once `set_direction()` has rotated the
  model. Recorded so neither is re-attempted; see `quality-recycler-design.md`
  → *The rotor axis*.
- **Local 5 px luminance sd sits 3–5 points above vanilla** (32.6–34.4 against
  the vanilla recycler's 29.2 and the chemical plant's 27.1). Measured, and the
  paint-over cannot fix it — sweeping `crevice_amount` 0.95 → 0.40 moved it only
  33.9 → 31.3. It is the cost of 205 objects on a 3×3. The next pass on this
  entity should cut parts, not turn knobs.
- **Two parts still draw nothing, and both are small.** The final object-ID
  pass (2026-09-11, all four rotations) reports `cap-can1` and `gantry-foot`
  invisible; `cap-can2` and `cap-top2` sit at 3 and 7 px. The capacitor bank is
  three cans and one of them is behind the coil; the gantry's foot plate is
  inside the rotor step. Neither is worth an 80-minute re-bake on its own —
  fold them into the next pass on this entity. The other six the pass lists
  (`arc1-3`, `frag1-3`) are keyed OFF at frame 0 and are artefacts of a
  one-frame check.
- **`scan` lives in QR_Base although it moves.** Harmless — it is keyed to
  scale 0 at frame 0 so it is absent from the static base sheet, and the glow
  sheet carries its sweep. Moving it to QR_Moving would be tidier and costs an
  `anim` re-bake.
