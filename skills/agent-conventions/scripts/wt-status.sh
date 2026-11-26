#!/usr/bin/env bash
# wt-status.sh — report worktrees and task branches, and which are safe to remove.
# Read-only: it never deletes anything; it prints the commands for what passes every check.
#
# usage: wt-status.sh [-C <repo>] [--base <ref>] [--fetch] [--no-lsof]
#   --base   integration ref to compare against (default: origin/dev, else origin/HEAD, else dev/main)
#   --fetch  run `git fetch --prune origin` first
#   --no-lsof  skip the "directory in use" check (it can be slow on large trees)
set -u

repo="." base="" fetch=0 use_lsof=1
while [ $# -gt 0 ]; do
  case "$1" in
    -C) repo="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --fetch) fetch=1; shift ;;
    --no-lsof) use_lsof=0; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

git() { command git -C "$repo" "$@"; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository: $repo" >&2; exit 2; }
[ "$fetch" = 1 ] && git fetch --prune origin >/dev/null 2>&1

if [ -z "$base" ]; then
  for ref in origin/dev "$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)" dev main master; do
    [ -n "$ref" ] && git rev-parse -q --verify "$ref^{commit}" >/dev/null && { base="$ref"; break; }
  done
fi
[ -n "$base" ] || { echo "no integration ref found; pass --base" >&2; exit 2; }

main_wt="$(git worktree list --porcelain | sed -n '1s/^worktree //p')"
stashes="$(git stash list --format='%gs' 2>/dev/null)"

# A branch is in the base when its tip is an ancestor, or every commit has an equivalent patch there (rebase merge).
merged() {
  git merge-base --is-ancestor "$1" "$base" 2>/dev/null && return 0
  [ -z "$(git cherry "$base" "$1" 2>/dev/null | grep '^+')" ]
}
age() { git log -1 --format=%cr "$1" 2>/dev/null; }

echo "repo:  $(cd "$repo" && pwd -P)"
echo "base:  $base ($(git rev-parse --short "$base"))"

# Main checkout health.
mb="$(git -C "$main_wt" symbolic-ref -q --short HEAD || echo DETACHED)"
mdirty="$(git -C "$main_wt" status --porcelain 2>/dev/null | head -1)"
mnote="ok"
[ "$mb" = DETACHED ] && mnote="detached HEAD"
[ -n "$mdirty" ] && mnote="uncommitted changes"
if [ "$mnote" = ok ] && [ "$mb" != DETACHED ]; then
  up="$(git -C "$main_wt" rev-parse -q --verify '@{upstream}' 2>/dev/null)"
  [ -z "$up" ] && mnote="no upstream"
  [ -n "$up" ] && [ "$(git -C "$main_wt" rev-parse HEAD)" != "$up" ] && mnote="not equal to upstream"
fi
echo "main checkout: $main_wt [$mb] $mnote"
echo

safe_cmds=""
checked_branches=" "
printf '%-10s %-34s %-12s %s\n' STATUS BRANCH AGE WORKTREE
path="" branch="" detached=0
report_wt() {
  [ -z "$path" ] && return
  [ "$path" = "$main_wt" ] && { path=""; return; }
  local ref reasons="" status
  if [ "$detached" = 1 ]; then ref="$(git -C "$path" rev-parse HEAD 2>/dev/null)"; branch="(detached)"; else ref="$branch"; fi
  checked_branches="$checked_branches$branch "
  case "$branch" in main|master|dev|develop)
    printf '%-10s %-34s %-12s %s\n' LONG-LIVED "$branch" "$(age "$ref")" "$path"; path=""; branch=""; detached=0; return ;;
  esac
  [ -d "$path" ] || reasons="${reasons}missing-dir,"
  [ -d "$path" ] && [ -n "$(git -C "$path" status --porcelain --untracked-files=all 2>/dev/null | head -1)" ] && reasons="${reasons}dirty,"
  merged "$ref" || reasons="${reasons}not-in-base,"
  [ "$detached" = 0 ] && printf '%s\n' "$stashes" | grep -q "on $branch:" && reasons="${reasons}stash,"
  if [ "$use_lsof" = 1 ] && [ -d "$path" ] && command -v lsof >/dev/null 2>&1 && [ -n "$(lsof -t +D "$path" 2>/dev/null | head -1)" ]; then reasons="${reasons}in-use,"; fi
  if [ -z "$reasons" ]; then
    status="REMOVABLE"
    safe_cmds="${safe_cmds}git worktree remove '$path'"$'\n'
    if [ "$detached" = 0 ]; then
      safe_cmds="${safe_cmds}git branch -d '$branch'"$'\n'
      git rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null && safe_cmds="${safe_cmds}git push origin --delete '$branch'"$'\n'
    fi
  else status="KEEP"; fi
  printf '%-10s %-34s %-12s %s %s\n' "$status" "$branch" "$(age "$ref")" "$path" "${reasons:+(${reasons%,})}"
  path=""; branch=""; detached=0
}
while IFS= read -r line; do
  case "$line" in
    "worktree "*) report_wt; path="${line#worktree }" ;;
    "branch refs/heads/"*) branch="${line#branch refs/heads/}" ;;
    detached) detached=1 ;;
  esac
done < <(git worktree list --porcelain; echo)
report_wt

# Branches without a worktree (skip the long-lived ones).
for b in $(git for-each-ref --format='%(refname:short)' refs/heads); do
  case "$b" in main|master|dev|develop) continue ;; esac
  case "$checked_branches" in *" $b "*) continue ;; esac
  [ "$b" = "$mb" ] && continue
  reasons=""
  merged "$b" || reasons="not-in-base,"
  printf '%s\n' "$stashes" | grep -q "on $b:" && reasons="${reasons}stash,"
  if [ -z "$reasons" ]; then
    status="REMOVABLE"; safe_cmds="${safe_cmds}git branch -d '$b'"$'\n'
    git rev-parse -q --verify "refs/remotes/origin/$b" >/dev/null && safe_cmds="${safe_cmds}git push origin --delete '$b'"$'\n'
  else status="KEEP"; fi
  printf '%-10s %-34s %-12s %s %s\n' "$status" "$b" "$(age "$b")" "-" "${reasons:+(${reasons%,})}"
done

echo
if [ -n "$safe_cmds" ]; then
  echo "Passes every check (clean, contained in $base, no stash, not in use). Review, then run:"
  printf '%s' "$safe_cmds"
  echo "git worktree prune"
else
  echo "Nothing is safe to remove automatically."
fi
echo "KEEP items: ask the owner first. Squash-merged branches show not-in-base: confirm the PR before deleting."
