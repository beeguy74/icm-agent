#!/usr/bin/env bash
# Pre-launch gate for an ICM workdir: one line per problem, then CHECK OK or CHECK FAILED.
# Usage: icm-check.sh <workdir>
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: icm-check.sh <workdir>" >&2; exit 2; }
wd="${1%/}"
[ -d "$wd/04_workspace/input" ] || { echo "not an ICM workdir: $wd" >&2; exit 2; }
fail=0

for f in 00_system.md 01_project.md 02_persona.md 03_task_execution.md launch_prompt.md; do
  [ -f "$wd/$f" ] || { echo "MISSING LAYER $f"; fail=1; }
done

mapfile -t md < <(find "$wd" -maxdepth 1 -name '0?_*.md'; find "$wd/04_workspace/input" -name '*.md')
if [ "${#md[@]}" -gt 0 ]; then
  # A backticked `[INSERT:` is quoted text, not a placeholder; templates never backtick theirs.
  hits="$(grep -HnE '(^|[^`])\[INSERT:' "${md[@]}" || true)"
  [ -z "$hits" ] || { printf '%s\n' "$hits" | sed 's/^/PLACEHOLDER /'; fail=1; }
fi

while IFS= read -r -d '' f; do echo "EMPTY INPUT $f"; fail=1; done \
  < <(find "$wd/04_workspace/input" -type f -empty -print0)

if [ -f "$wd/launch_prompt.md" ] && grep -qF '{{WORKDIR}}' "$wd/launch_prompt.md"; then
  echo "UNRENDERED launch_prompt.md"; fail=1
fi

manifest="$wd/04_workspace/input/targets.md"
if [ -f "$manifest" ]; then
  # Path lines: "- /abs[:L1-L2] note", "- `/abs with spaces` note", "- Working directory: /abs".
  while IFS= read -r line || [ -n "$line" ]; do
    p="$(printf '%s\n' "$line" | sed -nE 's/^[[:space:]]*- (Working directory: )?`(\/[^`]*)`.*/\2/p; t; s/^[[:space:]]*- (Working directory: )?(\/[^[:space:]]*).*/\2/p')"
    [ -n "$p" ] || continue
    p="$(printf '%s\n' "$p" | sed -E 's/:[0-9]+(-[0-9]+)?$//')"
    [ -e "$p" ] || { echo "MISSING PATH $p"; fail=1; }
  done < "$manifest"
fi

if [ "$fail" -ne 0 ]; then echo "CHECK FAILED"; exit 1; fi
echo "CHECK OK"
