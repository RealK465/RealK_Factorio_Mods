# Upcycler Planner — journal

What happened, newest first. **Append-only**: a past entry is a record of what was true and
believed at the time, so it is never edited, even once superseded. What is true *now* lives in
`decisions.md`; the evidence lives in `analysis/`. Never ships (leading dot).

Entries are added in the session that produced them. When this file passes ~800 lines, move
everything older than the last release into `journal-archive/<year>.md` and leave a pointer.

---

## 2026-11-27 - "42 buildings are too far for a circuit wire": a recycler with no wire

The owner: "i have a warning '42 buildigns are too far for a circuit wire and will run without
limits' that is always visible, what's is causing that ?", then "otherwise see how this can be
improved" and "we can envasige a fix for quality recycler too". A scratch spec loaded the three
repo mods beside the planner and read every wired prototype's reach. All read 9 except Quality
Recycler, which read 0: written from scratch, it declares no `circuit_wire_max_distance` and
no connector. `planner.circuit_reach` took the recycler into the one shared minimum, so every
hop failed. Nothing was wired, and every building that should carry a limit was counted: 19 on
belts to legendary, 27 to celestial, and the owner's 42 with more columns. The vanilla recycler
gave 0 in every case.

The planner now holds the recycler to its own reach, as `feed_reach` already held the feed
chests (`../scripts/circuits.lua`). A recycler that cannot carry the wire both ways is left off,
and its census joins the machine over it. A reach of 0 is counted apart, as `circuit_wireless`,
and named in its own warning, "Quality Recycler can't connect to circuit wires, so 6
recyclers will run without limits". Three pure specs failed on the old decorator and pass now:
no wire on belts, no wire on bots, and a merely short wire, which stays "too far". On the scratch run at celestial,
the machines, feed chests and stock chests all came back gated, with only the recyclers bare.
Pure 187, headless 515, static clean; the belt goldens did not move.

The source was fixed in Quality Recycler 0.1.6, which now has a connector of its own (its
journal). With it, the scratch run read reach 9, planned with nothing unlinked and nothing
wireless, and a stamped loop carried the cap and a green wire on every one of its recyclers,
on belts and bots alike.

## 2026-11-27 - A moved window jumped back to the centre: 2.0.1 opened

The owner, hours after 2.0.0 shipped: "if i move the upcycler planner gui in the screen then i
change a setting it centers again the gui in the center of screen". The cause was the one
reading the release had marked **not verified** (§38): that a player's drag clears
`auto_center`. 2.0.0's `recentre` and its rebuild both re-centred only while the frame read the
flag as on, and the report shows a dragged frame still reads it so. 1.2.8 had kept the location
on every rebuild and never re-centred; 2.0.0 added re-centring for the window that now grows
with its tab, and took the flag as the "never moved" test.

A real drag could not be staged. Mouse messages posted to the client's window, a press, twenty
moves and a release, never moved the frame. A Steam copy of the game was open, and the
probe's window was never given the real cursor. A scratch probe in a scratch
install measured what needs no input instead (§39). The engine's centring raises one event
with the flag still on. A centring that leaves the frame where it stands raises none. Jumping
the frame to 0,0 first always yields one. Script writes and content growth raise nothing.
`force_auto_center()` just turns the flag on.

So the window is never left auto-centring: `recentre` jumps it to 0,0 and asks again,
`gui.on_location_changed` (newly wired in `control.lua`) switches the flag off as the
centring lands, and an event that finds it off sets `window_moved`. A resolution or UI-scale
change re-centres it, as the engine's auto-centring did. The old spec simulated a drag by
writing `auto_center = false`, the same wrong model of the engine, and was replaced by four
specs. Three raise the engine's event through whatever `control.lua` registered, and two of
them failed on the 2.0.0 code before the fix. The fourth waits for the real engine in the
graphics tier, behind a bare frame that tells a client from a headless run. It needed game
speed 1, because the framework runs at 1000 and the client lays a GUI out per drawn frame. A
mutant copy that never pinned failed it with the engine's own event. Headless 512 of 512,
graphics 512 of 512, static clean.

`info.json` went to 2.0.1 and the changelog opened its section, `Date: ????`: 2.0.0 is
tagged, so this is the next release, not part of the last one. Still unwatched: a real drag
of the pinned window (§39).

## 2026-11-27 - 2.0.0 released: the bot loop and the four-tab window

The owner: "can you keep all docs up to date, release and publish this to mod portal and
everything commited and pushed?", the same day as the review. The gates ran on 2.1.25:
`validate.ps1 -FullLoad` clean, every sprite and sound opened; `--check-unused-prototype-data`
run by hand against a scratch copy, since `validate.ps1` does not pass it — 703,331 properties
read, no warning; and the suite's graphics pass, 509 of 509, after the review's headless 509
and pure 184.

The zip held 26 files in 182,389 bytes — nothing from `images/`, `tests/` or these notes —
identical to the working tree, and to the tag once line endings are normalised. `fmtk upload`
answered "Published", and the portal's 2.0.0 sha1 is the local zip's (`b2d88386…`). The work
went in as `f1de736`, the release skill's video note as `1bccaad`, the summary quoted in every
README as `c8ce246` (the root row's "as ghosts" corrected with it), the datestamp as `6ba397b`,
tagged `upcycler-planner_2.0.0` and pushed; the branch rule's pull-request notice is the
owner's bypass going through.

After the push the four raw GitHub media answered 200 at their local sizes, and `fmtk details
--readme README.md --faq faq.md` synced the page: the new summary, both videos, the tabs and the
beacons still — license, category and gallery untouched, read back with a cache-buster. The
gallery pass uploaded only the two new shots, each id coming back as its sha1, and set the
seven in filename order. The one live id with no local file, `020e27a8…`, was the old
`01-planner-menu.jpg` — its sha1 matches the 1.2.8 tag's blob — and leaving it out of the list
is what replaced the shot.

Left open: `modded-upcycling.gif` still shows the window before the tabs, and the six other
mods' portal pages show the old summary until each is synced (both in `deferred.md`). The
journal had passed 4,400 lines, so everything from the 1.2.8 release back moved to
`journal-archive/2026.md` the same day (`4e50ae2`).

---

## 2026-11-27 - A full review of both sessions' work, and the fixes it earned

The owner: "can you do now a full review on everything that was done? try to find for bugs,
things to improve, performance improvements, regressions, simplifications", then "when they
finish fix what should be fixed". Four reviewers ran in parallel over the uncommitted tree —
the bot loop and the planner, the window, the suite, the player text with the media and these
notes — and every finding was checked against the code before anything changed. No crash, no
nil index, no desync path; in a reviewer's sweep the belt ring came out structurally
identical to HEAD's on 19,440 shapes, far past the 26 goldens.

**The window.** Opening or closing the settings panel never re-centred the window, so the
next fill — or ticking the panel's own setting — jumped the pair by half the panel's width:
`recentre` runs for the panel too now, measured on screen (x 1040, 896 with the panel, 1040
again; §38). The Overflow chest row showed on a belt ring to legendary, which builds none:
`layout_rules` hides it off `planner.uses_chest`, and the Chests tab refills on a target
change. The tallest tab made the window 872 px at 100% — past a 768-pixel laptop and past
1080p at 125% — so each tab is a `naked_scroll_pane` capped by `tab_max_height`, the screen
less `WINDOW_CHROME`, the rest of the window measured at 455 px. A tab switch re-planned the
loop for nothing, seconds on a huge layout: it repaints only the Circuits fields. A click on an
empty module picker after research landed filled a default and refilled the tab under the
chooser, leaving the next E swallowed: a browse guard on both module pickers, and `fill_tab`
drops the chooser presumption. Simplified on the way: `count_row` / `count_field` for the six
count rows, the Circuits tab one builder, `close_side_panel` folded into `close_settings`, and
the columns hint for a state no offered target reaches gone with its locale key.

**The planner.** A trip to Bots and back cost the belt plan a beacon — the stored count
snapped to the bot loop's lower max — so it snaps to what fits either layout now
(`planner.max_beacon_count` takes a kind). With bots the inserter refusals name the missing
filter slot rather than the recipe (two locale keys). The bot builder caches its extract filter
per quality, and stale comments (the wizard, the pipe list's length, the relay hop) were
rewritten. Left as they are: `repick_inserter` replacing a bot-only inserter on the way back to
belts (modded inserters only, and the plan would be refused otherwise), and the bot builder
honouring a `product_buffer` the planner never withholds from it.

**The suite.** The live bot spec's first assertion rested on a recycler's coin flip (a gear
recycles to a plate half the time): it allows for that plate now, the rolled-up plate is seeded
inside the recycler so the extract inserter runs live, its two tests are one, and the rig
stands off spawn. New: the four rates refills, the overflow row, the beacon count's round trip,
the browse click, a tab switch that plans nothing, the panel keeping the centring flag,
validate and plan agreeing (ok asserted at full research, a refusal at fresh), the pole memo
in both directions, a bot plan with columns, a repeated-tier bot spine in the pure tier, and a
live relay spec — a foundry loop with beacons that relays every hop, pinning §37's premise on
2.1.25 through the planner's own blueprint. Writing it turned up three engine facts (§37): a
recipe's surface conditions drop it on revive on the wrong planet, a machine its control
behaviour switched off takes nothing in, and a script cannot seed an assembler's result slot.
`stamp.wipe` replaces five copies, `maybe_widget` walks rather than catching errors, and the
plan golden logs its whole serialisation on a mismatch. Headless 509/509 on 2.1.25, pure
184/184, luacheck clean.

**Player text and media.** The README and the FAQ had the belt ring "working anywhere, with or
without a logistic network"; every belt tier's ingredient chest is a requester, so both now say
to build inside roboport range, and the Layout tooltip, the overflow and loop-not-running
answers, the ten-ingredient line (belts only), the no-productivity sentence and the changelog's
Bots entries were corrected the same pass, plus a Gui line for the scrolling tabs. The beacon
picture still showed the Build options window: re-shot as `beacons-and-pipes.jpg`, on GitHub
like the rest. The tabs grid was re-shot without the overflow row, and both videos re-shot and
encoded as limited-range BT.709 `yuv420p`, where the first cut had gone out full-range. A first
beacon shot landed beside the belt scene's standing loop and was re-taken on a site kept clear
of it; the bot scene re-taken alongside came out on patchier ground, so the earlier take stays.

**Notes.** `decisions.md`, `deferred.md`, `CLAUDE.md`, the analysis notes and the release
skill were corrected where the review found them stale or holding two answers — the
ten-ingredient cap, the rebuild's re-centring, the five always-shown chests, three deferred
entries about the removed count rule. This journal is past its archive mark (about 3,800
lines); moving the pre-release entries is left for its own change. Nothing committed.

---

## 2026-11-27 - The window simplified: four tabs of labelled rows; new portal media

The owner, back from playing the three-tab window, with a screenshot of a blank band under the
short Buildings tab: "There is an empty space in some cases in the GUI", "Can you simplify the
GUI and make it more user friendly?", and "Improve the FAQ and README, add new images and videos
with the updated layouts and gui, spawn a user facing text agent to review and make it simple
all the user facing text". Three calls, each the owner's pick from previewed options: labelled
rows in four tabs with the side windows folded in (over icon groups with the windows folded in,
and over fixing the blank space alone); stop hiding options to save space; the media on GitHub,
"preferably use videos not gifs". Recorded in `decisions.md` (the modal's two blocks and four
tabs, everything built has its row, labelled rows, one label width, the mix and the ratio
counts, the columns, Portal presentation).

**The blank space was the pane, not the content.** A tabbed pane sizes to its tallest tab
(§38), so the fix is structural: only the selected tab is filled, the rest stand empty, and a
switch refills in place (`fill_tab`, `TAB_BUILDERS`, whose `refill_on` replaced the side-panel
registry's `invalidated_by`). Measured in a graphics run before trusting it, and then three
things the new height-following window exposed (§38, 2.1.25): an `auto_center` frame is not
re-centred when it grows, the engine does not keep a frame on screen — a tall tab grown from a
short one's centred spot cut Place off at the bottom — and writing `auto_center` again
re-centres it. So a centred window re-centres on every fill, and a rebuild keeps the centring.
Whether a player's drag clears `auto_center` could not be measured.

**Built.** `gui.lua`: `add_row`/`show_row` carry the top block's label-beside-control shape
into every tab at one `LABEL_WIDTH`; the Buildings, Modules, Chests and Circuits builders; the
Ratios and Columns per tier side panels became `add_split_section` and `add_columns_section`
inline; the settings panel is the one side panel left. The hide-by-count rule, the hidden
beacon group and the *Show all build options* setting went (`settings.lua`, the locale); the
recycler, the beacon and every chest always show, and a row hides only while the loop as chosen
does not build it. A refill destroys the widget whose event asked for it (a module pick, the mix
checkbox, the beacon count) — safe, the dispatcher's valid check turning the click's second
event into nothing.

**Tests.** `gui_spec`'s path helper picks a control's tab first, as a player would, since only
the selected tab holds anything; the side-panel tests became inline-row tests, and new ones pin
the empty unselected tabs, the in-place fill, the pane click that fills nothing, the centring
kept and the moved window left alone, the settings round trip, and the nothing-to-mix sentence
under a research state with no productivity module. Two tests held a module picker across a
pick that now refills its tab and were re-fetched. Headless 499/499 on 2.1.25. A `-Filter gui`
run fails "another GUI taking focus": its chest at a fixed spot is out of reach of the
character a filtered run still has — order-dependent before this change, passing in the full
suite.

**Player text.** The user-facing-text agent rewrote the README and the FAQ for the four tabs,
shortened most tooltips without renaming a label, polished the open changelog section, and
carried the README's bold line to `info.json` and the locale summary (the owner's 2026-08-26
sentence, replaced at their ask to simplify all the text). It flagged the old sentence in the
other mods' "Check my other mods" lists and the root README's "drops it as ghosts" row, both
left alone (`deferred.md`). The lamps' "green when paused" stays true outside network mode
(`circuits.lua`).

**Media.** The owner's "check how mining patch planner and pump mods did it" was about their
portal videos, not their windows: both embed an MP4 as a markdown image, which the portal
renders as a muted autoplaying loop, and P.U.M.P. hosts its own on GitHub. Raw GitHub serves an
MP4 as `application/octet-stream` with `nosniff`; Chromium played one in the portal's exact
tag, Firefox and Safari untested. A throwaway spec in a scratch copy shot every frame
(`game.take_screenshot`, the hold per shot logged), on a force of its own researched while the
player was elsewhere — no achievement toasts — after `unlock_quality`, since a new force has
not even normal quality unlocked. Out of it: `belt-loop.mp4` (plan, Place, ghosts, a build in
waves, the loop running in its logistic network), `bot-loop.mp4` (the same with Bots),
`planner-tabs.png` (the four tabs over a black void, cropped by colour), and two gallery shots,
`01-planner-menu.jpg` re-taken and `02-bot-loop.jpg` new, the old 02 to 06 renamed 03 to 07.
The README links point at `main`, so they resolve only after a push.

---

## 2026-11-27 - The bot loop built, and Build options in three tabs (2.0.0 opened)

The owner asked: "I wonder if you can implement the bot layout now ... And make the UI more
user friendly." Run as a feature-dev session: three explorers mapped the planner, the GUI and
the suite; the owner then picked every shape from offered options. **The window**: tabs
(Buildings, Chests, Circuits) over a grouped scrolling column, captions beside their rows, or
only a new row; the Limits and ingredient amounts moved inline into their tabs, Ratios and
Columns kept their panels; the chests always shown in their tab. **The bot loop's scope**:
beacons, fluids and circuit limits, no roboport; the items a lower tier rolls early go to
storage through active providers. **The architecture**: a new builder module plus shared
helpers, and per-tab builders with one table of what bots hide — both "clean" approaches over
the minimal ones two architects laid out. Recorded in `decisions.md` (the two layout families,
the modal's tabs, the chests, the inline limits and amounts).

**Measured first.** Tabbed panes, headless (`api.md` §38): contents are children found by name;
neither `add_tab` nor a script write raises the tab event; a fresh pane has NO tab selected.
The bot loop's engine premises (`api.md` §37): an active provider fills an open request before
storing the rest, keeps its items with no storage, and a wired inserter with no behaviour moves
items and reads nothing — the last is what made the spine relay through the top-row inserters
safe.

**Belt plans frozen before any edit.** The suite's "byte-identical" specs compared two builds of
one code, so they could not catch a refactor; 18 builder cases and 8 planner cases were
digested on the pristine tree (`tests/support/fingerprint.lua`). The first capture diverged
between host Lua and the game on exactly the four decorated cases with a cap: the running
lamp's 0.15 / 0.45 colour prints `0.15` under the game's `%.17g` and `0.14999999999999999` on the
host, 30 characters a case. The fingerprint now writes numbers as integers only (fractions in
micro-units) and agrees on both. Falsified on purpose afterwards: a swapped entity, a dropped
tag and a moved tile each change the digest.

**Built.** `scripts/layout.lua` exports the rules both builders share (module slots, the column
plan, the beacon stack, the pipe run, the circuit stack, the above-tier filter); all 26 goldens
stayed put. `scripts/layout_bot.lua` is the bot builder. The planner reads
`planner.layout_kind` and dispatches to a builder through `GEOMETRY`; `uses_chest`,
`requests_forced`, `circuit_network` and `filters_needed(recipe, choices)` own what differs,
the pole memo leads with the kind, `circuit_reach` drops the belt for bots, and plan and
validate read the same gates. `circuits.decorate` gained a ring-less spine path relaying through
`relay_out` / `relay_in` inserters; belt plans never reach it. `gui.lua` builds the pane from
`build_options` and three tab builders, `layout_rules` hides what bots do not build (show-all
included), `repaint_circuits` owns the inline limits' enabled states, a target change rebuilds
the Circuits rows in place, and `entry.tab` remembers the tab through the new
`on_gui_selected_tab_changed` registration. Two scope slips caught before any run: a GUI
handler placed above the `settled_on` local it calls, and a helper left global.

**Tests.** New: `tests/pure/layout_bot_spec.lua` (20), a bot block in `circuits_spec` (7),
`tests/bot_plan_spec.lua`, `tests/bot_loop_spec.lua` (live: seeded items reached the tier that
requests them, rare gears went to storage, tier 0 crafted 96 and recycled 92 in 2400 ticks), a
`layout` prune spec, and a tabs-and-layout block in `gui_spec`. The circuits and ingredients
GUI specs were rewritten for the inline fields; a one-line tab map in `gui_spec`'s path helper
kept its other ~150 call sites as they were. Pure 183/183, headless 499/499, static clean on
2.1.23. Six graphics-client screenshots (belts and bots, each tab) read back as designed; the
pane keeps one height on every tab. Taking them needed the planner moved left of the
achievement toasts full research raises, `auto_center` off before a `location` write sticks,
and the player's own display resolution (`api.md` §38).

**Reviewed.** Three reviewers in parallel (bugs, simplicity, the repo's conventions) found no
defect at confidence 80. What they did find, all fixed the same day at the owner's word: about
twenty comments and doc lines still naming the Limits wizard, the ingredient panel, the
numbered side panels or a "deferred" bot loop; the no-logistic-connection refusal telling a
bots player to untick a box bots grey out (now its own Bots wording); `plan.layout`, set and
never read; the inserter re-pick copied into two handlers (`repick_inserter`); the GUI
re-implementing `planner.circuit_network`; the forced-requests test spelled three times in
`plan()`; `column_plan` taking a pitch it could derive; and test fixtures copied across specs
(now `layout_params.with_beacon` / `salvager` / `flat_recycler` / `bot_of` and
`stamp.reachable` — the golden spec keeps its own). The goldens held through all of it. Left
as they are: the chest and inserter closures each builder keeps, and the in-place circuit
rows. Not measured: whether E reaches Place from a focused textfield at all.

**Docs and player text.** `analysis/layout-bot-loop.md` rewritten from a spec into the record
of what is built; `deferred.md` lost the bot-transport entry and gained what stays open on it,
plus the stale portal pictures; the changelog opened a section as 1.3.0, renumbered 2.0.0 at the owner's word the same
day ("this will be version 2.0"; `info.json` with it, 2.0.0 free on the tags and the portal),
and the
README and FAQ were corrected for the tabs and given the bot layout's network caveats. Nothing
committed, nothing published.

---

## 2026-11-27 - README simplified and synced to the portal page

At the owner's ask ("simplify the readme of upcycler planner"), the README was rewritten by
the `user-facing-text` agent, freshly moved to Opus 5.5 at high effort: 120 lines to 90, every
embedded image kept at its URL, the "Check my other mods", AI-Assisted Development and License
blocks byte-identical. The feature list became short bullets, the images moved under one
Examples heading with one-line captions, the circuit-limit detail was left to `faq.md`, and the
1.0 timing figures, the rebind path and the Maraxis beacon example went. One fact was wrong
and is fixed: it said recipes with spoilable items are not supported, while they have only
warned since the owner's 2026-08-27 call. The bold summary was rewritten too, which split it
from `info.json` and the locale (`deferred.md`, Housekeeping).

Synced with `fmtk details --readme` on the owner's ask the same day; read back with a
cache-buster: the new description is live, license and the six gallery shots untouched, the
portal summary still the `info.json` sentence. No release, so the 1.2.8 zip keeps the old
README.

---

Older entries, from the 1.2.8 release back to the first session, are in
`journal-archive/2026.md`, moved there unedited on 2026-11-27.
