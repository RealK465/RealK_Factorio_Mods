# RealK's Factorio Mods

This is a Factorio **mods directory** that is also a git repository — it's the live
`mods/` folder Factorio loads at game start, checked into git so the mods developed here
have version history. Only the mods authored in this repo are tracked; everything else
Factorio or another author put here (other mods' `.zip` files, save-related files, the
game's own settings) is git-ignored.

## Mods

| Mod | Status | Description |
|---|---|---|
| [`pure-modules-realk`](pure-modules-realk/) | [published](https://mods.factorio.com/mod/pure-modules-realk) | A clean top tier of modules above tier 3 — stronger, with no speed or quality penalty — plus a wide-area beacon built for the tier. |
| [`space-forge`](space-forge/) | in development | A large overhaul. Early scaffolding — not playable yet. |
| [`space-forge-graphics`](space-forge-graphics/) | in development | The art for Space Forge, split out so a balance patch stays small. Contains no code. |
| [`upcycler-architect`](upcycler-architect/) | in development | A layout planner for quality upcycling loops — pick an item and a target quality, and it designs the loop and drops it as ghosts. First version works end to end; unreleased. |

Each mod folder is self-contained and carries its own `README.md`, `LICENSE` and
`changelog.txt`, which is what ships to the [mod portal](https://mods.factorio.com/) on
release.

## Repository layout

```
<mod-name>/          one folder per mod, matching its info.json name exactly
assets/<mod-name>/   art sources (.blend, textures) behind that mod's graphics/ — never shipped
.claude/skills/       Factorio-modding reference used by Claude Code while working here
CLAUDE.md             portable repo conventions and rules
CLAUDE.local.md        machine-specific paths and identity (git-ignored, not in a fresh clone)
LICENSE               GPLv3, mirrored into each mod folder so it ships in the zip
```

## Using this repository

Clone it into a Factorio `mods` directory to make the tracked mods loadable and editable in
place — save a file, restart the game, see the change:

- Windows: `%APPDATA%\Factorio\mods`
- macOS: `~/Library/Application Support/factorio/mods`
- Linux: `~/.factorio/mods`

Working from elsewhere is fine too, but a mod won't be live in-game until it's symlinked
or copied into a real `mods` folder.

If you also *play* Factorio, clone into a **second, standalone (DRM-free) copy of the game**
kept for development instead, and leave your play install alone. The mods you play with never
mix with the ones you're building, the dev copy stays pinned to one game version, and — because
a standalone install keeps its own lock and user-data — validation and screenshot runs work
while your actual game is open. That's how this repo is maintained, and the tooling under
`.claude/` assumes it: the scripts locate the game by looking one level up from the repo.

## Branches

One branch per Factorio generation. Both are permanent trunks.

Both are intended to be protected — pull requests required, force-pushes and branch deletion
blocked. That protection is **currently off**: the repository is temporarily private, and
GitHub Free offers branch protection only on public repositories. It will be restored as part
of making the repository public again.

| Branch | Factorio | Role |
|---|---|---|
| `main` | 2.1 | Where new work happens. The default branch. |
| `legacy/2.0` | 2.0 | The 2.0 build of every mod here, kept while 2.0 is the stable release. |

A mod zip declares exactly one `factorio_version`, so supporting both games means two
builds and two uploads of the same mod — the portal serves each game only the releases
matching it. Version numbers come from a single sequence shared by both branches, so a
release number says nothing about which game it targets; the changelog entry does.

Only a mod's own source differs between the branches. The docs, `.claude/`, each mod's
notes and its `changelog.txt` are kept identical, so `git diff main` from the `legacy/2.0` side should only ever
list the files a port genuinely changes.

Released versions are marked with annotated `<mod-name>_<version>` tags, per mod, on
whichever branch shipped them.

## Development

This repo is developed with [Claude Code](https://claude.com/claude-code); `CLAUDE.md`
holds the conventions and `.claude/skills/` the Factorio-specific reference material
(mod setup, prototypes, graphics, changelogs, releases, validation, multi-version
support) that guide that work. None of it ships with a mod or reaches the mod portal.

Tooling used across mods in this repo:

- [**fmtk**](https://github.com/justarandomgeek/vscode-factoriomod-debug) (`factoriomod-debug`) — versioning, packaging and publishing
- **Blender**, for entity and icon art — sources live in `assets/`, exports in each mod's `graphics/`
- Factorio's own headless binary, for validating that a mod's data stage loads before packaging

## License

The whole repository — every mod folder and the tooling around it — is licensed under
the [GNU General Public License v3.0](LICENSE).
