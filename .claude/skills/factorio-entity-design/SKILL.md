---
name: factorio-entity-design
description: Use when conceiving a new entity for a Factorio mod — a crafting machine, miner, beacon, turret, pole or anything else a mod will add — before any modelling, rendering or prototype code exists. Runs a staged design session against the target mod's own context and writes the result as a design document in the mod's .ai-support/. Use it when someone wants to design, invent or think up a machine or entity, or asks what a new machine should look like. It decides what the entity is and how it looks, not how it is coded — factorio-graphics builds the sprites from the document this produces, and factorio-mod-development writes the prototype afterwards.
---

# Designing a new entity

This skill runs the **conception session**: the conversation that turns "I want a new machine"
into a design document specific enough to model from. It ends where Blender begins.

```
factorio-entity-design   ->   <mod>/.ai-support/<subject>-design.md   ->   factorio-graphics
   (this skill: what it is,          the artifact, in the mod              (models, renders,
    what it looks like)              it belongs to                          exports sheets)
```

**Do not model, render, or open Blender here.** When the document is written and indexed, hand
off and stop.

`factorio-graphics/references/design-language.md` is the **schema** — it defines the eight
sections a design contains and the vanilla anatomy behind them, and it is not repeated here.
This skill is the **process** for filling that schema in with a human. Improvising the process
is how a design ends up as a box with pipes on it.

## The standing ambition: maximum legible complexity

Aim high — the audited vanilla range is 8–15 distinct kinds of functional detail on a production
machine, and a big entity is an assembly of plausible sub-machines rather than one shape scaled
up. A design that comes out simple is the thing to fix.

But complexity means **more distinct systems, not more stuff**; uniform density reads as noise at
gameplay zoom. The discipline that buys both is in `design-language.md` §Detail distribution.
The test to apply at every stage: **can the player say what this part is for?** A part with no
answer is decoration and gets cut, however good it looks.

## Session checklist

```
Entity design session:
- [ ] Phase 0: load the mod's context
- [ ] Phase 1: pin function and hard prototype constraints
- [ ] Phase 2: gather references
- [ ] Phase 3: the eight stages, one at a time
- [ ] Phase 4: write the document, index it, run the check, hand off
```

---

## Phase 0 — Load the mod's context

**Ask which mod this entity is for** if the user has not said. A design conceived without the
mod's house style has to be redone when it lands next to the mod's other machines.

Read `info.json` (does it depend on Space Age? that decides which machine families this entity
stands beside), the mod's `CLAUDE.md`, and then `.ai-support/index.md` — which names that mod's
registers. Two matter:

- **the art-direction register**, if there is one. This is the jackpot: the house style is
  already decided and the entity has to be designed *into* it. Read its rules sections; they are
  constraints, not suggestions.
- **the register that owns the mod's identity** — its tier or progression structure, and what is
  still open. Do not assume a filename: a large mod names registers for their concept, so
  `index.md` is what tells you which file that is.

Also skim any existing `<subject>-design.md` for house format, and check what art already exists.

Then say what you found in two or three sentences before asking anything. **If the mod has no
art direction, say so plainly** — this entity will set the house style by default, which is worth
doing deliberately.

## Phase 1 — Pin the function before the look

Wube prototype an entity with placeholder graphics and playtest it, and only then hold the art
meeting (FFF-146). An unsettled function produces art that expresses nothing.

Establish and write down:

- **What it does**, in one sentence a player would understand.
- **Where it sits** — which tier, what it supersedes, what stands next to it.
- **The hard prototype constraints**, which bind the art absolutely: footprint in tiles; fluid
  connection points (position and direction — these drove the entire fusion plant layout,
  FFF-420); whether it rotates, which forces an asymmetric business face; module slots, energy
  source, heat connections, each a visible fitting.

**If the function is not settled, that is the session.** Say so and settle it first.

## Phase 2 — Gather references

Three sources. **`references/reference-hunt.md`** has the lookup tables — how to read a vanilla
counterpart's real numbers, the FFF index, and a map from machine function to the real industrial
equipment that does that job.

1. **The vanilla counterpart**, on disk at the pinned version. Run
   `python scripts/counterpart.py <entity>` rather than sampling by hand.
2. **Prior art in `exemples/`** — how Krastorio 2 and Space Exploration solved it, including
   where they got it wrong.
3. **Real industrial equipment that does the analogous job.** This is the source people skip and
   the highest-value one: legibility comes from looking at a real rotary kiln or vacuum arc
   remelter, not from imagining one.

Report what you found before Phase 3. A reference the user has not heard cannot influence the
design.

## Phase 3 — The eight stages

The stages are `design-language.md`'s eight design-plan sections, in the order they stop being
answerable independently — silhouette before components, because components must fit inside a
shape; materials before wear, because wear is a map over zones. **Read that file for what each
section must contain.** What follows is only how to run the conversation.

**One stage at a time.** Each stage's options depend on the previous answer, so batching them
produces choices that contradict each other.

**Bring options, not blank questions.** "What should the silhouette be?" is unanswerable.
"Tiered tower like the foundry, open gantry like the radar, or squat with a tall stack?" is a
decision someone can make in five seconds. Two to four concrete options per stage, each
genuinely different rather than a variation, each with its trade-off stated.

**Propose a recommendation and say why.** You have read the mod's art direction, the counterpart's
real numbers and the references; the user has taste and the final call.

**Record each answer as you go**, so stage 6 can refer to stage 5's zones by name.

| # | Stage | What this stage is really deciding, and the failure mode to name |
|---|---|---|
| 1 | Function & hero | The one part that does the action, modelled first and oversized. Failure: no hero — every part equally important reads as a container. |
| 2 | Family | Which vanilla entity anchors it and what it quotes. **If the mod's art direction has tiers or a gradient, this is where it binds** — the entity's position decides its palette and wear before those stages are reached. |
| 3 | Silhouette | Decided before any detail; it does more identification work than every greeble combined. Failure: the bounding box (fills its tile, flat tray base) and plan view (all roof, no south wall) — the two tells that most reliably out a mod sprite. |
| 4 | Components — the four flows | Where the complexity ambition is actually spent. Push for all four flows visible; **human service** is the one most often missing and the one that makes a model read as equipment. Failure: a detail implying a mechanic the entity lacks (FFF-339). |
| 5 | Material zones | Four to six, named with colours. If the mod's art direction sets a palette or paint target for this tier, it decides this stage and you are only choosing within it — say so rather than re-opening it. |
| 6 | Wear map | Placed by physics, not sprayed on. If the entity lives where the ordinary physics does not apply — vacuum, extreme cold — say what replaces rust rather than leaving the surface clean. |
| 7 | Busy / calm | Names the dense hero zone and the calm hulls. This is what keeps stage 4's ambition from becoming noise, so do not skip it because the fun part is over. |
| 8 | State & animation | Active and inactive side by side. Motion reads effortful and mechanical; status glow stays small and local. If it rotates, how direction reads at a glance. |

For stage 4, prefer naming parts the render library already builds — that is cheaper than
inventing them, and the authoritative list is one call:

```
python -c "import sys; sys.path.insert(0, '.claude/skills/factorio-graphics/scripts'); \
           from factorio_render import parts; print(parts.catalogue())"
```

It returns both placement verbs' vocabularies — `place()` for parts defined by a centre,
`run()` for parts defined by a path — plus `polyhaven:<slug>`, any CC0 industrial model,
which `parts.py` imports and conditions for the material stack automatically. **A component
named from that list costs one line to build; one invented here costs an afternoon.** That is
worth knowing while choosing components, which is why it belongs in this stage and not in the
modelling one.

**It does not lower the bar for what a component must be.** A part still needs a stated
purpose, and being available is not a justification. Four kitbash iterations on 2026-08-30
assembled real CC0 machinery with no design behind it and produced, in order, props on a flat
slab, a scrap pile, and plumbing routed where the camera never sees it. Cheap parts raise the
ceiling on complexity; only this session raises the floor on coherence.

## Phase 4 — Write the document and hand off

The artifact is **`<mod>/.ai-support/<subject>-design.md`**. Copy `assets/design-doc-template.md`
and fill it in. (`pure-modules-realk/.ai-support/pure-beacon-design.md` is a finished example,
but most of its length is build detail added after the session — the template is what this phase
needs.)

Then, per the repo `CLAUDE.md` → *AI support folders*: write it in the same session, add its row
to that folder's `index.md`, and run `.claude/scripts/check-ai-support.ps1`. Staging new files is
fine; committing needs the owner's explicit ask.

**Record what the design does not settle** — balance numbers, prototype fields nobody chose,
anything deferred. Silence reads as a decision.

Then say the design is ready and that `factorio-graphics` builds it. Do not start.

## When this skill is the wrong one

- **The entity already has a design document and needs modelling or rendering** →
  `factorio-graphics`.
- **The prototype Lua needs writing** → `factorio-mod-development`. This skill decides what the
  entity is and looks like; it does not author `data:extend`.
- **The mod has no identity at all** and the real question is "what is this mod about" → that is
  a mod-level conversation, and its answer belongs in the mod's own register before any single
  entity is worth designing.
