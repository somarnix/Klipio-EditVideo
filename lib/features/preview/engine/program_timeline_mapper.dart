import '../../timeline/domain/timeline_models.dart';

/// A resolved position in the final edited program.
///
/// [timelineSeconds] always uses the final [TimelineModel] clock, while
/// [sourceSeconds] uses the clock inside [clip]'s original media file.
class ProgramTimelineTarget {
  const ProgramTimelineTarget({
    required this.timelineSeconds,
    required this.clip,
    required this.sourceSeconds,
    required this.isGap,
  });

  final double timelineSeconds;
  final ClipModel? clip;
  final double? sourceSeconds;
  final bool isGap;
}

/// Converts between the final program clock and original media clocks.
///
/// Hook/Best Moments may create the [ClipModel] ranges, but this mapper never
/// reads legacy deleted ranges. Once clips exist, [TimelineModel] is the only
/// edit decision list used by Program Monitor playback.
abstract final class ProgramTimelineMapper {
  static bool hasPlayableVideo(TimelineModel model) => model.videoTracks.any(
        (track) => !track.isMuted && track.clips.any((clip) => !clip.isMuted),
      );

  static double duration(TimelineModel model) {
    final calculated = TimelineModel.calculateDuration(model.tracks);
    return calculated > model.duration ? calculated : model.duration;
  }

  static ProgramTimelineTarget resolve(
    TimelineModel model,
    double timelineSeconds, {
    Map<String, double> playbackSpeedsByMediaPath = const {},
  }) {
    final programDuration = duration(model);
    final playhead = timelineSeconds
        .clamp(0.0, programDuration > 0 ? programDuration : double.infinity)
        .toDouble();
    final active = _activeProgramClip(model, playhead);
    if (active == null) {
      return ProgramTimelineTarget(
        timelineSeconds: playhead,
        clip: null,
        sourceSeconds: null,
        isGap: true,
      );
    }
    final localTimelineSeconds =
        (playhead - active.timelineStart).clamp(0.0, active.duration);
    final playbackSpeed = _safePlaybackSpeed(
      playbackSpeedsByMediaPath[active.mediaPath] ?? 1,
    );
    return ProgramTimelineTarget(
      timelineSeconds: playhead,
      clip: active,
      sourceSeconds: (active.sourceStart +
              localTimelineSeconds * playbackSpeed)
          .clamp(active.sourceStart, active.sourceEnd)
          .toDouble(),
      isGap: false,
    );
  }

  static double timelineSecondsForSource({
    required ClipModel clip,
    required double sourceSeconds,
    double playbackSpeed = 1,
  }) {
    final speed = _safePlaybackSpeed(playbackSpeed);
    return (clip.timelineStart + (sourceSeconds - clip.sourceStart) / speed)
        .clamp(clip.timelineStart, clip.timelineEnd)
        .toDouble();
  }

  static double _safePlaybackSpeed(double value) {
    if (!value.isFinite) return 1;
    return value.clamp(0.25, 4).toDouble();
  }

  static ClipModel? nextPlayableVideoClip(
    TimelineModel model, {
    required double atOrAfterTimelineSeconds,
    String? excludingClipId,
  }) {
    final clips = _playableVideoClips(model)
        .where((clip) => clip.id != excludingClipId)
        .where(
          (clip) => clip.timelineStart >= atOrAfterTimelineSeconds - 0.03,
        )
        .toList()
      ..sort(_programOrder);
    return clips.isEmpty ? null : clips.first;
  }

  static ClipModel? _activeProgramClip(
    TimelineModel model,
    double playhead,
  ) {
    // V1 is the base program picture. Prefer it whenever it is present, then
    // fall back to the highest visible overlay for overlay-only timelines.
    for (final track in model.videoTracks) {
      if (track.isMuted) continue;
      final active = track.clips
          .where(
            (clip) =>
                !clip.isMuted &&
                playhead >= clip.timelineStart - 0.001 &&
                playhead < clip.timelineEnd - 0.001,
          )
          .toList()
        ..sort((a, b) {
          final start = b.timelineStart.compareTo(a.timelineStart);
          return start != 0 ? start : b.zIndex.compareTo(a.zIndex);
        });
      if (active.isNotEmpty) return active.first;
    }
    return null;
  }

  static List<ClipModel> _playableVideoClips(TimelineModel model) => [
        for (final track in model.videoTracks)
          if (!track.isMuted)
            for (final clip in track.clips)
              if (!clip.isMuted) clip,
      ];

  static int _programOrder(ClipModel a, ClipModel b) {
    final start = a.timelineStart.compareTo(b.timelineStart);
    if (start != 0) return start;
    final zIndex = a.zIndex.compareTo(b.zIndex);
    return zIndex != 0 ? zIndex : a.id.compareTo(b.id);
  }
}
