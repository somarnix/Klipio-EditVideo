import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/editor/domain/video_render_settings.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  final timeline = TimelineModel(duration: 100, tracks: [
    TrackModel(id: 'video', type: TrackType.video, index: 1, clips: [
      for (var i = 0; i < 10; i++)
        ClipModel(
            id: 'v$i',
            mediaPath: 'asset$i.mp4',
            timelineStart: i * 10,
            duration: 10,
            sourceStart: 0,
            zIndex: 0,
            playbackSpeed: 1),
    ]),
    TrackModel(id: 'audio', type: TrackType.audio, index: 1, clips: [
      for (var i = 0; i < 10; i++)
        ClipModel(
            id: 'a$i',
            mediaPath: 'asset$i.mp4',
            timelineStart: i * 10,
            duration: 10,
            sourceStart: 0,
            zIndex: 0,
            playbackSpeed: 1,
            isLinkedAudio: true,
            linkedClipId: 'v$i'),
      const ClipModel(
          id: 'detached',
          mediaPath: 'asset0.mp4',
          timelineStart: 5,
          duration: 10,
          sourceStart: 0,
          zIndex: 0,
          playbackSpeed: .5),
    ]),
  ]);
  const settings = VideoRenderSettings(
      mediaPath: 'asset0.mp4',
      speed: 1.15,
      originalVolume: .4,
      transform: ClipTransform(
          scaleX: 2,
          scaleY: 3,
          opacity: .7,
          rotationDegrees: 45,
          canvasMode: 'blur',
          canvasBlur: 30));
  TimelineModel? apply(TimelineModel model,
          {bool speed = true,
          bool audio = true,
          bool frame = true,
          bool canvas = true}) =>
      applyVideoSettingsBatch(
          timeline: model,
          settings: settings,
          targetClipIds: {for (var i = 0; i < 10; i++) 'v$i'},
          copySpeed: speed,
          copyAudio: audio,
          copyFrame: frame,
          copyCanvas: canvas);

  test('ten-video batch copies canonical speed, full transform and companions',
      () {
    final next = apply(timeline)!;
    for (var i = 0; i < 10; i++) {
      final clip = next.clipById('v$i')!.clip;
      expect(clip.playbackSpeed, 1.15);
      expect(clip.duration, 10);
      expect(clip.transform.opacity, .7);
      expect(clip.transform.rotationDegrees, 45);
      expect(clip.transform.scaleY, 3);
      expect(clip.transform.canvasMode, 'blur');
      expect(next.clipById('a$i')!.clip.playbackSpeed, 1.15);
      expect(next.clipById('a$i')!.clip.volume, .4);
    }
    expect(next.clipById('detached')!.clip.playbackSpeed, .5);
    expect(timeline.clipById('v0')!.clip.playbackSpeed, 1);
    final reloaded = TimelineModel.fromJson(next.toJson());
    expect(reloaded.clipById('v9')!.clip.transform.opacity, .7);
    expect(reloaded.clipById('a9')!.clip.playbackSpeed, 1.15);
  });

  test(
      'checkboxes preserve unchecked settings and locked companion rejects atomically',
      () {
    final locked = timeline.copyWith(tracks: [
      timeline.tracks[0],
      timeline.tracks[1].copyWith(isLocked: true)
    ]);
    expect(apply(locked), isNull);
    expect(locked.clipById('v0')!.clip.playbackSpeed, 1);
    final frameOnly = apply(locked, speed: false, audio: false, canvas: false)!;
    expect(frameOnly.clipById('v0')!.clip.transform.scaleX, 2);
    expect(frameOnly.clipById('v0')!.clip.transform.canvasMode, 'none');
    expect(frameOnly.clipById('a0')!.clip.volume, 1);
    final speedOnly =
        apply(timeline, frame: false, audio: false, canvas: false)!;
    expect(speedOnly.clipById('v0')!.clip.transform.scaleX, 1);
    expect(speedOnly.clipById('a0')!.clip.playbackSpeed, 1.15);
    expect(speedOnly.clipById('a0')!.clip.volume, 1);
  });
}
