# Source implementation report — 2026-09-07

Scope: first bounded implementation slice from the knowledge library, in the
working tree based on `f27fef8`. These changes are not committed or released.
This report does not supersede the remaining proposed roadmap or claim that
the entire book has been implemented.

## Changes made

### Captured render state owns its collections

`lib/features/composition/domain/program_render_snapshot.dart` previously kept
the caller's source timeline directly. Final model fields did not protect mutable
track, clip, effect, or keyframe lists. Mutating a caller-owned list could change
the source state used by a running snapshot.

The snapshot now copies and makes these collections unmodifiable for both the
source timeline and retimed output timeline. Source duration is preserved.
Immutable value objects remain shared; no project format migration is needed.
This adds allocation at snapshot creation, not a claim of improved frame rate.

### Linked audio respects clip identity

The previous fallback selected the first linked audio with the same file path,
even if that audio explicitly belonged to another video clip. Repeated uses or
splits of a source could therefore inherit the wrong mute or volume.

Exact clip links still take priority. Legacy fallback now requires an absent
link, matching media, source start, timeline start and duration, and exactly one
candidate. Ambiguous legacy data uses the existing no-link default volume of 1
rather than arbitrarily borrowing another clip's settings. Older projects whose
unlinked ranges differ require explicit relinking; this fallback does not guess.

## Verification

New file: `test/program_render_snapshot_isolation_test.dart`.

- Regression coverage for explicit links to another same-file clip.
- Coverage for unique, mismatched and ambiguous legacy audio.
- Coverage for caller mutation and unmodifiable captured collections.
- Focused workflow plus new tests: 8 passed.
- Full `flutter test`: 86 passed.
- `flutter analyze`: no issues.
- After explicitly preserving captured duration, the 3 new tests passed again.
- `git diff --check`: passed; Git reported normal LF/CRLF conversion warnings.

These are automated source-level checks, not a real-device long-video stress
test or proof of pixel-identical preview/export for every effect and caption.

## Still pending

- Playback advances near some clip endpoints using early time margins. Inspect
  native completion and exact boundary behavior together before changing them.
- Speed remains keyed by media path in this snapshot, not independent clip ID.
- Active editor autosave needs a separate lifecycle/recovery audit; changing the
  standalone AutosaveManager alone would not repair the active save path.
- Seven-video thumbnail behavior, long-media cancellation, and render parity
  need focused integration/manual evidence on the target machine.
- The broader command/state ownership and product-experience roadmap remains
  incremental work, not completed by these two corrections.

No production code was deleted merely because it was large. No installer or
application EXE was built, installed, deleted, or replaced. No source media,
project data or release artifacts were removed.
