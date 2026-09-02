# Menus and context menus

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

KlipioContextMenu derives actions from target identity, lock and capability. Order common edits first, object-specific actions next, destructive actions last. Show shortcut hints from the same registry.

## Klipio behavior rules

Right-click preserves or updates selection through a documented policy before opening. Keyboard menu invocation works. Menu dismissal restores focus. Disabled actions show reasons without becoming executable.

## Acceptance and failure checks

Test no-target menus, multiselect, text-input context menus, Escape, focus return and selected object disappearing while menu is open.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

