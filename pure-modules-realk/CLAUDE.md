# CLAUDE.md — Pure Modules

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only
covers what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

One new top tier of modules — named "Pure", not numbered — stronger than tier 3 and stripped
of its speed and quality penalties, keeping only a flat energy and pollution cost. Quality
modules alone carry no penalty. Plus beacons sized for the tier.

Both halves are implemented and balanced. **Modules**: speed, productivity and quality, with
their categories, recipes, technologies and icons. **Beacon**: entity, item, recipe,
technology, full animated graphics and icons, an Aquilo frost overlay, remnants and a dying
explosion. Design notes live in `.ai-support/pure-beacon-design.md`. Four startup settings
govern where the tier can be built and what the beacon will carry — see **Settings** below.

**Published, on two tracks** — Factorio 2.1 from `main`, Factorio 2.0 from `legacy/2.0`.
Run the `factorio-release` skill's "Published or open?" check rather than trusting a number
written here: `git tag -l 'pure-modules-realk_*'` is what has shipped, and a changelog section
still stamped `Date: ????` is what has not. Both tracks draw from one shared version sequence,
so new work takes the next free number whichever track it ships on — `factorio-multiversion`
→ Version numbering.

**The two tracks differ on purpose, in the Lua.** The 2.0 build cannot hold module penalties
flat across quality — `consumption_quality_multiplier` and `pollution_quality_multiplier` are
2.1-only, so on 2.0 quality scales the penalties along with the bonuses and no property exists
to stop it; the flat-penalty claim therefore belongs to a 2.1 changelog section and to no 2.0
one. `definitions.lua` carries `quality = 0.04` on `main` against `0.4` on `legacy/2.0`, because
a 2.0 quality value is ten times its 2.1 counterpart, and `recipe.lua` and `beacon.lua` fork on
the category and ingredient forms 2.0 understands.
**Do not reconcile those files by syncing them** — the divergence is the port.

**`changelog.txt` is not one of them, since 2026-08-07.** One file, shared by both branches,
listing every release with its game named in the section. The portal renders a single changelog
per mod, so the 1.0.4 entries — written only on `legacy/2.0` — never reached the website at all,
and the 1.0.5 section the website *does* show says only that it is the port. **The two copies
were reconciled in the 1.0.6 / 1.0.7 pair on 2026-08-08** — one identical file on both branches
carrying every section from 1.0.0 to 1.0.7, confirmed rendering all eight on the live site. The
zips published before that still carry the split copies and cannot be corrected; see the repo
`CLAUDE.md` → Git and `factorio-multiversion` → Changelog across two tracks.

`README.md` was a third until 1.0.2/1.0.3. The rewrite that shipped with them dropped the
sentence about a module's cost not growing with its quality — the only 2.1-only claim it
carried — so both tracks now ship the same README, and it is the same text the mod portal
serves as the description.

Efficiency is deliberately absent. Vanilla's efficiency module already has no drawback, so a
Pure version would carry the tier's whole identity on a +0.05 consumption bonus. Adding it is a
row in `prototypes/modules/definitions.lua` and a render — `TYPES` in the icon generator already holds
its measured colours — if that judgement changes.

## Layout

```
settings.lua                          the four startup settings
data.lua                              requires the modules/ then beacon/ files
data-final-fixes.lua                  requires both final-fixes files, in either order
prototypes/
  modules/
    definitions.lua                   the one table every other module file reads
    category.lua                      the pure-* module categories
    item.lua                          the module items
    recipe.lua                        their recipes
    technology.lua                    their technologies, gated behind the beacon's
  beacon/
    beacon.lua                        the pure-beacon entity, item, recipe and technology
    graphics.lua                      its BeaconGraphicsSet, required by beacon.lua
    remnants.lua                      the pure-beacon-remnants corpse
    explosion.lua                     the pure-beacon-explosion and its crystal particle
  shared/
    aquilo.lua                        the Aquilo-only surface condition (modules + beacon)
    beacon-effects.lua                what the Pure beacon may carry, read by two stages
    beacon-tints.lua                  what colour a module lights a beacon socket
    science-units.lua                 shared technology unit costs (modules + beacon)
                                      one count each, one fresh table per call
  final-fixes/
    module-beacon-art.lua             beacon art fields for every module shipped without them
    beacon-categories.lua             both beacon whitelists, once every category exists
graphics/icons/                       120x64 item icons
graphics/technology/                  480x256 technology icons
graphics/entity/beacon/               beacon sheets and module-socket sprites
graphics/entity/beacon/remnants/      the corpse sheet, two variations stacked
thumbnail.png                         144x144, portal and in-game mod browser
images/                               portal gallery screenshots — never shipped
```

Folders follow the community convention in the `factorio-mod-setup` skill: grouped by **content**
rather than by prototype kind, and a folder named after a data stage (`final-fixes/`) holds exactly
what that stage requires. `shared/` and `modules/definitions.lua` are plain Lua modules, not
prototypes — nothing calls `data:extend` in them.

**`require` paths use dots, mod-wide.** This is a readability convention, not a safety one: the
note that used to sit here claimed mixing `.` and `/` would run a file twice under two cache
entries, and that is wrong for Factorio — it caches by the resolved file, verified on 2.1.14
(see the repo `CLAUDE.md`). Keep the dots anyway so `modules/definitions.lua`, required from
four places, is grep-able as one spelling.

The numbers in `prototypes/beacon/graphics.lua` and `prototypes/beacon/remnants.lua`
(widths, heights, shifts) are **measured output** of the sheet scripts —
`sheet_numbers.txt` / `slot_numbers.txt` / `remnant_numbers.txt` in the beacon assets
folder hold the current values. Re-rendering can change the crops; always re-check those
files against the Lua after a render.

`modules/definitions.lua` is one table holding every module's name, colour, effect, ingredients and
parents. It is the only file to edit when adding or rebalancing a module; its four
siblings iterate over it. **Keep the numbers there and nowhere else** — this file deliberately does not
restate them, so there is nothing to drift.

Art sources live outside the mod, in `assets/pure-modules-realk/` at the repo root, so `fmtk package`
cannot sweep them into the zip.

## Commands

Paths are relative to the repo root. Blender and the validate script take absolute paths on
this machine — see `CLAUDE.local.md`.

**Regenerate every icon.** Renders all three modules from the generator script, not from the
`.blend`, so it is reproducible and needs no running Blender:

```bash
blender -b -P assets/pure-modules-realk/icons/render_icons.py -- <out_dir>
for k in speed productivity quality; do
  python assets/pure-modules-realk/icons/export_icon.py item "<out_dir>/pure-$k-module.png" \
    "pure-modules-realk/graphics/icons/pure-$k-module.png"
  python assets/pure-modules-realk/icons/export_icon.py tech "<out_dir>/pure-$k-module.png" \
    "pure-modules-realk/graphics/technology/pure-$k-module.png"
done
```

**Iterating costs one layer, not seven.** Every layer is cropped independently
and carries its own shift, and `make_sheets.py` **skips any layer with no frames
in the directory** — leaving that sheet on disk and carrying its numbers over from
`sheet_numbers.txt`. So a deck or hull edit is `--layers base,shadow`, an arc edit
is `--layers arcs`, and neither disturbs the other's sheet. `render_entity.py
--only 3,8,55` renders just those frames of the loop for eyeballing one beat
(~1 s per arc frame) without paying for all 64. `deck` is a fourth sheet — the
deck plant's hologram, cryo vapour and cable pulses, 64 frames of a small crop at
~7 s each, independent of `anim` and `arcs`; a device or cable edit is
`--layers base,shadow,deck`. `make_stencils.py` regenerates the
decal atlas in `textures/` and only needs running when a mark changes.

`glow` is the fifth sheet: the same geometry as `anim` rendered with **every
light in the scene switched off**, so what lands on film is the materials' own
emission and nothing else — which is exactly what an additive `draw_as_light`
sprite should contain. It is what keeps the core shining after dark, the way
vanilla's own beacon uses `beacon-light.png`. Anything that changes the crystal
or the ring seams invalidates `anim` **and** `glow` together. It is the one
sheet packed at half the source resolution and declared `scale = 1.0`: it is a
9 px gaussian with no detail to lose, and at full res it was 4.2 MB, larger
than the anim sheet it only lights.

`export_icon.py` does the bloom, the downscale and the mipmap strip. Bloom happens there and
not in Blender's compositor because the glow has to extend the PNG's **alpha** — otherwise the
halo vanishes against the game background.

**Regenerate the beacon sprites.** Reproducible from the generator scripts; the `.blend` is a
saved snapshot, not the source of truth:

```bash
blender -b -P assets/pure-modules-realk/entity/beacon/render_entity.py -- <out_dir> \
  --layers base,anim,arcs,deck,glow,shadow,slot-box,slot-lights --frames 64
python assets/pure-modules-realk/entity/beacon/make_sheets.py <out_dir> pure-modules-realk/graphics/entity/beacon
python assets/pure-modules-realk/entity/beacon/make_slots.py <out_dir> pure-modules-realk/graphics/entity/beacon
# re-check sheet_numbers.txt / slot_numbers.txt against prototypes/beacon-graphics.lua
blender -b -P assets/pure-modules-realk/entity/beacon/audit_overlaps.py -- --top 20   # interpenetration report
blender -b -P assets/pure-modules-realk/entity/beacon/save_blend.py   # regenerate the committed beacon.blend snapshot

blender -b -P assets/pure-modules-realk/entity/beacon/render_icon.py -- <icon_dir>
python assets/pure-modules-realk/icons/export_icon.py item <icon_dir>/pure-beacon.png pure-modules-realk/graphics/icons/pure-beacon.png
python assets/pure-modules-realk/icons/export_icon.py tech <icon_dir>/pure-beacon.png pure-modules-realk/graphics/technology/pure-beacon.png
```

**Regenerate the Aquilo frost overlay.** One static frame off the whole machine, moving parts
included, so it costs one render rather than the full sheet run. `make_frozen.py` prints the
Lua numbers *and* gates the result against every vanilla frozen patch — colour bands, coverage
against the machine's own area, and the alpha spread. Read that report; the alpha spread is the
one that catches a patch which is technically the right colour and still reads as a film:

```bash
blender -b -P assets/pure-modules-realk/entity/beacon/render_entity.py -- <out_dir> --layers frozen
python assets/pure-modules-realk/entity/beacon/make_frozen.py <out_dir> pure-modules-realk/graphics/entity/beacon
# re-check frozen_numbers.txt against prototypes/beacon/graphics.lua
```

**Regenerate the remnants.** Independent of the entity sheets — the wreck is its own
scene and shares nothing but `beacon_gen`'s helpers and the render rig. **Judge the
result composited on the ground colour, not on white** — the fringe and overall value
are invisible otherwise, and both went wrong that way once:

```bash
blender -b -P assets/pure-modules-realk/entity/beacon/render_remnant.py -- <out_dir> \
  --layers wreck,shadow --variations 2          # add footprint to re-run the 320px gate
python assets/pure-modules-realk/entity/beacon/make_remnant.py <out_dir> \
  pure-modules-realk/graphics/entity/beacon/remnants
# re-check remnant_numbers.txt against prototypes/beacon/remnants.lua
blender -b -P assets/pure-modules-realk/entity/beacon/save_remnant_blend.py
```

**Validate — both configurations, always.** `modules/definitions.lua` and `modules/technology.lua` branch on
`mods["quality"]` and `mods["space-age"]`, so a single run only ever exercises half of this mod.
The four settings branch on top of that; `validate.ps1` cannot set them, so the only way to
exercise a non-default value is to flip `default_value` in `settings.lua`, run, and put it back:

```powershell
.\.claude\skills\factorio-validate\validate.ps1 -ModPath <abs>\pure-modules-realk
.\.claude\skills\factorio-validate\validate.ps1 -ModPath <abs>\pure-modules-realk `
  -Disable space-age,quality,elevated-rails,recycler
```

Add `-KeepDump` and read the resulting dump to confirm values rather than trusting the source;
delete the 28 MB file afterwards. The script runs in scratch write-data mode, so `-KeepDump`
leaves it at `%TEMP%\data-raw-dump-pure-modules-realk.json` and there is nothing to clean up in
the install. Nothing has to be closed first — the dev install holds its own lock.

## Portal images

Two different things, and only one of them ships.

**`thumbnail.png` at the mod root ships.** 144x144 — the size
`doc-html/auxiliary/mod-structure.html` asks for — shown both on the portal and in the
in-game mod browser. It is a crop of `images/beacon-on-aquilo.jpg` with the title set in
Titillium Web Bold, the game's own UI face, which `make_thumbnail.py` reads from the dev
install's `data/core/fonts/`.
Regenerate it rather than editing the PNG:

```bash
python assets/pure-modules-realk/thumbnail/make_thumbnail.py --preview
```

The script keeps a 512px master beside itself; `--preview` also writes a nearest-neighbour
blowup, because the thing that goes wrong is only visible at final size. Two constraints
found by getting them wrong:

- **Cap height at 144px is about 15 pixels.** A multi-stop chrome ramp on the text averages
  straight back to flat pale blue in the downsample. What survives is lit-top to dark-bottom
  plus a single reflection kick — hence the deliberately short `METAL` ramp.
- **Fit both lines to one font size, taken from the longer line.** Fitting each line to the
  same target width instead scales "PURE" up to four enormous letters and buries the beacon.

**`images/` does not ship.** It holds the full-size screenshots meant for the portal's
gallery, so it is in `info.json`'s `package.ignore` — 874 KB that no player has any use for,
and `fmtk package` would otherwise sweep it in, since it is neither a dotfile nor covered by
anything else. It is tracked in git: the shots are of a specific build and are worth keeping
with it. Names are hyphenated and describe the shot (`factoriopedia-pure-beacon.jpg`,
`showcase-beacons-in-line.jpg`) — the portal shows filenames, and the originals had spaces.

**The gallery went live 2026-08-06, was refreshed for 1.0.4/1.0.5 on 2026-08-07, and had its
beacon shot replaced for 1.0.6/1.0.7 on 2026-08-08**: six images, in this order —
`showcase-beacons-in-line`, `factoriopedia-pure-beacon`, the three module shots in item order
(speed, productivity, quality), and `mod-settings` last.
`beacon-on-aquilo.jpg` is deliberately *not* in it — it stays the source crop for
`thumbnail.png`. The gallery has no fmtk surface; it is the
v2 `images/add` + `images/edit` API written up in the `factorio-release` skill, and the id list
handed to `images/edit` **is** the gallery, so an id left out of it is removed. Uploading or
reordering is a **public write** and needs the repo owner's explicit approval for that specific
release — the rule in the repo `CLAUDE.md` and the `factorio-release` skill.

Three things these refreshes found, all of which cost a live gallery:

- **Re-uploading an unchanged file no longer works, and this replaces the old advice here.**
  The note used to say an id is a content hash, so re-uploading a byte-identical file returns
  the id it already had, and that this was how to map an entry back to a local file. As of
  **2026-08-08** the portal answers that call with
  `{"error":"InvalidRequest","message":"Image already exists"}` and **no id at all** — so the
  old recipe now walks straight into the empty-id trap below and would wipe the entries it was
  meant to identify. Only ever upload the file that actually changed.
- **Map the gallery by comparing pixels instead.** Download each id from
  `https://assets-mod.factorio.com/assets/<id>.png`, decode it and the local `images/*.jpg`
  with Pillow, and match on size plus mean absolute difference. The portal re-encodes to PNG
  but does not resample, so an unchanged shot scores **exactly 0.0000** against its local
  file — an unambiguous mapping. The one portal image matching nothing is the one being
  replaced, and its position is where the new id goes. Used on 2026-08-08 to confirm the
  beacon shot sits at slot 2 before touching anything.
- **`images/add` can return a response with no `id`**, and did on the first two calls of that
  refresh. Combined with the rule above — the list *is* the gallery — an empty id silently
  drops that image, so the two unchanged shots disappeared from the live page until the full
  list was re-sent. Check every id is non-empty *before* calling `images/edit`, and read the
  gallery back afterwards with a cache-buster.

## Decided

- **One unnumbered tier.** "Pure Speed Module", not "Speed Module 4". Tiers 1–3 are left
  alone; Pure sits above them as a distinct kind rather than a fourth rung.
- **Above tier 3, with only an energy and pollution cost.** The tier's identity is the
  missing speed and quality penalties, not the absence of all cost. Quality modules alone
  carry no penalty.
- **One new beacon** with a larger supply area. It accepts *every* tier of module, vanilla
  and Pure alike; the exclusivity runs the other way, by a setting that stops Pure modules
  fitting any other beacon.
- **Base game, with optional Space Age integration.** No hard SA dependency, and no
  `*_required` flag declared in `info.json` — declaring one would make the expansion
  mandatory. Reading `feature_flags` to light up expansion-only behaviour is fine and is what
  the Aquilo frost does.
- **Mod name `pure-modules-realk`, display title "Pure Modules".** Plain `pure-modules` is
  squatted on the portal by a deleted account (`deleted_638d1b511b2c`, five releases
  0.5.0–0.6.0 for Factorio 2.0, May 2025 — the same concept, found 2026-08-06 via the
  read-only portal GET). Portal names stay unique even after account deletion, so the mod
  was renamed before first release: folder, `info.json` `name`, `__pure-modules-realk__`
  paths, the settings prefix and the locale keys all match. Titles are not unique on the
  portal, so the player-visible name stays "Pure Modules". Prototype names (`pure-beacon`,
  `pure-*-module`, the `pure-*` categories) were not renamed — they could collide with the
  dead mod's only if a player installed both, which its 2.0-only releases make unlikely.

## Settings

All four are **startup** settings — they rewrite prototypes, so they lock once a save exists.
Names are prefixed `pure-modules-realk-`; the setting namespace is global across all mods.

| Setting | Default | What it does |
|---|---|---|
| `aquilo-only` | on | `surface_conditions` on all four recipes, pinning them to Aquilo. **Space Age only — the setting does not exist without it** |
| `restrict-to-pure-beacon` | on | strips the Pure categories from every *other* beacon |
| `beacon-allow-productivity` | off | adds `productivity` to the Pure beacon's effects and categories |
| `beacon-allow-quality` | off | adds `quality` to the same two. **Quality expansion only — the setting does not exist without it** |

- **Aquilo has no identifying property**, so pinning a recipe to it means matching its pressure
  exactly — `{property = "pressure", min = 300, max = 300}`, which is what vanilla's
  `cryogenic-science-pack` does. Aquilo's `surface_properties` (in
  `space-age/prototypes/planet/planet.lua`) are pressure 300, gravity 15, magnetic-field 10;
  no other planet shares the pressure.
- **`mods` is available in `settings.lua`**, not only in the data stage — the settings and
  prototype stages are built identically, which `doc-html/auxiliary/data-lifecycle.html` states
  for both at once. So the Aquilo setting is simply not defined without Space Age, instead of
  sitting in the GUI doing nothing. The catch: **indexing a setting that was never defined is an
  error, not a nil**, so every read of it must short-circuit on `mods["space-age"]` first, the
  way `shared/aquilo.lua` does.
- **The gate is on the recipe, not the entity.** Built on Aquilo, shipped and used anywhere —
  the same deal Vulcanus gives the foundry.
- **The Pure beacon takes every tier**, vanilla tier 1–3 and Pure alike. It is no longer
  Pure-only; the exclusivity now runs the other way, through the other beacons.
- **Both beacon whitelists are computed in `data-final-fixes`**, because both need the complete
  set of module categories and mods add those right up to that stage. A mod whose own
  final-fixes runs after this one can still slip a category past both lists — and the two
  directions are not equally harmless. On the Pure beacon a late category is simply *allowed*
  in, which is permissive and fine. On every *other* beacon the list has been materialised,
  so a late category is *excluded* from every beacon in the game, this mod's doing and on by
  default. There is no fix from here; it is inherent to `allowed_module_categories` having no
  subtractive form.
- **`allowed_module_categories` unset means "all of them"**, so excluding one category means
  materialising the entire list and leaving that one out — there is nothing to subtract from.
  The list is sorted before it is written: `pairs()` order over `data.raw` is not something to
  bake into a prototype every client in a multiplayer game has to agree on.

## Balance rationale

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

## Gotchas specific to this design

Most of these fail quietly rather than erroring — check them before assuming a value works.

- **A setting that cannot mean anything must not be defined**, and there are now two of
  them. `aquilo-only` is gated on `mods["space-age"]`; `beacon-allow-quality` is gated on
  `mods["quality"]`, because without the quality expansion there is no quality module and no
  quality module category — the setting would have charged the beacon its extra megawatt
  forever to transmit an effect nothing can produce, and a startup setting locks once a save
  exists. Every read of either must short-circuit on the `mods` check first: indexing a
  setting that was never defined is an error, not a nil. `shared/beacon-effects.lua` is where
  that short-circuit lives for the beacon, so `beacon.lua` and `final-fixes/` cannot drift
  apart on the answer.
- **Beacons cannot transmit productivity or quality in vanilla.** The base beacon's
  `allowed_effects` is `{"consumption", "speed", "pollution"}`. Both are now settings on the
  Pure beacon, off by default — beaconed productivity in particular is a large swing.
- **`allowed_effects` does not reliably keep a module out.** `speed-module-3`'s effect
  includes `quality = -0.025`, and it goes into the vanilla beacon perfectly happily even
  though that beacon does not list `quality`. So the effect list governs what is
  *transmitted*, and the module categories are what actually govern *admission*. Both have to
  be set together, or a module gets in and then silently does nothing — which reads as a bug
  rather than as a setting.
- **Restricting the beacon needs real module categories.** `allowed_module_categories` on
  `BeaconPrototype` filters by `ModuleCategory`, so each Pure module needs its own
  `module-category` prototype and a matching `category` on the module. Reusing the vanilla
  `"speed"`/`"productivity"`/`"efficiency"`/`"quality"` categories makes the whitelist
  impossible to express.
- **New categories cut both ways.** `RecipePrototype` and `CraftingMachinePrototype` also
  have `allowed_module_categories`. Anything that sets one will reject Pure modules, because
  they are not in its list. This mod's own final-fixes pass only ever writes to
  `data.raw["beacon"]`, so machines are never narrowed by it. Re-audited against 2.1.14:
  **nothing in base, quality, elevated-rails, recycler or Space Age sets it at all**, so the
  risk is modded content only.
- **Productivity is still gated per recipe** by `allow_productivity`, independent of module
  category. A Pure productivity module will not bypass that, and shouldn't be made to.
- **Legendary is `level = 5`, not 4** — the quality mod skips 4. Module effects scale by the
  quality prototype's `default_multiplier`, `1 + 0.3 * level`, so the legendary factor is 2.5
  and not 2.2. This is why the Pure quality effect is 0.04 to land on 10%. Sanity check any
  such sum against vanilla: its 0.025 → 6.25%, which is what the game displays.
- **Module penalties do not scale with quality, and that is free.**
  `consumption_quality_multiplier` and `pollution_quality_multiplier` default to 0.0 when
  their effect is positive (a penalty) and 1.0 when negative. So a legendary Pure module gains
  bonus without gaining cost. Setting those fields explicitly would break it — leave them
  unset.
- **A recipe may not list the same ingredient twice**, which `recipe.lua` guards by merging on
  add rather than appending. Without the quality expansion the speed module's substitute is an
  `efficiency-module-3`, and that is also the shared ingredient every recipe gets; the two
  collide and must collapse into one entry.
- **`beacon_counter = "same_type"`** means the diminishing-returns `profile` is counted per
  beacon prototype. Pure beacons diminish among themselves separately from vanilla beacons,
  so ringing one machine with both types sidesteps the Pure cap. That is **kept on purpose**:
  the vanilla beacon is `"same_type"` too and nothing can make it count ours back, so
  `"total"` would only penalise this beacon one-sidedly. Worth writing the ceiling down,
  though: three Pure beacons (2.8125x) plus eight vanilla ones (4.24x) transmit **7.06x**,
  against vanilla's own twelve-beacon maximum of 5.20x. The hatch costs floor space,
  beacon power and — see the next bullet — quality.
- **A beacon's own `allowed_effects` does not filter what it transmits, and this file used to
  claim it did.** The property is documented as *"the types of modules that a player can
  place inside of the beacon"* — a placement filter, nothing more. The transmission filter is
  the **receiver's** `allowed_effects`, worded *"the modules and beacon effects that are
  allowed to be used on this machine"*, and every crafting machine, lab and mining drill
  lists `quality` in it. So `speed-module-3`'s −2.5% **does** leave the beacon it sits in,
  multiplied by the whole transmission figure on the way out. Read straight out of 2.1.14's
  `prototype-api.json`; the old claim here and in `beacon.lua` was the exact opposite and was
  wrong. **This is the tier's strongest selling point rather than a footnote:** four
  `speed-module-3` in a Pure beacon at the 2.8125x cap would transmit −28.1% quality to
  every machine in 25x25 tiles, and four Pure speed modules transmit none — so the Pure beacon is
  the only way to run a machine hard and still farm quality on it.
- **Two things about the pollution are not verified in a running game.** A `--dump-data` run
  proves the prototype loads carrying the value and nothing else. (1) No beacon anywhere
  emits, so whether the engine actually applies an energy source's `emissions_per_minute` to
  a `BeaconPrototype` has no precedent to point at — it is the kind of thing that would fail
  silently. (2) Pollution is documented as the figure *"at full energy consumption"*, and
  `beacon_power_usage_multiplier` cuts a legendary beacon's draw to 1/6, so a legendary Pure
  beacon plausibly emits 2/min rather than 12 — the same discount quality already gives on
  power. Both want one look at the entity tooltip on a real map.
- **Quality scaling fields exist and default off**: `quality_affects_supply_area_distance`,
  `quality_affects_module_slots` on the beacon, and the `*_quality_multiplier` fields on
  the module. Leaving them unset is a choice, not neutral — supply area and slot count
  deliberately do not grow with quality, so a legendary beacon is stronger without also
  being bigger. `distribution_effectivity_bonus_per_quality_level` is the one that *is*
  set, and it is inherited from vanilla by the deepcopy rather than absent: rescaling it
  to the new base was required, not optional.
- **Most modules carry no beacon art at all.** `art_style` and `beacon_tint` are set on
  vanilla's speed and efficiency modules and on nothing else — not productivity, not the
  quality mod's, not most modded ones — because the vanilla beacon never takes those. Both
  are needed and both fail silently: a beacon selects its visualisation by matching
  `ModulePrototype::art_style` against `BeaconModuleVisualizations::art_style`, so a nil art
  style matches none and the socket draws nothing, and `beacon_tint` defaults to *no color*,
  which multiplies the mask sprite to transparent. `final-fixes/module-beacon-art.lua` fills
  both in wherever they are missing, from `shared/beacon-tints.lua`. **`primary` tints the
  cartridge body and `secondary` its lamps**, and reading a colour off the icon gets that
  backwards: the lamps are an icon's most saturated pixels, so sampling for "the module's
  colour" finds them. Productivity is a red module with gold lamps and quality a silver one
  with red lamps — not the gold and red module a sampler reports.
  Watch `requires_beacon_alt_mode` alongside them: it
  defaults to **true**, so a module left at the default only shows its cartridge while alt
  mode is on — which looks like the same bug to anyone playing without it.
- **A beacon shows a module's tier by sprite variation, and there is no fourth one.** Vanilla's
  slot sprites carry `variation_count = 3` and the game indexes them by `ModulePrototype::tier`
  — tier 1 lights one lamp, tier 2 two, tier 3 three — while all three tiers share a single
  `beacon_tint`. So vanilla's grammar is **tier = lamp count, kind = colour**. A Pure module is
  tier 4, past the end of that strip, so it clamps to the tier-3 variation and is pixel-identical
  to a tier-3 module in any vanilla beacon. Nothing can be added to someone else's sprite sheet,
  and Space Exploration simply accepted the tier-3 look for its tiers 4–9. This mod instead
  carries the distinction in the tint — dark anodised chassis, lamps toward white, family hue
  kept — which needs no new art and works in modded beacons too. That is why the `pure-*`
  entries in `shared/beacon-tints.lua` deliberately do not match their tier-3 parent.
- **Four tint slots, two audiences.** Vanilla names only `primary` and `secondary` and leaves
  `tertiary` / `quaternary` unused, which is what makes the split possible. The Pure beacon's
  own sockets ask for **tertiary/quaternary** and every other beacon gets **primary/secondary**,
  because the two are solving different problems: abroad a Pure module has to be told apart
  from a tier-3 one that shares its sprite, so it goes dark-chassis with white-hot lamps; at
  home the socket art is ours and draws one cartridge, so it should simply look like its own
  icon. The cost is that **every** module now needs all four slots or it goes invisible in the
  Pure beacon — vanilla modules name two. `beacon-tints.lua`'s `complete()` backfills the
  missing ones and `final-fixes/module-beacon-art.lua` applies it to every module in
  `data.raw`, this mod's and everyone else's. That is a deliberate global write, and the
  reason it is in final-fixes: a module another mod registers in *its* final-fixes is still
  caught.
- **`has_empty_slot = true` means that layer draws in BOTH states**, not only
  when the slot is empty — vanilla uses it for the layer carrying the module
  chip itself. So a slot layer is drawn over the base permanently, and if it
  repeats geometry the base already has, it occludes the base around it. This
  beacon therefore draws the ports **in the base sprite** and gives
  `module_visualisations` only the cartridge and its lenses; there is
  deliberately no empty-slot sprite.
- **Freezing is gated by `feature_flags["freezing"]`, not `mods["space-age"]`.** The flag is
  what actually permits `EntityPrototype::heating_energy` (repo `CLAUDE.md` has the full list),
  and it is on whenever *any* mod declares `freezing_required` — Space Age does. Declaring it
  in this mod's own `info.json` would enable the property here too, at the price of making the
  whole mod require the expansion, which it deliberately does not. Reading a flag that is off
  is safe: `false`, not an error, unlike an undefined startup setting.
- **`heating_energy` is what makes the beacon freeze at all** — "This entity can freeze if
  heating_energy is larger than zero." Space Age sets it on the vanilla beacon in
  **data-updates**, and `frozen_patch` alongside it, so a data-stage `table.deepcopy` of that
  beacon inherits **neither**. Both have to be set here. Without the first, the frost overlay
  can never be drawn, because the state it draws in never happens.
- **The frost patch covers the rings and crystal, so it depends on
  `reset_animation_when_frozen`.** It was rendered against animation frame 0; the flag pins a
  frozen beacon to that pose so the ice lands on the rings instead of beside them. Vanilla's
  centrifuge does the same for its drums. `random_animation_offset` is on, so without it a
  frozen beacon would sit at an arbitrary frame — and keep spinning.
- **Derive the beacon via `table.deepcopy(data.raw["beacon"]["beacon"])`** rather than
  writing it from scratch, per the repo-wide rule. The copied `graphics_set` glow is
  positioned for the vanilla footprint — if the Pure beacon changes size, re-author or drop
  it.

## Open questions

Beacon and release questions now; the module side is settled.

- **Nothing is in game yet.** Every number below the data stage is verified from a
  `-KeepDump` run and nothing else: the animation, the socket tints, the frost patch, the
  supply-area overlay at radius 10 and the alt-mode icon row have never been looked at on a
  real map. That is the one check left that cannot be automated.
- **`water_reflection` is vanilla's, scaled.** The 3x3 beacon's reflection sprite with
  `scale` taken 5 → 8 and its shift with it. Proportionally right, visually unverified, and
  the only piece of the entity's art not rendered for it.
- **`thumbnail.png` is done** — see **Portal images** below. What is still open is whether the
  Aquilo screenshot is the right hero shot at all; it was picked because the frost and the
  crystal read well at 144px, not after comparing alternatives.
- **`max_health = 600` has two defensible anchors and sits on neither.** Every 5x5 vanilla
  building is 350 (foundry, cryogenic plant, electromagnetic plant, biolab); the nuclear
  reactor is 500 and the fusion reactor 1000. Scaling the vanilla beacon's own 200 by
  footprint area instead lands near 550. So 600 either overshoots the building family or
  roughly matches the beacon lineage, depending which family this belongs to. Left as it was;
  it is a one-line change either way.
- **`draw_animation_when_idle = false` is undocumented and has no precedent anywhere.**
  `prototype-api.json` gives it no description, and nothing in base, quality, space-age,
  Krastorio 2 or Space Exploration sets it — vanilla's beacon top is `repeat_count = 45`, a
  static frame, so vanilla never had an animating beacon to test it against. The reading this
  mod assumes is "the animation freezes when idle"; the other reading is "the animation is
  not drawn when idle", which on this entity would mean an **invisible idle beacon**, since
  the plinth and rings are both animation-list elements. The redundancy argument favours the
  first reading — `always_draw = false` per element already expresses "only while working",
  so a set-level flag meaning the same thing would have nothing to add — but that is
  inference, not evidence. **Check it first of everything, the moment the mod is in a game.**
  If it is the bad reading, delete the line: the default is `true` and the arcs already carry
  `always_draw = false`, which is the behaviour that was actually wanted.
- How many beacon variants? "Beacons" was plural in the brief but only one is built.
- Remnants and dying explosion are **done** — `prototypes/beacon/remnants.lua` (corpse
  `pure-beacon-remnants`, two variations) and `prototypes/beacon/explosion.lua`
  (`pure-beacon-explosion`, sized against the cryogenic plant, plus a tinted crystal
  particle). The measured vanilla conventions behind both — remnant grammar, the
  63-67 luminance band, the dark scorch fringe — are in the `factorio-graphics`
  skill. The fuller design write-up is `.ai-support/pure-beacon-design.md`.

## Working here

- The skill table in `../CLAUDE.md` applies unchanged; invoke them before the work, not after.
- Commit scope is `pure-modules-realk`, e.g. `feat(pure-modules-realk): add pure speed module`.
- `README.md` and the `info.json` / locale descriptions are player-facing and go to the mod
  portal — `README.md` becomes the portal description verbatim, via `fmtk details --readme`.
  So a claim that is only true on one track has to be checked against the branch it ships from.
- `LICENSE` at the mod root is the GNU GPLv3 text, copied verbatim from the repo root's
  `LICENSE` — see the repo `CLAUDE.md` → License. Keep the two in sync if the root copy is
  ever refreshed.
- Design notes live in `.ai-support/pure-beacon-design.md` — one consolidated file
  covering the beacon's lore, look, materials, animation, remnants and dying explosion.
  Follows the repo-wide default: tracked, ships nowhere (not to the mod portal, not into
  the zip). Anything that generalises beyond this mod belongs in a skill under `.claude/`
  instead.
