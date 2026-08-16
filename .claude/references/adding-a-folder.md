# Adding a folder to the repo root

Loaded on demand from the repo `CLAUDE.md` → *Folder classes*. Read it when adding a root
folder; it is a procedure, not a standing rule, which is why it does not sit in `CLAUDE.md`.

The class decides how many places need updating, and getting it wrong is silent — it surfaces
later as an accidental commit, or as an edit to someone else's mod.

| Class | `.gitignore` | `settings.json` deny | `CLAUDE.local.md` | own `CLAUDE.md` |
|---|---|---|---|---|
| Deliverable | — tracked | — | — | yes |
| Local mod | yes | — | yes | yes |
| Patched vendor | yes | — | yes | yes |
| Frozen vendor | yes | **yes** | yes | no — never write into it |
| Reference | yes | **yes** | yes | no |

A deny rule needs **both** `Edit(<folder>/**)` and `Write(<folder>/**)`; they are separate tools
and denying one leaves the other open. Neither constrains Bash, so `sed -i` or `cp` still reaches
a frozen folder — the deny list raises the cost of a mistake, it does not make one impossible.

`.claude/scripts/check-folder-scope.ps1` checks all four columns against what is on disk. Run it
after adding a folder. It exists because all three lists had already drifted: a frozen-vendor mod
was sitting in `.gitignore` with no deny rule and no mention in `CLAUDE.local.md`, and a patched
one was in none of them.

The script infers the class from evidence rather than from a fourth list — the presence of a deny
rule *is* the machine-readable marker, and an editable folder declares itself by carrying its own
`CLAUDE.md`:

```
tracked                       -> Deliverable
ignored + deny rules          -> Frozen vendor / Reference  (hands-off)
ignored + no deny rules       -> Local mod / Patched vendor (editable, must self-declare)
```

A new **Deliverable** also needs the rest of the new-mod checklist — `info.json`, a `LICENSE`
copy, locale, `changelog.txt`, its own `CLAUDE.md`. That lives in the `factorio-mod-setup` skill.
