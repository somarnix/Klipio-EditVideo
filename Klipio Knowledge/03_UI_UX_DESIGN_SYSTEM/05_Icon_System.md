# Klipio icons

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Use one documented icon family or original consistent set with recorded licensing. Icons share optical size, stroke weight, alignment and filled/outline policy. Do not mix arbitrary downloaded sets.

## Klipio behavior rules

KlipioIconButton always has an accessible name; tooltips show action and active shortcut. Destructive icons have confirmation or undo policy. Cursor changes reflect an enabled interaction, not decoration.

## Acceptance and failure checks

Check unknown icons with users, keyboard discovery, disabled meanings and high-density rendering. An icon alone must not distinguish success from failure.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

