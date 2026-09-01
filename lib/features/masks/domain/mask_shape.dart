enum MaskShapeType { linear, mirror, radial, rectangle, star }

class MaskShape {
  const MaskShape({
    required this.type,
    this.centerX = 0.5,
    this.centerY = 0.5,
    this.width = 0.5,
    this.height = 0.5,
    this.rotation = 0,
    this.feather = 0,
    this.inverted = false,
  });

  final MaskShapeType type;
  final double centerX;
  final double centerY;
  final double width;
  final double height;
  final double rotation;
  final double feather;
  final bool inverted;
}
