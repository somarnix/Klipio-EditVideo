import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/editor/application/editor_session.dart';
import 'package:klipio/features/editor/application/transition_edit.dart';
import 'package:klipio/features/editor/application/snapshot_history.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/preview/engine/professional_clip_preview.dart';
import 'package:klipio/features/preview/engine/multi_track_preview.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:klipio/features/timeline/domain/transition_boundary.dart';

TimelineModel fixture(String path,
    {double speedA = 1,
    double speedB = 1,
    double gap = 0,
    double duration = 1}) {
  final a = ClipModel(
      id: 'A',
      mediaPath: path,
      timelineStart: 0,
      duration: duration,
      sourceStart: 0,
      zIndex: 0,
      playbackSpeed: speedA);
  final b = ClipModel(
      id: 'B',
      mediaPath: path,
      timelineStart: duration + gap,
      duration: duration,
      sourceStart: duration,
      zIndex: 1,
      playbackSpeed: speedB);
  return TimelineModel(duration: duration * 2 + gap + .2, tracks: [
    TrackModel(id: 'V1', type: TrackType.video, index: 1, clips: [a, b]),
    TrackModel(id: 'A1', type: TrackType.audio, index: 1, clips: [
      a.copyWith(id: 'audio-A', isLinkedAudio: true, linkedClipId: 'A'),
      b.copyWith(id: 'audio-B', isLinkedAudio: true, linkedClipId: 'B'),
    ])
  ]);
}

const dissolve =
    ClipTransition(type: ClipTransitionType.dissolve, duration: .2);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'canonical transition edit matrix preserves gaps, short durations, speeds and linked ownership',
      () {
    for (final a in [.5, 1.0, 2.0]) {
      for (final b in [.5, 1.0, 2.0]) {
        for (final gap in [0.0, 1e-15, .001, .25]) {
          for (final length in [.02, 1.0]) {
            final model = fixture('same-source',
                speedA: a, speedB: b, gap: gap, duration: length);
            final edit = TransitionEdit.prepare(model, 'B', dissolve);
            if (gap >= .001) {
              expect(edit, isNull);
              continue;
            }
            expect(edit, isNotNull);
            final after = edit!.after;
            expect(after.duration, model.duration);
            final restored = TimelineModel.fromJson(after.toJson());
            final output = ProgramRenderSnapshot.build(
                sourceTimeline: restored,
                playbackSpeedsByMediaPath: const {}).outputTimeline;
            final first = output.clipById('A')!.clip,
                second = output.clipById('B')!.clip;
            expect(TransitionBoundary.overlaps(first, second), isTrue,
                reason: '$a/$b gap=$gap length=$length');
            expect(second.transitionIn!.duration,
                lessThanOrEqualTo(first.duration * .49 + 1e-15));
            expect(second.timelineStart,
                output.clipById('audio-B')!.clip.timelineStart);
            expect(second.timelineEnd,
                output.clipById('audio-B')!.clip.timelineEnd);
            final d = second.transitionIn!.duration;
            for (final phase in [0.0, .25, .5, .75, 1.0]) {
              expect(
                  TransitionBoundary.progress(
                      second, second.timelineStart + d * phase),
                  closeTo(phase, 1e-12));
            }
            final repeat = TransitionEdit.prepare(
                after, 'B', after.clipById('B')!.clip.transitionIn);
            expect(repeat, isNull);
            final removed = TransitionEdit.prepare(after, 'B', null)!.after;
            expect(
                removed.clipById('B')!.clip.timelineStart, first.duration * a);
            expect(removed.duration, model.duration);
            expect(removed.clipById('audio-B')!.clip.transitionIn, isNull);
          }
        }
      }
    }
    final model = fixture('same');
    final locked = model.copyWith(tracks: [
      model.tracks.first,
      model.tracks.last.copyWith(isLocked: true)
    ]);
    expect(TransitionEdit.prepare(locked, 'B', dissolve), isNull);
    final preview = TransitionPreview();
    final token = preview.begin(model, 'B');
    preview.discard();
    expect(preview.complete(token, model, dissolve), isFalse);
    final next = preview.begin(model, 'B');
    expect(
        preview.complete(next, model.copyWith(tracks: []), dissolve), isFalse);
    expect(
        TransitionEdit.prepare(
            model,
            'B',
            const ClipTransition(
                type: ClipTransitionType.dissolve, duration: double.nan)),
        isNull);
  });

  testWidgets(
      'dissolve browser-independent active session lifecycle with real frame and PCM export',
      (tester) async {
    final root = (await tester
        .runAsync(() => Directory.systemTemp.createTemp('klipio-dissolve-')))!;
    addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
    final ffmpeg =
        File('ffmpeg_extracted/ffmpeg-8.1.2-essentials_build/bin/ffmpeg.exe')
            .absolute
            .path;
    final source = '${root.path}/fixture.mkv';
    await tester.runAsync(() async {
      final result = await Process.run(ffmpeg, [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'color=black:s=32x32:r=20:d=1',
        '-f',
        'lavfi',
        '-i',
        'color=white:s=32x32:r=20:d=1',
        '-f',
        'lavfi',
        '-i',
        'aevalsrc=0.1:s=48000:d=2',
        '-filter_complex',
        '[0:v][1:v]concat=n=2:v=1:a=0[v]',
        '-map',
        '[v]',
        '-map',
        '2:a',
        '-c:v',
        'ffv1',
        '-c:a',
        'pcm_s16le',
        source
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    });
    var session = EditorSession()..timeline = fixture(source);
    final history = SnapshotHistory<EditorProjectRevision>(),
        preview = TransitionPreview();
    var commits = 0;
    bool apply(ClipTransition? value) {
      final result = session.commitTransition(
          TransitionEdit.prepare(session.timeline, 'B', value),
          beforeChange: () {
        history.record('transition', session.capture, coalesce: false);
        commits++;
      });
      if (result) preview.discard();
      return result;
    }

    final baseline = session.capture();
    final token = preview.begin(session.timeline, 'B');
    expect(preview.complete(token, session.timeline, dissolve), isTrue);
    expect(session.capture().data, baseline.data);
    expect(commits, 0);
    expect(history.undoEntries, isEmpty);
    final temp = preview.resolve(session.timeline);
    expect(temp.clipById('B')!.clip.timelineStart, .8);
    preview.discard();
    expect(
        identical(preview.resolve(session.timeline), session.timeline), isTrue);
    final again = preview.begin(session.timeline, 'B');
    preview.complete(again, session.timeline, dissolve);
    expect(apply(dissolve), isTrue);
    expect(commits, 1);
    expect(history.undoEntries, hasLength(1));
    session.restore(history.undo(session.capture)!);
    expect(session.timeline.clipById('B')!.clip.transitionIn, isNull);
    session.restore(history.redo(session.capture)!);
    expect(session.timeline.clipById('B')!.clip.transitionIn!.toJson(),
        dissolve.toJson());
    expect(
        apply(const ClipTransition(
            type: ClipTransitionType.dissolve, duration: .3)),
        isTrue);
    expect(session.timeline.clipById('B')!.clip.timelineStart, .7);
    expect(apply(dissolve), isTrue);
    final path = '${root.path}/project.klipio';
    await tester.runAsync(() => session.save(path));
    session.dispose();
    session = EditorSession();
    await tester.runAsync(
        () async => session.restore((await session.read(path)).revision));
    final captured = ProgramRenderSnapshot.build(
        sourceTimeline: session.timeline, playbackSpeedsByMediaPath: const {});
    expect(captured.outputTimeline.clipById('B')!.clip.timelineStart, .8);
    expect(session.timeline.duration, 2.2);
    expect(
        apply(const ClipTransition(
            type: ClipTransitionType.slideLeft, duration: .2)),
        isTrue);
    expect(apply(null), isTrue);
    expect(session.timeline.clipById('B')!.clip.timelineStart, 1);
    session.restore(history.undo(session.capture)!);
    expect(session.timeline.clipById('B')!.clip.transitionIn, isNotNull);
    session.restore(history.redo(session.capture)!);
    expect(session.timeline.clipById('B')!.clip.transitionIn, isNull);
    expect(captured.outputTimeline.clipById('B')!.clip.transitionIn!.type,
        ClipTransitionType.dissolve);
    await tester.runAsync(() => session.save(path));
    session.dispose();
    session = EditorSession();
    await tester.runAsync(
        () async => session.restore((await session.read(path)).revision));
    expect(session.timeline.clipById('B')!.clip.transitionIn, isNull);
    final output = captured.outputTimeline;
    final plan = const MultiTrackFilterBuilder().build(
        MultiTrackExportJob(
            timeline: output,
            outputPath: 'unused.mp4',
            width: 32,
            height: 32,
            frameRate: 20),
        encoder: 'libx264',
        audioClipIdsWithStreams: {'audio-A', 'audio-B'},
        sourceDimensions: {source: (width: 32, height: 32)});
    late List<int> frames;
    await tester.runAsync(() async {
      final prefix =
          plan.arguments.take(plan.arguments.indexOf('-map')).toList();
      final result = await Process.run(
          ffmpeg,
          [
            '-v',
            'error',
            ...prefix,
            '-map',
            '[outv]',
            '-map',
            '[outa]',
            '-c:a',
            'pcm_s16le',
            '-f',
            'null',
            'NUL',
            '-map',
            '[outv]',
            '-frames:v',
            '22',
            '-pix_fmt',
            'rgb24',
            '-f',
            'rawvideo',
            'pipe:1'
          ],
          stdoutEncoding: null);
      // Independent consumers of filter labels require separate graph runs below.
      if (result.exitCode == 0) {
        frames = result.stdout as List<int>;
      }
    });
    // Render video and audio together into a lossless intermediate, then measure.
    await tester.runAsync(() async {
      final movie = '${root.path}/render.mkv';
      final prefix =
          plan.arguments.take(plan.arguments.indexOf('-map')).toList();
      final render = await Process.run(ffmpeg, [
        '-v',
        'error',
        ...prefix,
        '-map',
        '[outv]',
        '-map',
        '[outa]',
        '-c:v',
        'ffv1',
        '-c:a',
        'pcm_s16le',
        '-t',
        '2.2',
        movie
      ]);
      expect(render.exitCode, 0, reason: '${render.stderr}');
      final raw = await Process.run(
          ffmpeg,
          [
            '-v',
            'error',
            '-i',
            movie,
            '-frames:v',
            '22',
            '-pix_fmt',
            'rgb24',
            '-f',
            'rawvideo',
            'pipe:1'
          ],
          stdoutEncoding: null);
      expect(raw.exitCode, 0);
      frames = raw.stdout as List<int>;
      final pcm = await Process.run(
          ffmpeg,
          [
            '-v',
            'error',
            '-i',
            movie,
            '-vn',
            '-ac',
            '1',
            '-ar',
            '48000',
            '-f',
            's16le',
            'pipe:1'
          ],
          stdoutEncoding: null);
      expect(pcm.exitCode, 0);
      final data =
          ByteData.sublistView(Uint8List.fromList(pcm.stdout as List<int>));
      // Equal DC sources crossfade to the same amplitude, without a dip or peak.
      for (final time in [.79, .8, .85, .9, .95, 1.0, 1.05]) {
        final amplitude =
            data.getInt16((time * 48000).round() * 2, Endian.little) / 32768;
        expect(amplitude, closeTo(.1, .002), reason: 'PCM time=$time');
      }
    });
    for (final index in [15, 16, 17, 18, 19, 20, 21]) {
      final time = index / 20;
      final expected = time < .8
          ? 0
          : time >= 1
              ? 255
              : ((time - .8) / .2 * 255).round();
      expect(frames[index * 32 * 32 * 3 + (16 * 32 + 16) * 3],
          closeTo(expected, 3),
          reason: 'export $time');
      final active = MultiTrackPreview.activeVideoLayers(
          model: output, playheadSeconds: time, includeBaseTrack: true);
      final key = GlobalKey();
      await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
              child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Stack(fit: StackFit.expand, children: [
                        const ColoredBox(color: Colors.black),
                        for (final layer in active)
                          ProfessionalClipPreview(
                              clip: layer.clip,
                              playheadSeconds: time,
                              child: ColoredBox(
                                  color: layer.clip.id == 'A'
                                      ? Colors.black
                                      : Colors.white))
                      ]))))));
      await tester.pump();
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
        final rgba =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        expect(rgba.getUint8((16 * 32 + 16) * 4), closeTo(expected, 1),
            reason: 'preview $time');
        image.dispose();
      });
    }
    session.dispose();
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 2)));
}
