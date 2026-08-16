#!/usr/bin/env python3
"""Content checks for the repo's documentation. See CLAUDE.md -> AI support folders.

check-ai-support.ps1 checks the SHAPE of an .ai-support folder (index present, every file
listed). This checks the CONTENT of the notes against things that can actually contradict them:

  1. API citations   `LuaSurface.create_entity` resolves against the installed
                     doc-html/runtime-api.json
  2. Game data       `data/recycler/data.lua:109` names a file that exists, at a line it has
  3. Freshness       every analysis/**/*.md declares verified_against, matching the install
  4. Links           every relative path written in a doc resolves to something on disk

The point is coupling: a note that has drifted from the game should BREAK, not sit there being
quietly believed. Citations pass today, which is what makes the check worth having - it fires
the day the pinned install is replaced, naming exactly which claims need re-checking.

The install is the folder holding this repo's mods/ directory, so the script self-locates: run
it from the legacy worktree and it checks against 2.0 instead. Exit 0 = clean, 1 = problems.
"""

import io
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
INSTALL = os.path.dirname(REPO)
SKIP_DIRS = {".git", "exemples", "node_modules"}

problems = []
notes = []


def markdown_files():
    for base, dirs, files in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.endswith(".md"):
                yield os.path.join(base, f)


def rel(path):
    return os.path.relpath(path, REPO).replace("\\", "/")


def read(path):
    return io.open(path, encoding="utf-8").read()


def all_repo_paths():
    out = set()
    for base, dirs, files in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            out.add(rel(os.path.join(base, f)))
        for d in dirs:
            out.add(rel(os.path.join(base, d)) + "/")
    return out


REPO_PATHS = all_repo_paths()


def resolves(target, here, docrel):
    """True if `target` names something real, tried from the bases a reader would assume."""
    t = target.rstrip("/")
    bases = [here, REPO]
    mod = docrel.split("/")[0]
    if os.path.isdir(os.path.join(REPO, mod)):
        bases += [os.path.join(REPO, mod), os.path.join(REPO, mod, ".ai-support")]
    for b in bases:
        if os.path.exists(os.path.normpath(os.path.join(b, t))):
            return True
    # Bare names, and paths written relative to a folder the prose already established.
    return any(p == t or p.rstrip("/").endswith("/" + t) for p in REPO_PATHS)


# ---------------------------------------------------------------- installed API

api_path = os.path.join(INSTALL, "doc-html", "runtime-api.json")
installed_version = None
class_members = {}

if not os.path.exists(api_path):
    notes.append("no doc-html/runtime-api.json beside the repo - API and freshness checks skipped")
else:
    api = json.load(io.open(api_path, encoding="utf-8"))
    installed_version = api.get("application_version")
    for c in api.get("classes", []):
        names = set()
        for m in c.get("methods", []):
            names.add(m["name"])
        for a in c.get("attributes", []):
            names.add(a["name"])
        class_members[c["name"]] = names

# ------------------------------------------------------------------- the checks

CITE = re.compile(r"\b(Lua[A-Za-z]+)\.([a-z_][a-z0-9_]*)\b")
GAMEDATA = re.compile(r"`(data/[a-z0-9_-]+/[A-Za-z0-9/_-]+\.lua):(\d+)(?:-\d+)?`")
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
BACKTICK_PATH = re.compile(r"`([A-Za-z0-9_./-]+\.md)`")
FRONT = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.S)

n_cite = n_data = n_link = n_front = 0

for path in markdown_files():
    text = read(path)
    here = os.path.dirname(path)
    r = rel(path)
    is_note = "/.ai-support/" in ("/" + r)

    # 1. API citations - only inside .ai-support, where claims are made about the engine.
    if is_note and class_members:
        for cls, mem in set(CITE.findall(text)):
            n_cite += 1
            if cls not in class_members:
                problems.append("%s : cites `%s.%s` - no such class in %s"
                                % (r, cls, mem, installed_version))
            elif mem not in class_members[cls]:
                problems.append("%s : cites `%s.%s` - not a member of %s in %s"
                                % (r, cls, mem, cls, installed_version))

    # 2. Game-data citations. Line numbers shift on every game update, which is exactly why
    #    they are worth checking rather than trusting. Notes only: repo docs and skills mention
    #    such paths illustratively, and an expansion cited by one mod (recycler is 2.1-only) is
    #    legitimately absent from another install.
    for target, line in (set(GAMEDATA.findall(text)) if is_note else set()):
        n_data += 1
        full = os.path.join(INSTALL, target.replace("/", os.sep))
        if not os.path.exists(full):
            problems.append("%s : cites `%s` - not present in this install" % (r, target))
            continue
        count = sum(1 for _ in io.open(full, encoding="utf-8", errors="replace"))
        if int(line) > count:
            problems.append("%s : cites `%s:%s` - the file has only %d lines"
                            % (r, target, line, count))

    # 3. Freshness. Required on evidence files; the version is what matters, not elapsed time -
    #    the install is pinned deliberately and only moves when someone replaces it by hand.
    if "/.ai-support/analysis/" in ("/" + r) and not r.endswith("/index.md"):
        n_front += 1
        m = FRONT.match(text)
        if not m:
            problems.append("%s : evidence file with no front matter - needs verified_against" % r)
        else:
            fm = dict(re.findall(r"(?m)^([a-z_]+):\s*(.+?)\s*$", m.group(1)))
            if "verified_against" not in fm:
                problems.append("%s : front matter has no verified_against" % r)
            elif installed_version and fm["verified_against"] != installed_version:
                problems.append("%s : verified against %s, install is %s - re-check its claims"
                                % (r, fm["verified_against"], installed_version))

    # 4. Relative links, both markdown links and this repo's backticked-path convention.
    #    The house style names a file by its bare name once the sentence has established the
    #    folder ("`decisions.md` holds what is settled"), so a name is not a path and must not
    #    be resolved as one. A name passes if it matches ANY file in the repo; that still
    #    catches the case this exists for - a rename leaves the old name matching nothing.
    #    Scope: a MOD's own docs, which reference that mod's own files - the case this exists
    #    for. Repo-level docs and skills are excluded because they name conventions rather than
    #    paths (`decisions.md` as a genre, not a file), and reference things that are absent by
    #    design: CLAUDE.local.md is git-ignored, exemples/ is optional, and legacy/2.0 carries
    #    only the mods that ship a 2.0 build. Checking them there reports the branch, not a bug.
    mod = r.split("/")[0]
    in_mod = "/" in r and os.path.exists(os.path.join(REPO, mod, "info.json"))
    if not in_mod:
        continue

    candidates = set()
    for t in LINK.findall(text):
        if not re.match(r"^(https?:|mailto:|#)", t):
            candidates.add(t.split("#")[0])
    for t in BACKTICK_PATH.findall(text):
        candidates.add(t)

    for target in candidates:
        if not target or "<" in target or ">" in target or "*" in target:
            continue  # illustrative placeholder, not a real path
        if target == "CLAUDE.local.md" or target.startswith("exemples/"):
            continue  # git-ignored by design and absent from a fresh clone - never a defect
        n_link += 1
        if not resolves(target, here, r):
            problems.append("%s : names `%s`, which matches no file in the repo" % (r, target))

# ------------------------------------------------------------------------ report

print("install: %s (%s)" % (INSTALL, installed_version or "version unknown"))
print("checked: %d API citations, %d game-data citations, %d evidence files, %d paths"
      % (n_cite, n_data, n_front, n_link))
for n in notes:
    print("  note: %s" % n)

if not problems:
    print("ai-docs consistent")
    sys.exit(0)

print("\n%d problem(s):" % len(problems))
for p in sorted(set(problems)):
    print("  - %s" % p)
sys.exit(1)
