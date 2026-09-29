# Architecture and decisions

## Boundaries

CLI scripts handle default paths, user-facing parameters and process exit codes. The shared `ITOpsLab` module returns data objects, validates contracts and owns side effects. Tests import the module directly; commands remain thin.

| Component | Input | Output | Side effects |
|---|---|---|---|
| Windows collector | Service names | Schema v1 data object | Read-only CIM/service queries |
| HTML renderer | Data object, disk threshold | HTML string | None |
| Report exporter | Data object, output directory | HTML/JSON paths | Unique report directory |
| Inventory validator | UTF-8 CSV | Validity, asset count, errors | None |
| Config reader | JSON | Validated dictionary | None |
| Provisioner | Config, paths, options | Run summary and events | Directories, journal, optional packages |

## Why a module, not a web dashboard

The primary workflow is workstation support. A small module provides inspectable operations, testable logic and a low dependency count. A dashboard would add authentication, hosting and persistence without improving the initial workstation workflow.

## Error model

Collection is best effort: OS, memory, disk and network failures are independent. A single unavailable service does not erase the other findings. Missing information is explicitly unavailable. HTML creation and output write errors are terminating failures.

Inventory validation accumulates errors so the operator can fix multiple records in one pass. Missing headers are reported before row properties are accessed.

Provisioning validates the entire configuration and planned paths before writes. WinGet exit zero indicates an installed match; only `0x8A150014` means no applications found. Any other query code blocks installation for that package. Output text is not parsed because it is localized. Successful install is followed by a detection query.

`Succeeded` in a provisioning summary means no recorded operation failed. It does not imply every requested operation was applied: examine `IsPreview` and the event statuses. A declined `-Confirm` operation is `NotApplied`. Declining the journal prevents an applying run.

## Security and privacy decisions

- No credentials, tenant IDs, employee imports or cloud writes in v0.1.
- Every HTML data value is encoded; no remote fonts, scripts or tracking.
- Native process arguments use .NET `ArgumentList`, not concatenated shell commands.
- Package configuration is data, not executable PowerShell.
- Live reports omit IP/MAC addresses, serial numbers and usernames, but machine names and exception messages can still identify a system.
- Output is ignored by Git, not encrypted or automatically sanitized. Files inherit directory permissions.

## Known limitations

No fleet remoting, central database, concurrent inventory editing, package rollback, install version pinning, cloud identity management or AI integration. No filesystem locking against concurrent changes. No promise of atomic two-file report writes: if disk space disappears between JSON and HTML writes, a partial output directory can remain and the command reports failure. Check the returned success result before treating a report pair as complete.
