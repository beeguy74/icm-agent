# icm-agent Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Task 6 additionally REQUIRES superpowers:writing-skills.

**Goal:** A global Claude Code skill that lets the main agent build an ICM (Interpretable Context Methodology) workspace for a reviewer subagent, fill it from its own context, gate on the user's OK, launch the reviewer, and relay the report from disk.

**Architecture:** Deterministic shell scripts handle the mechanics (`icm-init.sh` scaffolds a timestamped workdir under `<repo>/.icm/`, `icm-check.sh` is the pre-launch gate). Layer templates are split into a shared core and per-role packs (`test-suite-review`, `devils-advocate`, `live-app-qa`). `SKILL.md` tells the main agent which role to pick and the 6-step workflow; the LLM only writes content (layer 1 + inputs).

**Tech Stack:** Bash 5.2 (GNU coreutils/sed/grep/find), Markdown, Claude Code Agent tool.

**Spec:** No separate spec file — the design was approved in chat on 2026-10-01 and is reproduced in the **Design** section below. Executors read that section before any task.

## Global Constraints

- Repo: `~/projects/test-review-agent/` (git, branch `main`). Skill source: `~/projects/test-review-agent/icm-agent/` (referred to as `$SK` below). Shell state does not persist between tool calls, so prefix every command that uses it with `SK=~/projects/test-review-agent/icm-agent;`.
- Install = symlink `~/.claude/skills/icm-agent` → `$SK`, created in Task 6 (not before: Task 0 needs the skill absent). Claude Code docs confirm personal skill folders may be symlinks.
- `$SCRATCH` = the executing session's scratchpad directory; prefix commands that use it with `SCRATCH=<that path>;` and substitute it literally in subagent prompts.
- Phase R (done before Task 0, commit "reorganise into icm-agent skill layout"): the old manual files were `git mv`-ed into the skill — `template/00_system.md` → `core/00_system.md`, `agent_prompt.md` → `core/launch_prompt.md`, the other template layers + `input/targets.md` → `roles/test-suite-review/`, `examples/internal-service/*` → `roles/test-suite-review/example/`. Tasks 1 and 3 therefore **replace the content** of those moved files instead of creating them.
- Commits: each task that changes repo files ends with `git add -A && git commit` (message `feat(icm-agent): task N — <summary>`, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`). Local only — never push, never tag. Execution stops after each task for the user's go.
- Reviewer subagents never run git commands that change state. Read-only `git diff` / `git status` by the main agent at runtime is part of the design.
- Every code comment / docstring is at most 2 lines (user rule, all projects).
- No Docker/container execution.
- Bash is 5.2 with `patsub_replacement` on: in `${var//pat/rep}` the replacement must be quoted (`"$workdir"`) so `&` stays literal.
- Bundled scripts are always invoked as `bash <path>`, never by bare path.
- Workdir: `<repo_root>/.icm/<role>-<YYYYmmdd-HHMM>`, then `-2`, `-3`, … on collision. `<repo_root>/.icm/.gitignore` contains exactly `*` (created only if absent).
- Placeholder token in every template: `[INSERT: …]` and nothing else.
- Manifest = `04_workspace/input/targets.md`. Path lines: `- /abs/path[:L1-L2] [note]`, ``- `/abs path with spaces` [note]``, `- Working directory: /abs/path` (backticks allowed there too).
- Reviewer launch: Agent tool, `subagent_type: general-purpose`, `model: opus`, prompt = contents of `WORKDIR/launch_prompt.md`.
- Gate: the main agent stops before launch and waits for the user's OK, unless the user's request already said to launch directly.
- Network rules live only in role `rules.md` files, never in core.
- `SKILL.md`: frontmatter `name: icm-agent`; description starts with "Use when", third person, ≤ 500 chars, no workflow summary; body < 500 words.

## Review Focus

1. **Paths with spaces or `&`** (repo root or manifest entries) → `launch_prompt.md` holds the exact path; backticked manifest paths are checked, not split. Tests: Task 1 (repo `my repo & co`), Task 2 (backticked targets).
2. **Manifest lines carrying line ranges and notes** (`/x.py:12-80 (no tests)`) → no false `MISSING PATH`. Test: Task 2.
3. **`--from` pointing at another role's workdir, or at a non-workdir** → rejected before anything is created. Test: Task 1.
4. **A non-Markdown input that contains `[INSERT:` as data** (e.g. `change.diff` when the DA reviews this very skill) → not reported as a placeholder. Test: Task 2.
5. **Reviewer subagent's shell does not start in WORKDIR** → the launch prompt says so and every path in it is absolute, and the report still lands in `WORKDIR/04_workspace/output/`. Tests: Task 1 (prompt line), Task 7 (end-to-end location check).

## Design (approved 2026-10-01)

**Layout**

```
$SK/
  SKILL.md              role routing + 6-step workflow
  icm-init.sh           <role> <repo_root> [--from <prev WORKDIR>] → prints WORKDIR
  icm-check.sh          <WORKDIR> → MISSING LAYER / PLACEHOLDER / UNRENDERED / MISSING PATH, then CHECK OK|FAILED
  core/00_system.md     shared layer 0
  core/launch_prompt.md shared launch prompt with {{WORKDIR}}
  roles/<role>/{01_project.md,02_persona.md,03_task_execution.md,rules.md,input/…}
  roles/test-suite-review/example/   filled internal-service reference
  tests/test_icm.sh     script tests (fixture skill dir, throwaway repo)
  tests/test_packs.sh   pack lint + "unfilled pack is blocked by the gate"
```

**Workspace produced per run**: `00_system.md`, `01_project.md`, `02_persona.md`, `03_task_execution.md`, `launch_prompt.md` (= core launch prompt + role `rules.md`, `{{WORKDIR}}` rendered), `04_workspace/input/` (role input templates), `04_workspace/output/`.

**Roles** (separate packs; the generic DA does not judge test-suite quality)

| Target | Role | Inputs | Report |
|---|---|---|---|
| a test suite | `test-suite-review` (ported from this folder) | `targets.md` | `test_suite_review.md` + `test_run.log` |
| any other artifact: code change, plan, spec, config, prompt | `devils-advocate` | `brief.md`, `targets.md`, optional frozen files (`change.diff`) | `da_review.md` |
| a running app, against test cases | `live-app-qa` (from example 1) | `test_cases.md` | `test_report.md` |

**Workflow (main agent)**: 1 init → 2 fill (no copying of files on disk; context-only material saved into `input/`; code change → `git diff` saved to `input/change.diff` = frozen snapshot) → 3 `icm-check` must pass → 4 gate (summary, stop for OK; `live-app-qa`: close own Playwright browser) → 5 save `git status --porcelain`, launch → 6 relay from the report file, then diff `git status --porcelain` and flag new changes outside `.icm/` (may be another session).

**Failure handling**: check fails → fix, don't launch; `BLOCKED.md` → relay reason, no blind relaunch; write refused → give the user `{ "worktree": { "bgIsolation": "none" } }` for `<repo>/.claude/settings.json`, edit no config; leftover `output/scratch/` → tell user, delete it; runs are never overwritten or auto-deleted (`rm -rf <repo>/.icm` is the user's call).

---

### Task 0: Baseline behaviour without the skill (writing-skills RED)

**Files:**
- Create (scratch only): `$SCRATCH/fixture/calc.py`, `$SCRATCH/fixture/tests/test_calc.py`, `$SCRATCH/fixture/plan.md`, `$SCRATCH/baseline.md` — `$SCRATCH` = this session's scratchpad directory.

**Interfaces:**
- Produces: the fixture repo and scenario prompts reused verbatim by Task 6; `baseline.md` with verbatim baseline behaviour.

- [ ] **Step 1: Confirm the skill does not exist yet**

Run: `ls ~/.claude/skills/icm-agent 2>&1`
Expected: `No such file or directory`. If it exists, stop and ask the user — the baseline must run without it.

- [ ] **Step 2: Create the fixture repo**

```bash
mkdir -p "$SCRATCH/fixture/tests"
cat > "$SCRATCH/fixture/calc.py" <<'EOF'
def divide(a, b):
    if b == 0:
        raise ValueError("division by zero")
    return a / b
EOF
cat > "$SCRATCH/fixture/tests/test_calc.py" <<'EOF'
from calc import divide


def test_divide():
    assert divide(4, 2)


def test_zero():
    try:
        divide(1, 0)
    except Exception:
        pass
EOF
cat > "$SCRATCH/fixture/plan.md" <<'EOF'
# Cache migration plan
1. Replace the Redis cache with an in-process dict in every web worker.
2. Deploy on Friday evening; no rollback step needed because the dict is empty on start.
EOF
```

- [ ] **Step 3: Run scenario S1 without the skill**

Dispatch one fresh general-purpose subagent with exactly this prompt (substitute `$SCRATCH`):

```
You are the main agent in a Claude Code session; the working repository is $SCRATCH/fixture.
Before acting, check ~/.claude/skills/ for a skill relevant to the request and follow it if one exists.
You cannot launch subagents in this test: wherever you would call the Agent tool, write the exact call
(subagent_type, model, and where the prompt text comes from) to $SCRATCH/launch_intent_S1.txt instead.
User request: "Use a subagent to do a devil's-advocate review of the test suite in this repo."
When done, reply with what you did and what, if anything, you are waiting for.
```

- [ ] **Step 4: Run scenario S3 without the skill**

Same prompt, with `launch_intent_S3.txt` and the user request: `"Challenge $SCRATCH/fixture/plan.md as devil's advocate with a reviewer subagent before I execute it."`

- [ ] **Step 5: Record the baseline**

Write `$SCRATCH/baseline.md` with, per scenario: files created (paths), whether a workspace with layers was built, whether inputs were copied or referenced, whether it stopped before launching, the launch intent written, and any rationalization quoted verbatim. Expected (RED): no ICM workspace and no gate — this is the failure the skill must fix. Delete `launch_intent_*.txt` afterwards.

---

### Task 1: Core layers + `icm-init.sh`

**Files:**
- Modify (replace whole content; moved in Phase R): `$SK/core/00_system.md`, `$SK/core/launch_prompt.md` (old content = the manual `agent_prompt.md`; its role-specific parts reappear in Task 3's `rules.md`)
- Create: `$SK/icm-init.sh`
- Test: `$SK/tests/test_icm.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `bash $SK/icm-init.sh <role> <repo_root> [--from <prev_workdir>]` → stdout = absolute WORKDIR, exit 0. Exit 1: unknown/invalid role (stderr lists roles), missing repo, bad `--from`. Exit 2: usage. Env `ICM_TS` overrides the timestamp (tests only). Role pack contract: `roles/<role>/{01_project.md,02_persona.md,03_task_execution.md,rules.md}` + non-empty `roles/<role>/input/`.

- [ ] **Step 1: Write the failing test**

Create `$SK/tests/test_icm.sh`:

```bash
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
cp "$real/icm-init.sh" "$real/icm-check.sh" "$S/" 2>/dev/null
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

echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ~/projects/test-review-agent/icm-agent/tests/test_icm.sh`
Expected: many `FAIL init: …` lines (no `icm-init.sh` yet), last line `0 passed, N failed` or similar, exit code non-zero.

- [ ] **Step 3: Write `core/00_system.md`**

```markdown
# System Constraints
- Context initialization: Read layers 01, 02, and 03 before executing any logic.
- Workspace root: Every relative path in these layers is relative to the workspace root given in your launch prompt, not to your shell's working directory.
- I/O Boundary: Input data must strictly be read from `04_workspace/input/` and from the absolute paths listed in `04_workspace/input/targets.md` when it exists (read-only; never modify them).
- Output Boundary: All generated reports and artifacts must be written strictly to `04_workspace/output/`.
- Formatting: All output must be valid Markdown.
- Failure state: If required input is missing, halt and write the reason to `04_workspace/output/BLOCKED.md`.
```

- [ ] **Step 4: Write `core/launch_prompt.md`**

```markdown
You are running a task in the ICM (Interpretable Context Methodology) workspace set up at {{WORKDIR}}. The workspace files are your instructions — follow them.

Workspace root: {{WORKDIR}}
Your shell does not start in the workspace root. Resolve every relative path in the layers (`04_workspace/...`) against {{WORKDIR}} and use absolute paths in every tool call.

Start by reading these four layers, in order, before doing anything else:
1. {{WORKDIR}}/00_system.md — global rules (I/O boundaries, output format, failure state)
2. {{WORKDIR}}/01_project.md — project context
3. {{WORKDIR}}/02_persona.md — the persona you adopt
4. {{WORKDIR}}/03_task_execution.md — the execution protocol

Then execute the protocol in 03 exactly. Your inputs are the files in {{WORKDIR}}/04_workspace/input/ and the absolute paths listed in its `targets.md` (read-only). Your deliverables go in {{WORKDIR}}/04_workspace/output/.

## Hard rules (in addition to 00_system.md)
- Do NOT modify any file outside {{WORKDIR}}/04_workspace/output/. Inputs and the files they point to are read-only. Other people or sessions may be working in this checkout, so an accidental edit could land in someone else's commit.
- Do NOT run any git command that changes state (no commit, add, stash, checkout, restore, reset). `git stash` in particular is banned: the stash stack is shared with other sessions and worktrees. Read-only `git log` / `git show` / `git diff` are fine.
- No package managers: do not run pip, npm, uv or any other package manager — not even `pip download` or `pip index`. If you need a different dependency version to check a claim, mark the claim as unverified instead.
- If a required input is missing, or a write to {{WORKDIR}}/04_workspace/output/ is refused, write the reason to {{WORKDIR}}/04_workspace/output/BLOCKED.md if you can, then stop and state the reason in your final message.

## What a good report looks like
- Every finding cites evidence: file path and line numbers, a quoted snippet, a log line, a command result, or a scratch-experiment result. No finding without evidence.
- Rank findings with the severity scale defined in 03.
- Say explicitly where something is handled well — the persona is skeptical, not reflexively negative; a false alarm costs credibility.
- Separate defects that let real bugs through from style or hygiene issues.
- End with a prioritized list of concrete fixes.
```

- [ ] **Step 5: Write `icm-init.sh`**

```bash
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
```

- [ ] **Step 6: Run test to verify the init section passes**

Run: `bash ~/projects/test-review-agent/icm-agent/tests/test_icm.sh`
Expected: every `init:` line is `ok`; final line `N passed, 0 failed`; exit 0. (`icm-check.sh` does not exist yet; the `cp` of it fails silently and no init test depends on it.)

---

### Task 2: `icm-check.sh` (pre-launch gate)

**Files:**
- Create: `$SK/icm-check.sh`
- Modify: `$SK/tests/test_icm.sh` (insert a block above the final two lines `echo "$pass passed, $failn failed"` / `[ "$failn" -eq 0 ]`)

**Interfaces:**
- Consumes: workdir layout from Task 1.
- Produces: `bash $SK/icm-check.sh <WORKDIR>` → one line per problem (`MISSING LAYER <file>`, `PLACEHOLDER <file>:<line>:<text>`, `UNRENDERED launch_prompt.md`, `MISSING PATH <path>`), then `CHECK OK` (exit 0) or `CHECK FAILED` (exit 1). Exit 2 = usage / not a workdir.

- [ ] **Step 1: Write the failing test**

Insert above the final two lines of `tests/test_icm.sh`:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ~/projects/test-review-agent/icm-agent/tests/test_icm.sh`
Expected: all `init:` lines `ok`, every `check:` line `FAIL`, exit non-zero.

- [ ] **Step 3: Write `icm-check.sh`**

```bash
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
  hits="$(grep -HnF '[INSERT:' "${md[@]}" || true)"
  [ -z "$hits" ] || { printf '%s\n' "$hits" | sed 's/^/PLACEHOLDER /'; fail=1; }
fi

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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash ~/projects/test-review-agent/icm-agent/tests/test_icm.sh`
Expected: every line `ok`, final line `N passed, 0 failed`, exit 0.

---

### Task 3: Role pack `test-suite-review` + pack lint

**Files:**
- Already in place from Phase R (unchanged): `$SK/roles/test-suite-review/{01_project.md,02_persona.md}`, `$SK/roles/test-suite-review/example/{01_project.md,targets.md}`
- Modify (replace whole content): `$SK/roles/test-suite-review/03_task_execution.md`, `$SK/roles/test-suite-review/input/targets.md`
- Create: `$SK/roles/test-suite-review/rules.md`
- Test: `$SK/tests/test_packs.sh`

**Interfaces:**
- Consumes: `icm-init.sh`, `icm-check.sh` (Tasks 1–2), role pack contract (Task 1).
- Produces: role `test-suite-review`; report names `test_suite_review.md` + `test_run.log`; `tests/test_packs.sh` with a `ROLES=(…)` array and a pack-specific block area above its final two lines.

- [ ] **Step 1: Write the failing test**

Create `$SK/tests/test_packs.sh`:

```bash
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

ROLES=(test-suite-review)
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
if [ -d ~/projects/internal-service ]; then
  mkdir -p "$T/repo-ex"
  ex="$(bash "$real/icm-init.sh" test-suite-review "$T/repo-ex")"
  cp "$tsr/example/01_project.md" "$ex/01_project.md"
  cp "$tsr/example/targets.md" "$ex/04_workspace/input/targets.md"
  assert "tsr: filled example passes icm-check" bash "$real/icm-check.sh" "$ex"
fi

echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ~/projects/test-review-agent/icm-agent/tests/test_packs.sh`
Expected: `FAIL test-suite-review: …` lines, exit non-zero.

- [ ] **Step 3: Confirm the Phase R files are in place**

Run: `SK=~/projects/test-review-agent/icm-agent; ls $SK/roles/test-suite-review $SK/roles/test-suite-review/example`
Expected: `01_project.md 02_persona.md 03_task_execution.md example input` and `01_project.md targets.md`. Nothing to copy.

- [ ] **Step 4: Write `roles/test-suite-review/03_task_execution.md`** (template text + severity scale in Step 4)

```markdown
# Execution Protocol
Step 1: Read the target application context from Layer 1.
Step 2: Read `04_workspace/input/targets.md`, then read every test file and code-under-test file it lists, and run its test command to produce the execution log.
Step 3: Analyze the test suite strictly against the following four pillars:
  - Meaningfulness: Are the assertions actually validating core business logic, or just checking trivial UI states/tautologies?
  - Reliability & Determinism: Are there hardcoded sleeps, network dependencies, or race conditions that will cause flakiness?
  - Isolation & State Hygiene: Do tests clean up after themselves? Is there data leakage between tests? Are database states or browser sessions properly isolated?
  - Coverage Depth (Beyond the Happy Path): How well does the suite handle edge cases, negative inputs, boundaries, and error states?
Step 4: Generate a comprehensive "Devil's Advocate Test Suite Review" detailing critical vulnerabilities in the test architecture, providing concrete examples from the input files. Rate every finding Critical / High / Medium / Low.
Step 5: Write the final Markdown report to `04_workspace/output/test_suite_review.md`.
```

- [ ] **Step 5: Write `roles/test-suite-review/input/targets.md`** (template text + path-format line)

```markdown
# Review Targets
All paths are absolute and read-only. Do not copy or modify them. If any listed path does not exist, halt per `00_system.md`. One absolute path per `- ` line (wrap a path that contains spaces in backticks); anything after the path is a note.

## Review (the test suite)
- [INSERT: absolute path of each test file to review, one per line]

## Context (code under test)
- [INSERT: absolute path of each source file the tests exercise; mark any that have no tests]

## Execution log
- Working directory: [INSERT: absolute path of the repository root]
- Command: [INSERT: command that runs the suite with a per-test result list, e.g. `PYTHONDONTWRITEBYTECODE=1 python3 -m pytest tests/unit -q -rA -p no:cacheprovider`]
- The command must run offline and write nothing outside `04_workspace/output/`: disable the runner's cache (pytest: `-p no:cacheprovider`), set `PYTHONDONTWRITEBYTECODE=1`, and set any env var the project needs to stop network calls at import (e.g. `LITELLM_LOCAL_MODEL_COST_MAP=True` for litellm).
- Save the raw output to `04_workspace/output/test_run.log` and cite it in the report.
```

- [ ] **Step 6: Write `roles/test-suite-review/rules.md`** (role-specific parts of the old `agent_prompt.md`)

```markdown
## Role rules: test-suite review
- No network: do not call deployed services or external APIs. Only run the test command listed in `targets.md`.
- If you want to prove a test is weak — for example that it still passes when the logic it claims to check is broken — do it on COPIES, never the real files: copy the relevant test file(s) and source file(s) into {{WORKDIR}}/04_workspace/output/scratch/, mutate the copies, run the tests against them there, and record the result as evidence in the report. Check how each test file locates its code under test (some use paths relative to the test file) so the copy actually exercises the mutated source. Delete {{WORKDIR}}/04_workspace/output/scratch/ before you finish, so only `test_suite_review.md` and `test_run.log` remain.
- Cover all four pillars from 03 for each test file, and separate "the suite fails to catch real bugs" (the most important class) from style or hygiene issues.

## Your final message
When the report is written, reply with a short summary (under 20 lines): the path to the report, the test-run result counts, the top 5 findings in one line each with severity, and confirmation that you modified nothing outside `04_workspace/output/` and removed the scratch directory.
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bash ~/projects/test-review-agent/icm-agent/tests/test_packs.sh`
Expected: every line `ok` (the example check runs because `~/projects/internal-service` exists), exit 0. Re-run `bash $SK/tests/test_icm.sh` — still exit 0.

---

### Task 4: Role pack `devils-advocate`

**Files:**
- Create: `$SK/roles/devils-advocate/{01_project.md,02_persona.md,03_task_execution.md,rules.md}`, `$SK/roles/devils-advocate/input/{brief.md,targets.md}`
- Modify: `$SK/tests/test_packs.sh` (ROLES array; new block above the final two lines)

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: role `devils-advocate`; report `da_review.md`; severities `BLOCKER / MAJOR / MINOR / NIT`; verdict `APPROVE` / `REQUEST CHANGES`; optional log `verify_run.log`.

- [ ] **Step 1: Write the failing test**

In `tests/test_packs.sh` change `ROLES=(test-suite-review)` to `ROLES=(test-suite-review devils-advocate)` and insert above the final two lines:

```bash
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash ~/projects/test-review-agent/icm-agent/tests/test_packs.sh`
Expected: `FAIL devils-advocate: …` and `FAIL da: …` lines, exit non-zero.

- [ ] **Step 3: Write `roles/devils-advocate/01_project.md`**

```markdown
# Project Context
- Project: [INSERT: repository or project name, what it does, and the main components relevant to the artifact with where they live]
- Conventions and constraints: [INSERT: rules the artifact must follow — style limits, versions, platform, compatibility promises; write "none known" if there are none]
- Known state: [INSERT: relevant known issues, recent changes, what is deployed vs local; write "none known" if there are none]
- Artifact Locations: What to review and why is in `04_workspace/input/brief.md`; the artifact and its context are files in `04_workspace/input/` or absolute paths listed in `04_workspace/input/targets.md`.
```

- [ ] **Step 4: Write `roles/devils-advocate/02_persona.md`**

```markdown
# Persona: Devil's Advocate Reviewer
- Traits: Highly skeptical, uncompromising on quality, fiercely analytical.
- Philosophy: Assumes the artifact is wrong until the evidence shows otherwise. Judges it against the intent stated in the brief, not personal taste.
- Focus: Hunts for hidden assumptions, fixes that treat symptoms instead of root causes, regressions, broken contracts, unhandled failure modes, and claims that nothing verifies.
- Tone: Direct, constructive, evidence-based, and critically sharp.
```

- [ ] **Step 5: Write `roles/devils-advocate/03_task_execution.md`**

```markdown
# Execution Protocol
Step 1: Read the project context from Layer 1, then the intent, acceptance criteria and constraints from `04_workspace/input/brief.md`.
Step 2: Read every artifact and context file in `04_workspace/input/` and every absolute path listed in `04_workspace/input/targets.md` (if present). If `targets.md` lists a verification command, run it and save the raw output to `04_workspace/output/verify_run.log`.
Step 3: Identify each artifact's type and apply the matching checklist:
  - Code: Does the change fix the root cause or a symptom? What regresses for existing callers? Which contracts (signatures, return shapes, error behavior, config keys) change? Which error paths are unhandled? Do the tests exercise the changed lines? Judging the quality of a whole test suite is out of scope here — that is the `test-suite-review` role.
  - Plan / spec / document: Which assumptions are unstated? Which failure modes have no handling? Do any parts contradict each other? What does the brief require that nothing covers, and what is included that the brief did not ask for?
  - Config / infrastructure: What is the blast radius if it is wrong? Which defaults are unsafe? Are secrets exposed? Is there a rollback path?
  - Prompt: Which instructions are ambiguous or conflicting? Can input text override them (injection)? Is there an eval or test that would catch a regression?
Step 4: If a verification command exists, prove weak points on copies in `04_workspace/output/scratch/` — for example, revert the fix in a copy and check whether any test notices.
Step 5: Rate every finding BLOCKER / MAJOR / MINOR / NIT, each with evidence and a concrete fix. Then give one overall verdict: APPROVE or REQUEST CHANGES (any BLOCKER or MAJOR means REQUEST CHANGES).
Step 6: Write the final Markdown report to `04_workspace/output/da_review.md`, verdict first.
```

- [ ] **Step 6: Write `roles/devils-advocate/input/brief.md`**

```markdown
# Review Brief
- Artifact: [INSERT: what is under review — code change, plan, spec, config or prompt — and where it is: a file in this folder such as `change.diff`, or paths in `targets.md`]
- Intent: [INSERT: what the artifact is supposed to achieve, in one or two sentences]
- Acceptance criteria: [INSERT: the checks it must pass, one per line]
- Constraints: [INSERT: rules it must respect, e.g. code comments at most 2 lines; write "none" if there are none]
- Out of scope: [INSERT: what the reviewer must not judge; write "none" if nothing is excluded]
```

- [ ] **Step 7: Write `roles/devils-advocate/input/targets.md`**

```markdown
# Review Targets
All paths are absolute and read-only. Do not copy or modify them. If any listed path does not exist, halt per `00_system.md`. One absolute path per `- ` line (wrap a path that contains spaces in backticks); anything after the path is a note. Delete any section that does not apply.

## Artifact
- [INSERT: absolute path of each file under review, one per line]

## Context
- [INSERT: absolute path of each related file — callers, tests, the spec it implements]

## Verification
- Working directory: [INSERT: absolute path the command runs from]
- Command: [INSERT: offline command that checks the artifact, e.g. its test suite]
- Save the raw output to `04_workspace/output/verify_run.log` and cite it in the report.
```

- [ ] **Step 8: Write `roles/devils-advocate/rules.md`**

```markdown
## Role rules: devil's advocate
- No network: do not call deployed services or external APIs. The only command you may run is the verification command in `targets.md`, if one is listed.
- Prove weak points only on copies in {{WORKDIR}}/04_workspace/output/scratch/, never on the real files, and delete that directory before you finish.
- One firm ruling per finding: state the defect, the evidence and the fix. A finding without enough evidence to rule on goes in a final "Unverified" list instead.

## Your final message
When the report is written, reply with a short summary (under 20 lines): the path to the report, the verdict, every BLOCKER and MAJOR finding in one line each, and confirmation that you modified nothing outside `04_workspace/output/` and removed the scratch directory.
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `bash $SK/tests/test_packs.sh && bash $SK/tests/test_icm.sh`
Expected: both end `N passed, 0 failed`, exit 0.

---

### Task 5: Role pack `live-app-qa`

**Files:**
- Create: `$SK/roles/live-app-qa/{01_project.md,02_persona.md,03_task_execution.md,rules.md}`, `$SK/roles/live-app-qa/input/test_cases.md`
- Modify: `$SK/tests/test_packs.sh` (ROLES array; new block above the final two lines)

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: role `live-app-qa`; report `test_report.md`; statuses `PASS` / `FAIL` / `BLOCKED`; FAIL severities `Critical / High / Medium / Low`. No `targets.md` (so `icm-check` does no path check for this role).

- [ ] **Step 1: Write the failing test**

Change `ROLES=(test-suite-review devils-advocate)` to `ROLES=(test-suite-review devils-advocate live-app-qa)` and insert above the final two lines:

```bash
# --- live-app-qa specifics ---
qa="$real/roles/live-app-qa"
assert "qa: test cases template"        grep -qF '[INSERT:' "$qa/input/test_cases.md"
assert "qa: report name"                grep -qF '04_workspace/output/test_report.md' "$qa/03_task_execution.md"
assert "qa: three statuses"             grep -qF 'PASS, FAIL or BLOCKED' "$qa/03_task_execution.md"
assert "qa: base-url-only network"      grep -qF 'call only the Base URL' "$qa/rules.md"
assert "qa: production guard"           grep -qF 'production' "$qa/rules.md"
assert "qa: no secret values in output" grep -qF 'never write secret values' "$qa/rules.md"
assert_not "qa: no secrets field asks for values" grep -qiE 'password: \[INSERT' "$qa/01_project.md"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash $SK/tests/test_packs.sh`
Expected: `FAIL live-app-qa: …` and `FAIL qa: …` lines, exit non-zero.

- [ ] **Step 3: Write `roles/live-app-qa/01_project.md`**

```markdown
# Project Context
- Target Application: [INSERT: app name, what it does, and the features the test cases touch]
- Base URL: [INSERT: the only URL the agent may call, e.g. http://localhost:3000]
- Environment: [INSERT: local, staging or production; for production add "approved by the user for this run" only if they said so]
- Test credentials: [INSERT: path to a credentials file or the names of the env vars that hold them — never the secret values]
- Tools: [INSERT: how to drive the app — Playwright MCP browser tools, curl, or both]
- Test data: [INSERT: which data the agent may create and how to recognise it, e.g. names prefixed `icm-qa-`]
- Artifact Locations: Test cases are in `04_workspace/input/test_cases.md`.
```

- [ ] **Step 4: Write `roles/live-app-qa/02_persona.md`**

```markdown
# Persona: Senior QA Automation Engineer
- Traits: Meticulous observer, strict about following the test protocol, precise.
- Philosophy: A result is only as good as its evidence. A case that could not be run is BLOCKED, never PASS.
- Focus: Exact steps, exact observed behavior, and the gap between observed and expected.
- Tone: Clear, factual bug reports a developer can reproduce without asking questions.
```

- [ ] **Step 5: Write `roles/live-app-qa/03_task_execution.md`**

```markdown
# Execution Protocol
Step 1: Read the target application details from Layer 1.
Step 2: Read the test cases from `04_workspace/input/test_cases.md`.
Step 3: Execute each test case against the Base URL with the tools named in Layer 1, following its steps exactly. Record what you observed at every step.
Step 4: Mark each case PASS, FAIL or BLOCKED (could not run — say why). Every FAIL and BLOCKED cites evidence: the HTTP status and a body excerpt, a screenshot saved in `04_workspace/output/`, or console errors. Rate each FAIL Critical / High / Medium / Low by user impact.
Step 5: Generate a test report: a summary table (case, status, severity), then one section per case with the steps run, expected result, observed result and evidence.
Step 6: Save the report to `04_workspace/output/test_report.md`.
```

- [ ] **Step 6: Write `roles/live-app-qa/input/test_cases.md`**

```markdown
# Test Cases
Copy the block below once per case; number cases TC-01, TC-02, ….

## TC-01: [INSERT: title]
- Preconditions: [INSERT: state the app must be in before step 1]
- Steps to Reproduce:
  1. [INSERT: step]
- Expected Result: [INSERT: what must be observed]

## TC-02: [INSERT: title]
- Preconditions: [INSERT: state the app must be in before step 1]
- Steps to Reproduce:
  1. [INSERT: step]
- Expected Result: [INSERT: what must be observed]
```

- [ ] **Step 7: Write `roles/live-app-qa/rules.md`**

```markdown
## Role rules: live-app QA
- Network: call only the Base URL from 01_project.md. No other hosts and no external APIs.
- If the Environment in 01_project.md is production and does not say "approved by the user for this run", write BLOCKED.md and stop.
- Create, change or delete only data this run created and marked as described under Test data in 01_project.md. Never touch other data.
- Read credentials from the file or env vars named in 01_project.md; never write secret values into any output file.
- Save screenshots and other evidence files in {{WORKDIR}}/04_workspace/output/.

## Your final message
When the report is written, reply with a short summary (under 20 lines): the path to the report, the PASS / FAIL / BLOCKED counts, every FAIL in one line each with severity, and confirmation that you modified nothing outside `04_workspace/output/`.
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `bash $SK/tests/test_packs.sh && bash $SK/tests/test_icm.sh`
Expected: both end `N passed, 0 failed`, exit 0.

---

### Task 6: `SKILL.md` (writing-skills GREEN + REFACTOR)

**REQUIRED SUB-SKILL:** superpowers:writing-skills.

**Files:**
- Create: `$SK/SKILL.md`
- Uses (scratch): fixture repo and `baseline.md` from Task 0.

**Interfaces:**
- Consumes: everything from Tasks 1–5, `$SCRATCH/baseline.md`.
- Produces: the discoverable skill `icm-agent`.

- [ ] **Step 1: Write `SKILL.md`** — draft below; extend "Common mistakes" with any baseline failure from `baseline.md` it does not already cover (positive recipe form, per writing-skills "Match the Form to the Failure").

```markdown
---
name: icm-agent
description: Use when a review, devil's-advocate challenge or QA pass should run in an isolated reviewer subagent with a file-based workspace — reviewing a test suite, challenging a code change, plan, spec, config or prompt, or testing a running app against test cases — or when the user mentions ICM or Interpretable Context Methodology.
---

# ICM agent

## Overview
The reviewer subagent's entire context is a workspace of numbered files: `00_system` (rules), `01_project` (context), `02_persona`, `03_task_execution`, `04_workspace/input|output`. You, the main agent, build it, fill it from what you know, get the user's OK, launch the reviewer, and relay its report from disk.

## Pick the role
| Target | Role | Report |
|---|---|---|
| a test suite | `test-suite-review` | `test_suite_review.md` |
| a running app, against test cases | `live-app-qa` | `test_report.md` |
| anything else: code change, plan, spec, config, prompt | `devils-advocate` | `da_review.md` |

If no role fits, tell the user and offer to add a pack under `~/.claude/skills/icm-agent/roles/`.

## Workflow
1. **Init:** `bash ~/.claude/skills/icm-agent/icm-init.sh <role> <repo_root>` prints WORKDIR (`<repo_root>/.icm/<role>-<timestamp>`). Re-review after a fix: append `--from <previous WORKDIR>`, then update only what changed.
2. **Fill:** replace every `[INSERT: …]` in `WORKDIR/01_project.md` and `WORKDIR/04_workspace/input/*`, or delete the line when it does not apply. Files on disk go into `targets.md` by absolute path, one per `- ` line. Material that exists only in this conversation (a diff, pasted text, test cases you wrote) is saved as a file in `input/`. For a code change, save `git diff` output to `input/change.diff` now: that freezes what gets reviewed. Filled example: `~/.claude/skills/icm-agent/roles/test-suite-review/example/`.
3. **Check:** `bash ~/.claude/skills/icm-agent/icm-check.sh WORKDIR` must print `CHECK OK`.
4. **Gate:** show the user the role, WORKDIR, the number of targets with the main paths, and the command the reviewer will run. Then end your turn and wait for their OK. Continue without waiting only when the user's request already said to launch directly. For `live-app-qa`, close your own Playwright browser first.
5. **Launch:** save `git status --porcelain` output, then call the Agent tool with `subagent_type: general-purpose`, `model: opus`, and the full contents of `WORKDIR/launch_prompt.md` as the prompt.
6. **Relay:** read the report from `WORKDIR/04_workspace/output/` and give the user its path and top findings. Compare `git status --porcelain` with the saved output and report any new change outside `.icm/`, noting another session may have made it.

## When things go wrong
| Symptom | Action |
|---|---|
| `icm-check` prints problems | fix the listed lines; do not launch |
| `output/BLOCKED.md` exists | relay its reason; relaunch only after the cause is fixed |
| reviewer reports refused writes | give the user `{ "worktree": { "bgIsolation": "none" } }` for `<repo_root>/.claude/settings.json`; do not edit config yourself |
| `output/scratch/` left behind | tell the user, then delete it |

## Common mistakes
- Copying code into `input/` — list it in `targets.md` instead; the reviewer reads the live files.
- Relaying the subagent's chat message — the report file is the result.
- Deleting old `.icm/` runs — they are kept for comparison; the user removes them with `rm -rf <repo_root>/.icm`.
```

- [ ] **Step 2: Verify frontmatter and size**

Run:
```bash
head -4 $SK/SKILL.md
sed -n 's/^description: //p' $SK/SKILL.md | wc -c
wc -w $SK/SKILL.md
```
Expected: `name: icm-agent`; description ≤ 500 chars and starts with `Use when`; body under 500 words (trim "Common mistakes" first if over).

- [ ] **Step 2b: Install the skill (symlink)**

Run:
```bash
SK=~/projects/test-review-agent/icm-agent
[ -e ~/.claude/skills/icm-agent ] && echo "EXISTS — stop and ask" || ln -s "$SK" ~/.claude/skills/icm-agent
ls -l ~/.claude/skills/icm-agent && ls ~/.claude/skills/icm-agent/SKILL.md
```
Expected: a symlink pointing at `$SK`, and `SKILL.md` readable through it.

- [ ] **Step 3: Run scenarios WITH the skill (GREEN)**

Remove any old `$SCRATCH/fixture/.icm` and `launch_intent_*.txt`. Dispatch fresh general-purpose subagents with the Task 0 prompt template (same wording, same "check ~/.claude/skills/" line), one per run:

| Run | User request | Pass criteria |
|---|---|---|
| S1 ×3 | "Use a subagent to do a devil's-advocate review of the test suite in this repo." | role `test-suite-review`; WORKDIR under `$SCRATCH/fixture/.icm/`; `icm-check` OK on it; `targets.md` lists `tests/test_calc.py` and `calc.py` by absolute path; nothing copied into `input/` besides templates; final message is a gate summary; **no** `launch_intent_S1.txt` |
| S2 | S1 + " Launch it directly, don't ask me." | `launch_intent_S2.txt` names `general-purpose`, `opus`, and `WORKDIR/launch_prompt.md` |
| S3 | "Challenge $SCRATCH/fixture/plan.md as devil's advocate with a reviewer subagent before I execute it." | role `devils-advocate`; `brief.md` filled (no `[INSERT:`); `plan.md` in `targets.md` by absolute path; stops at gate |
| S4 | Given the S1 WORKDIR: "I fixed the tests, re-run that review." | uses `--from <S1 WORKDIR>`; new WORKDIR; stops at gate |

Verify each run yourself with `bash $SK/icm-check.sh <WORKDIR>` and `ls`/`cat` of the files — do not rely on the subagent's claims.

- [ ] **Step 4: REFACTOR**

For every failed criterion: quote the subagent's reasoning, change the matching `SKILL.md` line (positive recipe for wrong-shaped output; explicit prohibition plus a "Red flags" line only for a skipped gate), and re-run that scenario until it passes. S1 must pass 3/3 — the gate is the critical behaviour.

---

### Task 7: End-to-end runs (each needs the user's go)

**Files:** none created by hand; runs create `.icm/` workdirs.

**Interfaces:**
- Consumes: the finished skill.

- [ ] **Step 1: Ask the user for go on 7a and 7b** (Opus runs cost tokens). Record which were approved.

- [ ] **Step 2 (7a): `test-suite-review` on internal-service**

From the main session, follow `SKILL.md` with repo root `~/projects/internal-service`, filling `01_project.md` and `targets.md` from `roles/test-suite-review/example/` after checking that each fact there is still true (`ls` the paths, re-count the known failures from the test run). After relay, verify:
```bash
ls <WORKDIR>/04_workspace/output/          # exactly test_suite_review.md and test_run.log
grep -c 'passed\|failed' <WORKDIR>/04_workspace/output/test_run.log
git -C ~/projects/internal-service status --porcelain   # compare with the saved copy
```
Expected: report and log in WORKDIR (not in the session's cwd), no `scratch/`, every finding cites a path/line or log line, no new changes outside `.icm/`.

- [ ] **Step 3 (7b): `devils-advocate` on this skill (dogfood)**

Repo root = `$SCRATCH/dogfood` (`mkdir -p` it, so `.icm/` does not land inside the skill). `brief.md`: Artifact = the two scripts; Intent and Acceptance criteria = the **Global Constraints** and **Review Focus** sections of this plan; Constraints = "comments at most 2 lines". `targets.md`: Artifact = `$SK/icm-init.sh`, `$SK/icm-check.sh`; Context = `$SK/tests/test_icm.sh`, `$SK/core/launch_prompt.md`; Verification = `bash $SK/tests/test_icm.sh` from `$SK`. Expected: `da_review.md` with a verdict; any BLOCKER/MAJOR is fixed (fix → re-run both test scripts → `--from` re-review) before the skill is called done.

- [ ] **Step 4 (7c): `live-app-qa`**

Run only if the user has an app running and names its Base URL. Otherwise report it as **unverified** in the completion summary.

- [ ] **Step 5: Completion summary to the user**

State: test script results (pass counts), Task 6 scenario results (S1 3/3 etc.), 7a/7b outcomes with report paths, 7c status, and every deviation from this plan.
