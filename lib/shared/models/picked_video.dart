import 'dart:io';

/// Stable shared media selection boundary used by import and editor features.
class PickedVideoAsset {
  const PickedVideoAsset({
    required this.path,
    this.duration = Duration.zero,
    this.width,
    this.height,
    this.hasAudio = false,
  });

  final String path;
  final Duration duration;
  final int? width;
  final int? height;
  final bool hasAudio;

  String get name => path.replaceAll('\\', '/').split('/').last;
  bool get exists => File(path).existsSync();
  double? get aspectRatio =>
      width == null || height == null || height == 0 ? null : width! / height!;

  PickedVideoAsset copyWith({
    Duration? duration,
    int? width,
    int? height,
    bool? hasAudio,
  }) =>
      PickedVideoAsset(
        path: path,
        duration: duration ?? this.duration,
        width: width ?? this.width,
        height: height ?? this.height,
        hasAudio: hasAudio ?? this.hasAudio,
      );
}
