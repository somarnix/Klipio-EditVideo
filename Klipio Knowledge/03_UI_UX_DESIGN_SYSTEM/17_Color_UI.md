# Klipio Color UI

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Basic adjustments precede curves/HSL/wheels/LUTs/scopes. Label source/working/output scope point and unsupported color modes. Reset applies to selected adjustment group only.

## Klipio behavior rules

Preset intensity and manual settings must show their composition order. Temporary look preview is isolated. Warn for unknown source metadata rather than imply calibrated accuracy.

## Acceptance and failure checks

Test neutral reset, mixed selection, clipping indication, SDR reference charts, backend parity and scope updates that do not block dragging.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

