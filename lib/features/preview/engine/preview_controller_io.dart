import 'dart:io';

import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createPreviewController(String path) async {
  final controller = VideoPlayerController.file(File(path));
  try {
    await controller.initialize();
    await controller.setLooping(true);
    return controller;
  } catch (_) {
    // A failed initializer is never returned to the editor, so its caller
    // cannot dispose the native player/decoder on our behalf.
    try {
      await controller.dispose();
    } catch (_) {
      // Preserve the initialization failure rather than masking it with cleanup.
    }
    rethrow;
  }
}
