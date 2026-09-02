/// Text dimensions are logical pixels on a 1080-high project canvas, not
/// desktop/device pixels. Existing saved numeric sizes retain their value.
abstract final class TextGeometry {
  static const referenceHeight = 1080.0;
  static double scale(double canvasHeight) => canvasHeight / referenceHeight;
  static double fontSize(double size, double canvasHeight) =>
      size.clamp(5.0, 500.0) * scale(canvasHeight);
}
