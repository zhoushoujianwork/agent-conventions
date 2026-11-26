# branch-flow

A tiny Agent Skill with Git conventions for **one person working with several AI coding agents**
(Claude Code, Codex, Antigravity, Gemini CLI …) in the same repositories:

- `main` holds releases, `dev` integrates, every task gets its own branch **and worktree** from `origin/dev`;
- finished work is merged into `dev` and reported as "merged, waiting for release" — never "released";
- the task's worktree and branch are **removed in the same turn**, after four safety checks;
- releases happen only when a person names a version: `dev` → `main` → annotated tag → verified assets.

The rules are in [`skills/branch-flow/SKILL.md`](skills/branch-flow/SKILL.md). A repository's own
`AGENTS.md` / `CLAUDE.md` overrides them where it is stricter.

## Install

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/zhoushoujianwork/branch-flow/main/install.sh | bash
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/zhoushoujianwork/branch-flow/main/install.ps1 | iex
```

One copy goes to `~/.agents/skills/branch-flow`; every agent tool found on the machine gets a link to it
(copies on Windows):

| Tool | Skill folder |
|---|---|
| Claude Code | `~/.claude/skills/branch-flow` |
| Codex | `~/.codex/skills/branch-flow` (and the shared `~/.agents/skills`) |
| Antigravity (`agy`) | `~/.gemini/antigravity/skills/branch-flow` |
| Gemini CLI | `~/.gemini/skills/branch-flow` |

Options for `install.sh`:
- `--ref v0.1.0` pins a release instead of `main`.
- `--only claude,codex` limits which tools get it.
- `--copy` installs copies instead of links.
- `--dry-run` shows what would happen.
- `--uninstall` removes it again.

The installer never touches a folder it did not create.

## What is left over?

```bash
~/.agents/skills/branch-flow/scripts/wt-status.sh -C path/to/repo [--fetch]
```

Lists every worktree and task branch with its state:

| State | Meaning |
|---|---|
| `REMOVABLE` | Clean, contained in `origin/dev`, no stash, not in use. |
| `KEEP` | Fails a check; the reason is shown (`dirty`, `not-in-base`, `stash`, `in-use`). |
| `LONG-LIVED` | `main` or `dev`. |

For the removable items it prints the exact `git worktree remove` / `git branch -d` commands to run. It deletes nothing itself.

## Development

This repository follows its own rules: work on a task branch from `dev`, merge into `dev`, release from `main` with a tag.

```bash
bash tests/run.sh
```

MIT licensed.

---

**中文简介**：个人 + 多个 AI Agent 协作开发的 Git 约定 Skill。`main` 放发布，`dev` 做集成。每个任务从 `origin/dev` 开独立分支和 worktree，完成后合入 `dev`，并在同一轮里通过四项安全检查后回收 worktree 和分支。只有人指定版本时才发布，发布顺序是 `dev` → `main` → 附注 tag → 核验资产。一行命令即可安装到 Claude Code、Codex、Antigravity 和 Gemini CLI。
