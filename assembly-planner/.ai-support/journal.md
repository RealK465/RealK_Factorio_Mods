# Journal — Assembly Planner

Dated sessions, newest first. Append-only: entries are history and are never edited.

## 2026-11-28 (night, last) — 0.4.0 published

The owner asked for the mod to be released and published. Pre-flight: the portal held 0.1.0 to
0.3.0 (owner RealK), `assembly-planner_0.3.0` was the newest tag, and `main` matched `origin`.
Every gate ran again on 2.1.25: the data stage clean with every expansion and with none, nothing
unused, `-FullLoad` clean; in-game 162/162 headless and in a window, pure 56/56, static clean. A
0.3.0 save is safe: `state.of` gives an entry without `cells` an empty one, the prune reads
`cells or {}`, and the update's configuration change closes every window. The chains went in as
`391a9e9`. `fmtk datestamp` stamped the changelog 2026-11-28 and `fmtk package` built a 26-file
zip of 103,667 bytes with nothing private in it, sha1 `7c95c7c40ce4e912080914c7600317be37f34bf2`,
matching the index file for file once line endings are normalised. `fmtk upload` published it,
and a cache-busted read-back listed 0.4.0 with that sha1. The release commit carries the stamp
and the tag `assembly-planner_0.4.0`.

The portal page was not synced, now three releases behind. Its description lacks every README
line added in 0.2.0, 0.3.0 and 0.4.0, and by sha1 only `05-fluid-cells.jpg` of the six gallery
shots is current. Both wait for `fmtk details` and the image API, a separate public write.

## 2026-11-28 (night, later) — ratios

Shown the first build, the owner asked: "It would be nice if user can configure ratios but also
see and get the optimal ratios". Built without further questions, as asked: a count drop-down
per row, the root's included, the balanced count green in it, and a *Balance* line that applies
the balanced counts in one click (`decisions.md` → Production chains, `chain-design.md` →
Ratios). Counts stay at one until changed, so the earlier pick of a warning over automatic cells
still holds by default.

Bigger rows needed a faster pole solver first. `poles.plan` now keeps a `blocked` and a `near`
flag per candidate, updated once per placement, and files consumers by column; the goldens and
the pure pole tests came out identical. Timed in a real client on 2.1.25: a fresh 32-cell
beaconed row in 164 ms (AM3) to 303 ms (EM plant), every repeat within 20 ms through the memo.
The cap is 32 cells; more refuses.

The screenshot harness caught the counts clipped to a sliver at 56 px (now 72). A bug review
found one real defect, fixed with a test: *Balance* could push a chain past the cap, after which
the refused plan left every drop-down showing its old count — the button now waits, saying why,
and a refused plan repaints the counts from storage. The showcase's window shot now shows a
balanced eight-cell chain. End state: in-game 162/162, static clean. Nothing committed or
published.

## 2026-11-28 (night) — production chains, 0.4.0 open

The owner asked for "chains of production in the mall … if I place electronic circuits it would
also propose optionally copper cables", with "a very beautiful compact and accessible ui to
configure nested chains", then asked for autonomy and no publishing. One round of three
questions settled the shape: extra rows in the window, robots between cells, a warning rather
than more cells when one falls short (`decisions.md` → Production chains, `chain-design.md`).

Single-cell plans were pinned first: eight digests captured on the untouched tree
(`tests/plan_golden_spec.lua`, with Upcycler Planner's fingerprint helper), then `plan.build`
split into `plan.cell` and its power, and all eight held. The chain went in as `chain.lua` (the
walk, what a cell inherits, the row planned and powered once) and the pure `row.lua` (fluid
tiles, beacon gaps), test first in each tier.

A fresh-context check of the design before the window was built found three things that would
have broken — 0.3.0 entries without `cells`, the root's amounts leaking into cells through the
derive, and `plan.build` gaining keys under the goldens — all three already handled in the
build, and nine smaller ones, folded in (`chain-design.md` → The check). Its beacon arithmetic
corrected the design's prose: sided cells abut with 0.6 tile of slack, not one; a sided cell
beside an unsided one, and above-only cells, need 2 or 3.

A scratch harness modelled on the showcase photographed the window in five states on 2.1.25.
It changed three things: the strips needed the ◀ to read as ingredients rather than more module
slots; a line per short cell pushed an eight-cell window off a 1080p screen, so short cells now
turn red in their rows behind one status line; and a rebuild that grows the window now lifts it.

Two reviews at the end, as the feature-dev process asks: one for simplicity and conventions,
whose tidy-ups went in (named steps in `chain.build`, `row.lua` unnested, a one-cell `cells`
list on every plan, one-sentence tooltips), and one for bugs, which found no crash or desync and
two small defects, both fixed with a test each — a top-tier cell charged a quality share nothing
can roll, and a kovarex cell able to untick itself from its own row.

The showcase's window shot now shows a three-cell chain; the five world shots came out
byte-identical. End state: in-game 155/155 headless, pure 56/56, static clean, the data stage
clean with every expansion and with none. Nothing committed; nothing published. `info.json` and
the changelog are at 0.4.0, `Date: ????`.

## 2026-11-28 (later) — 0.3.0 published

The owner asked for the redesign to be released and published. Pre-flight: the portal held
0.1.0 and 0.2.0 (owner RealK), `assembly-planner_0.2.0` was the newest tag, and the window work
went in as `60cc963`. `fmtk datestamp` stamped the changelog 2026-11-28 and `fmtk package` built
a 24-file zip of 90,333 bytes with nothing private in it, sha1
`3f7563f2a9d761868c8057e5988f4fbe8f2ac0ef`. `fmtk upload` published it, and a cache-busted
read-back listed 0.3.0 with that sha1. The release commit carries the stamp and the tag
`assembly-planner_0.3.0`.

The portal page was not synced. The README's line about the Settings panel changed and the
gallery still shows the old window; both wait for `fmtk details` and the image API, a separate
public write. The description's images are absolute links to `images/` on `main`, so the new
window shows there once pushed.

## 2026-11-28 (later) — a compact window, 0.3.0

The owner asked for a simpler, more compact window with every option still one click away —
"I don't like the beacons line being too large in width … make it beautiful, make it the best
possible" — then a release. The window became one form in three sections (`decisions.md` → The
window): captions beside their controls instead of above them, pickers in recessed slot strips,
56 px beacon counts, the item's name or the hint beside the item picker, one line of numbers
under the form, a pencil for the ingredient amounts, and the Settings panel replaced by a
titlebar toggle. At 1080p it went from about 477×720 to 440×520.

Built against screenshots, not guesses: a scratch harness opened the window in seven states
(empty, the showcase cell, gears with the amounts panel, a refusal, a fluid recipe, no limit,
show-unresearched on) and photographed each. That caught the toggle's first icon:
`utility/technology_white` drew at half the close cross, because a sprite-button fits the whole
sprite into its box and vanilla's flask fills only the middle half of a 64 px canvas. A sprite
of our own cropped to the flask (`prototypes/planner/sprites.lua`) matches it. The new toggle
test also shows that writing our own per-player setting raises
`on_runtime_mod_setting_changed` at once: the window is rebuilt before the click handler
returns.

`tests/gui_spec.lua` now finds controls by name, not by path, and gained four tests: the hint
and the shut status area, the beacon counts, the pencil's pressed state through a rebuild and
both closes, and E doing nothing while the panel is up. In-game 118/118 headless and in a
window, pure 48/48, static clean; the data stage clean with every expansion and with none,
nothing unused, and `-FullLoad` opened the new sprite.

The shorter window uncovered a blinking no-power icon in the planner shot: the showcase's
beaconed electronic circuit cell leaves one inserter outside its medium poles' reach, which the
plan already warns about. The shot's camera moved down so the window covers it, and the
shortcoming went into `deferred.md`.

## 2026-11-28 — 0.2.0 published

The owner asked to release, publish, commit and push once the review was done. Pre-flight: the
portal held only 0.1.0 (owner RealK), `assembly-planner_0.1.0` was the only tag, and `main`
matched `origin`. The feature went in as `ca42247`. `fmtk datestamp` stamped the changelog
2026-11-28 and `fmtk package`, given a relative `--outdir`, built a 23-file zip of 89,393 bytes
with nothing private in it, sha1 `0ae496ced9177cf052b83a446fe5029c85ce81ec`. `fmtk upload`
published it, and a cache-busted read-back listed 0.2.0 with that sha1. The release commit
`1c3cd8a` carries the stamp and the tag `assembly-planner_0.2.0`; the zip matches the tag file
for file once line endings are normalised.

The portal page was not synced. The README gained one line and five screenshots changed. The
README's images are absolute links to `images/` on `main`, so the pushed shots show in the
description at once; the line itself and the gallery copies wait for `fmtk details` and the
image API, a separate public write left for the owner to approve.

## 2026-11-27 to 11-28 — inserter throughput, 0.2.0

The owner asked for the planner to work out speeds and transfer rates: "with beacons the
bottleneck is the inserter transferring items from the request chest to the assembler … check
if there is free space … if so maybe split between 2 requester chests", and then that modded
inserters be read rather than assumed. Asked what to do when the edge is full, and again how
chests should share requests, the answer both times was "the best possible". The design went
through a fresh-context builder check first (`throughput-design.md`). It caught three things
the first draft had wrong: the default 4-craft request is below a bulk inserter's hand for most
fast recipes, which made an even share useless; four normal quality module 3s do not beat five
speed beacons' quality malus; and a one-at-a-time allocator stalls when inputs and output tie.

Built test first in all three tiers. The swing formula came from the wiki's 2.0.26 table,
`2 * (ceil(0.5 / rotation) - 1)`, and was then measured live on 2.1.25 for every vanilla
inserter at normal and legendary, into a chest and into a machine. It matched to the tick
(`analysis/api.md` §7). The live rigs also found the stack inserter holding a partial hand and
never swinging (§8). A first end-to-end run crafted at an AM3's bare speed because a revived
ghost leaves its modules to robots, so the spec now fits them by hand (§9). One existing spec
changed item: its fast-inserter cell now gains side inputs and no longer needs a pole row, so it
pins the row with a slow recipe instead.

The factorio-test data dir for 2.1.25 was seeded with 3.1.2 from upcycler-planner's, per
`CLAUDE.local.md`. The screenshots were rebuilt: the mall row's AM3s and two beacon cells now
carry side inputs.

A fresh-context review at the end, as the owner asked, found nothing critical. Fixed from it:
a mod's fractional plain-inserter bonus would have written a fractional request count into the
blueprint (the engine floors the hand, 4.5 to 4, and `proto.inserter_hand` now does too); the
nil-swing guard and the small-request warning gained tests, each proven by a run against a
deliberately broken plan; the changelog and four locale lines misdescribed several chests (a
small request is copied whole, not shared); and four notes claimed more than was measured.
Deferred as minor: three pure coverage gaps, a comment tying `swings_per_craft` to the share
floor, and a refresh of the open window when research finishes. End state before the release:
pure tier 48/48, in-game 114/114 headless and in a window, static clean, the data stage clean
with every expansion, with none, and on a full load.

## 2026-11-25 (late night) — linked from the other mods

The owner asked for the docs to be brought up to date after the release. Every other mod's
README gained Assembly Planner under *Check my other mods*, as each did for Robot World
Continued. Their portal pages were not re-synced: the link reaches each page only through its
own `fmtk details --readme`. The release's two findings went into the `factorio-release` skill:
`fmtk package --outdir` wants a relative path, and `edit_details` takes tags as a repeated
form field.

## 2026-11-25 (night) — 0.1.0 published

The owner asked to release and publish. Just before that, at the owner's request, the README was
cut to a third of its length and the summary became one sentence (`decisions.md` → Portal).

Pre-flight: the portal GET answered 404 for the name, no `assembly-planner_*` tag existed, and
`main` matched `origin`. The data stage loaded clean with every expansion, with none, and on the
vanilla install; `--check-unused-prototype-data` found nothing either way, and `-FullLoad`
opened every sprite and sound. Pure tier 31/31, in-game 81/81 headless and 81/81 in a real
window.

`fmtk datestamp` stamped the changelog 2026-11-25, and `fmtk package` built a 23-file zip of
85,250 bytes with nothing private in it (sha1 `9eca6b26569f5f621191f5ae52acb1dffc51125a`).
`fmtk package --outdir` given an absolute Windows path dies with ENOENT: fmtk 2.1.8 joins it onto
the working folder, so a relative path was used. The zip went up through `init_publish` and the
multipart upload. Then `edit_details` set GPLv3, category `utilities` and four tags, `fmtk
details` pushed the README, and the six shots went up as the gallery in filename order, each id
checked against its file's sha1. A cache-busted read-back confirmed every field, and the
release's sha1 matched the zip.

## 2026-11-25 (evening) — presentation, and a pole row

The owner asked for the graphics checks, a thumbnail made from the shortcut icon (hoping it was
an assembling machine 3; it is, with a requester chest in the corner), simple player-facing
text, and images.

With the screen back, `validate.ps1 -FullLoad` opened every sprite and sound with both custom
inputs active, and the `-Graphics` tier passed at 79 tests once `blueprint_spec` moved to the
lab surface: a ghost stamped on nauvis at (200, 200) would not revive in a real client. The
thumbnail comes from `assets/assembly-planner/thumbnail/make_thumbnail.py`; the README and the
changelog were rewritten for players.

The planner window's own screenshot caught a bug: a beaconed AM3 cell with a medium pole warned
that two buildings were out of reach. No free tile below a full row of beacons reaches both its
ends with a medium pole's supply, and the right-hand column reached only one. The fix is a pole
row along the top (`cell.lua` `pole_row`; the plan's ladder tries the column, the row, then
both), with a test in each tier.

The screenshots come from `assets/assembly-planner/showcase/`, which stamps four rows of real
cells and photographs them. Getting them clean taught three things. Rows have to be spaced by
the medium pole's sprite, which stands 3.34 tiles above its position, or every close-up catches
the next row's poles. A pole made by `create_entity` wires itself to every pole in reach unless
`auto_connect = false`. And two beaconed EM plant cells with medium poles end up with poles 10
tiles apart, one past wire reach, parked in `deferred.md`.

End state: pure tier 31/31, in-game 81/81, static tier clean. The graphics tier last ran before
the pole row.

## 2026-11-25 (later) — the review round

Three reviews ran on the finished mod: correctness, simplicity, repo conventions. Conventions
found nothing at its threshold, and every API member and locale key was checked against
2.1.23. Correctness found four real bugs, each now fixed with a regression test:

- **The build-quality warning skipped most picks.** Its list was written with `and`, which
  yields nil for an absent machine module, and `ipairs` stops at the first nil, so with no
  module only the machine's own quality was ever checked.
- **The split box dead-ended on a refused plan.** Its handler compared against an automatic
  answer a refused plan does not have, so unticking stored "automatic" again and the refusal the
  split caused could not be undone from the box.
- **The amounts panel went stale in minutes mode.** Only a size edit repainted it, while module
  and beacon picks also move the pace the defaults are priced at.
- **A quality change on the item reset the recipe and the hand-set amounts**, though neither
  depends on quality.

The simplicity review's changes went in too: one number field and handler for sizes, caps and
ingredient amounts; one descriptor per mode in `plan.lua`; the beacon-count clamp shared by the
window and the plan; a drop-down wrapper and one mode handler; the window's builder split into
sections; the pole solver without its redundant set; dead parameters and exports removed. Tall
narrow machines (the crusher) now lie on their side to fit the row.

Mid-session the owner said another agent was starting on Upcycler Planner. The new folder was
unstaged at once so a commit there cannot sweep it in; it stays untracked, and the only edits
outside it are the two unstaged repo-level entries (`CLAUDE.md`, `README.md`).

End state: pure tier 30/30, in-game 79/79, static tier and data stage clean.

## 2026-11-25 — the mod, from idea to a green suite

The owner asked for a "mall / assembly planner" in Upcycler Planner's tradition and shared six
blueprints: an AM3 with quality modules splitting normal output into a chest capped at two
slots and better qualities into a second chest; the same for a K2 battery MK2 and a modded
solar recipe in an EM plant; an EM plant flanked by two speed beacons a side; a foundry at
direction 8 making big mining drills from molten iron; and a K2 advanced assembler. Their
requests were three and four crafts' worth.

Prior art checked on the portal: Quick Mall does the basic version but was 2.0 only, with fixed
one-stack requests and no beacons, split or fluids.

Decisions taken with the owner, in two rounds: name Assembly Planner; requests by crafts,
minutes or per ingredient; a full-width pipe row along the back; beacons beside and above; stock
capped by slots or network count (no limit added); automatic quality split with an override;
an optional pole; one cell per blueprint; then the purpose-built design over a fork of Upcycler
Planner, three cap modes, and every picker always shown.

Measured with a scratch probe before designing (`analysis/api.md`): `bar` counts open slots,
nameless normal filters survive and split, the north pipe row feeds each vanilla machine at its
rotation, the foundry only takes fluid where its recipe may craft, and all seven beacon spots
around an AM3 reach.

Built: the data stage (shortcut, two inputs, the gate re-seeded on requester chests), the pure
cell layout, the arithmetic, a small pole solver, the prototype questions, the one-pass plan,
the blueprint writer and the window. The suite found two real bugs. The pole solver never placed
a zero-gain bridge, leaving a consumer beyond wire reach dark (pure tier). Space Age's
`casting-iron-gear-wheel` sorts before `iron-gear-wheel`, so the default recipe turned a gear
cell into a foundry cell (in-game tier).

The runner's framework download picked factorio-test 3.2.0, which needs base 2.1.24; the
2.1.23 install refuses it. The data dir was seeded by hand with 3.1.2 from Upcycler Planner's.

End state: data stage clean with and without the expansions, no unused prototype properties,
pure tier 30/30, in-game 74/74, static tier clean. Not yet run: the graphics tier and the full
load (no screen attached during the session), and no played save.
