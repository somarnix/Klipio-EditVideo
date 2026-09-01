enum ResizeAxis { horizontal, vertical }

class ResizeHandleModel {
  const ResizeHandleModel({
    required this.axis,
    required this.minimum,
    required this.maximum,
  });

  final ResizeAxis axis;
  final double minimum;
  final double maximum;

  double clamp(double value) => value.clamp(minimum, maximum).toDouble();
}
