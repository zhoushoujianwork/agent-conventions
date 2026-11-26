#!/usr/bin/env bash
# Self-contained tests: a throwaway repository for wt-status.sh and a throwaway HOME for install.sh.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd -P)"
tmp="$(cd "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if printf '%s' "$2" | grep -qE "$3"; then echo "ok   - $1"; else echo "FAIL - $1"; printf '%s\n' "$2" | sed 's/^/     /'; fail=1; fi; }
absent() { if printf '%s' "$2" | grep -qE "$3"; then echo "FAIL - $1"; fail=1; else echo "ok   - $1"; fi; }
g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@"; }

# --- wt-status.sh -----------------------------------------------------------
g init -q --bare "$tmp/origin.git"
g clone -q "$tmp/origin.git" "$tmp/repo" 2>/dev/null
cd "$tmp/repo"
echo a > a; g add a; g commit -qm init; g push -q origin HEAD:main
g checkout -qb dev; g push -q -u origin dev
for t in merged dirty open; do g worktree add -q -b "fix/$t" "$tmp/wt-$t" origin/dev; done
(cd "$tmp/wt-merged" && echo m > m && g add m && g commit -qm merged)
g merge -q --no-ff fix/merged -m "merge fix/merged"; g push -q origin dev
(cd "$tmp/wt-dirty" && echo d > d)
(cd "$tmp/wt-open" && echo o > o && g add o && g commit -qm open)
g branch -q fix/stale-merged fix/merged
g worktree add -q "$tmp/wt-main" main
out="$(bash "$root/skills/branch-flow/scripts/wt-status.sh" -C "$tmp/repo" --no-lsof)"
check "base is origin/dev" "$out" "base: +origin/dev"
check "main checkout healthy" "$out" "main checkout: .*\[dev\] ok"
check "merged clean worktree is removable" "$out" "REMOVABLE +fix/merged .*wt-merged"
check "dirty worktree kept" "$out" "KEEP +fix/dirty .*\(dirty\)"
check "unmerged worktree kept" "$out" "KEEP +fix/open .*not-in-base"
check "main worktree shown as long-lived" "$out" "LONG-LIVED +main .*wt-main"
check "merged branch without worktree removable" "$out" "REMOVABLE +fix/stale-merged"
check "commands printed" "$out" "git worktree remove '$tmp/wt-merged'"
absent "never suggests removing kept work" "$out" "worktree remove '$tmp/wt-(dirty|open)'"
(cd "$tmp/repo" && echo x > x)
out="$(bash "$root/skills/branch-flow/scripts/wt-status.sh" -C "$tmp/repo" --no-lsof)"
check "dirty main checkout reported" "$out" "main checkout: .*uncommitted changes"
[ -d "$tmp/wt-merged" ] && echo "ok   - report deleted nothing" || { echo "FAIL - report deleted a worktree"; fail=1; }

# --- install.sh --------------------------------------------------------------
h="$tmp/home"; mkdir -p "$h/.claude" "$h/.codex" "$h/.gemini/antigravity"
out="$(BRANCH_FLOW_HOME="$h" bash "$root/install.sh")"
check "shared copy installed" "$out" "installed agents: $h/.agents/skills/branch-flow"
check "claude linked" "$out" "installed claude"
check "codex linked" "$out" "installed codex"
check "agy linked" "$out" "installed agy"
check "gemini (parent folder present) linked" "$out" "installed gemini"
[ -L "$h/.claude/skills/branch-flow" ] && [ -f "$h/.claude/skills/branch-flow/SKILL.md" ] && echo "ok   - claude link resolves" || { echo "FAIL - claude link"; fail=1; }
[ -x "$h/.agents/skills/branch-flow/scripts/wt-status.sh" ] && echo "ok   - script executable" || { echo "FAIL - script not executable"; fail=1; }
h2="$tmp/home2"; mkdir -p "$h2/.claude/skills/branch-flow"; echo mine > "$h2/.claude/skills/branch-flow/SKILL.md"
out="$(BRANCH_FLOW_HOME="$h2" bash "$root/install.sh" --only claude)"
check "foreign folder left alone" "$out" "skipped +claude: .* not installed by branch-flow"
[ "$(cat "$h2/.claude/skills/branch-flow/SKILL.md")" = mine ] && echo "ok   - foreign content intact" || { echo "FAIL - foreign content changed"; fail=1; }
out="$(BRANCH_FLOW_HOME="$h" bash "$root/install.sh" --copy --only codex)"
[ -d "$h/.codex/skills/branch-flow" ] && [ ! -L "$h/.codex/skills/branch-flow" ] && echo "ok   - --copy makes a real copy" || { echo "FAIL - --copy"; fail=1; }
out="$(BRANCH_FLOW_HOME="$h" bash "$root/install.sh" --uninstall)"
[ ! -e "$h/.claude/skills/branch-flow" ] && [ ! -e "$h/.codex/skills/branch-flow" ] && [ ! -e "$h/.agents/skills/branch-flow" ] \
  && echo "ok   - uninstall removes every install" || { echo "FAIL - uninstall"; fail=1; }

exit "$fail"
