# Product roadmap — eleven gated stages

Status: proposed, not a delivery-date promise. Dependencies determine order. Basic security, accessibility, performance budgets, and recovery begin at Stage 0 and deepen later.

## Stage 0 — Clean foundation

Goal: Stable identities, time units, command boundaries, save/recovery and diagnostics.

Features: Typed IDs; half-open ranges; revision snapshots; migration fixtures.

Architecture: Editor Core and persistence ports.

Dependencies: Existing behavior fixtures.

Risks: Refactor changes behavior; old projects fail.

Required tests: Command inverse properties; reopen fixtures; interrupted save.

Definition of Done: A small project reopens and renders identically; source ownership documented.

## Stage 1 — Basic editor

Goal: Complete offline import-to-export journey.

Features: Import; one sequence; trim; playback; audio; export profiles.

Architecture: Media adapter, snapshot resolver, export coordinator.

Dependencies: Stage 0 invariants.

Risks: Decoder failures; incorrect dimensions; runtime dependencies.

Required tests: Synthetic media end-to-end; disconnected source-runtime test.

Definition of Done: One workflow exports correct frames/audio without account or source-code drive.

## Stage 2 — Strong timeline

Goal: Predictable reversible editing.

Features: Split; ripple; slip; roll; links; groups; snapping; multiselect.

Architecture: Pure timeline commands and interaction sessions.

Dependencies: Basic media and time mapping.

Risks: Desync, boundary drift, lock violations.

Required tests: Random edits; execute/undo/redo; mixed-rate fixtures.

Definition of Done: All defined operations preserve timing/link invariants and recover with undo.

## Stage 3 — Professional editing

Goal: Precise picture, captions, text and audio controls.

Features: Transforms; canvas; manual/auto captions; basic color; inspector.

Architecture: Composition-space render contract and text shaping.

Dependencies: Strong timeline; fonts; deterministic snapshot.

Risks: Preview/export mismatch; script shaping failure.

Required tests: Cross-ratio golden frames; Khmer; settings-copy tests.

Definition of Done: Same-time export comparison passes documented tolerances.

## Stage 4 — Creative content systems

Goal: Scale content without bespoke widgets.

Features: Definitions; presets; templates; fonts; registry; downloads.

Architecture: Versioned manifest, resolver, authoring validator.

Dependencies: Stable render primitives and persistence.

Risks: Unknown primitives; dependency/version drift.

Required tests: Ten package types; corruption; offline reopen; upgrade.

Definition of Done: Curated packages survive download, pinning, upgrade and recovery.

## Stage 5 — Performance

Goal: Sustain responsive editing under measured load.

Features: Proxies; caches; virtualization; bounded workers; profiling.

Architecture: Resource scheduler and quality policy.

Dependencies: Budgets begin at Stage 0; real workloads now available.

Risks: Memory pressure; device loss; cancellation leaks.

Required tests: Long-media soak; resource caps; process exit checks.

Definition of Done: Reference benchmark published with stable resource use and limitations.

## Stage 6 — Advanced editing

Goal: Add compositional power.

Features: Ramps; masks; blend modes; nested sequences; multicam; scopes.

Architecture: Time-map evaluator, graph extensions, sync groups.

Dependencies: Stable render/audio/time contracts.

Risks: Complexity and cache explosion.

Required tests: Reverse/ramp boundaries; nesting cycles; angle cuts.

Definition of Done: Advanced fixtures pass preview/export and recovery gates.

## Stage 7 — AI

Goal: Reviewable intelligent assistance.

Features: Translation; tracking; reframing; cleanup; smart-cut proposals.

Architecture: AI adapter and artifact review workflow.

Dependencies: Jobs, snapshots, consent and resource controls.

Risks: Quality variability; privacy; cost duplication.

Required tests: Representative evaluation; stale result; retry/cancel.

Definition of Done: Results are editable, traceable, budgeted and safely cancellable.

## Stage 8 — Cloud

Goal: Optional durable connected workflows.

Features: Backup; sync; comments; later live collaboration.

Architecture: Revision API, blob storage, authorization and job persistence.

Dependencies: Local-first save, stable schema/IDs.

Risks: Conflict loss; tenant leaks; outages.

Required tests: Offline edits; upload resume; conflict; restore; authorization.

Definition of Done: Cloud outages do not break local work; conflicts preserve both branches.

## Stage 9 — Creator ecosystem

Goal: Controlled third-party content supply.

Features: Submissions; moderation; licensing metadata; distribution; entitlements.

Architecture: Catalog governance and business boundaries.

Dependencies: Content registry, backend, operational review.

Risks: Malicious content; rights disputes; broken updates.

Required tests: Package safety; review flow; rollback; account compromise.

Definition of Done: Private pilot passes rights/security/operations review before public release.

## Stage 10 — Master platform

Goal: Sustainable multi-platform product.

Features: Capability-based platforms; supported plugins; mature operations.

Architecture: Stable public APIs, ownership and compatibility processes.

Dependencies: Prior stages evidenced; team capacity.

Risks: Overexpansion; unsupported promises; maintenance debt.

Required tests: Cross-platform conformance; sandbox tests; incident drills.

Definition of Done: Published support matrix and sustained reliability; not an unlimited feature checklist.

## Planning discipline

Take one vertical slice per milestone. Estimate only after a prototype and measured team throughput. Reserve time for regression, migration, accessibility and failure testing. Record evidence links for each exit gate. A stage is not complete because its folders exist or its UI has buttons.

