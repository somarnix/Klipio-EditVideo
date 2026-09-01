import 'package:flutter/foundation.dart';

class ProgramMonitorController extends ChangeNotifier {
  double _playhead = 0;
  double _duration = 0;
  bool _playing = false;
  double _volume = 1;

  double get playhead => _playhead;
  double get duration => _duration;
  bool get playing => _playing;
  double get volume => _volume;

  void configureDuration(double seconds) {
    _duration = seconds < 0 ? 0 : seconds;
    _playhead = _playhead.clamp(0, _duration).toDouble();
    notifyListeners();
  }

  void seek(double seconds) {
    _playhead = seconds.clamp(0, _duration).toDouble();
    notifyListeners();
  }

  void setPlaying(bool value) {
    if (_playing == value) return;
    _playing = value;
    notifyListeners();
  }

  void setVolume(double value) {
    _volume = value.clamp(0, 1).toDouble();
    notifyListeners();
  }
}
