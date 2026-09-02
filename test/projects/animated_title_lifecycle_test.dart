import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/editor/application/editor_session.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/caption_frame_stream.dart';
import 'package:klipio/features/export/services/export_service.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/text/domain/title_visual_state.dart';
import 'package:klipio/features/text/presentation/caption_paragraph.dart';
import 'package:klipio/features/text/presentation/project_text_raster.dart';
import 'package:klipio/features/timeline/application/timeline_editor.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

const frames = [
  ClipKeyframe(
      offset: 0,
      transform: ClipTransform(
          positionX: .3, positionY: .4, scaleX: .7, scaleY: .9, opacity: .4)),
  ClipKeyframe(
      offset: .4,
      transform: ClipTransform(
          positionX: .7,
          positionY: .6,
          scaleX: 1.2,
          scaleY: .8,
          rotationDegrees: 27,
          opacity: .9)),
  ClipKeyframe(
      offset: .8,
      transform: ClipTransform(
          positionX: .5,
          positionY: .5,
          scaleX: .9,
          scaleY: 1.1,
          rotationDegrees: -27,
          opacity: .6)),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('TitleKhmer');
    loader.addFont(Future.value(ByteData.sublistView(
        await File('C:/Windows/Fonts/NotoSansKhmer-Regular.ttf')
            .readAsBytes())));
    loader.addFont(Future.value(ByteData.sublistView(
        await File('C:/Windows/Fonts/arial.ttf').readAsBytes())));
    await loader.load();
  });
  test(
      'production title export captures before await and publishes only on success',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('klipio-title-publish-');
    addTearDown(() => directory.delete(recursive: true));
    final destination = File('${directory.path}/title.mp4');
    await destination.writeAsString('previous valid output');
    final liveKeys = [...frames];
    final liveTitles = [
      TextOverlaySettings(
          id: 'title',
          text: 'សួស្តី Klipio',
          font: 'TitleKhmer',
          size: 100,
          timelineEnd: .8,
          keyframes: liveKeys)
    ];
    final running = exportMultiTrackTimeline(MultiTrackExportJob(
      timeline: const TimelineModel(tracks: [], duration: 1),
      outputPath: destination.path,
      width: 160,
      height: 240,
      frameRate: 10,
      textOverlays: liveTitles,
    ));
    liveKeys.clear();
    liveTitles.clear();
    final result = await running;
    expect(result.success, isTrue, reason: result.message);
    final published = await destination.readAsBytes();
    final decode = await Process.run(
        File('ffmpeg_extracted/ffmpeg-8.1.2-essentials_build/bin/ffmpeg.exe')
            .absolute
            .path,
        [
          '-v',
          'error',
          '-i',
          destination.path,
          '-ss',
          '0.3',
          '-frames:v',
          '1',
          '-pix_fmt',
          'rgb24',
          '-f',
          'rawvideo',
          'pipe:1'
        ],
        stdoutEncoding: null);
    expect(decode.exitCode, 0, reason: '${decode.stderr}');
    final pixels = decode.stdout as List<int>;
    expect(pixels.length, 160 * 240 * 3);
    expect(pixels.where((v) => v > 30).length, greaterThan(20));
    // Real preparation failure after job staging, not a successful blank export.
    final failed = await exportMultiTrackTimeline(MultiTrackExportJob(
      timeline: const TimelineModel(tracks: [], duration: 1),
      outputPath: destination.path,
      width: 160,
      height: 240,
      frameRate: 10,
      textOverlays: [
        TextOverlaySettings(text: List.filled(400, 'X').join('\n'), size: 500)
      ],
    ));
    expect(failed.success, isFalse);
    expect(await destination.readAsBytes(), published);
    final token = ExportCancelToken()..cancel();
    final canceled = await exportMultiTrackTimeline(MultiTrackExportJob(
      timeline: const TimelineModel(tracks: [], duration: 1),
      outputPath: destination.path,
      width: 160,
      height: 240,
      cancelToken: token,
      textOverlays: const [TextOverlaySettings(text: 'Canceled')],
    ));
    expect(canceled.success, isFalse);
    expect(await destination.readAsBytes(), published);
    expect(await directory.list().length, 1);
  });
  for (final text in [
    'English title',
    'សួស្តី កម្ពុជា',
    'សួស្តី Klipio\nEnglish',
    '👩🏽‍💻 👨‍👩‍👧‍👦 e\u0301 កម្ពុជា',
    'Multiline wrapping words\nខ្មែរ English words'
  ]) {
    test('active session animated title reload and composed export: $text',
        () async {
      final root =
          await Directory.systemTemp.createTemp('klipio-title-lifecycle-');
      addTearDown(() => root.delete(recursive: true));
      final session = EditorSession();
      const editor = TimelineEditor();
      session.timeline = const TimelineModel(duration: 1.2, tracks: [
        TrackModel(id: 'text-1', type: TrackType.text, index: 1, clips: [
          ClipModel(
              id: 'title',
              mediaPath: 'title',
              timelineStart: .1,
              duration: .8,
              sourceStart: 0,
              zIndex: 0),
        ]),
      ]);
      for (final frame in frames) {
        session.timeline =
            editor.setClipKeyframe(session.timeline, 'title', frame);
      }
      session.timeline = session.timeline.copyWith(duration: 1.2);
      final draft = <String, Object?>{
        'id': 'title',
        'text': 'original',
        'font': 'TitleKhmer',
        'size': 100,
        'x': .5,
        'y': .5,
        'stroke': 2,
        'opacity': .8,
        'timelineStart': .1,
        'duration': .8
      };
      draft['text'] = text;
      final captured = session.capture(envelope: {
        'version': 6,
        'videos': [],
        'textOverlays': [draft]
      });
      final before = session.titleExport(revision: captured).single;
      final path = '${root.path}/title.klipio.json';
      await session.save(path, revision: captured);
      session.dispose();
      draft['text'] = 'mutated obsolete object';
      final fresh = EditorSession();
      addTearDown(fresh.dispose);
      fresh.restore((await fresh.read(path)).revision);
      final after = fresh.titleExport().single;
      expect(identical(before, after), isFalse);
      expect(identical(before.keyframes, after.keyframes), isFalse);
      expect(after.id, 'title');
      expect(after.text, text);
      for (final t in [0.0, .1, .3, .5, .899999, .9, 1.0]) {
        expect(TitleTimelineResolver.resolve(after, t).compositionKey,
            TitleTimelineResolver.resolve(before, t).compositionKey);
      }
      final mid = TitleTimelineResolver.resolve(after, .3);
      expect(mid.x, closeTo(.5, 1e-12));
      expect(mid.scaleX, closeTo(.95, 1e-12));
      expect(mid.scaleY, closeTo(.85, 1e-12));
      expect(mid.opacity, closeTo(.65, 1e-12));
      expect(TitleTimelineResolver.resolve(after, .9).active, isFalse);
      final titleSnapshot = [after];
      final streamFuture = CaptionFrameStream.open(
          cues: const [],
          titles: titleSnapshot,
          spec: const CaptionParagraphSpec(style: TextStyle()),
          width: 160,
          height: 240,
          fps: 10,
          duration: 1.2);
      // Mutate the live application AFTER stream capture, before async bind completes.
      fresh.timeline = editor.setClipKeyframe(
          fresh.timeline,
          'title',
          const ClipKeyframe(
              offset: .4,
              transform: ClipTransform(
                  scaleX: 3, positionX: 0, rotationDegrees: 90, opacity: 0)));
      fresh.capture(envelope: {
        'version': 6,
        'videos': [],
        'textOverlays': [
          {...draft, 'text': 'NEXT REVISION'}
        ]
      });
      titleSnapshot.clear();
      expect(fresh.titleExport().single.text, 'NEXT REVISION');
      final stream = await streamFuture;
      addTearDown(stream.close);
      final job = MultiTrackExportJob(
          timeline: const TimelineModel(tracks: [], duration: 1.2),
          textOverlays: [after],
          outputPath: 'unused.mp4',
          width: 160,
          height: 240,
          frameRate: 10);
      expect(
          () => const MultiTrackFilterBuilder()
              .build(job, encoder: 'libx264', titlesStreamed: true),
          throwsStateError);
      final plan = const MultiTrackFilterBuilder().build(job,
          encoder: 'libx264',
          titlesStreamed: true,
          captionStreamUrl: stream.url);
      expect(plan.filterGraph, isNot(contains('drawtext')));
      final result = await Process.run(
          File('ffmpeg_extracted/ffmpeg-8.1.2-essentials_build/bin/ffmpeg.exe')
              .absolute
              .path,
          [
            '-v',
            'error',
            ...plan.arguments.take(plan.arguments.indexOf('-map')),
            '-map',
            '[outv]',
            '-frames:v',
            '12',
            '-pix_fmt',
            'rgb24',
            '-f',
            'rawvideo',
            'pipe:1'
          ],
          stdoutEncoding: null);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      await stream.close();
      expect(stream.error, isNull);
      expect(stream.titleLayouts,
          1); // Multiple transforms, one shaped glyph layer.
      expect(stream.peakCachedBytes, 160 * 240 * 4);
      expect(stream.retainedTitleGlyphBytes, 0);
      expect(stream.peakTitleGlyphBytes, greaterThan(0));
      final output = result.stdout as List<int>;
      const frameSize = 160 * 240 * 3;
      expect(output.length, frameSize * 12);
      expect(output.take(frameSize).every((v) => v == 0), isTrue);
      expect(output.skip(frameSize * 9).every((v) => v == 0), isTrue);
      // Compare actual compositor output against the shared preview description,
      // using the same reusable glyph raster. This is not a native texture test.
      final layout = ProjectTextRaster.shape(after, 160, 240);
      await layout.cacheGlyphs();
      try {
        for (final index in [1, 3, 5, 8]) {
          final recorder = ui.PictureRecorder();
          layout.paint(ui.Canvas(recorder), const ui.Size(160, 240),
              TitleTimelineResolver.resolve(after, index / 10));
          final picture = recorder.endRecording();
          final image = await picture.toImage(160, 240);
          final rgba = (await image.toByteData(
              format: ui.ImageByteFormat.rawStraightRgba))!;
          var error = 0.0, ink = 0;
          for (var p = 0; p < 160 * 240; p++) {
            final alpha = rgba.getUint8(p * 4 + 3) / 255;
            if (alpha > .1) ink++;
            for (var c = 0; c < 3; c++) {
              error += ((rgba.getUint8(p * 4 + c) * alpha).round() -
                      output[index * frameSize + p * 3 + c])
                  .abs();
            }
          }
          expect(ink, greaterThan(20),
              reason:
                  'frame=$index size=${layout.size} state=${TitleTimelineResolver.resolve(after, index / 10).compositionKey}');
          expect(error / frameSize,
              lessThan(1.0)); // Existing monochrome raster bound.
          image.dispose();
          picture.dispose();
        }
      } finally {
        layout.dispose();
      }
    });
  }
}
