import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/editor/application/editor_session.dart';
import 'package:klipio/features/captions/domain/editable_caption.dart';
import 'package:klipio/features/captions/application/caption_project_export.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/caption_frame_stream.dart';
import 'package:klipio/features/export/services/export_output_transaction.dart';
import 'package:klipio/features/text/presentation/caption_paragraph.dart';

const asset = 'offline/source.mp4';
const sourceTimeline = TimelineModel(duration: 4, tracks: [
  TrackModel(id: 'video-1', type: TrackType.video, index: 1, clips: [
    ClipModel(
        id: 'first',
        mediaPath: asset,
        timelineStart: 0,
        duration: 2,
        sourceStart: 0,
        zIndex: 0,
        playbackSpeed: 1),
    ClipModel(
        id: 'fork',
        mediaPath: asset,
        timelineStart: 2,
        duration: 2,
        sourceStart: .25,
        zIndex: 0,
        playbackSpeed: 2),
  ]),
  TrackModel(id: 'audio-1', type: TrackType.audio, index: 1),
]);

List<CaptionCueSettings> exportCaptions(EditorSession session) {
  final snapshot = ProgramRenderSnapshot.build(
      sourceTimeline: session.timeline, playbackSpeedsByMediaPath: const {});
  return CaptionProjectExport.resolve(snapshot.sourceTimeline,
      captions: session.captions,
      outputTimeline: snapshot.outputTimeline,
      timelineEnd: snapshot.outputTimeline.duration);
}

CaptionParagraphSpec spec(String motion) => CaptionParagraphSpec(
    style: const TextStyle(
        fontSize: 90,
        color: Colors.yellow,
        height: 1.3,
        shadows: [Shadow(color: Colors.black, offset: Offset(2, 3))]),
    motion: motion,
    timedHighlight: motion != 'whole',
    alignment: TextAlign.center,
    background: const Color(0x88000000),
    padding: 8,
    activeWordBackground: motion == 'box' ? Colors.blue : Colors.transparent);

/// Real production stream -> FFmpeg decoder -> transactional publication.
/// Lossless raw RGBA isolates caption raster evidence from codec tolerances.
Future<List<int>> exportRaster(
    List<CaptionCueSettings> cues, String motion, String path) async {
  final result = await exportOutputTransaction(
      outputPath: path,
      render: (staging) async {
        final stream = await CaptionFrameStream.open(
            cues: cues,
            spec: spec(motion),
            width: 96,
            height: 128,
            fps: 8,
            duration: 3);
        try {
          final process = await Process.run(
              File('ffmpeg_extracted/ffmpeg-8.1.2-essentials_build/bin/ffmpeg.exe')
                  .absolute
                  .path,
              [
                '-v',
                'error',
                '-y',
                '-f',
                'rawvideo',
                '-pixel_format',
                'rgba',
                '-video_size',
                '96x128',
                '-framerate',
                '8',
                '-i',
                stream.url,
                '-frames:v',
                '24',
                '-c:v',
                'rawvideo',
                '-pix_fmt',
                'rgba',
                '-f',
                'rawvideo',
                staging
              ]);
          expect(process.exitCode, 0, reason: '${process.stderr}');
          expect(stream.error, isNull);
          return const ExportResult(
              success: true, message: 'caption layer exported');
        } finally {
          await stream.close();
        }
      },
      validate: (staging) async =>
          await File(staging).length() == 96 * 128 * 4 * 24);
  expect(result.success, isTrue, reason: result.message);
  return File(path).readAsBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final motion in ['whole', 'highlight', 'box', 'bounce', 'pop']) {
    test(
        'active session $motion edit/save/dispose/reload/resolve/export lifecycle',
        () async {
      final root = await Directory.systemTemp.createTemp('klipio-session-');
      addTearDown(() => root.delete(recursive: true));
      final path = '${root.path}/project.klipio.json';
      final old = EditorSession()..timeline = sourceTimeline;
      old.timelines[asset] = sourceTimeline;
      old.capture(envelope: {
        'version': 6,
        'videos': [
          {'path': asset, 'durationSeconds': 3}
        ],
        'outputName': 'Lifecycle',
        'selectedComposition': asset,
        'captions': {'style': motion, 'fontSize': 90, 'opacity': .8},
      });
      final cue = EditableCaptionCue(
          id: 'cue-main',
          start: 0,
          end: 1.25,
          text: 'ខ្មែរ go go 👩🏽‍💻\né English',
          x: .3,
          y: .65,
          metadata: {
            'speaker': 'speaker-1',
            'animation': {'type': motion}
          },
          words: motion == 'whole'
              ? []
              : [
                  EditableCaptionWord(
                      id: 'khmer', start: 0, end: .5, text: 'ខ្មែរ'),
                  EditableCaptionWord(
                      id: 'go-first', start: .5, end: .75, text: 'go'),
                  EditableCaptionWord(
                      id: 'go-second', start: .75, end: 1, text: 'go'),
                  EditableCaptionWord(
                      id: 'emoji', start: 1, end: 1.25, text: '👩🏽‍💻'),
                ]);
      // Same identity-targeted operation called by the real caption dialog.
      old.putCaption(asset, cue);
      old.putCaption(
          asset,
          EditableCaptionCue(
              id: 'cue-second',
              start: 1.5,
              end: 2,
              text: 'English + ខ្មែរ\n😀',
              x: .6,
              y: .4));
      old.putCaption(
          asset,
          cue.copyWith(end: 1.5, text: '${cue.text} edited', words: [
            for (final w in cue.words)
              w.id == 'emoji' ? w.copyWith(end: 1.5) : w,
          ]));
      final before = old.capture();
      final beforeCues = old.captions[asset]!;
      final capturedExport = exportCaptions(old);
      expect(capturedExport.map((c) => c.id), contains('cue-main/clip/fork'));
      // A captured save/export is unaffected by a later live edit.
      final saving = old.save(path, revision: before);
      old.putCaption(asset, cue.copyWith(text: 'must not leak', x: .99));
      old.dispose();
      await saving;
      expect(() => old.capture(), throwsStateError);

      final reopened = EditorSession();
      addTearDown(reopened.dispose);
      final loaded = await reopened.read(path);
      expect(loaded.recovered, isFalse);
      reopened.restore(loaded.revision);
      final after = reopened.captions[asset]!;
      expect(identical(before.data, loaded.revision.data), isFalse);
      expect(identical(beforeCues, after), isFalse);
      expect(identical(beforeCues.first.words, after.first.words), isFalse);
      expect(after.map((c) => c.toJson()).toList(),
          beforeCues.map((c) => c.toJson()).toList());
      expect(reopened.timeline.toJson(), sourceTimeline.toJson());
      expect(reopened.capture().data['captions'], before.data['captions']);
      // The production preview resolver and shaped selection geometry after
      // reconstruction, not just JSON fields.
      for (var i = 0; i < after.length; i++) {
        for (final time in [
          -.000001,
          0.0,
          .25,
          .5,
          .625,
          .75,
          1.0,
          1.25,
          1.5,
          2.0
        ]) {
          final a = EditorSession.captionResolver(beforeCues[i], motion: motion)
              .resolve(time);
          final b = EditorSession.captionResolver(after[i], motion: motion)
              .resolve(time);
          expect((b.cueId, b.text, b.active, b.motion),
              (a.cueId, a.text, a.active, a.motion));
          expect(b.words, a.words);
          expect(b.ranges, a.ranges);
          final first =
              spec(motion).highlightedLayout(a.text, 160, 1080, a.ranges);
          final second =
              spec(motion).highlightedLayout(b.text, 160, 1080, b.ranges);
          try {
            expect(second.highlightBounds, first.highlightBounds);
          } finally {
            first.dispose();
            second.dispose();
          }
        }
      }
      await reopened.save(path);
      final secondSession = EditorSession();
      addTearDown(secondSession.dispose);
      secondSession.restore((await secondSession.read(path)).revision);
      expect(secondSession.captions[asset]!.map((c) => c.toJson()).toList(),
          after.map((c) => c.toJson()).toList());
      final afterExport = exportCaptions(secondSession);
      secondSession.putCaption(asset, cue.copyWith(text: 'future export only'));
      final beforePixels = await exportRaster(
          capturedExport, motion, '${root.path}/before.rgba');
      final afterPixels =
          await exportRaster(afterExport, motion, '${root.path}/after.rgba');
      expect(afterPixels, beforePixels);
      expect(afterPixels.any((b) => b != 0), isTrue);
      expect(
          root
              .listSync()
              .whereType<Directory>()
              .where((d) => d.path.contains('.klipio-export-')),
          isEmpty);
      expect(
          File('${root.path}/Backups/project.previous.klipio.json')
              .existsSync(),
          isTrue);
    });
  }

  test(
      'session migration/recovery preserves duplicate identities and missing media',
      () async {
    final root =
        await Directory.systemTemp.createTemp('klipio-session-recovery-');
    addTearDown(() => root.delete(recursive: true));
    final path = '${root.path}/project.klipio.json';
    final legacy = EditorProjectRevision({
      'videos': [
        {'path': asset}
      ],
      'captionCues': {
        asset: [
          for (var i = 0; i < 2; i++)
            {
              'text': 'same',
              'start': 0,
              'end': 1,
              'words': [
                {'text': 'same', 'start': 0, 'end': 1}
              ]
            }
        ],
      }
    });
    final first = EditorSession()..restore(legacy);
    final ids = first.captions[asset]!.map((c) => c.id).toList();
    expect(ids.toSet().length, 2);
    await first.save(path);
    await first.save(path); // establishes the real backup through repository
    first.dispose();
    await File(path).writeAsString('{corrupt');
    final next = EditorSession();
    addTearDown(next.dispose);
    final recovery = await next.read(path);
    expect(recovery.recovered, isTrue);
    expect(next.captions, isEmpty); // recovery consent is not bypassed by read
    next.restore(recovery.revision);
    expect(next.captions[asset]!.map((c) => c.id).toList(), ids);
    expect(await File(path).readAsString(), '{corrupt');
    await next.save('${root.path}/recovered.json');
    expect(await File(path).readAsString(), '{corrupt');
  });

  test('captured save survives dispose, failed save does not poison next save',
      () async {
    final root = await Directory.systemTemp.createTemp('klipio-session-save-');
    addTearDown(() => root.delete(recursive: true));
    final session = EditorSession();
    final captured = session.capture();
    await expectLater(
        session.save('${root.path}/missing/legacy.json', revision: captured),
        throwsA(isA<FileSystemException>()));
    session.dispose();
    await session.save('${root.path}/project.klipio.json', revision: captured);
    expect(File('${root.path}/project.klipio.json').existsSync(), isTrue);
    expect(() => (captured.data['videos'] as List).add({}),
        throwsUnsupportedError);
  });
}
