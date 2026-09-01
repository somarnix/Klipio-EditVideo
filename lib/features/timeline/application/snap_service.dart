import '../domain/timeline_models.dart';
import 'timeline_editor.dart';

/// Dedicated magnetic-snap boundary used by timeline gestures.
class SnapService {
  const SnapService({this.thresholdSeconds = 0.12});

  final double thresholdSeconds;

  TimelineSnapResult snap(
    TimelineModel timeline, {
    required String movingClipId,
    required double proposedStart,
    required double clipDuration,
    double? playhead,
    List<double> markers = const [],
  }) =>
      TimelineEditor(snapThreshold: thresholdSeconds).snapTime(
        timeline,
        movingClipId: movingClipId,
        proposedStart: proposedStart,
        clipDuration: clipDuration,
        playhead: playhead,
        markers: markers,
      );
}
