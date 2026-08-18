# Upcycler Planner — journal

What happened, newest first. **Append-only**: a past entry is a record of what was true and
believed at the time, so it is never edited, even once superseded. What is true *now* lives in
`decisions.md`; the evidence lives in `analysis/`. Never ships (leading dot).

Entries are added in the session that produced them. When this file passes ~800 lines, move
everything older than the last release into `journal-archive/<year>.md` and leave a pointer.

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
