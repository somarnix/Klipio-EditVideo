import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/timeline/application/timeline_editor.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:klipio/features/timeline/presentation/dynamic_timeline_view.dart';

void main() {
  testWidgets(
      'filmstrip fills visible clip and maps trimmed speed to source frames',
      (tester) async {
    late Directory temporary;
    late List<String> frames;
    await tester.runAsync(() async {
      temporary = await Directory.systemTemp.createTemp('klipio_strip_layout_');
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.orange, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 9);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      frames = [for (var i = 0; i < 24; i++) '${temporary.path}/$i.png'];
      for (final path in frames) {
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
      }
      image.dispose();
      picture.dispose();
    });
    addTearDown(() => temporary.delete(recursive: true));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox).first);
    await tester.runAsync(() => Future.wait([
          for (final path in frames)
            precacheImage(
                ResizeImage(FileImage(File(path)), width: 160), context),
        ]));
    const model = TimelineModel(duration: 30, tracks: [
      TrackModel(id: 'v', type: TrackType.video, index: 1, clips: [
        ClipModel(
            id: 'clip',
            mediaPath: 'source',
            timelineStart: 0,
            duration: 30,
            sourceStart: 40,
            playbackSpeed: 2,
            zIndex: 0),
      ]),
      TrackModel(id: 'a', type: TrackType.audio, index: 1, clips: [
        ClipModel(
            id: 'linked',
            mediaPath: 'source',
            timelineStart: 0,
            duration: 30,
            sourceStart: 40,
            playbackSpeed: 2,
            zIndex: 0,
            isLinkedAudio: true,
            linkedClipId: 'clip'),
      ]),
    ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      height: 160,
      child: DynamicTimelineView(
        model: model,
        editor: const TimelineEditor.program(),
        pixelsPerSecond: 20,
        playheadSeconds: 0,
        visibleStartSeconds: 0,
        visibleEndSeconds: 30,
        thumbnailPaths: {'source': frames},
        sourceDurations: const {'source': 120},
        mediaWithSourceAudio: const {'source'},
        onModelChanged: (_) {},
        onSeek: (_) {},
        onClipSelected: (_) {},
      ),
    ))));
    await tester.pump();
    final images = find.byType(Image);
    expect(images, findsNWidgets(8));
    final bounds = [
      for (final element in images.evaluate())
        tester.getRect(find.byWidget(element.widget))
    ];
    expect(bounds.last.right - bounds.first.left, closeTo(598, 2));
    for (var i = 1; i < bounds.length; i++) {
      expect(bounds[i].left, closeTo(bounds[i - 1].right, .01));
    }
    final selectedPaths = [
      for (final image in tester.widgetList<Image>(images))
        ((image.image as ResizeImage).imageProvider as FileImage).file.path
    ];
    expect(selectedPaths.first, frames[8]);
    expect(selectedPaths.last, frames[19]);
    expect(selectedPaths.toSet().length, 8);
    final audio = tester
        .getRect(find.byKey(const ValueKey('linked-audio-waveform-clip')));
    expect(bounds.first.bottom, lessThanOrEqualTo(audio.top));
    expect(bounds.first.height, greaterThan(30));
    expect(tester.takeException(), isNull);
    // A new source/grid can be pending while old images remain in Flutter's
    // cache. Pending slots must not keep/repeat a cover or the previous source.
    await tester.pumpWidget(MaterialApp(
      home: DynamicTimelineView(
        model: model,
        editor: const TimelineEditor.program(),
        pixelsPerSecond: 20,
        playheadSeconds: 0,
        thumbnailPaths: {'source': List.filled(24, '')},
        sourceDurations: const {'source': 120},
        onModelChanged: (_) {},
        onSeek: (_) {},
        onClipSelected: (_) {},
      ),
    ));
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.movie_outlined), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
}
