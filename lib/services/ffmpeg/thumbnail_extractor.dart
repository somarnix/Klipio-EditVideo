import '../platform/platform_support.dart' as platform;

/// Feature-neutral facade over the bounded thumbnail worker implementation.
class ThumbnailExtractor {
  const ThumbnailExtractor();

  Future<String?> extractPoster({
    required String inputPath,
    required String cacheDirectory,
  }) =>
      platform.thumbnailForVideo(inputPath, cacheDirectory);

  Future<List<String>> extractTimeline({
    required String inputPath,
    required String cacheDirectory,
    required double durationSeconds,
    double? visibleSourceStart,
    double? visibleSourceEnd,
  }) =>
      platform.timelineThumbnailsForVideo(
        inputPath,
        cacheDirectory,
        durationSeconds,
        visibleSourceStart: visibleSourceStart,
        visibleSourceEnd: visibleSourceEnd,
      );
}
