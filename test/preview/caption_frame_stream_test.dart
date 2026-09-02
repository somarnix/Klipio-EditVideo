import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/export/services/caption_frame_stream.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/text/presentation/caption_paragraph.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Transfers 1.66 GB: observed ~25 s isolated and ~46 s with the full suite.
  // This is a cache/ownership characterization, not a 30-second speed gate.
  test('100 animated words at 1080p do not retain frame history', () async {
    final stream = await CaptionFrameStream.open(
        cues: [
          for (var i = 0; i < 100; i++)
            CaptionCueSettings(
                id: 'long-$i',
                start: i.toDouble(),
                end: i + 1.0,
                text: 'ខ្មែរ English 👩🏽‍💻',
                words: [
                  CaptionWordSettings(
                      id: 'word-$i',
                      text: 'ខ្មែរ',
                      start: i.toDouble(),
                      end: i + 1.0)
                ])
        ],
        spec: const CaptionParagraphSpec(
            style: TextStyle(fontSize: 72, color: Colors.white),
            timedHighlight: true,
            motion: 'bounce'),
        width: 1920,
        height: 1080,
        fps: 2,
        duration: 100);
    try {
      final socket = await Socket.connect(
          InternetAddress.loopbackIPv4, stream.server.port);
      final bytes = await socket.fold<int>(0, (n, chunk) => n + chunk.length);
      expect(bytes, 1920 * 1080 * 4 * 200);
      expect(stream.rasterizations, 200);
      expect(stream.paragraphLayouts, 100);
      expect(stream.peakCachedParagraphs, 1);
      expect(stream.peakCachedBytes, 8294400);
      expect(stream.error, isNull);
      debugPrint('LONG_ANIMATED_RESOURCE words=100 frames=200 '
          'peakParagraphs=${stream.peakCachedParagraphs} cachedBytes=${stream.peakCachedBytes}');
    } finally {
      await stream.close();
    }
    await expectLater(
        Socket.connect(InternetAddress.loopbackIPv4, stream.server.port),
        throwsA(isA<SocketException>()));
  }, timeout: const Timeout(Duration(minutes: 2)));
  for (final size in [(1920, 1080), (3840, 2160)]) {
    test('animated resource characterization ${size.$1}x${size.$2}', () async {
      final stream = await CaptionFrameStream.open(
          cues: const [
            CaptionCueSettings(
                id: 'resource-cue',
                start: 0,
                end: 1,
                text: 'ខ្មែរ English 👩🏽‍💻',
                words: [
                  CaptionWordSettings(
                      id: 'khmer', start: 0, end: .5, text: 'ខ្មែរ'),
                  CaptionWordSettings(
                      id: 'english', start: .5, end: 1, text: 'English')
                ])
          ],
          spec: const CaptionParagraphSpec(
              style: TextStyle(fontSize: 72, color: Colors.white),
              timedHighlight: true,
              motion: 'bounce'),
          width: size.$1,
          height: size.$2,
          fps: 4,
          duration: 1);
      try {
        final socket = await Socket.connect(
            InternetAddress.loopbackIPv4, stream.server.port);
        final bytes = await socket.fold<int>(0, (n, data) => n + data.length);
        expect(bytes, size.$1 * size.$2 * 4 * 4);
        expect(stream.rasterizations, 4);
        expect(stream.paragraphLayouts, 1);
        expect(stream.peakCachedParagraphs, 1);
        expect(stream.peakCachedBytes, size.$1 * size.$2 * 4);
        expect(stream.error, isNull);
        debugPrint('ANIMATED_CAPTION_RESOURCE ${size.$1}x${size.$2} '
            'cachedBytes=${stream.peakCachedBytes} paragraphLayouts=${stream.paragraphLayouts} '
            'composedFrames=${stream.rasterizations}');
      } finally {
        await stream.close();
      }
      await expectLater(
          Socket.connect(InternetAddress.loopbackIPv4, stream.server.port),
          throwsA(isA<SocketException>()));
    });
  }
  for (final motion in ['bounce', 'pop']) {
    test('$motion streaming reuses shaping while composing timeline phases',
        () async {
      final stream = await CaptionFrameStream.open(
          cues: const [
            CaptionCueSettings(
                id: 'cue',
                start: 0,
                end: 1,
                text: 'Hi Hi',
                words: [
                  CaptionWordSettings(
                      id: 'a',
                      start: 0,
                      end: .5,
                      text: 'Hi',
                      rangeStart: 0,
                      rangeEnd: 2),
                  CaptionWordSettings(
                      id: 'b',
                      start: .5,
                      end: 1,
                      text: 'Hi',
                      rangeStart: 3,
                      rangeEnd: 5)
                ])
          ],
          spec: CaptionParagraphSpec(
              style: const TextStyle(fontSize: 300, color: Colors.red),
              timedHighlight: true,
              motion: motion),
          width: 64,
          height: 64,
          fps: 8,
          duration: 1);
      try {
        final socket = await Socket.connect(
            InternetAddress.loopbackIPv4, stream.server.port);
        final bytes = await socket
            .fold<List<int>>([], (all, chunk) => all..addAll(chunk));
        const length = 64 * 64 * 4;
        expect(bytes.length, length * 8);
        expect(bytes.sublist(0, length),
            isNot(bytes.sublist(2 * length, 3 * length)));
        expect(stream.paragraphLayouts, 1);
        expect(stream.peakCachedParagraphs, 1);
        expect(stream.peakCachedBytes, length);
        expect(stream.error, isNull);
      } finally {
        await stream.close();
      }
    });
  }
  test('stream captures nested word lists before async preparation', () async {
    final words = [const CaptionWordSettings(start: 0, end: 1, text: 'Hello')];
    final cues = [
      CaptionCueSettings(start: 0, end: 1, text: 'Hello', words: words)
    ];
    final pending = CaptionFrameStream.open(
        cues: cues,
        spec: const CaptionParagraphSpec(
            style: TextStyle(fontSize: 72), timedHighlight: true),
        width: 64,
        height: 64,
        fps: 1,
        duration: 1);
    words.clear();
    cues.clear();
    final stream = await pending;
    try {
      expect(stream.cues.single.words.single.text, 'Hello');
      expect(() => stream.cues.single.words.clear(), throwsUnsupportedError);
      final socket = await Socket.connect(
          InternetAddress.loopbackIPv4, stream.server.port);
      expect(await socket.fold<int>(0, (n, bytes) => n + bytes.length),
          64 * 64 * 4);
      expect(stream.error, isNull);
    } finally {
      await stream.close();
    }
  });
  for (final size in [(1920, 1080), (3840, 2160)]) {
    test('resource characterization ${size.$1}x${size.$2}', () async {
      final stream = await CaptionFrameStream.open(
          cues: const [
            CaptionCueSettings(
                start: 0, end: 1, text: 'សួស្តី Klipio\nខ្មែរ English 😀')
          ],
          spec: const CaptionParagraphSpec(
              style: TextStyle(fontSize: 72, color: Colors.white)),
          width: size.$1,
          height: size.$2,
          fps: 2,
          duration: 1);
      try {
        final socket = await Socket.connect(
            InternetAddress.loopbackIPv4, stream.server.port);
        final bytes = await socket.fold<int>(0, (n, chunk) => n + chunk.length);
        expect(bytes, size.$1 * size.$2 * 4 * 2);
        expect(stream.rasterizations, 1);
        expect(stream.peakCachedBytes, size.$1 * size.$2 * 4);
        debugPrint(
            'CAPTION_RESOURCE ${size.$1}x${size.$2}: cachedBytes=${stream.peakCachedBytes}, cachedRasters=1, stagedCaptionBytes=0');
      } finally {
        await stream.close();
      }
    });
  }
  for (final box in [false, true]) {
    test('timed word box=$box changes visual but midpoint reuses it', () async {
      final stream = await CaptionFrameStream.open(
          cues: const [
            CaptionCueSettings(start: 0, end: 1, text: 'Hello world', words: [
              CaptionWordSettings(start: 0, end: .5, text: 'Hello'),
              CaptionWordSettings(start: .5, end: 1, text: 'world')
            ])
          ],
          spec: CaptionParagraphSpec(
              style: const TextStyle(fontSize: 300, color: Colors.red),
              activeWordBackground: box ? Colors.blue : Colors.transparent,
              timedHighlight: true,
              inactiveColor: Colors.white),
          width: 64,
          height: 64,
          fps: 4,
          duration: 1);
      try {
        final socket = await Socket.connect(
            InternetAddress.loopbackIPv4, stream.server.port);
        final bytes = await socket
            .fold<List<int>>([], (all, chunk) => all..addAll(chunk));
        const length = 64 * 64 * 4;
        expect(bytes.length, length * 4);
        var bluePixels = 0;
        for (var i = 0; i < length; i += 4) {
          if (bytes[i + 2] > bytes[i] && bytes[i + 2] > bytes[i + 1]) {
            bluePixels++;
          }
        }
        expect(bluePixels, box ? greaterThan(0) : equals(0));
        expect(bytes.sublist(0, length), bytes.sublist(length, length * 2));
        expect(bytes.sublist(0, length),
            isNot(bytes.sublist(length * 2, length * 3)));
        expect(stream.rasterizations, 2);
        expect(stream.paragraphLayouts, 1);
        expect(stream.peakCachedParagraphs, 1);
      } finally {
        await stream.close();
      }
    });
  }
  const spec = CaptionParagraphSpec(
      style: TextStyle(fontSize: 300, color: Colors.white));
  Future<CaptionFrameStream> open(int count,
          {ExportCancelToken? token, CaptionParagraphSpec style = spec}) =>
      CaptionFrameStream.open(
          cues: List.generate(
              count,
              (i) => CaptionCueSettings(
                  start: i.toDouble(), end: i + 1.0, text: 'ខ្មែរ $i 😀')),
          spec: style,
          width: 32,
          height: 32,
          fps: 1,
          duration: count.toDouble(),
          token: token);
  Future<int> read(CaptionFrameStream stream) async {
    final socket =
        await Socket.connect(InternetAddress.loopbackIPv4, stream.server.port);
    return socket.fold<int>(0, (total, bytes) => total + bytes.length);
  }

  for (final count in [100, 500]) {
    test('$count captions stream with one cached frame and no staging files',
        () async {
      final stream = await open(count);
      try {
        expect(await read(stream), count * 32 * 32 * 4);
        expect(stream.rasterizations, count);
        expect(stream.peakCachedBytes, 32 * 32 * 4);
        expect(stream.error, isNull);
      } finally {
        await stream.close();
      }
      await expectLater(
          Socket.connect(InternetAddress.loopbackIPv4, stream.server.port),
          throwsA(isA<SocketException>()));
    });
  }
  test('simultaneous jobs are isolated and decoder reconnect restarts',
      () async {
    final a = await open(100);
    final b = await open(100);
    try {
      expect(a.url, isNot(b.url));
      expect(await Future.wait([read(a), read(b)]), [409600, 409600]);
      expect(await read(a), 409600);
    } finally {
      await a.close();
      await b.close();
    }
  });
  test('cancel stops preparation and closes job socket', () async {
    final token = ExportCancelToken();
    final stream = await open(500, token: token);
    final socket =
        await Socket.connect(InternetAddress.loopbackIPv4, stream.server.port);
    var bytes = 0;
    try {
      await for (final chunk in socket) {
        bytes += chunk.length;
        token.cancel();
      }
      await stream.close();
      expect(bytes, lessThan(500 * 4096));
      expect(stream.rasterizations, lessThan(500));
      expect(stream.error, isNull);
    } finally {
      socket.destroy();
      await stream.close();
    }
  });
  test('raster failure is surfaced and releases connection', () async {
    final stream = await open(100, style: const _BrokenSpec());
    try {
      expect(await read(stream), 0);
      expect(stream.error, isA<StateError>());
    } finally {
      await stream.close();
    }
  });
}

class _BrokenSpec extends CaptionParagraphSpec {
  const _BrokenSpec() : super(style: const TextStyle());
  @override
  CaptionParagraphLayout layout(
          String text, double width, double canvasHeight) =>
      throw StateError('Injected shaping failure');
}
