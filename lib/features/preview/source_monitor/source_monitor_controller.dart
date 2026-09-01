import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../engine/preview_controller.dart';

class SourceMonitorController extends ChangeNotifier {
  SourceMonitorController();

  VideoPlayerController? _player;
  String? _mediaPath;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1;

  String? get mediaPath => _mediaPath;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  VideoPlayerController? get player => _player;
  bool get playing => _player?.value.isPlaying ?? false;

  Future<void> open(String mediaPath) async {
    final previous = _player;
    _mediaPath = mediaPath;
    _player = await createPreviewController(mediaPath);
    await previous?.dispose();
    _duration = _player!.value.duration;
    _position = _player!.value.position;
    notifyListeners();
  }

  Future<void> play() async {
    await _player?.play();
    notifyListeners();
  }

  Future<void> pause() async {
    await _player?.pause();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _player?.seekTo(position);
    _position = position;
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0, 1).toDouble();
    await _player?.setVolume(_volume);
    notifyListeners();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }
}
