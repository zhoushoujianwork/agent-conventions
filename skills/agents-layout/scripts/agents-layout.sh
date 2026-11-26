#!/usr/bin/env bash
# agents-layout.sh — check that AGENTS.md / .agents/skills are the real copies and Claude Code gets links.
# usage: agents-layout.sh [-C <repo>] [--apply]
#   Report only by default. --apply creates missing links, replaces exact duplicates with links and adopts a
#   lone CLAUDE.md / .claude/skills as the real copy. It never touches a CONFLICT (different content).
set -u
repo="." apply=0
while [ $# -gt 0 ]; do
  case "$1" in
    -C) repo="$2"; shift 2 ;;
    --apply) apply=1; shift ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
root="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repository: $repo" >&2; exit 2; }
cd "$root" || exit 2
problems=0 changed=0
say() { printf '%-9s %s\n' "$1" "$2"; case "$1" in OK|FIXED|INFO) ;; *) problems=$((problems + 1)) ;; esac; }
fixed() { printf '%-9s %s\n' FIXED "$1"; changed=$((changed + 1)); }
# The target a link resolves to, relative to its folder, without following further.
points_to() { [ -L "$1" ] && readlink "$1"; }
same_content() { [ -e "$1" ] && [ -e "$2" ] && diff -rq "$1" "$2" >/dev/null 2>&1; }

echo "repo: $root"
[ "$(git config --bool core.symlinks 2>/dev/null || echo true)" = false ] && say WARN "core.symlinks=false: Git writes links as text files here; enable it before committing links"

# --- Instructions: every AGENTS.md / CLAUDE.md folder (tracked or untracked, ignored files skipped).
dirs="$(git ls-files -co --exclude-standard | grep -E '(^|/)(AGENTS|CLAUDE|GEMINI)\.md$' | sed -E 's#(^|/)[^/]+$##; s#^$#.#' | sort -u)"
for d in $dirs; do
  a="$d/AGENTS.md" c="$d/CLAUDE.md" g="$d/GEMINI.md"
  [ "$d" = . ] && { a=AGENTS.md c=CLAUDE.md g=GEMINI.md; }
  if [ ! -e "$a" ] && [ ! -L "$a" ]; then
    if [ -f "$c" ] && [ ! -L "$c" ]; then
      if [ "$apply" = 1 ]; then mv "$c" "$a" && ln -s AGENTS.md "$c" && fixed "$a (adopted from CLAUDE.md, CLAUDE.md now links to it)"
      else say ADOPT "$c is the only copy: move it to AGENTS.md and link CLAUDE.md -> AGENTS.md"; fi
    fi
    continue
  fi
  [ -L "$a" ] && { say CONFLICT "$a is a link; AGENTS.md must be the real file"; continue; }
  for link in "$c" "$g"; do
    name="${link##*/}"
    if [ -L "$link" ]; then
      if [ "$(points_to "$link")" = AGENTS.md ]; then say OK "$link -> AGENTS.md"
      elif [ ! -e "$link" ]; then say BROKEN "$link -> $(points_to "$link")"
      else say CONFLICT "$link -> $(points_to "$link") (should point to AGENTS.md)"; fi
    elif [ -f "$link" ]; then
      if same_content "$link" "$a"; then
        if [ "$apply" = 1 ]; then rm "$link" && ln -s AGENTS.md "$link" && fixed "$link (identical copy replaced by link)"
        else say DUPLICATE "$link is an identical copy of AGENTS.md: replace it with a link"; fi
      else say CONFLICT "$link differs from AGENTS.md: merge it into AGENTS.md by hand, then link"; fi
    elif [ "$name" = CLAUDE.md ]; then
      if [ "$apply" = 1 ]; then ln -s AGENTS.md "$link" && fixed "$link -> AGENTS.md"
      else say MISSING "$link -> AGENTS.md"; fi
    fi
  done
done
[ -z "$dirs" ] && say INFO "no AGENTS.md / CLAUDE.md in this repository"

# --- Skills: .agents/skills is real; .claude/skills links to it.
real=.agents/skills claude=.claude/skills
if [ -L .claude ]; then say CONFLICT ".claude -> $(points_to .claude): link only .claude/skills, keep .claude a real folder for Claude's own settings"
elif [ -L "$real" ] || [ -L .agents ]; then say CONFLICT "$real must be a real folder"
elif [ -d "$real" ]; then
  if [ -L "$claude" ]; then
    if [ "$(points_to "$claude")" = ../.agents/skills ]; then say OK "$claude -> ../.agents/skills"
    elif [ ! -e "$claude" ]; then say BROKEN "$claude -> $(points_to "$claude")"
    else say CONFLICT "$claude -> $(points_to "$claude") (should point to ../.agents/skills)"; fi
  elif [ -d "$claude" ]; then
    if same_content "$claude" "$real"; then
      if [ "$apply" = 1 ]; then rm -rf "$claude" && ln -s ../.agents/skills "$claude" && fixed "$claude (identical copy replaced by link)"
      else say DUPLICATE "$claude is an identical copy of $real: replace it with a link"; fi
    else
      only="$(cd "$claude" && ls -1 | while read -r s; do [ -e "../../$real/$s" ] || printf '%s ' "$s"; done)"
      say CONFLICT "$claude differs from $real${only:+ (only in .claude: $only)}: move or merge into $real, then link"
    fi
  else
    if [ "$apply" = 1 ]; then mkdir -p .claude && ln -s ../.agents/skills "$claude" && fixed "$claude -> ../.agents/skills"
    else say MISSING "$claude -> ../.agents/skills"; fi
  fi
elif [ -d "$claude" ] && [ ! -L "$claude" ]; then
  if [ "$apply" = 1 ]; then mkdir -p .agents && mv "$claude" "$real" && ln -s ../.agents/skills "$claude" && fixed "$real (adopted from .claude/skills, which now links to it)"
  else say ADOPT "$claude is the only copy: move it to $real and link $claude -> ../.agents/skills"; fi
else say INFO "no project Skills"
fi

echo
if [ "$changed" -gt 0 ]; then echo "$changed change(s) made. Review with git status and commit them on a task branch."; fi
if [ "$problems" -eq 0 ]; then echo "Layout is tidy."; else echo "$problems item(s) need attention. CONFLICT items need a person to merge; --apply never touches them."; fi
[ "$problems" -eq 0 ]
