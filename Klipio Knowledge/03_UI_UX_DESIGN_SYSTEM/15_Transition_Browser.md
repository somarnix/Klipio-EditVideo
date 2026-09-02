# Transition browser adapter

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Reuse browser/card system. Preview shows two scenes and transition duration, not an unrelated animation. Applying requires a valid clip boundary and source handles.

## Klipio behavior rules

Explain shorten/reject/freeze-handle policy before commit. Controls expose duration, alignment and parameters; audio crossfade is explicit. Preview is transient and follows target identity.

## Acceptance and failure checks

Test adjacent speed changes, missing handles, boundary deletion, undo and exported first/last frames.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

