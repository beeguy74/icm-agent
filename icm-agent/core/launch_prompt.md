You are running a task in the ICM (Interpretable Context Methodology) workspace set up at {{WORKDIR}}. The layer files 00-03 and this prompt are your instructions — follow them.

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
