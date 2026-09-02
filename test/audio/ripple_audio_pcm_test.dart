import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/editor/application/editor_session.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/timeline/application/timeline_editor.dart';
import 'package:klipio/features/timeline/domain/magnetic_track_resolver.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:klipio/features/timeline/domain/detach_audio_edit.dart';
import 'package:klipio/features/timeline/domain/clip_speed_edit.dart';

TimelineModel fixture(String source, {bool linkedLocked = false}) {
  ClipModel clip(String id, double start, double duration,
          {bool linked = false}) =>
      ClipModel(
          id: id,
          mediaPath: source,
          timelineStart: start,
          duration: duration,
          sourceStart: id == 'music'
              ? .4
              : id == 'locked'
                  ? .7
                  : .1,
          zIndex: 0,
          volume: .5,
          isLinkedAudio: linked,
          linkedClipId: linked ? 'b' : null);
  return TimelineModel(duration: 3.5, tracks: [
    TrackModel(
        id: 'video-1',
        type: TrackType.video,
        index: 1,
        clips: [clip('a', 0, 1), clip('b', 1, .5)]),
    TrackModel(
        id: 'audio-1',
        type: TrackType.audio,
        index: 1,
        isLocked: linkedLocked,
        clips: [clip('linked', 1, .5, linked: true)]),
    TrackModel(
        id: 'audio-2',
        type: TrackType.audio,
        index: 2,
        clips: [clip('detached', 2, .2), clip('music', 2.5, .2)]),
    TrackModel(
        id: 'audio-3',
        type: TrackType.audio,
        index: 3,
        isLocked: true,
        clips: [clip('locked', 3, .2)]),
  ]);
}

void main() {
  const editor = TimelineEditor();
  for (final operation in ['move', 'split']) {
    test('locked linked track rejects atomic video $operation', () {
      final original = fixture('same.mp4', linkedLocked: true);
      final next = operation == 'move'
          ? editor.moveClip(original,
              clipId: 'b',
              targetTrackId: 'video-1',
              timelineStart: .2,
              snap: false)
          : editor.splitClip(original, clipId: 'b', playhead: 1.25);
      expect(next.toJson(), original.toJson());
    });
  }

  for (final operation in [
    'delete-before',
    'delete-linked',
    'insert',
    'trim-start',
    'trim-end',
    'move',
    'split',
    'trim-linked-start',
    'trim-linked-end',
    'detached-owner-edits',
    'locked-ripple',
    'locked-insert',
    'group-move',
    'zero-based-multiple-inputs',
    'delayed-multiple-inputs',
    for (final speed in [.5, 1.0, 2.0])
      for (final edit in ['delete', 'trim', 'insert']) 'retimed-$edit-$speed',
  ]) {
    test(
        'PCM after session save/reload and $operation respects audio ownership',
        () async {
      final root = await Directory.systemTemp.createTemp('klipio-ripple-pcm-');
      addTearDown(() => root.delete(recursive: true));
      final ffmpeg =
          File('ffmpeg_extracted/ffmpeg-8.1.2-essentials_build/bin/ffmpeg.exe')
              .absolute
              .path;
      final source = '${root.path}/tone.mkv';
      final generated = await Process.run(ffmpeg, [
        '-v',
        'error',
        '-y',
        '-f',
        'lavfi',
        '-i',
        'color=black:s=16x16:r=10:d=4',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=1000:sample_rate=48000:duration=4',
        '-c:v',
        'ffv1',
        '-c:a',
        'pcm_s16le',
        source
      ]);
      expect(generated.exitCode, 0, reason: '${generated.stderr}');
      var timeline = fixture(source,
          linkedLocked:
              operation == 'locked-ripple' || operation == 'locked-insert');
      var linkedStart = 1.0, detachedStart = 2.0, musicStart = 2.5;
      var lockedStart = 3.0;
      var linkedDuration = .5;
      var linkedPresent = true;
      if (operation.startsWith('retimed-')) {
        final speed = double.parse(operation.split('-').last);
        timeline = ClipSpeedEdit.apply(timeline, {'a'}, speed);
        timeline = timeline.copyWith(duration: 5.5, tracks: [
          for (final track in timeline.tracks)
            track.copyWith(clips: [
              for (final clip in track.clips)
                switch (clip.id) {
                  'detached' => clip.copyWith(timelineStart: 3),
                  'music' => clip.copyWith(timelineStart: 3.5),
                  'locked' => clip.copyWith(timelineStart: 5),
                  _ => clip,
                },
            ]),
        ]);
        linkedStart = 1 / speed;
        detachedStart = 3;
        musicStart = 3.5;
        lockedStart = 5;
        final edit = operation.split('-')[1];
        final delta = (edit == 'delete'
                ? -1
                : edit == 'trim'
                    ? -.25
                    : .25) /
            speed;
        timeline = switch (edit) {
          'delete' => editor.deleteClip(timeline, 'a'),
          'trim' => editor.resizeClip(timeline,
              clipId: 'a', startEdge: false, deltaSeconds: -.25),
          _ => editor.insertClip(timeline,
              trackId: 'video-1',
              clip: ClipModel(
                  id: 'inserted',
                  mediaPath: source,
                  timelineStart: 0,
                  duration: .25,
                  sourceStart: 0,
                  playbackSpeed: speed,
                  zIndex: 0)),
        };
        linkedStart += delta;
        detachedStart += delta;
        musicStart += delta;
      }
      switch (operation) {
        case 'delete-before':
          timeline = editor.deleteClip(timeline, 'a');
          linkedStart = 0;
          detachedStart = 1;
          musicStart = 1.5;
        case 'delete-linked':
          timeline = editor.deleteClip(timeline, 'b');
          linkedPresent = false;
          detachedStart = 1.5;
          musicStart = 2;
        case 'insert':
          timeline = editor.insertClip(timeline,
              trackId: 'video-1',
              clip: ClipModel(
                  id: 'inserted',
                  mediaPath: source,
                  timelineStart: 0,
                  duration: .25,
                  sourceStart: 0,
                  zIndex: 0));
          linkedStart = 1.25;
          detachedStart = 2.25;
          musicStart = 2.75;
        case 'trim-start':
        case 'trim-end':
          timeline = const MagneticTrackResolver().rippleTrim(
              timeline: timeline,
              clipId: 'a',
              deltaDuration: const Duration(microseconds: 250000),
              edge: operation == 'trim-start' ? TrimEdge.start : TrimEdge.end);
          linkedStart = .75;
          detachedStart = 1.75;
          musicStart = 2.25;
        case 'move':
          timeline = editor.moveClip(timeline,
              clipId: 'b',
              targetTrackId: 'video-1',
              timelineStart: .25,
              snap: false);
          linkedStart = .25;
        case 'split':
          timeline = editor.splitClip(timeline, clipId: 'b', playhead: 1.25);
          expect(
              timeline.audioTracks
                  .expand((t) => t.clips)
                  .where((c) => c.isLinkedAudio)
                  .length,
              2);
        case 'trim-linked-start':
        case 'trim-linked-end':
          timeline = editor.resizeClip(timeline,
              clipId: 'b',
              startEdge: operation == 'trim-linked-start',
              deltaSeconds: operation == 'trim-linked-start' ? .25 : -.25);
          linkedDuration = .25;
          detachedStart = 1.75;
          musicStart = 2.25;
        case 'detached-owner-edits':
          timeline = DetachAudioEdit.apply(timeline, 'b', 'detached-b');
          final detached = timeline.clipById('detached-b')!.clip.toJson();
          timeline = ClipSpeedEdit.apply(timeline, {'b'}, 2);
          timeline = editor.resizeClip(timeline,
              clipId: 'b', startEdge: true, deltaSeconds: .2);
          // Content after a ripple boundary follows independent ripple rules.
          // .2 source seconds at the owner's new 2x speed removes .1
          // program seconds from independently anchored downstream audio.
          detachedStart -= .1;
          musicStart -= .1;
          timeline = editor.moveClip(timeline,
              clipId: 'b',
              targetTrackId: 'video-1',
              timelineStart: 4,
              snap: false);
          timeline = editor.updateTrack(
              timeline,
              'video-1',
              (track) => track.copyWith(clips: [
                    for (final clip in track.clips)
                      clip.id == 'b'
                          ? clip.copyWith(volume: .01, isMuted: true)
                          : clip
                  ]));
          timeline = editor.deleteClip(timeline, 'b');
          expect(timeline.clipById('detached-b')!.clip.toJson(), detached);
        case 'locked-ripple':
          final original = timeline;
          timeline = editor.deleteClip(timeline, 'a');
          expect(timeline, same(original));
        case 'locked-insert':
          final original = timeline;
          timeline = editor.insertClip(timeline,
              trackId: 'video-1',
              clip: ClipModel(
                  id: 'insert',
                  mediaPath: source,
                  timelineStart: 0,
                  duration: .25,
                  sourceStart: 0,
                  zIndex: 0));
          expect(timeline, same(original));
        case 'group-move':
          timeline = editor.moveClips(timeline,
              clipIds: {'b', 'linked'},
              anchorClipId: 'b',
              targetTrackId: 'video-1',
              timelineStart: .25,
              snap: false);
          linkedStart = .25;
        case 'zero-based-multiple-inputs':
          timeline = editor.moveClip(timeline,
              clipId: 'b',
              targetTrackId: 'video-1',
              timelineStart: 0,
              snap: false);
          linkedStart = 0;
        case 'delayed-multiple-inputs':
          // All three distinct source ranges start after zero. No input may
          // inherit AV_NOPTS_VALUE from leading adelay silence.
          break;
      }
      final session = EditorSession()..timeline = timeline;
      final path = '${root.path}/project.klipio.json';
      await session.save(path);
      session.dispose();
      final reloaded = EditorSession();
      addTearDown(reloaded.dispose);
      reloaded.restore((await reloaded.read(path)).revision);
      final snapshot = ProgramRenderSnapshot.build(
          sourceTimeline: reloaded.timeline,
          playbackSpeedsByMediaPath: const {});
      final plan = const MultiTrackFilterBuilder().build(
          MultiTrackExportJob(
              timeline: snapshot.outputTimeline,
              outputPath: 'unused.mp4',
              width: 16,
              height: 16,
              frameRate: 10),
          encoder: 'libx264');
      final args = plan.arguments.take(plan.arguments.indexOf('-map')).toList();
      final rendered = await Process.run(
          ffmpeg,
          [
            '-v',
            'error',
            ...args,
            '-map',
            '[outv]',
            '-f',
            'null',
            '-',
            '-map',
            '[outa]',
            '-ac',
            '1',
            '-ar',
            '48000',
            '-f',
            'f32le',
            'pipe:1'
          ],
          stdoutEncoding: null);
      expect(rendered.exitCode, 0, reason: '${rendered.stderr}');
      final bytes = ByteData.sublistView(
          Uint8List.fromList(rendered.stdout as List<int>));
      expect(bytes.lengthInBytes ~/ 4,
          (snapshot.outputTimeline.duration * 48000).round());
      final intervals = <(double, double)>[
        if (linkedPresent) (linkedStart, linkedStart + linkedDuration),
        (detachedStart, detachedStart + .2),
        (musicStart, musicStart + .2),
        (lockedStart, lockedStart + .2),
      ];
      final actual = <(double, double)>[];
      double? start;
      for (var ms = 0; ms < bytes.lengthInBytes ~/ 4 ~/ 48; ms++) {
        var energy = 0.0;
        for (var i = 0; i < 48; i++) {
          final v = bytes.getFloat32((ms * 48 + i) * 4, Endian.little);
          energy += v * v;
        }
        final active = math.sqrt(energy / 48) > .002;
        if (active) {
          start ??= ms / 1000;
        } else if (start != null) {
          actual.add((start, ms / 1000));
          start = null;
        }
      }
      if (start != null) actual.add((start, bytes.lengthInBytes / 4 / 48000));
      expect(actual.length, intervals.length);
      // Existing 1 ms detector resolution; no codec priming at 1x PCM.
      for (var i = 0; i < intervals.length; i++) {
        // Compare detector bins as integers: the same 1 ms tolerance, without
        // subtraction turning exactly one bin into 1.0000000000003 ms.
        expect(
            ((actual[i].$1 * 1000).round() - (intervals[i].$1 * 1000).round())
                .abs(),
            lessThanOrEqualTo(1));
        expect(
            ((actual[i].$2 * 1000).round() - (intervals[i].$2 * 1000).round())
                .abs(),
            lessThanOrEqualTo(1));
        // ignore: avoid_print
        print(
            'RIPPLE $operation expected=${intervals[i]} measured=${actual[i]} '
            'error=${(actual[i].$1 - intervals[i].$1).abs()},${(actual[i].$2 - intervals[i].$2).abs()} tolerance=.001');
      }
    });
  }
}
