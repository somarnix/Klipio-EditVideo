import 'dart:io';

import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createPreviewController(String path) async {
  final controller = VideoPlayerController.file(File(path));
  await controller.initialize();
  await controller.setLooping(true);
  return controller;
}
