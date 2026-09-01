import 'package:flutter/foundation.dart';

/// Multi-selection state shared by clip widgets, toolbar commands and inspector.
class TimelineSelectionController extends ChangeNotifier {
  final Set<String> _clipIds = <String>{};
  String? _anchorClipId;

  Set<String> get clipIds => Set.unmodifiable(_clipIds);
  String? get primaryClipId => _anchorClipId;
  bool get hasSelection => _clipIds.isNotEmpty;
  bool isSelected(String id) => _clipIds.contains(id);

  void selectOnly(String id) {
    if (_clipIds.length == 1 && _clipIds.contains(id)) return;
    _clipIds
      ..clear()
      ..add(id);
    _anchorClipId = id;
    notifyListeners();
  }

  void toggle(String id) {
    if (!_clipIds.remove(id)) {
      _clipIds.add(id);
      _anchorClipId = id;
    } else if (_anchorClipId == id) {
      _anchorClipId = _clipIds.isEmpty ? null : _clipIds.last;
    }
    notifyListeners();
  }

  void replace(Iterable<String> ids, {String? primary}) {
    final next = ids.toSet();
    if (setEquals(next, _clipIds) && primary == _anchorClipId) return;
    _clipIds
      ..clear()
      ..addAll(next);
    _anchorClipId = primary ?? (next.isEmpty ? null : next.last);
    notifyListeners();
  }

  void addRange(Iterable<String> ids) {
    final oldLength = _clipIds.length;
    _clipIds.addAll(ids);
    if (_clipIds.length != oldLength) notifyListeners();
  }

  void clear() {
    if (_clipIds.isEmpty) return;
    _clipIds.clear();
    _anchorClipId = null;
    notifyListeners();
  }
}
