# Journal — Assembly Planner

Dated sessions, newest first. Append-only: entries are history and are never edited.

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
