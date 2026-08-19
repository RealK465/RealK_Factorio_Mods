# Reference hunt — where the design's raw material comes from

Read during Phase 2 of `SKILL.md`. These are lookup tables, not a process — pull what the
entity being designed actually needs and skip the rest.

## Contents

- The vanilla counterpart — the numbers, and how to get them right
- The FFF index — which post explains which design decision
- Prior art in `exemples/`
- Real industrial equipment — the function-to-machine map
- Licensing hygiene for reference material

---

## The vanilla counterpart — the numbers, and how to get them right

Every new entity has a nearest vanilla relative, and that relative is on disk at the pinned
version. It settles size, palette, greeble density and layer structure without a single
judgement call.

**Run the bundled script rather than sampling by hand:**

```
python .claude/skills/factorio-entity-design/scripts/counterpart.py foundry
```

It lists every layer with its kind and size, then reports the fraction of pixels carrying
identity paint versus the rust substrate, and the dominant hue of each emissive layer. It
deliberately does not measure drawn size against footprint — `factorio_render.vanilla`'s
`area_vs_footprint` does that properly, compositing layers at their prototype shifts, and a
second implementation here would give a second, disagreeing answer.

How to read the paint number: base-game entities run 13.7–44.7%, Space Age entities 0.1–1.7%.
Space Age identity lives in the emissive layer over a dark rusted hull, so a new entity's
paint fraction should be placed on that scale deliberately rather than by eye.

The hand-rolled version of this is a trap worth understanding, because it has produced wrong
answers twice in this repo. Sampling the **modal hue** of a machine reports that every entity in
Factorio is orange — including the blue assembling machine 3 — because the oxide and grime
substrate outnumbers the paint on almost every sprite. The statistic that means something is
"fraction of opaque pixels whose hue falls *outside* the rust band", which is what the script
computes. A flat-index pixel stride is the second trap: it aliases onto a fraction of the
sprite's columns, so it looks thorough while sampling an eighth of the width.

**Also read on disk**, which no script replaces:

- The prototype itself in `data/base/prototypes/entity/` or `data/space-age/prototypes/entity/`
  — footprint, fluid boxes, energy source, module slots, the real layer list.
- The sprite PNGs beside it. Open the counterpart and the entity that stands next to it in game;
  greeble density is judged by eye and only by eye.

## The FFF index — which post explains which design decision

Wube's own artists explaining their actual reasoning. Fetch the ones relevant to the entity being
designed; the URL pattern is `https://factorio.com/blog/post/fff-<number>`.

`design-language.md` already cites FFF-146, 195, 210, 218, 301, 320, 339, 350, 378, 420 and 432
**with the specific claim each one supports** — read them there rather than re-deriving what they
say. Fetch a whole post when designing something the same shape as its subject: 339 for a utility
entity that tiles in rows, 350 for anything that digs, 420 for a large assembly driven by fluid
connections, 432 for an entity on a frozen world.

These are the ones that reference does *not* cover:

| Post | Subject |
|---|---|
| **FFF-373**, **FFF-417**, **FFF-438** | how Space Age planets were themed, developed and wrapped up |
| **FFF-437** | a full deep dive on one entity's design, start to finish (cargo pod) |
| **FFF-442** | machines as assemblies of sub-machines, and the fresh-paint pass |
| **FFF-77**, **FFF-162** | theme art |

## Prior art in `exemples/`

The reference collection holds extracted copies of the mods worth comparing against. Read them
for how a problem was solved, never to copy assets.

- **`exemples/factorio-official/`** — vanilla base and core plus all four 2.1 expansions.
- **`exemples/krastorio2/`** — the closest comparison for a tier-above-vanilla overhaul, and the
  source of two documented failure modes: bounding-box silhouettes that fill the tile edge to
  edge with a flat tray base, and large saturated colour fields with no compensating wear.
- **`exemples/space-exploration/`** — the other big overhaul, and the source of a third:
  detail spread evenly across a sprite until it turns to noise at gameplay zoom.

Being able to point at *why* these read as mod art is more useful to a design conversation than
any positive example, because the user can then say "not that" about something concrete.

## Real industrial equipment — the function-to-machine map

The standard `design-language.md` sets is **legible industrial equipment**: a viewer can
reconstruct what the machine does. That legibility comes from looking at real equipment, which
has visible reasons for every part — a real machine's hopper is where it is because material
falls, and its walkway is where it is because someone has to reach the valve.

Start from what the entity *does* and search for the real machine that does it. Bring back two
or three specifics — a named sub-assembly, a characteristic proportion, where the operator
stands — rather than a general impression.

| The entity's job | Real equipment worth looking at |
|---|---|
| Smelting, refining metal | blast furnace, electric arc furnace, induction furnace, cupola, converter vessel |
| Casting, forming | continuous caster, ladle and tundish, rolling mill stand, forging press |
| Crushing, grinding | jaw crusher, cone crusher, ball mill, SAG mill, roller press |
| Mining, extraction | bucket-wheel excavator, roadheader, longwall shearer, rotary drill rig |
| Chemical processing | fractionating column, reactor vessel, heat exchanger bank, scrubber tower |
| Separation | centrifuge, cyclone separator, froth flotation cell, electrostatic precipitator |
| Drying, roasting, calcining | rotary kiln, fluidised bed reactor, autoclave |
| Electrolysis | Hall-Heroult pot line, electrolytic cell room, chlor-alkali membrane cell |
| Power generation | steam turbine hall, generator set, transformer bank, cooling tower |
| Fluid handling | centrifugal pump skid, manifold, surge tank, pig launcher |
| Agriculture, biology | combine harvester header, greenhouse rack, fermenter, bioreactor |
| Vacuum and space | vacuum arc remelter, cryostat, deployable radiator panel, solar concentrator |
| Assembly, fabrication | robotic cell, transfer line, pick-and-place gantry, CNC enclosure |

Two habits that make this pay off:

- **Ask what each part is for, not what it looks like.** "A cyclone separator is a cone because
  the spiral flow drops heavy particles out of the bottom" gives you a shape *and* a reason, and
  the reason is what makes it survive into the design.
- **Look for the human-service furniture.** Real equipment is covered in ladders, inspection
  hatches, gauge panels, lockout switches and warning placards, and this is exactly the flow
  most often missing from mod art.

## Licensing hygiene for reference material

Reference is for looking at, not for shipping.

- **Never trace, copy or composite a photograph or another mod's art into a sprite.** Study the
  arrangement and the reasoning, then model it.
- **Do not commit downloaded reference.** If images are pulled during a session, keep them in the
  scratchpad. The repo's own rule for a mod's `.ai-support/` already ignores `*.jpg` and `*.png`
  inside it, which is the escape hatch when a reference genuinely has to persist locally.
- **CC0 texture and HDRI sources are a different thing** and are handled by
  `factorio-graphics/references/materials.md` — Poly Haven and ambientCG, with cached downloads
  outside the mod folders. That is material for rendering, not reference for designing.
