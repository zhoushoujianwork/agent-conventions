# branch-flow

Two tiny Agent Skills for **one person working with several AI coding agents** (Claude Code, Codex,
Antigravity, Gemini CLI …) in the same repositories.

**[`branch-flow`](skills/branch-flow/SKILL.md): Git conventions**
- `main` holds releases and `dev` integrates.
- Every task gets its own branch **and worktree** from `origin/dev`.
- Finished work is merged into `dev` and reported as "merged, waiting for release", never "released".
- The task's worktree and branch are **removed in the same turn**, after four safety checks.
- Releases happen only when a person names a version: `dev` → `main` → annotated tag → verified assets.

**[`agents-layout`](skills/agents-layout/SKILL.md): one source of truth for agent files**
- `AGENTS.md` and `.agents/skills/` are the real files; Codex, Antigravity and Gemini CLI read them directly.
- Claude Code gets relative symlinks: `CLAUDE.md -> AGENTS.md` and `.claude/skills -> ../.agents/skills`.
- Each tool's own settings stay real files and are never linked.

Say **clean**, **收尾** or **wrap up** in a repository and the agent runs both checks and reports what is
left over and what is out of place. A repository's own `AGENTS.md` overrides these rules where it is stricter.

## Install

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/zhoushoujianwork/branch-flow/main/install.sh | bash
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/zhoushoujianwork/branch-flow/main/install.ps1 | iex
```

The real copies go to `~/.agents/skills/<skill>`. Tools that need their own folder get a link (copies on Windows):

| Tool | Reads Skills from |
|---|---|
| Codex | `~/.agents/skills` (directly) |
| Gemini CLI | `~/.agents/skills` (directly) |
| Antigravity | `~/.gemini/config/skills` (link), legacy `~/.gemini/antigravity/skills` (link) |
| Claude Code | `~/.claude/skills` (link) |

Options for `install.sh`:
- `--ref v0.2.0` pins a release instead of `main`.
- `--only claude,agy` limits which tools get links.
- `--copy` installs copies instead of links.
- `--dry-run` shows what would happen.
- `--uninstall` removes everything it installed.

The installer never touches a folder it did not create. Reinstalling removes the extra `~/.codex/skills` and
`~/.gemini/skills` links that v0.1.0 created, since those tools already read `~/.agents/skills`.

## The two checks

```bash
~/.agents/skills/branch-flow/scripts/wt-status.sh -C path/to/repo [--fetch]
~/.agents/skills/agents-layout/scripts/agents-layout.sh -C path/to/repo [--apply]
```

**`wt-status.sh`** labels every worktree and task branch:

| Label | Meaning |
|---|---|
| `REMOVABLE` | Clean, contained in `origin/dev`, no stash, not in use. |
| `KEEP` | Fails a check; the reason is shown. |
| `LONG-LIVED` | `main` or `dev`. |

It prints the exact commands for the removable items and deletes nothing itself.

**`agents-layout.sh`** labels every instruction file and Skill folder:

| Label | Meaning | `--apply` |
|---|---|---|
| `OK` | Already correct. | — |
| `MISSING` | A link is missing. | creates the link |
| `DUPLICATE` | An identical copy instead of a link. | replaces it with a link |
| `ADOPT` | `CLAUDE.md` or `.claude/skills` is the only copy. | moves it to `AGENTS.md` / `.agents/skills` and links back |
| `CONFLICT` | Content differs, or the wrong thing is linked. | never touched; needs a person |
| `BROKEN` | The link points nowhere. | never touched; needs a person |

Where each tool looks was checked against the official docs in 2026-11; see the table in
[`agents-layout`](skills/agents-layout/SKILL.md).

## Development

This repository follows its own rules: work on a task branch from `dev`, merge into `dev`, release from `main` with a tag.

```bash
bash tests/run.sh
```

MIT licensed.

---

**中文简介**：两个给“个人 + 多个 AI Agent”用的约定 Skill。
- **`branch-flow`** 管 Git：`main` 放发布，`dev` 做集成，每个任务用独立分支和 worktree，合入 `dev` 后同一轮回收，只有人指定版本时才发布。
- **`agents-layout`** 管 Agent 文件：`AGENTS.md` 和 `.agents/skills` 是唯一真实副本，Claude Code 用相对软链接入。
- 在仓库里说“clean”“收尾”或“wrap up”时，同时运行两项检查。
