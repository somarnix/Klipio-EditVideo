/// The editor's existing bounded snapshot history, independent of widgets.
class SnapshotHistory<T> {
  final List<T> undoEntries = [], redoEntries = [];
  String? lastKey;
  DateTime? lastAt;
  void record(String key, T Function() capture,
      {DateTime? now, bool coalesce = true}) {
    final time = now ?? DateTime.now();
    if (coalesce &&
        lastKey == key &&
        lastAt != null &&
        time.difference(lastAt!) < const Duration(milliseconds: 650)) {
      lastAt = time;
      return;
    }
    undoEntries.add(capture());
    if (undoEntries.length > 80) undoEntries.removeAt(0);
    redoEntries.clear();
    lastKey = key;
    lastAt = time;
  }

  T? undo(T Function() capture) {
    if (undoEntries.isEmpty) return null;
    redoEntries.add(capture());
    resetCoalescing();
    return undoEntries.removeLast();
  }

  T? redo(T Function() capture) {
    if (redoEntries.isEmpty) return null;
    undoEntries.add(capture());
    resetCoalescing();
    return redoEntries.removeLast();
  }

  void resetCoalescing() {
    lastKey = null;
    lastAt = null;
  }
}
