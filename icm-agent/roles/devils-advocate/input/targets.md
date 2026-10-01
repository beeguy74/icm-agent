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
