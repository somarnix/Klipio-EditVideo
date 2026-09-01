import 'dart:async';

class AutosaveService {
  AutosaveService({this.interval = const Duration(seconds: 20)});

  final Duration interval;
  Timer? _timer;
  bool _saving = false;

  bool get isRunning => _timer?.isActive ?? false;

  void start(Future<void> Function() save) {
    stop();
    _timer = Timer.periodic(interval, (_) async {
      if (_saving) return;
      _saving = true;
      try {
        await save();
      } finally {
        _saving = false;
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();
}
