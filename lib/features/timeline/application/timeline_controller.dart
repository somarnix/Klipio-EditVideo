import 'package:flutter/foundation.dart';

import '../domain/timeline_models.dart';
import 'timeline_editor.dart';
import 'timeline_selection_controller.dart';

/// Observable timeline state boundary for the staged editor extraction.
class TimelineController extends ChangeNotifier {
  TimelineController({
    TimelineModel? timeline,
    TimelineEditor? editor,
    TimelineSelectionController? selection,
  })  : _timeline = timeline ?? TimelineModel.empty(),
        editor = editor ?? const TimelineEditor(),
        selection = selection ?? TimelineSelectionController();

  TimelineModel _timeline;
  double _playhead = 0;
  double _zoom = 1;

  final TimelineEditor editor;
  final TimelineSelectionController selection;

  TimelineModel get timeline => _timeline;
  double get playhead => _playhead;
  double get zoom => _zoom;

  set timeline(TimelineModel value) {
    _timeline = value;
    _playhead = _playhead.clamp(0, value.duration).toDouble();
    notifyListeners();
  }

  void seek(double seconds) {
    final next = seconds.clamp(0, _timeline.duration).toDouble();
    if (next == _playhead) return;
    _playhead = next;
    notifyListeners();
  }

  void setZoom(double value) {
    final next = value.clamp(0.05, 20).toDouble();
    if (next == _zoom) return;
    _zoom = next;
    notifyListeners();
  }

  void addTrack(TrackType type) => timeline = editor.addTrack(_timeline, type);

  void splitSelected() {
    var next = _timeline;
    for (final clipId in selection.clipIds) {
      next = editor.splitClip(next, clipId: clipId, playhead: _playhead);
    }
    timeline = next;
  }

  void deleteSelected() {
    var next = _timeline;
    for (final clipId in selection.clipIds) {
      next = editor.deleteClip(next, clipId);
    }
    selection.clear();
    timeline = next;
  }

  @override
  void dispose() {
    selection.dispose();
    super.dispose();
  }
}
