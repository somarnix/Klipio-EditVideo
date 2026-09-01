class MediaAsset {
  const MediaAsset({
    required this.path,
    required this.duration,
    this.width = 0,
    this.height = 0,
    this.frameRate = 0,
    this.videoCodec,
    this.audioCodec,
    this.waveform = const [],
  });

  final String path;
  final Duration duration;
  final int width;
  final int height;
  final double frameRate;
  final String? videoCodec;
  final String? audioCodec;
  final List<double> waveform;

  bool get hasVideo => videoCodec != null;
  bool get hasAudio => audioCodec != null;
  double? get aspectRatio => height == 0 ? null : width / height;
  String get name => path.replaceAll('\\', '/').split('/').last;

  MediaAsset copyWith({List<double>? waveform}) => MediaAsset(
        path: path,
        duration: duration,
        width: width,
        height: height,
        frameRate: frameRate,
        videoCodec: videoCodec,
        audioCodec: audioCodec,
        waveform: waveform ?? this.waveform,
      );
}
