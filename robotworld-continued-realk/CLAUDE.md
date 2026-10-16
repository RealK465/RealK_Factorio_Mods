# CLAUDE.md — Robot World Continued (RealK)

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

**A fork and Factorio 2.1 port of thinkong's Robot World Continued, which itself continued
GamingComet's Robot World.** Startup settings scale robots, roboports and inserters; an Early
robots dropdown unlocks robots from the start with cheap recipes and four cheap early
technologies, and two toggles add a freeplay quick start kit and a starting power armor MK2.
Behaviour is upstream's except for what `.ai-support/decisions.md` records: the bug fixes under
*What the port changed*, the consolidated *Settings*, the Krastorio 2 quick start additions and
the starting power armor.

**Not our design.** The ideas, the numbers and most of the code are upstream's, and the credit
for them stays visible in `README.md` and `UPSTREAM-LICENSES.txt`. Treat a design question as
"what did upstream intend" before "what would be better".

**Published 2026-10-16 as 0.1.0, then 0.1.1, for Factorio 2.1**; `git tag -l
'robotworld-continued-realk_*'` is the list of what shipped.
**The data stage loads clean on 2.1.17 and 2.1.22, with every expansion and with none, at default and at
edge settings, and quick start, the starting armor, the early robotics flags and the AAI
Containers and Factorissimo 3 interactions were proven on created saves. Nothing has been
played.** See `.ai-support/deferred.md`.

Read `.ai-support/index.md` first. Decisions and their reasons are there, not here.

## Rules worth not re-deriving

- **Every setting and technology name carries the `rwcr-` prefix.** The owner chose it over
  upstream's bare names; settings therefore do not carry over from upstream, and the mod is
  marked incompatible with both originals. Do not drop the prefix for a "drop-in" convenience.
- **No globals in the data stage.** It is one Lua state shared by every mod, and upstream's
  global helpers were a collision waiting to happen. Helpers live in `prototypes/lib.lua`,
  returned as a module and required as `lib` — never as `helpers`, which would hide the
  engine's `helpers` global.
- **A robot's item is the one whose `place_result` names it**, never a name guessed from the
  entity's. That one rule covers every mod's naming, which is why there is no per-mod case.
- **Multipliers run in `data-final-fixes.lua`** so robots, roboports and inserters from other
  mods are scaled too. Moving them earlier silently stops covering modded entities.
- **Any recipe this mod changes after the recycler's `data-updates` must have its recycling
  recipe rebuilt** (`generate_recycling_recipe`), or it recycles into the old ingredients.
- **Quick start goes through freeplay's `get_created_items` / `set_created_items` in
  `on_init`**, never `on_player_created`. Freeplay then hands the kit to every new player and
  handles the crash-site cutscene itself.
- **A flag set on a `LuaForce` by script is lost on every technology reset**, so it is re-applied
  in `on_configuration_changed`, `on_technology_effects_reset`, `on_force_reset` and
  `on_force_created`. Early ghosts and the logistic network button work that way.
- **Hidden robots and hidden roboports are never scaled.** They belong to other mods' own
  mechanics — Factorissimo 3 sizes its in-factory roboport to the factory floor.
- **A mod that redefines a recipe this mod unlocks early must load first**, through a `(?)`
  dependency, or it re-locks the recipe. Load order follows dependency depth, so name
  order is no guarantee; AAI Containers is the measured case.
- **Equipment fuel comes from the equipment's own `burner.fuel_categories`**, never from a
  named mod or item. That is what makes Krastorio 2's nuclear reactor work without a K2 branch.
- **Testing anything in `on_player_created` needs `--benchmark-graphics`**, not `--create`:
  only the graphics run makes a player. `.ai-support/journal.md` has the probe set-up.
- **Factorio 2.1 only — there is no `legacy/2.0` build.** Upstream's own 2.0.0 serves 2.0.

## Layout

```
info.json                      2.1; `!` robotworld and robotworld-continued
settings.lua                   every startup setting, grouped by `order`
data.lua                       -> prototypes/early-unlocks.lua
data-updates.lua               -> prototypes/cheap-recipes.lua
data-final-fixes.lua           -> prototypes/multipliers.lua
control.lua                    the quick start kit, the starting power armor and the early robotics flags
prototypes/lib.lua             setting(), energy scaling, recipe helpers
prototypes/early-unlocks.lua   early recipes and the four rwcr-early-* technologies
prototypes/cheap-recipes.lua   cheap robot, chest and roboport recipes
prototypes/multipliers.lua     robot, roboport and inserter scaling
locale/en/robotworld-continued-realk.cfg
changelog.txt
README.md                      portal description, with the credits
LICENSE                        GPLv3
UPSTREAM-LICENSES.txt          upstream's MIT notice and the original's Unlicense; ships
thumbnail.png                  144x144, upstream's thumbnail upscaled
.ai-support/                   start at index.md
```

## Upstream

`https://github.com/thinkong/Robot-World` — the port is from its commit `cb9bd77` ("update for
2.0", upstream version 2.0.0). If upstream ever ships a 2.1 build, compare it against this one
before porting anything across; the `rwcr-` names mean nothing transfers by copy.
