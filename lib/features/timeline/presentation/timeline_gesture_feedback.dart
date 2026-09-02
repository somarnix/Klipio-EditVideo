import 'dart:math' as math;
import '../application/snap_service.dart';
import '../application/timeline_editor.dart';
import '../domain/timeline_models.dart';

/// Screen-space magnetism only. Does not alter canonical adjacency tolerances.
abstract final class TimelineGestureSnap {
  static TimelineSnapResult resolve(
    TimelineModel model, {
    required Set<String> movingIds,
    required String anchorId,
    required double proposedStart,
    required double duration,
    required double pixelsPerSecond,
    required double playhead,
    List<double> markers = const [],
    bool enabled = true,
  }) {
    if (!enabled) {
      return TimelineSnapResult(
          time: math.max(0, proposedStart), guideTime: null);
    }
    final stationary = model.copyWith(tracks: [
      for (final track in model.tracks)
        track.copyWith(clips: [
          for (final clip in track.clips)
            if (!movingIds.contains(clip.id) &&
                !(clip.isLinkedAudio && movingIds.contains(clip.linkedClipId)))
              clip,
        ]),
    ]);
    return SnapService(thresholdSeconds: 8 / pixelsPerSecond).snap(stationary,
        movingClipId: anchorId,
        proposedStart: proposedStart,
        clipDuration: duration,
        playhead: playhead,
        markers: markers);
  }
}

class TimelineGestureFeedback {
  const TimelineGestureFeedback(
      {required this.time,
      required this.duration,
      this.guide,
      this.valid = true});
  final double time, duration;
  final double? guide;
  final bool valid;
}

String timelineEditTime(double seconds) {
  final ms = (seconds * 1000).round();
  return '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';
}

/// Major labels stay legible even when fitting multi-hour projects. Integer
/// indices (rather than accumulated fractional additions) keep ticks aligned.
abstract final class TimelineRulerScale {
  static double majorStep(double pixelsPerSecond) {
    final wanted = 64 / pixelsPerSecond;
    final power =
        math.pow(10, (math.log(wanted) / math.ln10).floor()).toDouble();
    for (final multiple in const [1, 2, 5, 10]) {
      if (multiple * power >= wanted) return multiple * power;
    }
    return 10 * power;
  }

  static String label(double seconds, double step) {
    final micros = (seconds * 1000000).round();
    final whole = micros ~/ 1000000;
    final base = '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}';
    if (step >= 1) return base;
    final fraction = (micros % 1000000)
        .toString()
        .padLeft(6, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '$base.${fraction.isEmpty ? '0' : fraction}';
  }
}
