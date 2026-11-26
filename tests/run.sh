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
h="$tmp/home"; mkdir -p "$h/.claude" "$h/.codex/skills" "$h/.gemini/config" "$h/.gemini/antigravity" "$h/.gemini/skills"
# A v0.1.0 install left links in folders that read ~/.agents/skills anyway.
mkdir -p "$h/.agents/skills/branch-flow"; echo 0.1.0 > "$h/.agents/skills/branch-flow/.branch-flow"
ln -s "$h/.agents/skills/branch-flow" "$h/.codex/skills/branch-flow"; ln -s "$h/.agents/skills/branch-flow" "$h/.gemini/skills/branch-flow"
out="$(BRANCH_FLOW_HOME="$h" bash "$root/install.sh")"
check "both skills installed to the shared folder" "$out" "installed agents: .*/branch-flow .*installed agents: .*/agents-layout|installed agents: .*/agents-layout"
check "claude linked" "$out" "installed claude: .*/.claude/skills/agents-layout"
check "antigravity linked" "$out" "installed agy: .*/.gemini/config/skills/branch-flow"
check "antigravity legacy linked" "$out" "installed agy-legacy: .*/.gemini/antigravity/skills/branch-flow"
check "old codex link retired" "$out" "removed  retired: .*/.codex/skills/branch-flow"
[ ! -e "$h/.codex/skills/branch-flow" ] && [ ! -e "$h/.gemini/skills/branch-flow" ] && echo "ok   - no duplicate entries for Codex / Gemini CLI" || { echo "FAIL - retired links left"; fail=1; }
[ -L "$h/.claude/skills/branch-flow" ] && [ -f "$h/.claude/skills/agents-layout/SKILL.md" ] && echo "ok   - claude links resolve" || { echo "FAIL - claude link"; fail=1; }
[ -x "$h/.agents/skills/agents-layout/scripts/agents-layout.sh" ] && [ -x "$h/.agents/skills/branch-flow/scripts/wt-status.sh" ] && echo "ok   - scripts executable" || { echo "FAIL - scripts not executable"; fail=1; }
h2="$tmp/home2"; mkdir -p "$h2/.claude/skills/branch-flow"; echo mine > "$h2/.claude/skills/branch-flow/SKILL.md"
out="$(BRANCH_FLOW_HOME="$h2" bash "$root/install.sh" --only claude)"
check "foreign folder left alone" "$out" "skipped +claude: .*branch-flow exists and was not installed by branch-flow"
[ "$(cat "$h2/.claude/skills/branch-flow/SKILL.md")" = mine ] && echo "ok   - foreign content intact" || { echo "FAIL - foreign content changed"; fail=1; }
out="$(BRANCH_FLOW_HOME="$h" bash "$root/install.sh" --copy --only claude)"
[ -d "$h/.claude/skills/branch-flow" ] && [ ! -L "$h/.claude/skills/branch-flow" ] && echo "ok   - --copy makes a real copy" || { echo "FAIL - --copy"; fail=1; }
out="$(BRANCH_FLOW_HOME="$h" bash "$root/install.sh" --uninstall)"
left="$(find "$h" -name branch-flow -o -name agents-layout)"
[ -z "$left" ] && echo "ok   - uninstall removes every install" || { echo "FAIL - uninstall left: $left"; fail=1; }

# --- agents-layout.sh ---------------------------------------------------------
L="$root/skills/agents-layout/scripts/agents-layout.sh"
mk() { rm -rf "$tmp/l"; mkdir -p "$tmp/l"; (cd "$tmp/l" && g init -q); }
mk; echo rules > "$tmp/l/AGENTS.md"; mkdir -p "$tmp/l/.agents/skills/s1" "$tmp/l/sub"; echo s > "$tmp/l/.agents/skills/s1/SKILL.md"; echo sub > "$tmp/l/sub/AGENTS.md"
out="$(bash "$L" -C "$tmp/l" || true)"
check "missing CLAUDE.md link reported" "$out" "MISSING +CLAUDE.md -> AGENTS.md"
check "nested AGENTS.md covered" "$out" "MISSING +sub/CLAUDE.md"
check "missing .claude/skills link reported" "$out" "MISSING +.claude/skills -> ../.agents/skills"
absent "GEMINI.md not required" "$out" "GEMINI"
out="$(bash "$L" -C "$tmp/l" --apply || true)"
check "apply creates links" "$out" "FIXED +.claude/skills -> ../.agents/skills"
[ "$(readlink "$tmp/l/CLAUDE.md")" = AGENTS.md ] && [ "$(readlink "$tmp/l/sub/CLAUDE.md")" = AGENTS.md ] && [ -f "$tmp/l/.claude/skills/s1/SKILL.md" ] \
  && echo "ok   - links resolve" || { echo "FAIL - links"; fail=1; }
out="$(bash "$L" -C "$tmp/l")" && check "tidy after apply" "$out" "Layout is tidy" || { echo "FAIL - not tidy after apply"; echo "$out"; fail=1; }

mk; echo rules > "$tmp/l/AGENTS.md"; echo other > "$tmp/l/CLAUDE.md"; mkdir -p "$tmp/l/.agents/skills/a" "$tmp/l/.claude/skills/b"
out="$(bash "$L" -C "$tmp/l" --apply || true)"
check "different CLAUDE.md is a conflict" "$out" "CONFLICT +CLAUDE.md differs"
check "different .claude/skills is a conflict naming the extra skill" "$out" "CONFLICT +.claude/skills differs .*only in .claude: b"
[ "$(cat "$tmp/l/CLAUDE.md")" = other ] && [ -d "$tmp/l/.claude/skills/b" ] && echo "ok   - apply leaves conflicts alone" || { echo "FAIL - conflict touched"; fail=1; }

mk; echo rules > "$tmp/l/AGENTS.md"; cp "$tmp/l/AGENTS.md" "$tmp/l/CLAUDE.md"; echo rules > "$tmp/l/GEMINI.md"
out="$(bash "$L" -C "$tmp/l" || true)"
check "identical copy is a duplicate" "$out" "DUPLICATE +CLAUDE.md"
bash "$L" -C "$tmp/l" --apply >/dev/null || true
[ "$(readlink "$tmp/l/CLAUDE.md")" = AGENTS.md ] && [ "$(readlink "$tmp/l/GEMINI.md")" = AGENTS.md ] && echo "ok   - duplicates replaced by links" || { echo "FAIL - duplicates"; fail=1; }

mk; echo only > "$tmp/l/CLAUDE.md"; mkdir -p "$tmp/l/.claude/skills/x"; echo x > "$tmp/l/.claude/skills/x/SKILL.md"
out="$(bash "$L" -C "$tmp/l" || true)"
check "lone CLAUDE.md to adopt" "$out" "ADOPT +CLAUDE.md is the only copy"
check "lone .claude/skills to adopt" "$out" "ADOPT +.claude/skills is the only copy"
bash "$L" -C "$tmp/l" --apply >/dev/null || true
[ "$(cat "$tmp/l/AGENTS.md")" = only ] && [ -L "$tmp/l/CLAUDE.md" ] && [ -f "$tmp/l/.agents/skills/x/SKILL.md" ] && [ -L "$tmp/l/.claude/skills" ] \
  && echo "ok   - adopt moves the real copy and links back" || { echo "FAIL - adopt"; fail=1; }

mk; echo r > "$tmp/l/AGENTS.md"; ln -s AGENTS.md "$tmp/l/CLAUDE.md"; mkdir -p "$tmp/l/.agents/skills"; ln -s .agents "$tmp/l/.claude"
out="$(bash "$L" -C "$tmp/l" || true)"
check "whole-folder .claude link flagged" "$out" "CONFLICT +.claude -> .agents"

exit "$fail"
