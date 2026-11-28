# CLAUDE.md — Assembly Planner

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

A planner in Upcycler Planner's tradition, for bot malls: the player picks an item, and the mod
designs one mall cell — the crafting machine and its modules, an inserter row under it feeding
from requester chests and handing finished items to passive providers, more pairs up the sides
when one inserter cannot keep up, optional beacons beside and above it, a pipe row behind it for a fluid recipe, an optional pole — and hands it over as
a blueprint.

**Published** since 2026-11-25: 0.1.0, and 0.2.0 on 2026-11-28, for Factorio 2.1. Run the
`factorio-release` skill's "Published or open?" check rather than trusting a number here —
`git tag -l 'assembly-planner_*'` is what has shipped. Nothing has been played in a real save; the suite and
the probes are all the evidence there is (`.ai-support/journal.md`).

## The five technical facts worth not re-deriving

**1. The plan becomes a blueprint; the engine builds it.** Upcycler Planner's model and its
measurements (its `.ai-support/analysis/api.md` §21): the mod handles no placement event.

**2. A blueprint's `bar` counts open slots.** `bar = 2` leaves two slots; the runtime's
`get_bar` reads 3 for it. Measured both ways: `analysis/api.md` §1.

**3. The pipe row is north of the machine, and the machine turns to meet it.** Vanilla machines
stand north (AM3, chemical plant), east (EM plant) or south (foundry, cryogenic plant);
`proto.fluid_rotation` computes it per prototype from Upcycler Planner's rotation rule. Measured
live per machine: `analysis/api.md` §3.

**4. One pass, no validator.** `plan.build` resolves, refuses and builds in a single function,
returning a plan, `nil` plus a message, or `nil, nil` before an item is picked. Anything that
can fail must refuse there with a message — never throw.

**5. An inserter's round trip is `2 * (ceil(0.5 / rotation) - 1)` ticks**, `rotation` from
`get_inserter_rotation_speed` at its quality; quality never changes the hand. Measured to the
tick at normal and legendary for the inserter, fast, bulk and stack inserters into a chest, and
the first three into a machine: `analysis/api.md` §7.

**`.ai-support/` is this mod's local context — start at its `index.md`.**

## Dependencies

`["base >= 2.1.0"]` and no feature flags: the mod needs nothing from an expansion. Validate both
branches (`validate.ps1` plain and with `-Disable space-age,quality,elevated-rails,recycler`).

## Layout

```
data.lua                  requires the shortcut, the two custom-inputs and the toggle's sprite
data-final-fixes.lua      moves the shortcut's gate to the technology gate.lua names
settings.lua              one per-player setting: show unresearched items
control.lua               lifecycle and event wiring only, plus the test guard
prototypes/planner/       shortcut, custom-inputs (hotkey, linked confirm), icons, gate.lua,
                          sprites.lua (the titlebar toggle's flask)
scripts/
  gui.lua      the window, its ingredient amounts panel, every handler
  plan.lua     choices -> a finished cell, in one pass; the request, cap, split and throughput rules
  proto.lua    every question asked of the prototypes; research gating; an inserter's hand and swing
  cell.lua     pure geometry of one cell, the side slots included
  calc.lua     pure arithmetic: pace, request amounts, beacon transmission, swing time, chest
               shares, the inserter allocator
  poles.lua    pure pole cover for one cell
  blueprint.lua plan -> BlueprintEntity, and the hand-over into the cursor
  state.lua    persistent choices, flat values only, and their prune
  dispatch.lua tag-based GUI handler registry (Upcycler Planner's)
tests/                    the suite; registered in control.lua behind the active_mods guard
  pure/                   cell, calc, poles, gate -- also run on host Lua
  throughput_live_spec    inserter swings and hands measured live; stamped cells crafting at
                          their planned rate
  support/                research states, stamping, the lab surface
locale/en/assembly-planner.cfg   every player-visible string
images/                   portal screenshots, made by assets/assembly-planner/showcase/
```

## Naming

Prototypes, GUI element names and tag keys use **`apl-`**; settings and locale mod-level keys use
the full **`assembly-planner`**. Four prototypes: the shortcut `apl-open`, the hotkey
`apl-open` (same name, so the tooltip shows the binding), the linked `apl-confirm` and the
sprite `apl-show-all`. Every element name in the window is unique, which is how
`tests/gui_spec.lua` finds a control wherever the layout puts it.

## Working here

- Commit scope is `assembly-planner`. **Never commit, push or publish unprompted.**
- **Run the suite at checkpoints**: `run-tests.ps1 -ModPath assembly-planner` (factorio-testing
  skill), the pure tier on host Lua, `check-static.ps1`, and `validate.ps1` plus a hand-run
  `--check-unused-prototype-data`.
- **`README.md` is the portal description**; it and the locale are player-facing. Its images
  link to `images/` by absolute URL, so they show only once pushed.
- **Rebuild the screenshots** after a change a picture would show:
  `assets/assembly-planner/showcase/showcase.ps1 -Out <dir>`, then copy them into `images/`.
  It opens a game window and needs a screen attached.
- Design decisions go in `.ai-support/decisions.md` with the reason, the session in `journal.md`.

## Decided

The rules, in short; every reason lives in `.ai-support/decisions.md`.

- One cell per blueprint; the inserter row on the south edge, input / output / quality output,
  left-aligned; the chest row under it; the footprint is the bounding box.
- Throughput: when the inserters cap the machine, extra pairs fill the bottom edge, then go up
  the left side and the right, whose beacons step two tiles out; only while each one raises the
  real rate. The rate line shows that rate; a warning names what still caps it.
- Requests: crafts (default 4) or minutes (default 2, real speed), plus per-ingredient amounts;
  a rule or number change, or an item change, replaces the hand-set amounts. Several ingredient
  chests each ask for their share of every ingredient, never less than one inserter load, or
  the whole request when that is smaller.
- The quality split is automatic when the quality chance is above zero; its override is kept
  only while it disagrees. Filters are nameless, `=` and `>` at the recipe's quality.
- Stock cap: chest slots (default 2, shared between the recipe-quality outputs), network count
  (on every recipe-quality output inserter), or none.
- Fluids: one, through a full-width pipe row behind the machine. Fluid products and two fluids
  are refused.
- Beacons beside and above, off until picked, then as many as fit and reach; speed modules by
  default.
- An optional pole: free tiles first, then a right-hand column, a top row, or both, each kept
  only when it powers more.
- The window is one form in three sections, a caption beside each row's controls, every option
  one click away: pickers in slot strips, narrow beacon counts, the setting a titlebar toggle,
  the ingredient amounts behind a pencil.
- Every picker always shown with its quality; only what cannot apply hides.
- The default recipe: researched, then one the machine crafts, then the one named like the item.

## Open questions

`.ai-support/deferred.md` owns them.
