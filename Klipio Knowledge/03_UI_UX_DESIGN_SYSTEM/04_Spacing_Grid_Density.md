# Spacing, grid and density

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Use a 4-unit base with 4/8/12/16/24/32 spacing steps. Compact and comfortable density change padding, not functionality. Panel dividers are visually subtle but have usable hit regions.

## Klipio behavior rules

Align inspector labels and numeric fields in shared columns. Asset grids derive columns from available width. Enforce panel minima; collapse into tabs before hiding actions. Preserve user resizing as workspace state.

## Acceptance and failure checks

Resize continuously, use large text and test minimum window width. No horizontal clipping of Cancel, Apply or validation messages.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

