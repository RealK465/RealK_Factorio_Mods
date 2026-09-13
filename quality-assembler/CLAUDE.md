# CLAUDE.md — Quality Assembler

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

A new assembling machine: **12% base quality chance built in (no modules needed), crafting speed
2, five module slots, a 3x3 footprint, fast-replaceable with an assembling machine 3, unlocked
after Aquilo with Space Age and after the rocket without it.** The verified mechanism and how it
compares to its two reference machines are in `.ai-support/decisions.md`.

**Built and unplayed, as of 2026-09-13** — the entity is modelled, animated and rendered
(sources in `../assets/quality-assembler/entity/quality-assembler/`, sheets in `graphics/`),
wired into `data.lua`, validated in both configurations and photographed working in the engine;
the item and technology icons and `thumbnail.png` exist. Nothing has been played beyond
screenshots. **Unpublished**, `0.1.0`, no git tag; run the `factorio-release` skill's "Published
or open?" check rather than trusting a number written here. **The `legacy/2.0` track carries the
same build** with `info.json` and `prototypes/assembler/entity.lua` forked — the three
differences are in `.ai-support/decisions.md` → *The 2.0 track*, and the repo `CLAUDE.md` → *Git*
declares the two files.

The entity's visual design is settled and built — **an assembling machine 3 that came back from
Aquilo with half of it replaced**, hero a jacketed cold build vessel with an indexing turntable
behind a window, because **quality on an assembler reads as tolerance, not selection**. It lives
in `.ai-support/quality-assembler-design.md`, whose *Built* section says what shipped, and it
also sets the mod's house art style, since there is no separate art-direction register.

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
evidence lives inside the window.

Two more come from the engine, measured 2026-09-13, and both bind the sprite wiring:

**There is no idle loop, and do not add one.** `idle_animation` does not play — a machine that is
not working is frozen, and the idle sheet is drawn at the frame the working one stopped on. A
second sheet with different fan angles jumps the instant the machine stops. The machine freezes
when idle like every vanilla assembler; the state read is the window going dim and the fan
stopping.

**`pipe_picture` is drawn centred on the tile OUTSIDE the connection**, the origin pipe covers
use, not on the entity. `make_sheets.py` writes the four stub sidecars against that origin;
a sidecar written against the entity centre puts the stub a full tile past the pipe.

## Layout

```
info.json                  base, quality, optional space-age
changelog.txt              0.1.0 open, Date: ????
LICENSE
README.md
locale/en/quality-assembler.cfg
CLAUDE.md                  this file
data.lua                   requires the two prototype files, in order
prototypes/assembler/entity.lua     the assembling machine, built from scratch (see Decided)
prototypes/assembler/item.lua       item, recipe and technology, forked on mods["space-age"]
prototypes/assembler/pictures.lua   graphics_set, working_visualisations and pipe_picture
graphics/entity/quality-assembler/  base, anim (64f), shadow, glow (64f, half res), lamp and
                           pipe-N/S/E/W, each with the `.lua` sidecar util.sprite_load reads
graphics/icons/            item icon, 120x64 mipmap strip
graphics/technology/       technology icon, 480x256 mipmap strip
thumbnail.png              144x144 -- the icon render over a dark panel with the title, built
                           by ../assets/quality-assembler/thumbnail/make_thumbnail.py;
                           regenerate, never edit the PNG
.ai-support/index.md       the map, read it first
.ai-support/decisions.md   what is settled, and why
.ai-support/deferred.md    open questions and parked work
.ai-support/journal.md     dated sessions, newest first
.ai-support/quality-assembler-design.md   the entity's design and, in *Built*, what shipped
.ai-support/prototype.png  the owner's concept sheet; git-ignored, so not in a clone
```

`../assets/quality-assembler/entity/quality-assembler/` holds the Blender sources, all of them
importing the first:

| file | what it is |
|---|---|
| `qa_gen.py` | palette, the material stack (with the rime term), bmesh primitives, collections, animation, `audit()`; run it for one look frame and the `.blend` |
| `qa_layout.py` | **the machine**: plinth, the old hull and its bay, cabinet, gearbox, compressor, seam, skid, vessel, condenser, riser, plumbing, stubs |
| `render_entity.py` | headless bake of every layer -- `--layers base,anim,shadow,glow,lamp,pipes` |
| `make_sheets.py` | paint-over per frame, pack, write the sidecars and `sheet_numbers.txt` |
| `make_look.py` | the settled paint-over `POST` dict, the gates on a look frame |
| `show.py` | composite a look frame on Nauvis at game zoom and 3x beside the assembling machine 3 |
| `check_visibility.py` | the object-ID pass; `--hide window-glass` to audit the cell |
| `render_icon.py` / `make_icons.py` | the 512 icon render and the two mipmap strips |
| `renders/` | frames and the icon render; git-ignored, regenerable |

**No sprite numbers live in the Lua.** Every width, height and shift is in the `.lua` sidecar
beside its PNG, written by `make_sheets.py`, so a re-render never touches `prototypes/`. Two
traps that cost the recycler a validate each: `sounds` and `hit_effects` are globals inside
base's own data stage and must be `require`d by file, and **`frame_count` in a sidecar is
ignored** — `util.sprite_load` reads only width/height/shift/line_length from the file.

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
- **Rebuild, never hand-edit.** The `.blend` is a snapshot; `qa_gen.py` and `qa_layout.py`
  are the source. After any change to either: `render_entity.py` for the layers touched (a hull
  change invalidates `anim` and `glow` too, because the hull is their holdout and their light),
  `make_sheets.py`, `validate.ps1` in both configurations, then photograph it with
  `scripts/screenshot/shoot.ps1` (`-ExtraArgs '--force-opengl'` here) — the object-ID pass and
  the engine have each caught what no render showed (the fan buried in a solid body; the stubs
  a tile off).
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
- **Art is one direction.** No rotation sheets, and no idle loop (above).
- **Art direction settled and built** — `.ai-support/quality-assembler-design.md`. Accent is
  pale turquoise (180–195°), with exactly one small violet point on the module rack as the
  family tell to `quality-recycler`; identity paint is the assembler family's blue, on the west
  half only, measured at 21% of the base sheet against AM3's 13.7% target.
- **Built from scratch, not deep-copied from `assembling-machine-3`.** A deepcopy carries a
  working sound, a status light and a connector positioned for a different machine.
- **Health 400, pollution 3, the recipe and the technology cost on both branches** — reasoning
  in `.ai-support/decisions.md`.

Sounds, a real remnant, the connector check and balance are open. See
`.ai-support/deferred.md`.
