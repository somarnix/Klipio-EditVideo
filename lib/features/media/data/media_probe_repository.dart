import '../../../services/platform/platform_support.dart' as platform;
import '../domain/media_asset.dart';

class MediaProbeRepository {
  const MediaProbeRepository();

  Future<MediaAsset> probe(String path) async {
    final values = await Future.wait<Object?>([
      platform.videoDurationSeconds(path),
      platform.videoHasAudio(path),
    ]);
    final seconds = values[0] as double? ?? 0;
    return MediaAsset(
      path: path,
      duration: Duration(microseconds: (seconds * 1000000).round()),
      videoCodec: 'unknown',
      audioCodec: values[1] as bool ? 'unknown' : null,
    );
  }
}
