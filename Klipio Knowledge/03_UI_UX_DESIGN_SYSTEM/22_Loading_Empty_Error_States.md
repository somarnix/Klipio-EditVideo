# Feedback and recovery

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Loading names a phase; empty distinguishes no content from no matches; error names the failed action and recovery. Never replace missing media with a permanently blank strip.

## Klipio behavior rules

Use skeletons only while work is pending. Retry is idempotent. Cancel requested differs from cancelled. Success requires final verification. Preserve completed batch items and edited state after failure.

## Acceptance and failure checks

Test disk full, missing drive, denied access, unavailable model, corrupt package, timeout and retry. Messages redact private paths when exported as diagnostics.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

