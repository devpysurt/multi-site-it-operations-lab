# Multi-site IT Operations Lab

A practical PowerShell portfolio project for supporting Windows workstations across several company locations. It covers workstation diagnostics, repeatable setup, asset validation and user-facing support documentation.

**Version:** 0.1.0 · **Runtime:** PowerShell 7.4+ · **License:** MIT

> Fictional training environment. This project is not affiliated with Samherji or any other employer. All sample people, devices and operational details are invented.

[Start in Russian](docs/START-HERE.ru.md) · [Setup](docs/setup.md) · [Architecture](docs/architecture.md) · [Test plan](docs/test-plan.md) · [Verification status](docs/verification.md)

## What you can demonstrate

- Collect Windows OS, memory, disk, physical network adapter and selected service information.
- Produce standalone HTML and JSON reports, preserving partial results when a collector fails.
- Preview a workstation setup without launching WinGet or writing logs/directories.
- Create a workspace and optionally install missing packages using exact WinGet identifiers.
- Validate a multi-site equipment CSV with duplicate and assignment checks.
- Explain support procedures to nontechnical employees in English.

A disconnected network adapter is not proof of an internet outage, and a stopped service is not automatically a fault. The report makes these distinctions explicit.

## Try the offline demonstration

From the repository root in **PowerShell 7.4+** (`pwsh`, not Windows PowerShell 5.1):

```powershell
./scripts/Get-WorkstationReport.ps1 -Demo
./scripts/Test-AssetInventory.ps1
./scripts/Initialize-Workstation.ps1 -InstallPackages -WhatIf
```

The report command prints the output paths. Open the generated `report.html` in your browser. Alternatively, open [the static demo preview](examples/workstation-report.demo.html) after downloading the repository. The static preview uses fictional fixture data; it is not evidence of a live Windows run.

The offline demo and directory-only provisioning are designed to run on any OS with PowerShell 7.4+. Live collection and package installation require Windows. See [verification status](docs/verification.md) for what has actually been executed.

## Collect a Windows report

```powershell
./scripts/Get-WorkstationReport.ps1 -FreeSpaceWarningPercent 20
./scripts/Get-WorkstationReport.ps1 -ServiceNames Spooler,wuauserv -OutputDirectory ./reports
```

Each run creates a uniquely named directory with `report.json` and `report.html`. Collection failures are listed inside the report. File write failures stop the command with exit code 1. No remote connections or settings changes are performed by the collector.

## Prepare a workstation

Review `config/workstation.example.json` first. It specifies relative directories and two example packages: Visual Studio Code and 7-Zip. Neither package is a required company standard.

```powershell
# Preview all requested operations. No installed-state queries or writes.
./scripts/Initialize-Workstation.ps1 -InstallPackages -WhatIf

# Create directories and a JSON-lines journal; do not install packages.
./scripts/Initialize-Workstation.ps1

# Windows lab VM only: explicitly opt in to installation and agreement acceptance.
./scripts/Initialize-Workstation.ps1 -InstallPackages -AcceptPackageAgreements
```

Defaults stay inside the repository: `workstation/` and `logs/`. Override these with `-WorkspaceRoot` and `-LogDirectory`. Local configuration belongs in `config/workstation.local.json` (ignored by Git).

Existing directories and detected packages are skipped. The command does not upgrade applications, rename the computer, change execution policy, create accounts or restart the machine. Installers may request elevation; run from an appropriate authorized account. There is no automatic elevation or rollback. On a package failure the package loop stops; inspect the journal and workstation before retrying.

`-WhatIf` reports planned operations, **not a successful configuration**. It deliberately does not check whether packages are installed. `-Confirm` is also supported.

## Validate equipment records

```powershell
./scripts/Test-AssetInventory.ps1 -Path ./data/assets.example.csv
```

Required columns: `AssetId, DeviceName, SerialNumber, Site, AssignedTo, Status`.

Identifiers, serial numbers and device names must be unique after trimming and case-insensitive comparison. Allowed statuses are `InStock`, `Assigned`, `Repair`, `Retired`. Assigned assets require an owner; stock and retired assets must have none. Row numbers in errors count CSV records including the header, not physical lines inside quoted multiline fields.

| Command | Exit code 0 | Exit code 1 | Exit code 2 |
|---|---|---|---|
| Report | Files written, possibly with collection issues | Runtime / write failure | — |
| Provision | No failed recorded action (may include skipped/declined actions) | Preflight or action failure | — |
| Inventory | Valid inventory | Read / runtime failure | Invalid inventory |

Library functions return structured objects and throw terminating errors for preflight failures; CLI exit codes belong to the wrapper scripts.

## Test

```powershell
Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser
./scripts/Test-Syntax.ps1
./scripts/Invoke-Tests.ps1
# On Windows, also include read-only live collection:
./scripts/Invoke-Tests.ps1 -IncludeWindows
```

Tests exercise validation, HTML escaping, thresholds, report file output, provisioning idempotency, WhatIf and WinGet error classification. Package processes are mocked in automated tests; CI never installs the example apps. A GitHub Actions workflow is included for Windows and Linux. It has not run on GitHub yet.

## Repository map

| Path | Purpose |
|---|---|
| `src/ITOpsLab/` | Shared module, data collection, validation and provisioning |
| `scripts/` | CLI entry points and test commands |
| `config/` | Example workstation setup |
| `data/` | Six fictional assets at three locations |
| `examples/` | Fictional JSON fixture and static HTML preview |
| `tests/` | Pester tests |
| `docs/knowledge-base/` | Five employee support guides |
| `docs/` | Setup, architecture, test plan, handover and release instructions |
| `.github/` | CI and contribution templates |

## Scope and roadmap

This release is a local workstation support lab. Entra ID, Microsoft 365, Intune and AI are **planned extensions**, not implemented integrations. [The roadmap](docs/roadmap.md) defines their acceptance criteria and prerequisites. There are no tenant credentials or simulated cloud success claims in this release.

See [SECURITY.md](SECURITY.md) before sharing live diagnostic output and [CONTRIBUTING.md](CONTRIBUTING.md) before changing the code.
