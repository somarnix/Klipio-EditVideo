import 'dart:math' as math;

/// Single presentation mapping between program seconds and timeline pixels.
/// Domain timing remains owned by TimelineModel; this class only describes the
/// visible viewport and is shared by ruler, clips, overlays and media loaders.
class TimelineViewport {
  const TimelineViewport({
    required this.pixelsPerSecond,
    required this.visibleProgramStart,
    required this.viewportWidth,
    required this.projectDuration,
    this.minimumZoom = 4,
    this.maximumZoom = 480,
  });

  final double pixelsPerSecond;
  final double visibleProgramStart;
  final double viewportWidth;
  final double projectDuration;
  final double minimumZoom;
  final double maximumZoom;

  double get horizontalScrollOffset => visibleProgramStart * pixelsPerSecond;
  double get visibleProgramEnd => math.min(
      projectDuration, visibleProgramStart + viewportWidth / pixelsPerSecond);
  double programTimeToX(double seconds) =>
      (seconds - visibleProgramStart) * pixelsPerSecond;
  double xToProgramTime(double x) =>
      (visibleProgramStart + x / pixelsPerSecond).clamp(0.0, projectDuration);

  TimelineViewport zoomAround(
      {required double factor, required double pointerX}) {
    final next =
        (pixelsPerSecond * factor).clamp(minimumZoom, maximumZoom).toDouble();
    final anchor = xToProgramTime(pointerX);
    final nextStart = (anchor - pointerX / next)
        .clamp(0.0, math.max(0.0, projectDuration - viewportWidth / next))
        .toDouble();
    return TimelineViewport(
      pixelsPerSecond: next,
      visibleProgramStart: nextStart,
      viewportWidth: viewportWidth,
      projectDuration: projectDuration,
      minimumZoom: minimumZoom,
      maximumZoom: maximumZoom,
    );
  }
}
