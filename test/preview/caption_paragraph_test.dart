import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/text/presentation/caption_paragraph.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/export/services/export_service.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('word boxes use shaped wrapped selection bounds and project units', () {
    const boxSpec = CaptionParagraphSpec(
        style: TextStyle(fontSize: 72, color: Colors.white),
        timedHighlight: true,
        activeWordBackground: Colors.blue);
    const text = 'ខ្មែរ English 👩🏽‍💻\nសួស្តី';
    final full = boxSpec
        .highlightedLayout(text, 200, 1080, [(start: 0, end: text.length)]);
    final half = boxSpec
        .highlightedLayout(text, 100, 540, [(start: 0, end: text.length)]);
    try {
      final expected = full.painter.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: text.length));
      expect(full.highlightBounds, expected.map((b) => b.toRect()).toList());
      expect(full.highlightBounds.length, greaterThan(1));
      expect(half.highlightBounds.length, full.highlightBounds.length);
      for (var i = 0; i < full.highlightBounds.length; i++) {
        expect(half.highlightBounds[i].left,
            closeTo(full.highlightBounds[i].left / 2, .01));
        expect(half.highlightBounds[i].width,
            closeTo(full.highlightBounds[i].width / 2, .01));
      }
      expect(full.painter.text!.toPlainText(), text);
    } finally {
      full.dispose();
      half.dispose();
    }
  });
  test('caption preparation failure preserves output and removes staging',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('caption-budget-test-');
    addTearDown(() => directory.delete(recursive: true));
    final output = File('${directory.path}/existing.mp4');
    await output.writeAsString('previous export');
    final result = await exportMultiTrackTimeline(MultiTrackExportJob(
        timeline: const TimelineModel(tracks: [], duration: 10),
        outputPath: output.path,
        width: 0,
        captionParagraphSpec:
            const CaptionParagraphSpec(style: TextStyle(fontSize: 72)),
        captionSettings: VideoEditSettings(
            speed: 1,
            flip: 'none',
            scaleX: 1,
            scaleY: 1,
            zoom: 1,
            watermarkPath: null,
            watermarkPosition: 'custom',
            watermarkSize: .1,
            musicPath: null,
            originalVolume: 1,
            musicVolume: 0,
            captionCues: List.generate(
                65,
                (i) => CaptionCueSettings(
                    start: i / 10, end: (i + 1) / 10, text: 'cue $i')))));
    expect(result.success, isFalse);
    expect(result.message, contains('Invalid caption stream'));
    expect(await output.readAsString(), 'previous export');
    expect(await directory.list().length, 1);
  });
  const spec = CaptionParagraphSpec(
      style: TextStyle(
          fontSize: 72,
          height: 1.2,
          color: Colors.white,
          shadows: [Shadow(blurRadius: 2)]),
      padding: 10,
      background: Colors.black,
      radius: 8);
  test('whole cue layout preserves Unicode and scales in project units', () {
    const text = 'សួស្តី Klipio 👩🏽‍💻\ne\u0301 កម្ពុជា';
    final full = spec.layout(text, 810, 1080);
    final half = spec.layout(text, 405, 540);
    try {
      expect(full.painter.text!.toPlainText(), text);
      expect(half.size.width, closeTo(full.size.width / 2, 0.01));
      expect(half.size.height, closeTo(full.size.height / 2, 0.01));
    } finally {
      full.dispose();
      half.dispose();
    }
  });
  test('caption raster has visible pixels and bounded project dimensions',
      () async {
    final image = await spec.image('សួស្តី\nKlipio 😀', 162, 216, x: .5, y: .8);
    try {
      expect(image.width, 162);
      expect(image.height, 216);
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      expect(bytes.buffer.asUint8List().where((v) => v != 0), isNotEmpty);
    } finally {
      image.dispose();
    }
  });
  test(
      'caption compositor uses exclusive cue end and never drawtext for raster',
      () {
    const settings = VideoEditSettings(
        speed: 1,
        flip: 'none',
        scaleX: 1,
        scaleY: 1,
        zoom: 1,
        watermarkPath: null,
        watermarkPosition: 'custom',
        watermarkSize: .1,
        musicPath: null,
        originalVolume: 1,
        musicVolume: 0,
        captionCues: [CaptionCueSettings(start: .1, end: .3, text: 'សួស្តី')]);
    const job = MultiTrackExportJob(
        timeline: TimelineModel(tracks: [], duration: 1),
        outputPath: 'unused.mp4',
        captionSettings: settings,
        captionParagraphSpec: spec);
    final plan = const MultiTrackFilterBuilder().build(job,
        encoder: 'libx264', captionRasterPaths: {0: 'owned-caption.png'});
    expect(plan.filterGraph, contains("gte(t,0.1)*lt(t,0.3)"));
    expect(plan.filterGraph, isNot(contains('drawtext')));
    expect(plan.filterGraph, isNot(contains('subtitles=')));
    expect(job.withOutputPath('staging.mp4').captionParagraphSpec, same(spec));
    expect(settings.captionCues.single.text, 'សួស្តី');
  });
}
