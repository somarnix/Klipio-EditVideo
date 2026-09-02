import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/composition/domain/program_render_snapshot.dart';
import 'package:klipio/features/preview/engine/program_timeline_mapper.dart';
import 'package:klipio/features/timeline/application/timeline_editor.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  for (final speed in [1.0, 1.15, .5, 2.0]) {
    test('600 second source preserves program/source clock at $speed', () {
      for (final start in [0.0, 20.0]) {
        final span = 600 - start - (start > 0 ? 20 : 0);
        final video = ClipModel(
            id: 'v',
            mediaPath: 'same.mp4',
            timelineStart: 0,
            sourceStart: start,
            duration: span,
            playbackSpeed: speed,
            zIndex: 0);
        final source = TimelineModel(duration: span, tracks: [
          TrackModel(id: 'V1', type: TrackType.video, index: 1, clips: [video]),
          TrackModel(id: 'A1', type: TrackType.audio, index: 1, clips: [
            video.copyWith(id: 'audio', isLinkedAudio: true, linkedClipId: 'v'),
          ]),
        ]);
        final snapshot = ProgramRenderSnapshot.build(
            sourceTimeline: source, playbackSpeedsByMediaPath: const {});
        final output = snapshot.outputTimeline;
        final clip = output.clipById('v')!.clip;
        expect(output.duration, closeTo(span / speed, 1e-9));
        expect(clip.timelineEnd, output.duration);
        expect(output.clipById('audio')!.clip.timelineEnd, output.duration);
        expect(clip.sourceDurationFromProgram(), closeTo(span, 1e-9));
        final finalFrame = ProgramTimelineMapper.resolveMonitor(
            output, output.duration,
            frameRate: 30);
        expect(finalFrame.timelineSeconds, output.duration);
        expect(finalFrame.sourceSeconds, lessThan(start + span));
        expect(finalFrame.sourceSeconds,
            greaterThanOrEqualTo(start + span - speed / 30));
        expect(ProgramTimelineMapper.resolve(output, output.duration).isGap,
            isTrue);
        final split = const TimelineEditor.program()
            .splitClip(output, clipId: 'v', playhead: output.duration / 2);
        final clips = split.videoTracks.single.clips;
        expect(clips, hasLength(2));
        expect(clips.first.timelineEnd, clips.last.timelineStart);
        expect(clips.last.sourceStart, closeTo(start + span / 2, 1e-9));
        expect(clips.last.timelineEnd, closeTo(output.duration, 1e-9));
        final saved = ProgramRenderSnapshot.sourceFromProgram(split);
        final reopened = ProgramRenderSnapshot.build(
            sourceTimeline: TimelineModel.fromJson(saved.toJson()),
            playbackSpeedsByMediaPath: const {}).outputTimeline;
        expect(reopened.duration, closeTo(output.duration, 1e-9));
      }
    });
  }
}
