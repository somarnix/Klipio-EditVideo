import '../domain/timeline_models.dart';
import 'timeline_editor.dart';

/// Applies validated horizontal and cross-track clip moves.
class DragDropService {
  const DragDropService({this.editor = const TimelineEditor()});

  final TimelineEditor editor;

  TimelineModel move(
    TimelineModel timeline, {
    required String clipId,
    required String targetTrackId,
    required double timelineStart,
    double? playhead,
    List<double> markers = const [],
  }) =>
      editor.moveClip(
        timeline,
        clipId: clipId,
        targetTrackId: targetTrackId,
        timelineStart: timelineStart,
        playhead: playhead,
        markers: markers,
      );
}
