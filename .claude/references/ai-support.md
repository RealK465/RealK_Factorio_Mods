# `.ai-support/` — the working detail

Loaded on demand from the repo `CLAUDE.md` → *AI support folders*, which carries the standing
rules: the contract with `CLAUDE.md`, the genre table, and the four maintenance rules. This file
holds the parts you only need while actually adding, moving or re-verifying a note.

Start a new folder from `.claude/templates/ai-support-index.md`.

## Why `index.md` and not `README.md`

A mod's own `README.md` is player-facing and becomes the portal description verbatim via
`fmtk details --readme`. Letting a README inside `.ai-support/` mean something entirely
different from the one at the mod root is a live trap, not a style preference. The subfolder
indexes follow the same rule: `analysis/index.md`, and never a README beside it.

(Both spellings are deliberately absent from this paragraph as paths — `check-ai-docs.py`
resolves every backticked `.md` path it finds, and cannot tell a counter-example from a claim.
Write a forbidden name as prose, not as a path.)

## Size, and when to split

Size is not the axis to split on. A 600-line file costs roughly 1% of the context window to
read, so splitting to make files shorter buys nothing.

There are **two** axes, and they answer different questions:

- **Genre decides how a file is maintained.** A register is edited in place, a journal is never
  edited, evidence carries the version it was checked at. A file that is two genres can satisfy
  neither, which is the original reason for splitting at all.
- **Concept decides which file a fact goes in.** Registers are named for the subject they own —
  balance, art direction, identity — not for their lifecycle.

A small mod needs one register and can name it `decisions.md` without harm; the template does
exactly that. **A large mod must not.** An overhaul accumulates more decisions than one file can
hold, and a catch-all named after its lifecycle rather than its subject is where facts go to be
lost — by the time it is obviously too big, nobody knows which half to move. `pure-modules-realk`
has had `balance.md` from the start and never needed a decisions file; an overhaul in this repo
splits into identity and art-direction registers and states the rule in its own index.

(Register names are written here as prose rather than as paths on purpose: this file is kept
identical on `main` and `legacy/2.0`, and a mod that exists on only one branch would make a
backticked filename dangle on the other.)

Three habits that keep a concept split honest:

- **A concept file owns its subject completely** — decided, required-but-not-done, open and
  rejected together. They are the same conversation at different stages, and separating them by
  stage recreates the catch-all one level down.
- **Do not stub.** A concept file with nothing decided in it reads as though the question was
  considered. Add it when it has content.
- **Park orphan questions with a forwarding address.** A question whose concept has no file yet
  goes in the open list of the register nearest to it, naming the file its answer will become.
  That list is the mod's concept map, and it is what stops an answer landing back in a bucket.

**`journal.md` and `analysis/` keep their generic names.** For those two the lifecycle *is* the
subject — one is "what happened", the other "what was measured" — and `analysis/` is load-bearing
besides: `check-ai-docs.py` keys the `verified_against` freshness check on that literal path, so
renaming it silently switches the check off. Divide inside `analysis/` instead, one file per
topic.

When `journal.md` passes ~800 lines, move everything older than the last release into
`journal-archive/<year>.md` and leave a pointer in the index. That is the only size rule.

## Front matter on evidence files

```yaml
---
verified_against: 2.1.14
verified: 2026-08-16
---
```

**Version, not elapsed time.** The dev install is pinned deliberately and only moves when
someone replaces it by hand, so "the install is now 2.1.15 and this file was checked at 2.1.14"
is the signal worth having. A review calendar would just be noise on a repo worked in bursts.

Required on `analysis/**/*.md` (the index excepted). Optional elsewhere. **Dual-track content is
the exception**: `pure-modules-realk` ships from both `main` and `legacy/2.0`, and everything in
its `.ai-support/` is kept byte-identical across the two, so nothing there claims a single game
version.

## The checks

**Run `.claude/scripts/check-ai-support.ps1`** after adding, moving or re-verifying a file. It
runs the structural checks, then hands off to `check-ai-docs.py`. Together they are what gives
these notes an enforcement mechanism — a claim that has drifted from the game *breaks* instead
of sitting there being quietly believed.

| Check | Catches |
|---|---|
| index shape | a file with no row, a row naming a file that is gone, an untracked note, a `README.md` where an `index.md` belongs |
| API citations | `LuaSurface.create_entity` no longer resolving against the install's `runtime-api.json` |
| game data | `data/recycler/data.lua:109` pointing at a file or line that moved — line numbers shift on nearly every game update |
| freshness | an evidence file whose `verified_against` no longer matches the installed version |
| paths | any relative path in any tracked `.md` that matches nothing on disk |

Both scripts **self-locate to whichever install holds the repo**, exactly as `validate.ps1`
does, so running them from the legacy worktree checks against 2.0 rather than 2.1.

What they **cannot** check is whether a row is still *true*. Nothing can — which is why the
same-session rule in `CLAUDE.md` carries the weight the automation can't, and why a claim that
was never verified has to say so in those words rather than being left to look verified.

Baseline on 2026-08-19, at 2.1.14: 38 API citations, 14 game-data citations, 9 evidence files
and 155 paths, all clean. The checks were proved against a planted negative control — seven
deliberate defects, one of each kind, all caught.

## Which file does a thing go in?

- Changes **what a mod does or is** → rewrite the bullet in the register that owns that concept
  (`decisions.md` on a small mod; the named concept file on a large one), then append the session
  to `journal.md`. Both, not either.
- Belongs to **a concept that has no register yet** on a large mod → create it, named for the
  concept, and move the question out of whichever open list was parking it.
- **Cut for scope** → `deferred.md`, with enough context to pick up cold.
- A **fact about the engine**, verified or not → `analysis/`, with its confidence marker and the
  version it was checked at.
- A **rule the next agent must follow** → the mod's `CLAUDE.md`, as one line, pointing at the
  register for the reason. Never restate the reason there.
- **Generalises past one mod** → a skill under `.claude/skills/`, not here.
- A **repo procedure needed at one identifiable moment** → `.claude/references/`, like this file.
