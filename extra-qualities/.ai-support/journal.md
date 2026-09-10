# Journal — Extra Qualities

Dated sessions, newest first. Append-only: entries are history and may go stale. Only a moved
file path is ever repaired in place.

## 2026-09-10 — ported to Factorio 2.0, and the odds rescale was the whole job

`legacy/2.0`, version 0.1.1, clean against base 2.0.77 with Space Age. Four files fork; the
list and the reasons are in `decisions.md`.

**The one that would have shipped broken is `next_probability`.** 2.1.7 divided quality effect
values by ten and multiplied `next_probability` by ten together, so 2.1's 1.4 and 2.0's 0.14
describe the same 14% step. Copied across unchanged, the 2.1 numbers would have made every step
ten times as likely on 2.0 — the mod's entire difficulty curve gone — and nothing would have
errored, dumped oddly, or logged a word. It is exactly the silent class the multiversion skill
warns about, and the only reason it was caught is that the skill says to read the behaviour
entries before porting rather than after validating.

Three fields simply do not exist on 2.0 and were removed rather than left to be ignored:
`chain_probability`, `locomotive_power_multiplier`, `rolling_stock_max_speed_multiplier`. So the
2.0 build gives no train bonuses above legendary and can never skip a tier on a roll. Both are
recorded in the changelog under 0.1.1, because a player would notice.

**`data-final-fixes.lua` forked for a reason that only appeared when counted.** The `quality` mod
un-hides `normal` on 2.1 and does not on 2.0, so the shown count differs (7 against 6) while both
games build 8 qualities in total. The 2.1 rule of `shown + 1` would have set 2.0's threshold to 7
with 8 qualities present — losing the row of buttons, which is the single thing this file exists
to protect. The 2.0 file counts the total instead. Vanilla 2.1 disproves the strictest reading
on its own: it builds 6 qualities against a threshold of 6 and still shows buttons.

The dump diff is what turned all of this from argument into evidence: four 2.1-only fields
absent, `next_probability` differing by exactly ten, and **no difference at all** in
`default_multiplier` or in any of the four technologies. The strength ladder and the gating are
identical on both games, which is the part that had to be true.

## 2026-09-10 — a review pass found the registers quoting a ladder that no longer ships

A code review over the three commits found the Lua clean and the notes stale. The session below
retuned the odds from `1.5 / 1.4 / 1.3 / 1.2` to `1.4 / 1.3 / 1.1 / 1`, regenerated the cost
table in `balance.md`, and left the prose under it describing the old ladder. Ten lines apart
the same file gave two answers to the same question: the table said mythic costs 238–348 and
the paragraph said 182–265.

**The failure is worth naming because the rule already covers it.** `../CLAUDE.md` says a
register is edited in place; what happened is that the *generated* part was and the written part
was not, which reads as a maintained file rather than a stale one. Regenerating a table is a
mechanical act and pasting it is easy to finish; rereading four paragraphs against it is not,
and was skipped. Every wrong number in the review came out of that one boundary.

Fixed by re-running `qsim.py` and rewriting against its output: the cost prose, the like-for-like
table, the per-step ratios (claimed 1.5x–1.9x against vanilla's 2.9x–3.5x; actually 3.5x, 4.1x,
2.5x, 2.0x, 1.5x against vanilla's 3.9x, 4.3x, 2.8x), the without-the-retune figures, and the
two `deferred.md` items that quoted them. `analysis/quality-roll-mechanics.md` said its measured
block was taken "on the ladder as shipped" when the probe ran against the draft — the numbers
are real and are kept, relabelled, because what they demonstrate is that the engine multiplies
linearly, and five distinct values do that better than three.

Three claims were wrong on their own terms rather than stale. The strength ladder is monotone
absolutely but not proportionally (25% a step with two 28% blips), and the requirement was
stated proportionally. `level` runs 0, 1, 2, 3, 5, 6, 8, so every *counted* bonus steps +2 into
legendary and +1 into mythic — the requirement is met on strength and knowingly not on those.
And "the engine rejects zero" was true of `beacon_power_usage_multiplier` (must be >= 0.01) but
not of `mining_drill_resource_drain_multiplier`, whose range is `[0, 1]`; zero there is legal
and would mean free ore, which is a design refusal, not an engine one.

**One finding is not a documentation problem and is now the top open item.** The 1.62x cap
measures 1.57x one way and 1.77x the other. Like for like, modules held constant, the odds
retune buys 1.57x — that is how it was measured when the cap was set, and it is under it. End
to end, which is what a player pays, it is 1.77x, and the mod's own headline table has said so
since it was written. The difference is epic's multiplier moving 1.9 → 2.0, which makes epic
quality modules farm legendary faster; that change predates the cap and was never counted
against it. Nothing was changed pending the owner's ruling, and both numbers are now in
`balance.md`.

Also recorded as open, both from the same review: the asteroid collector's collection radius
defaults to `level`, so celestial reaches 15.5 off a 7.5 base, and the API warns that the
navigation pre-calculates for the highest tier that *exists* — a cost every Space Age save pays
on install, researched or not. And `legendary.next = "mythic"` is assigned unconditionally, so a
second mod adding a tier above legendary silently orphans one of the two.

## 2026-09-10 — the odds retune capped, after the discount was checked instead of trusted

The owner queried a changelog line, "working up through the older quality tiers is about twice
as quick", as sounding too generous. It was. Measured like for like, holding modules constant so
only the odds differ, the retune bought 1.41x at uncommon, 1.62x at rare, 1.88x at epic and
2.06x at legendary. "About twice" was the top of that range, not the middle, and the sentence
claimed it of every older tier.

**The compounding was the part that had gone unexamined.** Reaching legendary passes through
every step below it, so four modest per-step boosts multiply into a discount far larger than any
one of them. Nothing in the original design accounted for that; the numbers were set per step
and the cumulative effect was never measured until it was questioned.

The owner capped it at 1.62x. A search over non-increasing odds restricted to whole percentages
at the 10% reference gave `1.4 / 1.3 / 1.1 / 1.0`: legendary 1.58x, every tier under the cap,
and all four percentages distinct and descending so the README table reads cleanly. **Only the
first three steps are retuned now.** From epic upward the odds are vanilla's, which is both the
mechanism of the cap and a rule that states itself.

Two player-facing claims went with it, both now false and both fixed: "about half the material"
became "about a third less", and a second overstatement found while re-reading, "a steady 25%
better", became "about 25%" since two of the six steps are 28%.

The lesson worth keeping: **a per-step number and a cumulative outcome are different quantities,
and only the second is what a player experiences.** `qsim.py` could have said so at any point.

## 2026-09-10 — the strength ladder set as a whole, vanilla's tiers included

Third correction from the owner on the same ladder, and the one that showed the earlier two
were fixing the wrong thing: with mythic at 3.0, epic → legendary (+32%) was a bigger jump than
legendary → mythic (+20%).

**It was not tunable.** Vanilla's multiplier is a flat +0.3 per level and legendary sits two
levels above epic, so that one step is +32% against rare → epic's +19%. With celestial pinned
at crafting speed 5 there is only 1.6x of headroom from legendary upward, and `1.32² = 1.74`.
No arrangement of the two new tiers alone can keep the steps from shrinking. Two attempts had
already each fixed one end and broken the other — 3.2 gave shrinking ratios, 3.0 gave a
sawtooth — because both treated vanilla's numbers as fixed.

The owner refused all three ways out that changed the anchor, and was right to: **the mod
already retunes vanilla's odds and redraws vanilla's icons, so vanilla's multipliers were never
the untouchable thing I was treating them as.** Setting the whole ladder to one constant ratio
of about 1.26 hits celestial at exactly 5, keeps every assembling machine 3 speed on a round
number, and costs two changed vanilla values: uncommon 1.3 → 1.28 and epic 1.9 → 2.0. Rare and
legendary keep vanilla's exactly. Every step is now +25% or +28%, and the absolute gains rise
monotonically all the way up.

It reads as one rule — quality doubles every three tiers — which is exactly what the previous
two versions could not say about themselves.

**All seven multipliers now live in one table in `ladder.lua`**, including vanilla's. They were
split between `qualities.lua` and nothing at all, which is how an uneven step shipped twice: no
file showed the ladder whole, so nobody could see the shape of it.

Legendary got cheaper as a side effect — 90–124 against 101–140 — because epic modules are now
5% stronger. Re-validated clean at 2.1.17.

## 2026-09-10 — the celestial fracture removed, and the multiplier ladder given a rule

Two corrections from the owner, both from screenshots, and both about the same failure: a
number or a shape that was reasoned into place instead of derived from one.

**The ladder was uneven where it mattered most.** Mythic at multiplier 3.2 made legendary to
mythic a +28% step and mythic to celestial only +25% — the endgame tier gaining least. The
cause was picking mythic's value to land an assembling machine 3 on a round 4 rather than
deriving it: mythic is one level above legendary and celestial is two, so the jumps have to be
1:2. Mythic dropped to 3.0, which makes the rule above legendary a flat +0.5 of multiplier per
level, exactly as vanilla is a flat +0.3. One-level steps now land near +20% and two-level
steps near +32%, so celestial and legendary are parallel.

Cost moved with it, in the counter-intuitive direction again: weaker mythic modules farm
celestial more slowly, so the top tier went from 275–421 back up to 338–520. Any multiplier
change has to be re-run through `qsim.py`; it cannot be reasoned about.

**The celestial die's fracture is gone.** It was a jagged split lit from inside, justified by
"no die has a seven face". In game it read as stray blue lines across the icon, and — the
larger point — a fourth die that does not match the other three undoes the reason vanilla's two
were redrawn in the first place. The die is now the same die four times, distinguished only by
its pips. `_crack` and its plumbing were deleted rather than left switched off.

Re-validated clean at 2.1.17.

## 2026-09-10 — icons reworked across the whole set, and the ladder re-anchored

Two screenshots from the owner, both of a tooltip list showing all seven tiers side by side.
The complaint was alignment, and the list is what made it obvious: **mythic as a die's six face
— two columns of three — was a tall narrow block among square ones**, and both new glyphs used
a smaller pip than the five above them. The design that read well in isolation did not survive
being put in a row.

**The fix was to stop treating vanilla's icons as fixed.** Six pips cannot be drawn to vanilla's
geometry — six centres 27 px apart do not fit in a 64 px canvas in any arrangement — so the new
tiers must differ, and the only way out is to own the whole set. One generator now draws all
seven glyphs and one Blender model renders all four technology dies, vanilla's `epic-quality`
and `legendary-quality` included; `prototypes/quality/icons.lua` overrides them.

Six became a hexagonal ring and seven that ring with the middle filled — identical footprint,
identical pip size, and the middle pip drawn on top exactly as vanilla's fifth is. Redrawing
the vanilla five landed within 1–2 px of Wube's own bounding boxes.

**Two bugs found by looking rather than by measuring.** Drawing every ring and then every fill
loses the five-pip centre's outline under the corner fills, turning legendary's quincunx into
an orange blob — it needs two layers. And `normal` turned out to be the one quality whose icon
is not its colour over 0.7: base writes `255 * 0.7` and draws the pip at 188 grey.

**A third took a render to spot and looked like a material bug.** Enlarging the die pips to
vanilla's proportions made the five-pip face's centre socket overlap its corners, and two
intersecting cylinders in one joined boolean cutter make the exact solver discard the entire
die body. Three of the four icons rendered as gems floating in mid-air. `METRICS` now gives
every pip count its own socket radius and `_check_clearance` refuses to build a face that would
do it again.

**The balance was re-anchored to a number the owner gave**: an assembling machine 3 at crafting
speed 5 on celestial. That needs `default_multiplier` 4.0 where level 8 alone gives 3.4, so both
new tiers now set the multiplier by hand and leave `level` at 6 and 8 — the counted bonuses
(equipment grid, pole reach, accumulator capacity) stay where the owner put them, which is why
level 10 was not the answer. Mythic's 3.2 lands the same machine on a round 4.

That change moved the cost table in a direction worth noting: **celestial got cheaper, not
dearer**, from 423–652 to 275–421, because a mythic quality module 3 now gives 8% instead of 7%
and farms the tier faster. Gating the last step was measured (0.6 puts it at 357–547) and not
taken — the retuned ladder runs 1.6x–1.9x per step throughout, so 1.59x is in family, and the
best item in the game still costs more than vanilla's best. It is parked in `deferred.md` as a
play question.

Re-validated clean at 2.1.17, and the dump confirms the anchor: assembling machine 3 at 5 on
celestial, all eleven icon paths resolving to this mod's own files.

## 2026-09-10 — the mod, start to finish

Built in one session from the owner's brief: two tiers above legendary, a mandatory Space Age
dependency, epic moved to Fulgora, legendary to the first three planets, the new tiers on
Aquilo and promethium, "deep exploration to make it balanced", and good icons.

**Four decisions were put to the owner before any code.** Names and colours (mythic crimson,
celestial cyan, from four pairs offered); scope (full build, overriding the usual scaffold-only
rule for a new mod); the stat ladder (levels 6 and 8, skipping 7 the way vanilla skips 4); and
the reach cost — where the answer was not one of the four options but *"balance it, you may
need balance legendary tiers to feel progression balanced and make it slightly more easy to
improve vanilla tiers"*. That reply is what produced the design rule in `balance.md`: retune the
four older steps rather than gate the two new ones.

**The balance was measured, not asserted.** A Markov model of the upcycling loop
(`assets/extra-qualities/balance/qsim.py`) put vanilla legendary at 110–150 normal items with
legendary modules, which matches the published community figures, and that agreement is what
made the rest of its output usable. The retune values (1.5 / 1.4 / 1.3 / 1.2) were chosen to
land mythic-on-Aquilo on top of vanilla legendary-on-Aquilo, and the model's per-roll
distribution was then checked against the engine's own `get_roll_chances` — six decimal places,
exact. See `analysis/quality-roll-mechanics.md`.

**Background research turned up the one thing that would have shipped broken.** Core sets
`quality_selector_dropdown_threshold = 6`, so *any* mod adding one quality turns the row of
quality buttons into a dropdown — the loudest complaint on the portal's quality mods, and none
of the three with a 2.1 release appears to have fixed it. One line in `data-final-fixes.lua`.

**The stage split cost nothing only because it was checked.** space-age rewires `epic-quality`
and `legendary-quality` from its own `data.lua`, not from `data-updates.lua` as the filename
`base-data-updates.lua` suggests, so our edits sit in `data-updates.lua` and survive.

**The icons took five renders to stop looking like plastic.** The first three failed for
reasons that all looked like something else: a boolean had left an empty material slot 0 so the
die rendered in Blender's default grey; ambient occlusion does nothing on a convex die, so the
grime had to be painted; and the crack's glow object was a copy of an eight-unit cutter plane,
which filled the frame with cyan. All four traps are written up in `art-direction.md`. The
finished dies measure luminance sd 57.1 and 55.1 against vanilla's 51.9 and 56.1, with nothing
clipped.

Validated clean against base 2.1.17 with all four expansions, and again with
`--check-unused-prototype-data`: zero properties ignored, so every field written is a field the
engine read. Nothing has been played — `deferred.md` leads on that.
