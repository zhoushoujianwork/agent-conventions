#!/usr/bin/env bash
# Install the branch-flow Skill for every agent tool found on this machine.
#
#   curl -fsSL https://raw.githubusercontent.com/zhoushoujianwork/branch-flow/main/install.sh | bash
#   ./install.sh [--ref <tag|branch>] [--only claude,codex,agy,gemini,agents] [--copy] [--uninstall] [--dry-run]
#
# One copy lives in ~/.agents/skills/branch-flow; each tool's skill folder gets a symlink to it
# (a copy with --copy, or where symlinks are not available). Tool folders that do not exist are skipped.
set -euo pipefail

REPO="zhoushoujianwork/branch-flow" NAME="branch-flow"
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
canonical="$home/.agents/skills/$NAME"
# tool id | skill folder | folder whose presence means the tool is installed
targets="claude|$home/.claude/skills|$home/.claude
codex|$home/.codex/skills|$home/.codex
agy|$home/.gemini/antigravity/skills|$home/.gemini/antigravity
gemini|$home/.gemini/skills|$home/.gemini"

run() { if [ "$dry" = 1 ]; then echo "+ $*"; else "$@"; fi; }
wanted() { [ -z "$only" ] || case ",$only," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) copy=1 ;; esac

if [ "$uninstall" = 1 ]; then
  printf '%s\n' "$targets" | while IFS='|' read -r id dir _; do
    wanted "$id" || continue
    if [ -L "$dir/$NAME" ] || [ -f "$dir/$NAME/.branch-flow" ]; then run rm -rf "$dir/$NAME"; echo "removed  $id: $dir/$NAME"; fi
  done
  if wanted agents && [ -f "$canonical/.branch-flow" ]; then run rm -rf "$canonical"; echo "removed  agents: $canonical"; fi
  exit 0
fi

# Source: this checkout when run from it, otherwise the requested ref from GitHub.
here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd -P || true)"
tmp=""
if [ -n "$here" ] && [ -f "$here/skills/$NAME/SKILL.md" ]; then src="$here/skills/$NAME"
else
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "https://github.com/$REPO/archive/$ref.tar.gz" | tar -xz -C "$tmp"
  src="$(find "$tmp" -maxdepth 4 -type d -path "*/skills/$NAME" | head -1)"
  [ -n "$src" ] && [ -f "$src/SKILL.md" ] || { echo "download did not contain skills/$NAME" >&2; exit 1; }
fi
version="$(sed -n 's/^  version: "\(.*\)"/\1/p' "$src/SKILL.md" | head -1)"

# The shared copy. Replace only a previous branch-flow install, never someone else's folder.
if [ -e "$canonical" ] && [ ! -f "$canonical/.branch-flow" ]; then
  echo "refusing to overwrite $canonical: it was not installed by branch-flow" >&2; exit 1
fi
run mkdir -p "$(dirname "$canonical")"
run rm -rf "$canonical.new"
run cp -R "$src" "$canonical.new"
[ "$dry" = 1 ] || echo "$version" > "$canonical.new/.branch-flow"
run rm -rf "$canonical"
run mv "$canonical.new" "$canonical"
[ "$dry" = 1 ] || chmod +x "$canonical/scripts/"*.sh
echo "installed agents: $canonical ($version)"

printf '%s\n' "$targets" | while IFS='|' read -r id dir marker; do
  wanted "$id" || continue
  [ -d "$marker" ] || { echo "skipped  $id: $marker not found"; continue; }
  dest="$dir/$NAME"
  if [ -e "$dest" ] && [ ! -f "$dest/.branch-flow" ]; then
    echo "skipped  $id: $dest exists and was not installed by branch-flow"; continue
  fi
  run mkdir -p "$dir"
  run rm -rf "$dest"
  if [ "$copy" = 1 ]; then run cp -R "$canonical" "$dest"; else run ln -s "$canonical" "$dest"; fi
  echo "installed $id: $dest"
done
