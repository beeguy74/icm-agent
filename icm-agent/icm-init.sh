#!/usr/bin/env bash
# Scaffold an ICM workspace for one role under <repo_root>/.icm/ and print its absolute path.
# Usage: icm-init.sh <role> <repo_root> [--from <previous_workdir>]
set -euo pipefail

skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
usage() { echo "usage: icm-init.sh <role> <repo_root> [--from <previous_workdir>]" >&2; exit 2; }

[ $# -eq 2 ] || [ $# -eq 4 ] || usage
role="$1"; repo="$2"; from=""
if [ $# -eq 4 ]; then
  [ "$3" = "--from" ] || usage
  from="$4"
fi

role_dir="$skill_dir/roles/$role"
if ! [[ "$role" =~ ^[a-z0-9][a-z0-9-]*$ ]] || [ ! -d "$role_dir" ]; then
  echo "unknown role: '$role'. Available roles:" >&2
  ls -1 "$skill_dir/roles" >&2
  exit 1
fi
[ -d "$repo" ] || { echo "repo root not found: $repo" >&2; exit 1; }
repo="$(cd "$repo" && pwd)"

if [ -n "$from" ]; then
  [ -f "$from/01_project.md" ] && [ -d "$from/04_workspace/input" ] \
    || { echo "--from is not an ICM workdir: $from" >&2; exit 1; }
  from="$(cd "$from" && pwd)"
  [[ "$(basename "$from")" =~ ^${role}-[0-9]{8}-[0-9]{4}(-[0-9]+)?$ ]] \
    || { echo "--from belongs to another role: $(basename "$from")" >&2; exit 1; }
fi

icm_dir="$repo/.icm"
mkdir -p "$icm_dir"
[ -e "$icm_dir/.gitignore" ] || printf '*\n' > "$icm_dir/.gitignore"

base="$icm_dir/$role-${ICM_TS:-$(date +%Y%m%d-%H%M)}"
workdir="$base"; n=2
until mkdir "$workdir" 2>/dev/null; do
  [ -e "$workdir" ] || { echo "cannot create $workdir" >&2; exit 1; }
  workdir="$base-$n"; n=$((n + 1))
done

mkdir -p "$workdir/04_workspace/input" "$workdir/04_workspace/output"
cp "$skill_dir/core/00_system.md" "$workdir/"
cp "$role_dir/01_project.md" "$role_dir/02_persona.md" "$role_dir/03_task_execution.md" "$workdir/"
cp -R "$role_dir/input/." "$workdir/04_workspace/input/"
if [ -n "$from" ]; then
  cp "$from/01_project.md" "$workdir/01_project.md"
  cp -R "$from/04_workspace/input/." "$workdir/04_workspace/input/"
fi

# Quoted replacement keeps '&' in paths literal under bash 5.2 patsub_replacement.
prompt="$(cat "$skill_dir/core/launch_prompt.md"; echo; cat "$role_dir/rules.md")"
printf '%s\n' "${prompt//'{{WORKDIR}}'/"$workdir"}" > "$workdir/launch_prompt.md"
echo "$workdir"
