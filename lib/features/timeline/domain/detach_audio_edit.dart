import 'timeline_models.dart';
import '../../composition/domain/program_render_snapshot.dart';

/// Detachment freezes current program placement and speed into an independent
/// audio instance. It must not jump back to the unretimed source-track start.
abstract final class DetachAudioEdit {
  static TimelineModel apply(
      TimelineModel timeline, String videoId, String detachedId,
      {Map<String, double> legacySpeeds = const {}}) {
    final video = timeline.clipById(videoId);
    final linked = timeline.linkedAudioForVideo(videoId);
    if (video == null ||
        video.track.type != TrackType.video ||
        video.track.isLocked ||
        linked == null ||
        timeline.clipById(linked.id)!.track.isLocked ||
        timeline.clipById(detachedId) != null) return timeline;
    final snapshot = ProgramRenderSnapshot.build(
        sourceTimeline: timeline, playbackSpeedsByMediaPath: legacySpeeds);
    final output = snapshot.outputTimeline.clipById(linked.id)!.clip;
    final source = snapshot.sourceTimeline.clipById(linked.id)!.clip;
    final independent = source.copyWith(
        id: detachedId,
        timelineStart: output.timelineStart,
        isLinkedAudio: false,
        clearLinkedClipId: true);
    return timeline.copyWith(duration: timeline.duration, tracks: [
      for (final track in timeline.tracks)
        track.copyWith(clips: [
          for (final clip in track.clips)
            clip.id == linked.id ? independent : clip
        ])
    ]);
  }
}
