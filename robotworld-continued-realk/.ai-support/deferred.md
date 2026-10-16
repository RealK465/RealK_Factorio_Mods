# Deferred — Robot World Continued (RealK)

Parked and open work. The single owner of this list — `CLAUDE.md` doesn't keep a second copy.

As of 2026-10-16 the mod is **published (0.1.0), validated and unplayed**.

## Nothing has been played

Validated: the data stage on 2.1.17 and 2.1.22 with every expansion and with none, at default settings
and with every toggle on, every Early robots level and fractional multipliers; `--check-unused-prototype-data` silent;
the quick start list read back from freeplay on a created save. Not checked: a real game with
robots flying, that the early technologies read sensibly in the tech tree, and the kit landing
in an actual player's inventory (freeplay's own `insert_safe` does that part).

## Early robots do not unlock "connect to logistic network"

2.0 added a hidden `unlock-logistic-network` effect to `construction-robotics` and
`logistic-robotics`; it sets `LuaForce.unlock_logistic_network`, which enables the "connect to
logistic network" button on inserters, belts and the like. Unlocking robot recipes from the
start does not grant it, so a player using early robots cannot wire machines to the logistic
network until the vanilla technology is researched. Upstream (written for 1.1) has the same
gap. Candidate fix: add the effect to `rwcr-early-character-logistic-slots`. Not done because
the owner scoped the port to bug fixes; it is a behaviour change.

The sibling gap, ghosts on entity death, was fixed at the owner's request with a force flag set
from `control.lua` (`decisions.md` → *Early ghosts*). The same pattern would close this one
through `LuaForce.unlock_logistic_network`.

## Quick start kit at very small robot stack sizes

Freeplay inserts its list with `util.insert_safe`, which drops whatever does not fit. The kit
holds 250 robots, so at a robot stack size of about 5 or less part of the kit is silently lost,
and which part depends on list order. Slot arithmetic only, not measured. Left alone: nobody
sets stack size that low and also turns the kit on.

## Compatibility not run in game

Each dependency's reason is in `decisions.md` → *Dependencies*. Not run, for lack of a zip:
Space Exploration (its robot overrides were read in 0.7.60's source), AAI Industry (kept on
inference), and Bob's Electronics itself (its circuit name was read from source; Bob's
Logistics and Library were run). Nullius has no 2.1 release yet.

## Upstream values kept on purpose, flagged by review

A cleanup review (2026-10-16) suggested two behaviour changes, both left for the owner:

- **Scale the payload and speed caps with their stat** instead of raising them to the new
  base. Keeps what another mod meant by the cap (research headroom); today a big multiplier
  can leave research adding nothing on such a robot. No vanilla or Space Age robot sets
  either cap, so it only touches modded robots.
- **Factor the four early technologies into a builder.** They repeat `prerequisites`,
  `order` and two `unit` tables. Left written out like vanilla's own technology file, so
  each stays searchable by name; any builder must make fresh `unit` tables per call.

## Portal page

No gallery and no FAQ yet; screenshots would need a played game with robots working.
