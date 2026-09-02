import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

const video = ClipModel(
  id: 'video',
  mediaPath: 'shared.mp4',
  timelineStart: 0,
  duration: 10,
  sourceStart: 0,
  zIndex: 0,
);

ProgramRenderSnapshot capture(List<ClipModel> audio) =>
    ProgramRenderSnapshot.build(
      sourceTimeline: TimelineModel(tracks: [
        const TrackModel(
            id: 'v', type: TrackType.video, index: 1, clips: [video]),
        TrackModel(id: 'a', type: TrackType.audio, index: 1, clips: audio),
      ], duration: 10),
      playbackSpeedsByMediaPath: {},
    );

void main() {
  test('invalid saved speeds recover to normal playback', () {
    for (final invalid in [
      double.nan,
      double.infinity,
      double.negativeInfinity
    ]) {
      final snapshot = ProgramRenderSnapshot.build(
        sourceTimeline: const TimelineModel(tracks: [
          TrackModel(id: 'v', type: TrackType.video, index: 1, clips: [video]),
        ], duration: 10),
        playbackSpeedsByMediaPath: {'shared.mp4': invalid},
      );
      expect(snapshot.speedForMedia('shared.mp4'), 1);
      expect(snapshot.outputTimeline.duration, 10);
    }
  });
  test('explicit audio link never leaks to another use of the same file', () {
    final audio = video.copyWith(
        id: 'audio',
        isLinkedAudio: true,
        linkedClipId: 'other-video',
        volume: 0.2);
    expect(capture([audio]).playbackForClip('video')!.volume, 1);
    expect(
        capture([audio.copyWith(linkedClipId: 'video')])
            .playbackForClip('video')!
            .volume,
        0.2);
  });

  test('legacy audio requires a unique matching source and timeline range', () {
    final audio = video.copyWith(id: 'audio', isLinkedAudio: true, volume: 0.3);
    expect(capture([audio]).playbackForClip('video')!.volume, 0.3);
    expect(
        capture([audio.copyWith(sourceStart: 20)])
            .playbackForClip('video')!
            .volume,
        1);
    expect(
        capture([audio, audio.copyWith(id: 'duplicate')])
            .playbackForClip('video')!
            .volume,
        1);
  });

  test('snapshot owns immutable collections independent of editor state', () {
    final effects = <ClipEffect>[];
    final keyframes = <ClipKeyframe>[];
    final clips = [video.copyWith(effects: effects, keyframes: keyframes)];
    final tracks = [
      TrackModel(id: 'v', type: TrackType.video, index: 1, clips: clips)
    ];
    final snapshot = ProgramRenderSnapshot.build(
      sourceTimeline: TimelineModel(tracks: tracks, duration: 10),
      playbackSpeedsByMediaPath: {},
    );
    keyframes.add(const ClipKeyframe(offset: 1, transform: ClipTransform()));
    clips.clear();
    tracks.clear();
    expect(snapshot.sourceTimeline.clipById('video'), isNotNull);
    expect(snapshot.sourceTimeline.clipById('video')!.clip.keyframes, isEmpty);
    for (final timeline in [snapshot.sourceTimeline, snapshot.outputTimeline]) {
      expect(() => timeline.tracks.clear(), throwsUnsupportedError);
      expect(
          () => timeline.tracks.single.clips.clear(), throwsUnsupportedError);
      final clip = timeline.clipById('video')!.clip;
      expect(() => clip.effects.clear(), throwsUnsupportedError);
      expect(() => clip.keyframes.clear(), throwsUnsupportedError);
    }
  });
}
