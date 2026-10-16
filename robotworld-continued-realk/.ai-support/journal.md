# Journal — Robot World Continued (RealK)

Append-only, newest first. Entries may go stale; they are history.

## 2026-10-16 — 0.1.0 published

The owner asked to release, publish, keep the docs current, commit and push. Before the upload
the name was confirmed free (portal GET 404), there was no tag, and `validate.ps1 -FullLoad` passed on
2.1.22. `fmtk datestamp` stamped the changelog 2026-10-16, and the shipping zip was rebuilt
(16 files, nothing private). It was published through `init_publish` plus the multipart upload,
because `fmtk upload` cannot create a mod. Then `edit_details` set license GPLv3 and category
`tweaks`, and `fmtk details` pushed the README. A cache-busted read-back confirmed title,
owner, license, category, homepage, description and the one 2.1 release. The other five
mods' READMEs gained the cross-link in the same commit series; their portal pages were not
re-synced.

## 2026-10-16 — early ghosts

The review had parked the ghost gap as a behaviour change; the owner asked for it fixed. The
force flag is set from `control.lua` and re-applied after every technology reset. A probe mod
on `--create` and `--benchmark` runs checked it at start, after resets, on a new force, and with
the setting switched either way in an existing save. One harness trap: the scratch
`mod-settings.dat` written by the first run kept the old setting value, so the switched-setting
run first looked like a failure until that file was cleared between runs.

## 2026-10-16 — release review: recycling, roboport restart, dependencies

The owner asked for an overall review with one reviewer dedicated to the dependencies, and
flagged the Bob's circuit name as a likely bug. Three reviewers ran in parallel: Lua
correctness, dependencies (with load-order runs against copies of the K2 and Bob's zips), and
player text plus packaging.

Found and fixed, all inherited from upstream:
- cheap recipes recycled into the vanilla ingredients, because the recycler builds its
  recipes before our `data-updates`;
- a smaller roboport buffer could fall below `recharge_minimum` and never restart. Scaling it
  then tripped a load check at charging 0, so it is now floored at one tick of idle power;
- upstream's Bob's circuit name was Bob's 1.1 one. The owner was right that it was a bug, but
  in upstream: the port already found the 2.x name, and only a dead fallback was left.

Also: `(?) 248k` dropped (no 2.1 release), the recursive-blueprints branch removed (1.1 only),
and an armor-item guard added. The dependency reasons are now measured rather than assumed,
and recorded in `decisions.md` → *Dependencies*. On the text side: one false changelog claim
(the health fix was a crash, not a skip), six missing setting descriptions, and the
cheap-recipes tooltip reworded. Re-verified on 2.1.22: profiles A to E (C now with charging
and inserter speed 0), vanilla, a full load, the K2 quick start, and the armor on base and K2.

## 2026-10-16 — settings cut from 32 to 20

The owner asked to centralise the settings and to see the plan first. Proposed and approved:
robots per type only with one energy-use multiplier each, shared health and stack size, the
fixed roboport radius values dropped, charging and storage merged, and the three early-unlock
toggles folded into one dropdown, with the negative "keep vanilla recipes" turned into "cheap
early recipes". The edge-test mod was moved to the new keys; every profile, a
construction-only run and a full load passed on 2.1.22. The decisions are in `decisions.md` →
*Settings*.

## 2026-10-16 — starting power armor

The owner asked for a setting to start in mech armor with basic equipment, warning that K2's
power equipment often burns fuel. Read Space Age's mech armor (end-game, 10x12 grid) and K2's
equipment: its fission reactor gets a nuclear burner, its portable generators burn chemical
fuel, only solar runs free. Asked three questions; the owner chose power armor MK2 in every
game, the robot-builder loadout, and a fuelled reactor under K2.

Testing needed a real player, which `--create` never makes. A `--benchmark-graphics` run of
the created save does create player 1 and fires `on_player_created`, so a probe mod logged the
worn armor's grid and burner contents at tick 120. Measured on base only, Space Age, K2 and K2
Spaced Out: all 9 pieces placed (10x10, and 8x8 under K2), reactor holding uranium cells under
K2 (4 in the slot, the fifth burning).

Mid-session the mods folder's K2 zips were updated in place (K2 2.1.2 -> 2.1.4, Spaced Out
2.0.17 -> 2.0.19, by their timestamps the in-game updater). The test harnesses now pick the
installed version, and the quick start K2 numbers were re-measured on the new versions:
unchanged.

## 2026-10-16 — cleanup pass

The owner ran `/simplify` over the mod. Four reviews (reuse, simplification, efficiency,
altitude) agreed nothing costs measurable time — `multipliers.lua` runs in about 0.3 ms on a
heavy pack — so the changes were for clarity and generality. Applied: Bob's circuit written
straight into the cheap recipes (dropping `cheapen` and `replace_ingredient`); the helper
module renamed to `prototypes/lib.lua` and required as `lib`, because `local helpers`
shadowed the engine's `helpers` global; one `startup()` builder for all 31 settings; settings
read once per robot kind and once for roboports; robot items found through `place_result`
instead of the 248k special case; `util.parse_energy`'s number grammar for energy strings;
the connection-distance clamp moved inside the roboports the mod changes. Every edge profile,
the quick start and the K2 runs gave identical results afterwards, and the prototype list
checksum at default settings was unchanged.

## 2026-10-16 — quick start for Krastorio 2

The owner asked to improve the kit when Krastorio 2 is present. Read K2 2.1.2 and K2 Spaced
Out from `exemples/`, then measured with copies of the K2 zips staged into a scratch mod
directory: a probe mod logged freeplay's final created items and their slot count on
`--create` runs for vanilla, K2 and K2 Spaced Out. The base kit already worked everywhere
(31-32 of 80 slots); the gaps were power (K2's weaker boilers, hungrier labs) and research
(K2 labs take wood-based tech cards). Added both, K2-only, with the wood skipped where the card
is hidden. Re-measured: 33 slots, wood present on K2 and absent on K2 Spaced Out, and a K2
game with quick start off unchanged.

## 2026-10-16 — forked and ported to 2.1

The owner asked to fork thinkong's Robot World Continued as `robotworld-continued-realk`, port
it to Factorio 2.1 and publish it with a simpler description and credits.

Checked first: upstream is MIT and its own source, GamingComet's Robot World, is under the
Unlicense, so a GPLv3 fork is allowed with the notices kept; the new name was free on the
portal. Cloned upstream at `cb9bd77` (its 2.0.0) into the session scratchpad.

Read upstream against the 2.1.17 API and found four things that break or misbehave: the stale
`flags` hidden check, fractional cargo and stack sizes, the 2.0+ payload and speed caps, and a
quick start that only ever reached player 1 through the cutscene-skip path. Also found the
helpers were globals in the shared data-stage Lua state.

The owner chose: `rwcr-` prefix on everything (against the recommendation to keep upstream's
names for drop-in switching), port + bug fixes, version 0.1.0, and a stop before publishing so
the player-facing text can be reviewed.

Validated: a default run, then a hand-built run with a throwaway mod that flips every toggle,
sets fractional multipliers, and adds a capped robot and a hidden robot — clean on all four
expansions and on base only, nothing reported unused. Quick start proven by a `--create` run
reading the merged list back from freeplay.

A review pass then flagged exponent-form energy strings at tiny multipliers. Testing that
turned up a different, real failure first: a health multiplier of 0 stops the load ("Max
health must be positive"), inherited from upstream. Fixed with a 0.01 minimum; energy is now
written as a plain decimal; zero speed, battery, energy and radius were confirmed to load.
