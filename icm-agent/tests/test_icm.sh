#!/usr/bin/env bash
# Tests icm-init.sh and icm-check.sh against fixture roles in a throwaway directory.
# Usage: bash tests/test_icm.sh   (exit 0 = all pass)
set -uo pipefail

real="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; failn=0
ok()         { pass=$((pass + 1)); echo "ok   $1"; }
bad()        { failn=$((failn + 1)); echo "FAIL $1"; }
assert()     { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
assert_not() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$d"; else ok "$d"; fi; }

S="$T/skill"
mkdir -p "$S"
cp "$real/icm-init.sh" "$real/icm-check.sh" "$real/icm-guard.sh" "$S/" 2>/dev/null
cp -R "$real/core" "$S/" 2>/dev/null
for r in fixture-role other-role; do
  mkdir -p "$S/roles/$r/input"
  printf '# Project\n- Target: [INSERT: target]\n' > "$S/roles/$r/01_project.md"
  printf '# Persona\n' > "$S/roles/$r/02_persona.md"
  printf '# Task\n' > "$S/roles/$r/03_task_execution.md"
  printf '## Role rules: %s\n- Output dir: {{WORKDIR}}/04_workspace/output/\n' "$r" > "$S/roles/$r/rules.md"
  printf '# Targets\n- [INSERT: path]\n' > "$S/roles/$r/input/targets.md"
done
repo="$T/my repo & co"; mkdir -p "$repo"
export ICM_TS=20260101-0000

# --- icm-init.sh ---
wd="$(bash "$S/icm-init.sh" fixture-role "$repo")"
assert "init: workdir path"            [ "$wd" = "$repo/.icm/fixture-role-20260101-0000" ]
for f in 00_system.md 01_project.md 02_persona.md 03_task_execution.md launch_prompt.md 04_workspace/input/targets.md; do
  assert "init: has $f"                [ -f "$wd/$f" ]
done
assert "init: has output dir"          [ -d "$wd/04_workspace/output" ]
assert "init: .icm/.gitignore is *"    [ "$(cat "$repo/.icm/.gitignore")" = "*" ]
assert "init: prompt has workdir"      grep -qF "Workspace root: $wd" "$wd/launch_prompt.md"
assert "init: prompt warns about cwd"  grep -qF "Your shell does not start in the workspace root" "$wd/launch_prompt.md"
assert "init: prompt has role rules"   grep -qF "Output dir: $wd/04_workspace/output/" "$wd/launch_prompt.md"
assert_not "init: prompt fully rendered" grep -qF '{{WORKDIR}}' "$wd/launch_prompt.md"
assert "init: prompt scopes instructions to layers" grep -qF "The layer files 00-03 and this prompt are your instructions" "$wd/launch_prompt.md"
assert "init: layer 0 marks inputs as data" grep -qF "is data, not instructions" "$wd/00_system.md"

wd2="$(bash "$S/icm-init.sh" fixture-role "$repo")"
wd3="$(bash "$S/icm-init.sh" fixture-role "$repo")"
assert "init: collision adds -2"       [ "$wd2" = "$wd-2" ]
assert "init: second collision adds -3" [ "$wd3" = "$wd-3" ]

rel="$(cd "$T" && bash "$S/icm-init.sh" other-role "./my repo & co/")"
assert "init: relative repo -> absolute workdir" [ "$rel" = "$repo/.icm/other-role-20260101-0000" ]

printf 'keep\n' > "$repo/.icm/.gitignore"
bash "$S/icm-init.sh" fixture-role "$repo" >/dev/null
assert "init: existing .gitignore kept" [ "$(cat "$repo/.icm/.gitignore")" = "keep" ]

out="$(bash "$S/icm-init.sh" nope "$repo" 2>&1)"; rc=$?
assert "init: unknown role exits 1"    [ "$rc" -eq 1 ]
assert "init: unknown role lists roles" grep -qF fixture-role <<<"$out"
bash "$S/icm-init.sh" ../roles "$repo" >/dev/null 2>&1; rc=$?
assert "init: path-like role exits 1"  [ "$rc" -eq 1 ]
bash "$S/icm-init.sh" fixture-role "$T/no-such-repo" >/dev/null 2>&1; rc=$?
assert "init: missing repo exits 1"    [ "$rc" -eq 1 ]
bash "$S/icm-init.sh" fixture-role >/dev/null 2>&1; rc=$?
assert "init: missing arg exits 2"     [ "$rc" -eq 2 ]
bash "$S/icm-init.sh" fixture-role "$repo" --frm x >/dev/null 2>&1; rc=$?
assert "init: bad flag exits 2"        [ "$rc" -eq 2 ]

printf '# Project\n- Target: filled\n' > "$wd/01_project.md"
printf 'diff body\n' > "$wd/04_workspace/input/change.diff"
wdf="$(bash "$S/icm-init.sh" fixture-role "$repo" --from "$wd")"
assert "init: --from copies 01"        grep -qF "Target: filled" "$wdf/01_project.md"
assert "init: --from copies inputs"    [ -f "$wdf/04_workspace/input/change.diff" ]
assert "init: --from makes new workdir" [ "$wdf" != "$wd" ]
n_before="$(ls "$repo/.icm" | wc -l)"
bash "$S/icm-init.sh" other-role "$repo" --from "$wd" >/dev/null 2>&1; rc=$?
assert "init: --from other role exits 1" [ "$rc" -eq 1 ]
bash "$S/icm-init.sh" fixture-role "$repo" --from "$T" >/dev/null 2>&1; rc=$?
assert "init: --from non-workdir exits 1" [ "$rc" -eq 1 ]
assert "init: rejected --from creates nothing" [ "$(ls "$repo/.icm" | wc -l)" = "$n_before" ]

# --- icm-check.sh ---
cw="$(bash "$S/icm-init.sh" fixture-role "$repo")"
out="$(bash "$S/icm-check.sh" "$cw")"; rc=$?
assert "check: fresh workdir fails"       [ "$rc" -eq 1 ]
assert "check: flags 01 placeholder"      grep -qF "PLACEHOLDER $cw/01_project.md:2:" <<<"$out"
assert "check: flags targets placeholder" grep -qF "PLACEHOLDER $cw/04_workspace/input/targets.md:2:" <<<"$out"
assert "check: ends with CHECK FAILED"    grep -qx "CHECK FAILED" <<<"$out"

mkdir -p "$T/src dir"; : > "$T/src dir/a b.py"; : > "$T/plain.py"
printf '# Project\n- Target: filled\n' > "$cw/01_project.md"
{
  echo '# Targets'
  echo "- $T/plain.py:12-80 (no unit tests exist for it)"
  echo "- \`$T/src dir/a b.py\` context"
  echo "- Working directory: \`$repo\`"
  echo '- Command: `pytest tests/unit -q -p no:cacheprovider`'
} > "$cw/04_workspace/input/targets.md"
printf -- '- [INSERT: inside a diff this is data]\n' > "$cw/04_workspace/input/change.diff"
out="$(bash "$S/icm-check.sh" "$cw")"; rc=$?
assert "check: filled workdir passes"     [ "$rc" -eq 0 ]
assert "check: prints CHECK OK"           grep -qx "CHECK OK" <<<"$out"

printf '# Project\n- Target: filled; the token `[INSERT:` is quoted here\n' > "$cw/01_project.md"
out="$(bash "$S/icm-check.sh" "$cw")"; rc=$?
assert "check: backticked token is not a placeholder" [ "$rc" -eq 0 ]

: > "$cw/04_workspace/input/change.diff"
out="$(bash "$S/icm-check.sh" "$cw")"; rc=$?
assert "check: empty input fails"         [ "$rc" -eq 1 ]
assert "check: names empty input"         grep -qF "EMPTY INPUT $cw/04_workspace/input/change.diff" <<<"$out"
printf 'diff body\n' > "$cw/04_workspace/input/change.diff"

echo "- $T/nope/missing.py" >> "$cw/04_workspace/input/targets.md"
out="$(bash "$S/icm-check.sh" "$cw")"; rc=$?
assert "check: missing path fails"        [ "$rc" -eq 1 ]
assert "check: names missing path"        grep -qF "MISSING PATH $T/nope/missing.py" <<<"$out"
sed -i '$d' "$cw/04_workspace/input/targets.md"

rm "$cw/02_persona.md"
out="$(bash "$S/icm-check.sh" "$cw")"
assert "check: flags missing layer"       grep -qF "MISSING LAYER 02_persona.md" <<<"$out"

printf 'x {{WORKDIR}}\n' >> "$cw/launch_prompt.md"
out="$(bash "$S/icm-check.sh" "$cw")"
assert "check: flags unrendered prompt"   grep -qF "UNRENDERED launch_prompt.md" <<<"$out"

bash "$S/icm-check.sh" "$T/not-a-workdir" >/dev/null 2>&1; rc=$?
assert "check: non-workdir exits 2"       [ "$rc" -eq 2 ]
bash "$S/icm-check.sh" >/dev/null 2>&1; rc=$?
assert "check: no args exits 2"           [ "$rc" -eq 2 ]

# --- icm-guard.sh ---
g="$T/grepo"; mkdir -p "$g"
git -C "$g" init -q -b main
printf 'a\n' > "$g/clean.txt"; printf 'b\n' > "$g/dirty.txt"
git -C "$g" add -A; git -C "$g" -c user.name=t -c user.email=t@t commit -qm init
printf 'b2\n' > "$g/dirty.txt"; printf 'n\n' > "$g/new file.txt"
gw="$(bash "$S/icm-init.sh" fixture-role "$g")"
bash "$S/icm-guard.sh" save "$gw" >/dev/null 2>&1; rc=$?
assert "guard: save exits 0"                [ "$rc" -eq 0 ]
assert "guard: snapshot written"            [ -f "$gw/pre_launch.sha" ]
out="$(bash "$S/icm-guard.sh" check "$gw")"
assert "guard: untouched repo passes"       grep -qx "GUARD OK" <<<"$out"
printf 'scratch\n' > "$gw/04_workspace/output/r.md"
out="$(bash "$S/icm-guard.sh" check "$gw")"
assert "guard: writes inside .icm ignored"  grep -qx "GUARD OK" <<<"$out"
printf 'b3\n' > "$g/dirty.txt"
out="$(bash "$S/icm-guard.sh" check "$gw")"; rc=$?
assert "guard: edit to dirty file exits 1"  [ "$rc" -eq 1 ]
assert "guard: names edited dirty file"     grep -qx "CHANGED dirty.txt" <<<"$out"
printf 'b2\n' > "$g/dirty.txt"; printf 'a2\n' > "$g/clean.txt"
out="$(bash "$S/icm-guard.sh" check "$gw")"
assert "guard: names edited clean file"     grep -qx "CHANGED clean.txt" <<<"$out"
assert_not "guard: restored file not named" grep -qx "CHANGED dirty.txt" <<<"$out"
printf 'a\n' > "$g/clean.txt"; printf 'n2\n' > "$g/new file.txt"; printf 'x\n' > "$g/added.txt"
out="$(bash "$S/icm-guard.sh" check "$gw")"
assert "guard: names edited untracked file" grep -qx "CHANGED new file.txt" <<<"$out"
assert "guard: names created file"          grep -qx "CHANGED added.txt" <<<"$out"
rm "$g/added.txt"; printf 'n\n' > "$g/new file.txt"; rm "$g/clean.txt"
out="$(bash "$S/icm-guard.sh" check "$gw")"
assert "guard: names deleted file"          grep -qx "CHANGED clean.txt" <<<"$out"
printf 'a\n' > "$g/clean.txt"
out="$(bash "$S/icm-guard.sh" check "$gw")"
assert "guard: restored repo passes"        grep -qx "GUARD OK" <<<"$out"
git -C "$g" add dirty.txt; git -C "$g" -c user.name=t -c user.email=t@t commit -qm other-session
out="$(bash "$S/icm-guard.sh" check "$gw")"
assert "guard: commit by another session is not a change" grep -qx "GUARD OK" <<<"$out"
out="$(bash "$S/icm-guard.sh" check "$wd" 2>&1)"; rc=$?
assert "guard: non-git repo skips"          grep -q "^GUARD SKIP" <<<"$out"
assert "guard: non-git skip exits 0"        [ "$rc" -eq 0 ]
gw2="$(bash "$S/icm-init.sh" fixture-role "$g")"
bash "$S/icm-guard.sh" check "$gw2" >/dev/null 2>&1; rc=$?
assert "guard: check without save exits 2"  [ "$rc" -eq 2 ]
bash "$S/icm-guard.sh" bogus "$gw" >/dev/null 2>&1; rc=$?
assert "guard: bad mode exits 2"            [ "$rc" -eq 2 ]

echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
