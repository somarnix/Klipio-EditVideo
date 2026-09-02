# Klipio Professional Product Experience

Status: Specified. A working function is not automatically a complete feature.

Lifecycle: Discover → Open → Configure → Preview → Apply → Edit → Undo/Redo → Save → Reopen → Export → Recover.

A complete caption experience includes Generate, Progress, Cancel, Review, Edit, Style, Timing, Animation, Apply selected, Undo, Save, Reopen, Export and Retry. Completed batch documents survive later failures; stale results cannot replace current edits.

## Preview-first contract

Effects, filters, transitions, text/caption styles, animations and LUTs use temporary previews where practical. Start captures target/revision and creates a transient overlay. Leave/Escape/selection change discards the overlay. Apply validates and commits one command with undo. Autosave and export exclude transient previews.

Never implement hover by mutating durable state and hoping to undo it before save. Late downloads carry preview tokens. Keyboard/touch have explicit preview actions. Test hover/leave with zero revisions, click once, undo, stale target and export during preview.

## Parallel delivery tracks

Engineering owns timeline, rendering, playback, audio, text, effects, animation, export and measured performance.
Creative content owns original presets, transitions, text/caption styles, animation, stickers, templates, LUTs, licensed music/sounds, thumbnails and preview media.

Content cannot hide incorrect rendering; a capable engine still needs useful content. Each content version needs provenance, dependencies, supported primitives and preview/export checks.

## Delivery rule

Observe user problem → useful external research → define Klipio experience → owning Klipio system → data model → command/API → UI states → engine → shared UI → persistence → parity → tests → benchmarks → implementation status → knowledge update → release.

Verified requires relevant functionality, UI compliance, keyboard/accessibility, undo, persistence, parity, loading/empty/error/retry, cancellation, budgets, regression tests and documentation. Released additionally needs approved artifact and installation evidence.

See Part 49 in the [English book](../01_KLIPIO_MASTER_BLUEPRINT/English.md) and [Khmer book](../01_KLIPIO_MASTER_BLUEPRINT/Khmer.md) for the expanded teaching chapter.

