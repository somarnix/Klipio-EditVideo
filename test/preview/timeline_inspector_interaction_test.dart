import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/editor/presentation/inspector/inspector_value_control.dart';
import 'package:klipio/features/editor/domain/editor_selection.dart';
import 'package:klipio/features/editor/presentation/layout/workspace_panels.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:klipio/features/timeline/presentation/dynamic_timeline_view.dart';
import 'package:klipio/features/timeline/presentation/timeline_gesture_feedback.dart';

ClipModel clip(String id, double start, {ClipTransition? transition}) =>
    ClipModel(
        id: id,
        mediaPath: 'reused.mp4',
        timelineStart: start,
        duration: 2,
        sourceStart: 0,
        zIndex: 0,
        transitionIn: transition);

void main() {
  testWidgets(
      'numeric gestures commit once and invalid text never reaches commands',
      (tester) async {
    final commits = <double>[];
    var current = .5;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
      builder: (context, setState) => SizedBox(
          width: 270,
          child: InspectorValueControl(
            label: 'Opacity',
            value: current,
            min: 0,
            max: 1,
            resetValue: 1,
            onChanged: (v) {
              commits.add(v);
              setState(() => current = v);
            },
          )),
    ))));
    final slider = find.byType(Slider);
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(25, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(25, 0));
    await tester.pump();
    expect(commits, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(commits, hasLength(1));
    for (final text in ['-', 'NaN', 'Infinity', '2']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(commits, hasLength(1), reason: text);
    }
    await tester.enterText(find.byType(TextField), '0.25');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(commits, hasLength(2));
    expect(current, .25);
    await tester.tap(find.byTooltip('Reset Opacity'));
    await tester.pump();
    expect(commits, hasLength(3));
    expect(current, 1);
  });

  testWidgets('Escape discards a typed draft and selection change disposes it',
      (tester) async {
    final commits = <double>[];
    Future<void> show(String id) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: InspectorValueControl(
                key: ValueKey(id),
                label: 'Scale',
                value: 1,
                min: .1,
                max: 5,
                onChanged: commits.add))));
    await show('A');
    await tester.enterText(find.byType(TextField), '2');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(commits, isEmpty);
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text, '1');
    await tester.enterText(find.byType(TextField), '3');
    await show('B');
    await tester.pump();
    expect(commits, isEmpty);
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text, '1');
  });

  test(
      'snap threshold is screen-space and excludes the moving group and companions',
      () {
    final model = TimelineModel(tracks: [
      TrackModel(
          id: 'v',
          type: TrackType.video,
          index: 1,
          clips: [clip('A', 1), clip('B', 8).copyWith(duration: 3)]),
      TrackModel(id: 'a', type: TrackType.audio, index: 1, clips: [
        clip('linked-A', 1).copyWith(isLinkedAudio: true, linkedClipId: 'A')
      ]),
    ], duration: 10);
    for (final scale in [10.0, 50.0, 160.0]) {
      final result = TimelineGestureSnap.resolve(model,
          movingIds: {'A'},
          anchorId: 'A',
          proposedStart: 8 - 7 / scale,
          duration: 2,
          pixelsPerSecond: scale,
          playhead: 15);
      expect(result.time, 8);
      expect(result.guideTime, 8);
      final outside = TimelineGestureSnap.resolve(model,
          movingIds: {'A'},
          anchorId: 'A',
          proposedStart: 8 - 9 / scale,
          duration: 2,
          pixelsPerSecond: scale,
          playhead: 15);
      expect(outside.guideTime, isNull);
    }
    final group = TimelineGestureSnap.resolve(model,
        movingIds: {'A', 'B'},
        anchorId: 'A',
        proposedStart: 1.02,
        duration: 2,
        pixelsPerSecond: 50,
        playhead: 15);
    expect(group.guideTime, isNull);
    final bypass = TimelineGestureSnap.resolve(model,
        movingIds: {'A'},
        anchorId: 'A',
        proposedStart: 8.001,
        duration: 2,
        pixelsPerSecond: 50,
        playhead: 15,
        enabled: false);
    expect(bypass.time, 8.001);
    expect(model.clipById('A')!.clip.timelineStart, 1);
  });

  test(
      'ruler labels remain bounded at long-project zoom and preserve fractional times',
      () {
    for (final scale in [.08, .5, 1.0, 35.0, 160.0, 500.0]) {
      final step = TimelineRulerScale.majorStep(scale);
      expect(step * scale, greaterThanOrEqualTo(64));
      expect(step * scale, lessThanOrEqualTo(160));
    }
    expect(TimelineRulerScale.label(.5, .5), '0:00.5');
    expect(TimelineRulerScale.label(60.25, .25), '1:00.25');
    expect(TimelineRulerScale.label(3600, 60), '60:00');
  });

  testWidgets(
      'transition region selects its incoming instance, not a reused asset',
      (tester) async {
    String? selected;
    final model = TimelineModel(tracks: [
      TrackModel(id: 'v', type: TrackType.video, index: 1, clips: [
        clip('A', 0),
        clip('B', 1.5,
            transition: const ClipTransition(
                type: ClipTransitionType.dissolve, duration: .5))
      ])
    ], duration: 3.5);
    Future<void> show(TimelineModel value) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                height: 150,
                child: DynamicTimelineView(
                    model: value,
                    pixelsPerSecond: 100,
                    playheadSeconds: 0,
                    onModelChanged: (_) {},
                    onSeek: (_) {},
                    onClipSelected: (_) {},
                    onTransitionSelected: (id) => selected = id)))));
    await show(model);
    await tester.tap(find.byKey(const ValueKey('transition-B')));
    expect(selected, 'B');
    await show(model.copyWith(tracks: [
      model.tracks.first.copyWith(clips: [
        model.tracks.first.clips.first,
        model.tracks.first.clips.last.copyWith(timelineStart: 2.001)
      ])
    ]));
    expect(find.byKey(const ValueKey('transition-B')), findsNothing);
  });

  testWidgets(
      'drag commits once with grabbed offset preserved; locked companions disable trim',
      (tester) async {
    var commits = 0;
    TimelineModel? committed;
    final feedback = ValueNotifier<TimelineGestureFeedback?>(null);
    addTearDown(feedback.dispose);
    final model = TimelineModel(tracks: [
      const TrackModel(id: 'v1', type: TrackType.video, index: 1),
      TrackModel(
          id: 'v2', type: TrackType.video, index: 2, clips: [clip('A', 1)]),
    ], duration: 10);
    Future<void> show(TimelineModel value) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                height: 260,
                child: DynamicTimelineView(
                    model: value,
                    pixelsPerSecond: 50,
                    playheadSeconds: 0,
                    selectedClipId: 'A',
                    gestureFeedback: feedback,
                    onModelChanged: (v) {
                      commits++;
                      committed = v;
                    },
                    onSeek: (_) {},
                    onClipSelected: (_) {})))));
    await show(model);
    final draggable = find.byType(Draggable<TimelineClipDragData>);
    final center = tester.getCenter(draggable);
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(feedback.value, isNotNull,
        reason: 'Drag begins from $center; ${tester.getRect(draggable)}');
    expect(commits, 0);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(feedback.value, isNotNull,
        reason: 'Drag target must receive the active pointer');
    await gesture.up();
    await tester.pump();
    expect(commits, 1);
    expect(committed!.clipById('A')!.clip.timelineStart, 3);
    expect(feedback.value, isNull);
    await show(model.copyWith(tracks: [
      ...model.tracks,
      TrackModel(
          id: 'a',
          type: TrackType.audio,
          index: 1,
          isLocked: true,
          clips: [
            clip('linked', 1).copyWith(isLinkedAudio: true, linkedClipId: 'A')
          ])
    ]));
    expect(find.byKey(const ValueKey('clip-trim-A-end')), findsNothing);
    expect(find.byType(Draggable<TimelineClipDragData>), findsNothing);
  });

  testWidgets('canonical transition selection switches inspector content',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: ContextAwareInspector(
      selection: EditorSelection.transition('B'),
      projectDetails: Text('Project'),
      videoProperties: Text('Video'),
      audioProperties: Text('Audio'),
      textProperties: Text('Title'),
      captionProperties: Text('Caption'),
      transitionProperties: Text('Duration / Replace / Remove'),
    ))));
    expect(find.text('Duration / Replace / Remove'), findsOneWidget);
    expect(find.text('Video'), findsNothing);
  });
}
