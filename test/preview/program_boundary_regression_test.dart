import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/preview/engine/program_timeline_mapper.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:klipio/features/composition/domain/render_scene.dart';

void main() {
  const first = ClipModel(
      id: 'a',
      mediaPath: 'same.mp4',
      timelineStart: 1,
      duration: 2,
      sourceStart: 10,
      zIndex: 0);
  final second = first.copyWith(id: 'b', timelineStart: 3, sourceStart: 50);
  final model = TimelineModel(tracks: [
    TrackModel(id: 'v', type: TrackType.video, index: 1, clips: [first, second])
  ], duration: 5);

  test('program mapping agrees with render scene at exact cut boundaries', () {
    for (final time in [0.9999, 1.0, 2.9999, 3.0, 4.9999, 5.0]) {
      const speeds = {'same.mp4': 2.0};
      final target = ProgramTimelineMapper.resolve(model, time,
          playbackSpeedsByMediaPath: speeds);
      final scene = RenderSceneResolver.resolve(
          timeline: model,
          composition:
              const CompositionModel(width: 1080, height: 1440, frameRate: 30),
          timelineSeconds: time,
          playbackSpeedsByMediaPath: speeds);
      if (target.isGap) {
        expect(scene.clips, isEmpty);
      } else {
        expect(scene.clips.single.clipId, target.clip!.id);
        expect(scene.clips.single.sourceSeconds, target.sourceSeconds);
      }
    }
  });

  test('half-open boundaries preserve submillisecond final positions', () {
    expect(ProgramTimelineMapper.resolve(model, 0.9999).isGap, isTrue);
    expect(ProgramTimelineMapper.resolve(model, 1).clip!.id, 'a');
    expect(ProgramTimelineMapper.resolve(model, 2.9999).clip!.id, 'a');
    expect(ProgramTimelineMapper.resolve(model, 3).clip!.id, 'b');
    expect(ProgramTimelineMapper.resolve(model, 5).isGap, isTrue);
  });
  test('retimed source mapping does not freeze halfway through fast clips', () {
    for (final speed in [0.5, 1.0, 2.0, 4.0]) {
      for (final time in [1.0, 2.0, 2.9999]) {
        final resolved = ProgramTimelineMapper.resolve(model, time,
            playbackSpeedsByMediaPath: {'same.mp4': speed});
        expect(resolved.sourceSeconds, closeTo(10 + (time - 1) * speed, 1e-9));
        expect(
            ProgramTimelineMapper.timelineSecondsForSource(
                clip: first,
                sourceSeconds: resolved.sourceSeconds!,
                playbackSpeed: speed),
            closeTo(time, 1e-9));
      }
    }
    expect(
        ProgramTimelineMapper.resolve(model, 3,
            playbackSpeedsByMediaPath: {'same.mp4': 2}).sourceSeconds,
        50);
  });
  test('next clip lookup never reaches backwards across a gap', () {
    expect(
        ProgramTimelineMapper.nextPlayableVideoClip(model,
            atOrAfterTimelineSeconds: 3.01),
        isNull);
    expect(
        ProgramTimelineMapper.nextPlayableVideoClip(model,
                atOrAfterTimelineSeconds: 2.5)!
            .id,
        'b');
  });
}
