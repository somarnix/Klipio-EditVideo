import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../timeline/domain/timeline_models.dart';

class TransformGizmoController extends ChangeNotifier {
  TransformGizmoController({ClipTransform transform = const ClipTransform()})
      : _transform = transform;

  ClipTransform _transform;
  bool _snapX = false;
  bool _snapY = false;

  ClipTransform get transform => _transform;
  bool get snapX => _snapX;
  bool get snapY => _snapY;

  void load(ClipTransform value) {
    _transform = value;
    _snapX = false;
    _snapY = false;
    notifyListeners();
  }

  void translate({
    required Offset delta,
    required Size compositionSize,
    double snapThreshold = 5,
  }) {
    if (compositionSize.isEmpty) return;
    var x = _transform.positionX + delta.dx / compositionSize.width;
    var y = _transform.positionY + delta.dy / compositionSize.height;
    _snapX = ((x - 0.5) * compositionSize.width).abs() <= snapThreshold;
    _snapY = ((y - 0.5) * compositionSize.height).abs() <= snapThreshold;
    if (_snapX) x = 0.5;
    if (_snapY) y = 0.5;
    _transform = _transform.copyWith(
      positionX: x.clamp(0, 1).toDouble(),
      positionY: y.clamp(0, 1).toDouble(),
    );
    notifyListeners();
  }

  void scale({required double xFactor, required double yFactor}) {
    _transform = _transform.copyWith(
      scaleX: (_transform.scaleX * math.max(0.01, xFactor))
          .clamp(0.05, 20)
          .toDouble(),
      scaleY: (_transform.scaleY * math.max(0.01, yFactor))
          .clamp(0.05, 20)
          .toDouble(),
    );
    notifyListeners();
  }

  void rotateBy(double degrees) {
    _transform = _transform.copyWith(
      rotationDegrees: (_transform.rotationDegrees + degrees).remainder(360),
    );
    notifyListeners();
  }

  void clearGuides() {
    if (!_snapX && !_snapY) return;
    _snapX = false;
    _snapY = false;
    notifyListeners();
  }
}
