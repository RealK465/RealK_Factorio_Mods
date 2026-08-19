# Space Forge — art direction

Register: **the house style — what the machines look like.** Edited in place; when a rule
changes, rewrite it here rather than annotating, and append the story to `journal.md`.

Covers **both** mods of the pair: this file decides what the art looks like,
`../../space-forge-graphics/CLAUDE.md` decides where the files live. Never ships (leading dot).

**What this file does not own.** It says nothing about tiers, unlocks, recipes, science or
content — those are progression questions, they are not decided, and `identity.md` names the
register each of them becomes. An earlier draft of this file carried a four-act structure and
was quietly designing the mod's progression under cover of describing its art. That is removed.
What is left is a **visual gradient**: how a machine looks as it gets more advanced. It applies
however many tiers the mod turns out to have.

**Read `../../.claude/skills/factorio-graphics/references/design-language.md` first.** It is the
measured anatomy of a vanilla entity and is not repeated here. This file records only what is
specific to Space Forge — which of vanilla's axes we match, which we depart from, and why.

---

## The brief this implements

Settled by the repo owner; the rest of this file is the working-out.

- An overhaul of Space Age, positioned as Krastorio 2 is to base Factorio.
- **The game opens with very simple machines and ends with very powerful ones.**
- **Some vanilla art is replaced with custom art**, the miner line first.
- Machines should be **as complex as they can legibly be**.

## The gradient: three anchors, not a tier list

Machines get more advanced, and the art has to say so at a glance. Three anchors describe the
continuum. **They are not tiers** — how many tiers the mod ships, and what unlocks them, is a
progression question nobody has answered. A machine is placed on the continuum by how advanced
it is, and the numbers below interpolate between the anchors.

| Anchor | The machine reads as |
|---|---|
| **Crude** | *I am burning something* |
| **Industrial** | *I am making heat* |
| **Exotic** | *I am holding heat with nothing* |

### The through-line: the vessel disappears

This is what holds a coal-fired steam miner and an exotic forge in one family: they are the same
act — contain the fire, feed it, shape what comes out — performed with steadily less to contain
it with.

**Crude is a solid box. Exotic is a frame around a void.** Everything between opens up a little
more. That makes it a *silhouette* rule rather than a story: two machines from different points
on the gradient are distinguishable at thumbnail size with no colour information at all, which
is the job design-language.md says the silhouette must do.

It also runs with Wube's own trajectory rather than against it. The `factorio-graphics` skill
records "confident negative space" and "emissive as protagonist" as the Space Age evolution;
this extends that same line rather than inventing a grammar.

### What each anchor looks like

**Crude** — the filthiest, most hand-made thing in the mod. Power arrives as steam and leaves as
motion: exposed flywheels, drive belts, line shafts, lagged steam pipes, brass gauges. Hero is
the firebox door and its grate, glowing through the gap. Squat and wide, one tall stack breaking
the outline, a low hopper breaking it on the other side, riveted plate throughout. Firebrick
red-brown, cast iron grey-black, brass fittings, soot. Emissive: **ember orange, 10–20 deg** —
deliberately the same band as the vanilla foundry, because at this level the machine *is* just
burning coal and looking vanilla is correct. The mod earns its own colours further up.

**Industrial** — the vessel opens; heat stops being fuel and becomes a product of electricity.
Hero is the electrode arms and the arc gap between them, visible from the front. Taller and
gantried, bus bars breaking the roofline, first appearance of open frame. Graphite grey, copper
bus, galvanised steel, one desaturated identity paint. Emissive: **arc white** — near-white, very
low saturation, high value. That separates from both the vanilla foundry (saturated orange) and
the electromagnetic plant (saturated cyan) by *saturation* rather than hue, so it collides with
neither.

**Exotic** — must look like nothing else in Factorio. Hero is the process itself, uncontained:
a glowing mass held in an open bore between coil rings, with no crucible. Silhouette dominated by
**radiator fins** fanning past the footprint, and a centre that is a void with light in it. Bare
and unpainted: steel, titanium grey, gold thermal foil, black windings. Emissive: **violet,
290–310 deg** for the process, with **deep cherry red, 0–10 deg at low value** on the radiators
for waste heat — the process glows cool, the waste glows warm. Warm-against-cool pairing is a
standing vanilla habit.

---

## The rules

### 1. Paint decreases as emission increases — and it is checkable

Measured off the shipped 2.1.14 sprites (`analysis/vanilla-palette.md` §1), base-game entities
carry 13.7–44.7% painted pixels and Space Age entities carry **0.1–1.7%**. Space Forge continues
that line in both directions:

| Anchor | Non-rust painted pixels | Compares to |
|---|---|---|
| Crude | 20–35% | more painted than anything in vanilla |
| Industrial | 10–15% | base-game assembling machine 3 (13.7%) |
| Exotic | 1–3% | Space Age foundry / crusher (1.7 / 1.0%) |

Anything beyond exotic goes below 1%. Machines between two anchors interpolate.

This is a **gate, not a mood**: it is the same measurement `analysis/vanilla-palette.md`
describes, and `.claude/skills/factorio-entity-design/scripts/counterpart.py` computes it for any
sprite. A late machine that comes out colourful has failed a number, not a taste test.

The inverse holds too — emissive area grows along the gradient. The crudest machines glow through
a crack; the most advanced are mostly glow.

### 2. The violet rule

**Violet, 290–330 deg**, is the mod's own colour and is saved for the top of the gradient. No
crude or industrial machine, item icon or technology icon uses it. Its entire value is that it
appears only when the player reaches the most advanced machines in the game, and that value is
destroyed by spending it early for decoration.

Three bands are already spoken for, all measured (`analysis/vanilla-palette.md` §3): warm
0–45 deg, where four of six vanilla accents sit — which is why the mod cannot be identified by
orange however well it would suit a forge; cyan 195–210 deg, the electromagnetic plant's; and
**magenta 330–345 deg, the fusion reactor's**. That last one was an open question in the first
pass and the answer came back taken, which is why the band above stops at 330 rather than 345.

### 3. Wear is keyed to environment, not to advancement

A machine's wear map comes from where it *lives*, which is a separate axis from how advanced it
is. Space Age already ships both environments, so both rules apply regardless of what the
progression turns out to be.

**In atmosphere** — vanilla's own map, unchanged. Edges and protrusions chip to bare metal and
stay cleaner; crevices and skirts pool grime; heat exits get soot; mechanisms streak oil below
them; feet and flanges rust. The crudest machines carry the heaviest version of this: coal soot
above every opening, ash spill at the feet, slag crusted at the pour lip.

**In vacuum — nothing rusts.** Rust needs oxygen and free water and a vacuum has neither, so the
oxide-orange substrate that every vanilla entity shares is simply absent.

**This is the most dangerous rule in this file.** design-language.md lists showroom-clean surfaces
as the number one tell of amateur mod art, and "no rust" is one lazy step from "no wear". The rule
is **differently worn, never clean**:

- **Micrometeorite pitting** — tiny bright craters punched through paint to clean metal, on
  sun-facing and forward-facing plates only.
- **UV bleaching** — asymmetric, on one side only. Nothing in vacuum weathers evenly, because
  nothing turns around.
- **Thermal-cycle crazing** — fine crack networks at weld lines and panel joins, from the
  sunlight/shadow swing.
- **Regolith dust** — grey, not brown, at intakes and in crevices.
- **Scorch** at radiator roots and around vent exits.

Wear is still a map of use, exactly as in vanilla — only the physics generating the map changed.

### 4. Match vanilla's grammar; depart only where the theme pays for it

Space Forge sits *inside* a Space Age game, so its machines stand on the same belts as vanilla's
and are judged next to them. Everything in design-language.md's greeble vocabulary, silhouette
rules and wear discipline applies unchanged.

There are exactly three sanctioned departures, each earned by the theme rather than by preference:

1. **The vessel gradient** — solid to open as machines advance.
2. **The vacuum wear map** — pitting and bleaching instead of rust, wherever there is no air.
3. **The violet band** — reserved for the top of the gradient.

Anything else that differs from vanilla is a mistake, not a style. In particular, do not repeat
the tells design-language.md pins on Krastorio 2 and Space Exploration: bounding-box silhouettes,
near-plan-view renders with no front elevation, and large saturated colour fields with no
compensating wear.

### 5. Complexity is the ambition

Machines should be as complex as they can legibly be. The greeble range, the busy-against-calm
discipline that keeps density from becoming noise, and the can-the-player-say-what-it-is-for test
are general vanilla design language and are unchanged here — `design-language.md` §Greeble
vocabulary and §Detail distribution. What is specific to Space Forge is only that the ambition
sits at the top of that range rather than the middle.

### 6. What gets custom art, and what does not

An overhaul's art bill is what kills it. The rule that keeps this survivable:

- **Custom art is spent on a new tier or a new family, never on a re-skin.** If a machine's job
  and position on the gradient match a vanilla machine's, it keeps the vanilla sprite.
- **Vanilla machines that survive the overhaul keep vanilla art.** They are already the best art
  in the mod and they cost nothing.
- **A machine that gets custom art gets the whole set** — base, shadow, animation, status light,
  icon, remnants. A custom body with a borrowed shadow reads worse than an untouched machine.
- Every path is `__space-forge-graphics__/graphics/...`; sources live outside both mod folders
  under the repo's assets tree. `../CLAUDE.md` carries both rules.

### 7. Build order

Art is built in the order the player meets it, so whatever is finished at any moment is a playable
opening rather than a disconnected endgame.

1. **The miner line at the crude end** — the owner's chosen starting point, and the first machine
   a player ever sees.
2. The rest of the opening: smelting, then power.
3. Onward along the gradient, same order each time — extraction, then smelting, then power.

Design each entity through the `factorio-entity-design` skill, which writes a
`<subject>-design.md` here before any modelling; `../../pure-modules-realk/.ai-support/pure-beacon-design.md`
is the worked example of a finished one.

## Hard constraints

Camera, scale, lighting, colour management, layer split, the paint-over pass and the vanilla A/B
gate are the `factorio-graphics` skill's, unchanged — read them there. **Nothing in this file
overrides any of them**, and none of their values are repeated here: several carry a trap that
travels with the number (the sun's Y rotation is the documented example, where the community
value has the sign backwards), and a copy keeps the number while losing the warning.

## Not settled

- **Where the gradient's anchors actually land in the game.** That is progression, it is
  undecided, and it belongs in a **progression.md** when it is — not here.
- **Whether any vanilla machine gets re-arted** rather than merely replaced in the recipe tree.
  The owner has asked for custom miners; nothing beyond the miner line is decided.
- **Machine naming.** None chosen.
- **Icons.** The gradient is defined for entities; whether it reads at 64 px icon scale is
  untested, and `../../.claude/skills/factorio-graphics/references/icons.md` says most entity
  rules do not carry over.
- **Terrain contrast.** Everything above separates from vanilla on paper. None of it has been
  checked against Nauvis dirt, Vulcanus basalt or a space platform floor, which is the only test
  that counts.
- **Sound.** The graphics mod is specified to hold sounds too; nothing about them is decided.
