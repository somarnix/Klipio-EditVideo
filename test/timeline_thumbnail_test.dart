import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:klipio/services/platform/platform_support.dart' as platform;

void main() {
  test('desktop timeline thumbnails sample frames across the video', () async {
    if (!platform.isDesktop) return;
    final temp = await Directory.systemTemp.createTemp('klipio_filmstrip_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final source = '${temp.path}${Platform.pathSeparator}source.mp4';
    final generated = await Process.run('ffmpeg', [
      '-y',
      '-loglevel',
      'error',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=640x360:rate=24:duration=2',
      '-c:v',
      'libx264',
      '-preset',
      'ultrafast',
      source,
    ]);
    expect(generated.exitCode, 0, reason: '${generated.stderr}');

    final frames = await platform.timelineThumbnailsForVideo(
      source,
      '${temp.path}${Platform.pathSeparator}cache',
      2,
    );
    expect(frames.length, 8);
    for (final frame in frames) {
      expect(await File(frame).length(), greaterThan(0));
    }
  }, timeout: const Timeout(Duration(minutes: 1)));
}
