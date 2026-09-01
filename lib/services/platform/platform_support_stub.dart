bool get isAndroid => false;
bool get isIos => false;
String get pathSeparator => '/';
String basename(String path) => path.split('/').last;
bool get isDesktop => false;
Future<void> cancelBackgroundMediaTasks() async {}
Future<List<String>> videoFilesInFolder(String folderPath) async => const [];
Future<double?> videoDurationSeconds(String path) async => null;
Future<bool> videoHasAudio(String path) async => true;
Future<List<double>> audioWaveformPeaks(
  String path,
  String cacheFolder,
) async =>
    const [];
Future<double?> audioWindowLevelScore(String path, double start) async => null;
Future<String?> thumbnailForVideo(String path, String cacheFolder) async =>
    null;
Future<List<String>> timelineThumbnailsForVideo(
  String path,
  String cacheFolder,
  double? durationSeconds,
) async =>
    const [];
