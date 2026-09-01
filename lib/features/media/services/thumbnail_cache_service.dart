import '../../../services/platform/platform_support.dart' as platform;

class ThumbnailCacheService {
  const ThumbnailCacheService();

  Future<String?> cover(String mediaPath, String cacheFolder) =>
      platform.thumbnailForVideo(mediaPath, cacheFolder);

  Future<List<String>> filmstrip(
    String mediaPath,
    String cacheFolder,
    double durationSeconds,
  ) =>
      platform.timelineThumbnailsForVideo(
        mediaPath,
        cacheFolder,
        durationSeconds,
      );
}
