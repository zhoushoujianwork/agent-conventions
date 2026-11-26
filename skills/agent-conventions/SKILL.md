---
name: agent-conventions
description: Best practice for one person developing with several AI agents (Claude Code, Codex, Antigravity, Gemini CLI). Git — main/dev/task-branch roles, one worktree per task, merge into dev, clean up worktrees and merged branches right away, release only on request. Agent files — AGENTS.md and .agents/skills are the real copies, Claude Code gets relative symlinks. Use when starting, finishing, merging, cleaning up or releasing work in a Git repository, when setting up agent instruction files or Skills, or when the user says clean, 收尾 or wrap up.
metadata:
  version: "0.3.0"
---

# agent-conventions

Simple rules so one person and several AI agents can share repositories without overwriting each other,
leaving debris, or keeping drifting copies of the same instructions. A repository's own `AGENTS.md`
wins where it is stricter (for example "merge into dev only through a PR").

## 1. Branches and worktrees

| Branch | Holds | Rule |
|---|---|---|
| `main` | released code | never develop here; release builds come only from a pushed, clean `main` commit |
| `dev` | integration | every change enters here first; the main checkout stays on `dev`, clean and equal to `origin/dev` |
| `<type>/<task>` | one task | `feat/`, `fix/`, `docs/`, `chore/`; one task = one branch = one worktree |
| `vX.Y.Z` tag | a release | annotated tag on `main`; the release counts only when its assets are verified |

No `dev` branch in the repository? Use the default branch instead. Do not invent a branch scheme.

**Task lifecycle**

1. **Start:** `git fetch origin && git worktree add -b fix/<task> ../<repo>-wt-<task> origin/dev`. Never start from an unfetched local `dev`.
2. **Develop** in that worktree only.
   - Make small commits, one thing each.
   - Run the checks that cover the change.
   - Stage named files; never `git add -A` / `git add .`.
3. **Merge:**
   - Sync the branch with the latest `origin/dev`; resolve conflicts on the task branch.
   - Re-check, merge into `dev` (or open a PR if the repo requires one), and push.
   - Report "merged into dev at `<rev>`, waiting for release", never "released".
4. **Clean up in the same turn:**
   ```bash
   git worktree remove ../<repo>-wt-<task>
   git branch -d fix/<task>
   git push origin --delete fix/<task>
   git worktree prune
   ```
   Remove a worktree only when all four hold:
   - no uncommitted or untracked files
   - no process uses it (`lsof +D`)
   - the branch is contained in `origin/dev`
   - no stash belongs to it

   Another session's leftovers, or anything that fails a check: list it and ask.
5. **Release** only when the user names a version:
   1. Merge a verified `dev` into `main`.
   2. Build from a clean `main` checkout.
   3. Create an annotated tag and publish.
   4. Verify the published assets.

**Working beside other agents**
- One writer per set of files at a time; never touch another session's worktree.
- Before merging into `dev`, check whether it moved since your base.
- No `git reset --hard`, no force push, no rewriting shared history unless the user asks for exactly that.
- Shared builds and installs come from the main checkout's clean `dev` or `main`, never from a task worktree.

## 2. Agent files: one real copy, links for the rest

| Tool | Project instructions | Project Skills |
|---|---|---|
| Codex | `AGENTS.md` | `.agents/skills/` |
| Antigravity | `AGENTS.md` | `.agents/skills/` |
| Gemini CLI | `GEMINI.md` | `.agents/skills/` |
| Claude Code | `CLAUDE.md` (`AGENTS.md` only when no `CLAUDE.md` exists up the tree) | `.claude/skills/` only |

(Checked against the official docs, 2026-11.)

- Real copies: `AGENTS.md` (root and any subfolder) and `.agents/skills/<name>/SKILL.md`.
- Links, relative and committed: `CLAUDE.md -> AGENTS.md` beside every `AGENTS.md`, and `.claude/skills -> ../.agents/skills`. Add `GEMINI.md -> AGENTS.md` only if Gemini CLI is still used.
- Edit only the real copies. Notes for one tool go in a section of `AGENTS.md`, not in a separate file.
- Link the `skills` subfolder, never a whole tool folder. Each tool's own settings (`.claude/settings.json`, `.codex/config.toml` …) stay real files.
- A real `CLAUDE.md` or `.claude/skills` that differs from the real copy is a conflict for a person to merge; never overwrite it.
- Windows: Git needs `core.symlinks=true`. Fix that setting instead of replacing links with copies.

## 3. "clean" / "收尾" / "wrap up"

Run both read-only checks from this Skill's `scripts/` folder (installed at `~/.agents/skills/agent-conventions/`) and report them together:

```bash
scripts/wt-status.sh -C <repo> --fetch      # worktrees and branches: REMOVABLE / KEEP / LONG-LIVED
scripts/agents-layout.sh -C <repo>          # agent files: OK / MISSING / DUPLICATE / ADOPT / CONFLICT / BROKEN
```

Then act only on what is safe:
- Remove the `REMOVABLE` items that are yours, using the commands the report prints.
- Fix `MISSING`, `DUPLICATE` and `ADOPT` items with `agents-layout.sh --apply`, on a task branch.
- List everything else (`KEEP`, `CONFLICT`, `BROKEN`, other sessions' items) for the user.

**Done means:**
- the change is merged into `dev` and pushed, and the `dev` revision is noted
- my worktree and task branch are gone
- the main checkout is on `dev`, clean, and equal to `origin/dev`
- leftovers are listed for the user
