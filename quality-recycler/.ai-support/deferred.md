# Deferred — Quality Recycler

Parked and open work. The single owner of this list — `CLAUDE.md` doesn't keep a second copy.

## The entity

**The prototype exists and the data stage loads clean.** Name, dependency set, stats, recipe and
technology are all settled — see `decisions.md`. What is left:

- **Nothing has been played.** A clean data stage says nothing about whether the machine is worth
  building. 12% quality at 2.5x speed with five slots and a megawatt, for a recycler, two quality
  module 3s and three planets' worth of parts, is a reasoned guess at the balance
  (`decisions.md`), not a measurement — and the base-game branch (low-density structures,
  electric engines, the gate after the rocket) has been validated, never played.
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

## Art — v4, 2026-09-11 (third session)

Sources in `assets/quality-recycler/entity/quality-recycler/`, sheets in
`quality-recycler/graphics/entity/quality-recycler/`. Eight directions at six layers each: base,
anim (64f), shadow, fx (64f), light (64f), lamp. The v3 design is the last section of
`quality-recycler-design.md`; the build log is `docs/art/quality-recycler/LOG.md`.

- **The top shredder roller shows 2 px.** The lintel's 45-degree sight line clips it even after
  the maw was raised to 0.56 tall; the two lower rollers carry the maw. Lowering all three would
  make them interpenetrate. Accepted.
- **Neutral grey sits at 35-48% of opaque pixels**, above the vanilla recycler's 31%, because
  the composite family is a cool low-saturation grey by design. It reads as value contrast,
  not as flatness, but it is the number that would move if the panel family were warmed.
- **The rotor's apparent speed is unverified beyond screenshots, and screenshots cannot
  verify it.** `animation_speed = 2` was chosen because a crafting machine's animation is scaled
  by crafting speed unless `constant_speed` is set; the cap turns 60 degrees a loop. The
  benchmark renderer produces a new frame only every few ticks, so a tick sequence from the
  probe cannot resolve a 32-tick loop. Watch it in play beside a vanilla recycler; if it reads
  frantic or sluggish this is the one number to change and it needs no re-render.
- **The sill still reaches 0.28 tiles into the output tile.** Everything else at ground level
  is inside the footprint since v4, but the sill is the drop point and stays; a chest on the
  output tile draws over it in south. Check with items on the ground once the machine is
  played; the art-only fix would be a shorter sill.
- **The layout is in the 3x3's units at BASE_SCALE 1.2.** Correct and documented, but a
  reader of `qr_layout.py` has to know it. If the machine is ever re-laid at 1:1 the scale goes
  back to 1.0 and every literal grows by 1.2; nothing else changes.
- **The stream chips wrap inside the hood and the spout**, which relies on both staying solid
  and on the fx layer holding the base out. Moving either opens the wrap.
- **`thumbnail.png`.** Still not created.
- **Frozen layer for Aquilo.** Deliberately skipped, and the reason is a gameplay one: the
  patch only ever shows if the entity carries `heating_energy`, which the vanilla recycler gets
  from Space Age's `base-data-updates.lua` and this one does not. Adding it would make the
  machine stop on Aquilo without heat -- a balance change, not an art change. At eight
  directions it is eight more sprites when it happens.
- **The `fx` sheet is the least efficient thing on the entity** (64 frames whose union box
  spans the whole route). Half-resolution packing the way the glow sheet is packed would
  quarter it; not done blind, because it is a colour layer rather than a blur.
- **Sounds, `water_reflection`, a circuit connector and a real remnant** remain open -- see
  *The entity* above. The remnant is the next art job once the entity is played.
