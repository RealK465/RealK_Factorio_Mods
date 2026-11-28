# Decisions — Assembly Planner

What is settled, and why. Superseding means rewriting the entry here and telling the story in
`journal.md`.

## Identity

- **Name `assembly-planner`, title Assembly Planner** — the owner's pick (2026-11-25), over the
  suggested Mall Planner. Both portal names were free that day. It pairs with Upcycler Planner.
- **Prefix `apl-`** for prototypes, GUI element names and tag keys; settings and locale
  mod-level keys use the full `assembly-planner`. Upcycler Planner's convention (`upl-`), for
  its reasons.
- **No hard expansion dependency.** Only `base >= 2.1.0`, and no feature flags: a cell needs
  nothing from Space Age or quality, and the quality pickers simply offer normal without them.
- **Prior art: Quick Mall** (2.0 only when checked, 2026-11-25) generates the same kind of
  blueprint but requests a fixed stack of each ingredient and has no beacons, no quality split
  and no fluid plumbing. That gap, plus 2.1 support, is the reason this mod exists.

## Interaction

- **Shortcut → window → Place → a blueprint in the cursor**, Upcycler Planner's model and for
  its reasons: the engine owns preview, rotation, flipping, undo and the build, and the mod
  handles no placement event.
- **Gated on the first technology that unlocks a requester chest**, read off the finished data
  (`prototypes/planner/gate.lua`): the cell feeds its machine from one, so the planner is useless
  before it. `logistic-system` in vanilla. The owner asked for "once logistics are researched".
- **Hotkey CTRL+SHIFT+A**, rebindable; Upcycler Planner has CTRL+U. The game's Confirm key (E)
  reaches Place through a linked input, with Upcycler Planner's chooser presumption.

## The window

The owner's ask, 2026-11-28: "more compact while keeping options accessible in 1 click … I
don't like the beacons line being too large in width … make it beautiful, the best possible".

- **One form in three sections, every option on it**: what the cell makes (item, machine),
  what it is built from (logistics, beacons, pole), how it is stocked (requests, stock limit),
  split by full-width lines. A row is a caption beside its controls, so a group costs one line
  instead of a caption line and a control line — where the height had gone. 1080p, 100% UI:
  about 477×720 before, 440×520 after. Rejected: Upcycler Planner's tabs, which put options a
  second click away.
- **Pickers stand in recessed slot strips** (`slot_button_deep_frame`), each with what belongs to
  it — machine and modules, beacon and module, the four logistics pieces: vanilla's inventory
  look, and grouping without more words.
- **The beacon counts are 56 px drop-downs**, room for two digits; vanilla's drop-down is at
  least 116 px, which made the beacon row the widest thing in the window. The two rule
  drop-downs share 136 px, so their number fields line up.
- **The one setting is a titlebar toggle**, one click where the Settings panel took two. It wears
  vanilla's white technology flask through a sprite of our own cropped to the flask
  (`prototypes/planner/sprites.lua`): a sprite-button fits the whole sprite into its box, and
  vanilla's flask fills only the middle half of its 64 px canvas, so it drew at half the size of
  the close cross beside it.
- **The item row names the item, or holds the hint**: the recipe list in its place when several
  recipes make the item, the grey "Pick an item" before one is picked. So the status area stays
  shut until there is a plan, then carries one line of numbers — footprint, real rate, quality
  chance — above the messages.
- **The ingredient amounts open from a pencil** beside the request number, pressed while the
  panel is up. With a chain they are grouped under each cell's item.
- **A chain shows in the first section as extra rows** (Production chains below): beside each
  machine its ingredients behind a ◀, under the machine one row per ingredient cell.

## The cell

- **One cell per item.** A blueprint holds one cell, or a production chain's cells side by side
  (below). Unrelated items in one blueprint stay deferred.
- **The inserter row is on the machine's south edge, the chest row under it**, left to right:
  input, output, quality output, left-aligned under the machine. The owner's blueprints all put
  the row on one edge; the player rotates or flips the blueprint for any other side.
- **The footprint is the bounding box**, so cells placed side by side abut exactly.
- **A machine too narrow for the row and taller than wide lies on its side** — under three tiles
  wide, rotatable, no fluid: Space Age's 2x3 crusher fits three inserters lying down and two
  standing. A fluid recipe keeps the turn its fluid input needs.
- **Extra inserter-and-chest pairs fill the bottom edge's free tiles first, then go up the left
  side, then the right** (owner's ask, 2026-11-27: "check if there is free space … maybe split
  between 2 requester chests"; "the best possible" for the full edge, 2026-11-28). A side holding
  pairs moves its beacon column two tiles out and widens the cell by two, and takes pairs only
  while every beacon on it still reaches from there. It bends the one-edge rule above only for
  cells that need it; a cell nothing caps keeps its 0.1.0 blueprint. The bottom stays grouped
  inputs, outputs, quality. The row above keeps its machine-relative positions, so the beacon
  counts and their drop-downs never depend on the inserters. When to add a pair is Throughput.

## Requests

- **One requester chest holds every item ingredient.** Sized by **crafts' worth** (default 4)
  or **minutes of crafting** (default 2, at the machine's real speed: its speed at quality and
  the modules' and beacons' speed effects, floored at a fifth), plus a per-ingredient amount set
  by hand. The owner asked for all three. The default of four crafts follows the owner's own
  blueprints, which asked for three and four.
- **Changing the rule or its number replaces every hand-set amount**, Upcycler Planner's
  Minutes rule; picking a different item drops them too, a quality change on the same item does
  not. A fluid-only recipe has no requester at all.
- **The Ingredient amounts panel follows every refresh**, because in minutes mode its defaults
  move with the pace — a module or beacon pick changes them. A field the player set by hand is
  never rewritten, since it may be the one being typed in.
- Requests come from buffer chests; **Trash unrequested items** is on by default.
- **Several ingredient chests each carry every ingredient: their share, never less than one
  load** — `max(ceil(T / n), min(T, load))`, a load being the inserter's hand capped by the
  item's stack. The owner chose it as "the best one possible" over copying the full request into
  every chest (doubles Minutes stock) and an even share with a warning (a second chest gains
  nothing below a load, which the default 4 crafts usually is). It never shrinks what a swing
  carries and never wastes stock; with one chest it is the 0.1.0 request exactly. The amounts
  panel shows the request one chest would make alone; with several, a small request copied into
  each makes the cell hold more. The too-big warning checks one chest's share.

## The quality split

- **Automatic whenever the cell's quality chance is above zero** — the machine's own base effect
  (a machine with quality built in), its modules, its beacons — and a tier exists above the
  recipe's quality.
  The owner chose automatic with an override.
- **The override is stored only while it disagrees**, and dropped when the automatic answer
  comes round to it, so the box follows the modules again. A refused plan has no automatic
  answer, so there the box keeps and shows whatever was clicked — unticking it is one way out
  of a refusal the split caused.
- **Filters are nameless**: the capped output takes `{recipe quality, "="}`, the second chest
  `{recipe quality, ">"}`, so one slot each covers any recipe (measured, `analysis/api.md` §2).

## The stock cap

- **The player's pick per plan: chest slots, network count, or no limit** (owner's call; no
  limit added because the owner's foundry and K2 blueprints have none).
- **Chest slots** writes `bar` on every recipe-quality output chest, the value shared out —
  `ceil(value / n)`, at least one slot each — default 2, the owner's number. Every one is capped
  or the uncapped one keeps filling; shared, so the cell still stops near the number the player
  set. `bar` counts open slots (`analysis/api.md` §1). Quality chests are never capped.
- **Network count** puts a logistic condition `product@quality < N` on every recipe-quality
  output inserter, default two stacks of the product; the count is network-wide, so each holds
  the same one. It warns that the inserter only runs inside a logistic network (Upcycler Planner
  measured an entity disabled outright outside one).
- A capped chest stops the machine, and with it the quality output too. Accepted: the cap is
  what the player asked for.

## Throughput

The design record, with the approaches weighed, is `throughput-design.md`; the engine numbers are
`analysis/api.md` §7–§8.

- **The plan knows the real rate**: the machine's pace capped by what its inserters move. The
  rate line shows it, and a warning names what still caps it — no room, plus a second line
  when a request below a load is part of it. The owner asked for the inserter bottleneck beacons
  cause to be detected (2026-11-27).
- **Everything comes from the prototypes and the force**, never a table: the swing from
  `get_inserter_rotation_speed` at the inserter's quality, the hand from its built-in bonus and
  the force's capacity research. The owner asked for modded inserters to be read (2026-11-27).
- **A role gets more inserters only while that raises the rate**: room goes to the role allowing
  the fewest crafts, one at a time, then every role is cut back to what the final rate needs, so
  no pair is placed that buys nothing. The anti-goal: a cell that grows without getting faster.
- **Minutes are priced at the machine's pace, not the capped rate**, so the request, the hand and
  the rate never loop into each other in a one-pass plan.
- **Robots are not modelled.** A chest is assumed to hold what it asks for; small requests at a
  fast pace run dry on robots first (`deferred.md`).
- **No control for the extras yet** (`deferred.md`): automatic, like the quality split, and the
  split box is already the way to free a tile on a full 3-wide edge.

## Fluids

- **A pipe row along the back, the cell's full width**, so cells side by side join into one
  line the player feeds from either end (owner's pick). The machine turns so one input faces
  north onto it (`proto.fluid_rotation`); vanilla machines need north, east (EM plant) or south
  (foundry, cryogenic plant).
- **Refused for now: recipes with a fluid product or two fluid ingredients** — an output box
  with nowhere to drain stalls the machine, and a second fluid needs a second row.

## Beacons

- **Beside and above** (owner's pick): side columns stacked from the machine's top, never
  taller than the machine plus its two rows; a row above spanning the cell (side columns
  included), above the pipe row when there is one, filled from the middle. Off until a beacon is
  picked; then every count defaults to as many as fit and reach, each a drop-down.
- **The beacon module defaults to the best researched speed module** — the owner's blueprints
  used speed. Upcycler Planner defaults to efficiency because a speed module's quality malus
  costs a quality loop; a mall cell is usually there for speed, and the player can pick.

## Power

- **An optional pole, off by default** (owner's call). Free tiles first; only when they leave
  something dark does the plan try more ground, in order: a column on the right, a row along the
  top, then both. Each is kept only if it powers strictly more than the best so far, and the
  ladder stops once nothing is dark. The row is for a short-reach pole under a full row of
  beacons above: from no free tile below that row does a medium pole's 3.5-tile supply reach
  both its ends, and a column on the right reaches only the right one.
- **A solver of its own**, `scripts/poles.lua`: a greedy cover kept connected, with a bridging
  step when the next useful spot is out of wire reach. Upcycler Planner's solver is tuned for
  thousands of columns and full of loop-specific structure; a cell has a few dozen tiles.

## Pickers

- **Every picker is always shown, each with its quality** (owner's call). Only what cannot apply
  hides: the recipe list with one recipe, the module picker on a machine with no slots, the pipe
  without a fluid. One per-player setting, **Show unresearched items**.
- **Machines**: assembling-machine type, electric or void energy, placeable, no fixed recipe;
  module slots not required. **Inserters**: one-tile reach, electric — belt-stacking stack
  inserters are allowed, since a cell has no belt. **Chests**: one-tile requester and passive
  provider containers.
- **The default recipe** among several: researched first, then one the chosen machine crafts,
  then the one named like the item (`analysis/api.md` §6).
- **A pick that no longer fits is dropped on the change that broke it** — a machine module after
  a machine or recipe change, a beacon module after a beacon change — so the picker falls back
  to its default instead of the plan refusing.

## Production chains

The owner's ask, 2026-11-28: "if I place electronic circuits it would also propose optionally
copper cables etc … a very beautiful compact and accessible ui to configure nested chains". The
design record, with the fresh-context check that corrected it, is `chain-design.md`.

- **Offered, off until ticked.** Beside each machine stand the ingredients a cell of their own
  could make — the item picker's catalogue — with their count per craft; a click ticks one in
  and it gets a row, its own ingredients offered in turn. Unresearched ones hide unless *Show
  unresearched items* is on or the chain already makes them. Fluids never: the pipe brings them.
- **Robots carry, every cell a normal mall cell** (owner's pick over direct insertion): the
  ingredient cell fills its passive provider, the consumer's requester asks for it as it always
  did, and the rest of the base can draw on it too.
- **A chain is a set**: the root plus every ticked item reachable from it through ticked items,
  one cell per item whatever uses it — one cable cell feeds circuits and advanced circuits alike.
  Unticking keeps the entry, so ticking again brings the cell back as it was; a new root item
  drops the chain, as it drops the hand-set amounts.
- **Extra rows** (owner's pick over cell tabs and a side panel, which put cells a click away):
  one row per ingredient cell under the machine row, in depth-first order under the first cell
  that uses it, its product stepped in 12 px per level in the caption column. A row holds the
  machine strip, ◀, the ingredient strip (wrapping past four, so the window grows down, not
  across) and, when several recipes make the item, an icon-only recipe drop-down. A ticked
  ingredient is lit with `yellow_slot_button` — `slot_button`'s own selected look is its hover
  look, so a hovered slot would read as ticked.
- **A cell owns its recipe, machine, modules and their qualities, and its own amounts**;
  everything else is the chain's, read from the root's choices — quality, logistics, beacons
  (counts clamped per cell), pole, request rule, stock rule. The network count and the split
  override are numbers about the root's item, so an ingredient cell keeps its defaults for both.
  A cell refused because a quality module meets a filterless chain inserter is left refused: the
  cell's module picker and the inserter are both a click away.
- **A row warns when it falls short**: its product turns red, the two rates on hover, one
  status line for all of them. Made is the product at the recipe's quality a minute — real
  rate, every copy, productivity with research, less the quality share (none at the top tier);
  taken is every user row's copies at their real rate times its recipe's amount; 1% of slack so
  two equal numbers never warn.
- **Counts: a row stands copies of its cell** (owner's ask the same night, after the first
  build: "configure ratios but also see and get the optimal ratios"). Every row has a count
  drop-down, ×1 to ×10, the root's included; it stays 1 until changed, so the owner's earlier
  pick of a warning over automatic cells still holds by default. Copies stand side by side in
  the row, each a whole cell.
- **The balanced count**: the root's count as set, then every other row the fewest copies that
  keep up with its users, users first — so each row is sized against its users' balanced
  counts, not their current ones. Green in each drop-down, the exact need in its tooltip;
  *Balance* sets every ingredient row to it and leaves the root alone. A line under the numbers
  names the balanced chain and holds the button, only while some count differs. The root is
  never "balanced": it sets the pace.
- **At most 32 cells in a blueprint**, else the chain refuses. Measured on 2.1.25: a fresh
  32-cell beaconed row plans in 164 ms (AM3) to 303 ms (EM plant), and 19 to 20 ms once the pole
  memo holds it. The pole solver keeps a flag per candidate and files consumers by column to get
  there — same answers, the goldens prove it.
- **The row**: walk order, bottom-aligned so the chest rows make one line. A free tile beside a
  pipe row unless both neighbours carry the same fluid at the same height; then the smallest gap,
  up to six more tiles, at which no beacon reaches another cell's machine — cells with side
  columns abut, a sided cell beside an unsided one stands three apart. Past six (modded reach)
  they abut and the chain warns.
- **One power network**: the pole ladder runs over the whole row, every cell's extra column or
  row at once, one solve each time — connected by construction, so copies' unjoined poles
  (`deferred.md`) cannot happen inside a chain. The last eight solves are kept in a module-local
  memo, since a keystroke replans the whole row; a client without it computes the same answer.
- **At most eight rows (items)**: the window's height, the blueprint's width and the pole solve
  all grow with the count, and Upcycler Planner crashed twice on unbounded growth. A cut leaves
  the toggle unlit and disabled with the reason, and the status says so.
- **Warnings**: the root's, then each other cell's behind its icon; four read the same for every
  cell (network cap, quality and build quality not researched, a slot cap with no effect) and
  show once per distinct text. A refusing cell refuses the chain, its icon saying which.
- **The blueprint wears the chain's first four products**, the root first.
- **A rebuild that grows the window lifts it** so Place stays on screen, from an estimate of the
  window without the chain; the rows scroll past what the screen leaves.

## Portal

- **The summary is one short sentence, and the README stays short** — "Pick an item and get a
  ready-made bot mall blueprint for it." The owner turned down the longer "Choose an item, the
  mod designs and gives you…" summary with its list of parts as too long and not human, and
  asked for a shorter README (2026-11-25). The same line is in `info.json` and in the locale's
  `[mod-description]`, which overrides it in game.
- **The shortcut icon and the thumbnail are one picture: the cell the planner builds** —
  vanilla's assembling machine 3 icon with a requester chest and a passive provider under it,
  input left and output right as in the cell's chest row (`prototypes/planner/icons.lua`); the
  thumbnail sets it on vanilla's blue slot frame
  (`assets/assembly-planner/thumbnail/make_thumbnail.py`). The owner hoped for an assembling
  machine 3. Picked 2026-11-28 from mock-ups at real button size over a corner badge (a
  requester, a passive provider or a logistic robot) and the machine alone: the chest row says
  bot mall, where a badge read as a second Upcycler Planner icon. Every layer stays inside the
  icon's own square, so the engine fits nothing smaller than designed.
- **The shortcut button is `style = "blue"`** (2026-11-28, the owner's ask). It was green, the
  colour of Upcycler Planner's and of vanilla's upgrade planner, and the owner kept clicking the
  wrong planner. The style takes only `default`, `blue`, `red` or `green`: red is the
  deconstruction planner's, grey is every toggle's, blue is vanilla's blueprint buttons — and
  this one hands over a blueprint. The olive machine also stands out on blue, where it sank into
  green.
- **README images are absolute `raw.githubusercontent.com` URLs to `images/` on `main`.** A
  relative image is uploaded into the portal gallery (`factorio-release` → the markdown images
  rule), and these are meant as illustrations. They only show once `images/` is pushed.
- **The portal page follows Upcycler Planner's where it applies**: GPLv3, category `utilities`,
  tags blueprints, logistic-network, logistics and manufacturing. Upcycler's circuit-network,
  storage and fluids tags fit a loop better than one cell. The gallery is `images/` in filename
  order, so the planner window leads.
- **The screenshots are built, not staged by hand**: `assets/assembly-planner/showcase/` stamps
  real cells from the planner's own plans in a dev client and photographs them, so a change to
  the cell shows on the next run. It needs a screen attached.

## Rejected

- **Forking Upcycler Planner and pruning it** (2026-11-25, owner's call between two designs):
  about 3,000 lines of loop structure and comments to scrub, and two copies of shared code to
  keep in step. Only generic pieces were lifted, each saying so where it lives.
- **For chains, 2026-11-28, all the owner's picks:** direct insertion between machines (a new
  layout family, and the intermediate lost to the base); cell tabs and a side panel for the
  window (every other cell a click away); counts balanced automatically by default (a wider
  blueprint unasked, and Upcycler Planner withdrew its own auto-balancing after it crashed the
  game) — the owner then asked for counts to set and a balance to apply, which is what stands.
