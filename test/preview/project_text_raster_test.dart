import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/text/presentation/project_text_raster.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final sample in <String, String>{
    'wrapped Khmer': 'សួស្តី ពិភពលោក សួស្តី ពិភពលោក\nសួស្តី',
    'mixed Khmer English': 'សួស្តី Klipio\nភាសាខ្មែរ English',
    'combining marks': 'កម្ពុជា ក្ខ ក្រ ស្ត្រី\ne\u0301 A\u030a',
    'emoji and fallback': 'Klipio 👩🏽‍💻 👨‍👩‍👧‍👦 😀\nសួស្តី',
    'long narrow wrapping': List.filled(12, 'សួស្តី Klipio').join(' '),
  }.entries) {
    test('Flutter title raster survives export composition: ${sample.key}',
        () async {
      final font = File('C:/Windows/Fonts/NotoSansKhmer-Regular.ttf');
      final loader = FontLoader('RasterKhmer');
      loader.addFont(
          Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
      final title = TextOverlaySettings(
          text: sample.value,
          font: 'RasterKhmer',
          size: 100,
          x: 0.5,
          y: 0.5,
          opacity: 0.8,
          stroke: 3,
          shadow: true,
          curve: 15,
          timelineStart: 0.1,
          timelineEnd: 0.3);
      final png = await ProjectTextRaster.png(title, 160, 240);
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final rgba = (await frame.image
              .toByteData(format: ui.ImageByteFormat.rawStraightRgba))!
          .buffer
          .asUint8List();
      final temp =
          await Directory.systemTemp.createTemp('klipio-text-raster-test-');
      addTearDown(() => temp.delete(recursive: true));
      final imageFile = File('${temp.path}/text.png');
      await imageFile.writeAsBytes(png);
      const timeline = TimelineModel(tracks: [], duration: 0.4);
      final plan = const MultiTrackFilterBuilder().build(
          MultiTrackExportJob(
              timeline: timeline,
              outputPath: 'unused',
              width: 160,
              height: 240,
              frameRate: 10,
              textOverlays: [title]),
          encoder: 'libx264',
          textRasterPaths: {0: imageFile.path});
      expect(plan.filterGraph, isNot(contains('drawtext=')));
      final args = plan.arguments.take(plan.arguments.indexOf('-map')).toList();
      final result = await Process.run(
          File('ffmpeg_extracted/ffmpeg-8.1.2-essentials_build/bin/ffmpeg.exe')
              .absolute
              .path,
          [
            '-v',
            'error',
            ...args,
            '-map',
            '[outv]',
            '-frames:v',
            '4',
            '-pix_fmt',
            'rgb24',
            '-f',
            'rawvideo',
            'pipe:1'
          ],
          stdoutEncoding: null);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final output = result.stdout as List<int>;
      const frameSize = 160 * 240 * 3;
      expect(output.length, frameSize * 4);
      expect(output.take(frameSize).every((v) => v == 0), isTrue);
      expect(output.skip(frameSize * 3).every((v) => v == 0), isTrue);
      var ink = 0;
      var difference = 0;
      for (var pixel = 0; pixel < 160 * 240; pixel++) {
        final alpha = rgba[pixel * 4 + 3] / 255;
        if (alpha > 0.1) ink++;
        for (var c = 0; c < 3; c++) {
          final expected = (rgba[pixel * 4 + c] * alpha).round();
          difference += (expected - output[frameSize + pixel * 3 + c]).abs();
        }
      }
      expect(ink, greaterThan(100));
      // Output is YUV420: this tests preservation of an existing glyph raster,
      // not equality between independent shaping engines. Monochrome glyphs
      // allow a tight whole-frame mean bound for 8-bit conversion.
      expect(difference / frameSize, lessThan(1.0));
      frame.image.dispose();
      codec.dispose();
    });
  }
}
