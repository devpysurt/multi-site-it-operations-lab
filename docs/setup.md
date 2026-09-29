# Setup and operation

## Supported design targets

- PowerShell 7.4 or newer (Core edition).
- Windows 11 lab workstation for live CIM/service collection and WinGet installation.
- Windows or Linux with PowerShell for demo, validation, directory-only provisioning and unit tests.
- WinGet installed and registered for the current Windows user for package operations.
- Pester 5.7.1 only for tests; no extra PowerShell module is needed for normal local operations.

These are design targets, not a claim of completed compatibility certification. See `verification.md`.

## Lab preparation

1. Create a disposable Windows VM and record the OS, PowerShell and WinGet versions.
2. Take a VM snapshot before software installation tests.
3. Extract/clone the repository into a directory you own.
4. Open `pwsh` in the repository root. Do not weaken machine-wide execution policy as a setup shortcut. If Windows marks downloaded files as blocked, review the files and use your organization's approved unblocking/signing procedure.
5. Run the demo, syntax checker and test suite before applying changes.

A standard user should be sufficient for the demo and directory-only setup within their writable folder. CIM information may be restricted by policy; the report records these collection errors. Package installer elevation depends on the package. No automatic administrator relaunch is implemented.

## Local configuration

Copy `config/workstation.example.json` to `config/workstation.local.json` and edit the copy. Pass it with `-ConfigPath`.

The configuration parser rejects unknown keys to catch typos. Directories must be relative child paths made of letters, digits, underscores or hyphens, separated by `/` or `\`. Absolute paths, parent traversal and reserved Windows names are rejected. Existing symlink/junction ancestors are refused for provisioning. This reduces accidental redirection; it is not protection against a concurrent privileged attacker changing the filesystem.

Package entries contain only `id`. No arbitrary commands, installer arguments, shell expressions or URLs can be embedded in configuration. Package versions are not pinned; the initial installation uses the version resolved by the WinGet source at execution time. Existing versions are not upgraded. Version pinning is a future feature.

## Journaling and failure behavior

A unique JSON-lines journal is created before changes. Each attempted action gets `Started` and a final event where possible. A final event may be missing if the process is interrupted; inspect the machine before retrying. A write failure stops the run. If installation fails, subsequent package operations are not attempted. Previously completed changes remain applied.

Process timeout: 60 seconds for an installed-state query, 600 seconds for installation. A timed-out process tree is terminated where possible; an installer service can outlive it. No reboot is requested by this project, but package-specific behavior requires VM validation.

WinGet queries can contact its source. This is why `-WhatIf` does not run them. Package/source agreement acceptance is explicit for an applying run. The workflow does not support SYSTEM-account or unattended fleet deployment.

## Clean up the lab

Keep records you need before cleanup. The default `reports`, `logs` and `workstation` folders contain local output. Delete them manually only after checking their contents. Restore the VM snapshot to undo package installations. Deleting the project folder does not uninstall software.
