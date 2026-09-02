import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/timeline/application/timeline_editor.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

const editor = TimelineEditor();

TimelineModel lockedFixture({bool secondary = false}) {
  ClipModel clip(String id, double start, {bool linked = false}) => ClipModel(
        id: id,
        mediaPath: 'reused.mp4',
        timelineStart: start,
        duration: 1,
        sourceStart: 0,
        zIndex: 0,
        isLinkedAudio: linked,
        linkedClipId: linked ? 'b' : null,
      );
  return TimelineModel(duration: 5, tracks: [
    TrackModel(
        id: 'video-1',
        type: TrackType.video,
        index: 1,
        clips: [clip('a', 0), if (!secondary) clip('b', 1)]),
    if (secondary)
      TrackModel(
          id: 'video-2',
          type: TrackType.video,
          index: 2,
          clips: [clip('b', 1)]),
    TrackModel(
        id: 'audio-1',
        type: TrackType.audio,
        index: 1,
        isLocked: true,
        clips: [clip('linked-b', 1, linked: true)]),
  ]);
}

void main() {
  test('ripple anchoring distinguishes arithmetic noise from real early starts',
      () {
    final base = lockedFixture();
    final independent = base.copyWith(tracks: [
      base.tracks.first,
      TrackModel(id: 'audio-1', type: TrackType.audio, index: 1, clips: [
        for (final entry in <String, double>{
          'early': .999,
          'noise': 1 - 1e-15,
          'exact': 1,
          'gap': 1.001,
        }.entries)
          ClipModel(
              id: entry.key,
              mediaPath: 'same.wav',
              timelineStart: entry.value,
              sourceStart: 0,
              duration: .2,
              zIndex: 0),
      ]),
    ]);
    final result = editor.deleteClip(independent, 'a');
    expect(result.clipById('early')!.clip.timelineStart, .999);
    expect(result.clipById('noise')!.clip.timelineStart, 0);
    expect(result.clipById('exact')!.clip.timelineStart, 0);
    // A real gap is preserved through the operation, not snapped closed.
    expect(result.clipById('gap')!.clip.timelineStart, closeTo(.001, 1e-15));
  });
  test('group drag rejects locked companions before moving any selection', () {
    final original = lockedFixture();
    expect(
        editor.moveClips(original,
            clipIds: {'a', 'b'},
            anchorClipId: 'a',
            targetTrackId: 'video-1',
            timelineStart: 2,
            snap: false),
        same(original));
    final unlocked = original.copyWith(tracks: [
      for (final track in original.tracks) track.copyWith(isLocked: false),
    ]);
    for (final anchor in ['b', 'linked-b']) {
      final moved = editor.moveClips(unlocked,
          clipIds: {'a', 'b', 'linked-b'},
          anchorClipId: anchor,
          targetTrackId: anchor == 'b' ? 'video-1' : 'audio-1',
          timelineStart: 3,
          snap: false);
      expect(moved.clipById('a')!.clip.timelineStart, 2);
      expect(moved.clipById('b')!.clip.timelineStart, 3);
      expect(moved.clipById('linked-b')!.clip.timelineStart, 3);
    }
  });
  for (final secondary in [false, true]) {
    test('linked lock rejects whole transaction on V${secondary ? 2 : 1}', () {
      final original = lockedFixture(secondary: secondary);
      final operations = <String, TimelineModel Function()>{
        'delete owner': () => editor.deleteClip(original, 'b'),
        'trim start': () => editor.resizeClip(original,
            clipId: 'b', startEdge: true, deltaSeconds: .25),
        'trim end': () => editor.resizeClip(original,
            clipId: 'b', startEdge: false, deltaSeconds: -.25),
        'move': () => editor.moveClip(original,
            clipId: 'b',
            targetTrackId: secondary ? 'video-2' : 'video-1',
            timelineStart: 3,
            snap: false),
        'split': () => editor.splitClip(original, clipId: 'b', playhead: 1.5),
        ...{
          'delete before': () => editor.deleteClip(original, 'a'),
          'trim before': () => editor.resizeClip(original,
              clipId: 'a', startEdge: false, deltaSeconds: -.25),
          'insert before': () => editor.insertClip(original,
              trackId: 'video-1',
              clip: const ClipModel(
                  id: 'insert',
                  mediaPath: 'reused.mp4',
                  timelineStart: 0,
                  duration: .25,
                  sourceStart: 0,
                  zIndex: 0)),
        },
      };
      for (final entry in operations.entries) {
        expect(entry.value(), same(original), reason: entry.key);
      }
    });
  }
}
