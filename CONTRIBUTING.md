# Contributing

1. Create a branch for one focused change.
2. Keep CLI defaults and exit codes documented.
3. Add meaningful tests for changed behavior, especially failure handling and side effects.
4. Run `scripts/Test-Syntax.ps1` and `scripts/Invoke-Tests.ps1`.
5. If changing Windows integration, run the applicable VM scenarios in `docs/test-plan.md`.
6. Update docs and describe remaining limitations in the pull request.

Use PowerShell 7.4+ syntax, four spaces, approved verbs for public functions and comments explaining non-obvious decisions. Do not commit generated reports, journals, employee records, credentials or tenant exports.

Do not replace a failing check with a success claim. Record what ran, on which environment, and what was skipped. Package installation must remain opt-in, and `-WhatIf` must remain free of writes and native package queries.
