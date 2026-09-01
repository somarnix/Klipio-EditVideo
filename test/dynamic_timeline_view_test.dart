import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/timeline/presentation/dynamic_timeline_view.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  testWidgets('CapCut-style blue playhead and green skimmer respond to mouse',
      (tester) async {
    var seekSeconds = 0.0;
    final skimmerSeconds = ValueNotifier<double?>(null);
    final playheadOverride = ValueNotifier<double?>(null);
    addTearDown(skimmerSeconds.dispose);
    addTearDown(playheadOverride.dispose);
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'video-clip',
              mediaPath: 'video.mp4',
              timelineStart: 0,
              duration: 10,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(id: 'audio-1', type: TrackType.audio, index: 1),
      ],
      duration: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 260,
            child: DynamicTimelineView(
              model: model,
              pixelsPerSecond: 50,
              playheadSeconds: 2,
              skimmerSeconds: skimmerSeconds,
              playheadOverride: playheadOverride,
              onModelChanged: (_) {},
              onSeek: (value) => seekSeconds = value,
              onClipSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Ctrl+C'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(354, 90));
    await mouse.moveTo(const Offset(354, 90));
    await tester.pump();
    expect(skimmerSeconds.value, closeTo(4.44, 0.1));

    await tester.tapAt(const Offset(454, 90));
    await tester.pump();
    expect(seekSeconds, closeTo(6.44, 0.1));

    final handle = find.byIcon(Icons.arrow_drop_down);
    expect(handle, findsOneWidget);
    await tester.drag(handle, const Offset(100, 0));
    await tester.pump();
    expect(seekSeconds, closeTo(4, 0.25));

    playheadOverride.value = 7;
    await tester.pump();
    expect(tester.getCenter(handle).dx, closeTo(482, 1));
  });

  testWidgets('selected video clips expose draggable trim handles',
      (tester) async {
    TimelineModel? changed;
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'video-clip',
              mediaPath: 'video.mp4',
              timelineStart: 0,
              duration: 10,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
      ],
      duration: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 180,
          child: DynamicTimelineView(
            model: model,
            pixelsPerSecond: 50,
            playheadSeconds: 0,
            selectedClipId: 'video-clip',
            onModelChanged: (value) => changed = value,
            onSeek: (_) {},
            onClipSelected: (_) {},
          ),
        ),
      ),
    );

    final endHandle = find.byKey(const ValueKey('clip-trim-video-clip-end'));
    expect(endHandle, findsOneWidget);
    await tester.drag(endHandle, const Offset(50, 0));
    expect(changed?.clipById('video-clip')?.clip.duration, greaterThan(10.5));
  });

  testWidgets(
      'clicking empty timeline space seeks instead of only clearing marquee',
      (tester) async {
    var seekSeconds = -1.0;
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'video-clip',
              mediaPath: 'video.mp4',
              timelineStart: 0,
              duration: 5,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
      ],
      duration: 20,
    );
    final marquee = TimelineMarqueeController();
    addTearDown(marquee.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 180,
          child: DynamicTimelineView(
            model: model,
            pixelsPerSecond: 50,
            playheadSeconds: 0,
            marqueeController: marquee,
            onMarqueeSelection: (_, __) {},
            onModelChanged: (_) {},
            onSeek: (value) => seekSeconds = value,
            onClipSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(650, 90));
    await tester.pump();
    expect(seekSeconds, closeTo(10.36, 0.2));
  });

  testWidgets('linked source audio renders inside its video clip',
      (tester) async {
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'video-clip',
              mediaPath: 'video.mp4',
              timelineStart: 0,
              duration: 5,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'audio-1',
          type: TrackType.audio,
          index: 1,
          clips: [
            ClipModel(
              id: 'audio-video-clip',
              mediaPath: 'video.mp4',
              timelineStart: 0,
              duration: 5,
              sourceStart: 0,
              zIndex: 0,
              isLinkedAudio: true,
              linkedClipId: 'video-clip',
            ),
          ],
        ),
      ],
      duration: 5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 700,
          height: 180,
          child: DynamicTimelineView(
            model: model,
            pixelsPerSecond: 50,
            playheadSeconds: 0,
            onModelChanged: (_) {},
            onSeek: (_) {},
            onClipSelected: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('linked-audio-waveform-video-clip')),
      findsOneWidget,
    );
    expect(find.text('A1'), findsNothing);
  });

  testWidgets('caption cues render on T1 without a separate TRACKS row',
      (tester) async {
    String? selectedCaption;
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'video-clip',
              mediaPath: 'video.mp4',
              timelineStart: 0,
              duration: 5,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
      ],
      duration: 5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 700,
          height: 220,
          child: DynamicTimelineView(
            model: model,
            pixelsPerSecond: 50,
            playheadSeconds: 0,
            captionCues: const [
              TimelineCaptionCueData(
                id: 'caption:video:0',
                timelineStart: 1,
                duration: 2,
                text: 'Visible caption text',
              ),
            ],
            onCaptionSelected: (value) => selectedCaption = value,
            onModelChanged: (_) {},
            onSeek: (_) {},
            onClipSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('TRACKS'), findsNothing);
    expect(find.text('T1'), findsOneWidget);
    expect(find.text('Visible caption text'), findsOneWidget);
    expect(find.byTooltip('Hide captions'), findsOneWidget);
    expect(find.byTooltip('Lock captions'), findsOneWidget);
    expect(find.byTooltip('Delete caption track'), findsOneWidget);
    expect(find.byTooltip('Delete V1 track'), findsOneWidget);
    await tester.tap(find.text('Visible caption text'));
    expect(selectedCaption, 'caption:video:0');
  });

  testWidgets('source audio fallback keeps waveform inside the video clip',
      (tester) async {
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'video-clip',
              mediaPath: 'video.mp4',
              timelineStart: 0,
              duration: 5,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'text-1',
          type: TrackType.text,
          index: 1,
        ),
      ],
      duration: 5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 700,
          height: 190,
          child: DynamicTimelineView(
            model: model,
            pixelsPerSecond: 50,
            playheadSeconds: 0,
            mediaWithSourceAudio: const {'video.mp4'},
            onModelChanged: (_) {},
            onSeek: (_) {},
            onClipSelected: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('linked-audio-waveform-video-clip')),
      findsOneWidget,
    );
    expect(find.text('T1'), findsNothing);
  });

  testWidgets('video track exposes separate visibility and source audio mute',
      (tester) async {
    TimelineModel? changed;
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'video-clip',
              mediaPath: 'video.mp4',
              timelineStart: 0,
              duration: 5,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'audio-1',
          type: TrackType.audio,
          index: 1,
          clips: [
            ClipModel(
              id: 'audio-video-clip',
              mediaPath: 'video.mp4',
              timelineStart: 0,
              duration: 5,
              sourceStart: 0,
              zIndex: 0,
              isLinkedAudio: true,
              linkedClipId: 'video-clip',
            ),
          ],
        ),
      ],
      duration: 5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 760,
          height: 180,
          child: DynamicTimelineView(
            model: model,
            pixelsPerSecond: 50,
            playheadSeconds: 0,
            onModelChanged: (value) => changed = value,
            onSeek: (_) {},
            onClipSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('Hide track'), findsOneWidget);
    expect(find.byTooltip('Mute source audio'), findsOneWidget);
    expect(find.byTooltip('Lock track'), findsOneWidget);
    expect(find.byTooltip('Delete V1 track'), findsOneWidget);
    await tester.tap(find.byTooltip('Mute source audio'));
    expect(changed?.clipById('audio-video-clip')?.clip.isMuted, isTrue);
  });

  testWidgets('clip selection reports Ctrl toggle and Shift range modifiers',
      (tester) async {
    final selections = <(String, bool, bool)>[];
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'clip-one',
              mediaPath: 'one.mp4',
              timelineStart: 0,
              duration: 3,
              sourceStart: 0,
              zIndex: 0,
            ),
            ClipModel(
              id: 'clip-two',
              mediaPath: 'two.mp4',
              timelineStart: 4,
              duration: 3,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
      ],
      duration: 7,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 760,
          height: 180,
          child: DynamicTimelineView(
            model: model,
            pixelsPerSecond: 50,
            playheadSeconds: 0,
            onModelChanged: (_) {},
            onSeek: (_) {},
            onClipSelected: (_) {},
            onClipSelectionChanged: (id, toggle, range) =>
                selections.add((id, toggle, range)),
          ),
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('one'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('two'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(selections, [
      ('clip-one', true, false),
      ('clip-two', false, true),
    ]);
  });

  testWidgets('empty-space mouse drag marquee selects every touched clip',
      (tester) async {
    final controller = TimelineMarqueeController();
    addTearDown(controller.dispose);
    Set<String>? selected;
    bool? additive;
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'clip-one',
              mediaPath: 'one.mp4',
              timelineStart: 0,
              duration: 3,
              sourceStart: 0,
              zIndex: 0,
            ),
            ClipModel(
              id: 'clip-two',
              mediaPath: 'two.mp4',
              timelineStart: 4,
              duration: 3,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
      ],
      duration: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 760,
          height: 180,
          child: DynamicTimelineView(
            model: model,
            pixelsPerSecond: 50,
            playheadSeconds: 0,
            marqueeController: controller,
            onMarqueeSelection: (ids, add) {
              selected = ids;
              additive = add;
            },
            onModelChanged: (_) {},
            onSeek: (_) {},
            onClipSelected: (_) {},
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(600, 95));
    await mouse.down(const Offset(600, 95));
    await mouse.moveTo(const Offset(140, 35));
    await tester.pump();
    expect(controller.value, isNotNull);
    await mouse.up();
    await tester.pump();

    expect(selected, {'clip-one', 'clip-two'});
    expect(additive, isFalse);
    expect(controller.value, isNull);
  });

  testWidgets('marquee selects captions text video audio and music together',
      (tester) async {
    final controller = TimelineMarqueeController();
    addTearDown(controller.dispose);
    Set<String>? selected;
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'text-1',
          type: TrackType.text,
          index: 1,
          clips: [
            ClipModel(
              id: 'text-clip',
              mediaPath: 'title',
              timelineStart: 0,
              duration: 2,
              sourceStart: 0,
              zIndex: 2,
            ),
          ],
        ),
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'video-clip',
              mediaPath: 'video.mp4',
              timelineStart: 0,
              duration: 2,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'audio-2',
          type: TrackType.audio,
          index: 2,
          clips: [
            ClipModel(
              id: 'audio-clip',
              mediaPath: 'voice.wav',
              timelineStart: 0,
              duration: 2,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
      ],
      duration: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 760,
          height: 340,
          child: DynamicTimelineView(
            model: model,
            pixelsPerSecond: 50,
            playheadSeconds: 0,
            captionCues: const [
              TimelineCaptionCueData(
                id: 'caption:video:0',
                timelineStart: 0,
                duration: 2,
                text: 'Caption',
              ),
            ],
            musicPath: 'music.mp3',
            marqueeController: controller,
            onMarqueeSelection: (ids, _) => selected = ids,
            onModelChanged: (_) {},
            onSeek: (_) {},
            onClipSelected: (_) {},
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(640, 305));
    await mouse.down(const Offset(640, 305));
    await mouse.moveTo(const Offset(135, 31));
    await tester.pump();
    await mouse.up();
    await tester.pump();

    expect(selected, {
      'caption:video:0',
      'text-clip',
      'video-clip',
      'audio-clip',
      'music-track',
    });
  });

  testWidgets('offscreen clips are not built outside the buffered viewport',
      (tester) async {
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'visible-clip',
              mediaPath: 'visible.mp4',
              timelineStart: 2,
              duration: 3,
              sourceStart: 0,
              zIndex: 0,
            ),
            ClipModel(
              id: 'offscreen-clip',
              mediaPath: 'offscreen.mp4',
              timelineStart: 120,
              duration: 3,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
      ],
      duration: 125,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 180,
          child: DynamicTimelineView(
            model: model,
            pixelsPerSecond: 20,
            playheadSeconds: 0,
            visibleStartSeconds: 0,
            visibleEndSeconds: 20,
            onModelChanged: (_) {},
            onSeek: (_) {},
            onClipSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('visible'), findsOneWidget);
    expect(find.text('offscreen'), findsNothing);
  });

  testWidgets('trim previews during drag and commits once on release',
      (tester) async {
    var previewUpdates = 0;
    var commits = 0;
    var directModelUpdates = 0;
    TimelineModel? finalPreview;
    const model = TimelineModel(
      tracks: [
        TrackModel(
          id: 'video-1',
          type: TrackType.video,
          index: 1,
          clips: [
            ClipModel(
              id: 'video-clip',
              mediaPath: 'video.mp4',
              timelineStart: 0,
              duration: 10,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
      ],
      duration: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 800,
          height: 180,
          child: DynamicTimelineView(
            model: model,
            pixelsPerSecond: 50,
            playheadSeconds: 0,
            selectedClipId: 'video-clip',
            onModelChanged: (_) => directModelUpdates++,
            onModelPreviewChanged: (value) {
              previewUpdates++;
              finalPreview = value;
            },
            onModelPreviewCommitted: () => commits++,
            onSeek: (_) {},
            onClipSelected: (_) {},
          ),
        ),
      ),
    );

    final handle = find.byKey(
      const ValueKey('clip-trim-video-clip-end'),
    );
    await tester.drag(handle, const Offset(70, 0));
    await tester.pump();

    expect(previewUpdates, greaterThan(0));
    expect(directModelUpdates, 0);
    expect(commits, 1);
    expect(
      finalPreview?.clipById('video-clip')?.clip.duration,
      closeTo(11.4, 0.05),
    );
  });
}
