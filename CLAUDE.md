# CLAUDE.md

Guidance for Claude Code when working in this repository.

This file is portable — repo conventions and the rules that apply in any clone. Machine-specific values (install paths, git identity, installed versions) live in `CLAUDE.local.md`, which is git-ignored. **Read both.** Detailed reference lives in skills; see the table at the end.

## What this repository is

A Factorio **mods directory** that is also a git repository. Factorio loads whatever is here at game start, so it is a working install first and a source tree second. Only the mods developed in this repo are tracked; everything the game or another author put here is ignored.

Cloning into the mods directory — `%APPDATA%\Factorio\mods` on Windows, `~/Library/Application Support/factorio/mods` on macOS, `~/.factorio/mods` on Linux — is what makes edits testable without a copy step. Working elsewhere is fine, but the mods won't be live until symlinked or copied in.

On first use, copy `CLAUDE.local.md.example` to `CLAUDE.local.md` and fill it in. It is git-ignored and must stay that way — it is the one place machine paths and personal identity belong.

## Do not touch

- **`*.zip`** — other authors' mods, downloaded for play runs. Never edit, unzip in place, delete, or rename them. Reading one (e.g. extracting to a scratch directory) is fine as reference only.
- **`mod-list.json`**, **`mod-settings.dat`** — managed by the game. Editing these breaks the install. This is also why `--mod-directory` and `fmtk mods` must never be pointed at this folder.
- **Unpacked third-party mod folders** — any folder here that isn't one of this repo's own mods. `CLAUDE.local.md` lists the ones present locally. Don't read or modify them unless asked.
- Anything under the game install directory — read-only reference.

## Mods in this repo

Tracked unpacked folders are this repo's own mods:

- **`pure-modules-realk/`** — Pure Modules. A clean top tier of modules above tier 3, plus a wide-area beacon for them. Nothing published yet. The name is not plain `pure-modules` because that portal name is squatted by a deleted account — see the mod's `CLAUDE.md`, Decided. Design notes there too.

<!-- - `my-mod-name_0.1.0/` — one-line purpose -->

A mod folder must be named `<name>` or `<name>_<version>`, matching its `info.json` exactly, or Factorio silently won't load it.

A mod folder may carry an **`.ai-support/`** directory: guides, notes and design docs written for the agent rather than for the game. Read it when working on that mod — it is the mod's local context. It is tracked in git so it travels with the mod, and invisible to both Factorio and `fmtk package` (leading dot). Never put anything the mod needs to run in there — nothing in it ships.

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

## Git

The whole mods directory is one repository. `.gitignore` inverts the usual default: everything the game or another author put here is excluded (`*.zip`, `mod-list.json`, `mod-settings.dat`, `exemples/`, third-party mod folders, `CLAUDE.local.md`, `--dump-data` leftovers), and only this repo's own mod folders are tracked.

**`CLAUDE.md`, `.claude/`, `.ai-support/` and `assets/` are tracked**, so project context, skills and art sources travel with a clone and survive a mod folder being split into its own repo. None of it reaches the mod portal — see the `factorio-release` skill.

- New third-party material dropped in here is **not** covered by the ignore list unless it is a `.zip` or an image inside a mod's `.ai-support/` (`*/.ai-support/*.jpg|png` are ignored — reference screenshots stay local). Anything else needs an explicit rule *before* committing, and never `git add -A` a directory that may hold third-party drops.
- A `.gitignore` negation cannot rescue a file inside an ignored *directory*. `exemples/**/README.md` stays ignored because `exemples/` itself is excluded.
- **Never run `git clean -x`** (or `-X`) here. Almost everything in this folder is ignored-but-precious: it would delete the downloaded mods, `exemples/`, and the game's own settings.
- **Annotated tags `<name>_<version>` mark published releases** — created and pushed only as part of an authorised release, never unprompted. No tag for the version in a mod's `info.json` means that version is still **open**: changelog work belongs in its existing top section, not a new one. The decision procedure is in the `factorio-release` skill.
- **`main` is Factorio 2.1.** A mod that also ships for 2.0 keeps that build on a `legacy/2.0` branch, checked out as a worktree **outside this directory** — the mods folder is the live install, not a place for a second copy of a mod. Path in `CLAUDE.local.md`; workflow in the `factorio-multiversion` skill.

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

## Player-facing text

Everything a player reads is written in the mod's voice, not the agent's. **No AI signature, tagline, or generated-with credit** — no "Made with Claude Code", "AI-generated", "Built with an LLM", or similar, in any of: `info.json` `title`/`description`, `changelog.txt`, `README.md`/`description.md`/FAQ and anything else synced to the portal, locale strings, `thumbnail.png` and in-game graphics.

This is about the product reading as a mod, the same reason it carries no build-tool credits. It says nothing about commit messages or `.ai-support/` notes — those stay as they are.

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

The game install ships the authoritative API for the *exact installed version* — **prefer these over anything remembered, guessed, or found online.** Paths are relative to the install root (absolute path in `CLAUDE.local.md`; typically `C:\Program Files (x86)\Steam\steamapps\common\Factorio`, `/Applications/factorio.app/Contents`, or `~/.steam/steam/steamapps/common/Factorio`):

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
- **Errors surface in `factorio-current.log`**, in the same user-data folder as `mods/`. Read it when diagnosing a load failure — several failure modes are silent otherwise.

## Skills

Reference detail lives in `.claude/skills/`, tracked in this repo. **Invoke the relevant skill before doing the work, not after** — most of what they cover fails *silently* in Factorio. A mistyped `info.json` field, a folder name that doesn't match, a stray space in `changelog.txt`: none of these raise an error, they just produce a mod that quietly doesn't do what was meant. Recalling the rules from memory is how that happens; reading them takes seconds.

| Invoke | Before / when |
|---|---|
| `factorio-mod-development` | Writing or changing any mod Lua — prototypes, `control.lua`, `storage`, events, GUIs, performance, cross-mod compatibility, desyncs, debugging |
| `factorio-mod-setup` | Starting a mod; touching `info.json`, `locale/*.cfg`, `settings.lua` or `migrations/`; a mod that won't load or shows `Unknown key` in game |
| `factorio-changelog` | Writing or fixing **any** line of `changelog.txt` |
| `factorio-release` | Any version bump, `fmtk` command, packaging, or mod-portal question |
| `factorio-validate` | After editing prototypes and before packaging — proves the data stage loads |
| `factorio-graphics` | Any sprite, icon, `thumbnail.png` or Blender work — including *designing* an entity's look, which happens before any Blender step |
| `factorio-multiversion` | Anything touching a second game version — backporting to 2.0, the `legacy/2.0` branch, whether a change is safe there, or what 2.1 broke |

Roughly: `factorio-mod-development` is the code, `factorio-mod-setup` is the wrapper around it, the rest are the steps on either side.

Several tasks span two: a release is `factorio-release` **and** `factorio-changelog`; renaming a prototype is `factorio-mod-development` (the code), `factorio-mod-setup` (the migration) **and** `factorio-release` (the major bump); a backport release is `factorio-multiversion`, `factorio-validate` (against a 2.0 install) **and** both of the release pair. Invoke all of them.
