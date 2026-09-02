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
  /// A stopped monitor at the exclusive endpoint holds the last project-grid
  /// frame. Transport time, clip membership and export duration stay unchanged.
  static double monitorFrameTime(TimelineModel model, double seconds,
      {required double frameRate}) {
    final end = duration(model);
    final time = seconds.clamp(0.0, end).toDouble();
    if (time < end || end <= 0 || !frameRate.isFinite || frameRate <= 0) {
      return time;
    }
    return ((end * frameRate).ceil() - 1) / frameRate;
  }

  static ProgramTimelineTarget resolveMonitor(
      TimelineModel model, double seconds,
      {required double frameRate,
      Map<String, double> playbackSpeedsByMediaPath = const {}}) {
    final resolved = resolve(
        model, monitorFrameTime(model, seconds, frameRate: frameRate),
        playbackSpeedsByMediaPath: playbackSpeedsByMediaPath);
    return ProgramTimelineTarget(
        timelineSeconds: seconds.clamp(0.0, duration(model)).toDouble(),
        clip: resolved.clip,
        sourceSeconds: resolved.sourceSeconds,
        isGap: resolved.isGap);
  }

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
    final playbackSpeed = _safePlaybackSpeed(
      active.resolvedPlaybackSpeed(
          playbackSpeedsByMediaPath[active.mediaPath] ?? 1),
    );
    return ProgramTimelineTarget(
      timelineSeconds: playhead,
      clip: active,
      sourceSeconds: active.sourceTimeAtProgramTime(playhead, playbackSpeed),
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
    bool includeOverlapping = false,
  }) {
    final clips = _playableVideoClips(model)
        .where((clip) => clip.id != excludingClipId)
        .where(
          (clip) =>
              clip.timelineStart >= atOrAfterTimelineSeconds ||
              (includeOverlapping &&
                  clip.timelineEnd > atOrAfterTimelineSeconds),
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
                playhead >= clip.timelineStart &&
                playhead < clip.timelineEnd,
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
