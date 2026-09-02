import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';
import 'package:klipio/features/preview/engine/program_timeline_mapper.dart';
import 'package:klipio/features/timeline/application/timeline_editor.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:klipio/features/timeline/presentation/dynamic_timeline_view.dart';
import 'package:klipio/features/editor/presentation/inspector/clip_transform_controls.dart';
import 'package:klipio/features/editor/application/transform_preview.dart';
import 'package:klipio/features/editor/application/editor_session.dart';
import 'package:klipio/features/editor/application/snapshot_history.dart';

TimelineModel program(TimelineModel source) => ProgramRenderSnapshot.build(
    sourceTimeline: source, playbackSpeedsByMediaPath: const {}).outputTimeline;
TimelineModel stored(TimelineModel output) =>
    ProgramRenderSnapshot.trySourceFromProgram(output)!;

TimelineModel fixture(double speed,
    {double duration = 365.25,
    double sourceStart = 0,
    bool locked = false,
    double gap = 0}) {
  final first = ClipModel(
      id: 'A',
      mediaPath: 'same.mp4',
      timelineStart: 0,
      duration: duration,
      sourceStart: sourceStart,
      zIndex: 0,
      playbackSpeed: speed);
  final second = first.copyWith(
      id: 'B',
      timelineStart: duration + gap,
      sourceStart: 20,
      duration: 8,
      playbackSpeed: 2);
  final tracks = [
    TrackModel(
        id: 'video-1', type: TrackType.video, index: 1, clips: [first, second]),
    TrackModel(
        id: 'audio-1',
        type: TrackType.audio,
        index: 1,
        isLocked: locked,
        clips: [
          for (final clip in [first, second])
            clip.copyWith(
                id: 'audio-${clip.id}',
                isLinkedAudio: true,
                linkedClipId: clip.id)
        ]),
    TrackModel(id: 'audio-2', type: TrackType.audio, index: 2, clips: [
      first.copyWith(
          id: 'independent',
          timelineStart: duration / speed + gap,
          duration: 2,
          playbackSpeed: .5)
    ]),
  ];
  return TimelineModel(
      tracks: tracks, duration: TimelineModel.calculateDuration(tracks));
}

void sameProgram(TimelineModel actual, TimelineModel expected) {
  expect(actual.duration, closeTo(expected.duration, 1e-9));
  for (final track in expected.tracks) {
    for (final clip in track.clips) {
      final other = actual.clipById(clip.id)!.clip;
      expect(other.timelineStart, closeTo(clip.timelineStart, 1e-9));
      expect(other.duration, closeTo(clip.duration, 1e-9));
      expect(other.sourceStart, closeTo(clip.sourceStart, 1e-9));
      expect(other.resolvedPlaybackSpeed(), clip.resolvedPlaybackSpeed());
    }
  }
}

void main() {
  testWidgets('live transform drafts commit once despite preview rebuilds',
      (tester) async {
    var durable = const ClipTransform();
    ClipTransform? draft;
    var commits = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: StatefulBuilder(
                    builder: (context, update) => SizedBox(
                        width: 300,
                        child: ClipTransformControls(
                          transform: draft ?? durable,
                          onPreview: (value) => update(() => draft = value),
                          onCancel: () => update(() => draft = null),
                          onChanged: (value) => update(() {
                            durable = value;
                            draft = null;
                            commits++;
                          }),
                        )))))));
    final slider = find.descendant(
        of: find.byKey(const ValueKey('Scale Width')),
        matching: find.byType(Slider));
    await tester.ensureVisible(slider);
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(15, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(15, 0));
    await tester.pump();
    expect(draft, isNotNull);
    expect(durable.scaleX, 1);
    expect(commits, 0);
    final wanted = draft!.scaleX;
    await gesture.up();
    await tester.pump();
    expect(commits, 1);
    expect(draft, isNull);
    expect(durable.scaleX, wanted);
    expect(durable.scaleY, wanted);
  });

  test(
      'trim source limits and proportional scale bounds remain physical constraints',
      () {
    final output = program(fixture(2, duration: 60, sourceStart: 20));
    const editor = TimelineEditor.program(sourceDurations: {'same.mp4': 100});
    final expanded = editor.resizeClip(output,
        clipId: 'A', startEdge: false, deltaSeconds: 100);
    expect(expanded.clipById('A')!.clip.duration, 40);
    final start = editor.resizeClip(output,
        clipId: 'A', startEdge: true, deltaSeconds: -100);
    expect(start.clipById('A')!.clip.sourceStart, 0);
    expect(start.clipById('A')!.clip.duration, 40);
    sameProgram(program(stored(start)), start);
    final scaled = const ClipTransform(scaleX: 1, scaleY: 2)
        .withScale(20, width: true, uniform: true);
    expect(scaled.scaleX, 10);
    expect(scaled.scaleY, 20);
  });
  test(
      'monitor endpoint holds the final frame without changing half-open edits',
      () {
    final source = fixture(1.15);
    final only = source.copyWith(tracks: [
      source.videoTracks.first.copyWith(clips: [source.clipById('A')!.clip])
    ]);
    final output = program(only);
    const end = 365.25 / 1.15;
    expect(output.duration, end);
    expect(ProgramTimelineMapper.resolve(output, end).isGap, isTrue);
    final frameTime = ((end * 30).ceil() - 1) / 30;
    for (final requested in [end, end + 100]) {
      final target = ProgramTimelineMapper.resolveMonitor(output, requested,
          frameRate: 30);
      expect(target.timelineSeconds, end);
      expect(target.clip!.id, 'A');
      expect(target.sourceSeconds, closeTo(frameTime * 1.15, 1e-9));
    }
    const before = end - 1 / 30;
    expect(
        ProgramTimelineMapper.monitorFrameTime(output, before, frameRate: 30),
        before);
    final trailing = output.copyWith(duration: end + 2);
    expect(
        ProgramTimelineMapper.resolveMonitor(trailing, trailing.duration,
                frameRate: 30)
            .isGap,
        isTrue);
  });

  test(
      'program transition handles preserve canonical adjacency and source mapping',
      () {
    const edit = TimelineEditor.program();
    for (final speed in [.5, 1.0, 1.15, 2.0]) {
      for (final gap in [0.0, 1e-15, .001, .25]) {
        final before = program(fixture(speed, duration: 4, gap: gap));
        final changed = edit.setClipTransition(
            before,
            'B',
            const ClipTransition(
                type: ClipTransitionType.dissolve, duration: .25));
        if (gap >= .001) {
          expect(identical(changed, before), isTrue);
        } else {
          final reload = program(stored(changed));
          sameProgram(reload, changed);
          expect(reload.clipById('B')!.clip.transitionIn!.duration, .25);
          expect(
              ProgramTimelineMapper.nextPlayableVideoClip(reload,
                      atOrAfterTimelineSeconds:
                          reload.clipById('A')!.clip.timelineEnd,
                      excludingClipId: 'A',
                      includeOverlapping: true)
                  ?.id,
              'B');
          expect(reload.clipById('audio-B')!.clip.timelineStart,
              reload.clipById('B')!.clip.timelineStart);
          sameProgram(
              program(stored(edit.setClipTransition(changed, 'B', null))),
              before);
        }
      }
    }
  });

  test(
      'program edits survive session disposal, history, and frozen export capture',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('klipio-program-edit-');
    addTearDown(() => directory.delete(recursive: true));
    final session = EditorSession();
    session.timeline = fixture(1.15);
    final original = session.timeline;
    final history = SnapshotHistory<TimelineModel>();
    history.record('split', () => session.timeline, coalesce: false);
    session.timeline = stored(const TimelineEditor.program()
        .splitClip(program(session.timeline), clipId: 'A', playhead: 100));
    final changed = session.timeline;
    expect(changed.videoTracks.first.clips[1].sourceStart, closeTo(115, 1e-9));
    session.timeline = history.undo(() => session.timeline)!;
    sameProgram(program(session.timeline), program(original));
    session.timeline = history.redo(() => session.timeline)!;
    sameProgram(program(session.timeline), program(changed));
    final path = '${directory.path}/project.klipio.json';
    await session.save(path,
        revision: session.capture(envelope: {'version': 6, 'videos': []}));
    session.dispose();
    final fresh = EditorSession();
    addTearDown(fresh.dispose);
    fresh.restore((await fresh.read(path)).revision);
    expect(identical(fresh.timeline, changed), isFalse);
    sameProgram(program(fresh.timeline), program(changed));
    final capture = ProgramRenderSnapshot.build(
        sourceTimeline: fresh.timeline, playbackSpeedsByMediaPath: const {});
    final draft = TransformPreview();
    final id = fresh.timeline.videoTracks.first.clips.first.id;
    expect(
        draft.update(
            fresh.timeline, id, const ClipTransform(scaleX: 5, opacity: .5)),
        isTrue);
    expect(fresh.timeline.clipById(id)!.clip.transform.scaleX, 1);
    expect(
        draft.resolve(fresh.timeline).clipById(id)!.clip.transform.scaleX, 5);
    final accepted = draft.accept(fresh.timeline, id)!;
    fresh.timeline = accepted;
    expect(capture.sourceTimeline.clipById(id)!.clip.transform.scaleX, 1);
    expect(program(fresh.timeline).clipById(id)!.clip.transform.scaleX, 5);
    expect(draft.accept(fresh.timeline, id), isNull);
    expect(draft.update(fresh.timeline, id, const ClipTransform(scaleX: 2)),
        isTrue);
    expect(draft.accept(fresh.timeline, 'B'), isNull);
    expect(identical(draft.resolve(fresh.timeline), fresh.timeline), isTrue);
  });
  const editor = TimelineEditor.program(sourceDurations: {'same.mp4': 400});
  test(
      'source/program editing round trip preserves speed, gaps, linked and independent audio',
      () {
    for (final speed in [1.0, 1.15, 2.0, .5]) {
      for (final gap in [0.0, 1e-15, .001, .25]) {
        final source = fixture(speed, gap: gap);
        final output = program(source);
        expect(output.clipById('A')!.clip.duration, 365.25 / speed);
        final restored = stored(output);
        sameProgram(program(restored), output);
        sameProgram(
            program(TimelineModel.fromJson(
                jsonDecode(jsonEncode(restored.toJson())))),
            output);
        final at = ProgramTimelineMapper.resolve(output, 100);
        expect(at.sourceSeconds, closeTo(100 * speed, 1e-9));
        expect(output.clipById('audio-B')!.clip.timelineStart,
            output.clipById('B')!.clip.timelineStart);
      }
    }
  });

  test(
      'program split/trim/move/ripple preserve source continuity and companion ownership',
      () {
    for (final speed in [.5, 1.0, 1.15, 2.0]) {
      final before = program(fixture(speed, duration: 60, sourceStart: 20));
      final point = 30 / speed;
      final split = editor.splitClip(before, clipId: 'A', playhead: point);
      final pieces = split.videoTracks.first.clips
          .where((c) => c.replacesClipId == 'A')
          .toList();
      expect(pieces, hasLength(2));
      expect(pieces[0].sourceStart, 20);
      expect(pieces[1].sourceStart, 50);
      expect(pieces[0].timelineEnd, pieces[1].timelineStart);
      expect(split.duration, before.duration);
      sameProgram(program(stored(split)), split);
      final trim = editor.resizeClip(before,
          clipId: 'A', startEdge: true, deltaSeconds: 5);
      expect(trim.clipById('A')!.clip.sourceStart, 20 + 5 * speed);
      expect(trim.clipById('B')!.clip.timelineStart,
          before.clipById('B')!.clip.timelineStart - 5);
      expect(trim.clipById('independent')!.clip.timelineStart,
          before.clipById('independent')!.clip.timelineStart - 5);
      sameProgram(program(stored(trim)), trim);
      final moved = editor.moveClip(before,
          clipId: 'B',
          targetTrackId: 'video-1',
          timelineStart: before.clipById('B')!.clip.timelineStart + .25,
          snap: false);
      sameProgram(program(stored(moved)), moved);
      final deleted = editor.deleteClip(before, 'A');
      expect(deleted.clipById('B')!.clip.timelineStart, 0);
      expect(deleted.clipById('audio-A'), isNull);
      sameProgram(program(stored(deleted)), deleted);
      final locked = program(fixture(speed, locked: true));
      expect(
          identical(
              editor.resizeClip(locked,
                  clipId: 'A', startEdge: false, deltaSeconds: -1),
              locked),
          isTrue);
    }
  });

  testWidgets(
      'native example geometry uses program extent, not source duration',
      (tester) async {
    final output = program(fixture(1.15));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                height: 350,
                child: DynamicTimelineView(
                    model: output,
                    editor: editor,
                    pixelsPerSecond: 1,
                    playheadSeconds: 365.25 / 1.15,
                    onModelChanged: (_) {},
                    onSeek: (_) {},
                    onClipSelected: (_) {})))));
    final drag = find.byWidgetPredicate(
        (w) => w is Draggable<TimelineClipDragData> && w.data?.clipId == 'A');
    expect(tester.getSize(drag).width, closeTo(317.608695652, 1e-8));
    expect(find.textContaining('365.25 s'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'transform percentages, exact typing, proportional link and reset use canonical values',
      (tester) async {
    var transform = const ClipTransform(scaleX: 1, scaleY: 2);
    final commits = <ClipTransform>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: StatefulBuilder(
                    builder: (context, update) => SizedBox(
                        width: 300,
                        child: ClipTransformControls(
                            transform: transform,
                            onChanged: (v) {
                              commits.add(v);
                              update(() => transform = v);
                            })))))));
    Finder field(String label) => find.descendant(
        of: find.byKey(ValueKey(label)), matching: find.byType(TextField));
    await tester.enterText(field('Scale Width'), '500%');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(transform.scaleX, 5);
    expect(transform.scaleY, 10);
    expect(commits, hasLength(1));
    await tester.ensureVisible(find.text('Uniform scale'));
    await tester.tap(find.text('Uniform scale'));
    await tester.pump();
    expect(commits, hasLength(1));
    await tester.enterText(field('Scale Height'), '200%');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(transform.scaleX, 5);
    expect(transform.scaleY, 2);
    await tester.enterText(field('Opacity'), '25%');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(transform.opacity, .25);
    await tester.enterText(field('Rotation'), '45°');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(transform.rotationDegrees, 45);
    expect(ClipTransform.fromJson(transform.toJson()).toJson(),
        transform.toJson());
    await tester.ensureVisible(find.byTooltip('Reset Scale Width'));
    await tester.tap(find.byTooltip('Reset Scale Width'));
    await tester.pump();
    expect(transform.scaleX, 1);
    expect(transform.scaleY, 2);
    expect(tester.takeException(), isNull);
  });
}
