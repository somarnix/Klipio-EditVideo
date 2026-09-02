import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/composition/domain/text_geometry.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

// Characterization, NOT raster-equality evidence. Khmer uses the same primary
// font file. The grapheme export uses Arial; Flutter has explicit Latin/emoji
// fallbacks. Differences in fallback are recorded, not claimed equivalent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = File('C:/Windows/Fonts/NotoSansKhmer-Regular.ttf');
  test(
      'characterize Flutter versus FFmpeg Khmer/text layout without a loose pass tolerance',
      () async {
    final loader = FontLoader('ParityKhmer');
    loader
        .addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
    await loader.load();
    // flutter_test does not inherit the desktop font fallback collection.
    // Load explicit fixtures instead of accidentally measuring Ahem/missing glyphs.
    for (final entry in {
      'ParityLatin': 'arial.ttf',
      'ParityEmoji': 'seguiemj.ttf'
    }.entries) {
      final fallback = FontLoader(entry.key);
      fallback.addFont(Future.value(ByteData.sublistView(
          await File('C:/Windows/Fonts/${entry.value}').readAsBytes())));
      await fallback.load();
    }
    final ffmpeg =
        File('ffmpeg_extracted/ffmpeg-8.1.2-essentials_build/bin/ffmpeg.exe')
            .absolute
            .path;
    for (final entry in {
      'khmer': 'សួស្តី ពិភពលោក',
      'mixed': 'Klipio សួស្តី',
      'graphemes': 'Café 👩🏽‍💻',
      'multiline': 'Klipio\nសួស្តី',
      'wrapping': 'Klipio សួស្តី ពិភពលោក Khmer English wrapping fixture',
    }.entries) {
      const width = 320;
      const height = 240;
      const referenceSize = 162.0;
      final painter = TextPainter(
          text: TextSpan(
              text: entry.value,
              style: TextStyle(
                  fontFamily: 'ParityKhmer',
                  fontFamilyFallback: const ['ParityLatin', 'ParityEmoji'],
                  fontSize:
                      TextGeometry.fontSize(referenceSize, height.toDouble()),
                  color: const ui.Color(0xffffffff),
                  height: 1)),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.noScaling)
        ..layout(maxWidth: width.toDouble());
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..drawColor(const ui.Color(0xff000000), ui.BlendMode.src);
      painter.paint(
          canvas,
          ui.Offset(
              (width - painter.width) / 2, (height - painter.height) / 2));
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final flutter =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List();
      final plan = const MultiTrackFilterBuilder().build(
          MultiTrackExportJob(
              timeline: const TimelineModel(tracks: [], duration: 1),
              outputPath: 'unused.mp4',
              width: width,
              height: height,
              frameRate: 10,
              textOverlays: [
                TextOverlaySettings(
                    text: entry.value,
                    font: 'ParityKhmer',
                    size: referenceSize,
                    x: 0.5,
                    y: 0.5,
                    stroke: 0,
                    shadow: false)
              ]),
          encoder: 'libx264');
      final args = plan.arguments.take(plan.arguments.indexOf('-map')).toList();
      final graphIndex = args.indexOf('-filter_complex') + 1;
      // Pin the test adapter to the loaded file instead of relying on fontconfig.
      args[graphIndex] = args[graphIndex].replaceAll(
          "font='ParityKhmer'",
          entry.key == 'graphemes'
              ? "fontfile='C\\:/Windows/Fonts/arial.ttf'"
              : "fontfile='C\\:/Windows/Fonts/NotoSansKhmer-Regular.ttf'");
      final rendered = await Process.run(
          ffmpeg,
          [
            '-v',
            'error',
            ...args,
            '-map',
            '[outv]',
            '-frames:v',
            '1',
            '-pix_fmt',
            'rgb24',
            '-f',
            'rawvideo',
            'pipe:1'
          ],
          stdoutEncoding: null);
      expect(rendered.exitCode, 0, reason: '${rendered.stderr}');
      final exported = rendered.stdout as List<int>;
      expect(exported.length, width * height * 3);
      var difference = 0;
      var flutterInk = 0;
      var exportInk = 0;
      var equalPixels = 0;
      for (var pixel = 0; pixel < width * height; pixel++) {
        final a = flutter[pixel * 4];
        final b = exported[pixel * 3];
        difference += (a - b).abs();
        if (a > 8) flutterInk++;
        if (b > 8) exportInk++;
        if (a == b) equalPixels++;
      }
      expect(flutterInk, greaterThan(0), reason: 'Flutter ${entry.key}');
      if (entry.key != 'wrapping') {
        expect(exportInk, greaterThan(0), reason: 'FFmpeg ${entry.key}');
      }
      // The current drawtext adapter has no width-constrained wrapping and
      // can place every supported glyph outside the canvas in this fixture.
      // Record this explicitly; this characterization is NOT a parity gate.
      // No broad image-diff threshold: nonzero error is explicitly reported as
      // unresolved, not accepted as visual parity.
      // ignore: avoid_print
      print(
          'TEXT_CHARACTERIZATION ${entry.key}: fontBytes=${await font.length()} '
          'lines=${painter.computeLineMetrics().length} flutterInk=$flutterInk exportInk=$exportInk '
          'MAE=${difference / (width * height)} exactPixels=$equalPixels/${width * height} '
          'PARITY=UNVERIFIED exportBlank=${exportInk == 0}');
      painter.dispose();
      image.dispose();
      picture.dispose();
    }
  },
      skip: !font.existsSync()
          ? 'Requires the pinned Windows Noto Sans Khmer font fixture'
          : false);
}
