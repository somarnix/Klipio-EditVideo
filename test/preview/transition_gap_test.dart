import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/export/services/multi_track_filter_builder.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  for (final speed in [.5, 1.0, 2.0]) {
    for (final gap in [0.0, 1e-15, .001, .25]) {
      test('outgoing transition ownership speed=$speed gap=$gap', () {
        final source = TimelineModel(duration: 3, tracks: [
          TrackModel(id: 'audio', type: TrackType.audio, index: 0, clips: [
            ClipModel(
                id: 'a',
                mediaPath: 'same.wav',
                timelineStart: 0,
                sourceStart: 0,
                duration: 1,
                zIndex: 0,
                playbackSpeed: speed),
            ClipModel(
                id: 'b',
                mediaPath: 'same.wav',
                timelineStart: 1 / speed + gap,
                sourceStart: 1,
                duration: 1,
                zIndex: 0,
                playbackSpeed: speed,
                transitionIn: const ClipTransition(
                    type: ClipTransitionType.dissolve, duration: .2))
          ])
        ]);
        final timeline = ProgramRenderSnapshot.build(
            sourceTimeline: source,
            playbackSpeedsByMediaPath: const {}).outputTimeline;
        final plan = const MultiTrackFilterBuilder().build(
            MultiTrackExportJob(
                timeline: timeline,
                outputPath: 'unused.mp4',
                width: 16,
                height: 16),
            encoder: 'libx264');
        expect(plan.filterGraph.contains('afade=t=out'), gap < 1e-12);
        // B can still have its own fade-in from silence across a gap.
        expect(plan.filterGraph, contains('afade=t=in'));
      });
    }
  }
}
