#!/usr/bin/env bash
# Detects reviewer writes to the repo: "save" hashes every dirty/untracked file, "check" compares.
# Usage: icm-guard.sh save|check <workdir>   (repo root = the directory that holds .icm/)
set -euo pipefail

usage() { echo "usage: icm-guard.sh save|check <workdir>" >&2; exit 2; }
[ $# -eq 2 ] || usage
mode="$1"; wd="${2%/}"
[ "$mode" = save ] || [ "$mode" = check ] || usage
[ -d "$wd/04_workspace" ] || { echo "not an ICM workdir: $wd" >&2; exit 2; }
repo="$(cd "$wd/../.." && pwd)"
snap="$wd/pre_launch.sha"

if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "GUARD SKIP: $repo is not a git repo"; exit 0
fi

hash_of() { if [ -f "$repo/$1" ]; then sha256sum < "$repo/$1" | cut -d' ' -f1; else echo missing; fi; }

# One "hash<TAB>path" line per modified, deleted, staged or untracked (not ignored) file.
dirty_hashes() {
  { git -C "$repo" ls-files -z -m -o --exclude-standard
    git -C "$repo" diff --cached --name-only --relative -z; } \
    | sort -zu | while IFS= read -r -d '' p; do printf '%s\t%s\n' "$(hash_of "$p")" "$p"; done
}

if [ "$mode" = save ]; then
  dirty_hashes > "$snap"
  echo "GUARD SAVED $(wc -l < "$snap") dirty files"
  exit 0
fi

[ -f "$snap" ] || { echo "no snapshot in $wd: run icm-guard.sh save first" >&2; exit 2; }
declare -A before=() now=()
while IFS=$'\t' read -r h p; do [ -n "$p" ] && before["$p"]="$h"; done < "$snap"
while IFS=$'\t' read -r h p; do [ -n "$p" ] && now["$p"]="$h"; done < <(dirty_hashes)

changed=()
for p in "${!before[@]}"; do [ "$(hash_of "$p")" = "${before[$p]}" ] || changed+=("$p"); done
for p in "${!now[@]}"; do [ -n "${before[$p]+x}" ] || changed+=("$p"); done

if [ "${#changed[@]}" -eq 0 ]; then echo "GUARD OK"; exit 0; fi
printf 'CHANGED %s\n' "${changed[@]}" | sort -u
echo "GUARD CHANGED"
exit 1
