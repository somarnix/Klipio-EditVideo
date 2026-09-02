import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';

void main() {
  test(
      'keyframe boundaries and speed retiming preserve interpolated transforms',
      () {
    const clip = ClipModel(
        id: 'a',
        mediaPath: 'source.mp4',
        timelineStart: 0,
        duration: 4,
        sourceStart: 10,
        zIndex: 0,
        playbackSpeed: 2,
        keyframes: [
          ClipKeyframe(
              offset: 1,
              transform: ClipTransform(
                  scaleX: 1,
                  scaleY: 2,
                  positionX: 0.2,
                  rotationDegrees: -90,
                  opacity: 0.2)),
          ClipKeyframe(
              offset: 3,
              transform: ClipTransform(
                  scaleX: 2,
                  scaleY: 1,
                  positionX: 0.8,
                  rotationDegrees: 90,
                  opacity: 0.8)),
        ]);
    final snapshot = ProgramRenderSnapshot.build(
        sourceTimeline: const TimelineModel(tracks: [
          TrackModel(id: 'v', type: TrackType.video, index: 0, clips: [clip])
        ], duration: 4),
        playbackSpeedsByMediaPath: const {});
    final output = snapshot.outputTimeline.clipById('a')!.clip;
    for (final sourceLocal in [0.0, 1.0, 1.5, 2.0, 3.0, 3.5]) {
      expect(output.transformAt(sourceLocal / 2).toJson(),
          clip.transformAt(sourceLocal).toJson());
    }
    expect(clip.transformAt(2).scaleX, 1.5);
    expect(clip.transformAt(2).scaleY, 1.5);
    expect(clip.transformAt(2).rotationDegrees, 0);
    expect(clip.transformAt(2).opacity, 0.5);
  });

  test('submillisecond keyframe segments are not stretched to one millisecond',
      () {
    const clip = ClipModel(
        id: 'a',
        mediaPath: 'a',
        timelineStart: 0,
        duration: 1,
        sourceStart: 0,
        zIndex: 0,
        keyframes: [
          ClipKeyframe(offset: 0, transform: ClipTransform(opacity: 0)),
          ClipKeyframe(offset: 0.0002, transform: ClipTransform(opacity: 1)),
        ]);
    expect(clip.transformAt(0.0001).opacity, closeTo(0.5, 1e-10));
  });
}
