---
name: branch-flow
description: Simple Git conventions for one person working with several AI agents — main/dev/task-branch roles, one worktree per task, merge into dev, clean up worktrees and merged branches right away, release only on request (tag + verified assets). Use whenever you start, finish, merge, clean up or release work in a Git repository, or when asked what is left over.
metadata:
  version: "0.1.0"
---

# branch-flow

A few hard rules so several agents (and one human) can work in the same repository without
overwriting each other or leaving debris. A repository's own `AGENTS.md` / `CLAUDE.md` wins
where it is stricter (for example "merge into dev only through a PR").

## Branch roles

| Branch | Holds | Rule |
|---|---|---|
| `main` | released code | never develop here; release builds come only from a pushed, clean `main` commit |
| `dev` | integration | every change enters here first; the main checkout stays on `dev`, clean and equal to `origin/dev` |
| `<type>/<task>` | one task | `feat/`, `fix/`, `docs/`, `chore/`; one task = one branch = one worktree |
| `vX.Y.Z` tag | a release | annotated tag on `main`; the release counts only when its assets are verified |

No `dev` branch in the repository? Use the default branch in its place. Do not invent a branch scheme.

## Task lifecycle

1. **Start**
   ```bash
   git fetch origin
   git worktree add -b fix/<task> ../<repo>-wt-<task> origin/dev
   ```
   Note the base revision. Never start from an unfetched local `dev`.
2. **Develop** in that worktree only. Small commits, one thing each, message says what is done.
   Run the checks that cover the change. Stage named files — never `git add -A` / `git add .`.
3. **Merge**
   - Bring the branch up to date with the latest `origin/dev` and resolve conflicts on the task branch.
   - Re-run the checks, merge into `dev` (or open a PR to `dev` if the repo requires it), push, and note the `dev` revision.
   - Report it as "merged into dev at `<rev>`, waiting for release". Never call it released.
   - Not merged yet? Then it is "waiting for integration", not done.
4. **Clean up — in the same turn, not later**
   ```bash
   git worktree remove ../<repo>-wt-<task>
   git branch -d fix/<task>
   git push origin --delete fix/<task>   # if it was pushed
   git worktree prune
   ```
   Before removing, all four must hold:
   - no uncommitted or untracked files
   - no process uses the directory (`lsof +D <dir>`)
   - the branch is contained in `origin/dev`
   - no stash belongs to it

   Afterwards confirm with `git worktree list` and `git branch -vv`.

   Run `scripts/wt-status.sh` to see what is safe to remove; it only reports.

   Another session's worktree or branch, or anything that fails a check: list it and ask. Never delete it.
5. **Release** — only when the user names a version.
   1. Freeze a verified `dev` revision and merge it into `main`.
   2. Build from a clean checkout of the pushed `main` commit.
   3. Create an annotated tag `vX.Y.Z` and publish the release.
   4. Download or read back the published assets and check their SHA-256.
   5. Merge `main` back into `dev` if the release added commits.

   A tag without verified assets, or a draft release, is not a release.

## Working beside other agents

- One writer per set of files at a time. Do not edit, reset, switch or delete another session's worktree.
- Before merging into `dev`, check whether `dev` moved since your base. If it did, sync and re-check first.
- No `git reset --hard`, no force push, no rewriting shared history unless the user asks for exactly that.
- The main checkout is for integration, builds and installs only. Keep it on `dev`, clean, not detached, and tracking the remote that is actually maintained.
- Builds and installs that others will use come from the main checkout's clean, committed `dev` (or `main` for releases), never from a task worktree.

## Checklist before saying "done"

- [ ] change merged into `dev` and pushed; `dev` revision noted
- [ ] my worktree removed, my task branch deleted locally and on the remote, `git worktree prune` run
- [ ] `git worktree list` shows no worktree of mine; main checkout on `dev`, clean, equal to `origin/dev`
- [ ] anything left over (someone else's, or failing a check) listed for the user
