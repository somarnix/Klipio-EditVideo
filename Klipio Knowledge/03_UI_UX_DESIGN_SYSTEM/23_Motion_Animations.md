# Klipio UI motion

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Proposed UI transitions 120–180 ms for local emphasis and 180–240 ms for panel transitions, subject to measurement/user testing. These are not benchmark claims. Use motion to explain continuity, not hide latency.

## Klipio behavior rules

Reduced motion removes nonessential movement. Preview animation has CPU/GPU budget and stops off-screen. Loading animation does not imply real progress. UI motion never controls project animation time.

## Acceptance and failure checks

Test rapid interruption, low frame budget, reduced motion, focus stability and no project revision from UI animation.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

