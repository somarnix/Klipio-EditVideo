import 'dart:math' as math;

/// Contain the source, stretch independently, then pan across free/overflow
/// space. Rotation is applied around the resulting box's center.
abstract final class VideoGeometry {
  static ({double width, double height}) rotatedExtent(
      double width, double height, double degrees) {
    final radians = degrees * math.pi / 180;
    final c = math.cos(radians).abs();
    final s = math.sin(radians).abs();
    return (width: width * c + height * s, height: width * s + height * c);
  }

  /// Keep the unrotated pan pivot when a raster adapter expands its bounds.
  static String rotatedOffsetExpression(String canvas, String rotatedExtent,
          String originalExtent, String position) =>
      '${offsetExpression(canvas, originalExtent, position)}+($originalExtent-$rotatedExtent)/2';

  static double offset(double canvas, double extent, double position) =>
      (canvas - extent) / 2 +
      (2 * position.clamp(0.0, 1.0) - 1) * (canvas - extent).abs() / 2;

  static ({double left, double top, double width, double height}) resolve({
    required double canvasWidth,
    required double canvasHeight,
    required double sourceWidth,
    required double sourceHeight,
    required double scaleX,
    required double scaleY,
    required double positionX,
    required double positionY,
  }) {
    final contain =
        math.min(canvasWidth / sourceWidth, canvasHeight / sourceHeight);
    final width = sourceWidth * contain * scaleX.abs();
    final height = sourceHeight * contain * scaleY.abs();
    return (
      left: offset(canvasWidth, width, positionX),
      top: offset(canvasHeight, height, positionY),
      width: width,
      height: height
    );
  }

  /// FFmpeg equivalent of [offset] for normalized position expressions.
  static String offsetExpression(
          String canvas, String extent, String position) =>
      '($canvas-$extent)/2+(2*($position)-1)*abs($canvas-$extent)/2';
}
