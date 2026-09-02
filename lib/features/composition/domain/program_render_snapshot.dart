import 'dart:math' as math;

import '../../timeline/domain/timeline_models.dart';
import '../../timeline/domain/clip_speed_edit.dart';
import '../../timeline/domain/timeline_boundary.dart';
import '../../timeline/domain/transition_boundary.dart';
import 'render_scene.dart';

class ProgramClipPlayback {
  const ProgramClipPlayback({
    required this.clipId,
    required this.mediaPath,
    required this.speed,
    required this.volume,
  });

  final String clipId;
  final String mediaPath;
  final double speed;
  final double volume;
}

/// One immutable rendering contract shared by Program Monitor and export.
///
/// [sourceTimeline] preserves source time. [outputTimeline] is retimed for
/// playback/export. Both consumers must use this object instead of rebuilding
/// timing independently from mutable inspector fields.
class ProgramRenderSnapshot {
  ProgramRenderSnapshot._({
    required this.sourceTimeline,
    required this.outputTimeline,
    required Map<String, double> playbackSpeedsByMediaPath,
  }) : playbackSpeedsByMediaPath = Map.unmodifiable(
          playbackSpeedsByMediaPath,
        );

  factory ProgramRenderSnapshot.build({
    required TimelineModel sourceTimeline,
    required Map<String, double> playbackSpeedsByMediaPath,
    double minimumSpeed = 0.25,
    double maximumSpeed = 4,
  }) {
    final speeds = <String, double>{
      for (final entry in playbackSpeedsByMediaPath.entries)
        entry.key: (entry.value.isFinite ? entry.value : 1.0)
            .clamp(minimumSpeed, maximumSpeed)
            .toDouble(),
    };
    // Materialize legacy defaults into the captured instances. Consumers never
    // need to choose between an explicit clip value and an asset value again.
    final capturedTimeline =
        _captureTimeline(ClipSpeedEdit.migrate(sourceTimeline, speeds));
    return ProgramRenderSnapshot._(
      sourceTimeline: capturedTimeline,
      outputTimeline: _captureTimeline(_retimeTimeline(
        capturedTimeline,
        speeds,
        minimumSpeed,
        maximumSpeed,
      )),
      playbackSpeedsByMediaPath: speeds,
    );
  }

  final TimelineModel sourceTimeline;
  final TimelineModel outputTimeline;
  final Map<String, double> playbackSpeedsByMediaPath;

  /// Convert a program-clock editing result back to the durable source-clock
  /// sequence. Source offsets are already media seconds; only occupied ranges,
  /// keyframe offsets and transition handles are retimed. Independent audio
  /// keeps absolute program placement, exactly as in [_retimeTimeline].
  ///
  /// This is the UI command boundary, not another playback timing authority.
  static TimelineModel sourceFromProgram(TimelineModel program) {
    final tracks = <TrackModel>[];
    for (final track in program.tracks) {
      final ordered = [...track.clips]
        ..sort((a, b) => a.timelineStart.compareTo(b.timelineStart));
      ClipModel? previousProgram;
      ClipModel? previousSource;
      final converted = <String, ClipModel>{};
      for (final clip in ordered) {
        final speed = clip.resolvedPlaybackSpeed();
        final gap = previousProgram == null
            ? 0.0
            : clip.timelineStart - previousProgram.timelineEnd;
        final sourceGap = previousProgram != null &&
                TransitionBoundary.overlaps(previousProgram, clip)
            ? -clip.transitionIn!.duration * speed
            : TimelineBoundary.adjacent(gap, 0)
                ? 0.0
                : gap;
        final source = clip.copyWith(
          timelineStart: track.type == TrackType.audio && !clip.isLinkedAudio ||
                  previousSource == null
              ? clip.timelineStart
              : previousSource.timelineEnd + sourceGap,
          duration: clip.sourceDurationFromProgram(),
          transitionIn: clip.transitionIn == null
              ? null
              : ClipTransition(
                  type: clip.transitionIn!.type,
                  duration: clip.transitionIn!.duration * speed,
                ),
          keyframes: [
            for (final frame in clip.keyframes)
              ClipKeyframe(
                  offset: frame.offset * speed, transform: frame.transform)
          ],
        );
        converted[clip.id] = source;
        previousProgram = clip;
        previousSource = source;
      }
      tracks.add(track.copyWith(clips: [
        for (final clip in track.clips) converted[clip.id]!,
      ]));
    }
    final owners = {
      for (final track in tracks)
        if (track.type == TrackType.video)
          for (final clip in track.clips) clip.id: clip
    };
    final aligned = [
      for (final track in tracks)
        track.type != TrackType.audio
            ? track
            : track.copyWith(clips: [
                for (final clip in track.clips)
                  if (clip.isLinkedAudio &&
                      owners.containsKey(clip.linkedClipId))
                    clip.copyWith(
                        timelineStart: owners[clip.linkedClipId]!.timelineStart)
                  else
                    clip,
              ])
    ];
    final trailing = math.max(0.0,
        program.duration - TimelineModel.calculateDuration(program.tracks));
    return TimelineModel(
        tracks: aligned,
        duration: TimelineModel.calculateDuration(aligned) + trailing);
  }

  /// Reject a gesture the legacy sequential source clock cannot encode (for
  /// example a negative source-clock start caused by a same-track overlap).
  /// Such a gesture must not save as a different program after reopening.
  static TimelineModel? trySourceFromProgram(TimelineModel program) {
    final source = sourceFromProgram(program);
    if (source.tracks.any((track) => track.clips.any((clip) =>
        !clip.timelineStart.isFinite ||
        clip.timelineStart < 0 ||
        !clip.duration.isFinite ||
        clip.duration <= 0))) return null;
    final rendered = _retimeTimeline(source, const {}, .25, 4);
    for (final track in program.tracks) {
      for (final clip in track.clips) {
        final actual = rendered.clipById(clip.id)?.clip;
        if (actual == null ||
            !TimelineBoundary.adjacent(
                actual.timelineStart, clip.timelineStart) ||
            !TimelineBoundary.adjacent(actual.timelineEnd, clip.timelineEnd)) {
          return null;
        }
      }
    }
    return source;
  }

  double speedForMedia(String mediaPath) =>
      playbackSpeedsByMediaPath[mediaPath] ?? 1;

  ProgramClipPlayback? playbackForClip(String? clipId) {
    if (clipId == null) return null;
    final source = sourceTimeline.clipById(clipId)?.clip;
    if (source == null) return null;
    ({TrackModel track, ClipModel clip})? linkedAudio;
    for (final track in sourceTimeline.audioTracks) {
      for (final audio in track.clips) {
        if (audio.isLinkedAudio && audio.linkedClipId == clipId) {
          linkedAudio = (track: track, clip: audio);
          break;
        }
      }
      if (linkedAudio != null) break;
    }
    if (linkedAudio == null) {
      final legacyMatches = <({TrackModel track, ClipModel clip})>[];
      for (final track in sourceTimeline.audioTracks) {
        for (final audio in track.clips) {
          // Never borrow an explicit link belonging to another split/reuse of
          // this media. Older projects may omit the link; require matching
          // source and timeline ranges and reject ambiguous legacy matches.
          if (audio.isLinkedAudio &&
              (audio.linkedClipId == null || audio.linkedClipId!.isEmpty) &&
              audio.mediaPath == source.mediaPath &&
              audio.timelineStart == source.timelineStart &&
              audio.sourceStart == source.sourceStart &&
              audio.duration == source.duration) {
            legacyMatches.add((track: track, clip: audio));
          }
        }
      }
      if (legacyMatches.length == 1) linkedAudio = legacyMatches.single;
    }
    final volume = linkedAudio == null ||
            linkedAudio.track.isMuted ||
            linkedAudio.clip.isMuted
        ? linkedAudio == null
            ? 1.0
            : 0.0
        : linkedAudio.clip.volume;
    return ProgramClipPlayback(
      clipId: clipId,
      mediaPath: source.mediaPath,
      speed: source.resolvedPlaybackSpeed(),
      volume: volume.clamp(0.0, 1.0).toDouble(),
    );
  }

  RenderScene resolve({
    required CompositionModel composition,
    required double timelineSeconds,
  }) {
    return RenderSceneResolver.resolve(
      timeline: outputTimeline,
      composition: composition,
      timelineSeconds: timelineSeconds,
      playbackSpeedsByMediaPath: playbackSpeedsByMediaPath,
    );
  }
}

// Models have final fields, but callers can still own mutable backing lists.
// Capture every collection so later editor mutations cannot alter a running
// export, and consumers cannot accidentally mutate the captured contract.
TimelineModel _captureTimeline(TimelineModel timeline) => timeline.copyWith(
      duration: timeline.duration,
      tracks: List.unmodifiable([
        for (final track in timeline.tracks)
          track.copyWith(
            clips: List.unmodifiable([
              for (final clip in track.clips)
                clip.copyWith(
                  effects: List.unmodifiable(clip.effects),
                  keyframes: List.unmodifiable(clip.keyframes),
                ),
            ]),
          ),
      ]),
    );

TimelineModel _retimeTimeline(
  TimelineModel timeline,
  Map<String, double> playbackSpeedsByMediaPath,
  double minimumSpeed,
  double maximumSpeed,
) {
  double speedFor(ClipModel clip) => clip
      .resolvedPlaybackSpeed(playbackSpeedsByMediaPath[clip.mediaPath] ?? 1)
      .clamp(minimumSpeed, maximumSpeed)
      .toDouble();
  final tracks = <TrackModel>[];
  for (final track in timeline.tracks) {
    final ordered = [
      ...track.clips
    ]..sort((left, right) => left.timelineStart.compareTo(right.timelineStart));
    final retimedById = <String, ClipModel>{};
    ClipModel? previousSource;
    ClipModel? previousOutput;
    for (final clip in ordered) {
      final speed = speedFor(clip);
      final sourceGap = previousSource == null
          ? 0.0
          : clip.timelineStart - previousSource.timelineEnd;
      // Decimal source times represented as doubles can differ by ~1e-15 at
      // an otherwise shared edge. This is arithmetic noise, not an editing or
      // backend tolerance; genuine microsecond gaps remain untouched.
      final gap = previousSource != null &&
              TransitionBoundary.overlaps(previousSource, clip)
          ? -clip.transitionIn!.duration / speed
          : TimelineBoundary.adjacent(sourceGap, 0)
              ? 0.0
              : sourceGap;
      final timelineStart = track.type == TrackType.audio && !clip.isLinkedAudio
          ? clip.timelineStart
          : previousSource == null
              ? clip.timelineStart
              : previousOutput!.timelineEnd + gap;
      final retimed = clip.copyWith(
        timelineStart: math.max(0, timelineStart).toDouble(),
        duration: clip.programDurationFromSource(speed),
        transitionIn: clip.transitionIn == null
            ? null
            : ClipTransition(
                type: clip.transitionIn!.type,
                duration: clip.transitionIn!.duration / speed,
              ),
        keyframes: [
          for (final keyframe in clip.keyframes)
            ClipKeyframe(
              offset: keyframe.offset / speed,
              transform: keyframe.transform,
            ),
        ],
      );
      retimedById[clip.id] = retimed;
      previousSource = clip;
      previousOutput = retimed;
    }
    tracks.add(
      track.copyWith(
        clips: [for (final clip in track.clips) retimedById[clip.id] ?? clip],
      ),
    );
  }
  // Linked audio follows the exact owner's placement, not the ordering of
  // unrelated audio clips on its track.
  final videoById = {
    for (final track in tracks)
      if (track.type == TrackType.video)
        for (final clip in track.clips) clip.id: clip
  };
  final aligned = [
    for (final track in tracks)
      track.type != TrackType.audio
          ? track
          : track.copyWith(clips: [
              for (final clip in track.clips)
                if (clip.isLinkedAudio &&
                    videoById.containsKey(clip.linkedClipId))
                  clip.copyWith(
                      timelineStart:
                          videoById[clip.linkedClipId]!.timelineStart,
                      duration: videoById[clip.linkedClipId]!.duration)
                else
                  clip,
            ])
  ];
  final trailing = math.max(0.0,
      timeline.duration - TimelineModel.calculateDuration(timeline.tracks));
  return TimelineModel(
      tracks: aligned,
      duration: TimelineModel.calculateDuration(aligned) + trailing);
}
