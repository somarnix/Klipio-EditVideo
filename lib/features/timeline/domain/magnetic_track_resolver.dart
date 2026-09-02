import 'dart:math' as math;

import 'timeline_models.dart';
import 'linked_audio_edit_guard.dart';
import 'timeline_boundary.dart';
import '../../composition/domain/program_render_snapshot.dart';

enum TrimEdge { start, end }

/// Immutable ripple editing for the lowest-index video track (Klipio's V1).
///
/// A positive trim delta removes time. A negative trim delta restores time.
/// Secondary clips whose start is anchored at or after the edit boundary move
/// with the primary story unless their track is locked.
class MagneticTrackResolver {
  const MagneticTrackResolver(
      {this.minimumClipDuration = 0.15, this.programTime = false});

  final bool programTime;

  final double minimumClipDuration;

  TimelineModel rippleTrim({
    required TimelineModel timeline,
    required String clipId,
    required Duration deltaDuration,
    required TrimEdge edge,
  }) {
    final location = timeline.clipById(clipId);
    final primary = _primaryTrack(timeline);
    if (location == null ||
        primary == null ||
        location.track.id != primary.id ||
        primary.isLocked) {
      return timeline;
    }
    final clip = location.clip;
    final requestedRemoval = deltaDuration.inMicroseconds / 1000000;
    final newDuration = (clip.duration - requestedRemoval)
        .clamp(minimumClipDuration, double.infinity)
        .toDouble();
    final removed = clip.duration - newDuration;
    if (removed.abs() < 0.000001) return timeline;

    final boundary = clip.timelineEnd;
    final shiftedStarts = _shiftedPrimaryStarts(
      primary,
      excludingId: clipId,
      boundary: boundary,
      delta: -removed,
    );
    final linkedAudio = timeline.linkedAudioForVideo(clipId);
    final programClip = _programTimeline(timeline).clipById(clipId)!.clip;
    final updatedClip = clip.copyWith(
      duration: newDuration,
      sourceStart: edge == TrimEdge.start
          ? math
              .max(
                  0,
                  clip.sourceStart +
                      removed *
                          (programTime ? clip.resolvedPlaybackSpeed() : 1))
              .toDouble()
          : clip.sourceStart,
      keyframes: _trimmedKeyframes(clip, edge, removed, newDuration),
    );

    return _rewrite(
      timeline,
      primaryTrackId: primary.id,
      primaryReplacement: updatedClip,
      primaryRemovedId: null,
      shiftedPrimaryStarts: shiftedStarts,
      anchorBoundary: boundary,
      anchorDelta: -removed,
      programBoundary: programClip.timelineEnd,
      programDelta:
          -removed / (programTime ? 1 : clip.resolvedPlaybackSpeed(1)),
      linkedAudioId: linkedAudio?.id,
      linkedAudioReplacement: linkedAudio?.copyWith(
        duration: newDuration,
        sourceStart: edge == TrimEdge.start
            ? math
                .max(
                    0,
                    linkedAudio.sourceStart +
                        removed *
                            (programTime
                                ? linkedAudio.resolvedPlaybackSpeed()
                                : 1))
                .toDouble()
            : linkedAudio.sourceStart,
      ),
    );
  }

  TimelineModel rippleDelete({
    required TimelineModel timeline,
    required String clipId,
  }) {
    final location = timeline.clipById(clipId);
    final primary = _primaryTrack(timeline);
    if (location == null ||
        primary == null ||
        location.track.id != primary.id ||
        primary.isLocked) {
      return timeline;
    }
    final clip = location.clip;
    final linkedAudio = timeline.linkedAudioForVideo(clipId);
    final programClip = _programTimeline(timeline).clipById(clipId)!.clip;
    return _rewrite(
      timeline,
      primaryTrackId: primary.id,
      primaryReplacement: null,
      primaryRemovedId: clipId,
      shiftedPrimaryStarts: _shiftedPrimaryStarts(
        primary,
        excludingId: clipId,
        boundary: clip.timelineEnd,
        delta: -clip.duration,
      ),
      anchorBoundary: clip.timelineEnd,
      anchorDelta: -clip.duration,
      programBoundary: programClip.timelineEnd,
      programDelta: -programClip.duration,
      linkedAudioId: linkedAudio?.id,
      linkedAudioReplacement: null,
    );
  }

  TimelineModel rippleInsert({
    required TimelineModel timeline,
    required ClipModel clip,
    required int insertIndex,
  }) {
    final primary = _primaryTrack(timeline);
    if (primary == null || primary.isLocked) return timeline;
    final ordered = [
      ...primary.clips
    ]..sort((left, right) => left.timelineStart.compareTo(right.timelineStart));
    final safeIndex = insertIndex.clamp(0, ordered.length);
    final insertStart =
        safeIndex == 0 ? 0.0 : ordered[safeIndex - 1].timelineEnd;
    final inserted = clip.copyWith(
      timelineStart: insertStart,
      zIndex: primary.index - 1,
    );
    final shifted = <String, double>{
      for (var index = safeIndex; index < ordered.length; index++)
        ordered[index].id: ordered[index].timelineStart + inserted.duration,
      for (final track in timeline.videoTracks)
        if (track.id != primary.id && !track.isLocked)
          for (final item in track.clips)
            if (TimelineBoundary.atOrAfter(item.timelineStart, insertStart))
              item.id: item.timelineStart + inserted.duration,
    };
    if (LinkedAudioEditGuard.blocks(timeline, shifted.keys)) return timeline;
    final program = _programTimeline(timeline);
    final programBoundary = safeIndex == 0
        ? 0.0
        : program.clipById(ordered[safeIndex - 1].id)!.clip.timelineEnd;
    final programDelta = inserted.duration /
        (programTime ? 1 : inserted.resolvedPlaybackSpeed(1));
    final audioStarts = _companionStarts(timeline, shifted);
    final tracks = <TrackModel>[
      for (final track in timeline.tracks)
        if (track.id == primary.id)
          track.copyWith(
            clips: [
              ...track.clips.where((item) => item.id != inserted.id).map(
                    (item) => shifted.containsKey(item.id)
                        ? item.copyWith(timelineStart: shifted[item.id])
                        : item,
                  ),
              inserted,
            ],
          )
        else if (!track.isLocked)
          track.copyWith(
            clips: [
              for (final item in track.clips)
                if (audioStarts.containsKey(item.id))
                  item.copyWith(timelineStart: audioStarts[item.id])
                else if (!item.isLinkedAudio &&
                    TimelineBoundary.atOrAfter(
                        item.timelineStart,
                        track.type == TrackType.audio && !item.isLinkedAudio
                            ? programBoundary
                            : insertStart))
                  item.copyWith(
                    timelineStart: item.timelineStart +
                        (track.type == TrackType.audio && !item.isLinkedAudio
                            ? programDelta
                            : inserted.duration),
                  )
                else
                  item,
            ],
          )
        else
          track,
    ];
    return TimelineModel(
      tracks: tracks,
      duration: TimelineModel.calculateDuration(tracks),
    ).normalized();
  }

  TrackModel? _primaryTrack(TimelineModel timeline) =>
      timeline.videoTracks.isEmpty ? null : timeline.videoTracks.first;

  // Independent audio stores program placement, while V1 edits operate on
  // source-clock durations. Reuse the canonical retimer for that boundary.
  TimelineModel _programTimeline(TimelineModel timeline) => programTime
      ? timeline
      : ProgramRenderSnapshot.build(
          sourceTimeline: timeline,
          playbackSpeedsByMediaPath: const {}).outputTimeline;

  Map<String, double> _companionStarts(
          TimelineModel timeline, Map<String, double> videos) =>
      {
        for (final entry in videos.entries)
          if (timeline.linkedAudioForVideo(entry.key) case final audio?)
            audio.id: entry.value,
      };

  Map<String, double> _shiftedPrimaryStarts(
    TrackModel primary, {
    required String excludingId,
    required double boundary,
    required double delta,
  }) =>
      <String, double>{
        for (final item in primary.clips)
          if (item.id != excludingId &&
              TimelineBoundary.atOrAfter(item.timelineStart, boundary))
            item.id: math.max(0, item.timelineStart + delta).toDouble(),
      };

  List<ClipKeyframe> _trimmedKeyframes(
    ClipModel clip,
    TrimEdge edge,
    double removed,
    double newDuration,
  ) {
    if (edge == TrimEdge.end) {
      return clip.keyframes
          .where((item) => item.offset <= newDuration)
          .toList(growable: false);
    }
    return [
      for (final item in clip.keyframes)
        if (item.offset >= removed)
          ClipKeyframe(
            offset: math.max(0, item.offset - removed).toDouble(),
            transform: item.transform,
          ),
    ];
  }

  TimelineModel _rewrite(
    TimelineModel timeline, {
    required String primaryTrackId,
    required ClipModel? primaryReplacement,
    required String? primaryRemovedId,
    required Map<String, double> shiftedPrimaryStarts,
    required double anchorBoundary,
    required double anchorDelta,
    required double programBoundary,
    required double programDelta,
    required String? linkedAudioId,
    required ClipModel? linkedAudioReplacement,
  }) {
    final shiftedVideos = <String, double>{
      ...shiftedPrimaryStarts,
      for (final track in timeline.videoTracks)
        if (track.id != primaryTrackId && !track.isLocked)
          for (final item in track.clips)
            if (TimelineBoundary.atOrAfter(item.timelineStart, anchorBoundary))
              item.id: math.max(0, item.timelineStart + anchorDelta).toDouble(),
    };
    if (LinkedAudioEditGuard.blocks(timeline, [
      if (primaryReplacement != null) primaryReplacement.id,
      if (primaryRemovedId != null) primaryRemovedId,
      ...shiftedVideos.keys,
    ])) return timeline;
    final shiftedAudio = _companionStarts(timeline, shiftedVideos);
    final tracks = <TrackModel>[
      for (final track in timeline.tracks)
        if (track.id == primaryTrackId)
          track.copyWith(
            clips: [
              for (final item in track.clips)
                if (item.id != primaryRemovedId)
                  if (primaryReplacement != null &&
                      item.id == primaryReplacement.id)
                    primaryReplacement
                  else if (shiftedPrimaryStarts.containsKey(item.id))
                    item.copyWith(
                      timelineStart: shiftedPrimaryStarts[item.id],
                    )
                  else
                    item,
            ],
          )
        else if (track.isLocked)
          track
        else
          track.copyWith(
            clips: [
              for (final item in track.clips)
                if (item.id != linkedAudioId || linkedAudioReplacement != null)
                  if (linkedAudioReplacement != null &&
                      item.id == linkedAudioId)
                    linkedAudioReplacement
                  else if (shiftedAudio.containsKey(item.id))
                    item.copyWith(
                      timelineStart: shiftedAudio[item.id],
                    )
                  else if (!item.isLinkedAudio &&
                      TimelineBoundary.atOrAfter(
                          item.timelineStart,
                          track.type == TrackType.audio
                              ? programBoundary
                              : anchorBoundary))
                    item.copyWith(
                      timelineStart: math
                          .max(
                              0,
                              item.timelineStart +
                                  (track.type == TrackType.audio
                                      ? programDelta
                                      : anchorDelta))
                          .toDouble(),
                    )
                  else
                    item,
            ],
          ),
    ];
    return TimelineModel(
      tracks: tracks,
      duration: TimelineModel.calculateDuration(tracks),
    ).normalized();
  }
}
