# Klipio Caption Engine

Document: Klipio Caption Engine
Product: Klipio
Status: Active Specification
Document Version: 1
Last Updated: 2026-09-07
Implementation Authority: No

Status: Specified. Reuse Klipio Text Engine primitives through an interface; do not merge transcript jobs and glyph rendering into a global controller.

## Documents and timing

CaptionDocument includes identity, language, revision provenance, segments, word intervals, optional speaker information and style references. Time domain must be explicit: source, captured sequence, or another declared map. Manual captions and SRT/VTT import normalize to the internal model while preserving supported metadata.

Automatic captions consume captured edited audio. Results include input hash/model/version. A changed timeline requires remapping or review; no silent overwrite. Translation creates a reviewable language variant and does not replace the original without consent.

## Editing workflow

Generate → progress/cancel → review → transcript/timing → style/layout → animation/karaoke → apply selected → undo/save/reopen/export/retry.
Caption tracks have stable IDs and lock behavior. Word highlighting maps time to shaped text clusters. Segment/word overlap policy and empty words are validated.

Apply to All is an explicit target command: resolve numbers to identities, capture latest selected style, copy only chosen groups, preserve transcript/timing unless explicitly requested, validate locks and commit atomically. Mixed selections retain unrelated differences.

## Jobs and parity

Each batch item has independent status and persisted successful output. Retry failed items without duplicating tracks. Cancellation is terminal only after owned workers stop. Save documents and pinned style/font dependencies separately from analysis caches.

Tests: SRT/VTT edge timestamps; cut/speed remapping; absent speech; Khmer karaoke; speaker edits; failed third batch item; stale results; locked tracks; repeated Apply selected; undo; reopen; exported text bounds and timing.



## Khmer segmentation contract

Caption segmentation must not assume spaces identify every word in Khmer. Preserve transcript offsets and a mapping from timed segments/words to Unicode text and shaped clusters. Recognition word boundaries may require review before karaoke highlighting. Validate mixed Khmer/English, emoji, wrapping, font fallback and timing edits without splitting a visual cluster. Reuse Text Engine measurement rather than approximate character counts.
