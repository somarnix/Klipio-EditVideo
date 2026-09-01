import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createPreviewController(String path) async {
  throw UnsupportedError(
      'Video preview from local files is not available in web mode.');
}
