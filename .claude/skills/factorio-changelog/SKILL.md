---
name: factorio-changelog
description: Use whenever a Factorio mod's changelog.txt is written, edited, reviewed or debugged — adding a release section, wording entries for players, or working out why a changelog doesn't render in the in-game mod browser. Factorio's parser is exact about separators and indentation and fails silently when they're wrong, so consult this before writing even one changelog line rather than working from memory.
---

# `changelog.txt`

The player-facing record, shown in the in-game mod browser. The format is strict and the parser is unforgiving, but **the failure is silent** — errors land in `factorio-current.log` and the changelog simply doesn't render. Verify rather than assume.

The authoritative rules for the installed version are in `doc-html/auxiliary/changelog-format.html` under the game install (`CLAUDE.local.md` has the path), and `data/changelog.txt` is the format as Wube writes it. Check those before the web — the online wiki page is a redirect stub now.

## Shape

```
---------------------------------------------------------------------------------------------------
Version: 0.2.0
Date: 2026-08-05
  Features:
    - Added the heat exchanger tower.
  Bugfixes:
    - Fixed that the smelter kept consuming fuel while output was full.
    - Fixed a multiline entry, which wraps onto continuation lines
      indented by exactly six spaces.
---------------------------------------------------------------------------------------------------
Version: 0.1.0
Date: 2026-07-30
  Major Features:
    - Initial release.
```

## Rules, exactly

- Separator is **99 dashes**, no more, no less.
- The line straight after a separator must be `Version: ` (with the space) and must not be empty. `major.minor.sub`, each 0–65535; `0.0.0` is invalid; no two sections may share a version.
- `Date: ` is optional and its content is unrestricted. Vanilla and SE write `21. 07. 2026`; K2 writes `2026-06-28`. **Use ISO `YYYY-MM-DD` and stay consistent** — a mixed-format changelog looks unmaintained, and `fmtk datestamp` defaults to exactly this format. One non-date value carries meaning here: **`Date: ????` marks the open, unpublished section** — `fmtk version` writes it, and it resolves to a real date only during an authorised release, never before.
- Category lines: **exactly two spaces**, ending in a colon.
- Entry lines: **exactly four spaces, a dash, a space**. Continuation lines: **exactly six spaces**.
- No tabs. No trailing whitespace. Both produce misleading errors.
- Blank lines are skipped everywhere except immediately after a separator, where one is an error.
- No exact-duplicate entries within the same version and category — and individual lines of a multiline entry count for this too.
- Newest version at the top.

## Categories

Recognised and sorted ahead of the "All" tab: `Major Features`, `Features`, `Minor Features`, `Graphics`, `Sounds`, `Optimizations`, `Balancing`, `Combat Balancing`, `Circuit Network`, `Changes`, `Bugfixes`, `Modding`, `Scripting`, `Gui`, `Control`, `Translation`, `Debug`, `Ease of use`, `Info`, `Locale`, `Compatibility`.

Anything else is accepted but sorts last. Prefer `Bugfixes` / `Changes` / `Features` — that trio covers most releases.

## Writing entries

- Describe the **player-visible effect**, not the code change. "Fixed that steel pumps could not connect to fluid wagons", not "corrected fluid_box connection index".
- Full sentences, capitalised, ending in a period. Bugfixes conventionally start with "Fixed that …".
- Prefix entries that only apply with another mod active: `- [space-age] Blacklisted molten metals from the flare stack.`
- This is a different document from the git log, with a different audience. **Never copy a commit subject into it, and never copy changelog prose into a commit.**

## The open section

While a version has never shipped, its section is **open**: stamped `Date: ????`, and no
`<name>_<version>` git tag exists for it. The check, the tag convention and the read-only
portal fallback live in the `factorio-release` skill, under "Published or open?" — **run that
check before touching this file**, because it decides everything below:

- New work goes **into** the open section, merged into its existing categories — never into a
  second section. The section describes everything between the last published release and the
  next one, however many unrelated sessions produced it.
- After appending, check the open version number still fits the whole unreleased delta
  (`git diff <last-tag> -- <mod>/`). If it has outgrown its bump, **propose** the re-grade —
  section header and `info.json` together — and wait. Never re-grade unasked.
- A new section is opened only on top of a **shipped** one, and starts as `Date: ????`.

## Release coupling

**Every released version needs a section, and the top section's version must match `info.json`.** Add the entry in the same change that bumps the version — see the `factorio-release` skill for the full sequence.

### Two release tracks

A mod with a second release track has a second changelog, on its branch: each zip carries its
own file and a player only sees the one they installed.

- **Every published version gets its own section** — including a release whose only change is
  the game it targets, which is a normal thing to ship. Numbers are drawn from one sequence
  shared by both tracks (`factorio-multiversion` → Version numbering), so the number alone
  never tells a player which game a release was for. Say it: `- Releasing 1.0.0 for Factorio
  2.1.` Do not renumber an existing section to stand in for the new release — the version that
  shipped under the old number is real and keeps its own record.
- **Only the first of a paired release carries the detail.** When one change ships to both
  games it goes out as two releases, 2.0 first with the full entries, and the 2.1 release that
  follows gets a section that says only which build it is — `- Version 1.0.2, rebuilt for
  Factorio 2.1.` Copying the entry list into both is the mistake to avoid: no player sees both
  sections, so the duplicate buys nothing and the two files drift apart as soon as either is
  edited. Pure Modules 1.0.2 / 1.0.3 shipped that way on 2026-08-07 and cannot be corrected.
  Full rule, and the opposite case of a fix backported later: `factorio-multiversion` →
  Changelog across two tracks.
- **A section must describe the build that actually shipped under that number**, not the
  mod in general. Where the tracks genuinely differ, the entry belongs to whichever release
  introduced it and must be *absent* from the other. Pure Modules 1.0.0 (Factorio 2.0) cannot
  hold module penalties flat across quality — the properties are 2.1-only — so that entry sits
  in 1.0.1 (Factorio 2.1) alone. Repeating it in 1.0.0 would promise 2.0 players a feature
  their build does not have.
- Check the mod's `README.md` for the same claim before shipping it: it becomes the portal
  description, so a 2.1-only promise left in it is published against a 2.0 build.
- A backported fix earns an entry on both tracks, worded the same, under each track's own
  version number.

See `factorio-multiversion`.

## Before calling it done

Re-read the file and check the four things that fail silently: 99 dashes exactly, 2/4/6-space indents, no tabs, no trailing whitespace. If the mod has been loaded since, grep `factorio-current.log` for changelog errors.
