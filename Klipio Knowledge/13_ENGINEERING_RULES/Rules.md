# Engineering rules and feature template

## Nonnegotiable invariants

One durable project state; explicit IDs and units; pure command validation; immutable export snapshot; versioned content; bounded jobs; recoverable save; no silent feature loss. UI state is not render authority.

## Source organization

Prefer cohesive modules with narrow public APIs. Investigate large files, but do not mechanically create dozens of shared-state fragments. No empty scaffold folders without an implementation purpose. Shared utilities must have precise names and ownership.

## Async review

Who owns the job? How is it cancelled? What happens on disposal? How are stale results rejected? What limits resources? How are exceptions surfaced? Can an older save overwrite a newer one? Which process IDs may be terminated?

## Feature specification template

1. Problem and affected user journey.
2. Requirements and non-goals.
3. Owner and module dependencies.
4. Data model, identity, units, schema changes.
5. Public API and validation.
6. UI states, keyboard and accessibility.
7. Commands, transactions, undo/redo.
8. Render and audio semantics.
9. Persistence and migrations.
10. Cancellation, errors, recovery.
11. Tests and fixtures.
12. Performance budgets and benchmark device.
13. Diagnostics and privacy.
14. Documentation and rollout.
15. Definition of Done and known limitations.

## Definition of Done

Requirements trace to tests. Domain and adapter tests pass. Preview/export parity checked when applicable. Save/reopen verified. Cancellation releases owned resources. Errors preserve user data. Documentation distinguishes implemented from proposed. Release artifacts are separately built, installed and smoke-tested when authorized.

## Architecture decision record

Title/date/status; context; alternatives; decision; consequences; evidence; revisit trigger. Example decision: composition-space text metrics instead of screen-space values. Consequence: renderer needs deterministic font resolution; evidence: cross-resolution parity fixture.

## Cleanup rule

Identify call sites and tests before removing code. Preserve user data and historical artifacts unless explicitly authorized. A documentation task does not authorize app rewrites, installer replacement, or GitHub publishing.



## Status and evidence discipline

Use [Current Implementation Status](../CURRENT_IMPLEMENTATION_STATUS.md) for current evidence. Verified requires all relevant lifecycle gates, not merely execution of a primary function. Released additionally requires approved artifact and installation evidence. Benchmarks must record hardware, OS, fixture, version and date; absent results remain Not measured.

Required workflow: observe user problem → research when useful → define Klipio experience → owning system → data → command/API → UI states → engine → Klipio UI components → persistence → parity → tests → benchmark → status → documentation → release.

Engineering and content are parallel tracks with shared compatibility gates. Do not rename Klipio systems after references or compensate for incorrect rendering by increasing preset count.
