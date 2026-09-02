# Animation and keyframe UI

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Property rows expose keyframe enable/current key state. A keyframe lane shares timeline mapping. Show local versus sequence time explicitly where needed.

## Klipio behavior rules

Add/move/delete keys through commands; drag previews and commits once. Interpolation menus list only supported types. Preset entrance/exit/loop indicates interaction with manual keys.

## Acceptance and failure checks

Test exact keys, duplicate-time policy, trimmed clips, backwards seek, group edits, undo and exported animation.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

