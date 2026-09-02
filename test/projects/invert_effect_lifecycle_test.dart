import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/editor/application/editor_session.dart';
import 'package:klipio/features/editor/application/effect_edit.dart';
import 'package:klipio/features/editor/application/snapshot_history.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/export/services/export_service.dart';
import 'package:klipio/features/preview/engine/software_effect_frame.dart';
import 'package:klipio/features/preview/engine/professional_clip_preview.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

const invert = ClipEffect(id: 'invert-A-1', type: ClipEffectType.invert);
const second =
    ClipEffect(id: 'invert-A-2', type: ClipEffectType.invert, amount: .7);
const sourceColor = Color(0xff4080c0);
TimelineModel fixture(String path) => TimelineModel(duration: .4, tracks: [
      TrackModel(id: 'V1', type: TrackType.video, index: 1, clips: [
        ClipModel(
            id: 'A',
            mediaPath: path,
            timelineStart: 0,
            duration: .2,
            sourceStart: 0,
            zIndex: 0),
        ClipModel(
            id: 'B',
            mediaPath: path,
            timelineStart: .2,
            duration: .2,
            sourceStart: 0,
            zIndex: 1),
      ]),
    ]);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'invert active command/history/session and real preview/export lifecycle',
      (tester) async {
    final root = (await tester
        .runAsync(() => Directory.systemTemp.createTemp('klipio-invert-')))!;
    addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));
    final ffmpeg =
        File('ffmpeg_extracted/ffmpeg-8.1.2-essentials_build/bin/ffmpeg.exe')
            .absolute
            .path;
    final source = '${root.path}/source.mkv';
    final png = '${root.path}/source.png';
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(sourceColor, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(32, 32);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(png).writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      final result = await Process.run(ffmpeg, [
        '-v',
        'error',
        '-loop',
        '1',
        '-i',
        png,
        '-t',
        '0.4',
        '-r',
        '10',
        '-c:v',
        'ffv1',
        '-pix_fmt',
        'bgr0',
        source
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final decoder = EffectFrameDecoder();
      final decoded = await decoder.decode(source, .1);
      expect(decoded.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      await decoder.close();
      final canceledDecoder = EffectFrameDecoder();
      final pending = canceledDecoder.decode(source, .1);
      final canceled = expectLater(pending, throwsStateError);
      await canceledDecoder.close();
      await canceled;
    });
    var session = EditorSession()..timeline = fixture(source);
    final history = SnapshotHistory<EditorProjectRevision>();
    final preview = EffectPreview();
    var commits = 0;
    bool commit(EffectEdit? edit) {
      final success = session.commitEffect(edit, beforeChange: () {
        history.record('effect', session.capture, coalesce: false);
        commits++;
      });
      if (success) preview.discard();
      return success;
    }

    Future<void> verify(TimelineModel model, bool inverted, String label,
        {bool export = true, List<int>? rgb}) async {
      final clip = model.clipById('A')!.clip;
      final boundary = GlobalKey();
      await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
              child: RepaintBoundary(
                  key: boundary,
                  child: SizedBox(
                      width: 32,
                      height: 32,
                      child: ProfessionalClipPreview(
                          clip: clip,
                          playheadSeconds: .1,
                          child: const ColoredBox(color: sourceColor)))))));
      await tester.pump();
      final expected = rgb ?? (inverted ? [191, 127, 63] : [64, 128, 192]);
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
        final data =
            (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        for (var c = 0; c < 3; c++) {
          expect(data.getUint8((16 * 32 + 16) * 4 + c), closeTo(expected[c], 1),
              reason: 'preview $label');
        }
        image.dispose();
        if (!export) return;
        final plan = const MultiTrackFilterBuilder().build(
            MultiTrackExportJob(
                timeline: model,
                outputPath: 'unused.mp4',
                width: 32,
                height: 32,
                frameRate: 10),
            encoder: 'libx264',
            sourceDimensions: {source: (width: 32, height: 32)});
        final result = await Process.run(
            ffmpeg,
            [
              '-v',
              'error',
              ...plan.arguments.take(plan.arguments.indexOf('-map')),
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
        expect(result.exitCode, 0, reason: '$label ${result.stderr}');
        final pixels = result.stdout as List<int>;
        expect(pixels.length, 32 * 32 * 3 * 4);
        for (var c = 0; c < 3; c++) {
          expect(pixels[(16 * 32 + 16) * 3 + c], closeTo(expected[c], 3),
              reason: 'export A $label');
          expect(pixels[2 * 32 * 32 * 3 + (16 * 32 + 16) * 3 + c],
              closeTo([64, 128, 192][c], 3),
              reason: 'same-source B $label');
        }
      });
    }

    await verify(session.timeline, false, 'initial');
    final durable = session.capture();
    final token = preview.begin(session.timeline, 'A')!;
    expect(preview.complete(token, session.timeline, [invert]), isTrue);
    await verify(preview.resolve(session.timeline), true, 'temporary',
        export: false);
    expect(session.capture().data, durable.data);
    expect(history.undoEntries, isEmpty);
    expect(commits, 0);
    final project = '${root.path}/project.klipio';
    await tester.runAsync(() => session.save(project));
    final clean = EditorSession();
    await tester.runAsync(
        () async => clean.restore((await clean.read(project)).revision));
    expect(clean.timeline.clipById('A')!.clip.effects, isEmpty);
    clean.dispose();
    preview.discard();
    expect(preview.complete(token, session.timeline, [invert]), isFalse);
    await verify(preview.resolve(session.timeline), false, 'discard');
    final again = preview.begin(session.timeline, 'A')!;
    expect(preview.complete(again, session.timeline, [invert]), isTrue);
    expect(
        commit(EffectEdit.apply(session.timeline, {
          'A': [invert]
        })),
        isTrue);
    expect(commits, 1);
    expect(history.undoEntries, hasLength(1));
    expect(
        identical(preview.resolve(session.timeline), session.timeline), isTrue);
    await verify(session.timeline, true, 'apply');
    session.restore(history.undo(session.capture)!);
    await verify(session.timeline, false, 'undo');
    session.restore(history.redo(session.capture)!);
    await verify(session.timeline, true, 'redo');
    expect(session.timeline.clipById('A')!.clip.effects.single.id, invert.id);
    final captured = ProgramRenderSnapshot.build(
        sourceTimeline: session.timeline, playbackSpeedsByMediaPath: const {});
    final old = session;
    await tester.runAsync(() => old.save(project));
    old.dispose();
    session = EditorSession();
    await tester.runAsync(
        () async => session.restore((await session.read(project)).revision));
    expect(identical(session.timeline, captured.sourceTimeline), isFalse);
    expect(session.timeline.clipById('A')!.clip.effects.single.toJson(),
        invert.toJson());
    expect(
        identical(session.timeline.clipById('A')!.clip.effects.single,
            captured.sourceTimeline.clipById('A')!.clip.effects.single),
        isFalse);
    await verify(session.timeline, true, 'fresh reload');
    expect(
        commit(EffectEdit.change(session.timeline, 'A', invert.id,
            enabled: false)),
        isTrue);
    await verify(session.timeline, false, 'bypass');
    await verify(captured.outputTimeline, true, 'captured before bypass');
    await tester.runAsync(() => session.save(project));
    session.dispose();
    session = EditorSession();
    await tester.runAsync(
        () async => session.restore((await session.read(project)).revision));
    expect(
        session.timeline.clipById('A')!.clip.effects.single.enabled, isFalse);
    expect(
        commit(
            EffectEdit.change(session.timeline, 'A', invert.id, enabled: true)),
        isTrue);
    await verify(session.timeline, true, 'enable after reload');
    // Deliberate stacking is existing behavior, and order/IDs survive capture.
    expect(
        commit(EffectEdit.apply(session.timeline, {
          'A': [second]
        })),
        isTrue);
    await verify(session.timeline, false, 'two inverse instances');
    expect(session.timeline.clipById('A')!.clip.effects.map((e) => e.id),
        [invert.id, second.id]);
    await tester.runAsync(() => session.save(project));
    session.dispose();
    session = EditorSession();
    await tester.runAsync(
        () async => session.restore((await session.read(project)).revision));
    expect(session.timeline.clipById('A')!.clip.effects.map((e) => e.toJson()),
        [invert.toJson(), second.toJson()]);
    expect(
        commit(
            EffectEdit.change(session.timeline, 'A', second.id, remove: true)),
        isTrue);
    await verify(session.timeline, true, 'remove only second instance');
    const sepia = ClipEffect(id: 'sepia', type: ClipEffectType.sepia);
    expect(
        commit(EffectEdit.apply(session.timeline, {
          'A': [sepia]
        })),
        isTrue);
    await verify(session.timeline, true, 'invert then sepia',
        rgb: [185, 164, 128]);
    final stacked = session.capture();
    await tester.runAsync(() => session.save(project));
    session.dispose();
    session = EditorSession();
    await tester.runAsync(
        () async => session.restore((await session.read(project)).revision));
    expect(session.capture().data, stacked.data);
    await verify(session.timeline, true, 'reloaded noncommuting stack',
        rgb: [185, 164, 128]);
    expect(
        commit(
            EffectEdit.change(session.timeline, 'A', invert.id, remove: true)),
        isTrue);
    expect(
        commit(EffectEdit.apply(session.timeline, {
          'A': [invert]
        })),
        isTrue);
    // 255 - M_sepia * (64,128,192), rounded to eight-bit components.
    await verify(session.timeline, true, 'sepia then invert',
        rgb: [95, 113, 144]);
    expect(
        commit(
            EffectEdit.change(session.timeline, 'A', sepia.id, remove: true)),
        isTrue);
    const blur = ClipEffect(id: 'blur', type: ClipEffectType.blur, amount: .2);
    expect(
        commit(EffectEdit.apply(session.timeline, {
          'A': [blur]
        })),
        isTrue);
    await verify(session.timeline, true, 'invert plus constant-color blur');
    expect(session.timeline.clipById('A')!.clip.effects.map((e) => e.id),
        [invert.id, blur.id]);
    expect(
        commit(
            EffectEdit.change(session.timeline, 'A', blur.id, enabled: false)),
        isTrue);
    await verify(session.timeline, true, 'bypass only blur');
    expect(
        commit(EffectEdit.change(session.timeline, 'A', blur.id, remove: true)),
        isTrue);
    expect(
        commit(
            EffectEdit.change(session.timeline, 'A', invert.id, remove: true)),
        isTrue);
    await verify(session.timeline, false, 'remove');
    session.restore(history.undo(session.capture)!);
    await verify(session.timeline, true, 'undo remove');
    session.restore(history.redo(session.capture)!);
    await verify(session.timeline, false, 'redo remove');
    await tester.runAsync(() => session.save(project));
    session.dispose();
    session = EditorSession();
    await tester.runAsync(
        () async => session.restore((await session.read(project)).revision));
    await verify(session.timeline, false, 'reload removed');
    await tester.runAsync(() async {
      final destination = File('${root.path}/published.mp4');
      final exporting = exportMultiTrackTimeline(MultiTrackExportJob(
          timeline: captured.outputTimeline,
          outputPath: destination.path,
          width: 32,
          height: 32,
          frameRate: 10));
      final exported = await exporting;
      expect(exported.success, isTrue, reason: exported.message);
      final bytes = await destination.readAsBytes();
      final failed = await exportMultiTrackTimeline(MultiTrackExportJob(
          timeline: fixture('${root.path}/missing.mkv'),
          outputPath: destination.path,
          width: 32,
          height: 32));
      expect(failed.success, isFalse);
      expect(await destination.readAsBytes(), bytes);
      final canceled = await exportMultiTrackTimeline(MultiTrackExportJob(
          timeline: captured.outputTimeline,
          outputPath: destination.path,
          width: 32,
          height: 32,
          cancelToken: ExportCancelToken()..cancel()));
      expect(canceled.success, isFalse);
      expect(await destination.readAsBytes(), bytes);
    });
    session.dispose();
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
      'preview tokens reject selection changes, removed targets and invalid atomic edits',
      () {
    final session = EditorSession()..timeline = fixture('same-source');
    final preview = EffectPreview();
    final a = preview.begin(session.timeline, 'A')!;
    preview.begin(session.timeline, 'B');
    expect(preview.complete(a, session.timeline, [invert]), isFalse);
    final again = preview.begin(session.timeline, 'A')!;
    final removed = session.timeline.copyWith(tracks: []);
    expect(preview.complete(again, removed, [invert]), isFalse);
    final before = session.timeline;
    var history = 0;
    expect(
        session.commitEffect(
            EffectEdit.apply(before, {
              'A': [invert],
              'missing': [second]
            }),
            beforeChange: () => history++),
        isFalse);
    expect(identical(session.timeline, before), isTrue);
    expect(history, 0);
    final locked = before
        .copyWith(tracks: [before.tracks.single.copyWith(isLocked: true)]);
    expect(
        EffectEdit.apply(locked, {
          'A': [invert]
        }),
        isNull);
    final edit = EffectEdit.apply(before, {
      'A': [invert]
    })!;
    session.timeline = locked;
    expect(session.commitEffect(edit, beforeChange: () => history++), isFalse);
    expect(history, 0);
    preview.discard();
    expect(identical(preview.resolve(before), before), isTrue);
    session.dispose();
  });
}
