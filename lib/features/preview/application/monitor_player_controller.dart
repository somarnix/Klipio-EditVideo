import 'dart:async';

import 'package:flutter/foundation.dart';

typedef MonitorSeek = Future<void> Function(Duration position);
typedef MonitorCommand = Future<void> Function();

class MonitorPlayerController extends ChangeNotifier {
  MonitorPlayerController({
    required this.seekHandler,
    required this.playHandler,
    required this.pauseHandler,
    this.frameRate = 30,
  });

  final MonitorSeek seekHandler;
  final MonitorCommand playHandler;
  final MonitorCommand pauseHandler;
  final double frameRate;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _looping = false;
  double _volume = 1;

  Duration get position => _position;
  Duration get duration => _duration;
  bool get playing => _playing;
  bool get looping => _looping;
  double get volume => _volume;

  void synchronize({required Duration position, required Duration duration}) {
    _duration = duration.isNegative ? Duration.zero : duration;
    _position = _clamp(position);
    notifyListeners();
  }

  Future<void> seek(Duration value) async {
    _position = _clamp(value);
    notifyListeners();
    await seekHandler(_position);
  }

  Future<void> togglePlaying() async {
    if (_playing) {
      await pauseHandler();
    } else {
      await playHandler();
    }
    _playing = !_playing;
    notifyListeners();
  }

  Future<void> step(int frameDelta) {
    final safeRate = frameRate <= 0 ? 30 : frameRate;
    return seek(
      _position +
          Duration(
            microseconds:
                (frameDelta / safeRate * Duration.microsecondsPerSecond)
                    .round(),
          ),
    );
  }

  void setLooping(bool value) {
    if (_looping == value) return;
    _looping = value;
    notifyListeners();
  }

  void setVolume(double value) {
    final next = value.clamp(0, 1).toDouble();
    if (next == _volume) return;
    _volume = next;
    notifyListeners();
  }

  Duration _clamp(Duration value) {
    if (value.isNegative) return Duration.zero;
    if (_duration > Duration.zero && value > _duration) return _duration;
    return value;
  }
}
