# Pure Modules — balance rationale

Register: why the numbers are what they are. **Edited in place** — when a value changes, rewrite
the paragraph that justifies it rather than appending a note, so this file always describes the
shipped build. The values themselves live in `../prototypes/`; `../CLAUDE.md` holds the rules.

Never ships (leading dot). Both release tracks are covered: where a figure differs between
Factorio 2.1 (`main`) and 2.0 (`legacy/2.0`), say so at the figure.

---

The values themselves are in `definitions.lua` and `technology.lua`. What isn't visible there:

- **A module recipe is four parents plus two correctives.** Four tier 3 modules of the same
  kind carry the bonus across; one `efficiency-module-3` stands for the power the tier adds,
  and one module of the partnering kind — a quality module for Pure speed, a speed module for
  the other two — stands for the penalty it drops. **One of each corrective, not two**, since
  1.0.4; the parents are what set the cost.
- **Research gates on `quantum-processor` under Space Age**, and that is sufficient on its own.
  It requires `cryogenic-science-pack`, whose unit already costs all ten packs, so it
  transitively requires Aquilo and every other planet. Adding the four `planet-discovery-*`
  technologies alongside it would be redundant. The base game has no quantum processor, so
  there the gate is `space-science-pack`.
- **Vanilla tier 3, for comparison**, is in the installed `base/prototypes/item.lua` and
  `quality/prototypes/item.lua`. Read them rather than trusting a copy here.
- **Vanilla beacon**, for comparison (`base/prototypes/entity/entities.lua`,
  `type = "beacon"`): `supply_area_distance = 3`, `module_slots = 2`,
  `distribution_effectivity = 1.5`, `distribution_effectivity_bonus_per_quality_level = 0.2`,
  `energy_usage = "480kW"`, `beacon_counter = "same_type"`,
  `allowed_effects = {"consumption", "speed", "pollution"}`.
- **The beacon technology is the gate the whole tier sits behind.** It is a prerequisite of
  all three module technologies, which is why it costs 1000 against their 3000 and why its
  recipe cannot contain a Pure module — the first draft's did, and that is now circular. The
  order is also the honest reading of the tier: the beacon is what made a module this clean
  worth building, and it pays for itself the moment it is researched by holding the tier 3
  modules already in hand over 25x25 tiles.
- **Transmission is capped at three beacons, by arithmetic rather than a special case.**
  `distribution_effectivity` is 1.25 and `profile` is `{1, 0.75, 0.75, 2.25/4, 2.25/5, ...}`,
  so N beacons transmit `N * 1.25 * profile[N]` = 1.25x, 1.875x, 2.8125x, then 2.8125x
  forever. A fourth beacon costs its full power and adds nothing. The flatness comes from
  the `2.25/N` tail and holds for *any* `distribution_effectivity`, since that is a constant
  multiplier on every term — so the two numbers tune independently. Verified in a
  `-KeepDump` run rather than reasoned about — the multiplication is the engine's, not
  ours.
- **The cap is set against a wall of vanilla beacons, in module-equivalents.** The
  comparable figure is `slots * N * effectivity * profile[N]` — how many modules' worth of
  effect land on one machine. Vanilla's two slots reach 8.49 at eight beacons and 10.39 at
  twelve, its geometric maximum; three Pure beacons reach `4 * 2.8125` = **11.25**. So this
  is deliberately **past the vanilla ceiling** rather than merely competitive with it — the
  strongest transmission available in the game, and the power and pollution are what it is
  charged for that. **The 1.5x cap that shipped through 1.0.5 put it at 6.00** — below
  *four* vanilla beacons — so the tier's beacon lost to the beacon it is built out of, and
  the strongest play was to keep the wall and add Pure beacons on top of it. 1.0.6 fixes
  that in two steps: 2.25x beats an eight-beacon wall, 2.8125x beats anything.
- **Reach is sold alongside the strength now, not instead of it.**
  `supply_area_distance = 10` covers 25x25 tiles against vanilla's 9x9 — 625 tiles to its
  81. The three-beacon cap is what keeps that safe: a wide area with a hard ceiling is one
  ring over a bank of machines, not a way to reach a bigger number by adding beacons.
- **Reach is *not* in the power exchange rate, and that is the one soft spot.** A beacon's
  power is a fixed sum divided across every machine it covers, so widening the area quietly
  makes it cheaper per machine — 6 MW over 21x21 was 13.6 kW/tile, 7.5 MW over 25x25 is
  12.0, against vanilla's 5.9. Still about twice vanilla, but the direction is downward.
  **Any further widening should move the power number, not just the cap.**
- **`distribution_effectivity_bonus_per_quality_level` is 0.35, against vanilla's 0.2.**
  Factoriopedia labels this figure **"Beacon transmission strength"** (`core.cfg`) and lists
  it per quality level. 0.35 on a base of 1.25 lands legendary on **3.0**, against the 2.5
  vanilla's `1.5 + 5 * 0.2` reaches. Three legendary Pure beacons transmit **6.75x**, or 27
  module-equivalents. Quality is the axis the three-beacon cap deliberately does not close,
  so it is where the ceiling keeps rising once a fourth beacon stops paying. It was 0.1
  through 1.0.5 and 0.3 mid-way through the 1.0.6 pass; the number has to be set
  deliberately either way — inheriting vanilla's 0.2 through the deepcopy sits it on a
  different base and would be the silent mistake.
- **Power is 7.5 MW and climbs with what the beacon may carry**: +4 MW for productivity,
  +2 MW for quality, so 7.5/9.5/11.5/13.5 MW. **The base tracks the transmission cap** —
  1.5x / 2.25x / 2.8125x against 4 / 6 / 7.5 MW — so the beacon costs what it always did per
  unit of effect transmitted. The two adders are rounded to whole megawatts rather than
  tracking that factor exactly, because a 3.75 MW rung reads as arithmetic left in by
  accident. The floor sits at three times the foundry's 2.5 MW, the heaviest *crafting
  machine* in the game (the rocket silo's `active_energy_usage` is 3.99 MW and a fusion
  reactor draws 10 MW, so "heaviest draw in the game", as this file used to say, was
  wrong). Productivity costs twice what quality does because beaconed productivity is the
  larger swing. Written in kilowatts in the Lua, because 9.5 MW is a rung and vanilla
  writes its own big machines that way too.
- **The beacon pollutes, and no other beacon anywhere does.** `emissions_per_minute` on the
  energy source at 2 per megawatt — 15/min at the base draw, up to 27/min with both settings
  on. Not one beacon in base, quality, Space Age, Krastorio 2, Space Exploration, maraxsis or
  any beacon mod surveyed emits any, so there is no precedent to copy and the anchors are
  machines instead: foundry and oil refinery 6, biolab 8, big mining drill 40, heating tower
  100. A beacon runs whether or not the machines under it do, so it is dirty for as long as
  it is powered — which is the argument for putting part of the cost here rather than all of
  it in watts.
- **Only Nauvis has `pollutant_type = "pollution"`.** Vulcanus, Fulgora and Aquilo have none
  and Gleba has `spores`, so `{pollution = N}` costs nothing off-world. That is vanilla's own
  behaviour — the foundry emits 6 and Vulcanus absorbs none of it — rather than a gap to
  paper over with a second pollutant. The agricultural tower is the only thing that emits
  spores, and its own comment says that is for attack-group pathfinding, not balance.
- **That power argument is a normal-quality argument only.** `QualityPrototype` carries
  `beacon_power_usage_multiplier`, and `quality/prototypes/quality.lua` sets it to 5/6, 4/6,
  3/6 and **1/6** — so a legendary Pure beacon costs **1.25 MW** while its
  `distribution_effectivity` has risen to 3.0. Three of them transmit 6.75x for 3.75 MW
  total — 27 module-equivalents for less power than two normal-quality ones. The vanilla
  beacon takes the same discount, so this is Wube's balance rather than ours, but
  the tier's players are all past normal quality and the standing-cost framing does not
  survive there.
- **The Space Age recipe asks for one item off every planet** — tungsten (Vulcanus), carbon
  fibre (Gleba), a supercapacitor (Fulgora), a quantum processor (Aquilo) — chosen from each
  planet's `default_import_location` in `space-age/prototypes/item.lua`. None of them spoil,
  which rules most of Gleba's catalogue out. Without the expansion there are no planets to
  ask for, so low density structures stand in.
- **`heating_energy` is 600kW** because vanilla's 3x3 beacon asks 400kW — the highest figure
  in the game, checked across `space-age/`, where the 5x5 machines ask 100 to 300kW. A wider
  radiator asks more than the small one, not less.
