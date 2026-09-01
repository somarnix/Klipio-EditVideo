import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/timeline/application/timeline_controller.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  test('controller clamps seek and adds dynamic tracks', () {
    final controller = TimelineController(
      timeline: const TimelineModel(
        duration: 10,
        tracks: [
          TrackModel(
            id: 'video-1',
            type: TrackType.video,
            index: 1,
            clips: [
              ClipModel(
                id: 'clip-1',
                mediaPath: 'clip.mp4',
                timelineStart: 0,
                duration: 10,
                sourceStart: 0,
                zIndex: 0,
              ),
            ],
          ),
          TrackModel(id: 'audio-1', type: TrackType.audio, index: 1),
        ],
      ),
    );

    controller.seek(15);
    controller.addTrack(TrackType.video);

    expect(controller.playhead, 10);
    expect(controller.timeline.videoTracks.map((track) => track.label),
        ['V1', 'V2']);
    controller.dispose();
  });

  test('selection controller supports additive multi-clip selection', () {
    final controller = TimelineController();
    controller.selection.selectOnly('one');
    controller.selection.toggle('two');
    expect(controller.selection.clipIds, {'one', 'two'});
    controller.selection.toggle('one');
    expect(controller.selection.clipIds, {'two'});
    controller.dispose();
  });
}
