# Robotics Reforged — decisions

Register: what is settled, and why. **Edited in place** — a decision that changes is rewritten
here rather than annotated, and the story of the change goes in `journal.md`. So this file
always reads as the present tense, and never carries "superseded" or "amended" markers.

Open work has one owner, `deferred.md`. Evidence has one owner, `analysis/`. Never ships
(leading dot).

**This file is short on purpose.** As of 2026-08-27 the mod is a scaffold: identity and
packaging are settled, and *none* of the design is. Everything absent from this file is in
`deferred.md`, not forgotten.

## Identity and packaging

- **Name `robotics-reforged`, title *Robotics Reforged*.** The repo owner's name, kept
  verbatim. It is a rework mod and *Reforged* is the word that genre uses, so a player searching
  for one will recognise it.
- **The portal name is free, and free is not the same as ours.** `GET /api/mods/robotics-reforged`
  returned 404 on 2026-08-27, with the method sanity-checked against `mining-patch-planner`
  (200). A portal name is claimed by the **first upload** and by nothing else, so the name stays
  available to anyone until this mod is published. Worth having checked early: `pure-modules`
  was lost to a squat by a deleted account, and portal names stay taken after the account goes.
  Worth re-checking immediately before the first upload, because nothing reserves it in between.
- **Prototype prefix `rbr-`**, with settings and locale mod-level keys using the full
  `robotics-reforged`. Prototype names share one flat global namespace and a collision there is
  silent, which is the whole reason for a tag; settings are listed to players beside other mods'
  settings, where a three-letter tag would be meaningless. This matches the house style in
  `pure-modules-realk` (`pure-`) and `upcycler-planner` (`upl-`). `rr-` was rejected as too
  generic for a namespace shared with every mod in the game — two letters, no relation to the
  subject, and *Rail*, *Rocket* and *Reactor* mods all reach for it. `robotics-` was rejected
  because it reads as vanilla's own `robotics` technology and would make a modded prototype look
  like a base-game one in logs and Factoriopedia. **The tag is free to change until the first
  release** and costs a migration file plus a major bump after it.
- **Both game tracks, forked — Factorio 2.1 from `main`, Factorio 2.0 from `legacy/2.0`.**
  Asked for by the repo owner on 2026-08-27, reversing the scaffold's initial 2.1-only call the
  same day. That call rested on "there is no reason to carry a second build of a mod that has
  not shipped a first", which had it backwards: **2.0 is the stable release most players are
  on**, and the cheapest possible moment to fork a mod is before it has any code — the branch
  costs one file today and grows only as the mod does. Nothing here needs a 2.1-only API, so
  this was always a scope call rather than a technical one.
  **`main` carries no 2.0 code**: the repo forks, it never gates — no base-version branches, no
  `mods[...]` probes, no shims, however small. The one divergent file is `info.json`
  (`factorio_version`, the `base` floor), declared in the repo `CLAUDE.md` → *Git*; everything
  else, `CLAUDE.md`, `README.md`, `changelog.txt` and all of `.ai-support/` included, is kept
  identical on both branches so a cherry-pick never conflicts on documentation.
- **Version starts at `0.1.0`**, open, `Date: ????`, and the two tracks draw from **one shared
  sequential version line** (repo rule, `factorio-multiversion` → Version numbering). Nothing
  has shipped and no `robotics-reforged_*` tag exists, so `0.1.0` is unassigned to a track: by
  the repo's ship-2.0-first pair convention the first release pair would put the lower number on
  the 2.0 build, but that is the repo owner's call at release time and is not decided here.

## Dependencies and expansions

- **`["base >= 2.1.0", "? space-age"]`.** The optional prefix buys load order and nothing else:
  it costs nothing when the expansion is absent, and it is what guarantees Space Age's
  prototypes exist before a later `data-updates.lua` touches them. A version on it was
  deliberately omitted — a version on an optional dependency is still enforced, and would
  disable this mod against an older Space Age for no benefit.
- **No Space Age feature flags are declared.** A `*_required` flag makes owning the expansion
  mandatory and there is no partial mode, so declaring one would narrow the audience of a mod
  that works perfectly well in vanilla 2.1. The right tool for expansion-gated properties is the
  data-stage `feature_flags` table, which is safe to read when off (it is `false`, not an error).
  This is the opposite call from `upcycler-planner`, and for the opposite reason: that mod is
  worthless without quality tiers, and it wanted the portal's Space Age tag. This one is not and
  does not.
- **No `flib` dependency.** Nothing here needs a GUI, spatial math or table helpers yet. Add one
  only if the mod actually `require`s from it.

## Structure

- **One `definitions.lua` tier table is the single source of truth**, and `entity.lua`,
  `item.lua`, `recipe.lua` and `technology.lua` read it and define nothing of their own. A robot
  tier needs four prototypes that must agree about a name, an order and a set of numbers, and
  four hand-written files are four places for them to drift. This is the shape
  `pure-modules-realk` uses for its module tiers, and it also makes the tier table pure Lua —
  loadable by the host-interpreter test tier, which is where a tier's shape gets checked before
  the game ever sees it.
- **New tiers go in `data.lua`; retuning vanilla's two goes in `data-updates.lua`.** Vanilla's
  robots exist only after base's own `data.lua` has run, so touching them any earlier silently
  does nothing — the standing rule for another mod's prototypes, and base is another mod.
- **Art is deferred; a new tier wears the vanilla sprites of the robot it succeeds.** A flying
  robot needs a dozen animation fields plus shadows and a `dying_explosion`, and copying the
  vanilla prototype brings all of it for free. Real art is a separate project with its own
  skill (`factorio-graphics`) and is not a prerequisite for a playable mod. See `deferred.md`.
