# Open and deferred work — the design, in full

A running list of everything not yet decided or deliberately left out, each with enough context
to pick up cold. `decisions.md` holds what is settled; `analysis/` holds the evidence;
`journal.md` holds what happened; this holds the "not yet".

Add to this list whenever something is cut for scope. **Move an entry into `decisions.md` when
it is settled** — an entry does not live in both — and say so in `changelog.txt` if a player
would notice.

**As of 2026-08-27 the entire design is here.** The mod is a scaffold: identity is settled and
nothing else is. That is the expected state, not an oversight.

## The design questions

### How many tiers, of which kind
**Status:** open, and the first thing that has to be answered.

Vanilla has one logistic robot and one construction robot. Everything downstream — the tech
tree, the recipes, whether vanilla's two are retuned — depends on this, so it is answered first
and the rest follows. Three shapes worth weighing:

- **Two above vanilla, both kinds** (four new prototypes). Matches the mod's own name and the
  belt/inserter progression a player already reads as normal.
- **One above vanilla, both kinds** (two new prototypes). Cheaper, and leaves the endgame robot
  feeling like an endgame item rather than a step.
- **Asymmetric** — construction robots gain a tier that logistic robots do not, or vice versa.
  Defensible: the two do genuinely different jobs and hit different ceilings. Harder to explain
  to a player, and doubles the balance surface.

The mod's name promises a *rework*, so "add tiers and change nothing else" is the shape most at
odds with the title.

### What separates one tier from the next
**Status:** open, and constrained by a measured fact before it starts.

The obvious axes are speed, cargo, battery and energy cost. **The constraint is that
worker-robot research is force-wide** — `worker-robot-speed` and `worker-robot-storage` lift
*every* robot the force owns, so at maxed research a tier that only has a bigger base number
has quietly become the same robot in a different colour. The two fields that survive research
are `max_speed` and `max_payload_size_after_bonus`, both caps that include bonuses. Measured
values and the exact semantics: `analysis/vanilla-robots.md`.

That points at a real design choice rather than a numbers exercise: a lower tier can be given a
*low* cap, so research fills it up and then stops, and buying the next tier is what raises the
ceiling again. Whether that reads as an upgrade or as a nerf to the vanilla robot is the open
question, and it is entangled with the retune entry below.

Energy is the other axis with teeth. `max_energy`, `energy_per_move` and `energy_per_tick`
decide how far a robot flies between charges, and charging — not flight — is the real bottleneck
in a large network. A tier that flies further per charge is felt immediately; see the roboport
entry.

### Whether vanilla's two robots are retuned, and how much
**Status:** open. Affects existing saves, so it is also a changelog and possibly a settings
question.

Adding tiers on top of unchanged vanilla robots is the safe shape and the least interesting one.
Retuning vanilla's two — capping them, slowing them, making them cheaper — is what makes this a
*rework*, and it is also what changes the balance of a save a player is already mid-way through.

Three things to settle together: whether it happens at all, whether it hides behind a startup
mod setting (the repo's rule of thumb: a silent balance override is worth a setting), and what
the `changelog.txt` entry says. The code goes in `data-updates.lua` either way — vanilla's
robots do not exist before base's own `data.lua` has run.

### Where the tiers sit in the tech tree
**Status:** open, and complicated by Space Age being optional.

A tier needs prerequisites and a science cost, and the mod supports both vanilla 2.1 and Space
Age (`decisions.md`). Vanilla's own robot line runs `robotics` → `worker-robots-speed-1..6` on
base science, with Space Age adding `worker-robots-speed-7` behind the electromagnetic science
pack. So a tier priced in Space Age science is unreachable in vanilla, and a tier priced in base
science is trivially cheap in a Space Age game.

The available answers are the usual three: price in base science only, price in base science and
add a Space Age-gated tier above it behind a `feature_flags` branch, or fork the cost by flag.
No flag is declared and none should be (`decisions.md`) — the branch reads `feature_flags`, it
does not declare one.

### Roboports
**Status:** out of scope so far, and arguably the more interesting half of the problem.

Charging is the binding constraint on a large robot network, not flight speed: a roboport has a
fixed number of charging pads and every robot in range queues for them. A robot-tier mod that
never touches roboports has improved the half of the system that was not the bottleneck.

Deliberately parked rather than dismissed, because it roughly doubles the mod: a roboport tier
needs a real 4x4 sprite (a recolour will not pass), its own logistics and construction radii,
and a charging-rate decision that interacts with every robot tier above. Revisit once the robot
tiers exist and can be played.

### Quality
**Status:** open, and **not measured**.

Space Age quality applies to placed entities, and a robot is an item that becomes an entity — so
a legendary construction robot presumably exists. What quality actually scales on a flying robot
(health only? speed? payload?) has **not been checked against the engine**, and the answer
matters: if quality already scales the same numbers a tier would, then tiers and quality are
competing for the same design space and the tiers have to be about something else.

Measure this before the tier axes are fixed. It belongs in `analysis/` with its version once it
is known.

### Compatibility with existing robot mods
**Status:** open, and worth a survey before any prototype is written.

Robot-tier mods are a well-populated genre on the portal, and several are long-established. Two
questions: what the existing ones actually do (so this one is not a fourth copy of the same
idea), and whether loading alongside one produces a broken tech tree or merely a redundant one.
Nothing has been surveyed yet — `exemples/` holds no robot mod, so this is a portal-and-web
pass, and its result belongs in `analysis/` as a reference-mods note.

## Assets and presentation

### Real art for the new tiers
**Status:** deferred on purpose; a tier ships wearing the vanilla sprites of the robot it
succeeds (`decisions.md`).

A flying robot is not a cheap sprite: idle, in-motion, and both again with cargo, each with its
own shadow, plus a `dying_explosion` and remnants. Real art is a `factorio-graphics` project of
its own and is not a prerequisite for a playable mod. A tint pass over the copied sprites is the
obvious middle step and was not taken either — it is a real piece of work on a `RotatedAnimation`
with layers, not a one-line field.

### `thumbnail.png`
**Status:** missing. 144x144 at the mod root, required by the new-mod checklist and shown in the
in-game mod browser and on the portal.

Blocked on the art question above only in the sense that a thumbnail wants something to show. It
is cheap to produce ahead of the sprites and should not wait for a release.

### `faq.md`
**Status:** none, and none needed yet. `upcycler-planner` carries one because it has behaviour
players ask about; this mod has none. Add it if the portal thread starts repeating itself.

## Tooling

### The test suite
**Status:** none yet, and expected from the first prototype.

The shape is settled by the repo rather than by this mod — `factorio-testing` skill, with
`upcycler-planner`'s `tests/` as the reference. What is specific here: the tier table is pure
data, so the host-interpreter tier can check every tier's shape (names prefixed, numbers
monotone across tiers, no missing field) in under a second, and the in-game tier is what proves
the prototypes actually loaded and the tech tree connects.

The empty `tests/` and `prototypes/` folders in the working tree are scaffolding and are
invisible to git until they hold a file.

### Mod settings
**Status:** none defined, and `settings.lua` deliberately not created.

The one candidate so far is a startup toggle for the vanilla retune, above. Do not add a setting
before the thing it toggles exists.
