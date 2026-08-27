# CLAUDE.md — Robotics Reforged

Mod-local guidance. The repo-wide rules in `../CLAUDE.md` still apply; this file only covers
what is specific to this mod. `package.ignore` keeps it out of the shipped zip.

## What the mod is

A rework of Factorio's robot progression. Vanilla ships exactly two worker robots — one
logistic, one construction — and every improvement after that is force-wide research that lifts
both at once. This mod turns robots into something a player builds through: retuned vanilla
robots, and new tiers above them where the progression needs one.

**It is a scaffold, not a mod yet.** Created 2026-08-27. There is no Lua in it, no prototype has
been defined, and none of the design is settled — how many tiers, what separates them, whether
vanilla's two are retuned at all. `.ai-support/deferred.md` owns every one of those questions;
`.ai-support/decisions.md` holds the few things that *are* settled, which is identity and
packaging. Do not infer a design from this file; there isn't one to infer.

**Nothing has shipped, on either track.** No `robotics-reforged_*` git tag exists, so `0.1.0` is
**open** — new work joins its existing changelog section rather than opening a second one. Run
the `factorio-release` skill's "Published or open?" check rather than trusting this line.

**It targets both game versions** — Factorio 2.1 from `main`, Factorio 2.0 from `legacy/2.0`,
forked from the scaffold onward. See *The 2.0 build* below.

## The two technical facts worth not re-deriving

**Worker-robot research is force-wide and applies to every robot equally**, so research alone
cannot distinguish one tier from another — and at maxed research it actively erases the
distinction. The two prototype fields that survive it are `max_speed` and
`max_payload_size_after_bonus`, which cap a robot *including* bonuses. Any tier design that
means to stay meaningful in the late game hangs off those two. Measured baseline, both fields'
exact semantics and vanilla's own numbers: `.ai-support/analysis/vanilla-robots.md`.

**A roboport takes electric or void power and nothing else**, so it cannot be given a burner and
cannot be switched off by script either. Anything a single prototype refuses — a fuel-burning
roboport, a roboport welded to something that is not one — is built as a composite: one visible
parent entity plus hidden children at the same position, created and destroyed by script. Do not
re-derive the pattern or its lifecycle events; they are written up with a working example in
`.ai-support/analysis/composite-entities.md`.

## Dependencies

`["base >= 2.1.0", "? space-age"]` on `main`; the `legacy/2.0` build floors `base` at `2.0.0`.

The optional Space Age dependency buys load order and nothing else — it costs nothing when the
expansion is absent, and it is what makes a later `data-updates.lua` safe to point at Space Age
prototypes. **No Space Age feature flags are declared**, and none should be added unless the mod
becomes worthless without the expansion; read `feature_flags` at the data stage instead. Reasons
in `.ai-support/decisions.md`.

## The 2.0 build

**`main` carries no 2.0 code — never version-gate 2.0 compatibility into it.** The repo forks
and never gates; the reason is in `.ai-support/decisions.md`. The port lives entirely on
`legacy/2.0`, checked out as a worktree in the 2.0 dev install's own `mods/` so the 2.0 build is
live and testable exactly as `main` is in the 2.1 one (path in `CLAUDE.local.md`).

**The divergent file is `info.json`, and so far it is the only one** — `factorio_version` `"2.0"`
and `base >= 2.0.0` there against `"2.1"` and `>= 2.1.0` here. Declared in the repo `CLAUDE.md` →
*Git*; **add to that declaration the moment a second file forks.** Everything else is kept
identical on both branches, `README.md`, `changelog.txt`, this file and all of `.ai-support/`
included, so a cherry-pick never conflicts on documentation. `git diff main -- .` from the
legacy worktree is the check: anything beyond `info.json` is drift.

A cherry-pick that touches a forked file is rewritten by hand, never merged blind. Before
backporting anything, read it against the `factorio-multiversion` skill's
`references/2.1-breaking-changes.md` — a 2.1-only property does not error on 2.0, it is silently
ignored, which is the failure mode that costs a release.

**Validate with the script next to the mod, not with `-FactorioPath`.** The legacy worktree
carries its own copy of the validate skill, sitting in the 2.0 install, so running that copy
self-locates to 2.0. Running `main`'s copy against a legacy mod validates it against the wrong
game and exits 0 anyway.

## Naming

**Every prototype this mod defines is prefixed `rbr-`.** None exist yet, so the first one sets
the precedent for the rest. Prototype names are one flat global namespace shared with every
other mod and a collision there is silent, which is the whole reason for the tag.

Following `pure-modules-realk` and `upcycler-planner`, the split is:

- **Prototypes** use the short tag: `rbr-`.
- **Settings and locale mod-level keys** use the **full** `robotics-reforged` — settings are
  listed to players beside other mods' settings, where a three-letter tag means nothing.

**The tag is cheap to change now and expensive later**: from the first release onward a rename
costs a migration file and a major version bump. Which tags were rejected: `.ai-support/decisions.md`.

## Layout

Nothing below the four root files exists yet. This is the shape the code is expected to take —
grouped by **content**, not by prototype kind, following the community convention in the
`factorio-mod-setup` skill and the two sibling mods in this repo. Create a folder when there is
something to put in it, not before.

```
info.json                           identity, version, dependencies      [exists]
changelog.txt                       player-facing history                [exists]
LICENSE                             the repo root's GPLv3 text, verbatim [exists]
README.md                           the portal description               [exists]
CLAUDE.md                           this file                            [exists]

data.lua                            entry point; requires the prototype files
data-updates.lua                    where retuning VANILLA's robots goes -- they exist only
                                    after base's own data.lua has run
settings.lua                        mod options, if any are ever wanted
control.lua                         a data-only mod needs none, EXCEPT that the test framework
                                    is reached through it -- see Testing below
prototypes/robots/                  definitions.lua as the single source of truth (one table
                                    per tier, pure Lua so the pure test tier can load it), then
                                    entity/item/recipe/technology reading it and adding nothing
                                    of their own
tests/                              the suite; registered in control.lua behind the
                                    active_mods guard, excluded from the zip by package.ignore
  pure/                             specs that run on host Lua too -- the tier table's shape
  support/                          shared fixtures
locale/en/robotics-reforged.cfg     every player-visible string          [exists]
migrations/                         none, and none needed until a prototype is renamed
images/                             portal gallery material, never shipped
.ai-support/index.md                the map — read it first
.ai-support/decisions.md            what is settled, and why
.ai-support/deferred.md             the open design questions, each with enough context
.ai-support/journal.md              dated sessions, newest first
.ai-support/analysis/               the evidence: the measured vanilla robot baseline
```

No `graphics/`. Art is deferred — a new tier is expected to wear vanilla's sprites until real
art is decided on (`.ai-support/deferred.md`).

**`require` paths use dots, mod-wide** — a readability convention, not a correctness one, and
the same one both sibling mods use.

## Testing

A suite is expected here from the first prototype, following the `factorio-testing` skill and
`upcycler-planner`'s `tests/` as the reference shape. Two things to get right when it lands:

- **Add `"tests/**"` to `package.ignore`** — already done in `info.json`. A bare `"tests"` glob
  matches nothing and would ship the suite to every player, silently.
- **The framework is reached through `control.lua`**, behind an `active_mods["factorio-test"]`
  guard, even though this mod otherwise needs no control stage. The guard **replaces** the mod's
  own `on_init`, so it must call the real init itself if one ever exists.

The tier table is the natural home of the pure tier: keep it free of `data`, `util` and every
game global, and a host interpreter can check every tier's shape in well under a second.

## Working here

- Commit scope is `robotics-reforged`. Repo-wide changes use `repo`.
- **Never commit, push or publish unprompted** — repo `CLAUDE.md`, and approval is per request.
- **`README.md` is the portal description**, uploaded verbatim by `fmtk details --readme`. It is
  player-facing: write for a glance, and never restyle wording the repo owner wrote.
- `LICENSE` at the mod root is the repo root's GPLv3 text, copied verbatim. Keep the two in sync
  if the root copy is ever refreshed.
- **Design decisions go in `.ai-support/decisions.md` as they are made, with the reason, and the
  session that produced them in `.ai-support/journal.md`.** Both, not either — the repo
  `CLAUDE.md` → *AI support folders* has the rules. Anything that generalises beyond this mod
  belongs in a skill under `.claude/` instead.
- **Always pass `--check-unused-prototype-data` when validating.** It is the only thing that
  catches a misspelled prototype property, which the loader ignores rather than rejecting, and
  the exit code stays 0 either way — so the log has to be read. See the `factorio-validate` skill.
- **Retuning vanilla's robots changes an existing save's balance**, and a player mid-game will
  notice. That is a `changelog.txt` entry every time, and it is the kind of change worth a mod
  setting rather than a silent override.

## Decided

The rules, in short. **Every reason lives once, in `.ai-support/decisions.md`** — read it before
re-opening any of these, and don't restate a reason here.

- Name `robotics-reforged`, title *Robotics Reforged*. The portal name was checked free on
  2026-08-27 and is **not** reserved by that; it is claimed only by the first upload.
- Prototype prefix `rbr-`; settings and locale mod-level keys use the full name.
- `base >= 2.1.0` hard on `main` (`>= 2.0.0` on `legacy/2.0`), `? space-age` optional, **no
  feature flags**. Space Age content is reached by reading `feature_flags` at the data stage,
  never by declaring a `*_required`.
- Both tracks: Factorio 2.1 from `main`, 2.0 from `legacy/2.0`. No 2.0 code on `main` — the port
  is forked files on the legacy branch, `info.json` alone so far, declared in the repo
  `CLAUDE.md` → *Git*.
- Version starts at `0.1.0`, from one sequence shared by both tracks.
- New tiers are added in `data.lua`; retuning vanilla's two happens in `data-updates.lua`.
- One `definitions.lua` tier table is the single source of truth, and the four prototype files
  read it rather than defining anything themselves.

## Open questions

**`.ai-support/deferred.md` is the single owner** of open and parked work, so the two lists
cannot drift apart. Everything about the actual design is there — the tier count, what separates
one tier from the next, whether vanilla's robots are retuned, roboports, art, and the
research-cap problem the technical fact above describes.
