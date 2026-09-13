# Restoring branch protection

Loaded on demand from the repo `CLAUDE.md` → *Git*. Read it at exactly one moment: when the
remote goes public after a spell of being private. Until then nothing here is actionable, which
is why it is not preloaded.

## The situation

`main` and `legacy/2.0` were both protected until 2026-08-08: pull requests required,
force-pushes and branch deletion blocked. GitHub Free offers neither classic protection nor
rulesets on a *private* repository, so taking the repo private disabled both — `403: Upgrade to
GitHub Pro or make this repository public`, verified 2026-08-08. The repository went public
again on 2026-09-13 and protection was **restored the same day**, with the PUT below on both
branches; the response read every field in the table back.

If the repo is ever taken private again the protection drops with it. **Restore it as part of
the move back to public**, not later.

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

## What a direct push looks like with protection on

Because `enforce_admins` is off, the owner's own push bypasses the pull-request rule, and
GitHub says so on every push:

```
remote: Bypassed rule violations for refs/heads/main:
remote:
remote: - Changes must be made through a pull request.
remote:
To github.com:RealK465/RealK_Factorio_Mods.git
   acb02fa..4d09dab  main -> main
```

That is the **success** case — the `old..new  main -> main` line is the push landing. A real
rejection reads `! [remote rejected]` and `error: failed to push some refs`. Measured
2026-09-13 on both branches; a `| tail` on the push output can hide the header line and leave
only the bullet, which then reads as a refusal.

## What the loss actually costs

Less than it appears, and the part that matters is in `CLAUDE.md` rather than here:
`enforce_admins` was off, so the pull-request rule never bound the owner anyway. Force-push and
branch deletion were the only rules that actually bound anything — which is why the standing
rule while protection is off is that the committing rule is the entire floor, not a second layer.
