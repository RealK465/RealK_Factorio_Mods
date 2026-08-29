# Upcycler Planner — journal

What happened, newest first. **Append-only**: a past entry is a record of what was true and
believed at the time, so it is never edited, even once superseded. What is true *now* lives in
`decisions.md`; the evidence lives in `analysis/`. Never ships (leading dot).

Entries are added in the session that produced them. When this file passes ~800 lines, move
everything older than the last release into `journal-archive/<year>.md` and leave a pointer.

---

## 2026-08-29 - the review fixes reach Factorio 2.0, and both tracks gate on every tier

The full-review delta (entry below) cherry-picked onto `legacy/2.0`: both forked files
auto-merged and were read by hand rather than trusted, which is what caught the one hunk
that could not cross -- `quality_downgrades()` reads `previous_probability` and its chain
twin, neither of which exists on 2.0.77's `LuaQualityPrototype` (the read family is
2.1.7's, and a missing LuaObject attribute is a hard error, not nil). The legacy probe is
now a constant false with the seam documented in place: 2.0 has no downward roll at all,
so the solve's downgrade sweep never arms there. Everything else crossed verbatim; the
drift check lists exactly the declared divergent set.

The owner's ask widened the gate to every tier on BOTH tracks, and all of it is green:
data stage exit 0 (1.0.0 on 2.1.16, 1.0.1 on 2.0.77 with `data-final-fixes.lua` loading),
pure 92/92, static clean, headless 332/332, and a graphics pass through a real client on
each install. Docs rode the same session: the review's changelog Bugfixes block moved
ahead of Changes to match the file's own order, the `### Roboports` heading the review's
deferred.md edit had swallowed was restored, and the mod CLAUDE.md's suite count moved to
332. Both branches committed and pushed.

## 2026-08-29 - a full review of the mod; ten fixes land, one question parked

A ten-angle review of the whole runtime source (owner's ask, performance named the
priority). The suite stayed green throughout: pure tier 92, in-game 332, static clean.

What it found and this session fixed, all on `main` (the legacy cherry-pick is still owed):

- **`settled_on` compared raw stored values against normalised writes** - a build quality is
  nil until first picked while the button always reports one, and the `no_*` flags flip
  nil->false - so the very click that opens a picker's chooser read as a change: a full
  re-solve per first click, and with a rates-invalidated wizard open a rebuild that tore the
  opening chooser down (the recycler and productivity-module pickers' visible flash). Fixed
  centrally: `settled_view` normalises `_quality$` and `^no_` keys on both sides of the
  compare, the machine handler's own measured rule generalised.
- **A browse click on an empty terminal-module or beacon-module picker recorded an explicit
  clear** (`no_*_module = true` from the click leg's nil elem_value), permanently detaching
  the default from the machine-and-recipe pair. Both handlers now treat nil-value-on-
  already-empty as a browse and return.
- **The pole ladder re-ran on every refresh** though most refreshes move no geometry. `plan()`
  now keys the ladder's geometric inputs (footprints, tier count, consumer names, pole,
  fluid/tap flags) and a hit replays the won column gaps and pole placements through one
  `layout.build` - `append_poles` copies on every hand-out, so the cached poles are never
  aliased. Deterministically the same answer; the plan determinism specs exercise the hit
  path by construction. `layout.build` also stopped rebuilding identical ingredient-filter
  tables per physical column (shared per quality; the per-column `requests` stay fresh, the
  circuit pass mutates those).
- **`sets_per_recycle` was per recycling CRAFT, not per recycled item** - a modded recycling
  recipe eating >1 product per craft inflated S by that factor, skewing the split and
  overstating yield while the pace's own `items_per_craft` read disagreed. One shared
  `recycling_items_per_craft` now feeds both; a zero-amount modded product no longer divides
  the fallback into NaN yields.
- **Down-rolling quality mods (previous_probability) were priced as successes** by the
  complement in `quality_math.solve`. A `downgrade` flag (planner detects it from the chain,
  memoised) subtracts the below-tier mass - value 0, the recyclers' own rule - with the
  sweep gated so no real modset pays it. Pure spec added.
- **The circuit wizard never refreshed on a commit**, leaving validate's `circuit-min-too-big`
  and unlinked warnings stale until an unrelated pick; it now refreshes when the value moved,
  the ratio fields' rule. The stored read is type-guarded, as are the `circuit_min/max_` and
  `split_prod_` reads in the planner (the request/column families already were) - a
  hand-edited save can hold anything and used to crash the refresh.
- Smaller: the chooser presumption arms only on LEFT clicks (a right-click cleared nothing
  and cost the next E a close); `plan()` refuses a beacon whose `max_beacon_count` is 0
  instead of flooring to one and building across the ring (validate's own refusal, now on
  the direct-call path too), and `beacon_transmitted_effects` prices such a beacon as none;
  the columns and split wizards display through the plan's own clamps (a stale stored count
  can no longer show one number while the plan builds another); the empty-target-list
  drop-down no longer sets an out-of-range selected_index; `poles.column_at` is the one
  owner of the column-containment search (the shrink ladder had a hand copy); the
  split/limits buttons' enabled state has one owner (gui.refresh); validate's redundant
  target-existence guard folded into the `tiers_up_to` gate.

The gap sweep after the first pass added four more, all fixed: **the shrink ladder could
re-solve forever** - a column the layout floors open (the beacon's lane) can regain a pole
and re-grow its gap, so the "only ever collapses" termination argument fails and a
deterministic two-pattern orbit froze the game; the walk now remembers visited gap patterns
and a revisit breaks. **`recycling_closes_the_loop` counted product entries, not distinct
names**, refusing a hand-written recycling recipe that splits one ingredient across a
guaranteed and a probability row (and `sets_per_recycle` now SUMS such rows instead of
overwriting). **The chest and inserter handlers lacked the outside-the-role snap-back guard**
their sibling pickers carry (an empty candidate list leaves a picker unfiltered); the pipe
and quality-module handlers took the same guard. And **the min-too-big warning compared one
chest's capacity** where a capped repeated tier fills N summed chests - it now follows the
same cap resolution plan() applies.

Two flagged behaviours were left deliberately: the backfilled circuit cap surviving an item
change and the empty-Enter zero-commit are both recorded owner decisions (`decisions.md`,
circuit limits) - re-surfaced to the owner with the stack-1 scenario rather than changed.
The summed-vs-per-chest reserve reading under repeated columns is parked in `deferred.md`
with both resolutions costed; the machine picker's no-snap-back on clear is pinned by
gui_spec and stands.

## 2026-08-29 - the optimization delta reaches Factorio 2.0

`git cherry-pick 302fc0f` onto `legacy/2.0` auto-merged all fourteen files, the two forked
ones it touches included (`scripts/planner.lua` took the held-scan binary search, the cap at
64 and the `balanced_columns` deletion without disturbing the roll shim or the recipe-shape
seams; `tests/planner_spec.lua` took the spec swap beside its per-track figures).
`scripts/poles.lua` is a shared file and carried the whole rewrite as-is. The drift check
(`git diff main -- .` from the worktree) still lists exactly the declared divergent set.
Verified on 2.0.77 from the legacy worktree's own skill copies: data stage exit 0 as 1.0.1,
pure 91/91, in-game suite **331/331** — the same count as `main`. Both branches pushed; the
open 1.0.0 / 1.0.1 pair can now ship in order whenever the owner calls it.

## 2026-08-29 - the cap doubles to 64; the balanced hint leaves the columns wizard

Two owner calls the morning after the optimization pass, taken together. **The cap**:
"maybe we can now increase max columns to 64?" — measured before applied: with the
near-linear solve, 64-column plans cost proportionally (host: vanilla 5 tiers x 64 = 257
columns in 0.05 s; a 35-tier mod at full 64 = 2177 columns in 0.55 s, 1.5 s with a 5-wide
machine and fluid; even 254 x 64 = 16,193 columns solves in 4.5 s where the old code
squared toward hours), so `MAX_COLUMNS_PER_TIER` went 32 → 64. In game (2.1.16, one
refresh's validate + plan): vanilla legendary x 64 is 171 ms, the 35-tier mod at full 64
(2177 columns, 46k entities) 1.67 s — the exact linear doubling of its x32's 780 ms, on
the shape whose x32 the old code needed 46.7 s for. Every clamp spec was symbolic and none
moved; the tooltip takes the cap as a locale parameter and followed by itself.

**The hint**: "and remove the ideal counts of the bottom" — the balanced-columns line (and
its no-flow placeholder and separator) left the bottom of the Columns wizard, which is now
rows and nothing else. With it went `planner.balanced_columns` (dead code once nothing
displayed it; `station_times` keeps one reader, the pace), the three locale keys, and the
columns panel's `rates` escalation — nothing in the panel is solve-priced any more, so a
module, mix or beacon change refreshes instead of rebuilding, and the escalation spec now
pins the panel SURVIVING those changes where it used to pin the rebuild. The
balanced-line spec became a nothing-below-the-rows / stores-nothing pin, and
planner_spec's balanced block reduced to the one claim that still gates behaviour: extra
lower-tier columns genuinely move the pace. README, changelog (open 1.0.0, edited in
place), mod CLAUDE.md, decisions.md and deferred.md all track both calls; the 1.0.0/1.0.1
pair now waits on a fresh legacy cherry-pick covering the whole 08-28/08-29 delta.

## 2026-08-28 - the pole solve goes near-linear; the big-layout hang closed by measurement

The owner asked for the layout generation to be optimized without regressions — big column
counts and long modded quality chains were slow to the point of the game being killed as
hung. Profiling on the worst legal shapes (254 tiers x `MAX_COLUMNS_PER_TIER` physical
columns) found every remaining super-linear term in `poles.lua` plus two column-membership
scans, and all of them were replaced by exact equal-output structures in one pass:
candidate centres cached at enumeration, the per-placement candidate-array rebuild replaced
by a dead set over a `dx` bucket index, the greedy cover's per-round rescans replaced by
exact incrementally-maintained gains under a lazy max-heap ordered (gain, scan position) —
the same first-in-scan-order tie rule, so no pick moves — `bridge` given memoised in-reach
pole lists extended one distance check per new pole (plus a round-stamped shared `touched`
table; the per-candidate table per round was itself a measurable allocation cost),
`components_of` and `spanning_wires` walked through centre-column buckets with the member
order and both spanning tie-breaks reproduced exactly, and the `within_columns` /
`plan_with_poles` dead-column scans turned into binary searches over the sorted disjoint
column list. `scripts/poles.lua` and one hunk of `scripts/planner.lua` are the whole diff;
layout, circuits, blueprint and quality_math untouched.

Headline numbers (full tables in `analysis/poles.md` → *Near-linear at physical-column
scale*, every pair taken back to back in one machine state): host, 2025 columns
58 s → 1.3 s; the full 8097-column ceiling 754 s → 4.9 s (~150x conservative), and the
8097-column 5x5 shape the old code never finished (killed past 20 min) now solves in 12 s.
In game on 2.1.16, timed around one refresh's `validate` + `plan` with a scratch mod adding
30 quality tiers: 35 tiers x 32 columns **46.7 s → 0.7-1.8 s** — and under the old code
that shape tripped factorio-test's 15 s stuck-process watchdog, which is the owner's
big-layout crash reproduced under measurement. Vanilla plans sat at ~10-25 ms before and
after.

Proven identical the way the 2026-08-20 pass taught: a 4416-config layout-grid parity sweep
(old file recovered from git) plus 1200 pseudo-random scattered plans for the bridge- and
tie-heavy shapes, every field of every pole compared, `wire_to` included — zero mismatches —
with both harnesses falsified first (a dropped spanning second-end tie-break trips 10 grid /
17 scattered configs; a flipped greedy tie trips everything). The pinned 8-tier wire tree
matches, pure 91/91, static clean, and the in-game suite 333/333 with zero behavioural
drift. The in-game timing ran through a temporary `tests/perf_spec.lua` (since removed with
its control.lua registration — throwaway harness, the 2026-08-20 rule) against a scratch
`upl-bench-quality` mod in the test data dir. One honest caveat kept in `deferred.md`: what
remains is the linear work itself, so the extreme ceiling still costs a few in-game seconds
per refresh — margin now, not a hang. The changelog gained an Optimizations line in the
open 1.0.0; `MAX_COLUMNS_PER_TIER` stays 32, raising it now being a product call for the
owner rather than a crash risk.

## 2026-08-28 - the columns feature reaches Factorio 2.0

The port turned out to be a clean cherry-pick: `git cherry-pick f504c16` onto `legacy/2.0`
auto-merged all eighteen files, the three forked ones included — the columns delta touches
none of the fork hunks (the 2.0 roll shim, the recipe-shape seams, planner_spec's per-track
figures all sit elsewhere), so nothing needed rewriting by hand. The drift check
(`git diff main -- .` from the worktree) still lists exactly the declared divergent set.
Verified on 2.0.77 from the legacy worktree's own skill copies: data stage exit 0 as 1.0.1,
pure 91/91, static clean, in-game suite **333/333** — the same count as `main`, since every
new spec is in the shared files. The release-coupling warning in `decisions.md` is resolved:
the pair ships 1.0.0 (2.1) then 1.0.1 (2.0), whenever the owner calls it.

## 2026-08-28 - columns per tier, the owner's play-test revisions

The owner played the columns build the same day and revised four things, the third after a
crash:

- **The footprint left the stats.** The counts line now reads machines/recyclers only and
  carries `Footprint: W x H tiles` as its tooltip — worth a hover, not a stats row. The line
  keeps its `upl-stat-layout` name; the keystroke spec pins the machine count moving instead
  of the caption's old nested pair.
- **The Ingredient amounts and Columns per tier rows moved into Build options**, directly
  above the Circuits group whose label-plus-button shape they share ("maybe at top of
  circuits" — they tune the build, not what the loop makes). One `edit_row` helper builds
  both strips; the top block is back to the four MAKES picks.
- **The balanced Apply button is gone.** One click on a big layout wrote several large
  counts at once and asked the engine for a plan it could not survive — the game crashed.
  The balanced line stays as a hint (with a tooltip saying what it is), so a count now
  arrives one capped field at a time; the `columns-balanced` handler, its locale pair and
  the hint-equals-write spec went with it, the spec replaced by hint-matches-
  `balanced_columns` plus button-is-absent.
- **The cap came down 250 → 32** (owner's call, mid-session): a performance ceiling now,
  not a ratio-clearing one — the AM3 sustained ratio of 208 is deliberately out of reach —
  and the wizard field's tooltip names the cap and the reason, the number riding in as a
  locale parameter so it cannot drift from `MAX_COLUMNS_PER_TIER`. Every clamp spec was
  already symbolic, so none moved.

Same-session register rewrites: decisions.md (columns contract, ingredient-amounts entry
point, status-area shape), mod CLAUDE.md, README, changelog (all inside the open 1.0.0 —
the balanced-button sentence never shipped, so it is edited away rather than changelogged),
deferred.md's pole-ceiling note (254 x 32 now, ~8x smaller worst case). The port-before-
release coupling stands.

## 2026-08-28 - columns per tier: the deferred scaling entry ships

The deferred entry "Scaling beyond one machine per tier" shipped along its own recorded shape
— repeat columns, never new geometry — after the owner's four calls from offered options:
lower tiers only (the target keeps the single output chest the tap, catcher and cap stand
on), a Columns per tier row in the top block opening a fifth side panel, a balanced-counts
line with a button that fills it in, and the 250 cap, picked over 20 and 99 with the
modded-chain solve cost named and accepted.

The architecture surprise: **layout.build needed zero changes.** With the target pinned to
one column the expansion never repeats the last entry, so `is_terminal = index == #tiers`
stays true, `machines = #tiers` / `recyclers = #tiers - 1` count themselves right, and the
whole geometry follows from expanding the tiers array in `planner.plan` — `tier_columns` /
`expand_columns` (one expander, run over the chain and over the split's counts alike),
`plan_with_poles` and `circuits.decorate` just receiving the longer array. circuits, poles,
blueprint and quality_math untouched; the solve keeps the distinct chain, since expanding it
would corrupt the probability model. The old `loop_seconds` split into `station_times` — the
one owner both the pace divider and `balanced_columns` read — respecting the "reconciliation
written twice" complaint from birth.

The wizard is the ratio wizard's mechanics with the ingredient panel's floor: only-on-edit
`column_count_<quality>` keys, empty-plus-Enter deletes, every keystroke refreshes (footprint,
counts and pace all follow), and the balanced numbers ride the Apply button's own tags so
the write cannot drift from the display. Escalations: the target dropdown, the three module
pickers, and the Mix checkbox — the first checkbox to escalate, since unticking it moves
every station time. The review pass then caught the beacon module and count handlers still
refresh-only — stale balanced numbers a click could WRITE, worse than the ratio wizard's
older display-only version of the same gap — so both escalate now too, the fix pinned inside
the escalation spec by a rebuild-proving assertion (the old panel reference must die). The
conventions reviewer caught the wizard's strings saying "Balanced ratio" — the word the
vocabulary table reserves for the module mix, the Buffer-chest collision class exactly — so
every player string now says "balanced columns", the table gained the row, and the stale
"exact array the wizard is keyed by" identity claims in circuits.lua and the circuit
wizard's header were reworded for the expanded-array reality. README's "one column per
quality" line was corrected the same hour it became false. A third, template-driven review
(the owner's /requesting-code-review) returned no Critical findings and "ready": its catches
— the balance-matches-pace assertion was a <= tautology, strengthened into a guarded strict
improvement; a beacon-stacks-per-column pin was missing; the balanced comment over-promised
what round-to-nearest delivers; and research finishing mid-modal is a staleness window now
acknowledged in decisions.md as chosen (the frozen-tags reasoning), beside the release
coupling: the shared changelog puts the feature in 1.0.0, so the pair must not ship before
the legacy port.
Suite 333/333 with 29 new specs (layout and circuits pin the repeated-
tier premises pure; plan pins byte-identical defaults via deep_equal, the pace direction and
the yield's indifference; gui pins the five-panel slot, the keystroke repaint and the
hint-equals-write rule), static clean, data stage exit 0. The 2.0 port is deliberately
deferred to the end of the effort, the owner's call.

A four-angle cleanup pass (the owner's /simplify) then reshaped the seams without moving
behaviour, suite green throughout. The per-handler escalation disjunctions — which all
three reviewing angles flagged, and which had already leaked once — became declarations:
`SIDE_PANELS` entries carry `invalidated_by = { tiers, rates }` and one `gui.invalidate`
decides rebuild-or-repaint. The two solve-priced wizards' fields share one `override_count`
handler, bounds riding the tags, and a commit that moves nothing no longer re-designs the
loop (Enter after typing was paying a full plan for a value already committed). Apply
repaints its fields in place instead of rebuilding the modal — `balanced_columns` reads no
column key, so the recomputed line was provably identical. `expand_columns` replaced the
source-map re-key (one expander over the chain and over the split's counts, the terminal
hole pinned by a spec); `balanced_columns` lost its hand-copied restatement of `split`'s
preconditions and its dead `gathered` parameter; and the storage family was renamed
`column_count_<quality>` — the two-token prefix the other tier-keyed families already use,
so the prune sweep can never claim a future `columns_*` flag. Free only because nothing
had shipped. Deliberately left: the nine-argument `station_times` signature (a params
table trades churn for little), the plan/layout spec number overlap (the two-tier split is
the suite's own design), and a shared spec choices-builder (three pre-existing copies —
a spec-wide pass, not this one).

## 2026-08-28 - the open pair re-graded to 1.0.0 / 1.0.1

The owner's call, closing the arc the feature opened under ("the first step for the 1.0.0
version"): the still-open 0.7.0 / 0.7.1 pair becomes **1.0.0 (Factorio 2.1) / 1.0.1
(Factorio 2.0)**. Both sections were unreleased and untagged, so this is the sanctioned
open-section re-grade — headers and both info.jsons moved together, the 1.0.1 pointer
re-aimed at 1.0.0, and deferred.md's live references updated. Not a save-breaking major in
the semver sense; a milestone number, the owner's to give. Earlier entries below keep the
0.7.x names they were written under, as history does.

## 2026-08-28 - "find a way": the roll shim takes the whole feature set to 2.0

Hours after the partial port below shipped, the owner overruled its central premise: "try to
somehow port everything we did to 2.0 find a way to do it." The way was already latent in
two places. The solver never knew the engine existed — `params.roll_chances` is an injected
function — and the breaking-changes reference states 2.0's roll semantics outright: quality
effects are stored x10 and the true one-step chance is `effect x next_probability`, vanilla
np 0.1 on every tier. So the legacy planner's `roll_chances_for` became THE 2.0 ROLL SHIM: a
chain walk over `prototypes.quality` via `next`/`next_probability`, raw x10 effects in, the
x0.1 conversion landing exactly once — which makes the whole pipeline scale-coherent with
zero other changes, since module effects, beacon transmission and the recycler sum all stay
raw and only ever become chances through that one function.

With the solve alive on 2.0, the fork collapsed instead of growing: legacy `planner.lua` and
`gui.lua` are now main's files plus the four documented seams (recipe categories, the
allow_quality bridge, pipe volume, `contains_value`) plus the shim; `gui_spec`, `plan_spec`
and `blueprint_spec` went back to shared verbatim; `planner_spec` stays forked for the 212
pin and for premises that pin the shim digit-for-digit against §30's measured engine
distributions — plus a np=0.1 ground-truth walk, so a modded chain retune fails loudly.

First run: 303/304. The one failure was a measurement, not a bug: legendary q3 reads 0.62 on
2.0, not the curve's 0.625 — the wiki's "6.2%" was never rounding, it was 2.0's real value,
and 2.1 is what changed it to the exact 0.0625. Pinned per track; no optimum moved. Second
run 304/304 — full parity, the EM optimum, the 2161 crosscheck, the beacon kill-and-outweigh
cases all identical through the shim. Static clean, data stage exit 0 at 0.7.1, and the
0.7.1 changelog section simplified to the standard pointer: "Version 0.7.0, ported to
Factorio 2.0." The README and faq lost their 2.1-only scoping the same hour it stopped
being true.

## 2026-08-28 - the 0.7.1 port: the status area crosses to 2.0, the mix stays home

The owner's call after committing 0.7.0 (`bd58dc5`, main): port to `legacy/2.0`, keep both
branches committed and pushed. The split fell exactly along the API line. Portable: the
status-area redesign (pure GUI), hand-ported into the forked `gui.lua` minus the yield and
pace lines it has nothing to feed. Not portable: mix, yield, pace — all standing on
`get_roll_chances`, which 2.0.77 does not have. Shared files crossed verbatim
(`quality_math.lua` and its pure spec run happily on 2.0, the solver just has no caller
there; layout/blueprint/state/control degrade to the flat shapes), with one seam:
the shared `state.lua` prunes the 2.1-only productivity pick through
`planner.is_productivity_module`, so the forked legacy planner gained that one membership
test — a save coming back from 2.1 prunes cleanly instead of crashing.

The spec forks grew: `gui_spec`, `plan_spec` and `blueprint_spec` joined `planner_spec` on
the divergent list (repo `CLAUDE.md` updated on both branches), because 0.7.0 filled them
with 2.1-only surface. Legacy's `gui_spec` took the adapted status-area describe — both
icon premises hold on 2.0, quantum-processor refuses there too, and the big-pole stacking
geometry carried over unchanged. Legacy is 0.7.1, changelog section open on BOTH branches
("the module mix and the yield and time lines stay Factorio 2.1 features"), suite 280/280
on 2.0.77 first run, static clean, data stage exit 0. Both branches pushed; neither
released.

## 2026-08-28 - the pace line: the solve learns to count its own crafts

Third ask of the day: "add the time expected to the stats of quality." The yield knew how
many items a target item costs but not how much WORK, so `quality_math.solve` grew a
forward flow pass — expected ingredient-sets per machine and items per recycler, per one
target item out, riding the very distributions the chosen split was priced with (they are
now kept from the backward pass instead of re-rolled). Same per-tier self-loop, same
denominator, same 1e-9 floor; the two-tier hand fixture works out to clean numbers (2.5
sets, 0.25 terminal sets, 2.0 recycles per item) that conserve the output exactly, and a
dead loop (per_set 0) reports no flow at all, which is what the display keys on.

`planner.loop_seconds` turns crafts into wall-clock: steady-state, every station parallel,
the pace = the single slowest station's expected-crafts x craft-time. Rates fold in
`get_crafting_speed(build quality)` — new engine premise, spec-pinned — the module speed
penalties (`per_slot_effects` now carries the speed axis; q3's penalty is itself pinned so
the estimate cannot silently flatter), the beacon stack via profile x distribution
effectivity at beacon quality, and the engine's 20% speed floor. The recycling recipe's own
`energy` and ingredient amount are read, never assumed. plan_spec pins directions, not
numbers: legendary slower than rare, a speed beacon faster. The GUI adds one plain stat
line under the yield — "About one [target][item] out every N <unit>" — with
`duration_parts` picking seconds/minutes/hours/days so the number stays small and the unit
words stay in the locale. api.md gained §31. Suite 299 -> 304 on the first full run; static
clean.

The review then caught the first draft's real flaw: it credited a speed beacon's speed
while ignoring the quality malus the same modules transmit (§25 had documented the
mechanic all along), so the exact configuration the new spec blessed — speed beacons on a
normal-module loop — showed a shorter pace for a loop the beacons had in truth killed.
Fixed at the root rather than documented around: `beacon_transmitted_effects` is per-axis,
quality and productivity now feed the solve (machine base, recycler effect, memo key) so
the YIELD prices beacons too, and the pace spec was rewritten to pin both sides — an
efficiency beacon moves nothing, two speed beacons report a dead loop, one against
legendary quality modules is faster and honestly poorer. Plus the review's one-liners:
beacon module_slots asks the beacon_modules inventory, infinite worst returns nil,
duration_parts compares rounded amounts (119.7 s promotes to minutes), the split contract
comment names the arrays. Still 304 -- the pace test grew instead of multiplying; green on
the first run after the fix.

## 2026-08-28 - the status area: three kinds of line, three looks

Same day as the module mix, the owner's next ask: "improve the way the stats are displayed
... better distinction between layout shape stats, output stats and error/warning messages."
Three explorers mapped what existed — one `upl-status` label repainted whole, one flat
colour for the entire block, so a spoilage warning turned the footprint orange with it, and
the idle "Pick an item to upcycle." wore error red — and a survey of core's own style.lua
fixed the verified vocabulary (the orange_label/red_label families, `[img=utility/...]`
inline icons, `line` separators; no vanilla "warning_label" exists). The owner picked from
previews: structured rows over rich-text-in-one-label and over a bordered stats box; icons
on warnings AND errors; the wizard placeholders harmonized too.

The label became a vertical flow gui.refresh clears and rebuilds: stat lines plain white
(footprint+counts, then yield — moved UP beside its fellow stats, where it used to trail
the warnings), a separator, then one line per message — orange with the warning triangle,
or red with `not_available` on a refusal, stats absent since no plan exists. The empty
state became a grey hint, and `hint()` serves the three wizard placeholder sentences the
same grey. Both sprite paths pinned as engine premises (`is_valid_sprite_path` — an unknown
img tag renders as literal text, silently), the no-op-click sentinel moved from
caption-survives to child-label-survives, and the refusal spec found its item in the faq's
own example (quantum-processor, fluid alongside item). Three reviewers then tightened it:
the refresh's own hint branch now calls `hint()` instead of hand-rolling it, the key-match
half of that branch's condition states its why in place, the ingredients-panel hint assert
pins the key and not just the name, and a new stacking spec proves two warnings get two
separate lines — its pole-shortfall driver needed plan_spec's exact machine pinned, because
the EM plant's geometry lets the big pole cover what the assembler's does not. Suite
296 -> 299 (298 on the first run); static clean; the changelog gained its first Gui
section.

## 2026-08-28 - the per-tier module mix: pacak's ask became 0.7.0's open section

Started from portal discussion `6a9147f558087c568146a11d` (pacak: productivity modules in the
intermediate tiers, proposing a checkbox) and ended with the parked *Optimal module split* and
*Expected-output display* both shipped into an open 0.7.0 section. The owner made four calls
up front: computed best ratio as the DEFAULT rather than an opt-in; a third module picker
rather than reusing the final machine's; the yield display in the same release; 2.1-only,
legacy untouched. Then approved the risk-first architecture (probes before code, a pure
solver module, value-keyed memoisation) over the minimal inline variant.

**The probes came first and two of them corrected the plan.** `get_roll_chances` takes the
plain summed fraction, folds the whole chain in, and its `force` argument truncates at the
unlocked tiers — measured, so the solve deliberately omits it (plan-ahead-of-research,
validate's own stance). `get_module_effects("legendary")` returns the exact 0.0625, not the
wiki's rounded 6.2% — caught by the first spec run. And mixed modules in one blueprint
entity round-trip perfectly (encoder, decoder, item-request proxy), which retired the
per-tier-binary fallback unbuilt. All pinned as permanent specs; `analysis/api.md` §30.

**The solver is `scripts/quality_math.lua`** — pure, roll function injected, one closed-form
2x2 per tier from the target down, greedy provably global because quality never goes down.
Its wiki oracle missed on the first run: AM3-normal read 643 items per legendary against the
wiki's 2161, which settled a modelling fact — the wiki tables run ONE module quality
throughout, recyclers included, not its separately-stated fixed legendary recycler. With the
fixture corrected, both oracles pass, and the same numbers then came out of the ENGINE'S
roll chances in planner_spec — the pure stub and get_roll_chances agree to the wiki within
tolerance.

**The shape work stayed scoped**: `entity.modules` keeps its flat single-spec table
everywhere except a genuinely mixed tier, which becomes a two-spec array `items_of` fans
into two insert plans with contiguous stacks — so every pre-split plan is byte-identical
(the whole 276-test suite passed untouched the moment the wiring landed, because at normal
module quality the search reproduces the old rule exactly). The GUI grew the belt-shaped
productivity picker, the Ratios... wizard as the fourth SIDE_PANELS entry (ingredient
panel's only-on-edit storage — backfilling the optimum would freeze what research should
keep moving), the yield line on the status caption, and escalations so an open wizard
rebuilds when the target, the quality module, the terminal module or the productivity
module moves under it. One test premise broke on the way: `open_with_gears` defaults the
target to legendary at full research, so "rare has no row" was wrong twice over.

**The owner then revised the surface the same day**: a *Mix productivity modules* checkbox
(ticked by default, `split_enabled` nil-means-on) on its own line under the module pickers
as the opt-out, with
the productivity picker moved off the strip into the Ratios wizard as a labelled row above
the counts — the Circuits row's checkbox-plus-gated-button shape exactly. Unticking prices
no productivity module in the solve (the refusing-recipe path, the flag in the memo key),
parks the overrides for a re-tick, disarms the button and closes an open wizard. Two more
owner follow-ups landed the same hour: the mix line moved onto its own row under the module
pickers (a caption and a button crowd an icon row), and it now shows only where a mix is
structurally possible — `planner.mix_possible`, any productivity module fitting the pair,
research aside — hidden otherwise with show-all overriding, the pipe's fluid rule. One trip
on the way: the new handler was first registered above `settled_on`'s local definition and
captured a nil global — handlers live at the bottom of gui.lua for a reason.

Suite 257 -> 296 across all tiers (pure solver spec runs on host Lua and in-game; the
254-tier stress solves in ~106 ms in-game with the stub). The owner's first live session
caught the one gap the specs had not: the yield line repainted only on Enter, and typing
through the rows -- clicking field to field, which fires no confirm -- left the stats
sitting still while the plan underneath had already changed. Reproduced by a failing spec
first, then fixed: every keystroke commit now refreshes (one memo-missed solve each,
~0.1 s worst case at the modded ceiling). Four review passes ran before
wrap-up — three focused, one independent full-diff — and their findings landed the same
session: a stale `split_prod_` override on a productivity-refusing recipe no longer
outranks the missing module (the yield understated an otherwise-correct plan; regression
spec added), the productivity-cap arithmetic got one owner (`cap_productivity`), the
handler snaps back a pick the pair refuses instead of showing a module the plan ignores,
the productivity picker moved beside the quality module it shares slots with, and the
no-productivity sentence stopped blaming the recipe for what can also be the machine or
plain missing research. Static tier clean. 0.7.0 opened
with `Date: ????` and `info.json` bumped with it — the release itself, when asked for, is
single-track by design (2.1-only), which per the 0.6.6 lesson is exactly the shape that
needs the owner's explicit confirmation. For the eventual legacy sync: `layout.lua`,
`blueprint.lua`, `state.lua`, `control.lua`, `quality_math.lua` and the pure spec are
shared files and travel with the ordinary cherry-pick (the solver is pure Lua, fine on
2.0's interpreter); the forked `planner.lua`/`gui.lua` do NOT take the feature, so the 2.0
build keeps the flat rule with nothing to gate.

## 2026-08-27 - 0.6.6 / 0.6.7 shipped, and half a pair shipped first

The spoilage warning went out on both tracks: **0.6.6 for Factorio 2.1**, then **0.6.7 for
Factorio 2.0**. The entry above records the work; this records how the release went, because it
went wrong in a way worth not repeating.

**Half a pair was shipped and reported as done.** The owner approved "release it now" against a
prepared 0.6.6, which was the 2.1 build alone; that got uploaded, tagged and pushed, and the 2.0
half was left as a follow-up offer. The owner's answer was "no no not possible, ship also version
2.0". `factorio-release` says to ship a pair **2.0 first** precisely so the 2.0 section carries
the entries and the 2.1 one points at it - the offer to renumber had been made twice and not
taken up, and that was read as a decision when it was not. **The lesson is not "ask a third
time": it is that a mod on two tracks releases as a pair by default, and a single-track release
is the thing that needs confirming.**

**The recovery, and why it is shaped the way it is.** 0.6.6 was already public and cannot be
changed, so the documented pair shape was no longer reachable. Rather than duplicate the entry
into 0.6.7 - the Pure Modules 1.0.2/1.0.3 mistake - 0.6.7 was made the *mirror* of the usual
pointer: `Version 0.6.6, ported to Factorio 2.0.`, matching 0.6.5's own phrasing. The 0.6.7 zip
carries **both** sections, which is what keeps the rendered portal changelog honest now that
0.6.7 is the newest upload; shipping a section only into one track's file was the Pure Modules
1.0.4/1.0.5 mistake.

**`fmtk version` would have collided.** Legacy sat at 0.6.4 and the tool only increments, so it
would have produced 0.6.5 - already published, and rejected at upload. The number was set by
hand to 0.6.7 after a read-only portal GET confirmed it free. Worth remembering whenever the two
tracks have drifted apart in number: on the legacy branch, check the portal before bumping.

Gates before each upload: 257/257 headless on the target install, data stage exit 0 (with
`data-final-fixes.lua` loading on 2.0), and both zips verified by listing rather than by reading
`package.ignore`.
## 2026-08-27 - the spoilage warning, and two comments that pointed at the wrong thing

Started as "find a small safe thing to improve" and ended as a shipped feature, because the
measurement the small thing needed turned out to be the interesting part.

**The small things first.** Two stale comments, both comment-only, both verified against git
history rather than guessed. `scripts/planner.lua` carried the ten-line *shortest circuit-wire
distance* block above `planner.default_circuit_max`, because the 0.6.0 circuit-limits commit
(`0ad3bc6`) wrote both comment blocks in one edit and inserted the function between the block
and the `circuit_reach` it described - so one function wore a paragraph about wire reach and
the other read as undocumented. And `scripts/gui.lua`'s header still said the build options
were **five** captioned rows, listing Transport/Chests/Modules/Beacons/Power; Circuits became
the sixth in 0.6.0. `CLAUDE.md` and `decisions.md` both already said six, so the header was the
last place still wrong. `journal.md` says five too and was left alone - it is dated history.

**Then the spoilage question.** `deferred.md` had insisted it be settled by measurement before
anything was designed, and that was the right call twice over.

The first thing measurement caught was the note's own API spelling. `deferred.md` said to check
`prototypes.item[x].spoil_ticks`; **`LuaItemPrototype` has no such attribute**. The data stage
has one, the runtime does not, and reading it yields nil - so the obvious implementation would
have found *zero* spoiling items and shipped a guard that never fired, with nothing anywhere
raising an error. The runtime surface is `get_spoil_ticks(quality)`, a method, and it takes a
quality because spoil time genuinely grows with the tier (captive biter spawner: 108000 ticks
normal, 270000 legendary). Recorded as `analysis/api.md` S29.

The second was the answer itself, from a throwaway probe spec run through the real runner and
deleted after: of the 210 upcyclable items, **10** carry something perishable - `nutrients`
alone as the product, nine more through an ingredient. The row that decided the design was
**productivity module 3**, which takes biter eggs. That is a headline upcycling target, and
refusing it would have cost more than the guard saves - so the owner's pick of *warn* rather
than *refuse* was the right shape, and it is placed first among the warnings because it is the
only one that never resolves itself.

**What the owner asked for on top: "check if error messages/warnings are being properly
displayed."** They were - but nothing was stopping them from stopping. `gui.refresh` carries a
comment saying warnings "used to be silently dropped here, which made the warnings
unreachable", and `gui_spec` had **no** coverage of that branch at all: no test touched
`font_color`, `COLOR_WARNING`, or asserted a warning string reached the status caption.
`planner_spec` pinned that `validate` *returns* a warning; nothing pinned that the modal
*shows* one. A new `the status line` describe now covers all three colours - warning
(build-through, orange, footprint intact), plain, and refusal - and it caught one thing while
being written: the two branches of `gui.refresh` build the caption differently, a plan nesting
the message inside a concatenation and a refusal assigning the LocalisedString directly, so the
helper has to look in both places.

Locale cross-check came back clean: every `upl-message.*` key used in Lua resolves, none are
orphaned, and the run log carries no `Unknown key`.

Suite 253 -> 257. The two comment fixes and this feature are all unreleased; 0.6.5 is tagged, so
they open a new section rather than joining one.
## 2026-08-27 - 0.6.4 / 0.6.5 released on a timer, and the bump the owner declined

The owner asked for the pair to go out "around 16h" while they left for the airport, so the whole
release was prepared up front and the upload chain fired from a scheduled wake at 16:00:01. Both
uploads, the details sync and the git side ran unattended against work that had already passed
every gate; nothing was built or decided after the wake.

**The version number is the owner's, and it is not what the delta graded to.** The brief said
"minor update", and the unreleased delta - an additive, save-safe feature - grades to a semver
minor, so 0.7.0 / 0.7.1 was prepared first. The owner then asked for 0.6.4, and when the two
readings of "minor" were put to them directly they confirmed 0.6.4. So the pair shipped as 0.6.4
(Factorio 2.0) and 0.6.5 (Factorio 2.1), keeping the already-open number rather than re-grading
it. Recorded because the next agent reading `factorio-release`'s bump table against this delta
will get a different answer than the tags show: the table was not wrong, it was overruled, which
is the owner's call to make.

Track assignment needed no discussion - 2.0 first on the lower number, 2.1 as the port - which is
what every prior pair back to 0.1.0 did, so the even/odd reading of this mod's tags holds through
0.6.5.

Gates, all green before the first upload: data stage clean on 2.1.16 and on 2.0.77; **253/253
headless on both tracks**; 253/253 through a real client on 2.1; static tier clean (luacheck 0/0,
emmylua the usual nilability warnings only). The two validations were run sequentially, as the
scratch write-data folder keyed by mod name alone still requires.

**`faq.md` gained the release's question and `README.md` already had it.** The README line on the
Ingredient amounts **Edit...** button came in with the feature commit, so only the FAQ was behind;
the new entry covers setting the per-ingredient amounts and - the part no player would guess -
that clearing a field and pressing Enter returns it to the automatic amount.
`fmtk details --readme --faq` pushed both. The gallery was not touched: no new shots, so the
duplicate-upload trap of 2026-08-26 never came up and the five ids stayed where they were.

Post-upload check off a cache-busted `full`: releases now end 0.6.2/2.0, 0.6.3/2.1, 0.6.4/2.0,
0.6.5/2.1; license still `default_gnugplv3`, category still `utilities`, gallery still five
images.

**Two agents shared this working tree, and the index is shared with it.** Another agent was
building another mod's sprites in that mod's folder and `assets/` during this release,
and staged them with a repo-wide `git add` that swept this mod's three release files into the
index alongside their own. Nothing was lost - the fix is that both release commits were made
pathspec-limited (`git commit -F <msg> -- upcycler-planner/`), which commits those paths from the
working tree and leaves the rest of the index untouched. Worth knowing before the next concurrent
session: in this repo `git add -A` is not merely untidy, it hands your files to whoever commits
first, and a scoped commit is the only thing that reliably undoes it.

## 2026-08-27 — a survey of what players and the field are building, folded into `deferred.md`

The owner asked for a deep read of the mod plus the portal's *Some design ideas* thread and a
fresh web survey of upcycling layouts, with the result enriching `deferred.md`. Six entries
landed, no code touched and no decision changed — the file is a register of "not yet", so
everything went there rather than into `decisions.md`.

**The thread's substance was already shipped.** TornBreeze's design stops each tier's machines at
a threshold (200 in their example) and pauses each recycler when the tier above has enough —
which is 0.6.0's reserve-and-cap, arrived at independently and released four days after the
thread. What is genuinely new there is **per-quality belt lanes** in place of one shared ring,
which the author credits for their throughput. The blueprint itself never reached us; the paste
failed and the fromsmash link is expired, so the five Lightshot screenshots are the record.

**Three layout-side entries were written and the owner cut them before the commit** — the lanes
above, heat pipes for a loop stamped on Aquilo, and landfill/foundation tiles under the
footprint. Recorded here so the next survey does not re-file them as discoveries: they are the
owner's editorial call, not an oversight, and the two objections to lanes stand either way (the
single ring is what makes the layout tier-count-agnostic, and throughput is not the binding
constraint at one machine per tier).

**The field survey found the lineage still stationary.** kvdveer's book accumulates the same
hand-parameterisation fixes it always did (Kane99's foundry and bulk variants plus per-tier limit
combinators, Oct 2025; NuclearPotato64's legendary-filter fix; Pengudood's unpowered inserters
under medium poles — all three are defects this mod's generator cannot have). No new architecture
since the three in `analysis/blueprints.md` §8. What the survey did turn up was **adjacent gaps
rather than layouts**: nothing plans heat on Aquilo, where the best upcycling machine in the game
lives; nothing lays tiles the way Mining Patch Planner lays landfill; and the wiki's math page,
re-checked, still carries no physical layout advice at all.

**Two findings came from inside the repo, not the web.** The beacon count drop-down can offer a
count that transmits nothing — `profile` is per prototype, vanilla's is 1/sqrt(N) and keeps
paying, while Pure Modules' own beacon flattens at three (`balance.md`), so the sibling mod in
this repo is the counter-example. And spoilage appears nowhere in `scripts/`, which is either a
modded-content guard or a real refusal depending on a measurement nobody has taken.

Also recorded: pacak's multiple-recipes ask and the owner's public reason for declining it, so
the decision survives outside a portal thread.

## 2026-08-27 — configurable ingredient amounts, the third side panel

The owner asked for a way to configure the quantity of ingredients from the planner, pre-filled
with what the mod already does ("I think is 1 stack idk" — it is in fact `request_count`'s
minute-of-crafting-capped-at-a-stack, which often lands at the stack). Four design calls put to
the owner, all four resolved to the recommended option: the entry point is a row in the top
block (label + *Edit...* button, dead until an item is picked), edits reset on an item change,
the floor is one, and the scope is ingredients only — the product buffer stays a `deferred.md`
candidate.

Built as the third `SIDE_PANELS` entry, which cost exactly what that registry promised: a
builder, three dispatch handlers (`requests`, `ingredients-close`, `request-count`) and one
registry line — mutual exclusion, panel-first Esc, rebuild survival and the Confirm-key guard
all came free. The one deliberate divergence from the wizard is **no backfill**: only an edit
is stored (`request_<item>` flat numbers), so an untouched ingredient keeps following the live
formula and a recipe retune moves the default. The formula's value rides in each field's tags
for the Enter-on-empty reset — safe because any recipe change rebuilds the modal, panel
included. `state.prune` claims the family structurally ahead of the `_quality$` sweep (the
circuit families' precedent; `request_` cannot collide with `requester`/`requester_quality`,
checked letter by letter). The wizard's int32 cap was renamed `INT32_CAP` and shared.

Specs in the same session: plan_spec (override reaches the feed chest, zero falls back),
state_spec (prune by the chosen recipe's own ingredients), gui_spec (the button's gate, the
panel's containment, commit/reset mechanics, reset-on-item-change refilling an open panel, and
the three-way slot swap). The changelog first opened 0.7.0; **the owner re-graded the bump to
0.6.4** and reworded the entry in their own voice, `info.json` moving with it. Nothing shipped.

## 2026-08-26 — the 0.6.2 / 0.6.3 pair, and the portal description caught up

The owner asked for the pair to ship and for the portal's description and FAQ to be brought back
in line with `README.md` and `faq.md`. **0.6.2 for Factorio 2.0, 0.6.3 for Factorio 2.1**, the
usual shape: the 2.0 section carries the entries (the unfocus fix and the reworded mod
description), the 2.1 one points at it, and both sections live in the one shared `changelog.txt`
on both branches.

Gates, all green before either upload: data stage clean on 2.1.16 and on 2.0.77; **246/246
headless on both tracks**; 246/246 through a real client on 2.1; static tier clean (luacheck
silent, emmylua warnings only, the same nilability pedantry on `loop_spec` as before). The two
validations were run **sequentially** — the scratch write-data folder is keyed by mod name
alone, which is what the concurrent run broke earlier the same day.

**The description had drifted and the FAQ had not.** `fmtk details --readme --faq` had last run
before the reword, so the portal was still leading with the old sentence while `faq.md` matched
byte for byte. Worth recording is how the comparison has to be done: the portal **normalises the
markdown it stores** — `-` bullets come back as `*`, and it drops the README's leading `#
Upcycler Planner` heading — so a raw `diff` against the local file reports every line as
changed and says nothing. Normalise the bullets, strip the H1, then compare; that is what showed
the FAQ was already correct and the description was one paragraph out.

Reading the page back needs the cache-buster (`…/full?cb=<random>`), as ever. Post-upload check:
four releases now end 0.6.0/2.0, 0.6.1/2.1, 0.6.2/2.0, 0.6.3/2.1; license still
`default_gnugplv3`, category `utilities`, gallery still five images — nothing was touched but the
two text fields.

## 2026-08-26 — one description again, in both places

The owner asked for a new short description, and for the rule that had frozen the old pair to be
updated with it. `info.json` and the locale `[mod-description]` now both read *"Choose an item
and a target quality, the mod designs and gives you an entirely configurable upcycling loop
blueprint."* — the owner's own wording, with the typo fixed and a full stop added, nothing else
touched.

That retires the drift recorded earlier the same day: the locale key had claimed the loop is
"placed as ghosts" ever since 0.4.0 made it untrue, and the standing decision was to leave the
pair alone because nobody had asked. `decisions.md` now says the opposite — one string, moved
together, on both branches — since the only reason for the freeze was the absence of a request.

Both branches carry the pair, the `Locale:` entry in the open 0.6.2 section, and this record;
`locale/` is not a divergent file, so a change there is a change on `legacy/2.0` too.
`README.md`'s opening line went the same way on the owner's follow-up ask, so the sentence now
reads the same in all three places. That one is the portal's long description, so it reaches the
page only at the next approved upload — nothing was published here.

## 2026-08-26 — the modal no longer outlives a death, and two measurements taken wrong first

`deferred.md`'s last housekeeping item shipped: a modal left open across a death, a spectator
switch or a rejoin kept its frame and lost its focus, so Esc stopped closing it. The owner chose
**closing** over re-arming from two shapes put to them; the reasons are in `decisions.md`, and
the deciding one only existed because of a measurement — remote view already closes the modal, so
re-arming would have made death the one path that behaved differently.

**The exploration changed the fix.** The deferred note proposed `on_player_left_game` or
`on_player_joined_game`; the events those name are neither necessary nor sufficient.
`on_player_controller_changed` turned out to cover death, respawn, spectator and every other
controller in one handler, and remote view — which fires it constantly — turned out to be
*already correct*, because the engine raises `on_gui_closed` there. So the handler guards on the
state ("the frame stands but does not own `player.opened`") rather than on the event, and the
common controller change reaches no branch. Only the multiplayer disconnect sits outside the
event, which is what `on_player_joined_game` is still wired for. Full table: `analysis/api.md`
§28.

**Two readings were wrong before they were right, both worth not repeating.** Rounds 2 and 3 of
the throwaway harness concluded that `on_player_controller_changed` does not fire on death — it
does; the watcher was being read in the same tick as the write, and the event is raised later in
it. And `character.die()` **hangs a headless `--benchmark` run outright**: the runner never
returned and the process had to be killed. `ticks_to_respawn = 120` reaches the same respawn
state with no death screen to wait on, which is how `gui_spec` now gets there. Both recorded in
§28 rather than only here, since the next investigation will meet them before it reads this.

**The guard was wrong on the first pass, and the existing suite is what said so.** It read "the
frame stands but does not own `player.opened`", which is true of every broken state — and also
of a healthy one this file already pins: with the settings panel up, a player clicking a chest
dismisses the panel, keeps the planner, and leaves `opened` pointing at the **chest**. The first
guard would have closed the planner out from under it on the player's next controller change.
Narrowed to `opened == nil`, which every measured broken state reads and that one does not, and
a spec now holds the distinction from the other side.

**Two suite facts fell out of the spec work**, both about the player rather than the mod. By the
time `gui_spec` runs in a full suite the player has **no character** — an earlier spec leaves it
that way — so the spectator test failed only in the full run, passing in isolation, because it
assumed one to hand back; it now captures `controller_type` and restores whatever it found. And
the *respawn* test hands a character back, so anything after it in the file is the first thing in
this suite that has to satisfy a character's **reach**: the new chest test failed placing its
chest at the fixed spot the older chest test uses, and passes centred on the player. Both are
positional accidents of test order, not mod behaviour.

Gate: **246/246** headless (242 before), luacheck 0/0, emmylua warnings only and none of them on
the two edited files, data stage clean on 2.1.16, `check-ai-support` green. Not run: the graphics
tier, which belongs to a release.

**Committed, pushed and synced to `legacy/2.0` in the same session** on the owner's ask —
`23e369b` on main, `bfe3c67` on legacy. The cherry-pick conflicted **only** in `info.json`,
resolved by keeping legacy's own `0.6.0`: the 2.0 track is bumped by a release, never by a sync,
which is the same call the 0.6.0 sync recorded. `scripts/gui.lua` **auto-merged** despite being a
forked file — the new function lands well clear of the `contains_value` fork — and was read by
hand rather than trusted, since a clean auto-merge on a divergent file is precisely where a
silent wrong answer would come from. `git diff main -- .` afterwards lists the declared divergent
set and nothing else.

The 2.0 build then measured green on its own install: data stage clean on **base 2.0.77** with
`data-final-fixes.lua` loading, and **246/246**, the four new specs included. No rewrite and no
gate were needed — `on_player_controller_changed`, `on_player_joined_game` and
`LuaControl::opened` all exist in 2.0.77's own `runtime-api.json`, checked before the pick rather
than discovered by the suite.

## 2026-08-26 — 0.6.0 / 0.6.1 released, and the gallery API's duplicate rule corrected

The owner authorised the pair and the portal refresh in one ask: 0.6.0 for Factorio 2.0 from
`legacy/2.0`, 0.6.1 as its 2.1 port from `main`, description and FAQ resynced, and the replaced
`images/01-planner-menu.jpg` swapped into the gallery. The numbering followed the four prior
pairs — main's open 0.6.0 became the **2.0** number and main re-graded to 0.6.1 — which is the
standing convention, put to the owner rather than assumed because a version number is theirs.

The full gate ran on both tracks before either upload: data stage clean on **2.1.16** and
**2.0.77**, and **242/242** headless plus a graphics pass on each. Two runner facts fell out of
it, neither a mod bug. `validate.ps1` has **no `-CheckUnusedPrototypeData` switch** — the flag is
a raw `factorio.exe` argument the script does not pass through, and PowerShell's
parameter-binding error still exits **0**, so the failed run reads as a pass exactly the way the
skill warns the flag's own warnings do. And the script's scratch write-data folder is keyed by
**mod name, not install**, so validating both tracks concurrently makes them fight over one
`.lock`: the 2.1 run failed with `module prototypes.planner.shortcut not found` for a file that
was on disk the whole time. Run the two tracks sequentially.

**The gallery API does not behave the way `factorio-release` describes.** The skill says
re-uploading an unchanged file is free because images are content-addressed and the call returns
the id it already had. It does not: `images/add` answers
`{"error":"InvalidRequest","message":"Image already exists"}`, and fmtk-free tooling that reads
`.id` off that body sees an empty id — which is very likely what the 2026-08-17 "one of five
survived" measurement actually was, misread as a flake because the raw body was never printed.
The retry advice that follows from it cannot work; a duplicate fails identically every time
(four attempts here). What saved the gallery was the skill's *other* rule, which held exactly as
written: ids were collected and asserted before `images/edit`, so the abort left the live gallery
untouched instead of trimming it to one image.

The recovery is the shape to reuse. `images/add` had already appended the new shot, so the
gallery read six; the four unchanged ids came from a cache-busted
`GET /api/mods/<name>/full`, and each was **identified rather than assumed** — pixel dimensions
plus a 16x16 greyscale signature against the local files, every match exact at distance 0. The
sixth, 719x651, matched nothing on disk, which is precisely what the superseded menu shot should
look like. Only then was the five-id order set. Guessing which id was which would have scrambled
or deleted the wrong image, and `images/edit` answers `{"success":true}` either way.

## 2026-08-26 — the text pass committed, synced to legacy/2.0, the 2.0 build measured green

The owner reviewed the reworded strings, rewrote the 0.6.0 changelog's feature entries in
their own voice, and replaced `images/01-planner-menu.jpg` with a shot of the renamed pickers,
then authorised commit, push and the legacy sync in one ask.

Before committing, the owner's changelog edits were checked against the format rules and two
mechanical faults fixed: a **trailing space** on a continuation line — which the parser treats
as an error and reports misleadingly — and "instead requester chests". Terminating periods were
added to match every other section in the file. The deleted rename line went back in, because
the `container` role's published 0.5.1 label was *Buffer chest* and 0.6.0 adds a *Use buffer
chests* checkbox about a different role; without the entry an upgrading player meets one word
meaning two things and no note explaining it.

Docs were brought in line with the three renames in the same commit — the mod's `CLAUDE.md`,
five bullets in `decisions.md`, and the new vocabulary table that now owns the mapping so it
cannot drift again. `check-ai-support.ps1` green (41 API citations, 16 game-data, 8 evidence
files, 114 paths).

`main` went out as 930d192 (9 files). The cherry-pick onto `legacy/2.0` conflicted **only** in
`info.json`, exactly as expected: resolved by taking the new `description` and keeping the 2.0
band — `factorio_version` `"2.0"`, `base`/`quality >= 2.0.0`, and **no** `expansion_required`,
which does not exist in 2.0 and would gate nothing. `git diff main -- .` afterwards lists
exactly the declared divergent set and nothing else. The 2.0 build was validated from the
legacy worktree's own script: data stage clean against **base 2.0.77**, which was the check
that mattered, since the resolved `info.json` was written by hand. No Lua changed on either
branch, so the suite was never at risk.

Note for the next sync: legacy's `info.json` still reads `0.5.0` against main's `0.6.0`. That
is not drift — the 2.0 track has not been bumped for the 0.6.0 work yet, and a bump is a
release action needing the owner's approval for that specific release.

## 2026-08-26 — every player-facing string reworded, and three labels renamed

The owner asked for a clarity pass over everything a player reads: the locale, the README, the
FAQ and the mod description. An audit of the ~110 strings against the code that assembles them
found three classes of problem.

**Terminology drift.** One concept had three names — the GUI said *Build options*, the README
*Selectors*, the FAQ *Build options pickers*. The five chest labels mixed schemes: three named
a job (Ingredient, Output, Overflow), one named a kind (*Plain chest*), and one was vague
against a label already using the word (*Item chest* beside *Item to upcycle*). The
`terminal-module` picker was captioned *Top machine module* while its own tooltip called it
"the last machine". Settled as the vocabulary table now in `decisions.md`; the code keys were
deliberately left alone.

**Two strings had gone stale or were never complete.** The mod description still said the mod
"places it as ghosts", which stopped being true at 0.4.0 when Confirm started handing over a
blueprint. And the *Show all build options* setting described itself as revealing "the chests
and the ones with only one choice" — never mentioning the beacon group, which `beacon_visible`
has also gated since 2026-08-22.

**The warning family was unevenly finished.** `quality-not-researched` and
`recipe-not-researched` both reassured with "The loop will wait for it";
`build-quality-not-researched` and `no-pole-researched` stated the fact and stopped — the
second of those meaning "the loop arrives with no power", which is exactly what the player
would want to know. Now one family. Two other messages were repaired rather than reworded:
`inserter-too-few-filters` ignored a `__2__` that `planner.lua` had been passing all along, and
`no-recycler` said "Pick a recycler" for a picker that is hidden in a vanilla game.

**Renaming `container` was the one that mattered.** Its published 0.5.1 label was *Buffer
chest*, and this same unreleased version adds a *Use buffer chests* checkbox about a different
role — so leaving it would have shipped one word meaning two things in one window. All three
renames were free because 0.6.0 has no tag; the owner rewrote the changelog's feature entries
in their own voice afterwards, and the rename line went back in for the collision's sake.

Key set verified unchanged (109 before and after), placeholders and plural forms intact, file
pure ASCII, `info.json` description byte-identical to `[mod-description]`. No Lua changed, so
the suite was not at risk; the data stage was validated green regardless.

**One reported bug was checked and found not to exist.** The review claimed that
`gui.apply_defaults` re-defaulting the recycler only `if not choices.recycler` leaves a dead
end when the mod supplying a remembered recycler is uninstalled — a stale name that `validate`
refuses behind a picker `worth_showing` hides. It does not: `state.prune` runs on
`on_configuration_changed`, which is exactly when a mod leaves, and it already nils a recycler
that has dropped out of `planner.recyclers()`. Nothing was parked, and nothing needs fixing;
recorded here so the same reasoning is not repeated from the same starting point.

## 2026-08-26 — the place-button fix committed, synced to legacy/2.0, both measured green

The owner authorised commit, push and the legacy sync in one ask. The fix went to `main` as
ab0e5dc (6 files, suite at 242) and cherry-picked onto `legacy/2.0` with no conflict — the
forked `gui.lua` auto-merged, the confirm seams sitting clear of the 2.0 fork's own. The
change uses no 2.1-only API (plain GUI and state calls), so nothing needed rewriting. The
whole suite then ran from the legacy worktree against base 2.0.77: **242/242**, the two new
place-button specs included. Divergence stays exactly the declared set. Both branches pushed.

## 2026-08-26 — the Place button works beside an open side panel

The owner reported the Place button doing nothing while the settings panel or the Limits
wizard was open. Root cause: `gui.confirm` guarded on `side_panel_name`, a guard written for
the Confirm **key** — E under a panel must dismiss the panel, never place — but the button
routes through the same function, so a deliberate click was swallowed with it. The guard
moved to `gui.confirm_key` (after the chooser swallow, so a presumed chooser still gets its
press first); `gui.confirm` keeps only the frame check both routes share. The button now
places with a panel up — the panel dies with the frame on the normal close — and the wizard
case is safe by construction, since the threshold fields commit every keystroke. Two new
specs pin the button beside each panel, mirroring the two key-refusal specs, which stand
unchanged. `decisions.md` rewritten in both places that stated the old shared guard.

The owner authorised the commit and the sync: buffer-by-default went to `main` as one
commit (57ecf1d, 20 files, suite at 240) and cherry-picked onto `legacy/2.0` with **no
conflict at all** — the forked `planner.lua`, `gui.lua` and `planner_spec.lua` auto-merged,
none of the stock-role code touching the 2.0 seams. Before the pick, 2.0.77's own
`prototype-api.json` confirmed `"buffer"` in `logistic_mode`'s union (an inline union
there — the named `LogisticMode` type is 2.1's) and its `technology.lua` showed
`logistic-system` unlocking `buffer-chest`, so the same no-extra-research argument holds.
Then the whole suite ran from the legacy worktree against base 2.0.77: **240/240**, the
buffer-ghost round-trip, the kind flip and the GUI toggle included. Divergence stays
exactly the declared six-file set; legacy keeps `0.5.0`, the pairing being a release
decision as before.

## 2026-08-26 — the item chests become buffer chests, behind a checked-by-default checkbox

The owner asked whether the per-tier item chests should be buffer chests ("not the
ingredients ones") and, after the trade-offs — reserve stock the player can actually pull
via personal logistics and construction bots, against construction draining a loop that
upcycles exactly the things construction uses — picked a hybrid of the offered options:
"opt in checkbox checked by default", with the picker made dynamic ("propose requester
chests when checkbox is unchecked and buffer chests when checked... automatically fill the
best value"). That forced the role split the discussion had predicted: the census chests
left the `requester` role for a new `stock` role whose kind resolves through the flag
(`resolved_role` collapses unbuffered stock onto the requester list, so no duplicate scan),
and the modal gained its fifth chest picker plus the "Use buffer chests" checkbox beside
trash-unrequested. Toggling forgets the stock pick, rebuilds the modal and refills the new
kind's best, keeping the quality; prune tests the stock pick against the kind each player's
own flag names. The locale collision this exposed — the plain relief chest had been
labelled "Buffer chest" since the pickers landed — resolved as Item chest (stock) / Plain
chest (container), and `circuit-min-too-big` now says "item chest"; the owner then asked
the requester picker to say it is the ingredients one, which settled the whole strip on
job-based names — Ingredient / Item / Plain / Output / Overflow chest (internal role keys
untouched), recorded as a Gui entry in the open 0.6.0 section. Suite 237 → 240 (the
kind flip in plan and prune, the GUI toggle round-trip, buffer ghosts in the blueprint
round-trip and the relay walk); evidence in `analysis/api.md` §27, the full reasoning in
`decisions.md`. A three-reviewer round (correctness, simplicity, conventions) found no
functional defect and four cleanups, all applied: the `~= false` idiom centralised as
`planner.stock_buffered(choices)` — which also closes the latent raw-nil-into-resolved_role
inversion the correctness pass noted — two stale "four chests" comments, the Decided
bullet still saying five groups without Circuits, and a sweep of "buffer" comments that
had come to collide with the buffer-chest kind (circuits.lua, decisions.md, two specs).
Uncommitted — the feature sits in the open 0.6.0 section.

## 2026-08-26 — committed, and the 2.0 track measures the same feature green

The owner authorised the commit and the sync: circuit limits went to `main` as one commit
(0ad3bc6, 34 files, suite at 237) with the README and FAQ now describing the feature, and the
cherry-pick onto `legacy/2.0` conflicted on `info.json` alone — the forked `planner.lua`,
`gui.lua` and `planner_spec.lua` all auto-merged, none of the circuit code going near the 2.0
seams, exactly the overflow tap's precedent. Legacy keeps `0.5.0` (the version pairing
belongs to a release request, the 0.4.x rule) and the divergent set is unchanged — the
circuit feature needed **no new forked file**: `get_max_circuit_wire_distance`,
`circuit_green`, `get_inventory_size(index, quality)` and `lose_focus_on_confirm` all exist
on 2.0.77, checked in its own `runtime-api.json` before the pick. Then the whole suite ran
from the legacy worktree against base 2.0.77: **237/237**, the blueprint circuit round-trip,
the live pause/resume, the reserve floor and the widest-pitch relay included — which retires
the "schema read, not a measurement" caveat from the landing entry by measurement.

## 2026-08-26 — the owner catches the floor/trash deadlock

"What if the reserve limit is > than the number of requester items in the chests? with trash
unrequested option it will never work" — and it would not have: the buffer chest requests one
stack, trash-unrequested (checked by default) skims anything above the request, so a floor
past the request could never fill and that tier's recycling would stop silently. Three fixes
were laid out — grow the request with the floor, exempt floored chests from trash, warn only
— and the owner picked the first. `circuits.decorate` now raises a floored census chest's
request by the floor when it gates the reserve inserter, so trash skims only above
floor-plus-working-stock and tier 0's bots actively deliver toward the floor; a floor the
chosen chest cannot physically hold gets a validate warning (`circuit-min-too-big`, capacity
asked at the chest's build quality). Pinned in the pure spec (requests 100/75 on the 50-buffer
fixture), plan_spec (125/100 on gears), and planner_spec (the warning, and silence when the
floor fits). Suite 235 → 237.

## 2026-08-26 — a cleanup round: one slot, one owner, one pass

Four cleanup lenses (reuse, simplification, efficiency, altitude) over the still-uncommitted
feature, findings applied with no behaviour change intended and none observed. The side
panels became DATA — a `SIDE_PANELS` registry in `gui.lua` behind one find/close/recreate
mechanism, so the confirm guard, the close-request branch in `control.lua`, the rebuild
survival and the mutual exclusion all iterate it and a third panel (the expected-output
display is the standing candidate) is one entry, not five edits. "Zero means off" gained one
owner: the planner normalises reserves to a SPARSE table and a zero cap to nil before
`circuits.decorate`, whose contract is now "absence means off" — the reach min and the
wiring read the same tables and cannot drift; `plan_spec` pins the zero-cap path at the
planner boundary. The cap's default likewise: `planner.default_circuit_max` is called by
both the wizard's backfill and plan()'s fallback, so the number shown and the number used
are one value. Smaller strokes: layout's `add` returns its entity and the call sites tag
directly (both `extra` merge loops gone), the two prune sweeps merged into one
structurally-ordered pass, the relay belt-tap search became a single advancing pointer
(was quadratic at exactly the long-chain scale relay exists for), the textfield handler
dropped guards its numeric field makes unreachable, and the pure connectivity walker moved
to `tests/support/component.lua` — the pole and circuit specs' third copy was the signal.
Suite 234 → 235 (the zero-cap pin), all green.

## 2026-08-26 — a review round hardens the reach handling

The owner asked for a formal review pass (fresh reviewer, the diff against 601b2a4 and the
owner's spec as the yardstick, nothing from the build session). Verdict: no criticals, three
important hardening items, all taken. `circuit_reach` was calling
`get_max_wire_distance` — the COPPER getter — where `get_max_circuit_wire_distance` is the
documented circuit one; the two agree on vanilla 2.1.16, so nothing was broken, but the
wrong sibling would fail silently the day the engine distinguishes them (§26 now records
both). The reserve inserter was missing from the reach min entirely — and
`InserterPrototype.circuit_wire_max_distance` defaults to 0, so a wireless modded inserter
would have had its reserve wire dropped at build with no warning; it now joins the min
whenever a reserve is set, and only then, so an unused wireless inserter cannot zero a plan
that never wires one. And the substation+beacon+pipe column puts a machine-row spine hop at
exactly 9.0 against the 9 reach, where nothing records whether the engine measures centres
or connector points: every reach comparison now keeps half a tile of margin — an
exact-boundary hop becomes a relay or an honest warning instead of a silent gamble — and a
blueprint spec stamps that widest vanilla pitch and walks the one green component.

Minors taken in the same pass: a zero cap now means NO cap (machines ungated, matching the
zero-reserve rule, closing the accidental-dead-loop the reviewer found in the empty-wizard
Enter path; the Max tooltip says so), the field elements renamed to the honest
`upl-circuit-limit-<tier>`, the lose_focus_on_confirm comment's causality corrected, the
uncheck-closes-wizard branch got its spec, and the panel/ring walks moved to ipairs. Left on
the table for the owner: forcing the reserve inserters' hand size to one would make the
floors exact (today a capacity-bonus grab can dip a few below) at a throughput cost. Suite
231 → 234.

## 2026-08-26 — the owner corrects the semantics: reserve and cap, on the inserters

Reviewing the freshly-built cascade, the owner redefined both halves the same day: the MIN is
a **hard keep** — "the inserters should not remove items from the requester chests if the
items are < than the min" — and the machines "should be always work until the provider chest
has reached the maximum". So the cascade's per-tier machine thresholds went, replaced by one
shared cap (`product@target < max`, counted in the output chest) on every machine, and the
floors moved off the recyclers onto the **buffer-to-recycler inserters** (`product@tier >
min`) — which dissolved the compound-condition problem that had made hard floors look like
they needed a decider per tier: gating the inserter says it in one comparison. Two calls made
here and flagged to the owner as one-liners to reverse: the recyclers stop at the cap too
(otherwise a parked loop grinds surplus and tier 0 keeps draining the base — the exact waste
the feature exists to stop), and the reserve default is 0, with a zero-floor inserter left
ungated and unwired entirely.

Storage split into two families — `circuit_min_<quality>` and `circuit_max_<quality>` — so a
remembered floor can never turn into a ceiling when the target moves onto its tier; the
wizard rows grew Min/Max labels ("ui should be clear about this too"), and the cap defaults
to a stack where the reserves default to zero. Suite 228 → 231, green after two findings:
an inserter's `direction` is its PICKUP side (the new reserve rig had it backwards — the tap
and relief rigs knew), and a condition read back off a ghost **omits `first_signal.quality`
when it is normal**, the default-omission family again (api.md §26). The reserve mechanism
itself measured exact at hand size one: 8 in, floor 5, exactly 3 moved.

**The install advanced under the session** — the suite header read base 2.1.14 in the
morning and 2.1.16 after the owner's message. Everything passes on 2.1.16;
`CLAUDE.local.md`'s version line was brought up to date for the default install, the other
three installs unverified. The seven 2.1-stamped evidence files were re-pointed to
`verified_against: 2.1.16` on two grounds, not a blind bump: `check-ai-support` re-validated
all 40 API and 16 game-data citations against the new install, and the 231-test suite —
which pins the measured claims — is green there. Prose claims with neither a citation nor a
test carry the residual risk of a two-patch drift; §9's UNVERIFIED list already says so for
the ones that matter. The static tier's emmylua typedefs are still 2.1.14-generated —
regenerate with `-RegenerateTypedefs` at the next static run.

## 2026-08-26 — circuit limits land: the demand cascade, combinator-free

The owner asked for circuitry: per-tier MIN stocks in the chests and a MAX at the target that
shuts the machines off, pointing at TornBreeze's portal discussion (*"Some design ideas"* —
per-tier thresholds, machines stopping when their level has enough, recyclers when the next
level does; their blueprint file link had already expired, but the description carried the
design). The deferred circuits entry turned out to be waiting for exactly this, and the
`wire_to`-as-plan-index seam built on 2026-08-18 paid off as designed.

**The design collapsed to something much simpler than the reference garnish.** TornBreeze's
build needs combinators; this layout does not, because the buffer chests already separate
stock per tier and a 2.x wire signal is distinct per quality — so the whole cascade is plain
enable conditions on the machines and recyclers the plan already places, one green network,
zero new entities, zero footprint change. Four owner decisions, each picked from presented
options: cascade semantics (over hard MIN floors, which need a decider per tier, and over
MAX-only), off by default, the wizard as a sibling panel, numeric textfields. Architecture
likewise chosen from three offered: a pure `scripts/circuits.lua` decorator (poles.lua's
sibling, but strictly post-hoc since circuits move no geometry) over threading layout.build,
plus the scalar `circuit_wire_to` over generalising `wire_to` into a list — the list variant
touches poles' output shape and its falsified-parity-sweep obligation for no gain a tree
needs. One wrinkle found while comparing the architects' drafts: a chest-row census spine has
a vanilla-breaking last hop (buffer chest to output chest spans 3+Hm+Hr = 10 tiles against
the universal 9-tile wire reach), so the spine rides the machine row instead — pure
horizontal pitch, 3–8 on vanilla — and only a wide modded plan falls back to relaying along
the top ring belts at 1-tile hops.

**Verified before coding, then pinned by the suite** (`analysis/api.md` §26): furnaces gate
exactly like assembling machines (both inherit GenericOnOff; the recycler's blueprint group
carries `control_behavior` and nothing else); `SignalID.quality` makes a condition
tier-exact; wired chests broadcast by default; every relevant `circuit_wire_max_distance` is
9 (`data/core/lualib/circuit-connector-sprites.lua`); an enable condition with no connected
wire gates nothing — measured live, which is what makes `circuit_unlinked` honestly a
warning; and the §21 rename trap has a second instance, blueprint `circuit_enabled` against
runtime `circuit_enable_disable`, which the blueprint spec now reads back by the runtime
name on purpose.

**The suite grew 210 → 228, green on the first full run**: a pure `circuits_spec` (conditions
per tier, connectivity by BFS not wire values, the relay under a synthetic short reach, the
all-out-of-reach degradation), layout tag pins, plan-level off-is-byte-identical and
threshold-defaulting pins, the stamped round-trip (gates on both entity kinds, an
exactly-8-ghost green component, neutral ring belts), the live pause-at-5 / resume-on-drain /
unwired-runs-free measurement, prune-by-key for `circuit_min_*`, and five wizard GUI specs
(arm-open-swap, commit-without-rebuild, Esc panel-first, the Confirm-key refusal, target
reshaping the rows). The mod's first textfields required wiring `on_gui_text_changed` and
`on_gui_confirmed` into the dispatcher — dispatch itself needed nothing, it routes on tags.

Left deliberately: the graphics-tier pass stays a release step (the E-over-focused-field
question is guarded structurally — confirm refuses while the wizard is open — so the live
check is confirmation, not a gate); the README/portal description is untouched until the
owner words the feature; the 2.0 backport waits for a release request — 2.0.77's API JSON
already shows `LuaFurnaceControlBehavior` and the blueprint `circuit_enabled` family, so it
looks fork-free, but that is a schema read, not a measurement. Changelog opened 0.6.0 with
`Date: ????`; `info.json` bumped to match. Nothing committed, nothing published.

## 2026-08-22 — 0.5.0 / 0.5.1 released, and a graphics-tier seed flake hardened

The owner authorised the pair: 0.5.0 for Factorio 2.0 from `legacy/2.0`, 0.5.1 as its 2.1
port from `main`, both uploaded and tagged. One catch on the way out: the owner's changelog
edit had come from a copy that predated the beacon-count entry, so the stack line had
silently dropped — restored, keeping their Gui rewording verbatim. The release gate also
caught the suite's first real flake: the graphics tier creates a fresh freeplay save per
run, and on one map seed in many the beacon insert-plan measurement's forced stamp returned
a second, map-dependent ghost beside the beacon, failing a count assertion that was
incidental to the measurement. Isolated re-runs passed; the spec now finds the beacon ghost
and asserts on its insert plan instead of pinning the raw count, and registers every
returned ghost for cleanup. Both tracks shipped fully green: 210 headless plus a graphics
pass on 2.0.77 and 2.1.14 each.

## 2026-08-22 — the beacon count: stacks in the column, capped by geometry

The owner came back to the beacon feature asking whether the count could be configurable —
"the hard part would be to manage the maximum". Explored fresh (the GUI had been regrouped
since), and the geometry answered the hard part cheaply: the utility column's interior is
`6 + Hm + Hr` rows and one beacon uses `Hb` of them, so the max is
`floor(interior_height / Hb)` — four for vanilla shapes, computable from numbers validate
already holds, with the existing `beacon-too-tall` refusal falling out as its zero case. Two
findings framed the design discussion: a second *column* of vanilla beacons cannot reach
(supply 3 falls ~half a tile short), so vertical stacking in the existing column is the only
direction that pays and it costs no width at all; and with the default efficiency module one
beacon already saturates the −80% energy floor, so the count is really for speed-module and
modded builds — said to the owner before building. The owner chose the vertical stack and a
dynamic drop-down offering exactly 1..max.

Two architecture passes (minimal-diff vs cleanest-structure) agreed on nearly everything and
split on two points, both resolved for the clean side: the reach check loops the real stack
positions per receiver (some beacon reaches the machine, some the recycler) rather than a
top/bottom shortcut that could wrongly warn on exotic shapes; and `pole_gap` became the sum
`pole + beacon` width instead of their max, because a full-height stack can leave the column
with no free row — safe, since the ladder only reads `pole_gap` after the compact attempt
left something dark, so every previously-covering plan is byte-identical. Both passes
independently found the same latent bug: the recycler handler only refreshed, while its
rotated height now feeds the drop-down's max — it rebuilds via `gui.open` like the machine's.

The build: `layout.beacon_offset` became `beacon_offsets` (a list, block-centred, clamped as
one rigid body), `layout.max_beacon_count` sits beside `interior_height`, and the count rides
`layout_params.beacon_count` — a plain number in `choices.beacon_count`, defaulted and
snapped down in `apply_defaults`, clamped (never refused) in plan() and validate() through
one `chosen_beacon_count`. The drop-down is the quality dropdown's shape, values in its tags,
`worth_showing` inside the group's own visibility. Measured and pinned along the way: the
substation-with-full-stack plan opens three 2-wide lanes (width 38), and the revived
12-beacon loop's receiver union still covers every machine and recycler on the engine's own
answer. Suite 192 → 210, static tier clean.

## 2026-08-22 — the build options strip grouped by concept

The owner asked for the modal's picker strip to be reorganised: twelve icon-only pickers in
one flat six-wide grid had grown past what hovering could keep legible. Researched first —
the full element tree with its hide rules and test pins on one side, vanilla's grouping
idioms on the other (`subheader_frame`+`subheader_caption_label` panes, captioned
`bordered_frame` boxes, plain caption-over-content — all verified in 2.1.14's `style.lua`
and real call sites in base scenarios, K2 and SE). Three shapes were offered with mockups:
labelled rows in groups (recommended), grouped icon strips, and two side-by-side group
columns; the owner chose **grouped icon strips** with the **five fine groups** — Transport,
Chests, Modules, Beacons, Power.

The build: `upl-strip` (a six-column table) became five captioned rows — a
`semibold_caption_label` over a horizontal flow each, built by one `group()` helper. Pickers
kept their names and tags, so dispatch, state and every handler were untouched; the pipe
moved from the strip's tail into Transport beside the belt. The chest and beacon hide rules
moved **up onto their groups** — caption and row hide together, single owner — replacing the
four per-button `visible` writes; per-picker rules (inserter count, pipe fluid) stayed on
the buttons inside an always-visible group. `gui_spec` re-pinned the new paths, traded the
column-count assertion for group-membership and caption-visibility pins, and gained the
`upl-overflow` existence check the old tree test had missed. 192/192 headless, static tier
clean. Locale gained the five `group-*` captions; every picker tooltip still opens with its
own bold name, unchanged.

## 2026-08-22 — beacons, measured first and opt-in by design

The owner asked for beacons and beacon modules in the layout. Explored, designed and shipped
into the open 0.5.0 section in one session; the calls that shaped it — per-tier column
placement, off by default, efficiency-module default — were the owner's, made on a comparison
of the placement geometries and of what a speed module actually does to a quality loop.

**Measured before implementing, and both measurements paid.** Two engine facts gated the
design, and neither was in `analysis/`: which inventory constant a beacon's blueprint insert
plan targets, and where its supply area is measured from. A throwaway-turned-permanent spec
(`tests/beacon_spec.lua`) answered both in one run: `defines.inventory.beacon_modules`
round-trips through `create_blueprint`/`get_blueprint_entities` and stamps into ghost insert
plans, and the supply area is the **collision box expanded by `supply_area_distance`** — an
edge rule, not the pole's centre radius, distinguished by a machine five tiles over that a
centre rule could not reach. Both now live in `api.md` §25 with the sweep numbers.

**The layout change is one floor and one emission.** The fluid clamp generalised into
`gap_floor = (fluid and 1 or 0) + beacon width`, and each tier stands one beacon centred on
its machine+recycler band (machine alone on the terminal tier), flush against the tier column,
west of the pipe run. The `module_inventory` constant rides the params because `layout.lua`
runs on the host interpreter, where the pure runner guards `defines` down to `direction` —
reaching for `defines.inventory` there fails loudly, which is exactly what it is for.

**What needed no beacon-aware code is the finding worth keeping**: `poles.lua`. A beacon in
`built.entities` is an obstacle through `occupied()` and a consumer through
`electric_consumers()` — both generic scans — so the pole pass covers and avoids beacons
without knowing they exist. A pure spec now pins that, so a future name-aware branch fails it.
The file's one change came out of the review pass: its rectangle-overlap primitive is now
exported and `beacon_reach` delegates to it, instead of hand-maintaining a second copy of the
same rule. Three reviewers swept the diff; that duplication was the only finding.

**A four-angle cleanup pass (reuse / simplification / efficiency / altitude) then tightened
what the reviews had let stand.** The beacon placement formula, written twice and tied only by
comments, became `layout.beacon_offset` — interior_height's own pattern, so `beacon_reach` can
no longer drift from the built position. `modules_for`/`module_fits` finished the nil-recipe
generalisation `module_refusal` had started, deleting their two beacon-only clones; the
efficiency default now scores a memoised candidate map instead of re-reading `module_effects`
per call; the beacon params collapsed into `footprint_of` (which now carries
`module_inventory`); the tier-invariant beacon modules table hoisted out of the tier loop; the
stash dance the measurement spec had copied moved into `stamp.place_entities`; and the
zero-gap pure test — byte-identical input to its neighbour, so it could never fail alone —
now requests mixed below-floor gaps. Deliberately NOT done, each with its reason on record:
beacon resolution stays outside `resources()` (the pole's precedent, and the memoised map
removed the double-scan cost), `items_of` keeps its commented crafter_modules default, and
the terminal/beacon module handlers stay two narrative handlers rather than one parameterised
one.

**A fourth, full review at the owner's request found the one real gap the first three
missed**: the beacon handler lacked the unfiltered-picker snap-back guard its two sibling
handlers carry — with every beacon in a modset slot-less or unplaceable, the empty candidate
list leaves the picker unfiltered, and a non-beacon pick would sit in the strip while
`chosen_beacon` silently read it as off. Guard added, and its spec proved drivable (the API
accepts an off-filter `elem_value` write, so the branch is pinned rather than trusted). Also
out of that review: dead `buildable_beacons` dropped, the efficiency default now refuses a
modded hybrid with a negative quality rider, and §25 records the 0.45 margin clamp's
over-promise bound. Suite 191 → 192.

**The quality trade is real and shaped the defaults.** A vanilla beacon refuses quality and
productivity modules at insertion (§16's own rule, beacon as holder), but transmission is
gated by the *receiver's* `allowed_effects` — the sibling mod's corrected finding — so a
speed module's negative quality lands on every covered machine and recycler. Two speed-3s at
vanilla effectivity cost −7.5% quality against the +10% four quality-3s give. Hence: off by
default, efficiency by default, speed pickable with a warning tooltip.

**Suite 167 → 191**, all green on the first full run after the GUI wiring; the end-to-end spec
revives a beaconed loop and asks the engine itself (`get_beacon_effect_receivers`) whether
every machine and recycler receives. Static tier clean. The 2.0 backport was not attempted —
the owner has not asked, and the forked files would all need the port done by hand.

**Owner follow-up, same day: both beacon pickers hidden by default**, researched or not — the
chests' direction, one step further. The first cut left the beacon picker always visible
(clear-is-the-second-option, the pole's rule); the owner wanted the default strip free of it
entirely. One predicate now serves both buttons: show-all reveals them, a chosen beacon keeps
them visible so the opt-in stays clearable, clearing returns them to hidden. The changelog
entry now names the path in, since a hidden opt-in the changelog does not point at is a
feature nobody finds.

## 2026-08-20 — a played game hung, and the profile I trusted was of the wrong shape

The owner picked a high tier in the 2.0 game and Factorio stopped responding. **No Lua error, no
crash dump, nothing in `factorio-current.log` past the mod checksums** — which is itself the
diagnosis: a script error is logged and shown, so silence means nothing faulted. The Windows
Application log had it: `AppHangB1`, "stopped interacting with Windows and was closed". The game
was alive and busy, and the user force-closed it.

**Reproduced at 82 seconds.** One `poles.plan` on a 254-tier chain with a 5x5 machine and a
medium pole. Not the tier cap, not the double-fire — both already fixed — and not
`greedy_cover`, which the morning's entry had named as the one remaining quadratic term.

**It was `bridge`, and I had dismissed it.** A bridging round scores every candidate against
every placed pole, and the round count, candidate count and pole count all scale with the chain:
63 x 3702 x 213 at 128 tiers. Cubic. The reason the earlier pass missed it is worth writing down
plainly: **I profiled the fixture, not the failure.** The vanilla 3x3 ring puts every pole in one
component, so `bridge` exits immediately and never appears in the profile at all. The shape that
was slow was one I had never run.

**Fixed with the same column-index trick and one free bound.** `bridge` now files placed poles by
centre column and scores a candidate from the poles near it, against a `component_of` map rebuilt
per round; `greedy_cover` skips any candidate whose whole coverage list is no longer than the
incumbent's score, which is free because `count <= #list` always holds. 82.02 s → 2.49 s, and the
substation cases dropped too (4.04 → 0.67).

**7040 configurations, zero mismatches**, after adding a 5x5 machine to the sweep — the shape
that fragments the wire network, without which the sweep could not have exercised `bridge` at
all. Falsified as usual: removing the one-component-counts-once guard tripped 2330, weakening the
greedy bound tripped 4034.

**Not finished, and recorded as such.** 2.75 s is a wait, not a hang, but 254 tiers is the
ceiling, Windows fires at ~5 s, and Factorio's Lua is slower than the 5.5 host these numbers came
from. `deferred.md` carries the two remaining exact wins.

## 2026-08-20 — every picker was designing the loop twice

The tail of the pole-solve session below, taken as its own pass on the owner's call so a
regression in either would be attributable to one of them.

**One click, two events, one handler.** `control.lua` routes `on_gui_click` and
`on_gui_elem_changed` to the same dispatcher, and `dispatch` routes on the element's tags, not
on the event type — so a single pick ran every picker handler twice. The first run carries the
value the button already held, so it settled to no change and then re-ran `validate` + `plan`
anyway. `recipe` and `machine` were guarded back on 2026-08-17, but only because *their* second
run rebuilt the modal under the open chooser and flashed; the other nine were left, because
`gui.refresh` touches no elements and so showed nothing at all. What it did was design the whole
loop again — the most expensive thing the mod does, and on a 254-tier chain the difference
between one solve and two.

**The guard has to sit after the snap-back, not before it.** Seven of the nine resolve an
emptied picker back to a default and write it to the button; `pole` and `terminal-module`
instead record the clear as an explicit choice. A guard placed ahead of that resolution — the
obvious spot, and where `recipe` and `machine` put theirs — would skip the write that redraws
the button, so clearing a picker would stop snapping back visibly. `settled_on` therefore
snapshots the keys up front and is *called* at the end, after the handler has finished
resolving.

**Pinned by a test that was proven to fail first.** `gui.refresh` rewrites the status caption
every time, so a sentinel written into that caption and surviving an unchanged click is exactly
the observable for "no second plan". The belt guard was removed and the test re-run to confirm
it goes red (it does, `caption became table`) before being restored — the same discipline the
pole parity harness needed, for the same reason: a test that cannot fail is worse than none.

167 green on both tracks, static clean. `gui.lua` is a divergent file, so the 2.0 copy was
re-forked rather than copied — its only difference is the `util.contains_value` shim, and the
port was checked by diffing the two branches afterwards and confirming the same four hunks.

## 2026-08-20 — the pole solve stops being quadratic in the tier count

Removing the 32-tier cap (entry below) exposed what the cap had been hiding: `poles.plan` runs
on every picker change, and both of its hot terms grow with the tier count. At the 254 tiers
infinite-quality-tiers-plus offers on its top setting, one solve took 2.6 seconds.

**Profiled before anything was touched.** A sampling hook over the pure modules on host Lua put
78% of the solve in `coverage` → `covers`: every candidate tested against every consumer, which
on a 1018-wide plan means asking whether a pole at x=3 powers a machine at x=900. The second
term only surfaced once that was fixed — `spanning_wires` rescanning the whole tree per edge,
cubic in the pole count, which tracks the tier count.

**Two changes, both measured, both proven to move nothing.** A column index in `coverage`, and
Prim's carrying each outside pole's best edge into the tree. 254 tiers went 2604 ms → 441 ms,
and 32 tiers — where a modded game realistically sits — 32 ms → 11 ms. The soundness argument
for the index, the numbers, and what is deliberately still quadratic are in `analysis/poles.md`
→ *Long chains*.

**The suite could not have caught a rewiring, which is why this needed more than a green run.**
A code-explorer pass over the specs found that nothing anywhere pins a `wire_to` value: wire
counts and connectivity, yes, but a spanning tree rebuilt with different tie-breaks is still a
tree, still connected, still n−1 wires. So the old scan's tie-breaks were reproduced
deliberately at *both* ends of the edge, and `poles_spec.lua` gained a pin of the whole
eight-tier wire tree as one line, derived from the pre-change solver rather than the new one.

**The harness was falsified before it was believed** — this morning's false-pass lesson,
applied the same day it was written. Two deliberately broken copies: scan order swapped gave
2182 mismatches out of 5280, and dropping *only* the second-end tie-break gave 43. Without that
second run the zero-mismatch result would have been worth nothing, because 43-in-5280 is exactly
the rare divergence a thin sweep sails past — the first sweep, at 1512 configurations, caught it
only 3 times.

**What the profiling turned up on the way, and did not fix:** nine of the eleven picker handlers
run `validate` + `plan` **twice** per click, because one click raises both `on_gui_click` and
`on_gui_elem_changed` into a dispatcher that routes on tags and cannot tell the two apart. Only
`recipe` and `machine` were ever guarded, because they were the only two that visibly flashed.
That is a doubling at every chain length, vanilla included. It is `deferred.md`'s now, and is
the next thing to do — the owner's call was to land the pure-geometry work first and take the
GUI handlers as their own pass, so a regression in either is attributable.

## 2026-08-20 — the quality chain had a ceiling of 32, and no mod could see past it

The owner reported it from a played 2.0 game running infinite-quality-tiers-plus: the target
dropdown stopped at "Uncommon III" however much was researched. Neither the research gate nor
the dropdown — `planner.quality_chain()` walked `.next` inside `for _ = 1, MAX_QUALITY_TIERS`
with the constant at 32, so the chain was cut at its 32nd entry and everything downstream read
the truncated list: the picker, `tiers_up_to`, `needs_overflow_tap`, `is_quality`.

The arithmetic matched exactly, which is what made the diagnosis certain rather than plausible.
That mod numbers its tiers `normal`(0) … `supreme`(9), `normal-I`(10) … `supreme-II`(29),
`normal-III`(30), `uncommon-III`(31), and chain position is level + 1 — so level 31 is position
32, and `uncommon-III` is the last row in the owner's screenshot. Its own `quality-names.cfg`
confirmed the display name, which is what ruled out the other reading (that the numerals shift
by a cycle and the list had stopped at 22 instead).

**The constant was never meant to be a ceiling.** Its comment called it a cycle guard — `.next`
is a linked list a malformed mod could close into a loop — and 32 was an arbitrary number doing
a job a seen-set does properly. The walk now stops at the first name it has already seen: that
catches a real cycle on its first repeat, imposes no ceiling, and still terminates on the
pathological case the count was really buying, since a cycle of entirely hidden tiers grows the
chain by nothing and a bound on chain *length* would spin forever.

**The walk became `planner.walk_quality_chain(first)` so it could be tested at all.** A chain
longer than the installed game ships is unreachable from a real prototype table, so no spec
could ever have caught this from `prototypes.quality` alone; taking the head lets the suite feed
it stubs, exactly as the modded recycler is stubbed rather than fixtured. The new spec walks 100
stub nodes, closes the list into a loop, then walks a two-node all-hidden cycle. 164 green on
both tracks, static tier clean.

**The cost of removing the cap was measured before removing it**, on host Lua against the pure
layout and pole modules: the pole solve is roughly quadratic in tiers — 0.03 s per attempt at
32, 0.13 s at 64, 0.61 s at 128 — and several attempts run per `gui.refresh`. So the cap was
also, accidentally, the thing bounding a latent performance cliff. That half is now the open
part of `deferred.md`'s *Modded quality tiers*; correctness is settled, cost is not.

## 2026-08-20 — the ring silts up below legendary, and one nameless filter drains it

The owner reported it from a played game: research legendary, build a loop targeting rare or
epic, and the belt slowly fills with material nothing will ever use. That is `deferred.md`'s
*Ingredients that roll above the target tier*, which had stood since the layout was written with
"worth measuring in a real game before choosing" attached to it. This was the measurement.

**The diagnosis was structural, not a bug.** The only route to target-tier ingredients is a
recycler rolling them up, and a roll jumps one, two or three tiers (90 / 9 / 0.9 %). So the event
that feeds the terminal machine is the same event that overshoots it — which kills the file's own
option 2, capping the recyclers' quality modules: remove them and the top machine never runs at
all. That option is now recorded as a route that does not work, beside the trash-chest one from
2026-08-15.

**The fix hung entirely on one unmeasured engine fact.** `ItemFilter` documents a `comparator`,
but a documented field is not evidence an inserter acts on it, and the layout's slot budget turned
on the answer — per-ingredient filters would have cost `#ingredients` slots per tier above target,
which is hopeless. Five throwaway probe rounds (`analysis/api.md` §24): the comparator works and is
exact; `">="` normalises to the glyph on read, and *inside a blueprint on write*, where `">"` is
stored verbatim; it survives set → build → revive; and — the owner's own suggestion, which turned
the design from `#ingredients` slots into **one** — a filter may name a **quality and no item at
all**, which the inserter reads as "anything above this tier".

Three probe rounds proved nothing and are worth not repeating: one belt tile holds four items per
lane so a bulk seed is silently refused; two `insert_at_back` calls on the same line back to back
are refused for want of room; and a substation whose supply square misses the tap reads exactly
like a filter that does not work. The rig that settled it is the mod's own ring in miniature, now
`loop_spec`'s first test.

**What shipped**: an inserter and an active-provider chest in the two tiles the terminal column
had spare, whitelisting `{q_t, ">"}` with no item name. Footprint unchanged — it is that column's
unload inserter reversed. The catcher's per-tier list collapsed to a single `">="`, which also
retired a silent clamp that lost the top tiers of any quality chain longer than five. Price, and
the specs caught it rather than a player: **one more electric pole**, because the tap is a
consumer in a corner that had none and stands on two tiles the pole pass wanted.

**The web survey found the same defect in this layout's own ancestor.** kvdveer's book — the
reference lineage in `analysis/blueprints.md` — truncates its ladder at the target and filters
nothing above it, so its Rare stamps have exactly this problem, still, today. It also found that
**not one of 25 decoded published blueprints uses a quality comparator** (769 quality filters, all
`"="`), and the community's alternative architecture: never truncate the ladder, build every tier
and let the target only move the output tap. That one is real and is recorded in `deferred.md`
rather than adopted — it doubles the build at a rare target and collapses on modded chains that
add tiers above legendary.

**The 2.0 port needed no fork at all.** The cherry-pick conflicted on `info.json` alone; the three
divergent Lua files auto-merged because none of the tap's code goes near the 2.0 seams
(`category`/`additional_categories`, the `can_set_quality` mod-data bridge, the local
`contains_value`). Divergence after the pick is still exactly the six declared files. Then the
whole suite ran against 2.0.77 — 163/163, the live ring drain and the blueprint comparator
round-trip included — which is what turns "2.0's docs say the same" into a measured claim
(`analysis/factorio-2.0.md`). Worth noting the owner's 2.0 install runs **Quality++**, which adds
tiers *above* legendary: that is precisely the modset where a legendary-target loop still needs
the tap, and precisely where the full-height-ladder alternative would have failed.

Version numbers were deliberately left alone on the legacy branch — `main` opened `0.4.4` and
legacy stays at its last released `0.4.2`. A version string is unique per mod across both games,
so the pairing is a release decision and belongs to the release request, not to a code sync.

## 2026-08-20 — the silent hotkey refusal reads as a broken key

The owner reported CTRL+SHIFT+U "not working". Systematic pass found nothing broken: the
prototype loads (checksum in the morning's log), no vanilla control, no installed mod and no
`config.ini` rebind touches the combo — the only silent path was `gui.toggle_key`'s own
recycling gate, refusing by design with zero feedback. The morning's session was a freshly
assembled Krastorio2 modpack save (K2 keeps `recycling`, re-priced 5000 → 500), so the tech was
almost certainly unresearched — the gate was doing its job invisibly.

The lesson generalises: **the button greys out, a key just does nothing** — any gate a key
shares with a button needs its own voice. Fix on the owner's "fix it": the refused press prints
`upl-message.planner-not-researched`, naming the technology read from the shortcut prototype's
`technology_to_unlock` at runtime (exposed on `LuaShortcutPrototype`, checked in
`runtime-api.json` 2.1.14) so gate and message share one source. Refusal returned as a value —
`player.print` is unobservable from a spec — and pinned in `gui_spec`'s hotkey block, plus a
no-refusal pin on the unlocked path. Changelog folded into 0.4.2's open hotkey entry, since the
silent version never shipped.

Same session, the owner re-picked the default: **CTRL+U**, the combo they had already rebound
to in the dev install's `config.ini`. Scanned before switching: no vanilla control, none of the
dev install's mod zips, and none of the Steam library's 121 zips (read-only scan, owner's
explicit ask overriding the standing out-of-scope rule for that one look) binds CONTROL + U.
The hotkey never shipped, so no migration concern — the 0.4.2 changelog entry just says the
new combo.

---

## 2026-08-20 — the settings window becomes a column in an invisible container

The drag-flag fix below survived one in-game test. The owner's screenshots showed the settings
window centred on top of the modal on FIRST open, and stranded after a move: **2.1.14 raises
`on_gui_location_changed` for the engine's own auto_center layout**, so the "player moved it"
flag armed the moment the fresh modal was laid out — before any drag, before any measurement —
exactly the case the evidence note had hedged as "unverified, tolerates either answer". It did
not tolerate it. The lesson for next time: a hedge that says "either answer is fine" needs the
failing answer actually walked through, not asserted.

The owner's demand — "always side by side no matter what, check Even Distribution" — settled
the design: stop placing a second window and make the panel part of the planner's own screen
element. ED agrees from the other side (its settings panel is *anchored* to the inventory GUI,
never coordinate-placed; a mod frame cannot be an anchor, so containment is our equivalent).
First cut made the outer frame the visible window with two columns inside — the owner rejected
it on sight as one wide slab with dead background under the short panel. Final shape: the
screen element is vanilla's `invisible_frame` (no graphics, no padding), holding two
window-styled frames — planner and panel — 12px apart, titlebars level, map showing between.
Both titlebars drag the container, since `drag_target` must name a screen element.

What fell out: all placement arithmetic, the location event, and the three storage fields died
(state.prune clears the strays from dev saves); `player.opened` stays on the container always,
and control.lua turns a close request into "panel first"; a rebuild re-creates an open panel
with fresh ticks, retiring the repaint loop; gui.open and gui.close_settings sweep the
pre-0.4.2 standalone settings window a published save can still carry. Suite reshaped to 158
(three placement tests replaced by containment, sweep and close-together specs), all green
headless and in a real client; the owner verified the look in game.

The owner reported, with screenshots: open the planner, open settings (lands beside — right),
drag the planner left, reopen settings — it opens on the far side of the screen. Root cause was
in the width inference itself: `resolution - 2x` is exact for a centred modal, and the
plausibility band (200–1000 logical px) was carrying the whole burden of telling centred from
dragged. A *moderate* drag left lands the modal where the inference still reads as a plausible
width — accepted, cached, and the window placed at `x + wrong_width + gap`. The existing spec
only pinned *hard* drags, which the band does reject; the screenshots' window sat level with the
modal's top edge, proving it took the beside-branch with a wrong width rather than any fallback.

The real finding: the 2026-08-17 session's "neither is detectable directly, since nothing
reports whether a frame was moved" was wrong — **`on_gui_location_changed` reports exactly
that**, and Space Exploration's remote-view snapping is the prior art (it assigns `location`
inside the handler, so script writes cannot re-raise it). Measuring is now gated on the modal
not having moved since its last centred build; the flag and the trusted width moved from a
gui.lua local into the state entry, since they decide a frame's location — game state — and a
local would desync a rejoined multiplayer client and forget across save/load. Same event, same
placement call: the window now follows the modal while it is dragged, unless the player parked
the window somewhere themselves (`settings_moved`, forgiven when the window reopens).

Two new gui_spec tests (the poisoning-zone drag, the follow-and-parked pair) — red first on the
missing handler, then green; 159 total. Noticed in passing, not chased: `gui_spec`'s "another
GUI taking focus" test fails when run under a name filter but passes in full-suite order — an
order dependence that predates this session.

The repo owner asked for a hotkey to open the planner, CTRL+SHIFT+U by default. Everything
needed was already local: `CustomInputPrototype.key_sequence`'s exact format is in the
installed `prototype-api.json` (modifiers `CONTROL`/`SHIFT`/`COMMAND`/`ALT`, `" + "`
separated), and Krastorio 2 ships the pairing shape to copy — its jackhammer is a shortcut
and a custom-input under ONE name, with the shortcut's `associated_control_input` pointing at
the input so the button's tooltip advertises the binding. No web search needed; the request
to look online was answered by the docs the install ships.

**The one design point was the gate.** A custom input fires whether or not the shortcut is
unlocked, so a bare handler would open a planner the recycling technology has not delivered a
recycler for — undercutting the shortcut's own `technology_to_unlock` +
`unavailable_until_unlocked` gate. `gui.toggle_key` re-checks `player.is_shortcut_available`
(the engine's own availability, so script-granted or script-revoked shortcuts are honoured
too) and control.lua points the input at it, mirroring `gui.confirm_key`'s shape. The
shortcut's name moved into gui.lua as `gui.SHORTCUT`, exported like `gui.FRAME`, since three
things now share it.

**Three new specs** (suite 154 → 157): the prototype pairing read back at runtime —
`prototypes.custom_input["upl-open"].key_sequence` comes back exactly `"CONTROL + SHIFT + U"`
and the shortcut's `associated_control_input` closes the loop — plus toggle-open-toggle-closed
through `gui.toggle_key`, and the gate driven through `set_shortcut_available(false)` rather
than research state, so the spec proves OUR gate without depending on how the engine maps
technologies onto availability (which un-research may or may not latch; unmeasured, and the
gate is agnostic to it). Data stage validated clean, and `--check-unused-prototype-data` read
702,440 properties with zero warnings — `associated_control_input` and `key_sequence` were
both consumed, not silently dropped. The keypress itself stays the usual human check; the
`[controls]` locale key rendering in the controls menu rides the same live look.

---

## 2026-08-20 — E over a floating chooser placed the blueprint

The repo owner, from play: *"when i am selecting a machine and press e instead selecting the
machine it confirms the placement of the blueprint."* Exactly right: the `upl-confirm` input
fires on every press of E, and with the machine picker's chooser floating over the modal,
`gui.confirm` saw a modal, saw no settings window, and confirmed — trading the player's pick
for a blueprint and tearing the chooser down with the frame.

**The chooser has no API surface, checked three ways** (now `analysis/api.md` §23): no event
announces it, no `gui_type` names it, and it never takes `player.opened` — five releases of
picker clicks not closing the modal prove that last one behaviourally. Space Exploration's pin
dialog, the §22 prior art, has the same blind spot around its own icon picker. So there was
nothing to read, only something to infer.

**The fix is a per-player presumption, one press deep.** The click that opens a chooser is
visible (§20), and every later gui event means it closed — a pick fires `on_gui_elem_changed`,
clicking anything else dismisses it. `dispatch` gained a single observer slot that sees every
event before tag routing; `gui.note_gui_event` sets the presumption on a click on one of the
modal's own pickers (told by the dispatch tag) and clears it on anything else. The new
`gui.confirm_key` — now the key's entry point in `control.lua` — swallows one press while the
presumption holds, and §22's documented ordering means the engine's own confirm then lands on
the chooser. The button keeps `gui.confirm` untouched: reaching it is itself the click that
clears the presumption.

**The presumption lives in storage, not a module local, for a desync reason:** every client
sees the same gui events, but a player who joins mid-presumption would rebuild an empty module
table and take the other branch on the same E. It rides the state entry as
`chooser_maybe_open`, cleared by `gui.open`, `gui.close` and the swallow itself; `state.peek`
was added so the observer — which runs for every player's every click — cannot create entries
for players who never opened the planner.

**The accepted cost, chosen over the alternatives:** a chooser dismissed with Esc, a click on
nothing, or re-picking the same value leaves no event, so the presumption goes stale and the
next E closes the modal unconfirmed instead of placing — pre-0.4.0 behaviour, once, with the
choices kept. The alternatives were worse: `consuming = "game-only"` breaks E everywhere
(§22), and deferring the confirm by a tick fights the engine's own close. The button never
degrades.

**Six new specs drive the machinery** (suite 148 → 154): swallow-then-confirm, the pick and
the unrelated-interaction clears, the button's immunity, a foreign untagged picker, and the
close-drops-it rule. `fire()` in `gui_spec` now names its event, because the presumption keys
on click versus elem-changed. What no tier can cover stays a human check, the same one §22
already carries: a real E over a real chooser on a live client — the repo owner's next
session settles it.

---

## 2026-08-20 — the suite grows to 148, and the pole solver stops paying per round

The repo owner asked for two things across the whole mod: as many new tests as the suite could
honestly carry, and a performance pass over the algorithms. Both landed; no behaviour changed,
and a 512-shape parity sweep is what makes that claim checkable rather than asserted.

**Tests: 125 → 148, all green on every tier.** What the new ones pin, chosen for silent-failure
risk rather than coverage numbers: the ring's **circulation direction** tile by tile (the old
closure test counted belts but a wrong-facing belt stalls the loop invisibly); two-ingredient
filters and requests per tier; the row arithmetic under a 4-tall machine and the pitch under a
4-wide one; the two-tier minimal plan; module insert-plan counts; **deep-equal determinism** for
both pure modules (the desync contract, held structurally via a shared
`tests/support/deep_equal.lua`); the pole **bridge pass** and the **honesty rule** in the pure
tier — the header's old claim that unpowered > 0 needs a real planner plan was wrong, a
hand-built wall between two machines reaches it; 2x2 pole footprint handling; machine-candidate
membership with premise asserts (AM1 has no module slots, the refinery refuses quality);
`request_count` arithmetic against stub recipes; `with_quality` / `filters_needed` /
`needs_pipe` edges; the build-quality warning path; and terminal-module prune with the two
boolean clears. One lesson worth keeping: **`require` inside a test body is a runtime error
in-game** ("Require can't be used outside of control.lua parsing") while passing on the host
runner — a split verdict the pure tier cannot catch, so shared helpers are required at spec
top level.

**The solver: coverage lists, computed lazily once per candidate.** `greedy_cover` used to
re-run the supply-square overlap against every candidate x every uncovered consumer on every
round — the round count multiplying the whole geometry. Now `poles.plan` keeps one cache for
the solve; a candidate's covered-consumer list is computed on first consult and shared by the
greedy pass, the free-tile retry and the honesty tally, so the geometry is paid once and a
round is table lookups. Lazy, not precomputed: an eager version was measured first and
**regressed the substation case ~30%**, because a column solve that covers never consults the
free tiles at all. Iteration switched from `pairs` to numeric indexing at the same time, making
the scan-order determinism structural instead of an engine courtesy. `planner.is_quality` also
went from a chain scan to a memoised set — it runs once per quality-carrying material on every
refresh.

**Proof, then numbers.** A 512-shape deep-equal sweep (machine 3–6 wide, 2–5 tiers, four pole
shapes, fluid on and off, gaps 0–3; every shape placed poles, and the harness asserts the two
modules are distinct tables — the 2026-08-20 false-pass lesson below) came back **zero
mismatches**, so the rewrite carries no behaviour of its own. The recorded worst case — 6-wide
machine, five tiers, big electric poles, fluid — went **24.4 ms to 4.3 ms per solve** on the
host; the vanilla compact medium-pole solve 0.95 → 0.55 ms; the 5-tier big-pole column case
9.8 → 2.1 ms; the substation case level. `analysis/poles.md` §Performance re-verified with the
new figures. Changelog: one Optimizations line in the open 0.4.2.

**What this session did not do:** the `legacy/2.0` cherry-pick. `tests/planner_spec.lua` is a
forked file, so the new specs flow to that branch by hand at the next backport, per the repo
rules — nothing was touched there.

---

## 2026-08-20 — the pole columns stop being free, and the planner starts paying for them

The repo owner, with a screenshot of two loops side by side: *"the placement of the poles caused
too big empty columns now... at the left is the old algorithm it was compact, but now with new
algorithm/layout it's larger."* Both builds were four tiers of electromagnetic plants; the right
one reserved four utility columns and stood a substation in two of them. **26 wide to place two
poles that a single substation covers from free ground at 18.**

**The cause was one line, and it had been there since 0.2.0.** `column_gap` was
`(fluid and 1) + pole.tile_width`, applied to every tier unconditionally, so the footprint grew
by `tiers * G` whether or not anything stood in the columns. The 2026-08-17 entry below records
that as a deliberate simplification — the growth retry was deleted *because* the columns were
opened before the layout existed — and it is the trade that came due here.

**Measured before designing anything**, on the host interpreter against the mod's own pure
modules: four reserved columns and one used on a 4x4 machine with medium poles; three reserved
and two used on the pinned vanilla default. Worse, on some shapes the free-tile fallback won
outright, so the width was paid and the tidy line was not even delivered — the screenshot's own
configuration.

**The owner chose compact-first with sized growth, and "narrower wins" on a tie.** So
`layout.build` now takes `column_gaps`, a list per tier rather than one scalar, and
`planner.plan` runs a three-attempt ladder in a new local `plan_with_poles`: the compact plan,
then all columns, then collapsing back every column no pole stood in. Fewest unpowered wins,
width breaks the tie, and because the all-columns attempt is always in the running the outcome
cannot be worse than what shipped. Details in `analysis/poles.md` §"Choosing the columns".

**Two proofs were worth building before the change went in.** A parity harness ran the edited
`layout.build` against the git copy over 144 shapes with uniform gaps — byte-identical, so the
scalar-to-list refactor carried no behaviour of its own. Then a 768-shape sweep (machine 3–6
wide, 2–5 tiers, six pole shapes, fluid on and off) compared the ladder against the shipped
behaviour: **zero coverage regressions, zero width regressions**, max four solves. Both are
throwaway scratch scripts, not suite members — what they prove about *this* change is a
one-time question, and the suite pins the outcomes instead.

**The first parity run was a false pass and is worth recording as such.** The harness took the
old and new layouts as two arguments and I passed them in the wrong order, so each module was
called with the *other's* parameter name, both ignored it, and both built at gap zero —
144/144 identical, proving nothing. The rewrite asserts the two modules are distinct tables and
ends with a live check that a `{0, 2, 0}` gap really does widen the plan by exactly 2. A
comparison harness that cannot fail is worse than no harness, because it is believed.

**Cost, honestly.** Mean plan time went *down*, 4.2 ms to 3.8 ms, because the plan that usually
wins is also the smallest one to solve. The worst case went up, 35 ms to 49 ms, on a 6-wide
machine at five tiers with big electric poles and a fluid recipe — a dropped frame on a picker
click, inside `gui.refresh` where `layout.build` already lives.

**What a player gets and gives up.** The vanilla rare loop goes 14 → 11 wide, the screenshot's
own build 26 → 18, substation-to-legendary 27 → 21, the fluid battery loop 17 → 14. The price is
more poles (five instead of three on the vanilla loop) and no tidy line — the poles spread into
the dead ground beside the recyclers, which is exactly the look of the "old algorithm" build the
owner pointed at. **The big electric pole is unchanged**: all three of its columns open and stay
open, because there each one holds a pole doing real work. That case is now what proves growth
still happens, and its spec says so.

Suite 123 → 125 (two new pure layout tests: per-tier gaps, and the fluid clamp surviving a
collapse request), all green headless, static tier clean, data stage clean. Four pinned widths
and one pole count moved, every one of them predicted correctly by the host simulation before
the in-game run.

**One fixture bug found on the way**, in `tests/pure/layout_spec.lua`: `fluid_params` applied
its overrides *first* and then wrote its own defaults over them, so the new clamp test was
silently running at the default gap. Overrides now go on last.

**Not ported to `legacy/2.0`.** `scripts/planner.lua` is a declared divergent file, so the 2.0
build keeps the old behaviour until someone hand-applies this; `scripts/layout.lua` is not
divergent and cherry-picks cleanly, but the two have to move together.

---

## 2026-08-18 — released: 0.4.0 (Factorio 2.0) and 0.4.1 (Factorio 2.1)

Published at the repo owner's request, shipped 2.0-first on the lower number per the pair
convention. The release these two carry is the blueprint hand-over — Confirm now fills the
cursor with an ordinary blueprint instead of a one-shot selection tool — plus the hidden chest
pickers, the Confirm key, and the stay-in-hand stack.

**`main` had to be re-graded to make the pair work.** The blueprint work had been committed
with `info.json` already bumped to 0.4.0 on `main`, which would have shipped 2.1 first and put
the 2.0 build on the higher number — backwards from all three prior pairs. Presented as a choice
rather than corrected silently, since version numbers are the owner's call; they took the
conventional shape, so `main` moved 0.4.0 → 0.4.1 and the legacy worktree 0.3.0 → 0.4.0. The
lesson for next time is that bumping `info.json` inside a feature commit pre-commits the pair
ordering before anyone has decided it.

The release gate ran in full on both tracks before either upload: data stage clean on 2.1.14 and
2.0.77, the suite green through headless **and** a real client on each (123/123 four times over),
static tier clean (luacheck 0/0 across 25 files, emmylua_check 0 errors). Both zips verified by
listing rather than by reading `package.ignore` — `data-final-fixes.lua` in 0.4.0 alone, `LICENSE`
in both, no tests, images, `.ai-support` or CLAUDE files in either.

One save-safety question was worth settling before grading the bump: the delta removes the
`upl-planner` selection-tool prototype, which is normally major-bump territory. It was `hidden`
and `only-in-cursor`, so it can never have been in an inventory, and `state.prune` already clears
the `entry.pending` snapshot 0.3.1 and earlier left behind. Minor bump, no migration.

Both sections carry `Date: 2026-08-18`, and the 0.4.0 zip ships with the 0.4.1 section already
on top of its changelog — the same shape the 0.3.0 zip had, and what the one-shared-file rule
forces.

---

## 2026-08-18 — the chest pickers leave the strip

The repo owner, on the modal: *"the upcycler planner modal menu shows by default the chest
selector (to choose between wood / iron / steel chest), can that menu be hidden by default and
only shown when show all build options is true?"*

Yes, and it cost one line: the loop that builds the three chest buttons set
`visible = worth_showing(player, chest_names)` and now sets `visible = show_all_options(player)`.
The count rule was already there, and the buffer was the only chest passing it in a vanilla game
— wooden, iron and steel against one requester and one passive provider.

**Applied to all three roles, not just the buffer.** The three are built from
`planner.CHEST_ROLES` in one loop precisely so they cannot drift apart, and a per-role exception
would have been the first drift. In vanilla nothing changes for the other two — they were already
hidden on the count — so the difference is only visible in a modset that adds a second requester
or passive provider, where the new rule keeps them out as well. That is the consistent reading of
what the owner asked for: the chests are not a decision the planner puts in front of the player.

Nothing else moved. A hidden picker is still built, still handles its events and still holds the
default the plan uses, which is what let the spec that drives the shared chest handler through
`upl-container` keep working untouched. `gui.open` is the only place visibility is computed and a
setting flip reopens the modal, so there was no second path to fix.

Vanilla now shows five of the nine build options: belt, inserter, quality module, top machine
module, pole.

---

## 2026-08-18 — the Confirm key reaches Place

The repo owner, on the modal shipped hours earlier: *"in Factorio there is a default behaviour
that when we press E it takes the same action than the confirm button, but in this mod is not
working, when clicking on E it closes the modal without giving the blueprint."* Correct on both
counts, and the second half is the interesting one — E and Esc arrive at the mod as the *same*
event.

**There is no key information in `on_gui_closed`.** Twelve fields, none of them a key or a
modifier, so the close handler had no way to tell a confirm from a cancel and treated both as
cancel. `on_gui_confirmed` is not a way round it either: it fires for Enter in a textfield, and
this modal has none. Vanilla's E-confirms-a-dialog is engine-side and mod frames do not inherit
it. All of that is in `analysis/api.md` §22.

**The mechanism is a `custom-input` linked to the `confirm-gui` game control**, which the game
calls *Confirm window*. Linked rather than bound to a key of the mod's own, which is what makes
it follow a player's rebinding and lets it skip a locale key entirely. Space Exploration ships
the same pattern for its pin dialog (`scripts/pin.lua:737`) and Krastorio 2 for its search
focus, so this was a matter of finding the established shape rather than inventing one — the
repo rule about checking `exemples/` first paid for itself.

**One constraint decided the only real design question.** `consuming` has to stay `"none"`,
because `"game-only"` blocks the linked control *everywhere* — E would stop opening the
inventory in ordinary play. The engine's own close therefore always runs after our handler, and
that splits behaviour on exactly one path: when the hand-over is refused for full hands, the
button leaves the modal open to retry and the key does not. The repo owner chose to accept it
over the alternative, which was re-taking `player.opened` from inside `on_gui_closed` — the same
hazard `gui.close_settings` already carries a comment about. The message prints either way and
the shortcut reopens with every choice remembered.

**What changed in the code is small and mostly a move.** The confirm body came out of the
dispatcher registration into a public `gui.confirm(player)` that both callers use, and it now
guards its own preconditions: a modal must be open, and no settings window may be in front of
it. The button could never arrive without those; the key can, and does — it fires on every press
of E anywhere in the game, so the early-out is two table lookups and stays that way.

**Verification stops one step short, deliberately.** No tier can fake a keypress, so whether the
control is bound to E on a given machine, and whether it fires while a *mod* frame owns
`player.opened`, is a human check in a live game — the repo owner will take it in their own
session. Everything downstream of the event is covered: three new specs drive `gui.confirm` with
the modal open, with nothing open, and with the settings window in front, taking the suite from
120 to 123. Data stage clean, and `--check-unused-prototype-data` confirms the engine actually
read `linked_game_control` rather than dropping it as a typo.

---

## 2026-08-18 — the placement step becomes a blueprint in the cursor

The repo owner's ask: *"the player needs to select an area so the upcycler planner can design and
place the upcycler... the idea is to have a blueprint in the player hand so the player can preview
what he will be placing."* This was already parked in `deferred.md` as *Cursor-blueprint
placement*, blocked on "unverified engine fidelity". It shipped as 0.4.0.

**The blocker turned out to be narrower than it read, and mostly already answered in this
folder.** `analysis/blueprints.md` §7 has kept the decoded JSON of real 2.x upcycler blueprints
since day one, and it carries `recipe`, `recipe_quality`, `request_filters`, `filters`,
`use_filters`, `filter_mode` on exactly the entity types this mod places. So the question was
never "can a blueprint hold this" but "does `set_blueprint_entities` round-trip it when a script
writes it". Rather than answer that from the docs, the engine was asked: a plan was placed with
the then-current ghost builder, `create_blueprint` captured it, and `get_blueprint_entities()`
was dumped. Round-trip exact, 92 -> 92 -> 92, and the complete field set came back as thirteen.
That dump was the specification the serialiser was written against. Everything measured is in
`analysis/api.md` §21.

**One decision made itself.** There is no continuous read of the cursor's world position —
`render_position` is the player, `CustomInputEvent.cursor_position` only fires on a keypress — so
a `rendering`-drawn preview that follows the cursor cannot be built at all. A blueprint is not the
nicer route to a preview; it is the only one.

**The owner's call on behaviour removed more code than it added:** *"it should be identical as
placing blueprint... if it tries to place with a normal click and there is obstacles it should be
refused by game engine, but player can use SHIFT + CLICK or CTRL + SHIFT + CLICK."* The engine
already implements precisely that, so the mod handles no placement event whatever. Out went
`builder.lua` entire — the all-or-nothing pre-check, the tree marking and its rollback, the
blocked-placement message — plus `control.lua`'s two `on_player_selected_area` registrations, the
`upl-planner` selection tool prototype, and `state.arm`/`entry.pending`, which existed only so
reopening the modal could not change what was about to be placed and is now structural: the
blueprint *is* the frozen plan. Three locale strings went with them.

**The one risk worth the paranoia was flipping, and it came out clean.** The recycler throws on
`vector_to_place_result = {-0.35, -2.3}` — a non-zero x offset, so a mirror that failed to mirror
the throw would land it two thirds of a tile out and no craft would ever start, silently. Measured
through `build_from_cursor` in all four orientations, revived: every recycler's `drop_position`
still lands inside its own machine. Two false starts getting there, both worth the entry —
`drop_target` is **nil** on a furnace-type recycler (the unflipped control failed first, which is
what said the test was wrong rather than the layout), and `find_entities_filtered{position = ...}`
matches an entity centred on the point rather than one covering it, so containment needs a
degenerate `area`.

**Undo answered itself.** The parked question was whether ~90 `create_entity` calls collapse into
one undo step. They do not have to: a stamped blueprint files exactly one undo item, carrying 94
actions for a 92-entity loop. The entry left `deferred.md` along with the placement one.

**Removing the `upl-planner` prototype cost no migration**, for the same reason the `ua-` -> `upl-`
rename did not: the item was `only-in-cursor`, `not-stackable` and `hidden`, so it could never be
in an inventory, a chest or a blueprint, and nothing in `storage` named it. Factorio drops an
unknown *item* on load without a word — unlike an entity, which is what makes prototype removal
expensive. `entry.pending` went the same way and is the one loose end: a save made under 0.3.1
keeps its table of strings, so `state.prune` clears it on the configuration change that arrives
with this version, and then that line can go.

**A standing rule was too wide and is now corrected.** `CLAUDE.md`'s fact 1 read "place ghosts,
never a blueprint string". Searching every string in `runtime-api.json` for a simulation
restriction returns exactly one member — `create_entities_from_blueprint_string`. The rule was
true of that call and generalised past its evidence for four months.

**flib was checked and is not the answer**, which was worth confirming rather than assuming: it
has no blueprint helpers, no cursor helpers and no `LuaItemStack` code at all, and the one
function that would have mattered, `position.rotate`, does not exist. It is moot regardless — the
engine rotates the blueprint, so no rotator is written. The parked *Layout rotation* entry left
`deferred.md` for the same reason: it shipped for free.

No prior art for any of this exists in `exemples/` — nothing there puts a script-generated
blueprint in a cursor, and `on_pre_build` and `cursor_stack_temporary` have zero hits across the
whole tree. The two things worth taking from Space Exploration were `migrate.lua:1600` (a
blueprint authored purely from a Lua table, proving the shape works outside simulations) and
`blueprint-converter.lua:363`, which saves and restores the snap properties because
`set_blueprint_entities` clears them — not needed here, since this mod sets no snap grid, but the
kind of thing that would have cost an afternoon.

Suite: green, and meaningfully wider. `builder_spec` became `blueprint_spec` with the same
assertions against the same ghosts read back the same way — only the placement call changed —
plus the serialiser's own shape tests, the orientation tests, the undo test, and premise tests
pinning the build modes the mod now delegates to. `tests/support/stamp.lua` is new and exists for
one reason: the engine centres a stamped blueprint on the position it is given, so `fluid_spec`'s
absolute tap coordinates now go through a measured plan-to-world offset rather than assuming zero.

**A review pass then found the design flaw the rewrite had walked past.** `wire_to` was a *pole
ordinal* — a numbering private to `poles.plan` that `blueprint.lua` rebuilt downstream by walking
the whole plan and counting `pole = true`. Three modules agreeing on an invariant held by a
comment, and it fails silently in the worst way: a second pole pass, or a substation emitted from
`layout.lua`, shifts every ordinal by a constant and the copper lands on the wrong pairs —
geometry that still stamps, still previews, and still looks like a network. The fix belongs in
`planner.lua`, the one module that sees both numberings, which now rebases `wire_to` onto plan
indices as it appends. That deleted `pole_indices`, `pole_count`, the first-pass side effect, the
`pole = true` flag itself (the serialiser was its only reader) and the load-bearing-order comment,
and it left `blueprint.lua` knowing nothing about what a pole is. It is also a prerequisite for
the deferred circuit garnish rather than tidiness: a green wire between a belt and an inserter has
no per-type ordinal that could address either end.

Smaller things the same pass corrected: a `filter_mode` guard defending a shape `layout.lua`
cannot emit; `blueprint.give` returning a bare locale key where `planner.validate`'s house
convention is a ready-made message; `plan.quality`, ambiguous on a plan that holds a machine
quality, a recycler quality, a module quality and a pinned quality per tier, renamed
`target_quality`; and three comments in `planner.lua` still describing the snapshot and the tool.
Left alone deliberately: sharing the half-a-footprint centre rule between `blueprint.lua` and
`poles.lua`, because `poles.lua` requires nothing at all and that is what the pure host-Lua tier
rests on.

---

## 2026-08-17 — two regressions from the cleanup, reported from the game

The owner opened the mod and found the item and machine pickers dead: *"when i click on 'Item to
Upcycle' it does nothing anymore"*, and then the detail that named the cause — *"i can see a frame
but it disappears directly ... it opens and closes instantly"*.

**The cleanup pass had put those two handlers on the rebuild path, and `on_gui_click` shares a
dispatcher with `on_gui_elem_changed`.** So a click reached the handler *as the engine was opening
the button's own chooser*, the handler rebuilt the modal, and the rebuild destroyed the button with
the chooser on top of it. No error, nothing in the log — the picker just flashes. Only those two
pickers could hit it, because they are the only two that rebuild.

The fix is an equality guard rather than an event-name test: do nothing unless the value actually
changed. It keeps the specs able to drive the dispatcher with a hand-shaped event, and it wants the
*normalised* quality on the machine side — the button always reports one, the stored one is nil
until the player picks a tier, so a raw comparison reads every first click as a change.

**The third report was the placement, and it was a deeper mistake than the clamp admitted.** The
settings window is placed from the modal's width, inferred as `resolution - 2x` — exact for a
centred frame, and the modal is draggable. Dragged left the inference overshoots, so the window
went to the far right of the screen: *"they coordinates are being inversed"*, which is what an
overshoot looks like from the outside. The earlier clamp only kept it on screen; it did not make it
right. Now the **last plausible measurement is remembered per player** and reused whenever the
current reading falls outside the range a real modal can occupy. That is what makes a dragged modal
work at all, since nothing in the API reports whether a frame was moved.

Both are pinned, and both were confirmed by removing the fix and watching the new test fail. Worth
recording that the cleanup's own reviewers did not catch either: one was invisible without a real
client (no spec clicked a picker without changing it), and the other needed a player to drag a
window. **Suite: 116 passing**, and `api.md` gains §20 for the click-before-chooser ordering.


## 2026-08-17 — a cleanup pass, and the handlers stopped repainting by hand

Four reviewers over the same 0.3.0 diff, one each on reuse, simplification, efficiency and
altitude. Two of them independently named the same two extractions, which is the useful signal:
the modal and the settings window were building **the same fourteen-line titlebar** (three
separately load-bearing details in it — the filler's own `drag_target`, its 24px height matched to
`frame_action_button`, and the label's `ignored_by_interaction`), and five pickers each carried
their own copy of "the keys of a memoised candidate map, memoised". Both are now one helper:
`add_titlebar` and `names_of`.

**The altitude finding was the one worth the pass.** The recipe and machine handlers hand-repainted
four widgets each — machine filter, inserter value, the top module's filter and value, the pipe's
visibility — while the file header states the design is *rebuild, not repaint*. That was true when
a rebuild re-centred the modal and stole `player.opened`; this release fixed both, so the handlers
now just call `gui.open`. Twenty lines deleted, `widgets()` gone with them, and the pipe's
visibility — which had exactly one repaint site and would have needed a second the moment another
picker depended on the recipe — is derived in the one place that derives everything else. The
three specs that held an element reference across a handler now re-fetch, which is the honest
consequence: the modal really is rebuilt.

Smaller: `gui.open` gave up its 59-line defaulting preamble to `apply_defaults`; `filters_needed`
and the `#fluids == 1` test moved into `planner` as `filters_needed(recipe)` and `needs_pipe(recipe)`,
since both are planning rules the GUI was re-deriving; `quality_options` turned out to be `offered`
with different arguments; `module_items` became one `prototypes.get_item_filtered` call and now
feeds `module_candidates`, which was walking every item prototype once per effect;
`electric_inserter_candidates` filters the inserter table instead of rescanning every entity in
the game; and `validate` asks `is_quality_unlocked` once per distinct tier instead of once per
material — nine calls where the ordinary game has one answer.

**One block was deleted rather than moved.** `gui.open` normalised nine `*_quality` keys on every
open, and every read already goes through `planner.build_quality` or `with_quality`. It changed
nothing, but it read as load-bearing, so each new picker had been adding a line to it.

Four findings were recorded instead of acted on (`deferred.md`), the largest being that choice
reconciliation is written twice — purely in `planner.chosen_*`, destructively in the GUI — and has
already drifted enough to make one of validate's refusal messages unreachable. **Suite: 115
passing**, unchanged in count, which is the point: nothing here was meant to change behaviour.


## 2026-08-17 — Preferences became Settings, and a review found two live bugs

The owner asked for the titlebar's sliders glyph to become a button reading **Settings**, and for
the word *preferences* to go with it. The rename is mechanical — window, button, locale keys,
element names, dispatch tags, `gui.open_prefs` → `gui.open_settings` — and it is also the more
honest name: the two values genuinely are the mod's own per-player *settings*, editable from the
game's own menu.

The button was the interesting part. `frame_action_button` is a fixed 24x24 square with no room
for a word, but its **parent** `frame_button` is the same chrome without the size, so a plain
`button` in that style sits in the titlebar looking like the close X beside it once
`minimal_width` (108 by default), `height` (28) and padding come down to a titlebar's 24. The
sprite went with the glyph: `prototypes/planner/gui-sprites.lua` deleted and its `require`
removed, leaving the data stage at two prototype files. `api.md` §18 keeps the inversion finding
anyway, reframed — it is the answer for the next icon button, not a description of this one.

Then the owner reported the caption was black at rest. **`frame_button` inherits `button`'s font
colours, and vanilla's `button_default_font_color` is an empty table — pure black — with the
hovered colour matching it.** On a titlebar that reads inside out. `LuaStyle` exposes
`font_color`, `hovered_font_color` and `clicked_font_color` at runtime, so three lines on the
element do by hand what `invert_colors_of_picture_when_hovered_or_toggled` does for a glyph:
white at rest, black under the cursor.

**A code review ran in parallel and earned its seat.** Two reviewers, one on the runtime Lua and
one on conventions, tests and the published files; both returned *With fixes*. Two findings were
live bugs, and both were reproduced by tests written after the fact — then confirmed by removing
the fix and watching them fail:

- **Opening a chest while the settings window was up tore the planner down.** `close_settings`
  reclaimed `player.opened` unconditionally, and the API warns that opening a GUI inside
  `on_gui_closed` makes the engine force-close whichever one it was *not* asked for — here the
  modal, whose own close handler then destroyed it. Guarded on `player.opened ~= nil`.
- **A dragged modal pushed the window off the screen.** Its x is inferred from the modal's
  *centred* location and the titlebar makes the modal draggable: dragged right the width came out
  negative, dragged left it overshot. Silent both ways — the button just looked dead. Negative
  falls back to centring, and the x is clamped to keep the window reachable.

Neither was findable by running the suite, which was green on both. The rest were documentation,
and the worst of them were in files that ship: a **trailing space** in `changelog.txt` (a silent
parse failure — the changelog simply stops rendering), a `decisions.md` entry claiming four FAQ
entries where `faq.md` had two, a README sentence promising most pickers appear only with mods
when six of nine are visible in vanilla, and two behaviour changes the changelog never mentioned
at all. The FAQ gained the entry the register had already claimed for it. **Suite: 115 passing.**


## 2026-08-17 — the inserter and the three chests became pickers

Asked for by the repo owner: *"currently the inserters and the requester chests are being auto
selected, can you make it possible for the user to choose them in the menu?"*, with two
conditions — no stack inserters, and research-gated like everything else — and "default to the
best available, the current criteria seem to work". Four decisions came back from the questions:
**all three** chest roles rather than the requester alone, a quality on each picker, burners
never offered, and a minor bump (0.3.0 / 0.3.1). This closes the *Chest picker in the modal*
entry that had sat in `deferred.md` since 2026-08-15, when AAI Containers made the auto-pick
grab a 4x4 warehouse.

**Nothing new was invented.** The strip already had the shape five times over, so the work was
mostly instantiating it: a memoised candidate scan, a `buildable`-narrowed picker list, an
`is_*` membership test for prune, a `chosen_*` that falls back on a stale name, a default the
handler snaps an emptied button back to. Three places needed a real decision instead:

- **The chest roles became a table** (`CHEST_ROLES` + `CHEST_ACCEPTS`) rather than three copies
  of one predicate, which is what let the modal build all three buttons from a loop and share
  one dispatch handler keyed by a tag. `planner.container()` and `planner.logistic_container()`
  collapsed into `planner.chest(force, role)`.
- **The quality had to reach the ghosts**, so `inserter`, `container`, `requester` and
  `provider` are now `{ name, quality }` pairs in the layout params, matching the machine and
  the recycler. The bare-string-means-no-quality invariant fell out of that and is now written
  down in `decisions.md`.
- **`prune`'s quality list became a `_quality$` key match.** It was about to grow to eight names,
  and the failure mode of forgetting one is exactly what `state.arm`'s whole-table copy loop was
  fixed for.

**Two things the data dump caught that reasoning had not.** Base ships four 1x1 containers no
item can place — the crash-site pair and the two tips-and-tricks chests — so the show-all picker
offered scenery until both new lists gained the `items_to_place_this` gate the machine list has
always had. And the filter-slot refusal looked untestable in vanilla (all six inserters carry
five slots) until a query over every recipe in the dump turned up exactly one upcyclable recipe
needing six: fusion reactor equipment. Both are recorded in `analysis/api.md` §15.

**Suite: 100 passing, green on the first run** (90 before), plus luacheck 0/0 and emmylua_check
with no errors. The new specs are the picker lists and their three exclusions, the per-role
chest membership, the filter-slot refusal, picks and stale picks reaching (or not reaching) the
plan, prune keeping and dropping the new choices, and three GUI ones — the defaults, a role-keyed
chest write with its siblings untouched, and a recipe change re-picking an outgrown inserter. The
data stage still loads clean.

**Reading the diff back caught one thing the tests could not.** The new by-name filter-slot
refusal advised "pick an inserter with more filter slots" in a game where none has any — so the
three inserter refusals were reordered to ask `any_inserter` first: nothing available with enough
slots blames the recipe, and only past that gate is the pick named. That makes the vanilla path
the honest one and leaves the by-name branch reachable only with a modded inserter, which the
spec now says out loud instead of pretending to cover it.

**Then the top machine's module became the ninth picker**, asked for in the same session:
*"only pre-select productivity modules, if no productivity is allowed no pre-select any module,
make as available option only modules that are supported by the machine/recipe"*. Three things
came out of it beyond the picker itself.

The **quality-module fallback is gone**. When no productivity module was researched yet, the
terminal machine used to be filled with a quality module — a small yield gain, but a choice made
on the player's behalf at exactly the tier where quality has nothing left to roll into. The
default is now productivity or nothing, and the picker is where the alternative lives.

**The offered list needed a measured rule, and the obvious one was wrong.** "Every effect the
module carries must be allowed" would mean a speed module cannot go in an oil refinery — the
refinery disallows `quality` and the speed module carries `quality: -0.025`. A throwaway probe
spec (four holders × four modules, `can_insert` and a real insert, agreeing in all sixteen cases)
settled it: only the effects a module applies **positively** have to be allowed. The refinery
takes the speed module and refuses a quality module; the recycler refuses productivity. Written
up as `analysis/api.md` §16, including the second reading vanilla cannot distinguish and why the
conservative one is implemented.

**Nine buttons stopped fitting a row**, so the strip is a five-column table now — what moves the
items on the first row, what powers and equips them on the second. The two module pickers also
stopped sharing one quality: that was deliberate while the terminal module was *derived* from the
quality module, and became wrong the moment it was a choice of its own.

**Suite: 108 passing**, again green on the first run. The additions are the measured acceptance
rule against real prototypes whose `allowed_effects` differ, the per-pair offered list (gears
offer productivity, wooden chests do not), the productivity-or-nothing default, the pick reaching
the plan at its own quality while the recyclers keep theirs, clearing meaning empty, and two GUI
ones — a recipe swap dropping a module the new pair refuses, and a machine swap re-resolving it.

**And then the strip learned to hide itself.** Third request of the session: *"can you hide the
selectors if only 1 option is available?"*, with a list of pickers that must always be there —
item, target quality, machine, belt, quality module, pole — and one extra rule, that the pipe is
out until the recipe takes a fluid. The pole appeared on **both** lists in the request (named as a
hide example and then as always-visible); the explicit list won, and it has an independent reason:
clearing the pole picker means "no poles", so it is a choice at any count. The top machine's
module is exempt for exactly the same reason, which is the rule that resolved it rather than a
special case.

Two consequences worth recording. **A hidden picker takes its quality with it** — a vanilla game
can no longer ask for legendary recyclers or legendary logistic chests — which reverses the
2026-08-16 decision that the recycler row is always shown *because* its quality became pickable.
Flagged to the owner rather than quietly absorbed, and written into `decisions.md` as the trade it
is. And **the five-column table went away again**: it had been added an hour earlier because nine
buttons in a row would widen the modal, and the hide rule makes six the common case, so a single
row is right again. `visible` is documented as "taking no space in the layout", which is what
makes hiding a row inside a table reflow cleanly instead of leaving a hole.

`planner.buildable_pipes` was deleted as dead: the pipe picker narrows its own names list now,
because a *type* filter cannot be counted and the count is what decides visibility. **Suite: 109
passing**, green on the first run again; the new spec pins the four hidden pickers against
planner-level counts, so a modset that adds a second recycler fails the premise loudly instead of
silently contradicting the spec's claim.

**Fourth request: the settings moved into the modal.** *"In the main modal there is a button
'Preferences' that when we click it opens a 2nd modal... maybe we could do the same thing?"* — with
a screenshot of Factory Planner, and two preferences named: the existing *show unresearched* and a
new *show all build options*, which is precisely the escape hatch the hide rule above needed. The
owner also asked, mid-session, how FP actually does it. It has **no `settings.lua` at all** —
every preference is in `player_table.preferences`, filled by a `reload()` that keeps existing
values — and its nesting is `player.opened = modal_frame` with the main dialog's close handler
guarded by a stored `modal_dialog_type` flag, plus `player.opened = main_frame` on the way out
under the comment *"player.opened needs to be set because on_gui_closed sets it to nil"*.

Read, then deliberately not copied on the storage half. A throwaway probe spec settled three
engine questions in one 15-second run (now `analysis/api.md` §17): a mod **can** write its own
per-player setting, that write **does** raise `on_runtime_mod_setting_changed`, and handing
`player.opened` to another frame **does** get the modal destroyed. The first two make settings
strictly better than storage *here* — one value with two faces, one repaint path for both, and a
preference that survives into the next save, which FP's storage ones do not. FP's reason for
storage is thirty preferences of many widget types; this mod has two booleans. The third measured
answer is why `control.lua` now refuses a close on the modal while `gui.prefs_open(player)`, with
the window's existence as the guard rather than a stored flag — it cannot drift from the screen.

No gear exists in `data/core/prototypes/utility-sprites.lua`; the button is `utility/preset`, the
settings-sliders glyph vanilla uses for map-gen presets, and the owner picked it over a literal
iron-gear-wheel icon. Two small things fell out on the way: `strip_tooltip` became
`titled_tooltip` now that the titlebar uses it too, and both titlebars gained names — unnamed,
their buttons were reachable only by child index, which is what had kept the close button out of
the suite. Checkbox captions come from the `mod-setting-name` / `mod-setting-description` locale
categories, so the window and the settings menu cannot word one preference two ways.

**Suite: 112 passing**, green on the first run. The three new specs are the ones that would have
caught this feature's real failure modes: the window opening without taking the modal down with it
(the guard), the modal closing taking the window along, and ticking *show all build options*
rebuilding the modal with all four hidden pickers plus the fluid-less pipe visible. luacheck
caught one shadowed upvalue in a new spec helper; nothing else.

**Then the owner saw the button in game: dark at rest, white on hover — backwards.** The cause was
a style, not the sprite: `frame_action_button` sets
`invert_colors_of_picture_when_hovered_or_toggled` (`data/core/prototypes/style.lua:2797`), so it
supplies the hover state itself and the glyph it is given must be white. Vanilla's `close.png` is;
`preset.png` is black. Fixed with an `upl-preferences` sprite prototype — vanilla's own file with
`invert_colors = true`, verified white in both mip levels before writing it, and verified *read* by
a hand-built `--check-unused-prototype-data` run (zero unused properties: the only thing that
separates applied from silently ignored). No art drawn, none shipped. Detail in
`analysis/api.md` §18, along with the SpritePath rule that a bare prototype name is legal.

**And the error that arrived with it was a dev-loop artifact worth writing down.** The owner's
running game threw `Unknown sprite "upl-preferences"` from `on_lua_shortcut` while the dump showed
the prototype present and every checker green. Prototypes are read **once at process startup**;
loading a save re-runs `control.lua` from disk but never the data stage — so that process was
holding new GUI code over an old prototype set. A full restart is the fix, and no player can reach
the state. The same round's graphics run failed too, and separately: its log ends `Closed during
loading` at 19 s, killed mid sprite-load rather than erroring. Re-run clean, **112 passing in a
real client**, which is what actually proves the sprite resolves at runtime.

**Last round of the session: the window's default position, and a six-per-row grid.** The owner
sent a mock — Preferences to the right of the planner, top edges level — and asked that build
options never exceed six per row. The grid was a one-line change (`flow` -> `table` with
`column_count = 6`); the position was not, because **nothing in the API reads an element's rendered
size**. The way out is that an auto-centered frame's `location` gives its size back:
`size = resolution - 2 * location`, locale-proof where a hardcoded width is not.

Two things had to be measured in a real client, and a throwaway spec did both with
`take_screenshot{show_gui = true}` plus the centred-location trick (`analysis/api.md` §19).
**`location` reads 0,0 until a frame has been laid out** — the tick after it is built — so the
placement can only measure off a modal already on screen; the first attempt read it during a
rebuild, computed a width off a zero and put the window at x = 2575 on a 2560-wide screen. That is
also why a rebuild now **keeps the modal exactly where it was** instead of re-centring: the top
edge the window is levelled against stops moving, the modal stops jumping out from under the cursor
when a preference is flipped, and no re-placement is needed at all. **And a hidden child takes no
cell in a table**: six visible of nine measured 610px tall against 720px for all nine, which is one
strip row plus the recycler row — identical heights would have meant cells held. Confirmed by
screenshot: one dense row of six, and 6 + 3 when everything shows.

The suite earned its keep twice in this round. It caught `place_beside_modal` being defined *below*
`gui.open`, where the name resolved as a nil global — a non-recoverable error on the first
preference flip, from a change that looked obviously correct. And the screenshots needed the probe
to run alone: the framework prints every result to the console and `research_all_technologies()`
raises a queue of achievement toasts that draw over the modal and outlast a 600-tick wait.
`player.clear_console()` fixed the first, isolation the second. **Suite: still 112 passing** -- the
grid's column count is the one piece of geometry a headless spec can see, and it joined an existing
test rather than becoming another one.

Also corrected two stale numbers in `decisions.md` while reading it: the suite pins **210**
upcyclable items and big-pole's honest **3** unpowered, not the 185 and 7 from before 0.2.0.

---

## 2026-08-17 — released: 0.2.0 (Factorio 2.0) and 0.2.1 (Factorio 2.1)

Published at the repo owner's request ("you can release 0.2, update also description and faq
and gallery"), shipped 2.0-first on the lower number per the pair convention. The release
gate ran in full: the graphics tier drove the whole suite through BOTH real clients (90/90 on
2.1.14 and on 2.0.77) on top of the headless/pure/static greens, and both zips were verified
by listing before upload — `data-final-fixes.lua` in 0.2.0 alone, no tests or images or
CLAUDE files, `info.json` description byte-equal to the locale string inside each zip, one
identical changelog in both.

The owner rewrote the 0.2.0 section's entries in their own shorter words before the release;
kept verbatim except a parser-breaking trailing space and two grammar slips ("a fluids
ingredients", "Meanwhile only items"), fixed the way the 0.1.0 README slips were. The 0.2.1
section is the pointer per the pair shape.

The portal page moved in the same session: README and FAQ synced via `fmtk details`, and the
gallery went from four shots to five through the images API — the retired epic-substations
image identified among the portal's ids by hash (the image id IS the file's SHA-1; three of
four matched local files exactly, elimination gave the fourth), then the ordered edit list
placed 01, 02, the new fluid big-miners shot, 04, and the new extra-quality shot.
`{"success":true}` on every write. The 01 menu shot still predates the pipe picker — the
register's re-shoot flag stands for a future release.

---

## 2026-08-17 — the gallery refreshes for 0.2.0

The owner supplied two new gallery shots and retired one: the epic-substations image left,
replaced at slot 03 by the big mining drill's molten-iron loop to legendary in foundries on
Vulcanus — the 0.2.0 fluid feature photographed, pole columns and the under-ring pipe taps
in frame — and a fifth shot arrived, a modded loop climbing through mod-added quality tiers.
Renamed on arrival per the standing practice: only a "legandary" → "legendary" typo fix,
free because the portal never shows gallery filenames. The register carries the new list;
the portal gallery itself still shows the old set until a release syncs it with the owner's
approval, and the menu shot (01) predates the pipe picker — flagged in the register as worth
re-shooting before that sync.

---

## 2026-08-17 — the fluid feature ports to 2.0, one seam wide

The 0.2.0 feature commit cherry-picked onto `legacy/2.0` with exactly one conflict — the
forked `planner_spec` item-count pin — and exactly one API seam: **`LuaFluidBoxPrototype`
carries `volume` as an attribute on 2.0 where 2.1.7 replaced it with `get_volume()`**, so the
legacy `planner.lua` fork scores pipes by `box.volume`. Everything else the feature reads was
verified present and identically shaped in 2.0.77's own `runtime-api.json` before the pick
(`pipe_connections` with `direction`/`positions`/`connection_type`, `production_type`,
`max_underground_distance`); the two long-forked files took the main-side hunks cleanly and
were hand-reviewed to confirm the 2.0 adaptations (the mod-data bridge, the category shape,
the `contains_value` local) survived.

The class-3 questions — does 2.0's engine merge input boxes per recipe, does the outside tap
feed through the ring — were answered by running the whole suite on the 2.0 install rather
than assuming: **90/90 on 2.0.77** (pure 20/20, static clean, data stage exit 0 with the
legacy-only `data-final-fixes.lua` loading), with `fluid_spec`'s live rigs — the unrotated EM
plant on a west run, the player-side underground tap, the revive-and-craft pipeline — passing
unchanged. **The 2.0 track offers 212 upcyclable items** (187 base + the same 25 single-fluid
items), measured and pinned in the forked spec; `main` re-ran green the same session (90/90,
pure, static). Both branches' evidence: `analysis/factorio-2.0.md`, difference #4 and the
new measured-identical section. Release numbering for the eventual 2.0/2.1 pair stays the
owner's call at release time; legacy `info.json` remains at its released 0.1.4 until then.

---

## 2026-08-17 — nothing outside the ring: the header becomes outward stubs

The repo owner reviewed the freshly-built fluid geometry and redrew its boundary: **nothing
may be built outside the belt loop — not the pipe header, not even a pole** — with the fluid
offered as underground pipes on the two sides, the player choosing how to wire them up.

So the external header and its crossing rows (+2 height) went the same day they arrived.
Each utility column's run now spans the full interior height and ends in a pipe-to-ground
stub at each end — surface opening INTO the run (south at the harvest row, north at the
unload row), underground reaching outward beneath the ring belts. The player stands a
matching underground pipe outside, north or south, one tap per column, and interconnects
them however their base likes; the columns are independent networks until then. The "poles
outside" half resolved itself: with the extra rows gone, the plan's bounding box IS the ring
rectangle again, and the pole pass cannot place beyond the box.

Cheap to change because the header was never load-bearing: an interior header was impossible
from the start (every interior row is an inserter reach-chain), so the planned pipes were
always vertical, and a vertical run ends in an outward stub as naturally as in a crossing.
No planner, poles, GUI or state code moved — the whole diff is `layout.build`'s fluid
emission (and the row-shift machinery deleted, heights back to `8 + Hm + Hr` for every
plan). Engine side, nothing new needed measuring: a lone pipe-to-ground is an offered
connection until a partner appears, already §14's fact 5 — the live specs were re-rigged as
player-side taps (the hand rig taps a north stub, the revive-whole-plan pipeline taps tier
0's south stub) and the suite held at 90/90 with the fluid heights re-pinned at 15.

Recorded in `decisions.md` as its own bullet — the ring rectangle is the plan's entire
footprint — beside the rewritten fluid bullet; `layout-belt-ring.md` §Fluid recipes and
`api.md` §14.5/6 reworded to match.

---

## 2026-08-17 — fluid recipes and the utility columns: the 0.2.0 feature lands

The repo owner asked for fluid-recipe support and for poles in a dedicated column — one
column carrying both, its width adapting to what lives in it. Built end to end this session:
26 recipes / 25 items newly plannable (185 → 210), every machine rotated per prototype so its
fluid input meets a pipe run, and the suite grew from 74 to 90, all green (pure 20/20, static
clean).

**The shape was forced before it was chosen.** Three cheaper geometries died on paper against
measured facts: no row can be inserted anywhere inside the ring (every top- and bottom-side
position is part of an inserter reach-chain, and inserters reach exactly one tile), a
horizontal trunk cannot thread the existing rows at pitch 3 (single free tiles between
occupied ones, and a pipe-to-ground cannot be entry and exit on one tile), and a 1-wide
column cannot host a trunk T-junction. What survives: a full-width **header outside the ring**
(+2 rows), a **pipe-to-ground pair per utility column** diving under the top belt, and a
**run down each column's east edge** spanning the machine's full height. The measured
recycler-eject lesson repeated as `planner.machine_fluid_orientation()`: rotation computed
per prototype, never assumed — and vanilla proves it immediately, because the foundry and
cryogenic plant author their inputs on the SOUTH face (they stand facing east), while the
EM plant's inputs sit on opposite flanks (it stays north).

**Probes before geometry, and the probes paid.** A temporary in-game spec (deleted after; the
functional rigs graduated into `tests/fluid_spec.lua`) settled §9.4 — `positions` IS the
[N,E,S,W] rotation orbit — and found the fact that collapsed the hard case: **the engine
merges every input box a recipe needs into one live box exposing ALL their connection
points, and feeding any one feeds the machine** (`analysis/api.md` §14). A west run fed an
unrotated EM plant crafting supercapacitors, so no vanilla machine needs refusing. Output
boxes never materialise for fluid-input-only recipes, which dissolved the chemical-plant
always-visible-outputs worry unprompted. `IngredientPrototype.fluidbox_index` exists in the
schema but is nil throughout vanilla — the architect agent that found it also found
`PipeConnectionDefinition.direction`, which is what the orientation arithmetic actually
reads.

**The utility columns replaced the pole growth retry.** The owner's clarified rule — column
width = pole width, +1 when pipes join it, collapse only when both are absent — made "not
enough room" stop being a pole failure mode, so `poles.plan` lost its layout-rebuilding
retry and gained a two-attempt ladder: candidates inside the columns first, any free tile as
the honest fallback, kept only when it powers strictly more. Measured deltas worth the line:
the rare medium-pole loop now takes **3 poles in a tidy line** where free tiles took 5, and
the big-electric-pole worst case dropped from 7 unpowered to **3**. Widths moved
release-visibly (rare 11 → 14 with the default pole; the pinned scenarios re-measured and
re-pinned), and the cleared-picker fluid-free plan keeps the old 11 exactly.

**Design decisions of the session**, all the owner's: utility columns always (every plan with
poles), one fluid maximum (vanilla's only two-fluid recipe is ammonia-rocket-fuel, whose
product plain rocket-fuel covers — so zero items lost), a pipe picker in Build options (no
quality; the pipe-to-ground derived by the `<name>-to-ground` convention with a
longest-reach fallback, since no prototype links the pair), and no fluid status line in the
modal. Three architect agents (minimal / clean / pragmatic) blueprinted it first; the
minimal-diff design won — pipes emitted inside `layout.build` so any re-layout re-places
them by construction — carrying the pragmatic architect's probe-gated sequence, and the
clean architect's separate-fluids-module was declined for creating the exact re-run hazard
the inline emission cannot have.

**The end-to-end proof is a permanent spec**: a battery plan placed as ghosts, revived
whole, fed from an infinity pipe on the header, crafts on real ticks
(`fluid_spec.lua`) — the planner→layout→builder chain pinned the way `loop_spec` pins the
eject. Quantum processor stays out on a different axis (fluid PRODUCT — needs a drain
network, recorded in `deferred.md`), and the FAQ says so to players.

---

## 2026-08-17 — the docs audited against the research, and 0.2.0 opened

The repo owner asked for a no-exaggeration accuracy pass over every doc, folding in the
research. Reading everything back caught two errors in the previous entry, both worth the
correction on record. **The "per one recycler" claim was wrong**: the wiki's exact table —
re-fetched forensically after two extractions disagreed — puts AM3 at 208.5 : 30.4 : 9.8 :
2.9 : 1 crafters plus **52.8 recyclers** per sustained legendary crafter (about one recycler
per five machines); the "1 recycler" figure came from the page's *per-recycler-normalised*
table, a different table. `deferred.md` carried the error for a day and is fixed. And **"no
published design was found doing the tangent eject" overstated it**: the decoded reference
book — this mod's own ancestor, `analysis/blueprints.md` §1 — is built on the tangent
arrangement. The defensible finding is narrower: the wiki documents the mechanic, no surveyed
page presents the inserter-free machine feed as a feature, and the zero-circuit claim stands
unqualified.

What the pass added, each with its verification: `quality-math.md` §1 gained the 2.1.7 roll
rework (`next_probability` ×10 so a 100% effect guarantees an increase; `chain_probability`
now carries the multi-step rule — installed `data/changelog.txt`, sections confirmed by
line-mapping); §2 the wiki's exact per-tier module splits (fetched twice identically —
fractional productivity starts at the middle tiers even with normal modules); §3 the exact
pyramid and recycler counts; §6 the FFF-442 attribution — the agents' 2.1.12 dating of the
asteroid ban was checked against the changelog and rejected, 2.1.7 as the doc already said —
and the LDS shuffle's post-ban standing (community claim, t=133951). `blueprints.md` grew §9:
the reference lineage's afterlife (every reported bug is a hand-parameterisation slip; Kane99's
fork is the maintained successor) and the softened negative finding — recycler-only artifacts
do exist for self-recyclers, so that refusal now rests on economics, not absence, with the
matching bullets in `decisions.md` and `deferred.md` reworded. `api.md` §6 gained
`inserter_max_belt_stack_size` with the bulk/stack tie pinned to file:line, §7 the 2.1.7 read
family. `layout-bot-loop.md` gained the survey's scale evidence for the bot family.
`README.md` and `faq.md` needed nothing.

**The open section was re-graded 0.1.6 → 0.2.0 at the owner's direction** — the next release
is to carry a major feature — section header and `info.json` moved together per
`factorio-release`. The stack-inserter exclusion entry rides along unchanged.

---

## 2026-08-17 — the layout on trial against the wild, and the stack-inserter exclusion

The repo owner asked how the generated layout stands against community upcycler designs. Three
web fan-outs (architecture families; concrete shared blueprints; creators and theory) came back
with the design validated on every structural axis: per-tier pinned columns are both the
dominant published family and what the maths says to build (the wiki's upcycling-math tutorial,
exyr.org's Feb-2026 equilibrium solution, dfamonteiro's matrices all agree), terminal
productivity is the universal optimum, buffer chests are the community's own fix for roll
variance, and the 2.1.7 asteroid-casino ban — announced in FFF #442; the research agent
misattributed it to 2.1.12 and the installed `data/changelog.txt` line 334 settled it — moved
the endgame meta back onto exactly this loop family. Two things no published design was found
doing: running with zero circuits, and the tangent eject feeding the machine with no inserter —
every published build ejects onto belts. kvdveer's own thread carries the argument for a
generator over a book: its reported bugs (a legendary filter left on the epic stamp, requester
counts of 1000, missing undergrounds) are all hand-parameterisation slips, plus third-party
fix-forks. What the wild does better, already known and now confirmed: fluids, machines-per-tier
scaling, and circuit quantity-stops.

One code change fell out. The community documents belt-stacking inserters freezing in
quality-recycler builds (a stacking hand holds out for a full belt stack of one item-and-quality;
ktz.me, 2026-04-08), and the pick could not defend against it: bulk-inserter and stack-inserter
tie the scorer outright — both `bulk`, both rotation 0.04 — so the winner was engine iteration
order. The owner's call: belt-stacking inserters are never planned. `inserter_candidates()` now
excludes `inserter_max_belt_stack_size > 1`, with a spec whose premise is asserted loudly so it
cannot pass hollow. The review also caught that `loop_spec`'s relief rig stood a hand-chosen
fast-inserter, so the wedge-relief measurement had never covered the inserter the layout
actually plans — the rig now takes `planner.inserter()`'s own pick, and the measurement holds
with the bulk inserter: a partial hand drains the stuck plate from the recycler output. Suite
74/74 headless (was 73), pure and static tiers clean; changelog section 0.1.6 opened with the
entry, `info.json` bumped to match.

Throughput, answered from the same research: no rival architecture beats this family — what
beats the current build is the same skeleton scaled. The wiki's sustained ratios for AM3 are
208:30:10:3:1 crafters per single recycler, so the taper is ~7x then ~3x, not a flat 10x, and
one recycler outruns a whole column (2.1.13 made recycling faster still). The wild's throughput
shapes are circuit-blocked belt bulks and bot farms; the route here, if scaling is ever asked
for, stays "repeat columns per tier" (`deferred.md`), with the ring as the eventual bandwidth
ceiling and the deferred bot loop as the shape past it.

---

## 2026-08-16 — two release pairs, and the description that lived in three places

The flag work above shipped, and then shipped again an hour later to fix something the first
release carried out the door.

**Released 0.1.2 (2.1) / 0.1.3 (2.0)** on the owner's approval. The portal tag question the
entry above left open is now **answered: the public page shows a "Space Age Mod" label**, so
`quality_required` alone earns it and `space_travel_required` was never needed
(`analysis/api.md` §13). Worth knowing that the tag appears only on the HTML page — no JSON
API endpoint exposes it, which is exactly why it could not be checked before uploading.

**Then the owner caught what the release had missed: `[mod-description]` in the locale file
still said "Pick" where `info.json` said "Choose".** That is the more instructive half of the
day, because the locale entry **overrides `info.json`** — so the in-game mod browser had been
showing the old wording the whole time, and every check that had been run looked at
`info.json` and passed. The description effectively lives in three places (`info.json`, the
locale `[mod-description]`, and the README's opening line, which is the portal's long
description) and only the first two are the same string. **Released 0.1.4 (2.0) / 0.1.5 (2.1)**
to correct it, with the zips verified by asserting the locale string and `info.json`
description are byte-equal *inside the built zip* rather than on disk.

Two process notes worth keeping:

- **The portal summary read stale immediately after an upload, then corrected itself.** After
  the first pair it still showed the old wording even through a cache-buster, which read as
  "the portal does not refresh summary from later uploads" and nearly bought an unnecessary
  `edit_details` write. It was just the CDN lag `factorio-release` already warns about. Give it
  time before concluding a portal write did not land.
- **`git tag` ran even though the `git commit` in the same batch had failed**, pinning the tag
  to the pre-release commit. Caught because the tag was checked against HEAD before pushing;
  it had not left the machine. Verify what a tag points at before pushing it — a release tag is
  supposed to reproduce the uploaded zip exactly.

Also reconciled drift that predated all this: `thumbnail.png` had never received the 7720ccd
pip fix on `legacy/2.0`, and the two `info.json` descriptions had diverged — invisible to
`git diff` because `info.json` is a declared divergent file, but the portal renders the
description of whichever release is newest, so the wording would have flip-flopped between
tracks on alternating releases.

---

## 2026-08-16 — Space Age feature flags, and the one that does not exist on 2.0

The repo owner asked for the flag that makes the Space Age DLC mandatory, then for the mod to
show up in the portal's Space Age section. Both landed, but the second ask is the one that
actually decided the design.

**The no-flag decision was reversed for a reason the old one never considered.** The original
call weighed enforcement only, and on that ground it was right: behind a hard `quality`
dependency, the flag gates nothing extra, because `quality` ships with Space Age and nothing
else. What it missed is that the **mod portal tags a mod as Space Age from the expansion flags
in its uploaded `info.json`, not from its dependency list** — so the mod was invisible in the
portal's Space Age section no matter how hard the dependency was. That is not something the
enforcement argument can see, and it is why the reversal is not a contradiction of the old
entry so much as a different question.

**The flag was measured rather than trusted, and the measurement paid.** Declaring a flag is a
one-line edit that looks obviously correct, so the temptation was to write it and move on. Four
throwaway probe mods — `info.json` only, one flag, no `quality` dependency — run against the
two no-expansion installs settled it instead, and turned up the thing that would have shipped
wrong: **`expansion_required` does not exist in Factorio 2.0.** The 2.0 probe declaring it
**loaded clean on an install with no expansions at all**. Silently ignored, gating nothing — a
dead field that reads at a glance exactly like a working gate. The engine's own startup log
confirmed it independently: 2.1 enumerates eight feature flags, 2.0 enumerates seven, missing
`expansion`. Vanilla `quality/info.json` agrees, declaring both flags in 2.1 and only
`quality_required` in 2.0. Full table in `analysis/api.md` §13.

So the flags fork along the same seam `info.json` already forks on, which is tidy: `main` gets
`expansion_required` + `quality_required`, `legacy/2.0` gets `quality_required` alone. Both were
verified to refuse a no-expansion install; `quality_required` is the one carrying the gate on
both tracks.

Two things worth knowing next time. **A refused mod crashes under `--dump-data` rather than
printing a tidy error** — `ModManager::enterMinimalMode` in the stack trace on 2.1,
`ModManager::loadData` on 2.0 — so the exit code alone reads as an ordinary failure and the
stack trace is where the answer is. And **`space_travel_required` was rejected on honesty
grounds**, not technical ones: it would have earned the portal tag too, but it unlocks planet
and space-platform prototypes this mod never touches.

What is still **unverified**: the portal tag itself. The portal API exposes no feature-flag
field on any endpoint, so whether the Space Age section actually picks the mod up can only be
confirmed after an upload — which needs the owner's approval for that specific release anyway.
Wube's own statement (forum `p=698604`) names the expansion flags collectively rather than
singling one out, and `quality_required` is among the DLC's own set, so the expectation is good
but it is an expectation.

Shipped as a paired release, prepared and stopped before upload: `0.1.2` for Factorio 2.1 and
`0.1.3` for Factorio 2.0, both sections open at `Date: ????`. Both builds validate clean.

---

## 2026-08-16 — a permanent test suite, and the eject question answered

The scratch-harness era ended today: the assertion matrix every session had been rebuilding by
hand is now a committed 73-test suite under `tests/`, run by the new repo skill
`factorio-testing`. Deep research (three web fan-outs: frameworks, outside-game testing, real
mod CI) picked **factorio-test** — the only maintained, 2.1-ready framework; the owner
approved the framework, all tool installs, GUI as core scope and the eject investigation, and
the shape held through implementation: in-game specs for state/planner/plan/builder/loop/gui,
`tests/pure/` for layout and poles running both in-game and on host Lua (14 specs,
sub-second), and a static tier (luacheck clean at 0/0; emmylua_check against fmtk-generated
2.1.14 typedefs, 0 errors with warnings listed).

**The standing caution is resolved, and the answer is worse and better than assumed**
(evidence: `analysis/api.md` §9.6): a rolled-up ingredient in the recycler's output does not
politely stall the eject — it **wedges the recycler entirely** (furnace output semantics; 40
gears sat unprocessed, `products_finished` 0 on both buildings), and only the blacklist relief
inserter keeps the loop alive: with it, the stuck plate drained to the chest, all 40 gears
recycled, the machine crafted on, nothing lost, nothing wrong-quality delivered. The relief
inserter is load-bearing, now guarded by a test. Deterministic seeding: script-inserting into
`defines.inventory.crafter_output` works and stands in for a lucky roll.

**gui.lua ran for the first time — in both tiers.** The discovery that made it cheap: a
singleplayer save's player stays *connected* under `--benchmark` (§12 of api.md), so even the
headless suite drives the real modal through `dispatch.on_gui_event` with real widgets — the
whole flow up to Confirm arming the tool into the cursor. The graphics tier verifies the same
against a real client, unattended after three fights: the CLI's bundled 2.0-era save shows a
migration dialog (fix: create a current-version save each run), freeplay's intro blocks the
first join (fix: `set_skip_intro`/`set_disable_crashsite` baked in at save creation, test-only
code path), and graphics mode never closes itself (fix: the runner watches for the framework's
finish marker and kills only dev-install processes). The owner sat through the two failed
window-opening attempts; the third ran hands-free.

The historical numbers all reproduced on first run — widths 11 and 13, the five pole
scenarios including big-pole's 15-wide growth with exactly 7 honestly-unpowered consumers,
the 185 offered items, wooden-chest's empty terminal machine, the 100-plate request cap — so
the suite genuinely is the old matrix, made permanent. Two of the day's failures were the
suite teaching *me*: `{ field = nil }` is an empty table (the refusal test passed vacuously
until a remove-sentinel fixed it), and pole-wire assertions must test connectivity, not edge
counts, because ghost poles auto-preview-connect on top of the builder's spanning tree.
Smaller API facts: `get_filter()` hands back a plain string; `tags()` marks the *next* block
defined, not the enclosing one; spec files are required before `game` exists.

Windows plumbing worth its journal line: the CLI spawns a bare `npx`, which cannot resolve on
Windows — a scoop shim (`node.exe` + `npx-cli.js`) fixed it, worth reporting upstream — and
its default portal-credential source is `%APPDATA%\Factorio`, dodged permanently by seeding
the framework mod through fmtk with the **dev install's** `player-data.json`. Installed and
recorded in `CLAUDE.local.md`: factorio-test-cli 3.6.0, Lua 5.5, luacheck 1.2.0,
emmylua_check 0.25.1.

A three-agent review closed the session. Conventions: nothing. Simplicity: a stale comment
pointer, and the vanilla params fixture duplicated across the two pure specs — now one copy
in `tests/support/layout_params.lua`. Correctness: four, the real one being that the
quality-dropdown spec **could not fail** — nothing changed research mid-test, so the
tag-frozen list and a fresh derivation were identical; it now un-researches two quality
technologies before firing and selects index 4 of a list a re-deriving handler would have
shrunk to two. All fixed; all tiers re-run green (73/73 headless, 73/73 in the real client
through the runner's `-Graphics` path, pure 14/14, static clean). The owner set the cadence —
checkpoints rather than per-edit, suites opt-in per mod, the graphics pass at releases — now
written into this mod's `CLAUDE.md`, the `factorio-testing` skill, and `factorio-release`
step 3. The runner was also prepared for the legacy track (data dirs keyed per install,
`recycler` auto-dropped where an install ships none), and the skill's 2.0 section became the
session checklist for it: fork `loop_spec` for the `furnace_*` inventory names, re-measure
the 185.

**The suite then went to the 2.0 track the same day**: cherry-picked to `legacy/2.0` (one
hand-resolved conflict, `info.json` as always) and 72/73 on the very first run. Both
checklist predictions dissolved on contact: the `loop_spec` fork never happened —
`defines.inventory.crafter_input` and `crafter_output` already exist on 2.0.77, 2.1 merely
removed the `furnace_*` aliases — and the one real fork is `tests/planner_spec.lua`, because
**the 2.0 track offers 187 upcyclable items where 2.1 offers 185** (measured, not itemised).
The seeding lesson: fmtk's plain `mods install` grabs the overall-newest framework release, a
2.1-only build the 2.0 game refuses to load, so the runner now picks the newest release
matching the install's own major.minor from the portal API directly.

## 2026-08-16 — first release: 0.1.0 (Factorio 2.0) and 0.1.1 (Factorio 2.1)

Published at the repo owner's request, which named the pair: the 2.0 build took `0.1.0`, the
2.1 build `0.1.1`, shipped 2.0-first per the release-pair convention. The first publish went
through the v2 `init_publish` API — `fmtk upload` cannot create a new mod name — and 0.1.1
followed as an ordinary `fmtk upload`. Before upload, both builds validated against their own
installs (exit 0, checksum line present, `--check-unused-prototype-data` silent on both), and
both zips were verified by listing: the legacy-only `data-final-fixes.lua` ships in 0.1.0
alone, `changelog.txt` and `README.md` byte-identical in the two.

The portal page was set in the same session: license `default_gnugplv3` (a new mod defaults to
MIT), category `utilities` (Mining Patch Planner's own), the README synced as the description
via `fmtk details --readme`, and the four `images/` shots uploaded in filename order — all
four ids came back non-empty on the first try, and the cache-busted `/full` GET read back two
releases, each serving its own `factorio_version`.

The changelog took the pair shape before packaging — 0.1.0 carries the entries plus the
game-naming line, 0.1.1 is the pointer section, one identical file on both branches — and five
grammar slips in `README.md` were fixed (it ships in the zip and is the portal description);
no claim changed. Tags `upcycler-planner_0.1.0` and `upcycler-planner_0.1.1` mark the two
commits.

## 2026-08-16 — ported to Factorio 2.0, forked on the legacy branch

Repo owner's ask: the first version is good enough for a release, so make the 2.0 build real
and testable in the 2.0 dev install. This reverses the 2.1-only decision, whose stated reason —
"`recycler` is 2.1-only" — turned out to be about the *mod*, not the machine: on 2.0 the
recycler entity, the `recycling` technology and the recipe generation all ship inside the
`quality` mod (`data/quality/prototypes/entity/entity.lua`, eject vector `{-0.5, -2.3}`, which
`recycler_orientation` lands north with `eject_col = 0` exactly like 2.1's `{-0.35, -2.3}`).

**The whole API surface was checked against the 2.0 install's own `doc-html/` before touching
code**, and nearly all of it is identical at 2.0.77 — `insert_plan` on ghosts, the logistic
point/sections/`trash_not_requested` machinery, wire connectors, `manual_ghost`, every
quality-parameterised getter, the `-with-quality` elem types, even
`defines.inventory.crafter_modules`, which 2.0 already carries with the old per-machine names
merely deprecated. Three real differences (`analysis/factorio-2.0.md` is the full record):

- `LuaRecipePrototype.categories` is 2.1-only; 2.0 has `category` + `additional_categories`,
  and reading a `LuaObject` attribute the running version lacks is a hard error, not nil.
- `can_set_quality` has no 2.0 runtime mirror at all. A new `data-final-fixes.lua` records
  every recipe with `allow_quality == false` into a mod-data prototype
  (`upl-no-quality-recipes`), and the planner reads it through `LuaModData.get`. Vanilla 2.0
  does set the flag (oil cracking, lubricant, a catalyst recipe), so the bridge carries real
  content, though those all fail the fluid gate anyway — its real audience is modded games.
- `util.contains_value` is 2.1-only in core's lualib. The recycler icon also moves mods:
  `__recycler__` on 2.1, `__quality__` on 2.0 — the same 120x64 strip in both.

**The shape changed mid-session, at the owner's correction.** The first build gated all of
this inside shared files (a base-version seam in `planner.lua`, a `mods["recycler"]` probe in
`icons.lua`), so that every file except `info.json` stayed identical across branches. The
owner rejected it: the 2.0 track is temporary — it stops getting work when 2.1 goes stable —
and gated 2.0 code sitting in `main` would confuse readers long after it stopped mattering.
Reworked to **forked files on `legacy/2.0`**, with `main` reverted byte-for-byte to its
pre-port state: the legacy branch carries its own `planner.lua` (2.0 category shape + the
bridge read), `icons.lua` (quality-mod icon path), `gui.lua` (local `contains_value`) and the
legacy-only `data-final-fixes.lua`; the divergent-file list is declared in the repo
`CLAUDE.md` → *Git* beside Pure Modules'. Reason recorded in `decisions.md`.

**Verified end to end on both installs, before and after the rework.** Data stage: exit 0 on
2.0.77 and 2.1.14, `--check-unused-prototype-data` silent on both, and `compare-dumps.py`
shows the shortcut and selection tool identical across versions — the only mod-authored
difference is the mod-data bridge, present on 2.0 alone, and the only other row is the
*generated* `upl-planner-recycling` recipe drifting in the known engine ways
(`category`→`categories`, `probability`→`independent_probability`). Runtime: the usual
`--create` harness, extended to cover the port (bridge contents, categories-driven machine
matching) and run against **both** installs — 38/38 on 2.0.77 and 37/37 on 2.1.14, with
byte-equivalent plans (130 ghosts, same picks, 7 wired poles) placed and read back on each.

The check tooling learned something from this: `check-ai-docs.py` used to hold every note to
the install beside the repo, which breaks in both directions once a mod straddles two — this
file's 2.0 evidence read from `main`, `api.md`'s 2.1 citations read from the legacy worktree.
It now resolves each *evidence* file against the install matching its own `verified_against`
(found through the git worktrees, each of which sits in its own install), and holds unpinned
notes — journal, registers — to "any pinned install knows this name", since the journal is
allowed to go stale by design.

The port sits in the legacy worktree **uncommitted**. Release numbering for the pair is
deliberately still open — one shared sequence, owner's call which track takes the lower
number — and `changelog.txt` therefore keeps its single open `0.1.0` section until that call
is made. The GUI remains the one thing no harness can reach on either version; the 2.0 fork
adds nothing GUI-side beyond the `contains_value` local, so the standing in-game checklist is
unchanged.

## 2026-08-16 — the shortcut icon was drawing wrong, and nobody could see it

The repo owner asked for the shortcut icon as an image, and sent a screenshot of the toolbar: a
tiny recycler shoved into the top-left with a legendary flower swallowing the rest of the button.
`--dump-icon-sprites` reproduced it exactly — a graphical run that writes the **engine's own**
icon composition to `script-output/<type>/<name>.png`, so a layered icon can be looked at without
opening the game. Ours dumped 121x121 where every vanilla shortcut dumps 24x24.

The cause is in `IconData::scale`, and it is a rule rather than a bug: scale and shift are
measured against the **prototype's expected icon size**, which is 64 for an item but 32 for a
shortcut's `icons` and 24 for `small_icons`. `icons.lua` was shared between the selection tool
and the shortcut *deliberately*, so the two could not drift — and that sharing is exactly what
broke it, because the same `scale = 0.28` means half again as much on a shortcut. Full write-up
in `analysis/api.md` §11.

Fixed by writing the composition once as fractions of one icon and resolving it per consumer, so
the sharing survives with the rescale done in one place.

**Then the design question turned out to be the real one.** A corner pip on a full-size recycler
is the obvious fix and it reads as *a legendary recycler* — the owner wanted *legendary +
recycler*, two symbols, which is what the broken version had been accidentally showing. Ten
dispositions across two rounds were dumped and composited at the owner's real button size
(measured off their screenshot: the style's 40 px at ~115% UI scale, 2 px padding), and the
button went `blue` -> `green` at their ask.

**The second round existed because the first pick was still clipped.** Leaning the two layers
away from each other looked symmetric written down, but a negative shift does not grow the
composed canvas — it pushes the layer off it, and the recycler was cut to a sliver while empty
margin sat in the opposite corner. Nobody would have caught that by reading the numbers; the
dump showed it, with the alpha bounding box ending 16 px short of the canvas. Settled at
recycler 0.85 unshifted, pip 0.80 shifted 0.38 down-right — all the separation on the layer that
grows the box.

`thumbnail.png` came out of the same work: 144x144, the game's own green plate 9-sliced up with
the composed icon inside, built from the dump rather than upscaled from a screenshot. That
clears the last housekeeping item that was blocking a release on art grounds.

**Two things worth keeping from the tooling side:** the dump needs a *staged copy* of the mod
(`--mod-directory` must never point at this repo), and a broken layered icon shows up in the
dumped file's dimensions before anyone looks at the picture.

## 2026-08-16 — the readme becomes the portal page, and the portal images arrive

Rewrote `README.md` twice at the repo owner's ask. It is what `fmtk details --readme` uploads, so
it is written for someone skimming the portal rather than for a contributor: a hook, four numbered
steps, one line per bullet in the build list, the modded-content claim, and four limits under
*Good to know*. Two of the edits were corrections rather than taste — "blueprint" left the opening
because the mod places ghosts and never makes one, and the licence link now points at GitHub,
since a relative `[LICENSE](LICENSE)` does not resolve on the portal.

The owner then supplied the images: four screenshots for the gallery, and two demo GIFs for the
description body, hosted on catbox. How the portal takes an image was checked rather than assumed
— Mining Patch Planner's own description embeds media as bare markdown images, an mp4 among
them — and the gallery turned out to re-host under hashed URLs, with no filename surviving, which is
what makes numbering the gallery files free. It is all in `decisions.md` → *Portal presentation*.
**Nothing is published and nothing is scheduled to be**; the material is gathered so a later
release does not have to guess at it.

Renamed on arrival: underscores to hyphens, the gallery files prefixed `01`..`04` in the order the
owner asked for (menu, then vanilla, then modded), and `images/gif helpers/` to
`images/description/` — a folder with a space in it gets quoted wrongly by something eventually,
and the new name says what the files are for rather than how they were made.

## 2026-08-16 — electric poles join the build

Repo owner's ask: build the loop with poles — a picker for the pole and its quality, the pole
layout optimal for its range, every electric consumer inside supply, and sizes beyond 1x1
handled. Four calls made up front, all the owner's: the default is the best researched **1x1**
pole (largest supply area — a substation is never sprung on the player, though every size is
pickable), and clearing the picker means "place no poles"; the layout grows only when free
tiles cannot reach full coverage; a pole that cannot cover even then places best-effort with a
warning rather than refusing; and the picker is one `entity-with-quality` widget like the rest
of the strip.

**The shape: a fourth pure module.** `scripts/poles.lua` runs after `layout.build` inside
`planner.plan`: occupancy read off the plan's own entities, candidate positions wherever the
footprint fits, greedy set cover under the quality-adjusted supply radius, a bridge pass for
wire-reach connectivity, one growth retry through a new `column_gap` layout param (kept only
when strictly fewer consumers stay unpowered), and Prim spanning wires the builder draws onto
the ghosts (`pole_copper`, ghost-to-ghost). Algorithm and measured shapes:
`analysis/poles.md`; engine facts: `analysis/api.md` §10.

Two pieces of the design carry their reasons:

- **Coverage counts only the largest wired component.** Raw geometric coverage would call a
  consumer powered when its only pole sits on an unwired island — a lie that surfaces in game
  as a mystery — and counting it unpowered is also what makes a connectivity failure drive
  growth.
- **`chosen_pole` is the one resolver with a none-state.** `choices.no_poles` (a boolean,
  `trash_unrequested`'s precedent) tells "cleared on purpose" apart from "never touched";
  only the explicit clear suppresses the researched-best default, and the pole handler is the
  one picker whose emptied button does not snap back — an empty button *is* the "no poles"
  state on display. `resources()` was deliberately not made its home: everything there is
  mandatory-if-valid, and the pole is the one optional material.

**Verified with the usual harness, 28/28** (`--create`, full research, plans built for five
choice sets, ghosts placed on real ground and read back), which also settled three engine
facts now in `api.md` §10: the powering rule is collision-box **overlap** with the supply
square (a machine straddling the edge with its centre outside IS powered); revived pole
ghosts auto-connect within reach; and ghost-to-ghost `connect_to` on `pole_copper` returns
false while creating the wire — the builder ignores the return value on purpose. Measured
solver behaviour worth keeping: rare-tier default is five medium poles in free tiles with no
footprint change; the same loop under legendary-quality medium poles takes **one**; substation
plus legendary target grows 17→25 wide and covers with two; the big electric pole lands
best-effort with seven consumers warned about.

A three-agent review pass the same session (correctness, simplicity, conventions) returned
one real defect and one cleanup, both applied and re-verified at 28/28. The defect: the
coverage stand-in shrank every consumer by a flat 0.3 — right for machines and the recycler,
but an inserter's collision box insets 0.35, so for inserters the stand-in was a SUPERSET of
the real box and could claim power the game would not deliver at a knife-edge distance —
exactly the lie the honest tally exists to prevent. The margin is now computed per prototype
from its real collision box (larger axis, clamped short of half a tile), so the subset
property holds for modded entities too. The cleanup folded a twice-written centre-distance
formula into one `distance_sq`. The conventions pass found nothing to change.

## 2026-08-16 — renamed to Upcycler Planner

Repo owner's call, reversing the name chosen the previous day. *Architect* had been picked over
the genre's usual *Planner* to sidestep two collisions at once — `generator` is Factorio's own
prototype type for power entities, and the plain `Upcycler` mod already exists and does
something else — with the acknowledged cost that it is not the word the genre uses. That cost
turned out to be the one that mattered: Mining Patch Planner and P.U.M.P. are what a player is
searching for a sibling of, so **Upcycler Planner** is legible where *… Architect* asked the
player to work out what the mod was. The collisions it was avoiding never bit — `planner` is not
a prototype type, and `upcycler-planner` is a distinct portal name from `upcycler`.

Free to do now and only now: **nothing has shipped.** No `upcycler-architect_*` tag exists, the
portal name was never claimed (`GET /api/mods/upcycler-architect` still 404s), and `0.1.0` is
still the open section. After a release this would have been a new mod rather than a rename —
the portal has no rename — so the window closes at the first upload.

What moved, in one pass:

- Folder, `info.json` `name`/`title`/`homepage`, and `locale/en/<name>.cfg` — the folder name and
  `name` must match exactly or Factorio silently skips the mod.
- The per-player setting `upcycler-architect-show-all` -> `upcycler-planner-show-all`, its two
  locale keys, and the constant in `gui.lua`.
- **The prototype tag `ua-` -> `upl-`**, since "UA" stood for the old title: shortcut `upl-open`,
  selection tool `upl-planner`, the `[upl-gui]` / `[upl-message]` locale sections, every GUI
  element name, and `dispatch.lua`'s `upl_handler` tag key. `up-` was the obvious successor and
  was rejected as too generic — "up" reads as a direction, and the tag has to be recognisable as
  a mod's namespace at a glance in a flat global namespace.

**No migration file.** Renaming a prototype normally costs one plus a major bump, but neither
prototype persists into a save: the shortcut is a per-player toolbar pin and the selection tool
is `only-in-cursor`, so nothing holds a reference. `storage` keeps only the player's picks —
recipe, quality and entity names belonging to other mods — and none of ours. An existing dev
save loses its shortcut pin and its setting value, which is the whole cost.

`changelog.txt` needed no entry: the 0.1.0 section is the unreleased initial one and never named
the mod, so there is no published text for the rename to contradict.

## 2026-08-16 — a Build options block, and quality on the things the loop is built from

Repo owner's ask, modelled on Mining Patch Planner's *Miscellaneous settings* panel: a section at
the bottom of the modal for the knobs that tune the output rather than describe it.

**Two blocks now.** The top frame is what the loop **makes** — item, target quality, machine,
recycler. Under a `caption_label` reading *Build options* sits a second frame holding what it is
built **out of**: a strip of unlabelled icon pickers (belt, quality module) and the
trash-unrequested checkbox, which moved down out of the top block. The pickers carry no row label
on purpose — the strip reads by icon, the way the game's own tool settings do — so each tooltip
opens with its own name in `[font=default-bold]`, which is exactly the row label it would have
had. The status line moved out of the content frame onto the window, wrapped and capped at 360px:
the longest validation messages run to a sentence and a half and an unbounded label drags the
whole modal out to their width.

**Quality is pickable on the machine, the recycler and the quality module**, through
`elem_type = "entity-with-quality"` / `"item-with-quality"`. **Not on the belt**, and that is a
measured call rather than a taste one: `belt_speed` is a plain attribute with no quality variant
the way `get_crafting_speed(quality)` has one, so a legendary belt carries exactly as much as a
normal one.

Verified live, 39/39, with the usual `--create` harness (assertions appended to a scratch copy's
`control.lua`, full research, ghosts placed on real ground and read back):

- **`create_entity{name = "entity-ghost", inner_name = ..., quality = ...}` really does produce a
  ghost of that quality.** `quality` is a *common* `create_entity` parameter rather than one of
  the `entity-ghost` variant group, so unlike `recipe` it does apply here. This was the one
  genuinely unverified fact in the change, and it is the counter-example to the variant-group
  trap in `analysis/api.md` §3 — not everything outside the group is inert, only the parameters
  that belong to *another* group.
- `insert_plan`'s `id.quality` carries the picked module quality onto the ghost.
- Module slot counts are read with `get_inventory_size(defines.inventory.crafter_modules,
  quality)`. `module_inventory_size` is documented as the normal-quality figure only, and
  `quality_affects_module_slots` — false for every vanilla machine — can raise it on a modded one.

**Storage stays flat strings.** The `-with-quality` widgets speak `{name, quality}` tables, but
the choices are kept as separate `machine` / `machine_quality` pairs. Two reasons, both silent
failures: `control.lua`'s stated contract is that storage holds nothing but strings, and
`state.arm`'s snapshot is a **shallow** copy — a nested table would stay *shared* with the live
choices rather than frozen at Confirm, so reopening the modal with a tool in hand would change
what was about to be placed.

**The recycler row is no longer hidden in vanilla.** It used to appear only when a mod added a
second recycler, on the grounds that one recycler is not a choice. With quality pickable it is a
choice on any modset, so the row is always shown and the `#recyclers == 1` special case that went
with it is gone — a remembered recycler now simply persists, as the belt already did.

### The bug the module work uncovered

`RecipePrototype.allow_productivity` defaults to **false**, and only ~43 of base's 193 recipes opt
in. The terminal machine has always been given a productivity module, and nothing ever consulted
`recipe.allowed_effects` — so for every upcyclable item that is not a vanilla intermediate (the
harness picks `wooden-chest`) the loop was planning a module the machine cannot accept, which
would sit unfilled in the insert plan forever.

Fixed at the repo owner's call by **leaving those slots empty**. A machine can allow quality
without allowing productivity, so both the recipe's and the machine's `allowed_effects` are
consulted. Research is deliberately kept as a separate axis: *not researched yet* still falls back
to the quality module, which is a small loss of yield rather than a gap, while *not allowed at
all* leaves the slots empty.

Worth noting how the fix had to be written. `is_terminal and terminal_module or quality_module`
falls through to the quality module on exactly the nil that means "leave it empty" — the idiom
quietly does the opposite of the fix — so it is an explicit `if`.

Three smaller gates went in beside it, all the same class: a rule the loop depends on that
nothing was checking.

- **`is_upcyclable` now requires `allowed_effects["quality"]` on the recipe.** `can_set_quality`
  is a different rule with a confusingly similar name — craftable *at* a quality, versus quality
  modules working on it at all — and a recipe passing one while failing the other would have
  carried an insert plan for a module it can never accept, while the recyclers kept rolling
  ingredients up regardless — a loop that limps rather than stops, which is the harder kind to
  diagnose. The **recycling** recipe is gated the same way and for the same reason, since the
  recyclers carry quality modules too. No vanilla recipe is affected either way: the offered
  item count stayed at 185.

  The alternative not taken: leave the *non-terminal* machines' slots empty for such a recipe
  and let the recyclers carry the climb alone, which would keep those items in the picker at
  roughly half the roll rate. Excluding them is simpler and honest — a loop the mod cannot
  build properly is better refused than shipped degraded — but the option is real, so it is
  written down rather than left to be re-derived.
- **`planner.recyclers()` requires the same of the recycler**, with a matching `validate` gate so
  a remembered recycler cannot outlive the rule.
- **`validate` checks the picked module's category** against the machine, the recycler and the
  recipe (`allowed_module_categories`, nil meaning everything is allowed). The player picks the
  module now, so one that something refuses is reachable in a modded game.

### Still unverified

The **GUI itself has not been run**. There is no way to create a player headlessly — no
`create_test_player` in 2.1's API, and `--create` / `--benchmark` join nobody — so every check
above exercises `planner`, `layout` and `builder` and none of them touch `gui.lua` beyond proving
it parses. The specific thing to watch on first open is whether **`elem_filters` is accepted on
the `-with-quality` elem types**; the docs say the applicable filter follows `elem_type`, and the
machine picker passed the same `EntityPrototypeFilter` as a plain `"entity"` picker before this
change, but it is an assumption until the modal opens. It fails loudly if wrong — a rejected
filter is a hard error at `add()`, not a silent empty list.

The second unknown is quieter and matters more to the design: **whether a custom `tooltip` on a
`choose-elem-button` still shows once the button holds a value**, or whether the chosen
prototype's own tooltip takes over. The whole icon strip rests on it — those two pickers carry no
row label, so the tooltip is the only thing naming them. 2.0 added a separate `elem_tooltip`
attribute for showing a prototype tooltip on any element, which reads as evidence that plain
`tooltip` is not the same channel, but the docs do not say and there is no headless way to ask.
If the elem tooltip does win, the fix is a small label above each button inside the strip —
which is the labelled-rows layout the repo owner explicitly did not pick, so ask before doing it.

A code-review pass the same day found one more instance of the same class and it is fixed: the
**terminal machine's productivity module was never category-checked**, though the quality
module beside it was. They are different module categories (`productivity` vs `quality`), so
a machine or recipe restricting `allowed_module_categories` to quality would have passed
validation and then refused the module — precisely the defect the terminal rule exists to
prevent. Gated inside `resources()` rather than as a fourth `validate` branch, so the existing
`or quality_module` fallback absorbs it and plan/validate agreement holds by construction.
Vanilla sets `allowed_module_categories` on nothing at all, so this is mod-only.

The same pass caught that **clearing the machine or recycler picker reset its quality to
normal**, contradicting the recipe handler one file over, which deliberately keeps the quality
when the machine is swapped on the grounds that the player asked for legendary machines rather
than a legendary assembler. All three pickers now keep the quality on clear.

## 2026-08-15 — first structured code review, and what it fixed

Three parallel reviewer agents read the whole codebase against these notes. Everything below
was fixed the same session and verified with a fresh live harness (35/35, SA modset,
`--create` with assertions appended to a scratch copy — including builder placement on real
ground). The two worth remembering:

- **The long-handed inserter won the inserter pick for the whole early game.** The pick scored
  bulk + rotation speed and never checked reach; long-handed is electric, filterable, faster
  than the plain inserter, and unlocked by `automation` — the first technology — so from
  automation until fast-inserter every planned inserter grabbed from the wrong row and the loop
  placed cleanly and did nothing. The earlier 19/19 matrix tested fresh/electronics/full and
  skipped exactly that window. Fix: the memoised inserter candidate table admits only one-tile
  reach (`reaches_adjacent_tiles`, reading `inserter_pickup_position` /
  `inserter_drop_position`, api.md §6), so `any_inserter` inherits the rule and the
  fuel-message split stays truthful. The automation-only state is now in the harness matrix.
- **Confirm could destroy what the player held.** `clear_cursor()` returns false when the
  cursor cannot be emptied (full inventory), and `set_stack` on top of that overwrites the
  stack. Now gated, with a `cursor-full` message; the pending snapshot is armed only after the
  tool is actually in the cursor.

The rest of the round:

- `state.prune` drops choices by **membership** in the planner's candidate lists rather than
  bare prototype existence — a mod update can keep a name while changing the prototype under
  it, and prototypes only ever change on configuration change, which is exactly when prune
  runs.
- `validate` re-runs the full machine gate plus a machine-can-craft-recipe check, and requires
  the recycler to still recycle and carry module slots; `builder.apply_modules` tolerates a
  nil slot count.
- A click on an armed tool whose snapshot was pruned clears the cursor and says so, instead of
  silently doing nothing.
- A **blocked placement cancels the deconstruction orders it just placed** — only its own,
  pre-existing marks survive — keeping the "leaves the world untouched" contract honest.
- Ghosts land on `event.surface`, not `player.surface`, via a context argument to
  `builder.place`.
- The **terminal catcher whitelists the product at the target quality and every quality above
  it** (clamped to filter slots, nearest first), closing the product half of the
  above-target-roll leak; the ingredient half stays in `deferred.md`, now with a warning about
  the fix that does not work.
- The placed-count message reports ghosts actually created; the quality-chain walk is bounded
  by iterations so an all-hidden malformed cycle cannot hang it; and `validate` takes
  `(force, choices)` like `plan`, so the two central entry points cannot be called with
  swapped arguments unnoticed.

A simplify pass the same session (four review agents: reuse, simplification, efficiency,
altitude) settled three structural invariants, each now documented at its site in the code:
**candidate scans are memoised, force checks never are** — the pickers' pure prototype
predicates live in `candidates()` tables beside `machine_candidates()`, while buildability
and research run fresh per call, which cut a GUI refresh from ~15 full prototype scans to
force-filtering a handful of short lists (`validate` also hands its gathered resources to
`plan` so one refresh pays once); **layout owns its geometric minima** — `MIN_MACHINE_WIDTH`
and `MIN_RECYCLER_WIDTH` are exported constants the planner consumes, so the gates cannot
drift from the column arithmetic they derive from; and **prune tests membership through
planner-exported predicates** (`is_belt`, `is_quality`) rather than restating the rules. The
Confirm snapshot moved into `state.arm()` as a whole-table copy so a new choice field cannot
be silently left out of it. Verified by the same harness, extended to 36/36.

## 2026-08-15 — researched-only pickers, the first setting, and the inserter fuel rule

- **Every picker offers only what the force has researched** — items (canonical recipe
  enabled), machines, recyclers, belts (buildable), qualities (`is_quality_unlocked`). The
  game's own "Show all items in selection lists" option is **not exposed to the runtime API**
  (searched 2.1.14's `runtime-api.json`), so a per-player bool setting,
  `upcycler-planner-show-all`, stands in for it — the mod's first `settings.lua`. An empty
  researched subset falls back to the full list so the modal never dead-ends; the frame
  rebuilds on `on_runtime_mod_setting_changed`.
- **The quality dropdown's offered list rides in the element's tags.** Research can finish
  while the modal is open; an index into a re-derived list would then name the wrong quality.
  The default target is the highest *offered* tier, and a remembered choice that is no longer
  offered snaps back to it.
- **Fuelled inserters are never used** (`burner_prototype` / `fluid_energy_source_prototype`)
  — an unattended loop cannot keep them fed. `planner.any_inserter` ignores the rule so
  validate can tell "everything researched needs fuel" (its own message,
  `only-fuelled-inserters`) from "not enough filter slots". **A fresh Space Age force
  genuinely starts burner-only**, so that message is the correct day-one state, vanilla
  included; the electric inserter takes over the moment electronics lands.
- **Status colours by severity**: red when Place is disabled, orange for warnings — which
  refresh used to compute and then silently drop; they render now.
- Two traps for the record: the inserter speed is the METHOD
  `get_inserter_rotation_speed(quality)` — the `rotation_speed` ATTRIBUTE exists but belongs
  to cars and turrets and reads nil on an inserter (the arithmetic crash lived on disk for
  minutes and the repo owner's live game caught it before the harness report landed); and
  per-player settings read through `player.mod_settings`, not `settings.global`.

Verified live, vanilla modset: 19/19 across fresh/electronics/full-research states, including
the fuel-only refusal message and the researched-subset lists at both extremes.

## 2026-08-15 — modded recyclers: rotation computed, any width fits

Age of Production's salvager (`aop-salvager`) broke the layout twice at once: 4x4 against the
3-tile column pitch (recyclers overlapped into a train), and an eject vector out its EAST
flank (`{2.35, -0.5}`) where the layout hardcoded vanilla's north throw — "not properly
rotated" was literal. The general facts, all verified live:

- `vector_to_place_result` is per-prototype and rotates with direction, and the game hands it
  over in ARRAY form (`[1]`,`[2]` — documented "will always provide the array format").
- The layout's real requirement was never "faces north": it is "the eject tile lands in the
  row directly above the footprint", the machine's bottom row under tangency.
  `planner.recycler_orientation()` tries the four rotations and returns direction, rotated
  footprint and eject column, or nil. Vanilla → north 2x4 col 0; salvager → WEST 4x4 col 1.
- **Width is not a constraint.** The first fix refused `Wr >= Wm`; the repo owner pushed back
  and re-deriving against the *implemented* layout showed the strict-width rule came from the
  reference design's down-the-side product channel, which was never built — the real product
  path runs up to the top ring, so the recycler band is empty beside the recycler. Column
  pitch is now `max(Wm, Wr)` (terminal column stays at `Wm`), and the only remaining limit is
  that the throw lands inside the machine: `eject_col < Wm`, refused with the minimum width
  named (`recycler-needs-wider-machine`). Lesson: check a constraint against the code, not
  against the doc that described the design before it was built.
- `best_recycler` prefers the narrowest oriented buildable recycler, so vanilla's stays the
  default over the salvager.

Verified live with PlanetsLib + AoP: salvager + AM3 plans 2 west-facing salvagers at width 13
(`2 + 2*4 + 3`), salvager + the 5-wide `aop-advanced-assembling-machine` at width 17, vanilla
byte-identical at width 11 — with a generic no-overlapping-tiles check and an
eject-tile-is-a-machine-tile check green on all three. The harness's overlap and eject
invariants are the ones to re-run after any row-plan change.

## 2026-08-15 — chests are hard-constrained to one tile

AAI Containers & Warehouses made the largest-inventory rule pick its **4x4 requester
storehouse**, and the placed rows overlapped into a solid wall of warehouse ghosts — every
chest position in the layout is exactly one tile, so footprint is a geometric constraint of
the row plan, not a preference. `container()` and `logistic_container()` now require
`tile_width == 1 and tile_height == 1` before scoring by inventory. A modded 1x1 chest with
more slots still wins legitimately; anything bigger is out regardless of research.

Worth remembering from the same screenshot: the overlapping ghosts **placed successfully** —
the all-or-nothing `can_place_entity` pass checks each position against the *current* world,
so N ghosts that each fit alone but collide with each other all pass, and `create_entity`
does not refuse the collision either. With every real entity at most one tile per layout
cell the layout cannot self-collide, so this stays a latent fact rather than a bug — but any
future change that lets a planned entity outgrow its cell has to revisit it.

Verified live with AAI + EE + all research: picks return to `requester-chest` /
`passive-provider-chest` / `steel-chest`, a rare plan carries zero chests bigger than 1x1.
A chest-type picker in the modal was floated by the repo owner as a maybe — parked in
`deferred.md`; the hard 1x1 filter is the default behaviour either way.

## 2026-08-15 — three GUI traps from the first session with the new inputs

All three found by the repo owner in game, all three silent.

- **`elem_value` is not an `add()` parameter.** It is a runtime attribute; `add()` ignores
  unknown fields without a word, so a picker "pre-filled" inline opens empty. Verified against
  `runtime-api.json`: `add` accepts `elem_filters` but has no `elem_value`. This is why the
  belt picker showed blank while the machine picker *looked* fine — the machine value was
  being assigned at runtime by the recipe-change handler, never by `add()`. Every picker now
  assigns `elem_value` after creation.
- **`elem_filters = nil` means NO filter, not "nothing yet".** Clicking the machine picker
  before choosing an item offered every entity in the game, belts and chests included. The
  fallback is `planner.machine_candidates()` — every machine the mod could ever plan with
  (the static `is_upcycling_machine` checks, no recipe-category match).
- **Padding on a checkbox displaces the check mark.** `style.top_padding = 4` shifted the
  widget's content — the mark — down while the box graphic stayed put, leaving a half-clipped
  tick hanging out the bottom of the square; measured on the owner's screenshot, displacement
  equals the padding. Diagnosed against core's own sprites (`gui-new.png`: box {56,132},
  checkmark {112,132}, both 28x28 — the real mark fills the box and overshoots top-right).
  Spacing on a leaf widget with custom drawing is a margin's job: `top_margin` displaces
  nothing.

## 2026-08-15 — the modal grows a belt picker and a trash checkbox

Both at the repo owner's ask, the same session as the research gating.

- **Belt picker**, defaulting to the fastest researched belt — the previous automatic choice.
  A slower ring is a legitimate call (the fast belts are expensive and the ring is short), so
  the belt is the one building material with a player override. An emptied button snaps back
  to the researched best and shows it, so the row always displays the belt that will actually
  be placed; a stale or wrong-type name falls back the same way at plan time.
- **"Trash unrequested items" checkbox, checked by default.** Only the trash half of the
  requester flags is exposed: request-from-buffers is purely additive and stays always-on,
  while trashing has a real downside — bots hauling surplus off to storage — that some players
  will want off. The flag rides on the *plan*, not through the layout: which chests exist is
  geometry, what they do with surplus is the player's call at Confirm. A pending snapshot from
  before the checkbox existed reads as checked (`~= false`).
- One dispatcher quirk: a checkbox click fires both `on_gui_click` and
  `on_gui_checked_state_changed`, and both are routed, so the handler runs twice per click. It
  reads the element's current state, which makes the repeat harmless — cheaper than teaching
  the dispatcher to filter by event.

Verified in the same live-harness style: 28/28, including the belt override, the wrong-name
fallback, and all three trash-flag states riding the plan.

## 2026-08-15 — building materials are gated by real research

First in-game feedback (a save with Editor Extensions installed) surfaced two bugs with one
root: `is_unlocked` counted *any* enabled recipe that produces an item, and **researching
`recycling` enables every generated `*-recycling` recipe at once** (`analysis/api.md` §8).
Reversal recipes produce the ingredients of what they grind, so `quality-module-3-recycling`
made unresearched quality-module-2 read as unlocked; and EE's infinity chests — whose only real
recipes are disabled cheat recipes, and which never opt out of recycling — got self-recycling
recipes, so the requester picker returned `ee-infinity-chest-requester` by iteration order.
Reproduction showed it worse than reported: `ee-super-productivity-module` (+250%) won the
productivity pick the same way, and would have kept winning at full research.

Three guards, all in `planner.lua`:

- **Recycling recipes never count as producers.** They consume the item class; counting them as
  a source inverts causality ("could grind one down" is not "can build one").
- **Factoriopedia-hidden recipes never count either.** That is how cheat tools ship free
  recipes, and EE force-enables its `ee-testing-tool` recipes whenever a player turns its
  editor helpers on — so an enabled-recipe test alone would regress during exactly the editor
  sessions this mod gets tested in. `hidden_in_factoriopedia` sits on `LuaPrototypeBase`
  (parent-key trap, `analysis/api.md` §6).
- **The chest picker takes only real `logistic-container`s, largest inventory first.** Infinity
  containers report a `logistic_mode` too, and a chest that conjures items out of nothing is
  never a correct buffer in a loop whose job is to conserve one population of items. Best-by
  also replaces first-iterated, so the pick is deterministic. This layer holds even in cheat
  mode, independently of the producer guards.

Verified with a scratch harness (real game via `--create`, EE and flib loaded, assertions
appended to a scratch copy's `control.lua`): 17/17 pass across fresh, recycling-only,
cheat-mode, per-recipe-unlock and full-research states, ending in a full rare-tier plan with
five `requester-chest` ghosts and zero `ee-` entities. As a negative control the producer guard
was reverted and the harness reproduced the original bugs (quality-module-2 and
ee-super-productivity-module picked with only recycling researched) — the test detects what it
claims to.

## 2026-08-15 — first implementation

Built the same day: shortcut, modal, planner derivations, the pure layout function and the
ghost builder. The mod is functional end to end and the data stage validates clean.

Two things learned the hard way, both worth not repeating:

- **`RecipePrototypeFilter` has no `name` filter**, though `EntityPrototypeFilter` and
  `ItemPrototypeFilter` both do. A `choose-elem-button` with `elem_type = "recipe"` and a
  computed name list is a hard error: *"Unknown filter type: name"*. This is why the first
  input is an **item** picker with the recipe derived from it — which is how the mod was
  described anyway. Verify a filter against the *specific* concept, never by analogy to
  another one.
- **Recycling recipes pass a naive upcyclability test.** A self-recycling recipe takes an item
  and returns that same item, so it trivially "closes the loop" while producing nothing. They
  have to be excluded by category — the recycler mod excludes the same category when
  generating recipes. Before the fix the picker offered 276 items; after, 185.

Also settled during implementation: the ring is a plain rectangle with a dedicated return
column rather than the shared blueprints' underground-threaded loop, because at this height the
span beneath a machine exceeds even a turbo belt's reach. And the extract chests inside the
loop are **plain containers** — but the product buffer in front of each recycler ended up a
**requester chest** after all, so bots can top it up when the ring runs slow; the engine's
quality-exact request rule keeps every tier above normal sealed from the base regardless. The
full set of network contacts and their counts is in `analysis/layout-belt-ring.md` §Request
counts.

## 2026-08-15 — architecture

Second session the same day. Two real upcycler blueprints were decoded (the repo owner's own,
and a 12-blueprint book found online), ~14 more designs were read, both reference planner mods
were cloned and studied, and the quality maths was checked against the wiki and FFF-375. The
condensed record is in **`analysis/`** — start at `analysis/index.md`. Everything below is a
decision; the evidence for it is there.

**The mechanism that explains the whole reference design** — and the thing most worth not
re-deriving: the recycler is a 2x4 furnace with `vector_to_place_result = {-0.35, -2.3}`
(`data/recycler/data.lua:109`), so it **throws its output out of its north face like a mining
drill**. Every reference build stands the recycler directly under its machine, tangent, so
recycled ingredients reach the crafter with *zero inserters*. The machine is pinned to
`recipe_quality = q_k` and quality ingredients match **exactly**, so an ingredient the recycler
rolled up a tier would jam the eject — which is what the blacklist-filtered inserter beneath the
recycler is for. Keep the tangency; it is the constraint everything else hangs off.

**The layout is parametric in more than tier count.** The online book solves the same design at
four target qualities across three machine types, which pins the scaling law: machines `t+1` at
pitch = the machine's tile width (3 for an assembling machine, 4 for an electromagnetic plant
with its 5 module slots, 5 for a foundry), recyclers `t`, only the terminal column different.
That is the argument for a layout *engine* rather than a stored blueprint — and the "with
fluids" variants in that book are actually **unbuildable as captured**, because a parameterised
blueprint loses the machine rotations that fluid connections need. A mod that knows the real
recipe at plan time can fix exactly that.

## 2026-08-15 — feasibility investigation

The question was whether a mod can compute an upcycling layout and place it in the world the
way Mining Patch Planner and P.U.M.P. place theirs. **It can.** Both reference mods were
extracted from the local `*.zip` copies and read; every API call below was verified against
`doc-html/runtime-api.json` from the installed 2.1.14, not from memory.

### Placement: ghosts, not blueprint strings

Neither reference mod uses a blueprint string. Both walk their computed layout and call
`surface.create_entity{name = "entity-ghost", inner_name = ...}` one entity at a time:

- `pump_2.2.2/constructor.lua:208` — `create_entity{name = "entity-ghost", ...}`
- `mining-patch-planner/layouts/*.lua` — the same, behind a `builder.create_entity_builder`
  wrapper; `layouts/simple.lua:1968` does tile ghosts the same way.

This is the route to use, and **the blueprint-string route is a dead end**:
`LuaSurface.create_entities_from_blueprint_string` is documented *"This method only works when
used in simulations"* — it exists for menu-background sims, not for mods.
`LuaRecord.build_blueprint` is real and usable, but it needs an actual blueprint record to
exist first, which buys nothing over emitting ghosts directly. Computing ghosts also means the
layout can respond to the player's choices instead of being a stored string.

### Every piece an upcycler specifically needs exists

Verified present in 2.1.14:

| Need | API |
|---|---|
| Place a ghost of any entity | `create_entity` `entity-ghost` group: `inner_name` (req), `tags` |
| Machines that are themselves quality | `create_entity` param `quality`, defaults to `normal` |
| Set the recipe on a planned machine | **`ghost.set_recipe(recipe, quality)` after creation** — see correction below |
| Request quality modules into the ghosts | **`ghost.insert_plan`** — see correction below |
| Read back what was planned | `LuaEntity.ghost_name` / `ghost_prototype` / `ghost_type` / `item_requests` / `quality` |
| The P.U.M.P. interaction model | `SelectionToolPrototype` + `on_player_selected_area` / `_alt_` / `_reverse_` |

Pinning the recipe's quality is exactly the axis an upcycler is built around — one machine per
tier, each pinned to that tier.

**Two rows above were wrong when first written, and were corrected on 2026-08-15** after
checking `runtime-api.json` directly. Both are load-bearing, so the detail is in
`analysis/api.md` §3 and only summarised here:

- **`create_entity` cannot set a ghost's recipe.** Its variant groups are keyed by the `name`
  argument, so with `name = "entity-ghost"` only `inner_name` and `tags` apply —
  `recipe`/`recipe_quality` belong to the `assembling-machine` group and never take effect.
  Create the ghost, then call `set_recipe(recipe, quality)` (positional, recipe first).
- **Modules go through `insert_plan`, not an `item-request-proxy`.** `LuaEntity.insert_plan` is
  read *and* write with `EntityGhost` among its subclasses; `LuaEntity.item_requests` is
  read-only in 2.1. Both reference planner mods use `insert_plan`, and the proxy would need the
  ghost to exist first anyway.

### Prior art: the niche is open

No mod generates these layouts. Checked on the portal:

- [`upcycler`](https://mods.factorio.com/mod/upcycler) — unrelated. A machine that converts N
  items into 1 of the next tier. Shares the word only.
- [`quality-cycler`](https://mods.factorio.com/mod/quality-cycler) — shifts quality up/down
  *inside* an existing blueprint. Does not design anything.

Everything else is hand-shared blueprint books — [FactorioBin](https://factoriobin.com/post/8wj94j/6),
[the forums](https://forums.factorio.com/viewtopic.php?t=121438), Factorio Prints. That is the
gap: players answer the same layout questions by hand every time.
