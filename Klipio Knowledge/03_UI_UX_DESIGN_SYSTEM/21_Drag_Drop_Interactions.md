# Drag and drop contracts

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Drag session captures source IDs, revision, anchor and proposed destination. Validate media type, locks, supported operation and bounds before showing a valid target.

## Klipio behavior rules

Preview never mutates durable state. Autoscroll is bounded. Escape/pointer cancel discards proposal. Release commits once after revision validation. Cross-app file drop validates paths and media asynchronously.

## Acceptance and failure checks

Test invalid target, lost pointer, selection change, source removal, delayed metadata, undo and no accidental copy/move duplication.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

