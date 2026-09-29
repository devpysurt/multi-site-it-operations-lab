# Roadmap

## v0.1 — local operations lab (implemented, execution verification pending)

Windows diagnostics, offline demo, HTML/JSON export, workstation configuration, journal, asset validator, English support guides, Pester suite and GitHub Actions configuration.

## v0.2 — Entra ID / Microsoft 365 onboarding

Prerequisites: a dedicated test tenant, approved Graph permissions and appropriate licenses. Never run onboarding against an employer tenant without authorization.

Planned implementation: validate a CSV of fictional employees; resolve explicit group IDs; preview a change plan; create only missing users; record creation and group membership results. Use interactive authentication and avoid storing secrets in the repository. Do not email credentials or write passwords into logs. Decide a secure initial credential handover method before implementation.

Acceptance: dry run performs no writes, duplicate input fails before writes, existing users are handled explicitly, group ambiguity fails closed, permission errors are actionable, and test accounts/groups can be removed through documented cleanup. Record tenant-specific test evidence.

## v0.3 — Intune device management

Prerequisites: licensed test tenant, Windows test device and appropriate administrative permissions.

Planned implementation: document enrollment, a small compliance policy and a read-only device report using Graph. Distinguish stale/check-in data from current endpoint state. Export only sanitized examples.

Acceptance: real test-device enrollment is documented, compliant/noncompliant examples are explained, policy assignments and cleanup are reproducible. Do not claim Intune compliance from the local diagnostic report.

## v0.4 — AI knowledge-base assistant

Planned implementation: answers drawn from the five approved support guides, with document citations and explicit escalation when the answer is absent. No automatic administrative actions. Separate evaluation cases from the source documents.

Acceptance: relevant citations, refusal to invent procedures, resistance to instructions embedded in user tickets, no sensitive ticket data in telemetry, measured performance on a small manually reviewed question set. Start with a local retrieval baseline before adding a model provider.
