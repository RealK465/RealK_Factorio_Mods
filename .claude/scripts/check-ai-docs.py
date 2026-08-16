#!/usr/bin/env python3
"""Content checks for the repo's documentation. See CLAUDE.md -> AI support folders.

check-ai-support.ps1 checks the SHAPE of an .ai-support folder (index present, every file
listed). This checks the CONTENT of the notes against things that can actually contradict them:

  1. API citations   `LuaSurface.create_entity` resolves against doc-html/runtime-api.json -
                     an evidence file is held to its own pinned install exactly; unpinned
                     notes (journal, registers) pass on any pinned install, since those
                     genres are allowed to age
  2. Game data       `data/recycler/data.lua:109` names a file that exists, at a line it has,
                     under the same install rule as the API citations
  3. Freshness       every analysis/**/*.md declares verified_against, matching a pinned
                     install - the one beside this repo, or one holding another worktree of it
  4. Links           every relative path written in a doc resolves to something on disk

The point is coupling: a note that has drifted from the game should BREAK, not sit there being
quietly believed. Citations pass today, which is what makes the check worth having - it fires
the day the pinned install is replaced, naming exactly which claims need re-checking.

The install is the folder holding this repo's mods/ directory, so the script self-locates: run
it from the legacy worktree and it checks against 2.0 instead. Evidence pinned to the OTHER
track's version (a 2.0 file read from main, api.md read from legacy) resolves through the git
worktrees, each of which sits in its own install - so one clone checks both, and only a version
no pinned install carries is a freshness problem. Exit 0 = clean, 1 = problems.
"""

import io
import json
import os
import re
import subprocess
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


# ---------------------------------------------------------------- installed APIs
#
# Evidence is pinned to a game version, and this repo deliberately spans two: main sits in the
# 2.1 install and legacy/2.0 sits, as a worktree, in the 2.0 one. Each evidence file is checked
# against the install matching its own verified_against, found through the worktrees, so a 2.0
# note is not "stale" on main nor a 2.1 note on legacy. Foreign installs load lazily - a repo
# whose evidence all matches the local install never pays for the second parse.


def load_api(install):
    api_path = os.path.join(install, "doc-html", "runtime-api.json")
    if not os.path.exists(api_path):
        return None, {}
    api = json.load(io.open(api_path, encoding="utf-8"))
    members = {}
    for c in api.get("classes", []):
        names = set()
        for m in c.get("methods", []):
            names.add(m["name"])
        for a in c.get("attributes", []):
            names.add(a["name"])
        members[c["name"]] = names
    return api.get("application_version"), members


def worktree_installs():
    try:
        out = subprocess.run(["git", "worktree", "list", "--porcelain"], cwd=REPO,
                             capture_output=True, text=True).stdout
    except OSError:
        return []
    return [os.path.dirname(line[len("worktree "):])
            for line in out.splitlines() if line.startswith("worktree ")]


installed_version, class_members = load_api(INSTALL)
if installed_version is None:
    notes.append("no doc-html/runtime-api.json beside the repo - API and freshness checks skipped")

api_by_version = {installed_version: (class_members, INSTALL)}
_unloaded_installs = [p for p in worktree_installs()
                      if os.path.normpath(p) != os.path.normpath(INSTALL)]


def api_for(version):
    """(class_members, install) for the install pinned at `version`; the local pair if none is."""
    while version not in api_by_version and _unloaded_installs:
        other = _unloaded_installs.pop()
        v, members = load_api(other)
        if v and v not in api_by_version:
            api_by_version[v] = (members, other)
    return api_by_version.get(version, (class_members, INSTALL))


def ensure_all_apis():
    """Load every worktree install, for the any-pinned-install checks on unpinned notes."""
    while _unloaded_installs:
        other = _unloaded_installs.pop()
        v, members = load_api(other)
        if v and v not in api_by_version:
            api_by_version[v] = (members, other)

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

    # Which install this file's claims are made against: the one carrying its own
    # verified_against when some worktree of this repo pins it, the local install otherwise.
    front = FRONT.match(text)
    fm = dict(re.findall(r"(?m)^([a-z_]+):\s*(.+?)\s*$", front.group(1))) if front else {}
    claimed = fm.get("verified_against")
    file_members, file_install = api_for(claimed) if claimed else (class_members, INSTALL)
    file_version = claimed if claimed in api_by_version else installed_version
    is_evidence = "/.ai-support/analysis/" in ("/" + r) and not r.endswith("/index.md")

    # 1. API citations - only inside .ai-support, where claims are made about the engine.
    #    Evidence files pin a version and are held to that install exactly. The other genres
    #    (journal, registers) carry no pin and the journal is ALLOWED to go stale, so their
    #    citations pass if any pinned install knows them - a name that exists nowhere is still
    #    a typo worth failing.
    if is_note and file_members:
        for cls, mem in set(CITE.findall(text)):
            n_cite += 1
            if is_evidence:
                if cls not in file_members:
                    problems.append("%s : cites `%s.%s` - no such class in %s"
                                    % (r, cls, mem, file_version))
                elif mem not in file_members[cls]:
                    problems.append("%s : cites `%s.%s` - not a member of %s in %s"
                                    % (r, cls, mem, cls, file_version))
            else:
                ensure_all_apis()
                if not any(m and cls in m and mem in m[cls]
                           for m, _ in api_by_version.values()):
                    problems.append("%s : cites `%s.%s` - not known to any pinned install"
                                    % (r, cls, mem))

    # 2. Game-data citations. Line numbers shift on every game update, which is exactly why
    #    they are worth checking rather than trusting. Notes only: repo docs and skills mention
    #    such paths illustratively, and an expansion cited by one mod (recycler is 2.1-only) is
    #    legitimately absent from another install.
    for target, line in (set(GAMEDATA.findall(text)) if is_note else set()):
        n_data += 1
        if is_evidence:
            installs = [(file_install, file_version)]
        else:
            ensure_all_apis()
            installs = [(inst, v) for v, (_, inst) in api_by_version.items() if v]
        ok, short_msg, missing_msg = False, None, None
        for inst, v in installs:
            full = os.path.join(inst, target.replace("/", os.sep))
            if not os.path.exists(full):
                missing_msg = missing_msg or ("%s : cites `%s` - not present in the %s install"
                                              % (r, target, v))
                continue
            count = sum(1 for _ in io.open(full, encoding="utf-8", errors="replace"))
            if int(line) <= count:
                ok = True
                break
            short_msg = short_msg or ("%s : cites `%s:%s` - the file has only %d lines in %s"
                                      % (r, target, line, count, v))
        if not ok:
            problems.append(short_msg or missing_msg)

    # 3. Freshness. Required on evidence files; the version is what matters, not elapsed time -
    #    the install is pinned deliberately and only moves when someone replaces it by hand.
    if is_evidence:
        n_front += 1
        if not front:
            problems.append("%s : evidence file with no front matter - needs verified_against" % r)
        elif "verified_against" not in fm:
            problems.append("%s : front matter has no verified_against" % r)
        elif installed_version and claimed not in api_by_version:
            problems.append("%s : verified against %s, but no pinned install carries that version"
                            " - re-check its claims" % (r, claimed))

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
for v, (_, p) in sorted((k, v) for k, v in api_by_version.items() if k):
    if v != installed_version:
        print("  also: %s (%s)" % (p, v))
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
