import 'package:flutter/foundation.dart';
import 'timeline_viewport.dart';

class TimelineZoomController extends ChangeNotifier {
  TimelineZoomController({
    double pixelsPerSecond = 36,
    this.minimum = 4,
    this.maximum = 480,
  }) : _pixelsPerSecond = pixelsPerSecond.clamp(minimum, maximum).toDouble();

  final double minimum;
  final double maximum;
  double _pixelsPerSecond;

  double get pixelsPerSecond => _pixelsPerSecond;

  void setPixelsPerSecond(double value) {
    final next = value.clamp(minimum, maximum).toDouble();
    if (next == _pixelsPerSecond) return;
    _pixelsPerSecond = next;
    notifyListeners();
  }

  void zoomBy(double factor) {
    if (factor <= 0) return;
    setPixelsPerSecond(_pixelsPerSecond * factor);
  }

  void fit({required double duration, required double viewportWidth}) {
    if (duration <= 0 || viewportWidth <= 0) return;
    setPixelsPerSecond(viewportWidth / duration);
  }

  TimelineViewport viewport({
    required double projectDuration,
    required double visibleProgramStart,
    required double viewportWidth,
  }) =>
      TimelineViewport(
        pixelsPerSecond: _pixelsPerSecond,
        visibleProgramStart: visibleProgramStart,
        viewportWidth: viewportWidth,
        projectDuration: projectDuration,
        minimumZoom: minimum,
        maximumZoom: maximum,
      );
}
