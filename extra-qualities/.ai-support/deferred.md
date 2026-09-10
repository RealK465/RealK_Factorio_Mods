# Open — Extra Qualities

Open questions and parked work. Edited in place; an answered item moves to the register that
owns it and is deleted here.

## Nothing has been played — the largest item on this list

The data stage loads clean, the roll mechanics are measured and the cost model is checked
against the engine, but **no part of this mod has been in a running game.** In particular:

- The technology counts (5000 / 5000 / 7500 / 10000) are a guess. The pack lists are the real
  gate and they are sound; the numbers beside them are not evidence of anything.
- Whether mythic-on-Aquilo *feels* like legendary-on-Aquilo is a play question, and the cost
  table in `balance.md` only says the material maths works out.
- The icons have been compared against vanilla's numerically and by eye at 40 px, but never
  seen in a technology tree or on an item.

## The portal name is unchecked

`extra-qualities` has not been checked for availability on the mod portal. Pure Modules had to
become `pure-modules-realk` for exactly this reason. Check before any first upload.

## Is the mythic-to-celestial step too cheap?

Celestial costs 275–421 normal items where mythic costs 182–265 — a 1.5x step, the smallest on
the retuned ladder, which otherwise runs 1.8x–1.9x. Gating it (`mythic.next_probability`
below 1) was measured and not taken. Left open because only play can say whether the last tier
feels earned; everything needed to decide is in `balance.md`.

## Should the retune be optional?

The mod changes vanilla's own odds for four tiers, which is a bigger footprint than "two new
tiers" implies, and some players will want the new tiers without it. A startup boolean would
cover that. Left out deliberately for now — the repo's code style is to not add configuration
nothing asked for, and the retune is what makes the ladder land where the planets are, so a
mod with it switched off is a different design rather than the same one with a knob.

## Quality module 4

Considered and not taken. It would keep "time to the top tier" closer to vanilla's time to
legendary by raising the module ceiling rather than by retuning the odds, and it lands celestial
at 200–620 instead of 423–652. It was rejected because it grows the mod past quality tiers into
modules, and because it scales every step equally rather than reshaping the curve — which is
the thing the design rule in `balance.md` actually needs.

## A 2.0 build

Not started, and cheap when it is wanted: the whole mod is five small prototype files. Two
things would need forking on `legacy/2.0` — `info.json`, and whatever the pre-2.1 quality-effect
scale does to `next_probability`.

**`info.json` has a second reason to fork now: the `+` recommended-dependency prefix is 2.1
only.** 2.0 has no such concept, so the 2.0 build has to drop `+ upcycler-planner` or downgrade
it to `?` (plain optional). Getting this wrong is the usual kind of silent: an unrecognised
prefix is not a loud failure. The 2.1.7 rescale divided quality effect values by ten and
multiplied `next_probability` by ten to compensate, so the values in `ladder.lua` are 2.1
numbers and mean something different on 2.0. Verify against the 2.0 install rather than
scaling by eye. Also unverified there: whether 2.0's core defines
`quality_selector_dropdown_threshold` at all.
