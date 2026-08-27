# Robotics Reforged — journal

What happened, newest first. **Append-only**: a past entry is a record of what was true and
believed at the time, so it is never edited, even once superseded. What is true *now* lives in
`decisions.md`; the evidence lives in `analysis/`. Never ships (leading dot).

Entries are added in the session that produced them. When this file passes ~800 lines, move
everything older than the last release into `journal-archive/<year>.md` and leave a pointer.

---

## 2026-08-27 — the 2.0 track, opened the same day the scaffold was

The owner read the scaffold and reversed its 2.1-only call in one line: *"this mod should
support legacy 2.0."* So the mod forks onto `legacy/2.0` before it has any code at all.

**The original reasoning was backwards, and it is worth naming why** so it is not repeated on
the next new mod. The scaffold argued there was "no reason to carry a second build of a mod that
has not shipped a first". But 2.0 is the *stable* release and is what most players are on, so a
2.0 build is the one reaching the larger audience — and the cheapest possible moment to fork is
exactly this one, before there is code to keep in sync. The branch costs one file today.

**One divergent file: `info.json`** — `factorio_version` `"2.0"` and `base >= 2.0.0`. Declared in
the repo `CLAUDE.md` → *Git* beside Pure Modules' and Upcycler Planner's lists, and repeated as a
rule in `../CLAUDE.md` → *The 2.0 build*. Everything else is identical across the branches by the
repo rule: `README.md`, `changelog.txt`, the mod's `CLAUDE.md` and all of `.ai-support/`. The
README's *Requirements* line was the one player-facing claim that had to change — it promised
2.1 and now names both.

`changelog.txt` needed nothing. `0.1.0` is open on both branches with `Date: ????`, and which
track takes which number is a release-time decision under the repo's shared-sequence rule, not
one to pre-empt in a scaffold.

Nothing was ported, because there is nothing to port. The first real backport will be the first
one that has to be read against `2.1-breaking-changes.md`.

---

## 2026-08-27 — the mod is scaffolded, and the baseline is measured

The repo owner asked for a new mod, *Robotics Reforged*: rework Factorio's robot tiers and add
new ones where the progression needs them. The ask was explicitly for **structure only** —
folders, docs and wiring, organised the way `upcycler-planner` is, with a `.ai-support/` folder
of the same shape and a place for tests.

**Lua was written and then removed.** The first pass produced a working spine — `data.lua`,
`control.lua` with the factorio-test guard, and `prototypes/robots/` as a `definitions.lua` tier
table plus four files reading it. The owner cut it mid-session: *"do not add lua files yet, just
the base structure, like a scaffold."* So the shape survives as prose in `../CLAUDE.md` →
*Layout* and as the structure bullets in `decisions.md`, and the folders sit empty. Recorded
here because the design of those files was real work and the next session should not re-derive
it from nothing — the tier table as the single source of truth, and the vanilla retune belonging
in `data-updates.lua`, are both decisions that came out of writing it.

**The portal name is free but not ours.** `GET /api/mods/robotics-reforged` → 404 on 2026-08-27,
method sanity-checked against `mining-patch-planner` → 200. Checked this early because
`pure-modules` was lost to a squat, and a portal name stays taken after the account behind it
goes. It is claimed by the first upload and by nothing else, so it needs re-checking immediately
before publishing.

**One measurement changed how the design has to be approached.** Worker-robot research is
force-wide: `worker-robot-speed` and `worker-robot-storage` lift every robot the force owns, so
a tier whose only distinction is a higher base number stops being a distinct thing as research
accumulates. The two prototype fields that resist this are `max_speed` and
`max_payload_size_after_bonus`, both caps that include bonuses — and **neither is set on either
vanilla robot**. That turns "what separates a tier" from a numbers exercise into a real design
choice, and it is written up as such in `deferred.md`. The full baseline, including the finding
that Space Age relocates the infinite speed technology from level 6 to level 7, is in
`analysis/vanilla-robots.md`.

**Decisions taken, all of them about identity rather than design:** the name and title, the
`rbr-` prototype prefix (`rr-` rejected as too generic for a global namespace, `robotics-` as
indistinguishable from vanilla's own technology), `base >= 2.1.0` with an optional `space-age`
for load order, **no Space Age feature flags** — the opposite call from `upcycler-planner`, and
for the opposite reason: this mod works in vanilla and that one does not — and 2.1 only, with no
`legacy/2.0` build for a mod that has not shipped a first build. Reasons in `decisions.md`.

**Everything else went to `deferred.md`**, which is unusually long for a new mod because it
holds the entire design: tier count, what separates a tier, whether vanilla's two are retuned,
where the tiers sit in a tech tree that has to work with and without Space Age, roboports,
quality, a portal survey of the existing robot mods, art, the thumbnail, and the test suite. No
entry in it is a decision; that is the point.

**Not done, and named so it is not mistaken for done:** no `thumbnail.png`, no tests, no
survey of competing mods, and no measurement of what quality does to a flying robot — that last
one is flagged UNVERIFIED in `analysis/vanilla-robots.md` §7 and should be settled before the
tier axes are.
