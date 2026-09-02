# Klipio Preview Monitor

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Label source and program monitors distinctly. Program monitor represents committed composition plus explicitly transient preview. Letterboxing the monitor viewport must not become stored canvas geometry.

## Klipio behavior rules

Gizmos use inverse screen/composition mapping. Provide numeric alternatives and safe-area guides. Show preparing/buffering/failed states with phase and retry. Quality/proxy controls change preview cost, not edit intent.

## Acceptance and failure checks

Test identical coordinates at multiple viewport sizes, pointer cancellation, aspect changes, frame step and same-time export comparison.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

