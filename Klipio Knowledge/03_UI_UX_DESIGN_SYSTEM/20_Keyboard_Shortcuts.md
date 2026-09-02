# Keyboard shortcut system

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

One command registry maps IDs to editable bindings, scope and display labels. Scopes distinguish text input, workspace, timeline and modal dialogs. Proposed bindings require conflict validation.

## Klipio behavior rules

Do not hijack typing keys inside text fields. Offer reset/import/export bindings with validation. Platform modifier labels adapt. Every essential drag operation has keyboard/numeric alternative.

## Acceptance and failure checks

Test conflicts, localized keyboards, modal focus traps, undo scope, disabled commands and tooltips reflecting customized bindings.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

