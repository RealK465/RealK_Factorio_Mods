---
verified_against: 2.1.17
verified: 2026-09-10
---

# How the engine rolls quality

All three findings below are **measured** against the pinned dev install, by a throwaway probe
mod that calls `LuaQualityPrototype.get_roll_chances` from `on_init` under
`factorio.exe --create`. The probe is not kept; its output is quoted here because that is the
part worth not re-deriving. Anything on this page that is derived rather than measured says so
in those words; everything else is the probe's own output.

## The roll formula

For a source quality with `next_probability = np`, a chain of `chain_probability = cp` values,
and a machine quality effect `q`:

```
P(land on the next tier)      = min(1, q * np) * (1 - cp)
P(land two or more tiers up)  = min(1, q * np) * cp
P(stay put)                   = 1 - min(1, q * np)
```

Steps are hops along the `next` chain, **not** differences in `level` — epic to legendary is one
hop despite level 3 to 5.

## `next_probability` above 1 is legal and linear — **measured**

Nothing in `prototype-api.json` gives it an upper bound (only ">= 0"), and the engine treats it
as a plain multiplier on the machine's quality effect. This is what makes it the per-step
difficulty knob this mod's `prototypes/quality/ladder.lua` turns.

Measured at `quality_effect = 0.25`. **The probe ran against a draft ladder, not the one that
ships** — its `next_probability` values were 1.5 / 1.4 / 1.3 / 1.2 where the shipped ladder is
1.4 / 1.3 / 1.1 / 1 (see `../balance.md`). Keep the draft numbers here rather than re-running:
what is being measured is that the engine multiplies linearly, and five distinct values above
1 demonstrate that better than three do.

```
  normal     np=1.5  stay=0.625000  up=0.337500  beyond=0.037500
  uncommon   np=1.4  stay=0.650000  up=0.315000  beyond=0.035000
  rare       np=1.3  stay=0.675000  up=0.292500  beyond=0.032500
  epic       np=1.2  stay=0.700000  up=0.270000  beyond=0.030000
  legendary  np=1    stay=0.750000  up=0.225000  beyond=0.025000
  mythic     np=1    stay=0.750000  up=0.250000  beyond=0.000000
  celestial  np=0    stay=1.000000  up=0.000000  beyond=0.000000
```

Every row matches the formula above exactly: `0.25 * 1.5 = 0.375`, times `1 - 0.1` for the
next tier and times `0.1` for beyond it. The cost model in `../balance.md` uses the same
arithmetic, which is why its numbers rest on a measured formula rather than an assumed one.

For the shipped values, the same formula gives `up` of 0.315 / 0.2925 / 0.2475 / 0.225 at
`quality_effect = 0.25`. **Derived from the measurement above, not separately measured.**

The last row is the terminal quality: no `next`, so `next_probability` defaults to 0 and the
roll always stays.

## A locked tier folds its probability up, it does not lose it — **measured**

A quality the force has not researched is never produced, and the probability that would have
gone to it is added to the highest quality that *is* unlocked. With legendary as the cap, epic
at `quality_effect = 0.25`:

```
  epic       0.700000
  legendary  0.300000
```

`0.27` for legendary plus the `0.03` that would have continued past it. So the two new tiers
being researched later costs nothing while they are locked — a player without `mythic-quality`
gets *slightly more* legendary than they otherwise would, not fewer items.

This is what makes gating the tiers by technology the whole mechanism: no other guard is needed
to stop a celestial item appearing on Nauvis.

## Things checked but not measured here

- **That a real crafting machine follows `get_roll_chances`.** The documented API was measured,
  not a machine's output over time. The API is documented as *the* roll, so this is a strong
  inference rather than an observation.
- **Whether any GUI other than the machine's quality selector honours
  `quality_selector_dropdown_threshold`.** The constant's value and that a mod override sticks
  were both confirmed; the visual result in the filter and logistic-request GUIs was not, and
  needs a graphical run.
