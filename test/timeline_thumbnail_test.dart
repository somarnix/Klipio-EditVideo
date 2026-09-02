import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:klipio/services/platform/platform_support.dart' as platform;

void main() {
  test('long-source cold and warm sparse grids have no missing image slots',
      () async {
    if (!platform.isDesktop) return;
    final temp = await Directory.systemTemp.createTemp('klipio_sparse_strip_');
    addTearDown(() => temp.delete(recursive: true));
    final source = '${temp.path}/source.mp4';
    final generated = await Process.run('ffmpeg', [
      '-y',
      '-loglevel',
      'error',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=160x90:rate=1:duration=120',
      '-c:v',
      'libx264',
      '-preset',
      'ultrafast',
      '-g',
      '1',
      source,
    ]);
    expect(generated.exitCode, 0, reason: '${generated.stderr}');
    final cache = '${temp.path}/cache';
    final updates = <List<String>>[];
    final cold = await platform.timelineThumbnailsForVideo(source, cache, 120,
        onFrames: (frames) => updates.add(List.of(frames)));
    expect(updates, hasLength(5));
    expect(updates.first.every((path) => path.isEmpty), isTrue);
    expect(updates[1].where((path) => path.isNotEmpty).toSet(), hasLength(4));
    expect(updates[1].last, isEmpty,
        reason: 'Do not repeat an early frame over undecoded later times');
    expect(updates.last, cold);
    expect(cold, hasLength(24));
    expect(cold.toSet().length, 16, reason: 'bounded full-source overview');
    expect(cold.first, endsWith('_00.jpg'));
    expect(cold.last, endsWith('_23.jpg'));
    for (final path in cold) {
      expect(File(path).lengthSync(), greaterThan(0));
    }
    expect({
      for (final path in cold) base64Encode(File(path).readAsBytesSync())
    }, hasLength(16), reason: 'Actual different pixels, not renamed covers');
    final warm = await platform.timelineThumbnailsForVideo(source, cache, 120);
    expect(warm, cold,
        reason: 'cache hit must not return nonexistent planned frames');
    final zoomed = await platform.timelineThumbnailsForVideo(source, cache, 120,
        visibleSourceStart: 45, visibleSourceEnd: 65);
    for (final path in zoomed) {
      expect(File(path).lengthSync(), greaterThan(0));
    }
    final warmZoom = await platform.timelineThumbnailsForVideo(
        source, cache, 120,
        visibleSourceStart: 45, visibleSourceEnd: 65);
    expect(warmZoom, zoomed);
    var canceled = false;
    final cancelCache = '$cache/cancel';
    final stopped = await platform.timelineThumbnailsForVideo(
      source,
      cancelCache,
      120,
      isCanceled: () => canceled,
      onFrames: (frames) {
        if (frames.any((path) => path.isNotEmpty)) canceled = true;
      },
    );
    expect(stopped, isEmpty);
    expect(Directory(cancelCache).listSync().whereType<File>(), hasLength(4),
        reason: 'Leaving the target stops remaining decode batches');
  }, timeout: const Timeout(Duration(minutes: 1)));

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
