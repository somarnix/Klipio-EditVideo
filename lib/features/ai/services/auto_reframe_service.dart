class ReframeCrop {
  const ReframeCrop({
    required this.width,
    required this.height,
    required this.x,
    required this.y,
  });

  final int width;
  final int height;
  final int x;
  final int y;
}

class AutoReframeService {
  const AutoReframeService();

  ReframeCrop centeredCrop({
    required int sourceWidth,
    required int sourceHeight,
    required double targetAspectRatio,
  }) {
    final sourceRatio = sourceWidth / sourceHeight;
    if (sourceRatio > targetAspectRatio) {
      final width =
          (sourceHeight * targetAspectRatio).round().clamp(2, sourceWidth);
      return ReframeCrop(
        width: width.isEven ? width : width - 1,
        height: sourceHeight.isEven ? sourceHeight : sourceHeight - 1,
        x: ((sourceWidth - width) / 2).round(),
        y: 0,
      );
    }
    final height =
        (sourceWidth / targetAspectRatio).round().clamp(2, sourceHeight);
    return ReframeCrop(
      width: sourceWidth.isEven ? sourceWidth : sourceWidth - 1,
      height: height.isEven ? height : height - 1,
      x: 0,
      y: ((sourceHeight - height) / 2).round(),
    );
  }
}
