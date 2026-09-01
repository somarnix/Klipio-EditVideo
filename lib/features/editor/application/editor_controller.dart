import 'package:flutter/foundation.dart';

import '../../timeline/application/timeline_controller.dart';
import '../domain/editor_selection.dart';
import 'editor_commands.dart';

class EditorController extends ChangeNotifier {
  EditorController({TimelineController? timeline})
      : timeline = timeline ?? TimelineController();

  final TimelineController timeline;
  final EditorCommandHistory history = EditorCommandHistory();
  EditorSelection _selection = const EditorSelection.none();

  EditorSelection get selection => _selection;

  void select(EditorSelection value) {
    if (value.kind == _selection.kind && value.id == _selection.id) return;
    _selection = value;
    notifyListeners();
  }

  void execute(EditorCommand command) {
    timeline.timeline = history.execute(timeline.timeline, command);
    notifyListeners();
  }

  void undo() {
    timeline.timeline = history.undo(timeline.timeline);
    notifyListeners();
  }

  void redo() {
    timeline.timeline = history.redo(timeline.timeline);
    notifyListeners();
  }

  @override
  void dispose() {
    timeline.dispose();
    super.dispose();
  }
}
