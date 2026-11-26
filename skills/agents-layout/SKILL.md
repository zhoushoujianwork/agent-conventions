---
name: agents-layout
description: One source of truth for AI agent instructions and Skills in a repository — AGENTS.md and .agents/skills are the real files, Claude Code gets relative symlinks (CLAUDE.md, .claude/skills). Use when setting up a repository for AI agents, adding a Skill, editing CLAUDE.md/AGENTS.md/GEMINI.md, or when the user says clean, 收尾, wrap up or asks whether the repo is tidy.
metadata:
  version: "0.2.0"
---

# agents-layout

Every kind of agent content has **one real copy**. Tools that cannot read it get a **relative symlink**, never a second copy that drifts.

## Where each tool looks (checked against the official docs, 2026-11)

| Tool | Project instructions | Project Skills |
|---|---|---|
| Codex | `AGENTS.md` | `.agents/skills/` |
| Antigravity | `AGENTS.md` (or `GEMINI.md`) | `.agents/skills/` |
| Gemini CLI | `GEMINI.md` | `.agents/skills/` (alias of `.gemini/skills/`) |
| Claude Code | `CLAUDE.md`; `AGENTS.md` only when no `CLAUDE.md` exists in this or a parent folder | `.claude/skills/` only |

## The layout

| Content | Real copy | Links |
|---|---|---|
| Instructions | `AGENTS.md` (root and any subfolder) | `CLAUDE.md -> AGENTS.md` beside each one; `GEMINI.md -> AGENTS.md` only if Gemini CLI is still used |
| Skills | `.agents/skills/<name>/SKILL.md` | `.claude/skills -> ../.agents/skills` |
| One tool's own config | real files in its folder (`.claude/settings.json`, `.codex/config.toml` …) | never linked |

## Rules

- Edit only `AGENTS.md` and `.agents/skills/`; never edit through a link or keep a second copy. Notes for one tool go in a section of `AGENTS.md`.
- Link the `skills` subfolder, never a whole tool folder (`.claude -> .agents` would mix Claude's settings into `.agents`).
- Links are relative so they survive a clone. Commit the links themselves.
- Windows: Git needs `core.symlinks=true` (and Developer Mode or admin rights). Without it Git checks links out as small text files; fix the setting, do not replace links with copies.
- A real `CLAUDE.md` or `.claude/skills` that differs from the real copy is a conflict for a person to merge. Never overwrite it.

## Check

```bash
~/.agents/skills/agents-layout/scripts/agents-layout.sh -C <repo>           # report only
~/.agents/skills/agents-layout/scripts/agents-layout.sh -C <repo> --apply   # also create missing links
```

The script reports `OK`, `MISSING` (a link can be created), `CONFLICT` (a real file or folder is in the way) or `BROKEN`.

- `--apply` creates only `MISSING` links and touches nothing else.
- Make layout fixes in a task branch (see the `branch-flow` Skill), not directly on `dev`.

When the user says **clean / 收尾 / wrap up** in a repository, run this check together with the `branch-flow` cleanup report (`wt-status.sh`). Report both results, then fix only what is safe.
