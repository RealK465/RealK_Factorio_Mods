# Upcycler Planner — journal

What happened, newest first. **Append-only**: a past entry is a record of what was true and
believed at the time, so it is never edited, even once superseded. What is true *now* lives in
`decisions.md`; the evidence lives in `analysis/`. Never ships (leading dot).

Entries are added in the session that produced them. When this file passes ~800 lines, move
everything older than the last release into `journal-archive/<year>.md` and leave a pointer.

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
