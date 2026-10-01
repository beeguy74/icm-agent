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
