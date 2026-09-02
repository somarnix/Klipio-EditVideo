import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';
import 'package:klipio/features/timeline/domain/detach_audio_edit.dart';
import 'package:klipio/features/timeline/domain/clip_speed_edit.dart';
import 'package:klipio/features/timeline/application/timeline_editor.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';

void main() {
  TimelineModel fixture({bool locked = false}) =>
      TimelineModel(duration: 4, tracks: [
        const TrackModel(id: 'v', type: TrackType.video, index: 0, clips: [
          ClipModel(
              id: 'v0',
              mediaPath: 'same.wav',
              timelineStart: 0,
              sourceStart: 0,
              duration: 1,
              zIndex: 0,
              playbackSpeed: .5),
          ClipModel(
              id: 'v1',
              mediaPath: 'same.wav',
              timelineStart: 1,
              sourceStart: 2,
              duration: 1,
              zIndex: 0,
              playbackSpeed: 2)
        ]),
        TrackModel(
            id: 'a',
            type: TrackType.audio,
            index: 0,
            isLocked: locked,
            clips: const [
              ClipModel(
                  id: 'a0',
                  mediaPath: 'same.wav',
                  timelineStart: 0,
                  sourceStart: 0,
                  duration: 1,
                  zIndex: 0,
                  isLinkedAudio: true,
                  linkedClipId: 'v0'),
              ClipModel(
                  id: 'a1',
                  mediaPath: 'same.wav',
                  timelineStart: 1,
                  sourceStart: 2,
                  duration: 1,
                  zIndex: 0,
                  isLinkedAudio: true,
                  linkedClipId: 'v1',
                  volume: .3)
            ])
      ]);
  ProgramRenderSnapshot snapshot(TimelineModel model) =>
      ProgramRenderSnapshot.build(
          sourceTimeline: model, playbackSpeedsByMediaPath: const {});
  test('detach freezes program placement and survives video edits and reopen',
      () {
    final original = fixture();
    final expected = snapshot(original).outputTimeline.clipById('a1')!.clip;
    expect(expected.timelineStart, 2);
    expect(expected.duration, .5);
    var model = DetachAudioEdit.apply(original, 'v1', 'detached');
    final detached = model.clipById('detached')!.clip;
    expect(detached.playbackSpeed, 2);
    expect(detached.isLinkedAudio, isFalse);
    expect(detached.linkedClipId, isNull);
    model = ClipSpeedEdit.apply(model, {'v1'}, .5);
    model = const TimelineEditor().moveClip(model,
        clipId: 'v1', targetTrackId: 'v', timelineStart: 5, snap: false);
    model = const TimelineEditor().deleteClip(model, 'v1');
    model = TimelineModel.fromJson(jsonDecode(jsonEncode(model.toJson())));
    expect(model.clipById('detached')!.clip.toJson(), detached.toJson());
    final output = snapshot(model).outputTimeline.clipById('detached')!.clip;
    expect(output.timelineStart, expected.timelineStart);
    expect(output.duration, expected.duration);
    expect(output.sourceStart, expected.sourceStart);
    expect(output.volume, .3);
    expect(snapshot(original).outputTimeline.clipById('a1')!.clip.toJson(),
        expected.toJson());
  });
  test('locked linked audio rejects detach atomically', () {
    final model = fixture(locked: true);
    expect(DetachAudioEdit.apply(model, 'v1', 'detached'), same(model));
  });
}
