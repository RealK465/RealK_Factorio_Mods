# CLAUDE.md

Guidance for Claude Code when working in this repository.

This file is portable — repo conventions and the rules that apply in any clone. Machine-specific values (install paths, git identity, installed versions) live in `CLAUDE.local.md`, which is git-ignored. **Read both.** Detailed reference lives in skills; see the table at the end.

## What this repository is

A Factorio **mods directory** that is also a git repository. Factorio loads whatever is here at game start, so it is a working install first and a source tree second. Only the mods developed in this repo are tracked; everything the game or another author put here is ignored.

Living inside a real mods folder is what makes edits testable without a copy step — save a Lua file, restart the game, see it. Working elsewhere is fine, but the mods won't be live until symlinked or copied in.

**The mods folder it lives in is a dedicated dev install** — a standalone (DRM-free zip) copy of the game kept for development, whose `mods/` holds nothing but this repo. Not the copy anyone plays. That buys three things: the repo root stays clean of other people's mods, the game version stays pinned instead of updating underneath the work, and a standalone install keeps its own `.lock` and write-data, so validation and screenshot runs work no matter what else is running.

**Any install used for actually playing is out of scope** — never read, never written, never validated against, never named in a tool invocation. There is no path in this workspace that needs one. Paths for the dev installs are in `CLAUDE.local.md`.

(A clone that instead sits in a play install's mods folder — `%APPDATA%\Factorio\mods` on Windows, `~/Library/Application Support/factorio/mods` on macOS, `~/.factorio/mods` on Linux — still works; it just has to keep other authors' mods straight from the deliverables, which is what *Folder classes* below is for.)

On first use, copy `CLAUDE.local.md.example` to `CLAUDE.local.md` and fill it in. It is git-ignored and must stay that way — it is the one place machine paths and personal identity belong.

## Do not touch

- **Any install used for playing** — outside the repo and outside our remit. Don't read it, write it, stage from it, validate against it, or point `--mod-directory` or `fmtk mods` at it. A play save's mod list is not recoverable from git, and a run against the wrong install exits 0 and looks like a pass. Everything needed is in the dev installs; needing a play path means something is misconfigured.
- **`*.zip`** — other authors' packaged mods, if any are ever dropped in here. Never edit, unzip in place, delete, or rename them. Extracting a copy to a scratch directory to read is fine; it stays reference only.
- **`mod-list.json`**, **`mod-settings.dat`** — managed by the game. Editing these breaks the install. This is also why `--mod-directory` and `fmtk mods` must never be pointed at this folder.
- **Frozen vendor mod folders** — other authors' unpacked mods, present only so the game loads them. Don't read or modify them unless asked. **Not every untracked folder is one of these** — see *Folder classes* below, and note that this rule is enforced by `permissions.deny` in `.claude/settings.json`, not by this line alone.
- **Anything under the game install directory** — read-only reference. That is the folder one level above this repo: its `data/` and `doc-html/` are the authoritative API, and its `config/`, `saves/` and `script-output/` are the game's own. Read freely, write nothing.

## Folder classes

Factorio requires every mod folder to sit at this directory's root, so they cannot be grouped
into subfolders — a declaration is the only thing separating a deliverable from another author's
mod. There are five classes, and the trap is that **"not in git" does not mean "do not touch"**:
two of the five are edited routinely and tracked by nothing.

**A dev install collapses most of this.** With the repo alone in its mods folder, the only class
with members is Deliverable, plus whatever Reference material was deliberately put here. The
table still stands — a clone can land in a mixed folder, and material can always arrive later —
but if the classes read as elaborate for what is actually on disk, that is the arrangement
working. Which classes are populated **here** is in `CLAUDE.local.md`.

| Class | Ours | In git | Agent may edit | Ships to portal |
|---|---|---|---|---|
| **Deliverable** | yes | tracked | yes | yes |
| **Local mod** | yes | ignored | yes | never |
| **Patched vendor** | no | ignored | yes | never |
| **Frozen vendor** | no | ignored | **no** | n/a |
| **Reference** | no | ignored | read-only | n/a |

- **Deliverable** — what this repo exists to publish, plus `assets/` and the docs. Listed under
  *Mods in this repo* below.
- **Local mod** — our own mod, deliberately untracked because it exists for one playthrough and
  is never published. Editing it is normal work; committing it is not.
- **Patched vendor** — another author's mod, unpacked here and modified in place for a
  playthrough. Editable, but **never committed and never re-uploaded**: the source belongs to
  someone else, and a mod that ships no `LICENSE` cannot be redistributed at all. Only a diff of
  our own changes could ever be tracked, never the mod.
- **Frozen vendor** — another author's mod, present only so the game loads it.
- **Reference** — read-only study material: `exemples/`, and the game install. Read freely,
  never write.

The classes are portable and live here; **which** local folder is in which class is
machine-specific and lives in `CLAUDE.local.md`.

### Adding a folder

A new root folder has to be declared in up to four places — `.gitignore`, the `settings.json`
deny list, `CLAUDE.local.md`, and its own `CLAUDE.md` — and **which of them depends on the
class**. Getting it wrong is silent: it surfaces later as an accidental commit, or as an edit to
someone else's mod. The matrix and the reasoning are in
**`.claude/references/adding-a-folder.md`**; read it before adding one.

`.claude/scripts/check-folder-scope.ps1` verifies all four columns against what is on disk. Run
it after. It exists because the lists had already drifted once.

## Mods in this repo

Tracked unpacked folders are this repo's own mods:

- **`pure-modules-realk/`** — Pure Modules. A clean top tier of modules above tier 3, plus a wide-area beacon for them. **Published**, on both tracks: Factorio 2.1 from `main`, Factorio 2.0 from `legacy/2.0`. `git tag -l 'pure-modules-realk_*'` is the list of what has actually shipped. The name is not plain `pure-modules` because that portal name is squatted by a deleted account — see the mod's `CLAUDE.md`, Decided. Design notes there too.

- **`space-forge/`** — Space Forge. A large overhaul, in early development; nothing is implemented yet. **Unpublished**, Factorio 2.1 only. Ships as a pair with the mod below, and the two carry independent version sequences. Scope, art direction and compatibility stance are all still open — the mod's `CLAUDE.md` and `.ai-support/` are where decisions get recorded, and that folder covers the graphics mod too.

- **`space-forge-graphics/`** — Space Forge Graphics. The art half of the mod above: sprites, icons and sounds, **and no Lua at all**. Splitting art out keeps a balance patch small for players; the rule that keeps it working is that this mod never gains a data stage. Same pattern as `space-exploration-graphics` and `Krastorio2Assets`. **Unpublished.**

- **`upcycler-planner/`** — Upcycler Planner. A layout planner for quality upcycling loops, in the tradition of Mining Patch Planner and P.U.M.P.: pick an item and a target quality, and the mod designs the loop and drops it as ghosts. In development — the first version works end to end (shortcut → modal → Confirm → selection tool → ghosts), with researched-gated pickers and support for modded recyclers, and a permanent four-tier test suite (`tests/`, run via the `factorio-testing` skill) that
  settled the once-open eject question by measurement. **Published** since 2026-08-16, on both tracks: Factorio 2.1 from `main`, 2.0 from `legacy/2.0` (divergent files declared under *Git* below); `git tag -l 'upcycler-planner_*'` is the list of what has actually shipped. The only mod here with a hard `quality` dependency. The mod's `CLAUDE.md` and `.ai-support/` hold the decisions and the verified API findings — chiefly that ghosts must be placed one at a time, because blueprint strings only work in menu simulations.

<!-- - `my-mod-name_0.1.0/` — one-line purpose -->

A mod folder must be named `<name>` or `<name>_<version>`, matching its `info.json` exactly, or Factorio silently won't load it.

A mod folder may carry an **`.ai-support/`** directory: notes written for the agent rather than for the game. Read its `index.md` first when working on that mod — it is the mod's local context. Rules for what goes in one and how it is kept: *AI support folders* below.

A mod folder may also carry an **`images/`** directory: full-size screenshots for the mod portal's gallery. Tracked in git, since a shot belongs with the build it was taken from, but **it must be listed in that mod's `package.ignore`** — unlike `.ai-support/` it has no leading dot, so `fmtk package` sweeps it into the zip by default and ships megabytes of screenshots to every player. Name files for what they show, hyphenated, no spaces: the portal displays the filename. The mod's **`thumbnail.png`** is the opposite case — 144x144 at the mod root, and it *is* meant to ship.

## License

The whole repository — this repo's tooling, skills and docs, and every mod folder in it — is licensed under the **GNU General Public License v3.0 (GPLv3)**. The full text is at `LICENSE` in the repo root.

`info.json` has no license field, so the license lives in two other places instead:

- A copy of the same `LICENSE` file sits at the root of each mod folder (e.g. `pure-modules-realk/LICENSE`) so it ships inside the packaged zip — it isn't a dotfile, so `fmtk package` includes it automatically. Give every new mod folder its own copy; see the `factorio-mod-setup` skill's new-mod checklist.
- On the mod portal, the license is a separate field set on the mod's Details page, not derived from anything in the repo. When a mod is published, select the closest GPLv3 entry in the portal's license list. See the `factorio-release` skill — this happens at the same `fmtk details` / portal-edit step that already needs the repo owner's explicit per-release approval, so it carries no new authorisation rule of its own.

## Asset sources — `assets/`

Art *sources* — `.blend` scenes, textures, HDRIs, reference boards, anything that produces a sprite but is never loaded by the game — live at the repo root in **`assets/<mod-name>/`**. Only the exported PNGs and their `.lua` sidecars go into the mod's own `graphics/`.

```
assets/pure-modules-realk/beacon/beacon.blend      # source, tracked, never shipped
pure-modules-realk/graphics/entity/beacon/*.png    # export, shipped
```

Keeping sources outside the mod folder is what stops `fmtk package` sweeping a 200 MB `.blend` into the zip — the exclusion is structural, so `package.ignore` never has to be maintained for it. A root folder with no `info.json` is not a mod, so Factorio ignores `assets/` exactly as it ignores `exemples/`.

- **`assets/` is tracked, committed and pushed.** The sources are the work, not scratch — commit a `.blend` alongside the renders it produced so a sprite can be reproduced later.
- One folder per mod, named exactly as the mod's `name` from `info.json`.
- Subdivide as soon as a mod outgrows a handful of files, mirroring the `graphics/` path the renders land in: `assets/<mod-name>/entity/<thing>/`, `assets/<mod-name>/icons/`.
- Blender `.blend1`/`.blend2` autosaves are git-ignored — don't commit them.
- Throwaway test renders belong in the session scratchpad, not here.

## AI support folders — `.ai-support/`

Notes written for the agent rather than for the game: decisions and their reasons, verified API
findings, parked work. Tracked in git so they travel with the mod, invisible to both Factorio
and `fmtk package` (leading dot), and **nothing in them ships**. Optional per mod — but a mod
that has one follows the rules below, because the failure mode is silent. A broken prototype
fails loudly; a stale note is read as ground truth and reasoned from with full confidence.

**The contract with `CLAUDE.md`.** A mod's `CLAUDE.md` holds **rules to follow**;
`.ai-support/` holds **the record of why**. Each fact lives in exactly one of them. A
`CLAUDE.md` may state a decision as a one-line rule and point at the register for its reason —
it must not restate the reason. A rule without its reason is still correct to follow; a reason
without its rule is inert. `upcycler-planner/CLAUDE.md` → *The four technical facts worth not
re-deriving* is the shape to copy.

**Every file is exactly one genre, and the genre sets its lifecycle.** Mixing two in one file
is what makes a design doc unreadable: a register has to be edited in place and a journal must
never be edited, so a file that is both can satisfy neither.

| Genre | File | Lifecycle |
|---|---|---|
| **Index** | `index.md` — **required whenever the folder exists** | edited; one line per file, what is in it *and when to read it* |
| **Register** — what is true now | `decisions.md`, `deferred.md` | **edited in place**; a superseded entry is rewritten or deleted, never annotated |
| **Journal** — what happened | `journal.md` | **append-only, newest first**; entries may go stale, they are history — only a moved file path is ever repaired in place |
| **Evidence** — verified facts | `analysis/*.md`, with its own `index.md` | edited on re-verification; carries `verified_against` front matter, and every claim a confidence marker |
| **Subject design** | `<subject>-design.md` | edited; covers one thing — an entity, a feature |

**Four maintenance rules:**

- **Write the entry in the same session as the work**, exactly as `changelog.txt` is handled. A
  decision recorded later is a decision recorded wrong.
- **Superseding means rewriting the register and appending the story to the journal.** Never
  leave two live answers to one question.
- **Adding a file without indexing it is an incomplete change.** A stale `index.md` is worse
  than none.
- **Mark what is not verified.** Anything not confirmed against the installed `doc-html/` or
  `data/` says so in those words, and names the version it was checked at.

Anything that generalises past one mod belongs in a skill under `.claude/skills/` instead.

**`.claude/scripts/check-ai-support.ps1` is the check** — index shape, API and game-data
citations, evidence freshness, and every relative path in every tracked `.md`. Run it after
adding, moving or re-verifying a file. It cannot check whether a claim is still *true*, which is
what the same-session rule above is for. Working detail — front matter, the split rules, which
file a thing goes in — is in **`.claude/references/ai-support.md`**.

## Git

The whole mods directory is one repository. `.gitignore` inverts the usual default: everything the game or another author put here is excluded (`*.zip`, `mod-list.json`, `mod-settings.dat`, `exemples/`, third-party mod folders, `CLAUDE.local.md`, `--dump-data` leftovers), and only this repo's own mod folders are tracked.

**`CLAUDE.md`, `.claude/`, `.ai-support/` and `assets/` are tracked**, so project context, skills and art sources travel with a clone and survive a mod folder being split into its own repo. None of it reaches the mod portal — see the `factorio-release` skill.

- New third-party material dropped in here is **not** covered by the ignore list unless it is a `.zip` or an image inside a mod's `.ai-support/` (`*/.ai-support/*.jpg|png` are ignored — reference screenshots stay local). Anything else needs an explicit rule *before* committing, and never `git add -A` a directory that may hold third-party drops.
- A `.gitignore` negation cannot rescue a file inside an ignored *directory*. `exemples/**/README.md` stays ignored because `exemples/` itself is excluded.
- **Never run `git clean -x`** (or `-X`) here. Almost everything in this folder is ignored-but-precious: it would delete the downloaded mods, `exemples/`, and the game's own settings.
- **Annotated tags `<name>_<version>` mark published releases** — created and pushed only as part of an authorised release, never unprompted. No tag for the version in a mod's `info.json` means that version is still **open**: changelog work belongs in its existing top section, not a new one. The decision procedure is in the `factorio-release` skill.
- **The remote is private, so branch protection is off — temporarily**, since GitHub Free offers
  neither classic protection nor rulesets on a private repository (verified 2026-08-08). So
  **nothing on the remote refuses a direct push, a force-push or a branch deletion**, and the
  committing rule below is the entire floor rather than a second layer — where a mistaken
  force-push used to bounce, it now lands. The repo is expected to go public again; **restore
  protection as part of that same move**, not later, following
  **`.claude/references/branch-protection.md`**, which carries the exact field values the
  restoring PUT has to send.
- **`main` is Factorio 2.1; `legacy/2.0` is Factorio 2.0.** Both are long-lived trunks, not a
  branch and a one-off side branch: `legacy/2.0` is where *every* 2.0 build of *every* mod in
  this repo lives, the 2.0 counterpart of `main`, and it keeps that role until 2.1 goes stable
  and the 2.0 track stops getting work. It is checked out as a **worktree in the 2.0 dev
  install's own `mods/`**, so the 2.0 build is live and testable exactly as `main` is in the 2.1
  one. Path in `CLAUDE.local.md`; workflow in the `factorio-multiversion` skill.
- **Only a mod's own source may differ between the two branches.** `CLAUDE.md`, `README.md`,
  everything under `.claude/`, and each mod's own `CLAUDE.md` are kept identical on both, so a
  cherry-pick never conflicts on documentation. For Pure Modules the legitimately divergent
  files are `info.json`, `prototypes/modules/definitions.lua`,
  `prototypes/modules/recipe.lua` and `prototypes/beacon/beacon.lua` — nothing else. For
  Upcycler Planner they are `info.json`, `prototypes/planner/icons.lua`, `scripts/planner.lua`,
  `scripts/gui.lua` and `tests/planner_spec.lua` (the 2.0 track offers 212 upcyclable items
  where 2.1 offers 210, so the regression pin forks with it), plus `data-final-fixes.lua`,
  which exists **only** on `legacy/2.0` — the 2.0 shims live on that branch alone, never
  version-gated into `main`.
  `README.md` used to be on that list and no longer is: the 1.0.2/1.0.3 rewrite dropped the
  claim that a module's cost does not grow with its quality, which was the only 2.1-only
  sentence in it, so both tracks now ship the same file.
  **`changelog.txt` came off that list on 2026-08-07** and is kept identical too. The mod portal
  renders one changelog per mod, from the newest uploaded release, so a section living only on
  the other branch never reaches the website — the rule and the evidence are in the
  `factorio-multiversion` skill. **The two copies were reconciled on 2026-08-08**, in the
  1.0.6 / 1.0.7 pair: both branches now carry one identical file listing every released
  section, 1.0.0 through 1.0.7, each naming the game it targets. Verified against the live
  site — `GET /api/mods/<name>/full` returns all eight sections where it previously returned
  five. Published zips still carry whichever copy shipped with them and cannot be corrected;
  the reconciliation applies from 1.0.6 onward.
  `git diff main -- .` from the legacy worktree is the check: anything it lists beyond that set
  is drift, and the fix is to bring it back in line rather than to leave the branches guessing.

Git identity is set **locally only**, in `.git/config` — values in `CLAUDE.local.md`. Never `git config --global` it, and never let a real email address into a commit here. An empty `user.email` is the default position — git accepts it and commits are authored `Name <>`, publishing nothing; a forge `<username>@users.noreply.<host>` address is the fallback when something needs a syntactically valid one, and keeps commits linked to the account without exposing a real address.

### Committing — the rule

**Never `git commit` unless the repo owner asks for it in that specific instance.** The same
applies to `git push` and to anything that rewrites history (`commit --amend`, `rebase`,
`reset --hard`, force-push).

Approval is **per request, never standing**. A finished feature, a clean validation run, a
tidy working tree, or having been asked to commit earlier in the same session are none of them
authorisation for the next one. Doing the work is encouraged — edit, validate, stage, draft the
message. **Stop at the commit and ask.**

Leaving work uncommitted costs nothing here, which is what makes the rule cheap to keep: this
repository *is* the live mods directory, so uncommitted changes are already loadable in game.
Review happens against the working tree, not against a commit.

### Commit messages

[Conventional Commits](https://www.conventionalcommits.org/): `<type>(<scope>): <subject>`.

- **type** — `feat`, `fix`, `docs`, `refactor`, `perf`, `style`, `test`, `build`, `chore`, `revert`.
- **scope** — the mod's `name` from its `info.json`, e.g. `feat(elevated-smelting): ...`. Use `repo` for anything workspace-wide. Omit only when nothing fits.
- **subject** — imperative mood, lowercase, no trailing period, ≤ 72 characters. "add heat pipe recipe", not "Added heat pipe recipe."
- **body** — optional, after a blank line, and only when it explains *why*. Wrap at 72.
- **breaking changes** — `!` before the colon plus a `BREAKING CHANGE:` footer. Worth being strict about: renaming or removing a prototype breaks existing saves, which is exactly what a player needs warning about.

No emoji. Attribution trailers follow the agent's default — no override either way.

`changelog.txt` is the player-facing record and is written separately — never paste commit subjects into it, and never paste changelog prose into a commit.

## Publishing — the rule

**Never publish, upload, release, or edit portal details unless the repo owner asks for it in that specific instance.** The portal is public and append-only; a version number can never be re-used and there is no undo.

Approval is **per release**, never standing. "It's ready", "tests pass" or a finished changelog entry are not authorisation. Preparing a release is encouraged — bump, write the changelog, build the zip locally. **Stop at the upload and ask.**

Never run unprompted: `fmtk publish`, `fmtk upload`, `fmtk details`, or any direct call to a `mods.factorio.com/api` endpoint. Mechanics are in the `factorio-release` skill.

## Changelog upkeep

**Updating `changelog.txt` is part of the change, not a follow-up task.** After work a player could notice — prototypes, recipes, balance, graphics, locale, settings, bugfixes — adapt the mod's changelog in the same session, unprompted, through the `factorio-changelog` skill; its open-section rules and the `factorio-release` skill's "Published or open?" check decide whether entries join the open section or a new one opens. Purely internal work gets no entry: refactors with no visible effect, `.ai-support/`, `assets/`, skills and repo docs. In doubt whether a player would notice, they usually would — write the entry.

## Code style

Write it the way a Factorio modder would.

- Comments should earn their place: explain *why*, or flag a Factorio gotcha that would otherwise bite. Skip the ones that just restate the line below them.
- Keep them short — a line or two. No banner/divider comments, no docstring blocks on trivial functions.
- Match the surrounding file's naming and indentation. Vanilla Lua uses 2-space indent and `snake_case`.
- Prefer the plain solution. Don't add configuration, abstraction, or extension points nothing asked for.

## Factorio version and local API sources

Target is **Factorio 2.1**. The exact installed version and expansion set are in `CLAUDE.local.md`.

2.1 is still the experimental branch; **2.0 is stable and is what most players are on.** So the
working tree, every `info.json` and all new work stay on 2.1, and a mod may *additionally* ship a
2.0 build from a `legacy/2.0` branch. That second track is a nice-to-have — worth doing, never
worth delaying or compromising the 2.1 mod for. `factorio_version` names exactly one major
version, so this genuinely is two builds and two release tracks, not one zip that spans both.
Mechanics, numbering and what 2.1 broke: the `factorio-multiversion` skill. When 2.1 goes stable
the 2.0 track simply stops getting work.

The game install ships the authoritative API for the *exact installed version* — **prefer these over anything remembered, guessed, or found online.** Read them from the dev install, whose version is pinned; absolute path in `CLAUDE.local.md`, and the paths below are relative to its root (the folder holding `bin/`, `data/` and `doc-html/`, one level above this repo):

- `doc-html/runtime-api.json` — full runtime (control-stage) API: classes, events, defines, concepts.
- `doc-html/prototype-api.json` — full prototype (data-stage) API: every prototype and type.
- `doc-html/*.html` — the same docs, human-readable.
- `doc-html/auxiliary/*.html` — the non-API reference: `mod-structure.html`, `changelog-format.html`, `migrations.html`, `data-lifecycle.html`, `storage.html`. **Check here before searching the web** — the online wiki pages for mod structure and changelog format are redirect stubs now.
- `data/base/`, `data/core/`, `data/space-age/`, `data/quality/` — Wube's own prototype definitions and Lua. The best source of truth for how a real prototype is actually written.

The JSON files are large — grep them for the specific class/property rather than reading whole.

For what the local files don't answer (community conventions, modding-forum idioms), use **context7** and **web search**. Always state which Factorio version the information applies to; pre-2.0 answers are frequently wrong for 2.1.

## `exemples/`

Optional local reference material: extracted copies of existing mods, kept to check how things are actually done — code, graphics, asset layouts. Read-only; never edit. **When implementing something, check here first for an established pattern before inventing one.**

It is git-ignored, so it does not come with a clone; `CLAUDE.local.md` records what is present on this machine. If the collection carries its own `CLAUDE.md` tree, start at `exemples/CLAUDE.md` for the index, then the collection's own, then the individual package's for full detail.

**`flib` (`exemples/flib_0.17.2/`)** is a reusable utility-function library, not a mod to pattern-match against — check its `CLAUDE.md` before hand-rolling array/table helpers, spatial math (position/direction/bounding-box), or a GUI-building system. Its save/load-safe declarative GUI handler registry (`gui.lua`) is the reference pattern for any mod that needs GUIs and persistent state to survive save/load together. Not currently a dependency of any mod in this repo — read it for prior art, and add it to an `info.json`'s `dependencies` only if a mod is actually going to `require("__flib__...")` from it.

## Modding gotchas

The detail lives in the `factorio-mod-development` skill — it is Factorio knowledge rather than a
repo convention, and it is long. Three facts orient everything else:

- **Stages run in order**: `settings.lua` → `data.lua` → `data-updates.lua` → `data-final-fixes.lua` → (game starts) → `control.lua`. Data-stage code cannot see runtime state; control-stage code cannot see or modify prototypes. Only touch other mods' prototypes in `data-updates`/`data-final-fixes`.
- **2.0 renamed things.** `global` → `storage`, `game.<x>_prototypes` → `prototypes.<x>`, assorted `game.*` utilities → `helpers.*`. Code using the old names is pre-2.0 and needs porting, not copying.
- **Errors surface in `factorio-current.log`**, in the same user-data folder as `mods/` — for a standalone install that is the install root, one level above this repo. Read it when diagnosing a load failure; several failure modes are silent otherwise.

## Skills

Reference detail lives in `.claude/skills/`, tracked in this repo. **Invoke the relevant skill before doing the work, not after** — most of what they cover fails *silently* in Factorio. A mistyped `info.json` field, a folder name that doesn't match, a stray space in `changelog.txt`: none of these raise an error, they just produce a mod that quietly doesn't do what was meant. Recalling the rules from memory is how that happens; reading them takes seconds.

| Invoke | Before / when |
|---|---|
| `factorio-mod-development` | Writing or changing any mod Lua — prototypes, `control.lua`, `storage`, events, GUIs, performance, cross-mod compatibility, desyncs, debugging |
| `factorio-mod-setup` | Starting a mod; touching `info.json`, `locale/*.cfg`, `settings.lua` or `migrations/`; a mod that won't load or shows `Unknown key` in game |
| `factorio-changelog` | Writing or fixing **any** line of `changelog.txt` |
| `factorio-release` | Any version bump, `fmtk` command, packaging, or mod-portal question |
| `factorio-validate` | After editing prototypes and before packaging — proves the data stage loads |
| `factorio-testing` | Running or writing automated tests for a mod — the in-game factorio-test suite (headless or graphics), the pure host-Lua tier, or the static checkers |
| `factorio-graphics` | Any sprite, icon, `thumbnail.png` or Blender work — including *designing* an entity's look, which happens before any Blender step |
| `factorio-multiversion` | Anything touching a second game version — backporting to 2.0, the `legacy/2.0` branch, whether a change is safe there, or what 2.1 broke |

Roughly: `factorio-mod-development` is the code, `factorio-mod-setup` is the wrapper around it, the rest are the steps on either side.

Several tasks span two: a release is `factorio-release` **and** `factorio-changelog`; renaming a prototype is `factorio-mod-development` (the code), `factorio-mod-setup` (the migration) **and** `factorio-release` (the major bump); a backport release is `factorio-multiversion`, `factorio-validate` (against a 2.0 install) **and** both of the release pair. Invoke all of them.

**`.claude/references/` is the other half.** A skill covers Factorio knowledge and is invoked by
its description; a reference file is a *repo procedure* needed at one identifiable moment, linked
by name from the section of this file that owns it. It stays out of `skills/` on purpose — a
skill's description is itself preloaded every session, so filing a once-a-year procedure as a
skill would cost context permanently to save it occasionally.

| Reference | Read it when |
|---|---|
| `ai-support.md` | adding, moving or re-verifying a note in a mod's `.ai-support/` |
| `adding-a-folder.md` | adding a folder to the repo root — the four declaration lists and which class needs which |
| `branch-protection.md` | the remote goes public again, and protection has to be restored on both branches |
