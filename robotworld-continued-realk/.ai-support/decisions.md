# Decisions — Robot World Continued (RealK)

What is settled, and why. Rewritten in place when superseded — see the repo `CLAUDE.md` →
*AI support folders*.

Everything below was settled on 2026-10-16, in the session that forked and ported the mod,
against the default dev install at **base 2.1.17**, and re-validated on **2.1.22** after the
install was updated mid-session.

## Identity and lineage

A fork of **Robot World Continued** by thinkong (portal `robotworld-continued`, source
`https://github.com/thinkong/Robot-World`, ported from commit `cb9bd77`, upstream version
2.0.0, Factorio 2.0). That mod is itself a continuation of **Robot World** by GamingComet
(portal `robotworld`, whose page now shows the owner as DoubleStyx). The owner asked for the
fork on 2026-10-16: add it as `robotworld-continued-realk`, port it to 2.1, publish it with a
simpler description and credits.

## Licensing

Robot World is released under the **Unlicense**; Robot World Continued under **MIT** (the
portal's license field — the upstream repository ships no license file). Both permit
modification, relicensing and redistribution, so this fork is **GPLv3** like every mod in the
repo. MIT's one condition — keep the copyright and permission notice in every copy — is met by
`UPSTREAM-LICENSES.txt` at the mod root, which ships in the zip (not a dotfile, not in
`package.ignore`). The README credits both authors by name and links both mods.

## Name, title, version

- **`robotworld-continued-realk`**, the owner's choice. Portal GET returned 404 on 2026-10-16.
- **Title "Robot World Continued (RealK)"** — the suffix keeps it apart from upstream's
  identically named mod in the in-game browser. Proposed by the agent; the owner released it
  under that title.
- **`0.1.0`**, the owner's choice over 1.0.0 and 2.1.0. Published 2026-10-16, tagged
  `robotworld-continued-realk_0.1.0`. **`0.1.1`** followed the same day with the fixes from
  the upstream discussion review (*Scope* below), and **`0.1.2`** is that build ported to
  Factorio 2.0, also the same day — the only 2.0 release (*Factorio 2.1 only* below); `git tag
  -l 'robotworld-continued-realk_*'` is the list of what shipped. The next release goes above
  0.1.2, not merely above `info.json`'s 0.1.1: the portal never takes a number twice.
- **Portal page:** license GNU GPLv3 (`default_gnugplv3`), category `tweaks` (it changes vanilla
  robots, roboports and inserters rather than adding content), description from `README.md`
  via `fmtk details`, run from `main`'s folder: it also sends `info.json`'s `homepage`, so it
  must be `main`'s. Gallery: `images/01-startup-settings.jpg` then
  `images/02-early-robots-choice.jpg`, the real mod settings screen at 150% UI scale.

## Names: everything prefixed `rwcr-`

Every setting and every technology the mod adds is `rwcr-<upstream name>`. **Owner's choice
(2026-10-16)**, against the agent's recommendation to keep upstream's bare names. The trade
was explicit: bare names would have let a player switching from upstream keep their startup
settings and their early-technology research; the prefix follows the repo's naming rule and
costs exactly that. The README tells switching players their settings do not carry over.

Either way the mod declares **`! robotworld` and `! robotworld-continued`**: both scale the
same vanilla robots, so running two of them multiplies everything twice.

## Scope: port + bug fixes, plus owner-requested changes

The owner chose this over a strict port and over a modernising rewrite, then asked for four
changes the same day: the Krastorio 2 quick start additions, the starting power armor, the
settings consolidation and early ghosts (each below). After 0.1.0 the owner had upstream's
portal discussion reviewed (50 of 52 threads; the portal would not serve the second page) and
chose three fixes for 0.1.1: Factorissimo 3's hidden roboports, the logistic network button for
early robots (*Early robotics flags*), and AAI Containers' chests (*Dependencies*). Otherwise
behaviour is upstream's; the code was restructured only as far as the fixes needed.

### What the port changed

- **Helpers are module locals, not globals.** The data stage is one Lua state shared by every
  mod; upstream defined `MultiplyEnergy`, `enableRecipes`, `replaceIngredient`,
  `run_early_updates` and more as globals, plus stray globals like `itemname` and
  `logistics_rad`. Any other mod using the same names would clobber or be clobbered.
- **Hidden robots are skipped by `robot.hidden`.** Upstream checked `flags` for `"hidden"`,
  which 2.0 replaced with the `hidden` property, so robots other mods hide were scaled.
- **Hidden roboports are skipped the same way** (0.1.1). Upstream scaled every roboport.
  Factorissimo 3 (`factorissimo-2-notnotmelon` 3.12.3) builds two hidden roboports into its
  factory buildings, one with a 64-tile construction radius sized to the factory floor;
  measured on 2.1.22, a construction multiplier of 2 took it to 128. Factorissimo has declared
  `! robotworld-continued` since its 3.11.17 (changelog gives no reason; its code touches
  nothing of ours), and this is the one interaction found. Factorissimo's hidden robot already
  carries `hidden`, so robots needed no change.
- **Cargo size is rounded to a whole number, at least 1.** `max_payload_size` is an
  `ItemCountType`; upstream multiplied it by a double, so any fractional result stopped the load.
- **`max_payload_size_after_bonus` and `max_speed` are raised to the new base values when lower.**
  Both are 2.0+ caps documented as "must be >= max_payload_size / speed"; a mod that sets
  them would otherwise stop the load once the base is scaled up. Proven on a test robot with
  both caps at their vanilla base values: the load stays clean and both caps rise.
- **Robot stack size is an `int-setting` with a minimum of 1.** Upstream's `double-setting`
  accepted fractions that `stack_size` rejects.
- **Quick start uses freeplay's created items.** Upstream's `on_player_created` branch never
  ran — `not player.character == nil` parses as `(not player.character) == nil`, always false —
  so only player 1 got the kit, and only through `on_cutscene_cancelled`, i.e. when skipping
  the intro. Adding the kit to freeplay's list in `on_init` reaches every new player. Proven on
  2026-10-16: a `--create` run with a probe mod read the merged list back from freeplay, which
  also proves freeplay initialises before this mod (otherwise the call would have errored).
- **The robot health multiplier has a minimum of 0.01.** Upstream allowed 0, and the engine
  stops the load with "Max health must be positive" — measured 2026-10-16. Every other
  multiplier keeps upstream's minimum of 0: speed, battery and energy at 0, and a roboport
  construction area of 0, were load-tested and are accepted.
- **Scaled energy is written as a plain decimal.** Lua formats small results in exponent form
  (`5e-06kJ`); the engine happened to accept that in a test run, but nothing documents it, so
  `multiply_energy` formats with `%.10f` and trims trailing zeros.
- **Quick start checks both freeplay methods exist** before calling them, so a partial
  `freeplay` interface from another scenario or mod is skipped rather than crashing.
- **Robot items are found through `place_result`.** Upstream looked up an item named like the
  robot and special-cased 248k's `_entity` → `_item` naming; any other mod's naming was
  silently skipped. Every item whose `place_result` names a scaled robot now gets the stack
  size, which matches upstream in vanilla and needs no per-mod case. Measured with Bob's
  Logistics 3.0.2: robot tiers 2-5 all get it.
- **Energy strings are parsed with `util.parse_energy`'s grammar** (any `tonumber` number,
  then an optional SI letter and J or W), so values another mod wrote in exponent form or as
  `.5MJ` are scaled instead of silently passed through. `util.parse_energy` itself is not
  used: it converts to joules per tick and drops the prefix.
- **Robots that leave `max_health` unset are scaled from the engine default of 10.** Upstream
  multiplied the nil field, which stopped the load.
- **Cheap recipes rebuild their recycling recipes.** The recycler generates every
  `<name>-recycling` in its own `data-updates.lua` and copies the ingredient amounts at that
  moment (`recycler/recycling.lua`, `add_recipe_values`); it always runs before this mod's
  `data-updates.lua` (deeper dependency chain with Space Age, natural sort order without). So a
  cheap roboport recycled into a quarter of the vanilla one's steel, gears and advanced
  circuits. `cheap-recipes.lua` calls `generate_recycling_recipe` again after each change,
  the same call Krastorio 2 makes for every recipe in its final-fixes; the duplicate hidden
  unlock it appends to the recycling technology is accepted by the engine. Inherited from
  upstream, where quality generated recycling the same way.
- **`recharge_minimum` scales with the roboport buffer.** It is the charge a roboport needs
  after a blackout before it works again (vanilla 40 MJ of a 100 MJ buffer). Scaling the
  buffer alone below 0.4 left a roboport that could never restart. Upstream had the same bug
  through its separate buffer multiplier. The engine also stops the load when
  `recharge_minimum` is below one tick of `energy_usage` ("recharge_minimum must be >=
  energy_usage", measured at charging 0 on 2.1.22), so it is raised to that floor, rounded up
  to a whole joule — rounding to nearest left it a hair under.
- **Bob's Electronics' basic circuit is `bob-basic-circuit-board`.** Upstream used
  `basic-circuit-board`, Bob's 1.1 name; Bob's renamed it with its 2.0 port, so upstream's
  cheap recipes named an item that no longer exists. Verified from bobelectronics' own source
  (tag 2.0.0, and the `dev2.1` branch at 3.0.1: `prototypes/electronics.lua`) and from Bob's
  Logistics 3.0.2 checking that name. Bob's makes `electronic-circuit` a later tier and gives
  its own early recipes this board, so the cheap recipes follow it.
- **The recursive-blueprints branch is removed.** That mod's last release is for Factorio 1.1
  (portal, checked 2026-10-16), and 2.1 refuses to load it, so the branch could never run.
- **`icon_mipmaps` removed** (gone since 2.0), and `icon_size` dropped beside `icons`.
- **Pre-2.0 recipe shapes (`normal` / `expensive`) dropped** from the helpers; 2.0 removed them.
- **Settings consolidated, 32 → 20** — see *Settings* below.
- **Locale rewritten** for players: shorter names, a typo fixed, missing descriptions added.

## Settings

Upstream's set, plus the power-armor toggle, was 32 settings. The owner asked on 2026-10-16
to cut the duplicates and approved this plan before it was built; the mod was unpublished, so
renaming or dropping a setting cost no player anything. Every key keeps the `rwcr-` prefix and
every setting carries `order`, so the GUI lists them in groups rather than alphabetically.

- **Robots are tuned per type only** — construction and logistic each get speed, cargo,
  battery and energy use. Upstream's "all robots" multipliers stacked on top of the per-type
  ones and are gone; changing every robot now means setting both types.
- **One energy-use multiplier per type** scales both `energy_per_move` and `energy_per_tick`.
  Separate flying and hovering energy was the knob nobody needs.
- **Health and stack size stay shared** by both robot types.
- **The fixed roboport radius values are gone**; only the two area multipliers remain. The
  values existed to set one radius across every roboport type at once.
- **Roboport charging scales the buffer too** (`buffer_capacity`, `input_flow_limit`,
  `recharge_minimum` and `charging_energy` together), so a faster port does not run its own
  storage dry. Idle power and "only change the vanilla roboport" stay.
- **Early robots is one dropdown** (`rwcr-early-robots`: off / construction / logistic /
  logistic-system), each level including the ones before it; `lib.early_level()` turns it into a
  number. Upstream's three independent toggles allowed logistic robots without construction
  robots, which this drops. Construction unlocks the robot, the roboport and the passive
  provider and storage chests; logistic adds everything `logistic-robotics` unlocks; the system
  adds everything `logistic-system` unlocks. The four early technologies come with any level
  except Off.
- **"Cheap early recipes" replaces "Keep vanilla recipes"**: the same switch worded the
  positive way, on by default.

Measured after the change on 2.1.22: every level of the dropdown, cheap recipes on and off,
the merged energy and charging values, and a full load.

### Kept as upstream had it, deliberately

- **Stage placement**: early unlocks in `data.lua`, cheap recipes in `data-updates.lua`,
  multipliers in `data-final-fixes.lua`.
- **The early technologies' costs, prerequisites and order string**, and the relinking of
  `worker-robots-speed-1` / `worker-robots-storage-1` onto the early ones.

## Dependencies

Each one reviewed on 2026-10-16 against the portal (read-only GET, `factorio_version` of every
release) and, where a zip was at hand, by load-order runs on 2.1.22 with the dependency removed
from a staged copy. Optional dependencies carry **no version floors**: a floor disables this mod
when an older version of the other one is installed, and upstream's dated from 0.18 and 1.1.

- **`(?) Krastorio2` — load-bearing, measured.** Without it K2's `data-updates` runs after the
  cheap recipes and adds 20 steel beams to the roboport. The multipliers came out the same
  either way. `control.lua` also reads it for the quick start.
- **`(?) boblogistics` — load-bearing, measured.** Without it Bob's `data-updates` overwrites
  the cheap robot and roboport recipes with frames, brains and steel.
- **`(?) space-exploration` — needed, read not run.** With K2 present, SE 0.7.60's
  `data-final-fixes` sets absolute speed, battery, health and cargo on the vanilla robots; loading
  after us it would erase the multipliers. No SE zip was available to run.
- **`? bobelectronics`** — real code (the circuit above), so the visible `?`.
- **`? aai-industry`** — kept on inference: it rewrites many early recipes, the same overwrite
  risk measured for K2 and Bob's, and SE hard-requires it. No source was available.
- **`(?) nullius`** — no 2.1 release yet, kept as a free hedge: its 2.0 `data-final-fixes` sets
  absolute inserter speeds.
- **`(?) aai-containers` — load-bearing, measured (0.1.1).** AAI Containers & Warehouses 0.4.0
  redefines the five 1x1 logistic chests under their vanilla names in its `data.lua`, recipes
  `enabled = false`. If it loads after us it erases the early unlock, which is upstream's
  "early game logistic chest unavailable" report. Load order follows dependency depth before
  name: upstream had no `space-age` dependency, so it loaded before AAI (which has `(?)
  space-age`); 0.1.0 happened to load after AAI only because `(?) space-age` evened the depth.
  Measured on 2.1.22 with AAI 0.4.0: our `(?) space-age` removed from a staged copy reproduced
  upstream's bug (all five chests locked); with `(?) aai-containers` added, AAI loads first
  either way. With it: every Early robots level unlocks exactly its chests, at the cheap cost,
  recycling rebuilt; a placed AAI chest joins a roboport's network; cheap recipes off leaves
  AAI's costs; Off changes nothing; the full graphics load is clean. AAI's own 2x2 and larger
  logistic containers stay behind its technologies, which are not early robots.
- **`(?) space-age`** — no measurable effect on the recipes and multipliers (identical output
  with and without it: Space Age edits robots and roboports in `data.lua` and has no
  `data-final-fixes`). Kept, hidden and harmless; it also sets our load depth, which is why
  `aai-containers` above needs naming explicitly rather than relying on it.
- **`! robotworld`, `! robotworld-continued`** — both scale the same vanilla robots. The second
  is measured to block (exit 1, "Incompatible with ..."); the first has only a 0.16 release and
  is refused on version anyway.
- **`(?) 248k` dropped** — 1.0/1.1 only, so it can never load on 2.1. Its 2.1 continuation is a
  different mod, `248k-Redux`, which defines its robots in `data.lua` with `place_result` set
  and changes nothing later, so it needs no dependency.
- **No `recycler` dependency.** The recycling rebuild above works in either load order:
  `generate_recycling_recipe` ends in `data:extend`, so whichever runs last writes the same
  recipe.

## Quick start with Krastorio 2

The owner asked on 2026-10-16 for the kit to suit Krastorio 2. Measured against K2 2.1.2 and
K2 Spaced Out 2.0.17 on created saves, and re-measured unchanged on K2 2.1.4 and Spaced Out
2.0.19, the base kit already works there: every item exists,
K2's own `kr-shelter` stays in freeplay's list (K2 loads first through the `(?) Krastorio2`
dependency, so its `on_init` adds before ours), and the result fits the inventory. Two K2
changes make it a worse fit, and the kit adds to it only when `Krastorio2` is active:

- **+2 boilers, +4 steam engines.** K2 sets the boiler to 1.5 MW and the steam engine to
  0.75 MW (`prototypes/updates/base/entities.lua` in K2), so the base 4 + 8 makes 6 MW instead
  of 7.2 — while K2 raises labs to 200 kW and drills to 100 kW, putting the kit's own buildings
  at about 6.4 MW at full load. 6 + 12 makes 9 MW and keeps the 1:2 ratio.
- **+100 wood, only while `kr-basic-tech-card` is not hidden.** K2 labs research with basic
  tech cards (5 wood + 5 copper cable for 5 cards, enabled from the start), and the kit gives
  labs with nothing to put in them. K2 Spaced Out hides the card, so the check asks the recipe
  prototype instead of naming that mod — measured: wood added on K2, not on K2 Spaced Out.
- **The `Krastorio2` check covers Spaced Out as well**: on 2.1 Spaced Out runs on top of
  Krastorio 2, so no second name is needed.

Considered and not added: K2's small roboport (unlocked by the advanced tech card, far too
late for a starter kit), wind turbines (20 kW each, too weak to matter), and more coal (the
base kit's 50 is upstream's number, and thin everywhere rather than in K2 specifically). The
owner was asked and did not answer; the two additions above were the recommended options.

## Starting power armor

Added 2026-10-16 at the owner's request, behind its own startup setting
`rwcr-start-with-power-armor` (off by default). The owner first asked for mech armor, then
chose **power armor MK2 in every game**, with or without Space Age — so the item is one base
prototype and there is no expansion branch.

- **Loadout, owner's choice ("robot builder"):** portable fission reactor, exoskeleton,
  2 personal roboports, night vision, 4 batteries — 44 cells. Listed largest first because
  `LuaEquipmentGrid.put` packs first-fit and Krastorio 2 shrinks this armor's grid from 10x10 to
  8x8; measured to fit both (all 9 pieces placed on base, Space Age, K2 2.1.4 and K2 Spaced Out
  2.0.19).
- **Fuel, owner's choice:** equipment with a burner gets 5 of the plainest (lowest
  `fuel_value`, not hidden) fuel in its own fuel categories, found with the `fuel-category`
  item filter. Only Krastorio 2 makes anything in this loadout burn fuel — it gives the
  fission reactor a nuclear burner at 2.4 MW — so in practice that is 5 uranium fuel cells,
  about 4.5 hours at full load. Reading the categories from the equipment keeps K2's name out
  of the code and covers any other mod that does the same.
- **Given in `on_player_created`, equipped.** It goes into the character's armor slot, or the
  main inventory if another mod filled that slot. Freeplay starts the crash-site cutscene from
  its own `on_player_created`, so the character is read from `player.character` or
  `player.cutscene_character`; measured in a graphics benchmark run, where the probe saw the
  armor worn under the cutscene controller. Any scenario, not only freeplay — unlike the
  quick start kit it needs nothing from freeplay. The handler is registered only when the
  setting is on.
- Not re-given on respawn: the armor drops in the corpse like any other.
- Skipped entirely if `power-armor-mk2` does not exist, so an overhaul that removes it costs
  a missing armor, not a script error on every new player.

## Early robotics flags

`construction-robotics` carries a `create-ghost-on-entity-death` effect, and both it and
`logistic-robotics` carry a hidden `unlock-logistic-network` effect (base `technology.lua`,
2.1.22), so early robots alone left destroyed buildings with no ghost and the "connect to
logistic network" button disabled until that research. Upstream had both gaps. The owner asked
for the ghosts fixed on 2026-10-16 (0.1.0) and the logistic network button the same day (0.1.1).

- **Both set on the force from `control.lua`** (`create_ghost_on_entity_death`,
  `unlock_logistic_network`), whenever Early robots is above Off: on every force except
  `enemy` and `neutral`. A technology effect would need research, which is the very thing
  early robots skip.
- **Set again after every reset.** The game recomputes the flags from research whenever technology
  effects are reset: on any mod or startup setting change (before `on_configuration_changed`,
  per `auxiliary/migrations.html`), and on `reset_technology_effects` / `LuaForce.reset` from any
  mod. So it is re-applied in `on_configuration_changed`, `on_technology_effects_reset`,
  `on_force_reset`, and for new forces in `on_force_created`.
- Measured on 2.1.22 with a probe mod, both flags together: on in a new game, after a reset in
  `on_init` and in a running game, and on a newly created force; off on `enemy`; switched on in
  an existing save through `on_configuration_changed`; and back off when the setting is turned
  off, by the game's own reset with nothing from this mod.
- **`vehicle_logistics` is not set.** `logistic-system` grants it, and the logistic-system
  level unlocks that technology's recipes early but not this flag — the same class of gap, not
  asked for. See `deferred.md`.

## Roboport map reveal scales with the radius

A roboport with no `radar_range` charts out to its larger radius rounded up to chunks
(`prototype-api.json`, `RoboportPrototype::radar_range`), so the construction area setting
widens what each roboport reveals — x2 takes vanilla's 2 chunks to 4. Upstream's "Radar Scale"
thread asked for a separate setting. **The owner decided on 2026-10-16 to keep it as it is**:
a bigger area revealing more map makes sense. Don't pin `radar_range`.

## Factorio 2.1 only

The port started 2.1-only; at the owner's ask a Factorio 2.0 build followed the same day,
2026-10-16, as 0.1.2 from `legacy/2.0`. On 2026-10-23 2.1 went stable at 2.1.23 and the owner
retired the 2.0 track: 0.1.2 stays on the portal unmaintained, `legacy/2.0` keeps its source as
a frozen backup, and there is no 2.0 work and no 2.0 release.

## Thumbnail

Upstream's 128x128 `thumbnail.png` — three logistic robots, the 1.x-era game sprite —
upscaled to the repo's 144x144 with Lanczos. No new art was made.
