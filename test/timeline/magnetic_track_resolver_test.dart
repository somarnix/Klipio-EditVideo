import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/timeline/domain/magnetic_track_resolver.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  const resolver = MagneticTrackResolver();

  TimelineModel fixture() => const TimelineModel(
        tracks: <TrackModel>[
          TrackModel(
            id: 'video-1',
            type: TrackType.video,
            index: 1,
            clips: <ClipModel>[
              ClipModel(
                id: 'a',
                mediaPath: 'a.mp4',
                timelineStart: 0,
                duration: 5,
                sourceStart: 2,
                zIndex: 0,
              ),
              ClipModel(
                id: 'b',
                mediaPath: 'b.mp4',
                timelineStart: 5,
                duration: 4,
                sourceStart: 0,
                zIndex: 0,
              ),
            ],
          ),
          TrackModel(
            id: 'audio-1',
            type: TrackType.audio,
            index: 1,
            clips: <ClipModel>[
              ClipModel(
                id: 'audio-a',
                mediaPath: 'a.mp4',
                timelineStart: 0,
                duration: 5,
                sourceStart: 2,
                zIndex: 0,
                isLinkedAudio: true,
                linkedClipId: 'a',
              ),
              ClipModel(
                id: 'audio-b',
                mediaPath: 'b.mp4',
                timelineStart: 5,
                duration: 4,
                sourceStart: 0,
                zIndex: 0,
                isLinkedAudio: true,
                linkedClipId: 'b',
              ),
            ],
          ),
          TrackModel(
            id: 'text-1',
            type: TrackType.text,
            index: 1,
            clips: <ClipModel>[
              ClipModel(
                id: 'title',
                mediaPath: 'title',
                timelineStart: 6,
                duration: 1,
                sourceStart: 0,
                zIndex: 0,
              ),
            ],
          ),
        ],
        duration: 9,
      );

  test('ripple end trim closes primary, linked audio, and anchored layers', () {
    final result = resolver.rippleTrim(
      timeline: fixture(),
      clipId: 'a',
      deltaDuration: const Duration(seconds: 2),
      edge: TrimEdge.end,
    );

    expect(result.clipById('a')!.clip.duration, 3);
    expect(result.clipById('audio-a')!.clip.duration, 3);
    expect(result.clipById('b')!.clip.timelineStart, 3);
    expect(result.clipById('audio-b')!.clip.timelineStart, 3);
    expect(result.clipById('title')!.clip.timelineStart, 4);
    expect(result.duration, 7);
  });

  test('ripple start trim advances source without leaving a gap', () {
    final result = resolver.rippleTrim(
      timeline: fixture(),
      clipId: 'a',
      deltaDuration: const Duration(seconds: 1),
      edge: TrimEdge.start,
    );

    expect(result.clipById('a')!.clip.timelineStart, 0);
    expect(result.clipById('a')!.clip.sourceStart, 3);
    expect(result.clipById('a')!.clip.duration, 4);
    expect(result.clipById('b')!.clip.timelineStart, 4);
  });

  test('ripple delete removes linked media and closes the story', () {
    final result = resolver.rippleDelete(timeline: fixture(), clipId: 'a');

    expect(result.clipById('a'), isNull);
    expect(result.clipById('audio-a'), isNull);
    expect(result.clipById('b')!.clip.timelineStart, 0);
    expect(result.clipById('audio-b')!.clip.timelineStart, 0);
    expect(result.clipById('title')!.clip.timelineStart, 1);
    expect(result.duration, 4);
  });

  test('ripple insert pushes primary and anchored layers right', () {
    const inserted = ClipModel(
      id: 'inserted',
      mediaPath: 'inserted.mp4',
      timelineStart: 99,
      duration: 2,
      sourceStart: 0,
      zIndex: 0,
    );
    final result = resolver.rippleInsert(
      timeline: fixture(),
      clip: inserted,
      insertIndex: 1,
    );

    expect(result.clipById('inserted')!.clip.timelineStart, 5);
    expect(result.clipById('b')!.clip.timelineStart, 7);
    expect(result.clipById('audio-b')!.clip.timelineStart, 7);
    expect(result.clipById('title')!.clip.timelineStart, 8);
    expect(result.duration, 11);
  });
}
