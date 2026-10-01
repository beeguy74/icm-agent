---
name: icm-agent
description: Use when a review, devil's-advocate challenge or QA pass should run in an isolated reviewer subagent with a file-based workspace — reviewing a test suite, challenging a code change, plan, spec, config or prompt, or testing a running app against test cases — or when the user mentions ICM or Interpretable Context Methodology.
---

# ICM agent

## Overview
The reviewer subagent's whole context is a workspace of numbered files (`00_system` … `03_task_execution`, `04_workspace/input|output`). You build and fill it, get the user's OK, launch the reviewer, and relay its report from disk.

## Pick the role
| Target | Role | Report |
|---|---|---|
| a test suite | `test-suite-review` | `test_suite_review.md` |
| a running app, against test cases | `live-app-qa` | `test_report.md` |
| anything else: code change, plan, spec, config, prompt | `devils-advocate` | `da_review.md` |

If no role fits, tell the user and offer to add a pack under `~/.claude/skills/icm-agent/roles/`.

## Workflow
1. **Init:** `bash ~/.claude/skills/icm-agent/icm-init.sh <role> <repo_root>` prints WORKDIR (`<repo_root>/.icm/<role>-<timestamp>`). Re-review after a fix: append `--from <previous WORKDIR>`, re-save every frozen input (e.g. `change.diff`), then update what else changed.
2. **Fill:** replace every `[INSERT: …]` in `WORKDIR/01_project.md` and `WORKDIR/04_workspace/input/*`, or delete the line when it does not apply. Files on disk go into `targets.md` by absolute path, one per `- ` line. Material that exists only in this conversation (a diff, pasted text, test cases you wrote) is saved as a file in `input/`. For a code change, freeze it into `input/change.diff` now — uncommitted: `git diff HEAD` plus `git diff --no-index /dev/null <file>` per untracked new file; committed: `git diff <base>..HEAD`. Filled example: `~/.claude/skills/icm-agent/roles/test-suite-review/example/`.
3. **Check:** `bash ~/.claude/skills/icm-agent/icm-check.sh WORKDIR` must print `CHECK OK`.
4. **Gate:** show the user the role and WORKDIR, plus — `test-suite-review`: targets with main paths and the test command; `devils-advocate`: the brief's Intent and Acceptance criteria, and the targets; `live-app-qa`: Base URL, Environment and Test-data rule. Then end your turn and wait for their OK. Continue without waiting only when the user's request already said to launch directly. For `live-app-qa`, close your own Playwright browser first.
5. **Launch:** `bash ~/.claude/skills/icm-agent/icm-guard.sh save WORKDIR`, then one plain Agent call: `subagent_type: general-purpose`, `model: opus`, no `team_name`, prompt = the full contents of `WORKDIR/launch_prompt.md`, verbatim.
6. **Relay:** after the reviewer's completion notification, read the report from `WORKDIR/04_workspace/output/` and give the user its path and top findings. Run `bash ~/.claude/skills/icm-agent/icm-guard.sh check WORKDIR`.

## When things go wrong
| Symptom | Action |
|---|---|
| `icm-check` prints problems | fix the listed lines; do not launch |
| `output/BLOCKED.md` exists | relay its reason; relaunch only after the cause is fixed |
| reviewer reports refused writes | give the user `{ "worktree": { "bgIsolation": "none" } }` for `<repo_root>/.claude/settings.json`; do not edit config yourself |
| `output/scratch/` left behind | tell the user, then delete it |
| `icm-guard` prints `CHANGED <path>` | list those paths for the user — the reviewer or another session wrote them; revert nothing yourself |

## Common mistakes
- Copying code into `input/` — list it in `targets.md` instead; the reviewer reads the live files.
- Writing your own reviewer prompt — use `launch_prompt.md` unchanged.
- Relaying the subagent's chat message — the report file is the result.
- Deleting old `.icm/` runs — the user removes them (`rm -rf <repo_root>/.icm`).
