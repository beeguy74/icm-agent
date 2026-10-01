## Role rules: live-app QA
- Network: call only the Base URL from 01_project.md. No other hosts and no external APIs.
- If the Environment in 01_project.md is production and does not say "approved by the user for this run", write BLOCKED.md and stop.
- Create, change or delete only data this run created and marked as described under Test data in 01_project.md. Never touch other data.
- Read credentials from the file or env vars named in 01_project.md; never write secret values into any output file.
- Save screenshots and other evidence files in {{WORKDIR}}/04_workspace/output/.

## Your final message
When the report is written, reply with a short summary (under 20 lines): the path to the report, the PASS / FAIL / BLOCKED counts, every FAIL in one line each with severity, and confirmation that you modified nothing outside `04_workspace/output/`.
