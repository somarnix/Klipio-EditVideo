import '../../timeline/domain/timeline_models.dart';

abstract interface class EditorCommand {
  String get label;
  TimelineModel apply(TimelineModel timeline);
}

class TimelineMutationCommand implements EditorCommand {
  const TimelineMutationCommand({required this.label, required this.mutation});

  @override
  final String label;
  final TimelineModel Function(TimelineModel timeline) mutation;

  @override
  TimelineModel apply(TimelineModel timeline) => mutation(timeline);
}

class EditorCommandHistory {
  final List<TimelineModel> _undo = [];
  final List<TimelineModel> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  TimelineModel execute(TimelineModel current, EditorCommand command) {
    final next = command.apply(current);
    if (identical(next, current)) return current;
    _undo.add(current);
    _redo.clear();
    return next;
  }

  TimelineModel undo(TimelineModel current) {
    if (_undo.isEmpty) return current;
    _redo.add(current);
    return _undo.removeLast();
  }

  TimelineModel redo(TimelineModel current) {
    if (_redo.isEmpty) return current;
    _undo.add(current);
    return _redo.removeLast();
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }
}
