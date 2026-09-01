import '../../../services/platform/platform_support.dart' as platform;
import '../domain/media_asset.dart';

class MediaProbeRepository {
  const MediaProbeRepository();

  Future<MediaAsset> probe(String path) async {
    final info = await platform.probeMedia(path);
    final seconds = info.durationSeconds ?? 0;
    return MediaAsset(
      path: path,
      duration: Duration(microseconds: (seconds * 1000000).round()),
      width: info.width,
      height: info.height,
      frameRate: info.frameRate,
      videoCodec: info.videoCodec,
      audioCodec: info.hasAudio ? 'unknown' : null,
    );
  }
}
