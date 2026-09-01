import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/preview/engine/program_timeline_mapper.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  group('ProgramTimelineMapper', () {
    test('uses final 10:06 program after a 7:48 hook boundary', () {
      final model = _timeline([
        _clip(
          id: 'hook-result',
          path: 'source.mp4',
          timelineStart: 0,
          duration: 468,
          sourceStart: 60,
        ),
        _clip(
          id: 'later-edit',
          path: 'source.mp4',
          timelineStart: 468,
          duration: 138,
          sourceStart: 900,
        ),
      ]);

      expect(ProgramTimelineMapper.duration(model), 606);
      final target = ProgramTimelineMapper.resolve(model, 480);
      expect(target.isGap, isFalse);
      expect(target.clip?.id, 'later-edit');
      expect(target.timelineSeconds, 480);
      expect(target.sourceSeconds, 912);
    });

    test('maps reordered A B A clips from program time to source time', () {
      final model = _timeline([
        _clip(
          id: 'a-first',
          path: 'a.mp4',
          timelineStart: 0,
          duration: 180,
          sourceStart: 20,
        ),
        _clip(
          id: 'b',
          path: 'b.mp4',
          timelineStart: 180,
          duration: 180,
          sourceStart: 300,
        ),
        _clip(
          id: 'a-later',
          path: 'a.mp4',
          timelineStart: 360,
          duration: 246,
          sourceStart: 900,
        ),
      ]);

      final target = ProgramTimelineMapper.resolve(model, 480);
      expect(target.clip?.id, 'a-later');
      expect(target.sourceSeconds, 1020);
      expect(
        ProgramTimelineMapper.timelineSecondsForSource(
          clip: target.clip!,
          sourceSeconds: target.sourceSeconds!,
        ),
        480,
      );
    });

    test('preserves non-zero timelineStart in both directions', () {
      final clip = _clip(
        id: 'non-zero',
        path: 'source.mp4',
        timelineStart: 480,
        duration: 60,
        sourceStart: 900,
      );
      final target = ProgramTimelineMapper.resolve(_timeline([clip]), 500);

      expect(target.sourceSeconds, 920);
      expect(
        ProgramTimelineMapper.timelineSecondsForSource(
          clip: clip,
          sourceSeconds: 920,
        ),
        500,
      );
    });

    test('returns an explicit gap instead of jumping to another clip', () {
      final first = _clip(
        id: 'first',
        path: 'a.mp4',
        timelineStart: 0,
        duration: 10,
        sourceStart: 100,
      );
      final second = _clip(
        id: 'second',
        path: 'b.mp4',
        timelineStart: 20,
        duration: 10,
        sourceStart: 500,
      );
      final model = _timeline([first, second]);

      final target = ProgramTimelineMapper.resolve(model, 15);
      expect(target.isGap, isTrue);
      expect(target.clip, isNull);
      expect(target.sourceSeconds, isNull);
      expect(target.timelineSeconds, 15);
      expect(
        ProgramTimelineMapper.nextPlayableVideoClip(
          model,
          atOrAfterTimelineSeconds: 15,
        )?.id,
        'second',
      );
    });

    test('switches clips cleanly at a cut boundary', () {
      final model = _timeline([
        _clip(
          id: 'before',
          path: 'a.mp4',
          timelineStart: 0,
          duration: 10,
          sourceStart: 100,
        ),
        _clip(
          id: 'after',
          path: 'b.mp4',
          timelineStart: 10,
          duration: 10,
          sourceStart: 500,
        ),
      ]);

      expect(ProgramTimelineMapper.resolve(model, 9.9).clip?.id, 'before');
      final after = ProgramTimelineMapper.resolve(model, 10.1);
      expect(after.clip?.id, 'after');
      expect(after.sourceSeconds, closeTo(500.1, 0.0001));
    });

    test('seeks around the old hook end without falling back to legacy edits',
        () {
      final model = _timeline([
        _clip(
          id: 'hook',
          path: 'source.mp4',
          timelineStart: 0,
          duration: 468,
          sourceStart: 0,
        ),
        _clip(
          id: 'extended',
          path: 'source.mp4',
          timelineStart: 468,
          duration: 138,
          sourceStart: 1000,
        ),
      ]);

      for (final seconds in [467.0, 469.0, 480.0, 570.0, 600.0]) {
        final target = ProgramTimelineMapper.resolve(model, seconds);
        expect(target.isGap, isFalse, reason: 'Program time $seconds');
        expect(target.timelineSeconds, seconds);
      }
    });
  });
}

TimelineModel _timeline(List<ClipModel> clips) {
  final tracks = [
    TrackModel(
      id: 'video-1',
      type: TrackType.video,
      index: 1,
      clips: clips,
    ),
  ];
  return TimelineModel(
    tracks: tracks,
    duration: TimelineModel.calculateDuration(tracks),
  );
}

ClipModel _clip({
  required String id,
  required String path,
  required double timelineStart,
  required double duration,
  required double sourceStart,
}) {
  return ClipModel(
    id: id,
    mediaPath: path,
    timelineStart: timelineStart,
    duration: duration,
    sourceStart: sourceStart,
    zIndex: 0,
  );
}
