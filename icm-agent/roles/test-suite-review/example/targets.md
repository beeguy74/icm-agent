# Review Targets
All paths are absolute and read-only. Do not copy or modify them. If any listed path does not exist, halt per `00_system.md`. One absolute path per `- ` line (wrap a path that contains spaces in backticks); anything after the path is a note.

## Review (the test suite)
- /srv/acme-billing/tests/unit/test_invoices.py
- /srv/acme-billing/tests/unit/test_payments.py
- /srv/acme-billing/tests/unit/test_webhooks.py

## Context (code under test)
- /srv/acme-billing/billing/invoices.py
- /srv/acme-billing/billing/payments.py
- /srv/acme-billing/billing/webhooks.py
- /srv/acme-billing/billing/currency.py (no unit tests exist for it)
- /srv/acme-billing/pyproject.toml

## Execution log
- Working directory: /srv/acme-billing
- Command: `PYTHONDONTWRITEBYTECODE=1 python3 -m pytest tests/unit -q -rA -p no:cacheprovider`
- Save the raw output to `04_workspace/output/test_run.log` and cite it in the report.
