# Restoring branch protection

Loaded on demand from the repo `CLAUDE.md` → *Git*. Read it at exactly one future moment: when
the remote goes public again. Until then nothing here is actionable, which is why it is not
preloaded.

## The situation

`main` and `legacy/2.0` were both protected until 2026-08-08: pull requests required,
force-pushes and branch deletion blocked. GitHub Free offers neither classic protection nor
rulesets on a *private* repository, so taking the repo private disabled both — `403: Upgrade to
GitHub Pro or make this repository public`, verified 2026-08-08.

The repo is expected to go public again. **Restore protection as part of that same move**, not
later.

## The restore

Both branches, via:

```
gh api -X PUT repos/RealK465/RealK_Factorio_Mods/branches/<branch>/protection
```

The PUT **replaces the whole object and silently drops any field left out**, so send all of it:

| field | value |
|---|---|
| `required_pull_request_reviews` | `dismiss_stale_reviews` true; `required_approving_review_count` 0; `require_code_owner_reviews`, `require_last_push_approval` false |
| `required_conversation_resolution` | true |
| `enforce_admins`, `allow_force_pushes`, `allow_deletions` | false |
| `required_linear_history`, `block_creations`, `lock_branch`, `allow_fork_syncing` | false |
| `required_status_checks`, `restrictions` | null |

`gh` is not on the agent's PATH — invoke it as `"/c/Program Files/GitHub CLI/gh.exe"`. It is
authenticated as **RealK465**.

## What the loss actually costs

Less than it appears, and the part that matters is in `CLAUDE.md` rather than here:
`enforce_admins` was off, so the pull-request rule never bound the owner anyway. Force-push and
branch deletion were the only rules that actually bound anything — which is why the standing
rule while protection is off is that the committing rule is the entire floor, not a second layer.
