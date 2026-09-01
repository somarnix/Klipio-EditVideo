import '../../../services/platform/platform_support.dart' as platform;

class WaveformService {
  const WaveformService();

  Future<List<double>> generate({
    required String mediaPath,
    required String cacheFolder,
  }) =>
      platform.audioWaveformPeaks(mediaPath, cacheFolder);

  List<double> slice(
    List<double> source, {
    required double sourceDuration,
    required double sourceStart,
    required double clipDuration,
  }) {
    if (source.isEmpty || sourceDuration <= 0 || clipDuration <= 0) {
      return const [];
    }
    final start = ((sourceStart / sourceDuration) * source.length)
        .floor()
        .clamp(0, source.length);
    final end =
        (((sourceStart + clipDuration) / sourceDuration) * source.length)
            .ceil()
            .clamp(start, source.length);
    return source.sublist(start, end);
  }
}
