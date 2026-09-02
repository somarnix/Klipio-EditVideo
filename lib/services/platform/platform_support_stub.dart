bool get isAndroid => false;
bool get isIos => false;
String get pathSeparator => '/';
String basename(String path) => path.split('/').last;
bool get isDesktop => false;

typedef MediaProbeInfo = ({
  double? durationSeconds,
  int width,
  int height,
  double frameRate,
  String videoCodec,
  int bitrate,
  bool hasAudio,
});

typedef AudioWaveformLod = ({
  List<double> peaks,
  double peaksPerSecond,
});

Future<void> cancelBackgroundMediaTasks() async {}
Future<List<String>> videoFilesInFolder(String folderPath) async => const [];
Future<double?> videoDurationSeconds(String path) async => null;
Future<bool> videoHasAudio(String path) async => true;
Future<MediaProbeInfo> probeMedia(String path) async => const (
      durationSeconds: null,
      width: 0,
      height: 0,
      frameRate: 0.0,
      videoCodec: 'unknown',
      bitrate: 0,
      hasAudio: true,
    );
Future<List<double>> audioWaveformPeaks(
  String path,
  String cacheFolder,
) async =>
    const [];
Future<AudioWaveformLod> audioWaveformLod(
  String path,
  String cacheFolder, {
  double? durationSeconds,
}) async =>
    const (peaks: <double>[], peaksPerSecond: 20.0);
Future<double?> audioWindowLevelScore(String path, double start) async => null;
Future<String?> thumbnailForVideo(String path, String cacheFolder) async =>
    null;
Future<List<String>> timelineThumbnailsForVideo(
  String path,
  String cacheFolder,
  double? durationSeconds, {
  double? visibleSourceStart,
  double? visibleSourceEnd,
  void Function(List<String> frames)? onFrames,
  bool Function()? isCanceled,
}) async =>
    const [];
bool mediaNeedsProxy(MediaProbeInfo info) => false;
Future<String?> generateProxyMedia(
  String path,
  String cacheFolder, {
  String resolution = '720p',
  double? durationSeconds,
}) async =>
    null;
