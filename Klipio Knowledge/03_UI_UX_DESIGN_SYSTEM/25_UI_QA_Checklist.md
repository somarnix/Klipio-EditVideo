# Klipio UI release gates

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

For every feature record owner, revision, fixture, expected result, observed result, evidence location and unresolved issues. Proposed specifications are not Verified features.

## Klipio behavior rules

Check functionality, component compliance, keyboard, accessibility, undo/redo, persistence, render parity, narrow layout, all feedback states, cancellation and resource budget. Mark irrelevant gates with justification.

## Acceptance and failure checks

Release requires approved artifact identity and installation smoke tests separately from source tests. No screenshot or primary-function test alone establishes production readiness.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

