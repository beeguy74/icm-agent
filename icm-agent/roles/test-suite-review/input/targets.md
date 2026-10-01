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
