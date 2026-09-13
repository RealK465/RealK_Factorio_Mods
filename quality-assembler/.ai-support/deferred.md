# Deferred — Quality Assembler

Parked and open work. The single owner of this list — `CLAUDE.md` doesn't keep a second copy.

As of 2026-09-13 the mod is a **scaffold**: folders, `info.json`, `changelog.txt`, `LICENSE`,
locale, `README.md`, `CLAUDE.md` and this folder. No Lua, no art, nothing validated. So most of
this list is "the mod", not a set of loose ends — it is written out so the next session can pick
up a specific piece rather than re-deriving the whole shape.

## Settled, so not here

Name, version, dependency set, footprint, the mechanic and its stats, crafting categories, fluid
boxes, `allowed_effects`, fast replacement and the technology gate are all decided — see
`decisions.md`. Don't reopen them without the owner.

## The prototype — not written

- **`data.lua` and `prototypes/assembler/{entity,item,pictures}.lua` do not exist.** The entity's
  numbers are all in `decisions.md`; what is *not* decided is below. Build the prototype from
  scratch rather than deep-copying `assembling-machine-3` — the recycler mod learned that a
  deepcopy carries a collision box, a circuit connector and a frame-synced working sound all
  positioned for a different machine.
- **`max_health` is open.** The assembling machine 3 is 400, the electromagnetic plant 350.
  `quality-recycler` took 400. Needs one number and a line in `decisions.md`.
- **`emissions_per_minute` is open.** The assembling machine 3 is 2, the electromagnetic plant
  and `quality-recycler` are 4. At speed 2 this machine does 1.6x an assembler 3's work, so
  somewhere in 3-4 is proportionate; pick one rather than letting it default.
- **The recipe is open, both branches.** `quality-recycler`'s shape is worth copying as a
  *shape*: a whole machine of the tier below plus two quality module 3s (the "quality built in"
  as an ingredient), then materials that say where the machine has been. Here that would start
  from an `assembling-machine-3` and, with Space Age, Aquilo-tier parts; without it, the base
  game's own late-game materials. `energy_required` 10 is the electromagnetic plant's and a
  reasonable default. Nothing is chosen yet.
- **Technology cost is open in its detail.** `decisions.md` fixes the *rung* and names
  `quantum-processor`'s 500 x 10 packs x 60 s as the cost class to copy; the exact unit count
  and the prerequisite list beyond `cryogenic-science-pack` still need writing.

## The entity — designed, not built

**The design is settled** — `quality-assembler-design.md`, written 2026-09-13 — and the repo
owner's own concept sheet, `prototype.png`, arrived the same day and **outranks the prose on
anything it shows**. Read both before any Blender work. The design document fixes the lore
anchor, the hero, the silhouette, the sixteen components, the palette, the wear map and the
animation; its *The owner's concept sheet* section records where the sheet changed it, and its
*Not settled* section is the authority on what is still open. Those are not repeated here.

**Four of those open questions came from the sheet and need the owner, not a modelling call.**
They are stated in full in the design document; in one line each: with the frost window gone the
machine shows **no material flow at all** — choose that or give the column a viewport; whether
the sheet's **amber** is a deliberate warm counterweight (replacing copper in material zone 4) or
incidental; whether the **violet family tell** to `quality-recycler` is dropped or merely not
drawn; and whether **rime** goes back on at modelling time.

What remains is the making of it:

- **All art.** Entity sheets (base, anim, shadow), the item icon, the technology icon. Sources
  belong in `../assets/quality-assembler/`, exports in `graphics/`. `factorio-graphics` is the
  skill; the design document is its input.
- **`thumbnail.png`.** Not created. 144x144, and `quality-recycler`'s
  `../assets/quality-recycler/thumbnail/make_thumbnail.py` is the pattern — built from the item
  icon render so the two match.
- **The visual relationship with `quality-recycler` is deliberately thin, and the concept sheet
  may have made it thinner still.** The two mods do *not* share a palette: the recycler is violet
  because it earned violet as steel tempering colour, and cold does not produce violet. The
  session's family tell was one small violet point on this machine's module bay backlight — and
  **the sheet draws no violet at all**, which is one of the four questions above. There is one
  tie the sheet did add without being asked: **hazard chevrons**, which the recycler quotes off
  the vanilla recycler and this machine now carries on its base plinth. If the family read still
  comes out too weak once both machines are in a game together, that chevron quote is the cheaper
  thing to lean on than a second accent colour.

## Entity properties the recycler also left open

Each of these is free when deriving from a vanilla entity and absent on one built from scratch.
The assembling machine 3 has all four, so there is a concrete reference for every one:

- **`working_sound`.** The assembling machine 3's loop is
  `__base__/sound/assembling-machine-t3-1.ogg` at volume 0.45 with a 4/20-tick fade. Reusing it
  is the cheap answer; accents synced to this machine's own animation would be better.
- **`water_reflection`.** The assembling machine 3 has one, from
  `prototypes.entity.assembler-pictures`.
- **Circuit connector.** The assembling machine 3 has one, and `circuit_wire_max_distance` with
  it. Unlike the recycler's case there is no footprint mismatch — this machine is the same 3x3 —
  so the vanilla assembler connector may well fit as-is. Check before assuming.
- **`corpse` and `dying_explosion`.** Generic `big-remnants` / `big-explosion` is the fallback;
  a real remnant is its own art job, and `factorio-graphics` → *Remnants* is emphatic that a
  wreck follows almost none of the entity's rules.

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

## Release and tracks

- **Unpublished.** `0.1.0`, `Date: ????`, no git tag. Portal name confirmed free 2026-09-13; the
  mod-portal **license field** must be set to GPLv3 at publish time, since `info.json` has no
  license key.
- **The `changelog.txt` 0.1.0 entry is a placeholder** — one `Major Features: - Initial
  release.` line. It needs to describe the machine the way `quality-recycler`'s does, written
  when the entity actually exists, not now.
- **The `legacy/2.0` build exists as a scaffold**, created 2026-09-13 in the same session, the
  way `robotics-reforged` was. `info.json` is its whole divergent list — four fields inside it:
  `factorio_version`, the `base` floor, the `quality` floor and `homepage`. **The version is
  `0.1.0` on both tracks**, because nothing has shipped on either and a second `Date: ????`
  section stacked on an unshipped one is what `factorio-changelog` forbids; the tracks take
  separate numbers at the first release. The declaration is in the repo `CLAUDE.md` → *Git*.
  Whether anything beyond `info.json` forks depends on what the prototype ends up using, and
  `factorio-multiversion`'s three classes of difference — hard errors, silent property drops,
  silent behaviour changes — are the thing to read before writing it, not after.
- **No migrations, and none expected.** A new mod has no old saves. A migration only becomes
  necessary if a prototype is renamed or removed after a release.
