import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';
import 'package:klipio/features/composition/domain/render_scene.dart';
import 'package:klipio/features/editor/domain/video_render_settings.dart';
import 'package:klipio/features/editor/domain/video_target_selection.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  test('mixed video target expression selects the exact requested videos', () {
    final result = parseVideoTargetSelection('1,2,4 to 7,9,10', 10);

    expect(result.error, isNull);
    expect(result.indexes, <int>[0, 1, 3, 4, 5, 6, 8, 9]);
  });

  test('captured video settings apply to picture and linked source audio', () {
    const timeline = TimelineModel(
      tracks: <TrackModel>[
        TrackModel(
          id: 'v1',
          type: TrackType.video,
          index: 1,
          clips: <ClipModel>[
            ClipModel(
              id: 'video-a',
              mediaPath: 'a.mp4',
              timelineStart: 0,
              duration: 10,
              sourceStart: 0,
              zIndex: 0,
            ),
            ClipModel(
              id: 'video-b',
              mediaPath: 'b.mp4',
              timelineStart: 10,
              duration: 10,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'a1',
          type: TrackType.audio,
          index: 1,
          clips: <ClipModel>[
            ClipModel(
              id: 'audio-b',
              mediaPath: 'b.mp4',
              timelineStart: 10,
              duration: 10,
              sourceStart: 0,
              zIndex: 0,
              isLinkedAudio: true,
              linkedClipId: 'video-b',
            ),
            ClipModel(
              id: 'independent-audio-b',
              mediaPath: 'b.mp4',
              timelineStart: 0,
              duration: 5,
              sourceStart: 0,
              zIndex: 1,
              volume: 0.8,
            ),
          ],
        ),
      ],
      duration: 20,
    );
    const captured = VideoRenderSettings(
      mediaPath: 'b.mp4',
      speed: 1.5,
      originalVolume: 0.35,
      transform: ClipTransform(
        scaleX: 1.4,
        scaleY: 1.2,
        positionX: 0.3,
        positionY: 0.7,
        flip: 'left',
        canvasMode: 'blur',
        canvasBlur: 40,
      ),
    );

    final updated = applyVideoRenderSettings(
      timeline: timeline,
      settings: captured,
    );

    expect(updated.clipById('video-a')!.clip.transform.scaleX, 1);
    final video = updated.clipById('video-b')!.clip;
    expect(video.transform.scaleX, 1.4);
    expect(video.transform.scaleY, 1.2);
    expect(video.transform.positionX, 0.3);
    expect(video.transform.positionY, 0.7);
    expect(video.transform.canvasMode, 'blur');
    expect(video.transform.canvasBlur, 40);
    expect(updated.clipById('audio-b')!.clip.volume, 0.35);
    expect(updated.clipById('independent-audio-b')!.clip.volume, 0.8);
  });

  test('a newer apply snapshot replaces old values and preserves locks', () {
    const timeline = TimelineModel(
      tracks: <TrackModel>[
        TrackModel(
          id: 'video-unlocked',
          type: TrackType.video,
          index: 1,
          clips: <ClipModel>[
            ClipModel(
              id: 'target-unlocked',
              mediaPath: 'target.mp4',
              timelineStart: 0,
              duration: 5,
              sourceStart: 0,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'video-locked',
          type: TrackType.video,
          index: 2,
          isLocked: true,
          clips: <ClipModel>[
            ClipModel(
              id: 'target-locked',
              mediaPath: 'target.mp4',
              timelineStart: 0,
              duration: 5,
              sourceStart: 0,
              zIndex: 1,
            ),
          ],
        ),
      ],
      duration: 5,
    );
    const first = VideoRenderSettings(
      mediaPath: 'target.mp4',
      speed: 1,
      originalVolume: 1,
      transform: ClipTransform(scaleX: 1.2, canvasMode: 'color'),
    );
    const latest = VideoRenderSettings(
      mediaPath: 'target.mp4',
      speed: 1,
      originalVolume: 1,
      transform: ClipTransform(scaleX: 1.8, canvasMode: 'blur'),
    );

    final firstApply = applyVideoRenderSettings(
      timeline: timeline,
      settings: first,
    );
    final latestApply = applyVideoRenderSettings(
      timeline: firstApply,
      settings: latest,
    );

    expect(latestApply.clipById('target-unlocked')!.clip.transform.scaleX, 1.8);
    expect(
      latestApply.clipById('target-unlocked')!.clip.transform.canvasMode,
      'blur',
    );
    expect(latestApply.clipById('target-locked')!.clip.transform.scaleX, 1);
    expect(
      latestApply.clipById('target-locked')!.clip.transform.canvasMode,
      'none',
    );
  });

  test('exact clip sync preserves unrelated split and independent audio', () {
    const timeline = TimelineModel(
      tracks: <TrackModel>[
        TrackModel(
          id: 'v1',
          type: TrackType.video,
          index: 1,
          clips: <ClipModel>[
            ClipModel(
              id: 'source',
              mediaPath: 'source.mp4',
              timelineStart: 0,
              duration: 3,
              sourceStart: 0,
              zIndex: 0,
              transform: ClipTransform(scaleX: 1.8, rotationDegrees: 22),
            ),
            ClipModel(
              id: 'target-one',
              mediaPath: 'target.mp4',
              timelineStart: 3,
              duration: 3,
              sourceStart: 0,
              zIndex: 0,
            ),
            ClipModel(
              id: 'target-other-split',
              mediaPath: 'target.mp4',
              timelineStart: 6,
              duration: 3,
              sourceStart: 3,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'a1',
          type: TrackType.audio,
          index: 1,
          clips: <ClipModel>[
            ClipModel(
              id: 'target-one-audio',
              mediaPath: 'target.mp4',
              timelineStart: 3,
              duration: 3,
              sourceStart: 0,
              zIndex: 0,
              isLinkedAudio: true,
              linkedClipId: 'target-one',
            ),
            ClipModel(
              id: 'music',
              mediaPath: 'target.mp4',
              timelineStart: 0,
              duration: 9,
              sourceStart: 0,
              zIndex: 0,
              volume: 0.9,
            ),
          ],
        ),
      ],
      duration: 9,
    );
    const settings = VideoRenderSettings(
      mediaPath: 'source.mp4',
      speed: 1.5,
      originalVolume: 0.25,
      transform: ClipTransform(scaleX: 1.8, rotationDegrees: 22),
    );

    final updated = applyVideoRenderSettingsToClipIds(
      timeline: timeline,
      settings: settings,
      targetClipIds: const {'target-one'},
    );

    expect(updated.clipById('target-one')!.clip.transform.scaleX, 1.8);
    expect(updated.clipById('target-one')!.clip.transform.rotationDegrees, 22);
    expect(updated.clipById('target-one-audio')!.clip.volume, 0.25);
    expect(updated.clipById('target-other-split')!.clip.transform.scaleX, 1);
    expect(updated.clipById('music')!.clip.volume, 0.9);
  });

  test('one render snapshot drives per-video preview and export timing', () {
    const timeline = TimelineModel(
      tracks: <TrackModel>[
        TrackModel(
          id: 'v1',
          type: TrackType.video,
          index: 1,
          clips: <ClipModel>[
            ClipModel(
              id: 'video-a',
              mediaPath: 'a.mp4',
              timelineStart: 0,
              duration: 10,
              sourceStart: 0,
              zIndex: 0,
            ),
            ClipModel(
              id: 'video-b',
              mediaPath: 'b.mp4',
              timelineStart: 10,
              duration: 20,
              sourceStart: 3,
              zIndex: 0,
            ),
          ],
        ),
        TrackModel(
          id: 'a1',
          type: TrackType.audio,
          index: 1,
          clips: <ClipModel>[
            ClipModel(
              id: 'audio-a',
              mediaPath: 'a.mp4',
              timelineStart: 0,
              duration: 10,
              sourceStart: 0,
              zIndex: 0,
              volume: 0.4,
              isLinkedAudio: true,
              linkedClipId: 'video-a',
            ),
            ClipModel(
              id: 'audio-b',
              mediaPath: 'b.mp4',
              timelineStart: 10,
              duration: 20,
              sourceStart: 3,
              zIndex: 0,
              volume: 0.7,
              isLinkedAudio: true,
              linkedClipId: 'video-b',
            ),
          ],
        ),
      ],
      duration: 30,
    );

    final snapshot = ProgramRenderSnapshot.build(
      sourceTimeline: timeline,
      playbackSpeedsByMediaPath: const <String, double>{
        'a.mp4': 2,
        'b.mp4': 0.5,
      },
    );

    expect(snapshot.outputTimeline.clipById('video-a')!.clip.duration, 5);
    expect(snapshot.outputTimeline.clipById('video-b')!.clip.timelineStart, 5);
    expect(snapshot.outputTimeline.clipById('video-b')!.clip.duration, 40);
    expect(snapshot.outputTimeline.duration, 45);
    expect(snapshot.playbackForClip('video-a')!.speed, 2);
    expect(snapshot.playbackForClip('video-a')!.volume, 0.4);
    expect(snapshot.playbackForClip('video-b')!.speed, 0.5);
    expect(snapshot.playbackForClip('video-b')!.volume, 0.7);
    final scene = snapshot.resolve(
      composition: const CompositionModel(
        width: 1080,
        height: 1920,
        frameRate: 30,
      ),
      timelineSeconds: 6,
    );
    expect(scene.clips.single.clipId, 'video-b');
    expect(scene.clips.single.sourceSeconds, 3.5);
  });
}
