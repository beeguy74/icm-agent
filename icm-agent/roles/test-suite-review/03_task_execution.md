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
