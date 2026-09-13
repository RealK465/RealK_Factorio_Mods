# CLAUDE.md — Quality Assembler

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

A new assembling machine: **12% base quality chance built in (no modules needed), crafting speed
2, five module slots, a 3x3 footprint, fast-replaceable with an assembling machine 3, unlocked
after Aquilo with Space Age and after the rocket without it.** The verified mechanism and how it
compares to its two reference machines are in `.ai-support/decisions.md`.

**Scaffold plus a design, as of 2026-09-13 — folders, wiring, docs and the entity's design
document; no Lua and no art.** Nothing has been validated, because there is nothing to validate
yet. **Unpublished**, `0.1.0`, no git tag; run the `factorio-release` skill's "Published or
open?" check rather than trusting a number written here.

The entity's visual design is settled — **an assembling machine 3 that came back from Aquilo
with half of it replaced**, hero a jacketed cold build vessel with an indexing turntable behind a
frost window, because **quality on an assembler reads as tolerance, not selection**. It lives in
`.ai-support/quality-assembler-design.md` and it also sets the mod's house art style, since there
is no separate art-direction register.

This mod is the sibling of `../quality-recycler` and was asked for as "similar, but an
assembler". The shared idea is the mechanic — a free permanent quality bonus on a top-tier
machine. **Everything structural differs**, and the four differences below are the ones that
will bite if the recycler is copied from rather than read.

**An assembling machine's art is NOT directional.** `assembling-machine-3` ships one
`graphics_set` — a single 64-frame animation with base, anim and shadow layers at `scale = 0.5`
— and the engine rotates only the fluid pipes. The recycler's eight sheets are a recycler thing.
Do not budget or build eight directions here; the entity has one elevation, and the whole
`set_direction()` / rotation-cone apparatus in the recycler's generator does not apply. Verified
against `data/base/prototypes/entity/assembler-pictures.lua` at 2.1.17.

**It has fluid boxes, and that decides where the art may put anything.** An assembler that can
run `crafting-with-fluid` needs an input box connecting north at `{0, -1}` and an output box
connecting south at `{0, 1}`, with `fluid_boxes_off_when_no_fluid_recipe = true` so they vanish
on a dry recipe. Those two tiles are pipe attachment points in every rotation, so nothing in the
model may stand over the north or south mid-edge. The recycler had no such constraint.

**It allows productivity, and the recycler deliberately does not.** `allowed_effects` here is
the assembling machine 3's exactly — `consumption`, `speed`, `productivity`, `pollution`,
`quality`. Recycling returns a fraction of what went in so productivity on it would be free
matter; assembling has no such problem.

**It is fast-replaceable with the vanilla assemblers.** `fast_replaceable_group =
"assembling-machine"`, which is what makes it an upgrade rather than a separate machine, and is
half the reason the footprint is 3x3. A change to either one is a change to both.

**`effect_receiver.base_effect.quality` is the mechanic, and it is inherited, not special.**
`AssemblingMachinePrototype` extends `CraftingMachinePrototype`, which is where `effect_receiver`
lives — the same field the recycler's furnace uses, verified in `prototype-api.json` at 2.1.17.
There is no assembler-specific spelling to look for.

**No `result_inventory_size` problem here.** The recycler carries a whole `data-final-fixes.lua`
sizing its result inventory to the widest recipe in its categories, because a *furnace* picks
its own recipe and silently refuses ingredients when it runs short of result slots. An
assembling machine is given its recipe by the player and sizes itself from it. Do not port that
file.

Three more rules come out of the design session and bind code as much as art. Their reasons are
in `.ai-support/quality-assembler-design.md`; these are the rules.

**Never add `heating_energy`.** The machine's whole premise is that it *makes* cold rather than
needing it supplied — it carries a compressor and a condenser, and deliberately no heat-pipe
fitting anywhere on the model. Adding the field would stop the machine on Aquilo without heat,
which is a balance change, and it would make the art a lie at the same time.

**The bright turquoise emissive goes in `working_visualisations`, never in
`graphics_set.animation`.** The animation layer is drawn in every state, so an emissive lit there
lights the *idle* machine. The base carries the dim idle glow alone. `quality-recycler` shipped
this fault once and had to dim its violet materials to 0.22 for the base pass.

**Nothing on the model may look like an item intake — no port, hopper or chute.** An assembling
machine accepts inserters on all four sides, so a named intake promises a direction the entity
does not have; vanilla's own assembler has none for exactly this reason. All the material
evidence lives inside the frost window.

## Layout

Planned. Only the files marked **on disk** exist today; the rest is the shape the work should
take, not a claim that it is there. Git does not track an empty directory, so
`prototypes/assembler/` and `graphics/` will not appear in a clone until they hold something.

```
info.json                  on disk -- base, quality, optional space-age
changelog.txt              on disk -- 0.1.0 open, Date: ????
LICENSE                    on disk
README.md                  on disk
locale/en/quality-assembler.cfg   on disk
CLAUDE.md                  on disk -- this file
data.lua                   requires the two prototype files, in order
prototypes/assembler/entity.lua     the assembling machine
prototypes/assembler/item.lua       item, recipe and technology
prototypes/assembler/pictures.lua   graphics_set
graphics/entity/quality-assembler/  base, anim and shadow, one direction, with the
                           `.lua` sidecars util.sprite_load reads
graphics/icons/            item icon
graphics/technology/       technology icon
thumbnail.png              144x144, portal and in-game mod browser
.ai-support/index.md       on disk -- the map, read it first
.ai-support/decisions.md   on disk -- what is settled, and why
.ai-support/deferred.md    on disk -- open questions and parked work
.ai-support/journal.md     on disk -- dated sessions, newest first
.ai-support/quality-assembler-design.md   on disk -- the entity's visual design, read before
                           any art work or the entity prototype
.ai-support/prototype.png  on disk -- the owner's concept sheet; outranks the prose on
                           anything it shows. Git-ignored, so not in a clone
```

**No sprite numbers will live in the Lua.** Every width, height and shift belongs in the `.lua`
sidecar beside its PNG, the way `../quality-recycler` does it, so a re-render never touches
`prototypes/`. Two traps that cost that mod a validate each and will cost this one the same:
`sounds` and `hit_effects` are globals inside base's own data stage and must be `require`d by
file, and **`frame_count` in a sidecar is ignored** — `util.sprite_load` reads only
width/height/shift/line_length from the file.

Blender sources go to `../assets/quality-assembler/`, never inside this folder. See the repo
`CLAUDE.md` → *Asset sources*.

No `control.lua` is expected for a data-only entity. If the mechanic turns out to need runtime
scripting, that is itself a decision to record in `decisions.md` before writing it.

## Dependencies

`["base >= 2.1.0", "quality >= 2.1.0", "? space-age"]`, and `quality_required: true`. No
`recycler` dependency — this mod touches nothing in it. Space Age is **optional**, so the mod is
two configurations and **both must validate** (`validate.ps1` plain, then with
`-Disable space-age`) once there is anything to validate. Reasons in `.ai-support/decisions.md`.

## Working here

- Commit scope is `quality-assembler`. Repo-wide changes use `repo`.
- **Never commit, push or publish unprompted** — repo `CLAUDE.md`, and approval is per request.
- **`.ai-support/` is this mod's local context — start at its `index.md`.**
- **Validate after any prototype edit** — `factorio-validate`, about five seconds, both
  configurations.
- **The entity is designed but not built.** `.ai-support/quality-assembler-design.md` is the
  brief; `factorio-graphics` builds from it. Read it before opening Blender, and read its *Not
  settled* section before deciding anything it deliberately left open.
- **`.ai-support/prototype.png` is the owner's own concept sheet, and on anything it shows it
  outranks the design document's prose.** Read both. The design document's *The owner's concept
  sheet* section records where the two differ and carries inline markers on the superseded
  passages. The sheet is git-ignored, so it is not in a clone — do not assume a reader has seen
  it.
- **Read `../quality-recycler/CLAUDE.md` for the rig lessons, not for the entity.** Its palette,
  cone, paint-over and object-ID rules are general and hard-won; its eight directions, its
  output port and its `data-final-fixes.lua` are not this machine.
- **Balance is a reasoned guess.** Nothing has been played. See `.ai-support/deferred.md`.

## Decided

Full reasoning in `.ai-support/decisions.md`; these are the rules.

- Name `quality-assembler`, title "Quality Assembler". Confirmed unclaimed on the mod portal
  2026-09-13.
- Version starts at `0.1.0`, unpublished.
- Dependencies and feature flags as above.
- **The mechanic: `effect_receiver.base_effect.quality = 0.12`, `crafting_speed = 2`, five
  module slots, 1600 kW, a 3x3 footprint** at `collision_box = {{-1.2,-1.2},{1.2,1.2}}`.
- **Crafting categories are the assembling machine 3's exactly** — `crafting`,
  `advanced-crafting`, `crafting-with-fluid`. It does not take `electromagnetics`, `metallurgy`,
  `cryogenics` or `organic`; those belong to the expansion machines and this one is not meant to
  replace them.
- **Fast-replaceable with the vanilla assemblers**, and 3x3 so that it is.
- **Unlocked after Aquilo** — `cryogenic-science-pack` — **with Space Age; after the rocket
  (space science) without it.**
- **Prototype `quality-assembler`, its own technology `quality-assembly`.**
- **Art is one direction.** No rotation sheets.
- **Art direction settled** — `.ai-support/quality-assembler-design.md`. Accent is pale
  turquoise (180–195°), with exactly one small violet point on the module bay as the family tell
  to `quality-recycler`. Identity paint is AM3's own 13.7%, on the west half only.

Recipe, health, pollution, sounds and the whole art job are still open. See
`.ai-support/deferred.md`.
