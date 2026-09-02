import 'timeline_models.dart';

/// Preflight the complete set of video instances affected by an edit, before
/// constructing any replacement tracks. Independent locked audio is not a
/// veto: ripple skips it. A locked companion is a veto because updating only
/// its video would break the ownership contract.
abstract final class LinkedAudioEditGuard {
  static bool blocks(TimelineModel timeline, Iterable<String> videoIds) {
    final ids = videoIds.toSet();
    final legacyIds = ids.map((id) => 'audio-$id').toSet();
    return timeline.audioTracks.any((track) =>
        track.isLocked &&
        track.clips.any((clip) =>
            (clip.isLinkedAudio && ids.contains(clip.linkedClipId)) ||
            legacyIds.contains(clip.id)));
  }
}
