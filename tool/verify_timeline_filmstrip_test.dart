// Run with flutter test tool/verify_timeline_filmstrip_test.dart and set
// KLIPIO_FILMSTRIP_SOURCE to a real local video. This probe is read-only for
// the source and writes derived frames only into a fresh temporary directory.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/services/platform/platform_support.dart' as platform;

void main() {
  test('real media decodes distinct timeline samples', () async {
    final source = Platform.environment['KLIPIO_FILMSTRIP_SOURCE'];
    expect(source, isNotNull, reason: 'Set KLIPIO_FILMSTRIP_SOURCE');
    final probe = await platform.probeMedia(source!);
    final duration = probe.durationSeconds;
    expect(duration, isNotNull);
    final cache = await Directory.systemTemp.createTemp('klipio_real_strip_');
    addTearDown(() => cache.delete(recursive: true));
    var updates = 0;
    final frames = await platform.timelineThumbnailsForVideo(
      source,
      cache.path,
      duration,
      onFrames: (_) => updates++,
    );
    expect(frames, isNotEmpty);
    expect(frames.every((path) => path.isNotEmpty), isTrue);
    final pixels = {
      for (final path in frames) base64Encode(await File(path).readAsBytes())
    };
    expect(pixels.length, greaterThan(1),
        reason: 'Use a source with changing scenes, not a still image');
    // ignore: avoid_print
    print('Source: $duration seconds; ${frames.toSet().length} decoded frames; '
        '${pixels.length} distinct image contents; $updates progressive updates');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
