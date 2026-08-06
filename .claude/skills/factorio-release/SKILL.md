---
name: factorio-release
description: Use when preparing a Factorio mod release or answering anything about the mod portal — choosing a patch/minor/major version bump, running fmtk version, datestamp, package or publish, checking what ends up in the shipped zip, package.ignore, portal naming rules, or upload API keys. Consult it before any version bump or packaging step, and note that uploading or publishing always needs the repo owner's explicit approval for that specific release.
---

# Releasing a mod

## The rule, restated

**Never publish, upload, release, or edit portal details unless the repo owner asks for it in that specific instance.**

The mod portal is public and effectively append-only: a version number can never be re-used, and a release that goes out is visible and downloadable immediately. There is no undo.

- Approval is **per release**, never standing. "Publish 0.3.0" authorises 0.3.0 and nothing after it.
- "It's ready", "tests pass", "that's the last fix", or a finished changelog entry are **not** authorisation.
- Preparing a release is fine and encouraged — bump the version, write the changelog, build the zip locally, verify it. **Stop at the upload.**
- When a release looks ready, say so and wait.

| Safe to run | Never run unprompted |
|---|---|
| `fmtk package` — builds a local zip only | `fmtk publish` — the whole commit → tag → upload → push chain |
| `fmtk version`, `fmtk datestamp` — local file edits | `fmtk upload` — pushes a zip to the portal |
| `fmtk lsp`, `fmtk docs` | `fmtk details` — rewrites the public mod page |
| `GET mods.factorio.com/api/mods/<name>` — read-only public info | Any other direct call to a `mods.factorio.com/api` endpoint |

## Published or open?

Every changelog and bump decision hangs on one fact: **has the version currently in
`info.json` ever shipped?** Shipped → new work opens a new changelog section and bumps.
Not shipped → that version is **open**, and new work belongs in its existing top section.
The answer has to survive a fresh conversation, so it is recorded in git rather than
remembered:

- **Annotated tags `<name>_<version>` mark published releases** — `pure-modules-realk_1.0.0`,
  matching the zip name, which keeps tags per-mod in this multi-mod repo. A tag is created
  and pushed only inside an authorised release (Sequence, step 6) — never unprompted.
- **The check:** `git tag -l '<name>_<version>'` with the exact version from `info.json`.
  Tag → shipped. No tag → open. `git tag -l '<name>_[0-9]*'` lists one mod's releases.
- **The unreleased delta is `git diff <last-tag> -- <mod-folder>/`** — uncommitted work
  included; no tags at all means the whole mod is the delta. That diff, not the current
  session's own change, is what the open changelog section must describe and what grades
  the bump.
- **Fallback, a read-only portal GET:** `https://mods.factorio.com/api/mods/<name>` —
  public, no key, and the one portal call that is fine to run unprompted; everything that
  writes stays under the rule above. Run it when the tags say "open" and the answer is
  about to matter (opening a new section, proposing a release). A 404 proves the name has
  never shipped. A 200 does **not** prove this repo shipped it — read the `owner` field.
  The GET catches the two things tags cannot: a release made by hand on the website and
  never tagged (propose backfilling the tag; the owner confirms which commit shipped), and
  a name already held by someone else's account, which blocks a first release entirely.

## Versioning

`version` carries no meaning to the game, so the convention is ours. Roughly semver, with **saves** as the thing being protected:

- **Patch** (`0.1.0` → `0.1.1`) — bugfixes, graphics, balance tweaks that don't touch prototype names.
- **Minor** (`0.1.1` → `0.2.0`) — new prototypes, recipes, technologies. Additive and save-safe.
- **Major** (`0.2.0` → `1.0.0`) — renaming or removing a prototype, or anything else that breaks an existing save without a migration. This is the bump that pairs with a `!` / `BREAKING CHANGE:` commit.

Grade the bump against the **whole unreleased delta** since the last release tag (see
"Published or open?"), not against one session's change — the diff says mechanically which
line above applies. Two autonomy levels: choosing the bump when **opening a new section**
is the agent's call; changing the number of an **already-open version** that outgrew its
bump — an open 1.0.1 gains a prototype and should be 1.1.0 — is a **re-grade: propose it,
with `info.json` and the section header changing together, and wait.** Never re-grade
unasked; the repo owner decides version numbers, open ones included.

A release is one atomic change: bump `info.json`, add the changelog section, rename the folder if it carries a version suffix. **All three must agree.**

**The minor digit is reserved for the game generation.** A mod supporting both live Factorio
versions releases `<major>.1.x` for 2.1 and `<major>.0.x` for 2.0, which keeps the newer game's
track numerically above the older one — the journey players make is 2.0 → 2.1 carrying a save,
and it should never look like a mod downgrade. That takes the semver minor away, so
additive-and-save-safe work bumps the patch digit and says what it is in the changelog. Major is
unchanged and bumps on both tracks together. Backporting, the legacy branch and the second
release track are the `factorio-multiversion` skill.

## Sequence

1. `fmtk version` — bumps `version` in `info.json` and opens a new changelog section stamped `Date: ????`. **Skip when the top section is already open** — the work belongs in it (see "Published or open?").
2. Write the changelog entries under that section by hand — see the `factorio-changelog` skill. The section keeps `Date: ????` for as long as the version is open, however many sessions that spans.
3. Validate the data stage — see the `factorio-validate` skill.
4. `fmtk package` — builds `<name>_<version>.zip`. Local only, safe, and the right way to sanity-check what would ship. A sanity zip may still carry `Date: ????`; the shipping one is rebuilt after the datestamp.
5. Verify the zip contents, then **stop and ask**.
6. The release itself, on approval — one approval covers this chain for this version and nothing after it: `fmtk datestamp` (replaces `????` with today's date; format from `package.datestamp_format`, **defaulting to `isoDate`**, which is why ISO is the house format) → rebuild the zip → `fmtk upload` → commit the release → tag `<name>_<version>` → push, tag included.
7. `fmtk publish` — the all-in-one alternative, only on explicit instruction. Requires a clean git tree on the publish branch, then: prepublish script → datestamp → commit → tag → package → upload → details sync → postpublish script → version bump → commit → push. Two catches in this repo: it **pushes to git and uploads to the portal in one go**, and its default git tag is the bare version number, which collides across mods in a multi-mod repository — set `"no_git_tag": true` in `package` and create the `<name>_<version>` tag by hand. When the steps should stay separable, use step 6 instead.

## Tooling: `fmtk`

`factoriomod-debug`, installed globally via npm; binary `fmtk` (also `factoriomod-debug`). Requires Node ≥ 22.7.0. **Run it from inside the mod folder** — it reads `./info.json` and `./changelog.txt` from the working directory. `CLAUDE.local.md` records the versions installed on this machine.

```
npm install -g factoriomod-debug
```

### `fmtk mods` — hazard

`fmtk mods enable|disable|install|adjust` defaults `--modsPath` to **the live mods directory** — i.e. this repo — and rewrites `mod-list.json`, which the "Do not touch" rule puts off-limits. Don't use these subcommands here. Managing the play install is the game's job.

## What goes in the zip

`fmtk package` includes everything under the mod folder except **dotfiles**, `<name>_*.zip`, and the globs in `info.json#/package/ignore`. The inner folder is named `<name>_<version>`.

- `.ai-support/`, `.git/` and `.claude/` are dotfiles, so they are excluded automatically — tracking them in git does not change that.
- **`CLAUDE.md` and `CLAUDE.local.md` are not dotfiles and would ship.** Every mod's `info.json` needs `"package": { "ignore": ["CLAUDE.md", "CLAUDE.local.md", ...] }`. `.gitignore` has no bearing on packaging, so this is a separate thing to remember for each new mod — and since `CLAUDE.md` is tracked rather than ignored, `package.ignore` is the *only* thing keeping it out of the zip. Add source renders, `.blend` files and tests to the same list.
- **`ignore` entries are globs, and a bare directory name matches nothing.** `"images"` leaves the whole folder in the zip; it has to be `"images/**"`. A plain filename like `"CLAUDE.md"` works because it matches literally, which is exactly what makes the directory case easy to get wrong — the list looks like it is working. Verified on 2.1.8, and the only thing that catches it is reading the built zip: `fmtk package` prints a file tree and exits 0 either way.
- **Verify by listing the zip, not by reading `package.ignore`.** `python -c "import zipfile;print(zipfile.ZipFile('<name>_<ver>.zip').namelist())"`, or compare the byte size before and after adding a rule.
- Built zips match `*.zip` in `.gitignore`, so they never get committed by accident.

The `package` object is fmtk config; Factorio ignores the key entirely. Fields: `ignore`, `extra` (extra root dirs), `scripts` (`compile`, `prepackage`, `datestamp`, `version`, `prepublish`, `publish`, `postpublish`), `git_publish_branch`, `datestamp_format`, `readme`, `faq`, `gallery`, `sync_portal_details`, `no_git_tag`, `no_git_push`, `no_portal_upload`.

## License

Every mod in this repo is GPLv3 (repo `CLAUDE.md` → License). Two separate things carry that, neither of them `info.json` — it has no license field:

- The mod's own `LICENSE` file (GPLv3 text, copied from the repo root) ships in the zip automatically once it exists at the mod root — it isn't a dotfile and isn't in `package.ignore`.
- The mod portal has its own license field on each mod's Details page, picked from a fixed preselected list (not free text) — select the closest GPLv3 entry there. This is set through the same portal-editing surface as `fmtk details` / the "Details" step in `fmtk publish`, so it falls under the existing rule: only touch it with the repo owner's explicit approval for that release.

## Portal rules the game doesn't enforce

`name` 4–49 chars, alphanumerics/dashes/underscores only; `factorio_version` with no third digit; and a version number that has never been uploaded before. A mod failing these loads fine locally and is rejected at upload.

Uniqueness is the only version rule — the portal does **not** require an upload to be numerically
newer than the last one. That is what makes a second release track possible: a `1.0.5` build for
Factorio 2.0 uploads cleanly after `1.1.2` for 2.1 already exists, and each game only ever sees
the releases matching its own major version.

Names are unique across every account that has ever published — deleted accounts included: `pure-modules` is held by one, which is why this repo's Pure Modules ships as `pure-modules-realk` and which only the read-only GET could have revealed. Check the name *before* the first release conversation, not during it.

## API key

Required only for upload/publish. Create it at https://factorio.com/profile, with the scope matching the intent:

- *ModPortal: Publish Mods* — first-ever release of a new mod name.
- *ModPortal: Upload Mods* — new release of an existing mod.
- *ModPortal: Edit Mods* — `fmtk details` / portal page sync.

It is tied to a factorio.com login, so **the repo owner has to create it — an agent cannot.** fmtk stores it in the OS credential store on first use, or reads `FACTORIO_UPLOAD_API_KEY`, which takes precedence. **Never write the key into `info.json`, a script, a commit, or any tracked file.** Grant only the narrowest scope needed; an upload-only key cannot rewrite the public page.

Underlying API, if fmtk ever needs bypassing — two steps, `Authorization: Bearer <key>`:

- New mod: POST `https://mods.factorio.com/api/v2/mods/init_publish` → POST the zip as multipart form-data to the returned `upload_url`.
- New release: POST `https://mods.factorio.com/api/v2/mods/releases/init_upload` → same multipart POST.
