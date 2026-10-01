# Execution Protocol
Step 1: Read the target application details from Layer 1.
Step 2: Read the test cases from `04_workspace/input/test_cases.md`.
Step 3: Execute each test case against the Base URL with the tools named in Layer 1, following its steps exactly. Record what you observed at every step.
Step 4: Mark each case PASS, FAIL or BLOCKED (could not run — say why). Every FAIL and BLOCKED cites evidence: the HTTP status and a body excerpt, a screenshot saved in `04_workspace/output/`, or console errors. Rate each FAIL Critical / High / Medium / Low by user impact.
Step 5: Generate a test report: a summary table (case, status, severity), then one section per case with the steps run, expected result, observed result and evidence.
Step 6: Save the report to `04_workspace/output/test_report.md`.
