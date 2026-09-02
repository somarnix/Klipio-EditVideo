import 'package:flutter/foundation.dart';

import '../../editor/domain/video_render_settings.dart';
import '../../timeline/domain/timeline_models.dart';

class InspectorController extends ChangeNotifier {
  VideoRenderSettings? _settings;

  VideoRenderSettings? get settings => _settings;
  bool get hasSelection => _settings != null;

  void load(VideoRenderSettings? value) {
    _settings = value;
    notifyListeners();
  }

  void updateTransform(ClipTransform transform) {
    final current = _settings;
    if (current == null) return;
    _settings = current.copyWith(transform: transform);
    notifyListeners();
  }

  void updateSpeed(double speed) {
    final current = _settings;
    if (current == null) return;
    _settings = current.copyWith(speed: speed.clamp(0.25, 4).toDouble());
    notifyListeners();
  }

  void updateSourceVolume(double volume) {
    final current = _settings;
    if (current == null) return;
    _settings = current.copyWith(
      originalVolume: volume.clamp(0, 1).toDouble(),
    );
    notifyListeners();
  }
}
