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

## Which measurement does the 1.62x cap mean? — needs the owner

The owner capped the legendary discount at 1.62x. Measured two ways it is **1.57x** (odds only,
modules held constant, which is how it was measured when the cap was set) and **1.77x** (end to
end, what a player actually pays, which is the mod's own headline table). The difference is the
epic multiplier moving 1.9 → 2.0, which makes epic quality modules farm legendary faster; that
change predates the cap and was never counted against it.

Nothing was changed pending a ruling. If the cap means end to end, the odds come down to
roughly 1.3 / 1.2 / 1.05 and every cost number in `balance.md` moves with them. Both figures
are in `balance.md` under "Two ways to read the cap".

## `level` steps unevenly where `default_multiplier` does not

Levels run 0, 1, 2, 3, 5, 6, 8, so epic → legendary gains +2 of every *counted* bonus and
legendary → mythic gains +1: tool durability, equipment grid, pole supply area and wire reach,
accumulator capacity, flying robot energy, module slot bonuses. The owner's "no step smaller
than an earlier one" is therefore met on strength and not on these.

Levels 7 and 9 would make it +2, +2, +2 throughout, at the cost of a celestial substation
reaching 36x36 instead of 34x34. Left at 6 and 8 because the supply-area blowup is the more
visible problem of the two, but it is a real trade and only play settles it.

## Asteroid collector radius at celestial

`asteroid_collector_collection_radius_bonus` is not set on either new tier, so it defaults to
`level` — a celestial collector reaches 15.5 against legendary's 12.5, off a 7.5 base. The
prototype API carries a performance warning on exactly this field: the navigation pre-calculates
ranges for the highest tier collector *possible*, so the cost lands on every Space Age save the
moment the mod is installed, researched or not. Measure it before publishing, or set the field
explicitly on both tiers.

## Another mod adding a tier above legendary

`ladder.lua` assigns `legendary.next = "mythic"` unconditionally. A second mod doing the same
silently orphans one of the two tiers — reachable only by the chain skip, never by a normal
roll — and unlike a name collision this does not fail loudly. There is no good automatic merge,
but a guard that detects an existing `next` and logs would at least make it findable.

## The portal name is unchecked

`extra-qualities` has not been checked for availability on the mod portal. Pure Modules had to
become `pure-modules-realk` for exactly this reason. Check before any first upload.

## Is the mythic-to-celestial step too cheap?

Celestial costs 357–549 normal items where mythic costs 238–348 — a 1.5x step, the smallest on
the ladder, where the step below it is 2.0x and the ones below that run 2.5x to 4.1x. Gating it
(`mythic.next_probability` below 1) was measured and not taken. Left open because only play can
say whether the last tier feels earned; everything needed to decide is in `balance.md`.

## Should the retune be optional?

The mod changes vanilla's own odds for the first three steps and all five of its multipliers,
which is a bigger footprint than "two new tiers" implies, and some players will want the new
tiers without it. A startup boolean would
cover that. Left out deliberately for now — the repo's code style is to not add configuration
nothing asked for, and the retune is what makes the ladder land where the planets are, so a
mod with it switched off is a different design rather than the same one with a knob.

## Quality module 4

Considered and not taken. It would keep "time to the top tier" closer to vanilla's time to
legendary by raising the module ceiling rather than by retuning the odds. It was rejected
because it grows the mod past quality tiers into modules, and because it scales every step
equally rather than reshaping the curve — which is the thing the design rule in `balance.md`
actually needs. The costs it was compared against at the time were from a draft ladder and are
not quoted here; re-run `qsim.py` with a module-4 multiplier if the idea comes back.

## The 2.0 build has not been played either

Built and validated on 2026-09-10 — `legacy/2.0`, version 0.1.1, clean against base 2.0.77 with
Space Age, and dump-diffed against the 2.1 build. What the port does and why is in
`decisions.md`. What is *not* settled is the same thing as on 2.1: nobody has played it, and the
2.0 build has two behaviour differences a player would notice — no train bonuses above legendary
and no tier skipping — that only in-game time can judge.
