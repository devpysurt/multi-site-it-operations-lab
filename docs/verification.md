# Verification record

## Current status — 2026-09-29

The project is published at [devpysurt/multi-site-it-operations-lab](https://github.com/devpysurt/multi-site-it-operations-lab). GitHub Actions has completed successfully on both Windows and Ubuntu.

### Observed CI evidence

| Run | Commit | Observed result | Evidence |
|---|---|---|---|
| PowerShell checks #1 | `b6d7e6f` | Success; both `Test on ubuntu-latest` and `Test on windows-latest` succeeded; two test-result artifacts were produced | [Run summary](https://github.com/devpysurt/multi-site-it-operations-lab/actions/runs/36558859989), shown in the repository owner's screenshot |
| PowerShell checks #2 — Update ci.yml | `f2e0ef8` | Success after the workflow update | Repository owner's screenshot of the [Actions list](https://github.com/devpysurt/multi-site-it-operations-lab/actions), showing the second successful run |

Evidence was reviewed from the GitHub screenshots supplied by the repository owner. Individual test logs and XML artifacts were not inspected for this documentation update; no exact test counts, coverage percentages or runner software versions are asserted.

### Verification coverage and limits

| Area | Status | Scope / remaining work |
|---|---|---|
| GitHub CI on Ubuntu and Windows | **Passed** | Both jobs succeeded in run #1; updated workflow run #2 also succeeded |
| Native PowerShell parsing and module manifest | Covered by successful CI | `scripts/Test-Syntax.ps1` is a required workflow step |
| Pester test suite | Covered by successful CI | Workflow runs `scripts/Invoke-Tests.ps1 -IncludeWindows`; Windows-only cases are skipped on Linux |
| Demo report, inventory and provisioning preview | Covered by successful CI | Demo smoke-test step exercises the public CLI commands |
| Read-only Windows collection | Covered by Windows CI | Included Windows-tagged tests; this does not establish behavior on an employee's workstation |
| Real WinGet installation and repeat installation | **Pending manual verification** | Automated package-operation tests use mocks and do not install example apps |
| Elevation, disconnected network, denied access and VM rollback | **Pending manual verification** | Complete the relevant W01–W14 scenarios in `test-plan.md` |
| Visual report layout in a browser | **Pending manual verification** | HTML structure was checked during authoring; desktop/mobile browser inspection remains open |
| Entra ID / Intune integration | **Not applicable** | Not implemented in v0.1 |

The successful runs establish the result of the configured CI checks, not production readiness or completion of all manual acceptance scenarios.

## Original source-delivery checks — 2026-09-29

At source delivery, the authoring environment was a Linux container with Python and Git. PowerShell, Windows, WinGet and a test tenant were unavailable. Runtime checks had not yet been executed there. The later GitHub CI evidence above supersedes the original "CI not run" status.

| Authoring-time check | Result | Limit |
|---|---|---|
| JSON fixtures/configuration parse | Passed | Independent Python parsing |
| Sample CSV contract and uniqueness | Passed | Static fixture check |
| Local Markdown links | Passed | Relative file targets checked |
| Workflow structure | Passed | YAML structure inspected |
| Static HTML preview | Passed, structure only | HTML parsed; title, table rows, warning and absence of active content checked |
| Whitespace / conflict markers | Passed | Git diff check and source scan |

The committed HTML example was assembled from the module's HTML template and fictional JSON fixture during packaging. It is a static preview, not a live Windows report. The CI demo command separately exercises report generation through PowerShell.

## Manual execution evidence to add

Keep actual failures and follow-up reruns visible. Record the OS, PowerShell and WinGet versions when manual testing takes place. Do not replace pending checks with a blanket pass based on CI.

| Date | Commit | Environment | Scenario | Result | Evidence |
|---|---|---|---|---|---|
| Pending | — | Disposable Windows VM | Manual workstation scenarios W01–W14 | Not run | — |
| Pending | — | Windows with WinGet | Real package installation and repeat-run detection | Not run | — |
| Pending | — | Desktop and narrow browser viewport | Visual report inspection W13 | Not run | — |
