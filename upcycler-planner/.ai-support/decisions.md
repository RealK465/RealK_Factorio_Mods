# Upcycler Planner — decisions

Register: what is settled, and why. **Edited in place** — a decision that changes is rewritten
here rather than annotated, and the story of the change goes in `journal.md`. So this file
always reads as the present tense, and never carries "superseded" or "amended" markers.

Parked and open work has one owner, `deferred.md`. Evidence has one owner, `analysis/`. Never
ships (leading dot).

## Identity and packaging

- **Name `upcycler-planner`, title *Upcycler Planner*.** Renamed 2026-08-16 from *Upcycler
  Architect*: *Planner* is the word the genre uses — Mining Patch Planner and P.U.M.P. are what
  a player searching for a sibling will have found — and the collisions *Architect* was avoiding
  turned out not to exist, since `planner` is not a prototype type and `upcycler-planner` is a
  distinct portal name from the existing `upcycler` mod. Free to do only because nothing had
  shipped; the portal has no rename, so the window closed at the first upload.
- **Portal name `upcycler-planner` is ours.** First published 2026-08-16 under the RealK
  account. Checked free beforehand (`GET /api/mods/upcycler-planner` 404 on 2026-08-16, method
  sanity-checked against `mining-patch-planner`) — worth having done: `pure-modules` was
  lost to a squat by a deleted account, and portal names stay taken after the account goes.
- **Prototype prefix `upl-`**, with settings and locale mod-level keys using the full
  `upcycler-planner`. Prototype names share one flat global namespace and a collision there is
  silent, which is the whole reason for a tag; settings are listed to players beside other mods'
  settings, where a three-letter tag would be meaningless. Matches the house style in
  `pure-modules-realk`. `upcycler-` was rejected because the portal already carries a different
  mod named `upcycler`, likely to own that name and its derivatives; `up-` as too generic — "up"
  reads as a direction before it reads as a namespace.
- **Hard dependency on `quality` (`>= 2.1.0` on `main`, `>= 2.0.0` on `legacy/2.0`).** The mod
  is worthless without quality tiers, and the dependency is the half that fixes load order —
  feature flags do not. The one line delivers the recycler on both tracks: in 2.1 `quality`
  declares `recycler >= 2.1.0`, and in 2.0 the recycler entity ships inside `quality` itself.
- **Space Age feature flags are declared, and the set forks by game version:
  `quality_required` on both tracks, `expansion_required` on `main` only.** Asked for by the
  repo owner on 2026-08-16, reversing the earlier no-flag call — that call was made when the
  only question was enforcement, where a flag is redundant behind the `quality` dependency.
  The deciding reason is the **mod portal**, which tags a mod as Space Age from the expansion
  flags in its uploaded `info.json` and *not* from its dependencies, so without a flag the mod
  never appears in the portal's Space Age section however hard its dependency is.
  `expansion_required` is omitted on `legacy/2.0` because **the flag does not exist in 2.0** —
  measured, it is silently ignored there and gates nothing, which would be a dead field
  pretending to be a gate (`analysis/api.md` §13). This mirrors vanilla `quality` exactly,
  which declares both flags in 2.1 and only `quality_required` in 2.0. `space_travel_required`
  was rejected: it would also earn the portal tag, but it unlocks planet and space-platform
  prototypes this mod never touches, so declaring it would be a false claim about the mod.
  Neither flag narrows the audience in practice — `quality` already ships only with Space Age.
- **Both game tracks, forked — `main` carries no 2.0 code.** Ported to Factorio 2.0 on
  2026-08-16 at the repo owner's ask, reversing the earlier 2.1-only call — that call rested
  on "`recycler` is 2.1-only", and 2.0's `quality` mod ships the recycler entity itself, so
  the mod's whole mechanism exists there; 2.0 is also the stable release most players are on.
  The port was first built as version-gated shared files and **the owner rejected that
  shape**: the 2.0 track is temporary — it stops getting work when 2.1 goes stable — and
  gated compat code in `main` would sit there confusing readers long after it stopped
  mattering. So the adaptations are forked copies on `legacy/2.0`: `scripts/planner.lua`
  (recipe `category` + `additional_categories` in place of 2.1's `categories`, and the
  mod-data bridge standing in for the missing `can_set_quality`),
  `prototypes/planner/icons.lua` (the recycler icon ships in `quality` there),
  `scripts/gui.lua` (local `contains_value`; core's is 2.1-only), and the legacy-only
  `data-final-fixes.lua` that writes the bridge — declared in the repo `CLAUDE.md` → *Git*
  beside Pure Modules' divergent list. A cherry-pick touching a forked file is rewritten by
  hand. The verified 2.0 API surface: `analysis/factorio-2.0.md`.
- **First release pair shipped 2026-08-16: `0.1.0` is the Factorio 2.0 build, `0.1.1` the
  Factorio 2.1 build** — the repo owner assigned the lower number to the 2.0 track in the
  release request, matching the ship-2.0-first pair convention. The two tracks share one
  sequential version line (repo rule, `factorio-multiversion`), so whatever ships next takes
  the next free number, whichever game it targets.
- **No flib dependency.** Its save/load-safe GUI handler registry is ~43 lines and worth
  reproducing by hand for one small frame; flib has nothing for shortcuts, and 0.17.0 was a
  breaking release. Copy the pattern, not the dependency.

## Portal presentation

Material for the mod portal page. Live since the 0.1.0 / 0.1.1 pair of 2026-08-16 — license
`default_gnugplv3`, category `utilities` (Mining Patch Planner's own), the README as the
description, the five gallery shots below in filename order (synced with the 0.2.0 / 0.2.1
pair on 2026-08-17). Every later upload or portal edit still needs the repo owner's
per-release approval.

- **`README.md` is the portal description**, uploaded verbatim by `fmtk details --readme`, so it
  is written for a player skimming the page rather than for a contributor. The portal takes
  GitHub-flavoured markdown, and images only as URLs to somewhere else.
- **`faq.md` is the portal FAQ tab**, synced by `fmtk details --faq` and shipped in the zip
  like `README.md` — deliberately not in `package.ignore`, it is a few hundred bytes of player
  help. The entries track the question each release generates: the research gate and the
  setting that lifts it (2026-08-16, the owner's pick), where the hidden pickers went
  (2026-08-17), what the active provider chest is for, why machines pause under circuit
  limits (2026-08-26), and why a two-fluid recipe is refused.
- **`images/` holds the gallery shots, numbered in the order they are uploaded**: the planner
  window first, then the vanilla loops, then the modded ones. The gallery has no order but upload
  order — the API's `images/edit` takes an ordered id list — so the number prefix is the only
  place that intent survives until the release that uses it. Refreshed by the owner on
  2026-08-17 for the 0.2.0 feature set: the epic-substations shot left, the fluid and
  extra-quality shots arrived.
  - `01-planner-menu.jpg` — the modal, legendary target, 5 machines and 4 recyclers. Predates
    the pipe picker; worth re-shooting before the 0.2.0 gallery sync if the strip should show
    all four buttons.
  - `02-legendary-upcycling-assemblers.jpg` — the vanilla loop that menu plans.
  - `03-legendary-upcycling-big-miners.jpg` — the 0.2.0 headline: the big mining drill's
    molten-iron loop to legendary in foundries on Vulcanus — pole columns, per-column pipe
    runs, and the player's underground taps visible beneath the bottom ring.
  - `04-modded-upcycling.jpg` — the same planner against modded machines and belts.
  - `05-modded-upcycling-extra-quality.jpg` — a modded loop climbing through mod-added
    quality tiers, seven machine columns wide.
- **Numbering the files costs nothing, because the portal does not show gallery filenames.**
  `GET /api/mods/<name>/full` returns `assets-mod.factorio.com/assets/<sha1>.png` and no name at
  all — checked against `pure-modules-realk` on 2026-08-16. The repo `CLAUDE.md` says the portal
  displays the filename, which holds for the description's own links but not for the gallery.
- **`images/description/` is not gallery material.** It holds what the README embeds, which the
  portal can only take as URLs, so each file is mirrored on catbox:
  `vanilla-upcycling.gif` → https://files.catbox.moe/thkeot.gif,
  `modded-upcycling.gif` → https://files.catbox.moe/ulihf9.gif,
  `shortcut-button.jpg` → https://files.catbox.moe/08ae4j.jpg (the shortcut button, shown inline
  in the how-to-use steps). The local copies are the masters — catbox is not ours and can drop a
  file, and replacing one is a description edit, so the mapping has to survive.
- **The whole `images/` tree stays out of the zip** via `package.ignore`'s `images/**`. Tracked
  in git so a shot travels with the build it was taken from.

## Interaction

- **Shortcut → modal → Confirm → a blueprint in the cursor.** Confirm designs the loop and puts
  it in the player's hand as an ordinary blueprint; from there the engine owns everything —
  preview, rotation, flipping, snapping, undo and the build. The mod handles no placement event
  at all, which is the point rather than an omission: obstacle handling, tree clearing and
  force-building are behaviours every player already knows, and reimplementing them could only
  differ from what they expect.
  Chosen 2026-08-18, replacing the one-shot selection tool the first version shipped. A
  selection tool can report an area but cannot show anything, and there is **no API for the
  cursor's world position** (`LuaControl.render_position` is the player, and
  `CustomInputEvent.cursor_position` only fires on a keypress) — so a cursor-following preview
  is not merely nicer as a blueprint, it is impossible any other way.
  The stack is a plain vanilla `blueprint`, not a prototype of this mod's own: it costs no name
  in a flat global namespace, and a custom one would buy only an icon, which `preview_icons`
  gives anyway. `player.cursor_stack_temporary = true` makes it behave like the tool it
  replaced — Q throws it away, nothing lands in the inventory — while leaving the player the
  option of dragging it into a slot to keep the design.
  **It is deliberately not one-shot.** The tool cleared itself from the cursor after a successful
  placement; a blueprint stays in hand and can be stamped again. That falls out of "identical to
  placing a blueprint" rather than being chosen separately, and it is the right answer anyway —
  a second column of the same loop is a thing players want, and refusing it would mean
  reimplementing consumption the engine does not do.
- **The game's "Confirm window" key confirms the modal**, so the planner behaves like every
  vanilla dialog: E places, Esc cancels. Chosen 2026-08-18 at the repo owner's request, after the
  key merely closed the modal and threw the design away.
  Nothing in the engine gives a mod GUI this for free — `on_gui_closed` carries no key, so the
  close handler cannot tell E from Esc, and `on_gui_confirmed` fires only for Enter in a
  textfield, which this modal has none of. The mechanism is a `custom-input` **linked** to the
  `confirm-gui` game control (`prototypes/planner/input.lua`), which rides whatever the player
  has bound, stays out of the controls GUI and so needs no locale key. Space Exploration ships
  the same pattern for its pin dialog.
  **`consuming` stays `"none"`, and that is forced rather than preferred**: `"game-only"` blocks
  the linked control everywhere, so E would stop opening the inventory. The engine's own close
  therefore always runs after the handler, and the repo owner's call was to accept what that
  costs — a refused hand-over (full hands) closes the modal on the key where the button leaves it
  open. The message still prints and the shortcut reopens with every choice remembered; the
  alternative was re-taking `player.opened` inside `on_gui_closed`, the exact hazard
  `gui.close_settings` already documents. Evidence: `analysis/api.md` §22.
  `gui.confirm(player)` is public and **guards its own preconditions** — a modal must be open and
  the settings panel may not be open — because the key can arrive with neither, where the
  button never can.
  **The key swallows one press while an element chooser is presumed open** (2026-08-20, after a
  press of E over the machine picker's floating chooser placed the blueprint and tore the
  chooser down instead of selecting). The chooser has no API surface at all — no event, no
  `gui_type`, and it never takes `player.opened` — so the click that opens one stands in as the
  signal, cleared by any later gui event for that player; the engine's own confirm, which runs
  after the handler, then lands on the chooser exactly as in a vanilla dialog
  (`gui.confirm_key`, the key's own entry point — the button keeps `gui.confirm` and never
  swallows). The presumption goes stale when a chooser closes without an event — Esc, a click
  on nothing, re-picking the same value — and the next E then closes the modal unconfirmed
  instead of placing. The owner accepts that cost: choices are kept, the shortcut reopens, and
  the button always works. Evidence, including why nothing better exists: `analysis/api.md` §23.
- **Gated on the `recycling` technology** (plus `unavailable_until_unlocked = true`), not on
  quality. The loop is unbuildable without a recycler, so gating on quality alone would offer a
  button that cannot yet produce anything.
- **A rebindable hotkey toggles the planner** — CTRL+U by default, requested by the repo
  owner 2026-08-20 (first shipped draft was CTRL+SHIFT+U; the owner re-picked the lighter
  combo the same day after rebinding to it in game, and both the dev install's mods and the
  Steam library were scanned — no vanilla control and no installed mod binds CONTROL + U). A second `custom-input`, this one keybound rather than linked, sharing the
  shortcut's own `upl-open` prototype name — the Krastorio 2 pairing shape (its jackhammer
  ships a shortcut and an input under one name), which is what lets the shortcut's
  `associated_control_input` advertise the binding in the button's tooltip and the three rename
  together. The key honours the same recycling gate as the button, through
  `gui.toggle_key` reading `is_shortcut_available` — a custom input fires whether or not the
  shortcut is unlocked, and without the check the key would open a planner the recycling
  technology has not delivered a recycler for. `[controls]` locale key `upl-open` names it in
  the controls menu. **A refused press prints why** (2026-08-20, after the silent refusal was
  reported as a broken key): the button greys out visibly but a dead key looks unbound, so
  `gui.toggle_key` names the gating technology, read off the shortcut prototype's
  `technology_to_unlock` at runtime so message and gate cannot drift. A scripted revoke with
  no gating tech stays silent — the scenario chose to hide the planner. The refusal is
  returned as a value because `player.print` is unobservable from a spec.
- **The modal is two blocks.** The top frame is what the loop **makes** — item, target quality,
  crafting machine, recycler. Under a *Build options* caption sits what it is built **out of**:
  belt, inserter, requester chest, buffer chest, output chest, overflow chest, quality module,
  top machine module, electric pole, pipe, and the trash-unrequested checkbox (checked by
  default). The
  inserter, the first three chests and the top machine's module joined the strip on 2026-08-17 at
  the repo owner's request, closing the parked chest picker and the parked productivity-module one;
  the overflow chest joined them on 2026-08-20 with the tap it feeds;
  **nothing the plan places is auto-picked any more** except the underground pipe, which is
  derived from the pipe rather than chosen. The strip is six captioned concept groups — see
  its own bullet below.
  The pipe (added 2026-08-17 with fluid support, the repo owner's call for a picker
  over an auto-pick) carries no quality — like the belt, nothing about it scales with quality —
  and matters only when the recipe takes a fluid; its underground counterpart is derived, not
  picked, since no prototype links the pair (`<name>-to-ground` convention first, longest
  researched reach as the fallback).
  The Build options pickers carry no per-picker row labels on purpose: each row reads by icon
  under its group's caption, the way the game's own tool settings do, so each tooltip opens
  with its own name in `[font=default-bold]`.
- **Quality is pickable on every entity picker except the belt and the pipe.** A measured call,
  not a taste one, and the engine states the rule itself: every entity type gets its own quality
  bonus apart from transport belt, pipe and rail
  (`quality/locale/en/quality.cfg`, *quality-bonus-exceptions*). So `belt_speed` is a plain
  attribute with no quality variant the way `get_crafting_speed(quality)` has one — a legendary
  belt carries exactly as much as a normal one — while the machine, recycler, module, pole,
  inserter and all five chests each have a bonus worth choosing. For the inserter and the chests
  those bonuses are swing speed and inventory size
  (`quality_affects_inventory_size` **defaults true** on `ContainerPrototype`, so a chest gets
  it without base opting in; `analysis/api.md` §15).
- **A build material with a quality travels as a `{ name, quality }` pair**, from `resources()`
  through the layout params to the ghost; a bare string means the thing has no quality
  dimension at all. The machine and the recycler already worked this way, so the belt and the
  pipe staying strings is the invariant rather than an inconsistency — the shape says which
  kind of material it is.
- **The shortcut button is `style = "green"`**, the repo owner's call on 2026-08-16 — it sits in
  the same `b[blueprints]` order block as the vanilla planners, and green is the one of the four
  styles (`default|blue|red|green`) not already worn by a neighbour there.
- **The icon is two symbols, not one badged item.** Recycler at 0.85 of the icon on the centre,
  legendary pip at 0.80 shifted 0.38 down-right — the mod turns recycling *into* quality, and a
  small corner pip reads instead as "a legendary recycler", which is the wrong idea. The repo
  owner's call on 2026-08-16, chosen from dispositions rendered at real button size.
- **Neither layer carries a negative shift**, because a negative one clips against the composed
  canvas instead of growing it (`analysis/api.md` §11). The separation therefore all sits on the
  pip rather than being split between the two.
- **`thumbnail.png` is the shortcut button at 144x144** — the game's own green button plate with
  the composed icon inside, so the portal card shows the thing the player will click. Built from
  the `--dump-icon-sprites` output rather than upscaled from a screenshot.
- **Icon layer `scale` and `shift` are written once as fractions of the icon and resolved per
  prototype.** They are measured against the prototype's *expected* icon size — 64 for an item,
  32 for a shortcut's `icons`, 24 for its `small_icons` — so one shared table renders the same
  layer at twice the intended size on a shortcut. A layer hanging outside the icon also inflates
  the composed bounding box, and the engine shrinks everything else to fit the button, which is
  the second half of what went wrong. `icons.lua` exports `item`, `shortcut` and `shortcut_small`
  from one set of fractions; evidence in `analysis/api.md` §11.
- **Pickers offer only what the force has researched.** The per-player
  `upcycler-planner-show-all` setting shows everything instead, standing in for the game's own
  "show all items in selection lists" option, which is not exposed to the runtime API. An empty
  researched subset falls back to the full list so the modal never dead-ends. Ticked in the
  settings panel below as well as in the game's settings menu.
- **A picker is only shown when it has something to choose between** (repo owner's call,
  2026-08-17). One option is not a choice, so a picker offering exactly one thing is hidden —
  which in a vanilla game is the recycler and the pipe, and
  a modset that adds an alternative brings each of them back. The count is taken on the list the
  picker would really offer, so the setting above moves it too. Seven pickers are exempt: the
  item, the target quality, the machine, the belt and the quality module are the choice whatever
  the count, and the pole and the top machine's module have a *clear* that is itself the second
  option ("no poles", "leave it empty") — the rule that resolved the pole appearing on both halves
  of the request. The pipe carries one extra condition of its own: it stays out of the strip until
  the chosen recipe takes a fluid, since it plumbs nothing otherwise.
  **The beacon group goes the chests' way, and further** (owner's call, 2026-08-22, same
  session the pickers landed): hidden by default whatever the count **and whatever is
  researched** — a beacon is an opt-in extra, and a beacon button in the default strip reads
  as a decision every player has to make before pressing Place. Show-all reveals the group,
  and a *chosen* beacon keeps it visible with show-all off again, so the opt-in stays on
  display and clearable rather than riding the plan as a hidden passenger. One predicate
  (`beacon_visible`) serves the whole group — beacon, module and the count drop-down, the
  count additionally following `worth_showing` inside it, since a max of one is not a choice;
  clearing the beacon returns the group to hidden.
  **The chests are the exception the other way** (owner's call, 2026-08-18): all four are
  hidden whatever the count, so the buffer goes even though wooden, iron and steel are a real
  choice. The default — the largest inventory the force has researched — is the right answer
  nearly every time, and a chest button apiece in a ten-button strip reads as that many decisions
  the player has to make before pressing Place. Show-all brings them all back, quality included.
  A hidden picker is still built, still holds the default the plan uses, and hides its row label
  with it; only the widget is gone. `visible` is documented as *"taking no space in the layout"*,
  which is what lets a hidden row reflow instead of leaving a hole.
  **What hiding costs, and the way out.** A hidden picker takes its *quality* with it, so hiding
  alone would put legendary recyclers and legendary logistic chests out of reach in a vanilla
  game. That is why the **`upcycler-planner-show-all-build-options`** setting exists (owner's
  call, 2026-08-17): with it on, every picker is shown whatever the count — the pipe included even
  for a recipe with no fluid, since a player asking to see everything means everything. So the
  count rule is the default rather than a ceiling: a hidden picker's quality is reached through
  the setting, not through a permanently visible row.
- **The two settings live in the modal, in a window-styled panel** (owner's call, 2026-08-17,
  patterned on Factory Planner's Preferences dialog): a **Settings** button in the titlebar opens
  a small panel holding *Show unresearched items* and *Show all build options*. It is called
  Settings rather than Preferences throughout — panel, button and locale — because that is what
  the two values are: the mod's own per-player settings, editable from the game's menu as well.
  **The button is captioned rather than drawn** (owner's call, 2026-08-17). The base game ships no
  gear, and its settings-sliders glyph (`preset`, for map-generation presets) reads as a preset
  switcher; `frame_button` — `frame_action_button`'s own parent — gives a caption the same chrome
  as the close X beside it, without the fixed 24x24 square. **The caption is white and darkens on
  hover**, set on the element rather than in a style prototype: `frame_button` inherits `button`'s
  font colours, which are black in both states and read inside out on a titlebar. That is the same
  reversal `frame_action_button`'s picture inversion performs for a glyph — and an icon button here
  would still need a *white* one, plus a sprite prototype of its own: `analysis/api.md` §18, kept
  for the next one.
  **They stay mod SETTINGS rather than moving into `storage`**, which is where Factory Planner
  keeps its own: a mod may overwrite its own per-player settings and doing so raises
  `on_runtime_mod_setting_changed` exactly as the settings menu does (both measured,
  `analysis/api.md` §17). So the window is a second face on one value instead of a second value —
  one repaint path serves both surfaces, and a setting follows the player into their next save,
  which a storage-backed one would not. FP's reason for storage does not apply here: it has thirty
  preferences of many widget types and no use for the settings menu.
  **It is a sibling COLUMN inside the planner's own screen element, not a second window**
  (owner's demand after two failed placements, 2026-08-20: "always side by side no matter
  what"). The screen element is an **invisible container** — vanilla's `invisible_frame`, no
  graphics, no padding — holding two window-styled frames: the planner, and the panel while it
  is open, with a 12px left margin standing in for the gap two windows used to have. So the
  pair still *looks* like two windows, titlebars level, map visible between them, while
  "beside" is the engine's layout and there is nothing to place, measure, or follow. Both
  titlebars drag the container (`drag_target` must name a `gui.screen` element). What killed
  placement-by-arithmetic, in order: no API reads an element's rendered size, so a second
  window's x had to come from the modal's auto-centred location (width = resolution − 2x) — an
  inference any drag silently invalidates, with a moderate drag still *plausible-looking*
  (owner's screenshots: the window opened across the screen); and the repair, gating
  measurement on an `on_gui_location_changed` drag flag, died the same day because **2.1.14
  raises that event for the engine's own auto_center layout too** (`analysis/api.md` §19), so
  the flag was set before any drag and the width was never learned. A visible container was
  also tried and rejected — one wide slab with dead background under the short panel (owner's
  screenshot). Even Distribution lands on the same principle from the other side: its settings
  panel is *anchored* to the inventory GUI, never positioned by coordinates. Opening the
  planner also **sweeps a leftover `upl-settings` screen window** a pre-0.4.2 save can carry,
  as does `gui.close_settings`. `gui_spec` pins the containment, the sweep, and the rebuild
  keeping an open panel open.
- **A picker handler does nothing unless its value actually changed.** `on_gui_click` and
  `on_gui_elem_changed` share one dispatcher, so a click reaches the handler carrying the value
  already in the button — and the two handlers that rebuild the modal would otherwise destroy the
  element while the engine was opening its chooser on it (`analysis/api.md` §20). One
  consequence worth keeping: **a rebuild leaves the modal exactly where it was** rather than
  re-centring, so it does not jump out from under the cursor when a setting is flipped.
  **The container keeps `player.opened` whether or not the panel is open** — the panel is a
  child, never a window of its own — and `control.lua` turns a close request on the container
  into "panel first": with the panel up, Esc, the engine's confirm, or another GUI taking over
  dismisses just the panel (retaking `opened` only when nothing else claimed it, since opening
  a GUI during `on_gui_closed` force-closes whichever one the engine was not asked for —
  measured in `gui_spec`); without it, the close is honoured. The panel's existence is the
  guard, rather than a stored flag as in FP, because it cannot drift from what is on screen.
  Closing the modal takes the panel with it for free; a rebuild triggered by flipping a
  setting re-creates an open panel with fresh ticks, which also retired the repaint-on-change
  loop.
- **The build options are six captioned concept groups** (owner's call, 2026-08-22,
  superseding the 2026-08-17 six-column grid; Circuits joined 2026-08-26): Transport (belt,
  inserter, pipe), Chests (the four roles), Modules (quality, top machine), Beacons (beacon,
  its module, the per-tier count drop-down), Power (pole), Circuits (the enable checkbox and
  the Limits button) — each a `semibold_caption_label` over a horizontal flow of
  icon pickers, the trash checkbox below them all. Twelve icon-only pickers in one flat grid
  left hovering as the only way to tell them apart; small captions name the concepts while the
  pickers stay icons — chosen from three offered shapes over per-picker labelled rows and over
  two side-by-side group columns. No group holds more than four icons, so a plain flow needs
  no wrap rule the way the old table did (an invisible child takes no space in either —
  `analysis/api.md` §19). A group whose every picker is hidden — the chests by default, the
  beacon group until show-all or a pick — hides caption and row together, the rule owned once
  by the group rather than by each button.
- **Storage holds flat strings.** `machine` / `machine_quality` pairs rather than the
  `{name, quality}` tables the `-with-quality` widgets speak. `control.lua`'s stated contract is
  that storage holds nothing but strings, and a nested table there fails silently rather than
  loudly. The second reason this used to carry — that Confirm's snapshot was a shallow copy, so
  a nested table would not have frozen — went with the snapshot on 2026-08-18: the blueprint
  handed over *is* the frozen plan.

## What gets planned

- **The plan is computed, then serialised into a blueprint the engine builds.**
  `scripts/blueprint.lua` turns the plan into an array of `BlueprintEntity`; the engine makes
  the ghosts when the player stamps it. Computing the layout rather than storing a string is
  what lets it answer the player's choices — that half never changed.
  The **simulation-only restriction applies to `LuaSurface.create_entities_from_blueprint_string`
  and to nothing else**: `set_blueprint_entities`, `import_stack`, `build_blueprint` and
  `create_blueprint` carry no such note (checked across every string in `runtime-api.json`,
  2026-08-18). The first version generalised that one restriction into "never a blueprint", which
  was wider than its evidence.
  The thirteen fields a plan needs were read out of the engine rather than the docs: a plan was
  placed as ghosts, captured with `create_blueprint`, and `get_blueprint_entities()` named them.
  Evidence in `analysis/api.md` §21.
  **A wire names a plan index, never a position among one kind of entity.** `poles.plan` numbers
  within its own result, because that is the only ordering it can know; `planner.plan` rebases
  onto plan indices as it appends, so the serialiser wires by index and knows nothing about
  poles. The alternative — counting a `pole` flag downstream — made three modules depend on an
  invariant none of them owned, and it cannot express a wire between two unlike entities at all,
  which is exactly what the deferred circuit garnish needs.
- **Belt ring first**, specified in `analysis/layout-belt-ring.md`. Chosen over the smaller bot
  loop because product circulation stays on its own belts, so it behaves identically in an
  isolated pocket and in a base-wide logistic network — the right default for a mod strangers
  install into arbitrary bases. The **bot loop is a deferred toggle, not a dead idea**: fully
  specified in `analysis/layout-bot-loop.md`, with its two blockers in `deferred.md`.
- **One machine per tier.** The compact "casino" every shared blueprint ships. Honest framing:
  a convenience build, not a throughput build — sustained ratios taper about tenfold per tier.
  If scaling is ever added, repeat *columns per tier* rather than inventing new geometry.
- **Modules are planned, not merely requested**: quality below the target tier, the player's
  pick at it, quality in the recyclers.
- **The top machine's module is its own picker, defaulting to productivity or to nothing**
  (repo owner's call, 2026-08-17). At the target tier quality has nothing left to roll into, so
  the default is the strongest researched module that actually raises productivity — and
  **nothing at all** when the recipe or the machine refuses it, which is the common case:
  `allow_productivity` defaults to false and only ~43 of base's 193 recipes opt in. With no
  productivity module researched the top machine is left **empty** rather than given a quality
  module: that would be choosing for the player, and the picker is where the choice belongs. Clearing the picker
  means "leave the top machine empty", the pole's rule, recorded in `no_terminal_module` so an
  explicit clear is not re-defaulted at open.
- **The two module pickers own their qualities separately.** One shared module quality was
  deliberate while the terminal module was derived from the quality module; once it became a
  choice of its own, one quality would have tied two unrelated decisions together.
- **A picker offers only what the machine AND the recipe accept**, which needed a measured rule
  rather than the obvious one: only the effects a module applies **positively** have to be
  allowed (`analysis/api.md` §16). Both halves are re-resolved when either the machine or the
  recipe changes, so a pick the new pair refuses is replaced rather than left to fail validation
  — the machine picker's own pattern. The quality-module picker keeps offering every quality
  module and refusing at validation instead: its own gate (`recipe` and machine must allow the
  quality effect) has already run by then, so there is nothing left for a list to exclude.
  The optimal split — how much quality against how much productivity — is still the open
  question, and still better driven by `get_roll_chances()` than by a hardcoded table.
- **Modded recyclers work by rotation, not by convention.** `vector_to_place_result` is
  per-prototype, so `planner.recycler_orientation()` computes the rotation that lands the throw
  in the machine above. Width is not a constraint — column pitch is `max(Wm, Wr)`. The one hard
  limit is that the throw lands inside the machine (`eject_col < Wm`), refused with the minimum
  width named.
- **Chests are hard-constrained to 1x1.** Every chest position in the layout is exactly one
  tile, so footprint is a geometric constraint of the row plan rather than a preference. A
  modded 1x1 chest with more slots still wins legitimately; anything bigger is out regardless of
  research — the picker cannot offer it either.
- **The five chest roles are fixed; only the chest is the player's.** `requester`, `stock`,
  `container`, `provider` and `overflow` are one predicate each, and each picker offers only its
  own kind: a requester chest cannot be swapped for a passive provider, nor the plain relief
  chest for a logistic one.
  The reason is the loop's own contract — the relief chest inside it must not talk to the
  player's network, or the loop competes with the base for its own intermediates — so the role
  is geometry-and-semantics while the chest is taste. Largest researched inventory remains the
  default per role. `overflow` is the one role pinned to a specific logistic mode (active
  provider) rather than merely to a kind, for the reason in its own bullet above: it is the only
  sink in the loop that empties itself. `stock` is the one role whose KIND is itself a choice —
  the bullet below.
- **The stock chests are buffer chests by default, requester chests by untick** (2026-08-26,
  owner's call: "opt in checkbox checked by default"). The per-tier item chests — the census
  chests the reserve inserters drain — are the `stock` role, split out of `requester` (which now
  covers only the ingredient feed chests; those, the output and the overflow never change kind).
  **Why buffer**: a buffer chest requests exactly as a requester does (same tech —
  `logistic-system` unlocks requester, buffer and active provider together, base
  `technology.lua` — same slots, same blueprint request shape), and additionally provides to
  personal logistics, construction bots and ticked requesters — which is what makes the circuit
  Min reserve stock the player can actually use instead of items locked away. **Why a
  checkbox**: construction bots serving nearby ghosts drain the loop's intermediates — modules,
  belts and machines are exactly what players upcycle — and outside consumers can dip below a
  circuit floor (the wire only gates the loop's own reserve inserter), so "always buffer" and
  "never buffer" were both rejected; the trade genuinely cuts both ways and the checkbox sits
  beside trash-unrequested. **Mechanics**: `choices.buffer_stock`, nil-means-true (`~= false`,
  the trash idiom); the stock picker's offered list, membership test, default pick and prune all
  resolve through the flag (`resolved_role` — the unbuffered kind IS the requester list, so no
  duplicate scan); toggling forgets the stock pick so the rebuild refills the new kind's best,
  and keeps the quality. One asymmetry accepted: a buffered loop cannot seed itself from stock
  the base holds in OTHER buffer chests, since buffers never request from buffers — the
  requester-kind untick restores that.
- **Both new pickers gate on `items_to_place_this`**, the same test the machine list uses. Found
  on 2026-08-17 by reading the data dump rather than by reasoning: base ships 1x1 *containers*
  for the crash site and the tips-and-tricks simulations (`red-chest`, `blue-chest`,
  `crash-site-chest-1/2`) that no item places, and without the gate they appear in the picker
  the moment *Show unresearched items* is on.
- **Fuelled inserters are never planned in and never offered**, and every planned inserter must
  reach one tile. An unattended loop cannot keep a burner fed. When every researched inserter
  needs fuel — how a fresh Space Age game genuinely starts — validation says so instead of
  planning a loop that would starve, which is why the burners stay in `inserter_candidates()`
  while the picker and the pick both read the electric subset.
- **A chosen inserter must still carry a filter slot per ingredient, and the refusal names the
  pick only when a better inserter actually exists.** The harvest and relief positions need the
  slots, so the requirement is not negotiable, and quietly substituting a different inserter
  would hide the player's own choice — but a message advising "pick one with more slots" is worse
  than useless when none has any. So `any_inserter` decides: nothing available with enough slots
  blames the *recipe* (every vanilla case — all six vanilla inserters carry five, and exactly one
  vanilla upcyclable recipe needs six, fusion reactor equipment), and only past that gate is the
  pick named. **The by-name branch therefore needs a modded inserter to reach and carries no
  spec**, which is written into the spec that covers the reachable side. A recipe change re-picks
  an outgrown inserter, exactly as it re-picks a machine that can no longer craft.
- **Belt-stacking inserters are never planned in** (the repo owner's call, 2026-08-17). A
  stacking hand holds out for a full belt stack of one item-and-quality, and a quality loop
  trickles dozens of item/quality combinations past every position — community-documented
  freezes in recycler builds (ktz.me, 2026-04-08, *Factorio: Recycler Belt Stacking*; community
  claim, not re-measured locally). The pick could not defend itself: vanilla's bulk-inserter and
  stack-inserter tie the scorer outright — both `bulk`, both rotation 0.04 — so the winner was
  engine iteration order. `inserter_max_belt_stack_size` is what tells them apart;
  `inserter_candidates()` excludes anything above one, a spec guards it, and `loop_spec`'s
  relief rig stands the planner's own pick so the wedge-relief measurement covers the inserter
  the layout actually plans.
- **Electric poles are planned in, and a plan is as narrow as full coverage allows.** The repo
  owner's call, 2026-08-20, superseding the 2026-08-17 rule that opened a utility column before
  every machine column: **the narrower plan wins whenever both power everything.** So the
  planner solves for the columns instead of assuming them — the compact plan first, then all
  columns, then collapsing back every column no pole stood in; fewest unpowered wins and width
  breaks the tie. Where a column does open it is still sized to the pole the player picked and
  still shared with the pipe run (pole width, +1 for pipes), and a fluid plan can never
  collapse below 1. What the owner accepted for the width: **more poles**, and they no longer
  stand in a tidy line — on a vanilla rare loop, five poles in the ring's own free ground
  rather than three in columns, at 11 wide instead of 14. Researched-best **1x1** pole by
  default (largest supply area; a substation is never sprung on the player, though every size
  is pickable), clearable to "no poles"; best effort plus an orange count when nothing covers;
  one wired network via ghost copper wires. Algorithm and the measured shapes in
  `analysis/poles.md`, engine facts in `analysis/api.md` §10. **Coverage counts only the
  largest wired component** — geometric coverage alone would call a consumer powered when its
  only pole sits on an unwired island, a lie that surfaces in game as a mystery.
- **Beacons are planned in, opt-in, a vertical stack per tier in the utility column** (the
  repo owner's calls, 2026-08-22: per-tier column placement, off by default, efficiency-module
  default; same day, the player-chosen count). When the player picks a beacon in Build
  options, every tier's column floors at the beacon's width and stands a stack of
  `choices.beacon_count` beacons — default one — centred as one rigid block on that tier's
  machine+recycler band, the machine alone on the terminal tier, where the supply squares span
  both (the measured edge rule, `analysis/api.md` §25; geometry in
  `analysis/layout-belt-ring.md` §Beacons). **Stacking costs rows, never width**: the block
  clamps into the interior rows as a whole, and the count is capped at
  `layout.max_beacon_count` = `floor(interior_height / beacon height)` — vanilla shapes take
  four. The count control is a **dynamic drop-down offering exactly 1..max** (the quality
  dropdown's shape, values riding in its tags), stored as a plain number, snapping down in
  `apply_defaults` when a re-pick shrinks the max — which is why the recycler handler now
  rebuilds via `gui.open` like the machine's: its rotated height is one of the max's inputs.
  **Off by default with no clear-flag**: unlike the pole there is no researched-best fallback,
  so nil already means exactly one thing and `chosen_beacon` needs no `no_beacon` boolean — a
  beacon costs a column of width per tier and its insertable modules trade against the quality
  rolls the loop exists for, so it is never sprung on the player. **The module default is the
  strongest researched efficiency module, never speed**: what a beacon transmits is gated by
  the receiver's own `allowed_effects`, so a speed module's negative quality component lands on
  every covered machine and recycler (§25) — the opposite of the mod's purpose — and the
  picker's tooltip says so while leaving speed pickable. The module answers to the beacon alone
  (no recipe half; `module_refusal` takes a nil recipe), clears to "place the beacon empty"
  (`no_beacon_module`, the terminal module's shape), fills every beacon in the stack alike,
  and re-resolves when the beacon changes. **The pole pass carries no beacon-aware code**: a
  beacon has an electric energy source and a tile footprint, so `electric_consumers` counts it
  and `occupied` avoids it through the same generic scans as a machine — a pure spec pins the
  claim, and `poles.lua`'s one change is exporting its overlap primitive for `beacon_reach` to
  share. `pole_gap` is the **sum** `pole width + beacon width` (plus the pipe's tile), not the
  max it was at count one: a full-height stack can leave the beacon's column without a single
  free row, so the pole reserves its own lane west of the stack — and the ladder only ever
  reads `pole_gap` after the compact attempt left a consumer dark, so every plan that covered
  before is byte-identical still. **Warn, don't refuse, on short reach**
  (`beacon-out-of-reach`, unreachable in vanilla): the check is per receiver — some beacon in
  the stack must reach the machine and some the recycler, not every beacon both — and a stack
  that cannot span its pair still leaves a working loop, the poles' own best-effort
  philosophy. The one structural refusal is a beacon taller than the interior rows
  (`beacon-too-tall`), which is exactly `max_beacon_count == 0`; an over-asked count clamps,
  never refuses.
- **Fluid recipes are planned in** (2026-08-17, the promised 0.2.0 feature): a pipe run down
  each utility column's east edge, spanning the full interior height, with every machine
  rotated per prototype so a fluid input connection meets it
  (`planner.machine_fluid_orientation`, the recycler-orientation lesson again; measured rule
  and the merged-fluid-box behaviour in `analysis/api.md` §14). Each run ends in underground
  stubs beneath the top and bottom ring belts; the player taps any column from either side
  with an underground pipe of their own and wires the columns together however they like.
  Nothing requests fluid by bots.
- **Everything the loop rolls above the target leaves through one tap, into an active provider.**
  The repo owner's call, 2026-08-20, after reporting a rare/epic loop silting its own belt up in
  a played game. Both halves of the loop overshoot — a moduled machine rolls the PRODUCT past the
  target, a moduled recycler rolls the INGREDIENTS past it — and nothing consumes either, because
  every machine is pinned to one tier and quality matching is exact. The tap is an inserter and a
  chest standing in the two tiles the terminal column has spare (no recycler there, so no extract
  stack), so **the footprint does not change**; it is that column's unload inserter reversed,
  facing the bottom ring instead of away from it.
  **One filter does it, naming a quality and NO item** — `{quality = target, comparator = ">"}`,
  which the engine reads as "anything at all, above this tier" (measured, `analysis/api.md` §24).
  So the cost does not grow with the ingredient count, and anything unexpected is caught too. The
  earlier shape — one filter per ingredient — was rejected for costing `#ingredients` slots to say
  the same thing.
  The chest is an **active provider** rather than the player's pick of logistic chest, because it
  is the loop's only unbounded sink: a passive provider or a plain chest merely fills, and the ring
  saturates again a few hours later. `logistic-system` unlocks it beside the requester chest the
  mod already requires, so it costs no research.
  **Placed whenever the quality chain has a tier above the target, researched or not.** Rolls
  cannot exceed a force's unlocked qualities, so a tap can sit idle — but researching a new tier is
  exactly what clogs a loop built before it, and two entities is cheaper than re-stamping every
  loop in the base. At the top of the chain nothing can overshoot, so no tap is built at all.
  **What it costs, and the owner accepted it: one more electric pole** on the vanilla rare loop
  (six, not five). The tap is a consumer in the terminal column's bottom corner, which had none
  before, and it stands on two tiles the pole pass could otherwise have used. The *width* is
  unchanged, which is what the compact-first rule protects.
  Two consequences worth stating, because both look like regressions and are not. Above-target
  **product** now normally leaves by the tap rather than by the terminal catcher: the tap sits on
  the bottom ring and the catcher on the top, and product from a lower tier crosses the bottom
  first. The catcher keeps `">="` as the backstop, so a bot-less base behaves exactly as before.
  And the catcher's filter list — target quality plus one entry per tier above it, nearest first,
  **clamped to the inserter's five slots** — collapsed into that single `">="`, which is both
  exact and immune to a modded quality chain longer than five tiers.
- **Circuit limits: reserve and cap, opt-in and combinator-free** (owner's calls, 2026-08-26;
  the semantics are the owner's correction of the first-built demand cascade, same day — the
  journal has the story). Two rules. The CAP: every machine and every recycler carries the one
  shared condition `product@target < max`, counted in the output chest — machines run free
  until the cap is met, then the whole loop stops, and it wakes as bots draw the chest down.
  The RESERVES: each lower tier's reserve inserter (stock chest to recycler) carries `product@tier > min`,
  so the loop never grinds a tier's chest below the floor the player set — the floor is
  enforced on the INSERTER, the only hand that can draw the chest down, while the machines
  stay ungated per tier. A zero minimum (the default) keeps nothing back, and that tier's
  inserter is left ungated and unwired. The recyclers joining the cap is the one half the
  owner did not spell out: without it a parked loop keeps grinding its surplus — and tier
  0 keeps pulling the player's base production — while nothing consumes the result, which is
  the waste the feature exists to stop; one line to remove if free-running is ever preferred.
  Combinator-free because the layout already separates what each condition needs: stock
  chests hold one tier's product each, the output chest alone holds the target's, and a wire
  signal is distinct per quality (`SignalID.quality`, api.md §26) — every rule is a single
  comparison on an entity that inherits on/off behaviour (machines, the furnace recycler,
  inserters alike), and the census chests broadcast by default with no configuration.
  Two approximations, both accepted: an inserter's swing checks the condition at pickup, so
  a bonus-sized hand can dip a few items below the floor (the mechanism is exact at hand
  size one, measured); and a swing in flight can land one hand past the cap.
  **A floor raises its census chest's logistic request by the same amount** (owner's catch,
  2026-08-26, option picked from three): the stock chest requests one stack, and with
  trash-unrequested on — the default — bots skim anything above the request, so a floor past
  the request could never fill and the tier would silently stop recycling. Growing the
  request keeps the working-stock band on top of the kept floor, preserves the one-stack
  hoard cap's intent, and on the first tier makes bots actively deliver toward the floor —
  the literal reading of "keep this many in the chest". The rejected shapes: exempting
  floored chests from trash (loses the hoard cap, floor never topped up from the base) and a
  warning alone (asks the player to learn an internal number). What remains impossible — a
  floor at or past the chest's physical capacity — validates as a warning
  (`circuit-min-too-big`), asked at the chest's build quality since quality grows inventory.
  **Rejected:** the demand cascade (per-tier machine thresholds, recyclers gated on the tier
  above — built first, replaced the same day: the owner wants machines running whenever the
  cap allows, and MIN to read as a hard keep, not a stock target); and hard floors via
  compound conditions on the recycler (`> min AND < cap` needs a decider per tier — gating
  the inserter says the same thing in one comparison).
  **The wiring is a tree beside the pole tree**: a scalar `circuit_wire_to` plan index per
  entity, `wire_to`'s own shape, resolved to `circuit_green` by the serialiser's now
  connector-parameterised `connect()`. Generalising `wire_to` into a typed list was rejected:
  it touches poles.lua's output shape, which carries the falsified-parity-sweep obligation,
  for no functional gain — a tree needs one parent pointer. Each column chains reserve
  inserter → census chest → recycler → machine (the terminal's output chest straight to its
  machine); the cross-tier spine rides the MACHINE row, not the chest row: machines share
  rows, so spine hops are pure horizontal pitch (3–9 vanilla — the substation+beacon+pipe
  column reaches exactly the 9-tile wire reach), where the chest row's last hop to the
  output chest spans the whole machine+recycler band (3+Hm+Hr = 10 vanilla) and would have
  forced the relay on every plan. **Every reach comparison keeps half a tile of margin**:
  where the engine measures a wire — entity centres or the off-centre connector points — is
  unrecorded (§26), and the margin turns an exact-boundary hop into a relay or an honest
  warning where guessing wrong would drop the wire silently at build and split the network;
  a blueprint spec stamps the widest vanilla pitch and walks the one green component. When a
  hop exceeds the margined reach — that pitch, or fat modded columns — the spine falls back
  to relaying along the top ring belts (1-tile hops, any width; a wired belt with no
  control_behavior stays neutral, §26), each machine tapping the belt above it.
  An entity even that cannot reach is counted in `plan.circuit_unlinked` and warned about,
  never refused: an unconnected enable condition gates nothing (measured, §26), so the loop
  degrades to exactly the uncircuited one.
  **Off by default costs nothing, provably** — plan_spec pins a circuits-off plan carrying no
  condition and no circuit wire anywhere. `scripts/circuits.lua` is a pure decorator run
  strictly after the pole pass (circuits change no geometry, so there is nothing to solve
  together); layout.lua only records structural tags (`circuit_role`/`circuit_tier`, the
  `utility_columns` precedent) and knows nothing about conditions.
  **The wizard is the settings panel's sibling in every mechanic** — a second window-styled
  column in the invisible container, mutual exclusion between the two panels, "panel first" on
  close, recreated across rebuilds — holding one numeric textfield per tier (the mod's first
  textfields: valid keystrokes commit at once so the Confirm key can never outrun an edit,
  Enter snaps the display back to what holds, and `gui.confirm` refuses while the wizard is
  open, which also covers E landing in a focused field). **Each row says which rule it sets**
  — a Min or Max label ahead of the quality (the owner's ask: the UI must be clear that the
  two numbers mean opposite things), with the tooltips spelling both out. The numbers live in
  storage as flat values under TWO families — `circuit_min_<quality>` for the reserves,
  `circuit_max_<quality>` for the cap — keyed by quality NAME so a value survives the target
  moving, and split so a remembered floor can never become a ceiling when the target lands on
  its tier; both pruned by the quality in the key. Defaults: reserves 0, cap one stack of
  the product (the stock chest's own sizing rule). **Zero means off on both sides**: a zero
  reserve keeps nothing and stays unwired, and a zero cap means no cap — machines and
  recyclers ungated and unwired, each remaining reserve its own two-entity island — so a cap
  committed empty before any item was picked disables nothing silently, and the Max tooltip
  says "0 means no limit". A cap backfilled from one product's stack is remembered across an
  item change like every other choice — the number was defaulted, not chosen, and the
  wizard shows it for re-picking.
- **Nothing is ever built outside the ring — poles included.** The repo owner's call,
  2026-08-17, replacing the first-built external pipe header the same day: the ring rectangle
  is the plan's entire footprint, so the ground the player reserves is exactly what they see,
  and the plumbing topology outside it is theirs (a shared header, per-column feeds, tanks —
  their base, their call). What made it cheap: an interior header is impossible anyway (every
  interior row is an inserter reach-chain), so the only planned pipes were ever going to be
  vertical, and vertical runs end naturally in outward underground stubs
  (`analysis/layout-belt-ring.md` §Fluid recipes).

## What the planner refuses

- **Recipes with two or more distinct fluid ingredients**, with a message. A second fluid
  means a second, separate network; vanilla has exactly one such recipe (`ammonia-rocket-fuel`,
  measured 2026-08-17) and its product is already covered by the one-fluid `rocket-fuel`
  recipe, so the cost is zero items. Fluid PRODUCTS stay excluded by the single-item-product
  gate — the quantum processor returns hot fluoroketone beside the item and would need a drain
  network, a separate decision.
- **A fluid machine with no rotation that lands an input connection on the pipe run**, refused
  naming the machine. Unreachable in vanilla — the merged-box rule covers even the EM plant's
  opposite-flank inputs — so this is the modded-machine guard, and the alternative was piping
  it wrong: the reference book's own defect.
- **Self-recycling items** (steel and friends). A recycler-only loop needs thousands of inputs
  per legendary; the few shared designs that wash self-recyclers are a different architecture
  (recycler walls with no crafting stage — `analysis/blueprints.md` §9) with the same dire
  economics.
- **Recipes whose `allowed_effects` excludes quality**, checked on the recycling recipe too
  since the recyclers carry quality modules as well. `can_set_quality` is a different rule with
  a confusingly similar name — craftable *at* a quality, versus quality modules working on it at
  all. A recipe passing one while failing the other would carry an insert plan for a module it
  can never accept while the recyclers kept rolling ingredients up: a loop that limps rather
  than stops, which is the harder kind to diagnose.
- **A beacon taller than the ring's interior rows** (`beacon-too-tall`), which would poke
  through the ring belts — the beacon bullet under *What gets planned* carries the full
  reasoning; short reach is a warning there, never a refusal.
- **Anything whose only "producer" is a recycling or Factoriopedia-hidden recipe.** Researching
  `recycling` unlocks every generated `*-recycling` recipe at once, so a naive "some enabled
  recipe produces it" test reads unresearched modules and cheat-mod infinity chests as unlocked.

## Testing

- **The mod carries a permanent four-tier test suite; the throwaway `--create` scratch
  harnesses are retired.** Decided 2026-08-16 with the repo owner (framework, installs, GUI
  scope and the eject investigation each approved explicitly). In-game tier: the
  **factorio-test** framework driven by its npm CLI — the only maintained, 2.1-compatible
  option (everything else in the ecosystem is dead) — with specs in `tests/`, registered
  behind `script.active_mods["factorio-test"]` in `control.lua`, `"tests/**"` in
  `package.ignore`, and **never** a `factorio-test` entry in `dependencies`. Pure tier:
  `tests/pure/` runs on host Lua too, sub-second. Static tier: luacheck + emmylua_check
  against fmtk-generated types. Mechanics, runner scripts and the hard-won Windows plumbing
  live in the repo's `factorio-testing` skill, not here.
- **The suite pins the historical harness numbers as regressions** — widths 11/13, the five
  pole scenarios (including big-pole's honest 3 unpowered), the 210 upcyclable items, the
  wooden-chest empty terminal — so a drift in any of them is a release-visible event, not a
  silent reshape.
- **The blacklist relief inserter is load-bearing, by measurement.** The eject investigation
  (journal 2026-08-16, evidence `analysis/api.md` §9.6) showed a rolled-up ingredient in the
  recycler's output wedges the recycler completely; only the relief inserter keeps the loop
  alive. Any future layout change must keep it, and a test now fails if the behaviour
  regresses.
- **A behaviour-preserving change to `poles.lua` is proven by a falsified parity sweep, not by a
  green suite.** The suite pins pole counts, plan widths and connectivity; it pins no `wire_to`
  value, so a spanning tree rebuilt with different tie-breaks stays connected, still carries n-1
  wires, and passes everything. The discipline, used for all three 2026-08-20 rewrites: run the
  live file against the pre-change one recovered with `git show`, deep-compare every field of
  every pole, and **first point the harness at a deliberately broken copy to prove it can fail**
  — an earlier sweep in this mod produced a false pass by comparing one implementation with
  itself. The sweep must also carry a 5x5 machine: that is what fragments the wire network into
  the components `bridge` exists to join, and without it the pass is never exercised at all.
  Axes and numbers: `analysis/poles.md`.
- **GUI specs run in both tiers.** Headless works because a save's player stays connected
  under `--benchmark` (`analysis/api.md` §12); the graphics tier remains the real-client
  check, unattended thanks to a current-version save, freeplay's skip-intro remotes, and the
  runner's close-on-finish watcher.

## Rejected

Written down so they are not re-litigated. A rejected idea that is not recorded comes back.

- **Blueprint strings for placement** — the API forbids it outside simulations. See above.
- **`upcycler-` and `up-` as the prototype tag** — see Identity.
- **A strict `Wr < Wm` recycler width rule.** It came from the reference design's
  down-the-side product channel, which was never built: the real product path runs up to the top
  ring, so the recycler band is empty beside the recycler. The lesson generalises — check a
  constraint against the code, not against the document that described the design before it was
  built.
- **Labelled rows in the Build options strip.** The repo owner's explicit call for icons,
  twice: the flat icon grid on 2026-08-17, and captioned concept groups over per-picker
  labelled rows on 2026-08-22. Still the standing fallback if a chosen prototype's own tooltip
  turns out to override the custom one — ask before switching.
- **Degrading rather than excluding quality-refusing recipes.** Leaving the non-terminal
  machines' slots empty and letting the recyclers carry the climb alone would keep those items
  in the picker at roughly half the roll rate. Excluding them is simpler and honest — a loop the
  mod cannot build properly is better refused than shipped degraded — but the option is real, so
  it is recorded rather than left to be re-derived.
