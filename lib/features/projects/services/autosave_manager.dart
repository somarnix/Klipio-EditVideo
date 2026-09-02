import 'dart:async';

/// Coalesces frequent editor mutations into one serial background save.
class AutosaveManager {
  AutosaveManager({
    required Future<void> Function() save,
    this.delay = const Duration(seconds: 2),
  }) : _save = save;

  final Future<void> Function() _save;
  final Duration delay;
  Timer? _timer;
  Future<void>? _activeSave;
  bool _dirty = false;
  bool _disposed = false;

  bool get hasPendingSave => _dirty || _timer?.isActive == true;
  bool get isSaving => _activeSave != null;

  void markDirty() {
    if (_disposed) return;
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(delay, flush);
  }

  Future<void> flush() async {
    if (_disposed || !_dirty) return;
    _timer?.cancel();
    _timer = null;
    final active = _activeSave;
    if (active != null) {
      await active;
      if (_dirty) await flush();
      return;
    }
    _dirty = false;
    final operation = _save();
    _activeSave = operation;
    try {
      await operation;
    } finally {
      _activeSave = null;
    }
    if (_dirty) await flush();
  }

  Future<void> dispose({bool savePending = true}) async {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    if (savePending) await flush();
    _disposed = true;
  }
}
