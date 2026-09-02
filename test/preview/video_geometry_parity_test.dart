import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/composition/domain/video_geometry.dart';
import 'package:klipio/features/composition/domain/text_geometry.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:klipio/features/preview/engine/program_timeline_mapper.dart';

void main() {
  test('text uses project units without rewriting Khmer or grapheme content',
      () {
    const title = 'សួស្តី Khmer 👩🏽‍💻\nCafé';
    expect(TextGeometry.fontSize(54, 360), 18);
    expect(TextGeometry.fontSize(54, 1440), 72);
    const timeline = TimelineModel(tracks: [
      TrackModel(id: 'v', type: TrackType.video, index: 0, clips: [
        ClipModel(
            id: 'a',
            mediaPath: 'a.mp4',
            timelineStart: 0,
            sourceStart: 0,
            duration: 2,
            zIndex: 0)
      ])
    ], duration: 2);
    final graph = const MultiTrackFilterBuilder()
        .build(
            const MultiTrackExportJob(
                timeline: timeline,
                outputPath: 'out.mp4',
                width: 1080,
                height: 1440,
                textOverlays: [
                  TextOverlaySettings(
                      text: title, size: 54, stroke: 3, shadow: true)
                ]),
            encoder: 'libx264')
        .filterGraph;
    expect(graph, contains('fontsize=72'));
    expect(graph, contains('borderw=4'));
    expect(graph, contains('shadowx=4:shadowy=4'));
    expect(graph, contains('សួស្តី Khmer 👩🏽‍💻'));
    expect(graph, contains(r'\nCafé'));
  });
  test(
      'rotation uses angle bounds after nonuniform scaling and keeps pan pivot',
      () {
    for (final source in [
      (width: 1600.0, height: 900.0),
      (width: 900.0, height: 1600.0)
    ]) {
      for (final angle in [0.0, 90.0, -90.0, 27.0]) {
        final box = VideoGeometry.resolve(
            canvasWidth: 900,
            canvasHeight: 1200,
            sourceWidth: source.width,
            sourceHeight: source.height,
            scaleX: 1.2,
            scaleY: 0.8,
            positionX: 0.75,
            positionY: 0.25);
        final extent =
            VideoGeometry.rotatedExtent(box.width, box.height, angle);
        if (angle.abs() == 90) {
          expect(extent.width, closeTo(box.height, 1e-8));
          expect(extent.height, closeTo(box.width, 1e-8));
        }
        final left = box.left + (box.width - extent.width) / 2;
        expect(
            left + extent.width / 2, closeTo(box.left + box.width / 2, 1e-8));
        final timeline = TimelineModel(tracks: [
          TrackModel(id: 'v', type: TrackType.video, index: 0, clips: [
            ClipModel(
                id: 'a',
                mediaPath: 'source.mp4',
                timelineStart: 0,
                sourceStart: 0,
                duration: 2,
                zIndex: 0,
                transform: ClipTransform(
                    scaleX: 1.2,
                    scaleY: 0.8,
                    positionX: 0.75,
                    positionY: 0.25,
                    rotationDegrees: angle,
                    flip: 'down',
                    opacity: 0.7))
          ])
        ], duration: 2);
        final graph = const MultiTrackFilterBuilder().build(
            MultiTrackExportJob(
                timeline: timeline,
                outputPath: 'out.mp4',
                width: 900,
                height: 1200),
            encoder: 'libx264',
            sourceDimensions: {'source.mp4': source}).filterGraph;
        expect(graph, contains('vflip'));
        if (angle != 0) {
          expect(
              graph.indexOf('scale=900'), lessThan(graph.indexOf('rotate=')));
          expect(graph, isNot(contains('rotw(iw)')));
          expect(graph, contains('abs(W-'));
          expect(graph, contains('-w)/2'));
        }
      }
    }
  });
  test('export optimization never removes a small gap or trailing canvas', () {
    for (final gap in [0.000001, 0.001, 0.002, 1.0]) {
      final timeline = TimelineModel(tracks: [
        TrackModel(id: 'v', type: TrackType.video, index: 0, clips: [
          const ClipModel(
              id: 'a',
              mediaPath: 'same.mp4',
              timelineStart: 0,
              duration: 2,
              sourceStart: 10,
              zIndex: 0),
          ClipModel(
              id: 'b',
              mediaPath: 'same.mp4',
              timelineStart: 2 + gap,
              duration: 2,
              sourceStart: 30,
              zIndex: 0),
        ])
      ], duration: 4 + gap);
      expect(
          ProgramTimelineMapper.resolve(timeline, 2 + gap / 2).isGap, isTrue);
      expect(ProgramTimelineMapper.resolve(timeline, 2 + gap).clip!.id, 'b');
      final plan = const MultiTrackFilterBuilder().build(
          MultiTrackExportJob(timeline: timeline, outputPath: 'out.mp4'),
          encoder: 'libx264');
      expect(plan.filterGraph, isNot(contains('concat=')));
      expect(plan.duration, timeline.duration);
      if (gap == 0.000001) {
        expect(plan.filterGraph, contains('gte(t,2.000001)'));
      }
    }
    const trailing = TimelineModel(tracks: [
      TrackModel(id: 'v', type: TrackType.video, index: 0, clips: [
        ClipModel(
            id: 'a',
            mediaPath: 'a.mp4',
            timelineStart: 0,
            duration: 2,
            sourceStart: 0,
            zIndex: 0)
      ])
    ], duration: 3);
    final plan = const MultiTrackFilterBuilder().build(
        const MultiTrackExportJob(timeline: trailing, outputPath: 'out.mp4'),
        encoder: 'libx264');
    expect(plan.filterGraph, isNot(contains('concat=')));
    expect(plan.duration, 3);
  });
  test('sequential optimization preserves the general text render contract',
      () {
    MultiTrackFilterPlan plan(double opacity) =>
        const MultiTrackFilterBuilder().build(
            MultiTrackExportJob(
                outputPath: 'out.mp4',
                timeline: TimelineModel(tracks: [
                  TrackModel(id: 'v', type: TrackType.video, index: 0, clips: [
                    ClipModel(
                        id: 'a',
                        mediaPath: 'same.mp4',
                        timelineStart: 0,
                        duration: 4,
                        sourceStart: 10,
                        zIndex: 0,
                        transform: ClipTransform(opacity: opacity)),
                  ])
                ], duration: 4),
                textOverlays: const [
                  TextOverlaySettings(
                    text: 'Title',
                    opacity: 0.45,
                    strokeOpacity: 0.6,
                    shadow: true,
                    shadowOpacity: 0.3,
                    timelineStart: 1,
                    timelineEnd: 3,
                  )
                ]),
            encoder: 'libx264');
    final sequential = plan(1).filterGraph;
    final general = plan(0.7).filterGraph;
    String textFilter(String graph) =>
        RegExp(r'drawtext=.*?(?=\[)').firstMatch(graph)!.group(0)!;
    expect(sequential, contains('concat='));
    expect(general, isNot(contains('concat=')));
    expect(textFilter(sequential), textFilter(general));
    expect(textFilter(sequential), contains('@0.45'));
    expect(textFilter(sequential), contains('@0.6'));
    expect(textFilter(sequential), contains('@0.3'));
    expect(textFilter(sequential), contains(r'gte(t\,1)*lt(t\,3)'));
  });
  test('3:4 contain then nonuniform scaling preserves both axes and pan', () {
    final box = VideoGeometry.resolve(
        canvasWidth: 900,
        canvasHeight: 1200,
        sourceWidth: 1600,
        sourceHeight: 900,
        scaleX: 1.2,
        scaleY: 0.8,
        positionX: 0.75,
        positionY: 0.25);
    expect(box.width, 1080);
    expect(box.height, 405);
    expect(box.left, -45);
    expect(box.top, 198.75);
    final small = VideoGeometry.resolve(
        canvasWidth: 300,
        canvasHeight: 400,
        sourceWidth: 1600,
        sourceHeight: 900,
        scaleX: 1.2,
        scaleY: 0.8,
        positionX: 0.75,
        positionY: 0.25);
    expect(small.left * 3, box.left);
    expect(small.top * 3, box.top);
    expect(small.width * 3, box.width);
    expect(small.height * 3, box.height);
  });

  test('export uses shared pan expression and excludes outgoing boundary', () {
    const transform = ClipTransform(
        scaleX: 1.2,
        scaleY: 0.8,
        positionX: 0.75,
        positionY: 0.25,
        opacity: 0.7,
        flip: 'up');
    const timeline = TimelineModel(tracks: [
      TrackModel(id: 'v', type: TrackType.video, index: 0, clips: [
        ClipModel(
            id: 'first',
            mediaPath: 'same.mp4',
            timelineStart: 0,
            duration: 2,
            sourceStart: 10,
            zIndex: 0,
            transform: transform),
        ClipModel(
            id: 'second',
            mediaPath: 'same.mp4',
            timelineStart: 2,
            duration: 3,
            sourceStart: 30,
            zIndex: 0,
            transform: transform),
      ]),
      TrackModel(id: 'music', type: TrackType.audio, index: 1, clips: [
        ClipModel(
            id: 'music',
            mediaPath: 'music.wav',
            timelineStart: 0,
            duration: 5,
            sourceStart: 1,
            zIndex: 0,
            volume: 0.4),
      ]),
    ], duration: 5);
    final plan = const MultiTrackFilterBuilder().build(
        const MultiTrackExportJob(
            timeline: timeline,
            outputPath: 'out.mp4',
            width: 900,
            height: 1200),
        encoder: 'libx264');
    expect(plan.videoInputCount, 2);
    expect(plan.audioInputCount, 1);
    expect(plan.arguments.where((v) => v == 'same.mp4').length, 2);
    expect(plan.filterGraph,
        contains('scale=900:1200:force_original_aspect_ratio=decrease'));
    expect(plan.filterGraph,
        contains('scale=trunc(iw*1.2/2)*2:trunc(ih*0.8/2)*2'));
    expect(plan.filterGraph,
        contains(VideoGeometry.offsetExpression('W', 'w', '0.75')));
    expect(plan.filterGraph,
        contains(VideoGeometry.offsetExpression('H', 'h', '0.25')));
    expect(plan.filterGraph, contains("enable='gte(t,0)*lt(t,2)'"));
    expect(plan.filterGraph, contains("enable='gte(t,2)*lt(t,5)'"));
    expect(plan.filterGraph, contains('hflip,vflip'));
    expect(plan.filterGraph, contains('colorchannelmixer=aa=0.7'));
    expect(plan.filterGraph, contains('volume=0.4'));
  });
}
