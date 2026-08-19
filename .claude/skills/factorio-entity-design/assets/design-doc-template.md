# <Entity name> — design notes

<!--
Copy this into <mod>/.ai-support/<subject>-design.md, fill it in, delete these comments,
and add a row for it in that folder's index.md. Genre: subject design — edited freely as
the entity evolves, unlike a register (never annotated) or a journal (never edited).

pure-modules-realk/.ai-support/pure-beacon-design.md is the worked example of a finished
one. It is longer than this because it accumulated build detail after the design session;
what this template covers is what should exist BEFORE any modelling.

Every section appears even when empty. A section that is genuinely empty says why — a gap
that is named can be filled later, a gap that is silent gets discovered in Blender.
-->

One or two sentences: what this entity is and where it sits in the mod. Then say which
document governs it — the mod's art direction register, if it has one — so a reader knows
which rules already bind before they read a word of this.

## Function & constraints

What it does, in a sentence a player would understand. Then the hard prototype facts the art
has to satisfy, because these are not negotiable later:

| | |
|---|---|
| Footprint | N x N tiles |
| Fluid connections | positions and directions, or none |
| Rotatable | yes / no — if yes, what reads the direction |
| Module slots | count, or none |
| Energy | electric / burner / heat / none |
| Tier or act | where it sits in the mod's progression |

## Lore anchor

*Optional, but it is what stops the material choices being arbitrary.* Where the entity comes
from and what it is made of — the beacon is built out of what Aquilo is made of, and every
palette choice resolves against that. State what each visible element **is not**, if there is
a reading worth ruling out: the crystal is not a gem, the rings are not decoration.

## Hero & family

**Hero:** the single working part that does the action. It takes the visual budget, is modelled
first, and is modelled oversized.

**Family:** which vanilla entity anchors it and what it quotes — proportions, a shared fitting,
a colour with a meaning. If the mod's art direction assigns this entity to a tier or act, name
it here; it is what decides the palette and wear sections below.

## Silhouette

Describe it at thumbnail size. What breaks the outline and on which sides — at least one tall
element and one low one. Where the tall mass sits, what the front elevation shows, whether the
construction is solid or open-frame, total height in tiles, and how it is anchored to the
ground.

If the entity tiles in rows, say whether the frame stays visually open, so a field of them does
not wall off the factory behind.

## Component list — the four flows

Every part, each with a purpose.

| Flow | Parts |
|---|---|
| Power in | |
| Material through | |
| Heat out | |
| Human service | |

**Cut deliberately:** anything that would imply a mechanic the entity does not have.

## Material zones

Four to six, numbered, each named with its colour and where it is allowed to go.

1.
2.
3.
4.

**Emissives**, with the semantic accent named and its hue band stated.

## Wear map

Where each kind of wear goes, and why — placed by physics, not sprayed on.

If the entity lives somewhere the ordinary physics does not apply — vacuum, extreme cold — say
what replaces rust. Never leave the answer "it is clean".

## Busy / calm

The one dense hero zone, and the calm zones that set it off and carry only seams, rivets and
wear. Say explicitly what is kept low so the hero is never occluded.

## State & animation

Idle versus working, described side by side. What moves, what glows, and how the loop closes.

| Element | Per loop | Why it loops |
|---|---|---|

Motion should read as effortful and mechanical. Status glow stays small and local. If the
entity rotates, say how direction reads at a glance.

## Not settled

Everything the design deliberately leaves open — balance numbers, prototype fields nobody chose,
anything deferred. Silence reads as a decision, so name the gaps.
