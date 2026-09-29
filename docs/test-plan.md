# Test plan

## Automated checks

Use `scripts/Test-Syntax.ps1` and `scripts/Invoke-Tests.ps1`. Pester 5.7.1 is pinned so local and CI discovery use the same test framework. The suite deliberately mocks package commands and does not install software.

| Area | Scenarios | Required behavior |
|---|---|---|
| Inventory | Valid sample, duplicate IDs/names/serials, missing headers, empty file, owner/status conflicts | Structured validation errors or valid result |
| HTML | Host/error injection, missing OS/memory, zero-size disks, boundary threshold | Escaped HTML, no division by zero, accurate warnings |
| Export | Repeated export, output parent is a file | Unique report pairs or clear failure |
| Configuration | Traversal, wrong schema, wrong types, reserved names, duplicate packages, unknown keys | Reject before writes |
| Provision | WhatIf, repeated directory setup, obstructing file, opt-in flags | No preview side effects, existing dirs skipped, journal |
| WinGet adapter | Success, documented not-found, source failure | Only not-found allows an install decision |
| CLI | Child-process exit codes, paths with spaces, preview forwarding | Public commands preserve the documented contract |
| Native process | Argument boundaries, output streams, timeout | No shell splitting; bounded process lifetime |
| Windows collection | Missing service while gathering other sections | Partial data, collection issue, renderable output |

The Windows-tagged collection test is read-only. On Linux it is skipped. The module's private native-command helper is mocked for package decision tests.

## Manual Windows acceptance

Record actual results in `verification.md` with date, OS, PowerShell and WinGet versions. Use a disposable VM.

| ID | Action | Pass condition |
|---|---|---|
| W01 | Run live report as a standard user | Report pair opens; denied sections are explicitly listed |
| W02 | Disconnect VM network and collect a report | Local report completes; no claim of internet health |
| W03 | Run a missing service query | Unavailable service and collection issue appear |
| W04 | Deny output-directory write access | Exit 1 and actionable write error |
| W05 | Run setup twice without packages | First creates dirs; second skips them; two journals |
| W06 | Run setup with `-InstallPackages -WhatIf` | No files, logs or WinGet processes created |
| W07 | In a snapshot VM, install reviewed example packages | Absent apps installed and detection verified |
| W08 | Run the package setup a second time | Installed apps skipped; no upgrade |
| W09 | Make source unavailable before a missing-package run | Failure surfaced; no blind installation attempt |
| W10 | Use a standard account with an elevation-requiring package | Prompt/error handled visibly; no false success |
| W11 | Decline a directory operation using `-Confirm` | `NotApplied` event; no directory created for that action |
| W12 | Use a junction within a planned path | Preflight rejects the reparse point |
| W13 | Open HTML in Edge at desktop and narrow width | Readable sections and horizontally accessible tables |
| W14 | Restore the VM snapshot | Lab returns to pre-installation state |

## Release gate

Do not describe CI or Windows behavior as verified until there is execution evidence. Before a public tagged release: parse scripts, pass Pester, run W01/W05/W06/W07/W08, inspect the resulting journals, and check the staged diff for private data. Failed or deferred checks must remain visible in the release notes.
