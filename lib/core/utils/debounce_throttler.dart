import 'dart:async';

class DebounceThrottler {
  DebounceThrottler({this.interval = const Duration(milliseconds: 16)});

  final Duration interval;
  Timer? _timer;
  void Function()? _pending;
  bool _running = false;

  void schedule(void Function() action) {
    _pending = action;
    if (_running) return;
    _running = true;
    _timer = Timer(interval, _flush);
  }

  void _flush() {
    final action = _pending;
    _pending = null;
    action?.call();
    if (_pending != null) {
      _timer = Timer(interval, _flush);
    } else {
      _timer = null;
      _running = false;
    }
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _running = false;
  }

  void dispose() => cancel();
}
