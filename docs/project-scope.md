# Project scope

## Fictional operating context

A fictional aquaculture business has workstations at Reykjanes, Akureyri and Dalvik. The names provide a realistic multi-site story; they are not a statement about any real company's systems. Six example assets cover assigned, stock, repair and retired states.

## v0.1 acceptance criteria

- A technician can create a readable HTML report and machine-readable JSON.
- One failed collector leaves other collected data available.
- Low disk space is visible using a configurable threshold.
- Inventory rejects duplicate equipment and inconsistent assignments.
- A setup preview causes no filesystem writes or WinGet process launches.
- Repeated setup skips existing directories and detected applications.
- Invalid configuration fails before setup writes.
- Applying setup produces an action journal.
- Installation failures are surfaced, not silently interpreted as success.
- A new contributor can follow the README and run the provided test commands.

Implementation is included for these criteria. Execution evidence and outstanding manual checks are tracked separately in `verification.md`.

## Job-to-evidence mapping

| Vacancy responsibility | Repository evidence |
|---|---|
| Equipment setup and management | Setup command, CSV inventory, handover checklist |
| Employee support | Diagnostic report and English knowledge base |
| System operation | Error handling, logs, repeatable setup and test plan |
| New site implementation | Fictional multi-site scenario and onboarding workflow |
| Microsoft environment | Windows CIM/services and PowerShell; cloud expansion plan |
| Intune / AI interest | Scoped future work with explicit acceptance criteria |

This project does not demonstrate Icelandic fluency, professional production experience or driving eligibility. Describe it honestly as a personal lab in applications.
