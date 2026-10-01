# Project Context
- Target Application: [INSERT: app name, what it does, and the features the test cases touch]
- Base URL: [INSERT: the only URL the agent may call, e.g. http://localhost:3000]
- Environment: [INSERT: local, staging or production; for production add "approved by the user for this run" only if they said so]
- Test credentials: [INSERT: path to a credentials file or the names of the env vars that hold them — never the secret values]
- Tools: [INSERT: how to drive the app — Playwright MCP browser tools, curl, or both]
- Test data: [INSERT: which data the agent may create and how to recognise it, e.g. names prefixed `icm-qa-`]
- Artifact Locations: Test cases are in `04_workspace/input/test_cases.md`.
