# Quality maths, recycler mechanics, and how closed loops fail

Space Age 2.0 mechanics carry into 2.1 except where a 2.1 change is named. Community claims name
their source; first-party claims are from the wiki, the FFFs, or the shipped data.

## 1. The roll

Chance that a craft's output is upgraded, per module, by module tier and the module's own
quality (wiki, cross-checked against FFF-375):

| Module | Normal | Uncommon | Rare | Epic | Legendary |
|---|---|---|---|---|---|
| Quality 1 | 1% | 1.3% | 1.6% | 1.9% | 2.5% |
| Quality 2 | 2% | 2.6% | 3.2% | 3.8% | 5% |
| Quality 3 | 2.5% | 3.2% | 4% | 4.7% | 6.2% |

Chances add across slots (4x legendary Q3 = 24.8%). Given an upgrade, the size of the jump
distributes 90% one tier, 9% two, 0.9% three — *"each additional step has 10 times lower
chance"* (FFF-375, dev-authored).

Two rules the layout depends on:

- **Crafting with quality-X ingredients sets the output floor to X, deterministically.** That is
  why the terminal machine's output is purely target quality.
- **Ingredient matching is exact per tier** — you cannot combine uncommon plates with rare
  batteries. That is why a rolled-up ingredient jams a pinned machine, and therefore why the
  blacklist inserter exists.
- **Fluids are exempt from quality entirely.**

2.1.12/2.1.13 added `LuaQualityPrototype.roll_quality()` and `get_roll_chances()`, so a mod can
ask the engine for real odds instead of embedding this table.

## 2. Module placement — the correction to folklore

*"Quality below target, productivity at target"* is optimal **only for normal-quality modules**.
The wiki's own tables shift productivity-ward as module quality rises — legendary Q3 modules in
an electromagnetic plant want 1 quality + 4 productivity even at the normal stage. The optimal
split is a function of (machine x module tier) and is sometimes fractional across a bank.

**The terminal rule is universal**, though: quality modules on the target-tier machine are pure
waste — there is nothing above the ceiling to roll into — and productivity strictly beats empty
slots. Every machine/tier row of the wiki tables ends `0 quality + N productivity`.

Field note: terminal-productivity is common but not universal in the decoded sample. Several
hand builds run the terminal machine bare or on quality. The rule stands on the maths, not on
majority practice.

## 3. Loop economics

All 2.0-era analyses; mechanics unchanged.

- **Pure recycler-only loop** (no crafting stage): ~14,430 base items per legendary at 10%
  chance, ~2,727 at 24.8% — independently derived by dfamonteiro and exyr.org, matching numbers.
  An order of magnitude worse than craft+recycle. This, plus the fact that **no shared
  recycler-only design was found anywhere**, is why self-recycling items are refused for now.
- **Craft+recycle loop** input-to-legendary efficiency: ~1.25% (assembling machine 3), ~7.6%
  (electromagnetic plant), ~14.5% (cryogenic plant). Slot count and built-in productivity
  dominate.
- **Machine choice genuinely matters and depends on the player's module tier** — electromagnetic
  plant (5 slots, +50% built-in, Fulgora), foundry (4 slots, +50% even on recipes where
  productivity is normally forbidden, Vulcanus), cryogenic plant (8 slots, no built-in bonus,
  Aquilo, wins on slot count at high module tiers). That is the argument for the machine picker
  being a player input rather than an auto-pick.
- **~300% total productivity makes a recycle loop break even** (0.25 x 4 = 1). Wube sized the
  `maximum_productivity` cap (default 3.0) for exactly this (FFF-375). Built-in +50% counts
  toward the cap, not on top of it.
- **Tier sizing tapers ~10x per step** for sustained throughput (e.g. chemical plant: ~332
  normal + ~39 uncommon + ~11 rare + ~3 epic machines plus ~90 recyclers per one sustained
  legendary crafter). **The compact one-machine-per-tier column is a convenience casino, not a
  throughput build.** Worth saying honestly in the GUI or docs. If scaling is ever added, scale
  *columns per tier* — the wild "bulk" variants put 3 machines in a column and keep the same
  skeleton.
- **Recycler timing**: recipe energy `craft_energy / 16 / result_count`, recycler speed 0.5, so
  wall-clock is about `craft_time / 8` — and **multi-output recipes recycle slower** by the
  `result_count` divisor. This is a documented community trap and the scaling changed again in
  2.1.13, so read generated recipes from `prototypes.recipe` rather than re-deriving.

## 4. Known failure modes of closed loops

- **Direct-insertion deadlock.** A quality-moduled machine direct-inserting into a fixed-quality
  consumer jams when off-quality output has nowhere to go. The eject + blacklist pair is the
  reference design's built-in fix; our layout inherits it.
- **Variance is not imbalance.** Closed loops show wild short-run skews (10:1 reported).
  Rseding91's ruling: random is random, it balances over hundreds of hours. The fix is buffer
  chests per item x quality plus overflow valves — our capped buffer chests are the small-scale
  version.
- **Quality-switch waste.** Single-machine circuit-driven designs recycle their buffered
  lower-tier ingredients when the live `recipe_quality` switches up (the design's own author
  documents this). One reason to pin one machine per tier instead.
- **Requester under-requesting.** 2.0-era parameterised books stall when the request is smaller
  than `recipe amount x batch`. The mod computes real counts from the recipe, which is one of
  the concrete things it does better than a blueprint.
- **Power-loss lock-ups** reported for combinator-driven designs. The belt ring's throttles are
  stateless conditions, not latches, so this does not apply.
- **Patched exploit, do not implement**: the speed-beacon swap mid-craft (quality is rolled at
  craft start) — dead since 2.0.17.

## 5. Prior art and demand

- **No mod generates upcycler layouts.** `upcycler` and `quality-condenser` replace the mechanic
  with a magic machine; `quality-cycler` edits quality inside an existing blueprint;
  scottmsul/upcycle and the exyr / dfamonteiro analyses stop at numbers; shared "smart upcycler"
  posts are hand blueprints with manual chest and inserter setup.
- Explicit player requests for automation exist on the forums, and some of the demand is a
  **discoverability gap** — players not knowing that quality modules work in a recycler at all.
  That is an argument for the GUI surfacing derived facts (footprint now, expected output
  later) rather than being a silent generator.

## 6. Out of scope, and why

- **Asteroid-chunk reprocessing laundering** — dead since 2.1.7, which disallowed quality
  modules on crusher reprocessing recipes (first-party, in the local changelog).
- **Biter-egg / spoilage tricks** — ordinary recipes with a farm input; the generic loop covers
  them.
- **The LDS "blue chip casino"** — a recipe-choice heuristic (expensive single-ingredient
  intermediates), not a distinct mechanic. The generic loop handles those recipes natively.

## 7. Sources

wiki.factorio.com `Tutorial:Quality_upcycling_math`, `Quality`, `Recycler`, `Productivity`,
`Electromagnetic_plant`, `Foundry`, `Cryogenic_plant`; factorio.com/blog/post/fff-375;
dfamonteiro.com pure-recycler-loop and recycler-assembler-loop posts;
exyr.org/2026/solving-factorio-quality/; forum threads t=121438 (the reference lineage),
t=122116 (single-machine), t=124099 (bot cell), t=120584 (variance ruling), t=118900 and
t=121103 (recycle-time formula), t=127564, t=128439; github.com/scottmsul/upcycle;
factoriobin posts 8wj94j, whtgdo, yjaf28, a10b2v.
