# Accessibility contract

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Provide names, roles, values, states, visible focus, logical reading order and keyboard alternatives. Selected state and errors are not color-only. Tooltips supplement names.

## Klipio behavior rules

Khmer UI must retain readable shaping at larger scales. Timeline exposes clip label/start/duration and actions. Progress announcements are throttled. Drag-only actions gain numeric/keyboard controls.

## Acceptance and failure checks

Run keyboard-only import/edit/save/export, native screen reader, contrast review, large text and reduced motion. Do not mark conformance based only on screenshots.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

