import 'dart:async';
import 'dart:collection';

typedef RenderTask<T> = Future<T> Function();

class RenderTaskQueue {
  final Queue<Future<void> Function()> _tasks = Queue();
  bool _running = false;
  bool _paused = false;

  bool get isRunning => _running;
  bool get isPaused => _paused;
  int get pendingCount => _tasks.length;

  Future<T> add<T>(RenderTask<T> task) {
    final completer = Completer<T>();
    _tasks.add(() async {
      try {
        completer.complete(await task());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    unawaited(_drain());
    return completer.future;
  }

  void pause() => _paused = true;

  void resume() {
    _paused = false;
    unawaited(_drain());
  }

  void clear() => _tasks.clear();

  Future<void> _drain() async {
    if (_running || _paused) return;
    _running = true;
    try {
      while (_tasks.isNotEmpty && !_paused) {
        await _tasks.removeFirst()();
      }
    } finally {
      _running = false;
    }
  }
}
