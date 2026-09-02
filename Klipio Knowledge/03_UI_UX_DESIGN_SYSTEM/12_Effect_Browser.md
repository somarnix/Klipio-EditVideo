# Effect browser adapter

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Use Klipio Creative Browser with an effect definition provider. Categories are content metadata. Card previews render supported parameters and disclose capability/access limitations.

## Klipio behavior rules

Hover/explicit preview creates a token-bound transient layer. Leaving restores display without mutating project. Apply validates selected target and commits one stack insertion. Stack controls support reorder, bypass and remove.

## Acceptance and failure checks

Test GPU-unavailable behavior, stale download, duplicate click, undo, reordered effects and parity. Never silently present a missing effect as successfully applied.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

