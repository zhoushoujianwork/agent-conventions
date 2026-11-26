#!/usr/bin/env bash
# Install the Skills in this repository (branch-flow, agents-layout) for every agent tool on this machine.
#
#   curl -fsSL https://raw.githubusercontent.com/zhoushoujianwork/branch-flow/main/install.sh | bash
#   ./install.sh [--ref <tag|branch>] [--only claude,agy] [--copy] [--uninstall] [--dry-run]
#
# The real copies live in ~/.agents/skills/<skill>, which Codex, Gemini CLI and Antigravity's CLI read natively.
# Claude Code (~/.claude/skills) and Antigravity (~/.gemini/config/skills, legacy ~/.gemini/antigravity/skills)
# get symlinks — copies with --copy or on Windows. Tools that are not installed are skipped.
set -euo pipefail

REPO="zhoushoujianwork/branch-flow" MARK=".branch-flow"
ref="main" only="" copy=0 uninstall=0 dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    --only) only="$2"; shift 2 ;;
    --copy) copy=1; shift ;;
    --uninstall) uninstall=1; shift ;;
    --dry-run) dry=1; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

home="${BRANCH_FLOW_HOME:-$HOME}"
shared="$home/.agents/skills"
# tool id | skill folder | folder whose presence means the tool is installed
targets="claude|$home/.claude/skills|$home/.claude
agy|$home/.gemini/config/skills|$home/.gemini/config
agy-legacy|$home/.gemini/antigravity/skills|$home/.gemini/antigravity"
# Folders v0.1.0 linked into that read ~/.agents/skills anyway: our own entries there are removed.
retired="$home/.codex/skills $home/.gemini/skills"

run() { if [ "$dry" = 1 ]; then echo "+ $*"; else "$@"; fi; }
wanted() { [ -z "$only" ] || case ",$only," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
ours() { [ -f "$1/$MARK" ]; }   # follows links: true for our copy or a link to it
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) copy=1 ;; esac

drop_retired() {  # $1 = skill name; removes our copy or a link (ours, or dangling) only
  for dir in $retired; do
    entry="$dir/$1"
    if ours "$entry" || { [ -L "$entry" ] && [ ! -e "$entry" ]; }; then run rm -rf "$entry"; echo "removed  retired: $entry"; fi
  done
}

if [ "$uninstall" = 1 ]; then
  for skill in branch-flow agents-layout; do
    printf '%s\n' "$targets" | while IFS='|' read -r id dir _; do
      wanted "$id" || continue
      if ours "$dir/$skill" || { [ -L "$dir/$skill" ] && [ ! -e "$dir/$skill" ]; }; then run rm -rf "$dir/$skill"; echo "removed  $id: $dir/$skill"; fi
    done
    drop_retired "$skill"
    if [ -z "$only" ] && ours "$shared/$skill"; then run rm -rf "$shared/$skill"; echo "removed  agents: $shared/$skill"; fi
  done
  exit 0
fi

# Source: this checkout when run from it, otherwise the requested ref from GitHub.
here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd -P || true)"
if [ -n "$here" ] && [ -f "$here/skills/branch-flow/SKILL.md" ]; then src="$here/skills"
else
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "https://github.com/$REPO/archive/$ref.tar.gz" | tar -xz -C "$tmp"
  src="$(find "$tmp" -maxdepth 2 -type d -name skills | head -1)"
  [ -n "$src" ] && [ -f "$src/branch-flow/SKILL.md" ] || { echo "download did not contain skills/" >&2; exit 1; }
fi

for path in "$src"/*/; do
  skill="$(basename "$path")"; [ -f "$path/SKILL.md" ] || continue
  version="$(sed -n 's/^  version: "\(.*\)"/\1/p' "$path/SKILL.md" | head -1)"
  real="$shared/$skill"
  # Replace only a previous install of ours, never someone else's folder.
  if [ -e "$real" ] && ! ours "$real"; then echo "refusing to overwrite $real: not installed by branch-flow" >&2; exit 1; fi
  run mkdir -p "$shared"
  run rm -rf "$real.new"
  run cp -R "${path%/}" "$real.new"
  [ "$dry" = 1 ] || { echo "$version" > "$real.new/$MARK"; chmod +x "$real.new/scripts/"*.sh 2>/dev/null || true; }
  run rm -rf "$real"
  run mv "$real.new" "$real"
  echo "installed agents: $real ($version), read directly by Codex, Gemini CLI and Antigravity CLI"
  drop_retired "$skill"

  printf '%s\n' "$targets" | while IFS='|' read -r id dir marker; do
    wanted "$id" || continue
    [ -d "$marker" ] || { echo "skipped  $id: $marker not found"; continue; }
    dest="$dir/$skill"
    if { [ -e "$dest" ] || [ -L "$dest" ]; } && ! ours "$dest" && [ -e "$dest" ]; then
      echo "skipped  $id: $dest exists and was not installed by branch-flow"; continue
    fi
    run mkdir -p "$dir"
    run rm -rf "$dest"
    if [ "$copy" = 1 ]; then run cp -R "$real" "$dest"; else run ln -s "$real" "$dest"; fi
    echo "installed $id: $dest"
  done
done
