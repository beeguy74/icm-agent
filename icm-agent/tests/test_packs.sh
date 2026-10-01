#!/usr/bin/env bash
# Lints every shipped role pack and proves the pre-launch gate blocks each unfilled pack.
# Usage: bash tests/test_packs.sh   (exit 0 = all pass)
set -uo pipefail

real="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; failn=0
ok()         { pass=$((pass + 1)); echo "ok   $1"; }
bad()        { failn=$((failn + 1)); echo "FAIL $1"; }
assert()     { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
assert_not() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$d"; else ok "$d"; fi; }
assert_no_insert() { ! grep -qF '[INSERT:' "$1"; }

ROLES=(test-suite-review devils-advocate live-app-qa)
for r in "${ROLES[@]}"; do
  d="$real/roles/$r"
  for f in 01_project.md 02_persona.md 03_task_execution.md rules.md; do
    assert "$r: has $f"                  [ -f "$d/$f" ]
  done
  assert "$r: input/ not empty"          [ -n "$(ls -A "$d/input" 2>/dev/null)" ]
  assert "$r: rules header"              grep -qE '^## Role rules' "$d/rules.md"
  assert "$r: rules has final message"   grep -qF '## Your final message' "$d/rules.md"
  assert "$r: 01 has placeholders"       grep -qF '[INSERT:' "$d/01_project.md"
  assert "$r: 03 names report in output" grep -qE '04_workspace/output/[a-z_]+\.md' "$d/03_task_execution.md"
  mkdir -p "$T/repo-$r"
  wd="$(bash "$real/icm-init.sh" "$r" "$T/repo-$r")"
  assert "$r: init creates workdir"      [ -d "$wd" ]
  assert_not "$r: unfilled pack blocked by icm-check" bash "$real/icm-check.sh" "$wd"
done

# --- test-suite-review specifics ---
tsr="$real/roles/test-suite-review"
assert "tsr: severity scale in 03"   grep -qF 'Critical / High / Medium / Low' "$tsr/03_task_execution.md"
assert "tsr: mutation on copies"     grep -qF '04_workspace/output/scratch/' "$tsr/rules.md"
assert "tsr: offline rule"           grep -qF 'No network' "$tsr/rules.md"
assert "tsr: example 01 filled"      assert_no_insert "$tsr/example/01_project.md"
# Rebuild the example's /srv/acme-billing tree under $T so its manifest paths exist.
mkdir -p "$T/repo-ex"
ex="$(bash "$real/icm-init.sh" test-suite-review "$T/repo-ex")"
cp "$tsr/example/01_project.md" "$ex/01_project.md"
sed "s#/srv/acme-billing#$T/acme-billing#g" "$tsr/example/targets.md" > "$ex/04_workspace/input/targets.md"
grep -oE '^- (Working directory: )?/[^ ]+' "$ex/04_workspace/input/targets.md" | sed -E 's/^- (Working directory: )?//' \
  | while read -r p; do [ -e "$p" ] || { mkdir -p "$(dirname "$p")"; touch "$p"; }; done
assert "tsr: filled example passes icm-check" bash "$real/icm-check.sh" "$ex"

# --- devils-advocate specifics ---
da="$real/roles/devils-advocate"
assert "da: brief template"             grep -qF '[INSERT:' "$da/input/brief.md"
assert "da: targets template"           grep -qF '[INSERT:' "$da/input/targets.md"
assert "da: report name"                grep -qF '04_workspace/output/da_review.md' "$da/03_task_execution.md"
assert "da: severity scale"             grep -qF 'BLOCKER / MAJOR / MINOR / NIT' "$da/03_task_execution.md"
assert "da: verdict"                    grep -qF 'APPROVE or REQUEST CHANGES' "$da/03_task_execution.md"
assert "da: points tests to tsr role"   grep -qF 'test-suite-review' "$da/03_task_execution.md"
assert "da: four artifact checklists"   [ "$(grep -cE '^  - (Code|Plan / spec / document|Config / infrastructure|Prompt):' "$da/03_task_execution.md")" -eq 4 ]
assert "da: offline rule"               grep -qF 'No network' "$da/rules.md"
assert "da: one ruling per finding"     grep -qF 'One firm ruling per finding' "$da/rules.md"

# --- live-app-qa specifics ---
qa="$real/roles/live-app-qa"
assert "qa: test cases template"        grep -qF '[INSERT:' "$qa/input/test_cases.md"
assert "qa: report name"                grep -qF '04_workspace/output/test_report.md' "$qa/03_task_execution.md"
assert "qa: three statuses"             grep -qF 'PASS, FAIL or BLOCKED' "$qa/03_task_execution.md"
assert "qa: base-url-only network"      grep -qF 'call only the Base URL' "$qa/rules.md"
assert "qa: production guard"           grep -qF 'production' "$qa/rules.md"
assert "qa: no secret values in output" grep -qF 'never write secret values' "$qa/rules.md"
assert_not "qa: no secrets field asks for values" grep -qiE 'password: \[INSERT' "$qa/01_project.md"

# --- command rules allow inspection and runs on copies ---
for r in test-suite-review devils-advocate; do
  assert "$r: rules allow read-only inspection" grep -qF 'Read-only inspection' "$real/roles/$r/rules.md"
  assert "$r: rules allow runs on copies"       grep -qF 'also against copies in' "$real/roles/$r/rules.md"
done

echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
