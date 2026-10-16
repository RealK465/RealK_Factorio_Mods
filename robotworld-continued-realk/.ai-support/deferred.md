# Deferred — Robot World Continued (RealK)

Parked and open work. The single owner of this list — `CLAUDE.md` doesn't keep a second copy.

As of 2026-10-16 the mod is **published (0.1.1 for Factorio 2.1, 0.1.2 for 2.0), validated and
unplayed**.

## Nothing has been played

Validated: the data stage on 2.1.17, 2.1.22 and 2.0.77 with every expansion and with none, at default settings
and with every toggle on, every Early robots level and fractional multipliers; `--check-unused-prototype-data` silent;
the quick start list read back from freeplay on a created save. Not checked: a real game with
robots flying, that the early technologies read sensibly in the tech tree, and the kit landing
in an actual player's inventory (freeplay's own `insert_safe` does that part).

## Early logistic system does not unlock vehicle logistics

`logistic-system` carries a `vehicle-logistics` effect, which lets cars, tanks and the like use
logistic requests. The logistic-system level of Early robots unlocks that technology's recipes
but not this flag, so vehicles keep waiting for the research. Same class of gap as the ghosts
and the logistic network button (`decisions.md` → *Early robotics flags*), and the same fix
would close it: set `LuaForce.vehicle_logistics` alongside them, at that level only. Not asked
for; noticed while fixing the logistic network button for 0.1.1.

## Upstream discussion: raised, not taken

From the 2026-10-16 review of upstream's portal discussion, left open by the owner:

- **Quick start in other scenarios.** The kit goes through freeplay's created items, so a
  scenario without the `freeplay` interface silently gets nothing (upstream's "16K Mini Factory"
  thread; that scenario is 1.1 only). A fallback that inserts the kit on player creation is
  possible, but many scenarios plan their own start.
- **5Dim's New Logistic** (`5dim_logistic`, has a 2.1 release): reported upstream as robots not
  available at the start. Not run.

## Quick start kit at very small robot stack sizes

Freeplay inserts its list with `util.insert_safe`, which drops whatever does not fit. The kit
holds 250 robots, so at a robot stack size of about 5 or less part of the kit is silently lost,
and which part depends on list order. Slot arithmetic only, not measured. Left alone: nobody
sets stack size that low and also turns the kit on.

## Compatibility not run in game

Each dependency's reason is in `decisions.md` → *Dependencies*. Run with this mod on 2.1.22:
Krastorio 2, Bob's Logistics and Library, AAI Containers & Warehouses 0.4.0 and Factorissimo 3
(3.12.3). Run on 2.0.77 (`decisions.md` → *Two tracks*): Krastorio 2 2.0.19, Krastorio 2 Spaced
Out 1.6.21, AAI Containers 0.3.2, Factorissimo 3.11.19, and Bob's Electronics, Logistics and
Library 2.1.x. Not run, for lack of a zip: Space Exploration (its robot overrides were read in
0.7.60's source; it gained a 2.1 release, 0.7.63, on 2026-10-15), AAI Industry (kept on
inference), and Bob's Electronics on 2.1 (its circuit name was read from source; on 2.0 it was run). Nullius has
no 2.1 release yet.

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

The gallery holds two mod settings screenshots (`images/`) and nothing in game; shots of robots
at work would need a played game. No FAQ.
