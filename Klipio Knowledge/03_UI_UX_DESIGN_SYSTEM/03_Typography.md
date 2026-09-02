# Typography and Khmer

Status: Specified design proposal; implementation compliance needs evidence.

## Purpose and contract

Use semantic roles: heading, panel title, body, label, metadata and timecode. Proposed body size 14 logical pixels, labels 12–14, headings 18–24; user scaling overrides density. Timecode uses tabular digits where available.

## Klipio behavior rules

Declare licensed UI fonts with Khmer shaping/fallback support. Do not truncate essential numeric values. Show complete asset names through accessible labels/details. UI font tokens are separate from composition font assets and export font metrics.

## Acceptance and failure checks

Test Khmer clusters, mixed English/Khmer, emoji, long translated labels, 200% text and missing fonts. Verify labels do not overlap inputs.

## Ownership

Klipio UI System owns presentation behavior. Durable editing changes go through Klipio Editor Core commands; widgets must not own a second project model. See [implementation status](../CURRENT_IMPLEMENTATION_STATUS.md) before assuming this specification exists in the app.

