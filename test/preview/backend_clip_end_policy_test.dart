import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/preview/engine/backend_clip_end_policy.dart';
import 'package:klipio/features/preview/engine/program_timeline_mapper.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

bool advance(double position,
        {bool playing = true,
        bool pending = false,
        bool error = false,
        double start = 10,
        double end = 20}) =>
    BackendClipEndPolicy.shouldAdvance(
        sourceSeconds: position,
        sourceStart: start,
        sourceEnd: end,
        isPlaying: playing,
        hasError: error,
        seekPending: pending);

void main() {
  test('historical source lookahead is isolated from exact clip end', () {
    expect(advance(19.899), isFalse);
    expect(advance(19.9), isTrue);
    expect(advance(19.999), isTrue);
    expect(advance(20), isTrue);
    expect(advance(9.999), isFalse);
  });
  test('completion before or after threshold cannot advance a stopped player',
      () {
    // Completion notification stops playback. It does not override position
    // or resurrect a playback intent, regardless of notification timing.
    for (final position in [19.8, 19.9, 20.0]) {
      expect(advance(position, playing: false), isFalse);
    }
  });
  test('loop wrap is not completion; missed end tick remains a backend risk',
      () {
    expect(advance(19.8), isFalse);
    expect(advance(0), isFalse);
    expect(advance(19.95), isTrue);
  });
  test('stale completion during seek and player error cannot advance', () {
    expect(advance(20, pending: true), isFalse);
    expect(advance(20, error: true), isFalse);
    expect(advance(double.nan), isFalse);
    expect(advance(9.98, start: 10, end: 10.05), isFalse);
  });
  test('same source, speeds, adjacency and gaps keep exact program semantics',
      () {
    for (final speed in [0.5, 1.0, 2.0, 4.0]) {
      for (final gap in [0.0, 1.0]) {
        final end = 10 / speed;
        final a = ClipModel(
            id: 'a',
            mediaPath: 'same.mp4',
            timelineStart: 0,
            duration: end,
            sourceStart: 10,
            zIndex: 0);
        final b =
            a.copyWith(id: 'b', timelineStart: end + gap, sourceStart: 30);
        final timeline = TimelineModel(tracks: [
          TrackModel(id: 'v', type: TrackType.video, index: 1, clips: [a, b])
        ], duration: end * 2 + gap);
        final target = ProgramTimelineMapper.resolve(
            timeline, end - 0.05 / speed,
            playbackSpeedsByMediaPath: {'same.mp4': speed});
        expect(target.clip!.id, 'a');
        expect(advance(target.sourceSeconds!), isTrue);
        final boundary = ProgramTimelineMapper.resolve(timeline, end);
        expect(boundary.isGap, gap > 0);
        if (gap == 0) expect(boundary.clip!.id, 'b');
        expect(
            ProgramTimelineMapper.resolve(timeline, end + gap).clip!.id, 'b');
      }
    }
  });
}
