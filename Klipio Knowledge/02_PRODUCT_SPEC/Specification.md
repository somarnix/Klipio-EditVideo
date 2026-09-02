# Product specification

Status: proposed. Owner role: product lead with editor-core and design maintainers.

## Users and promises

A beginner needs a complete understandable workflow. A frequent creator needs precise reusable editing. A future team needs sharing and review. Build for the first two before live collaboration.

Core promise: reopen preserves intent; preview and export agree; failures preserve user work. Local editing must not depend on account availability. Missing external media is distinct from missing app runtime.

## Primary journeys

| Journey | Preconditions | Successful result | Failure behavior |
|---|---|---|---|
| Import seven videos | Readable files | Seven independent asset records and posters | Individual retry; no silent replacement |
| Edit one clip | Selected clip ID | Only its settings change | Locked/invalid command explained |
| Apply selected | Source revision and exact targets | Chosen groups copied once | Atomic rejection under lock conflict |
| Generate captions | Captured edited audio | Reviewable timed document | Completed items retained |
| Export batch | Valid snapshots and destination | Correct named outputs | Per-item failure, retry, diagnostics |
| Reopen elsewhere | Project and managed media | Same composition | Relink unavailable external media |
| Cancel worker | Owned running job | Worker exited, project intact | Escalation status until confirmed |
| Install offline | Complete approved setup | Runtime launches without source drive | Clear missing optional model message |

## Requirements

R1: project identity never uses a display filename.
R2: source time, sequence time, and screen positions use distinct types/units.
R3: changes pass through commands with documented undo behavior.
R4: selection does not mutate other clips or running jobs.
R5: export dimensions are explicit, not inferred from a quality label.
R6: captions use composition coordinates and versioned fonts/styles.
R7: background jobs are bounded, cancellable, and revision-aware.
R8: errors offer a relevant recovery action and preserve project data.
R9: thumbnails have per-asset and per-time keys.
R10: unsupported features are disclosed rather than silently flattened or dropped.

## Explicit non-goals for the first release gate

Do not simultaneously implement cloud collaboration, public marketplace, native third-party plugins, generative video, HDR grading, and multicam. Do not use catalog count as a release-readiness measure.

## Acceptance scenario

Use generated assets A and B with different frame labels and audio ticks. Import both, trim A, set A speed to 2, add 3:4 canvas and text, copy only canvas to B, and then change A scale again. Save, reopen, export separately. Assert B speed unchanged; A latest scale retained; exact dimensions; expected source frame at each test time; captions within declared bounds; each item's progress and final status correct.

## Open product decisions

Choose reference hardware, supported source limits, first-platform scope, initial codec profiles, managed-media default, offline entitlement policy, and acceptable render tolerances before promising compatibility. Track decisions, not assumptions disguised as requirements.

