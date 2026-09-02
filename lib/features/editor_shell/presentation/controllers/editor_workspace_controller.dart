import 'package:flutter/foundation.dart';

enum EditorWorkspaceSection { media, text, audio, captions, effects }

class EditorWorkspaceController extends ChangeNotifier {
  EditorWorkspaceController({
    this.minimumLeftWidth = 220,
    this.minimumInspectorWidth = 260,
    this.minimumTimelineHeight = 180,
  });

  final double minimumLeftWidth;
  final double minimumInspectorWidth;
  final double minimumTimelineHeight;

  EditorWorkspaceSection _section = EditorWorkspaceSection.media;
  double _leftWidth = 300;
  double _inspectorWidth = 340;
  double _timelineHeight = 300;
  String _projectName = 'Untitled project';
  String _status = 'Ready';
  bool _busy = false;

  EditorWorkspaceSection get section => _section;
  double get leftWidth => _leftWidth;
  double get inspectorWidth => _inspectorWidth;
  double get timelineHeight => _timelineHeight;
  String get projectName => _projectName;
  String get status => _status;
  bool get busy => _busy;

  void selectSection(EditorWorkspaceSection value) {
    if (_section == value) return;
    _section = value;
    notifyListeners();
  }

  void resizeLeft(double value, double availableWidth) {
    final maximum = (availableWidth * 0.45).clamp(minimumLeftWidth, 720);
    final next = value.clamp(minimumLeftWidth, maximum).toDouble();
    if (next == _leftWidth) return;
    _leftWidth = next;
    notifyListeners();
  }

  void resizeInspector(double value, double availableWidth) {
    final maximum = (availableWidth * 0.45).clamp(minimumInspectorWidth, 720);
    final next = value.clamp(minimumInspectorWidth, maximum).toDouble();
    if (next == _inspectorWidth) return;
    _inspectorWidth = next;
    notifyListeners();
  }

  void resizeTimeline(double value, double availableHeight) {
    final maximum = (availableHeight * 0.7).clamp(minimumTimelineHeight, 720);
    final next = value.clamp(minimumTimelineHeight, maximum).toDouble();
    if (next == _timelineHeight) return;
    _timelineHeight = next;
    notifyListeners();
  }

  void renameProject(String value) {
    final next = value.trim().isEmpty ? 'Untitled project' : value.trim();
    if (next == _projectName) return;
    _projectName = next;
    notifyListeners();
  }

  void reportStatus(String value, {bool? busy}) {
    _status = value.trim().isEmpty ? 'Ready' : value.trim();
    _busy = busy ?? _busy;
    notifyListeners();
  }
}
