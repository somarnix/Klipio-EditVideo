import 'timeline_models.dart';

/// Atomic instance edit. A locked linked track rejects the transaction.
abstract final class ClipSpeedEdit {
  /// One-way migration. Once present, the clip field wins over every legacy
  /// asset default. Linked source audio inherits its exact owner's speed.
  static TimelineModel migrate(
          TimelineModel timeline, Map<String, double> legacy) =>
      timeline.copyWith(duration: timeline.duration, tracks: [
        for (final track in timeline.tracks)
          track.copyWith(clips: [
            for (final clip in track.clips)
              clip.copyWith(
                  playbackSpeed: (clip.isLinkedAudio &&
                                  clip.linkedClipId != null
                              ? timeline.clipById(clip.linkedClipId!)?.clip
                              : null)
                          ?.resolvedPlaybackSpeed(
                              legacy[clip.mediaPath] ?? 1) ??
                      clip.resolvedPlaybackSpeed(
                          track.type == TrackType.audio && !clip.isLinkedAudio
                              ? 1
                              : legacy[clip.mediaPath] ?? 1)),
          ]),
      ]);

  static TimelineModel apply(
      TimelineModel timeline, Set<String> ids, double speed) {
    final targets = <String>{
      for (final id in ids)
        if (timeline.clipById(id)?.track.type == TrackType.video) id
    };
    bool affected(ClipModel clip) =>
        targets.contains(clip.id) ||
        (clip.isLinkedAudio && targets.contains(clip.linkedClipId));
    if (targets.isEmpty ||
        timeline.tracks
            .any((track) => track.isLocked && track.clips.any(affected))) {
      return timeline;
    }
    final safe = (speed.isFinite ? speed : 1.0).clamp(0.25, 4).toDouble();
    return timeline.copyWith(duration: timeline.duration, tracks: [
      for (final track in timeline.tracks)
        track.copyWith(clips: [
          for (final clip in track.clips)
            affected(clip) ? clip.copyWith(playbackSpeed: safe) : clip,
        ]),
    ]);
  }
}
