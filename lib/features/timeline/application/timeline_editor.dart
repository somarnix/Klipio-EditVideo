import 'dart:math' as math;
import '../domain/transition_boundary.dart';

import '../domain/magnetic_track_resolver.dart';
import '../domain/linked_audio_edit_guard.dart';
import '../domain/timeline_boundary.dart';
import '../domain/timeline_models.dart';

class TimelineSnapResult {
  const TimelineSnapResult({required this.time, this.guideTime});

  final double time;
  final double? guideTime;

  bool get snapped => guideTime != null;
}

class TimelineEditor {
  const TimelineEditor({
    this.snapThreshold = 0.12,
    this.magneticTrackResolver = const MagneticTrackResolver(),
  })  : programTime = false,
        sourceDurations = const {};

  /// Editing the resolved program layout: durations/deltas are program seconds,
  /// while sourceStart remains media seconds. Durable callers retain the
  /// existing source-clock constructor.
  const TimelineEditor.program(
      {this.snapThreshold = 0.12, this.sourceDurations = const {}})
      : programTime = true,
        magneticTrackResolver = const MagneticTrackResolver(programTime: true);

  final bool programTime;
  final Map<String, double> sourceDurations;

  final double snapThreshold;
  final MagneticTrackResolver magneticTrackResolver;

  bool _linkedAudioTrackLocked(TimelineModel model, String videoId) {
    return LinkedAudioEditGuard.blocks(model, [videoId]);
  }

  TimelineModel addTrack(TimelineModel model, TrackType type) {
    final existing = model.tracks.where((track) => track.type == type);
    final nextIndex = existing.isEmpty
        ? 1
        : existing.map((track) => track.index).reduce(math.max) + 1;
    return model.copyWith(
      tracks: [
        ...model.tracks,
        TrackModel(
          id: '${type.name}-$nextIndex',
          type: type,
          index: nextIndex,
        ),
      ],
    ).normalized();
  }

  TimelineModel updateTrack(
    TimelineModel model,
    String trackId,
    TrackModel Function(TrackModel track) update,
  ) {
    return model.copyWith(
      tracks: [
        for (final track in model.tracks)
          if (track.id == trackId) update(track) else track,
      ],
    );
  }

  TimelineModel moveClip(
    TimelineModel model, {
    required String clipId,
    required String targetTrackId,
    required double timelineStart,
    double? playhead,
    List<double> markers = const [],
    bool snap = true,
  }) {
    final source = model.clipById(clipId);
    final target = model.trackById(targetTrackId);
    if (source == null ||
        target == null ||
        source.track.isLocked ||
        target.isLocked) {
      return model;
    }
    if (source.track.type != target.type) return model;
    if (_linkedAudioTrackLocked(model, source.clip.id)) return model;
    final targetStart = snap
        ? snapTime(
            model,
            movingClipId: clipId,
            proposedStart: timelineStart,
            clipDuration: source.clip.duration,
            playhead: playhead,
            markers: markers,
          ).time
        : math.max(0, timelineStart).toDouble();
    final moved = source.clip.copyWith(
      timelineStart: targetStart,
      zIndex: target.type == TrackType.video ? target.index - 1 : 0,
    );
    final linkedAudioId = source.track.type == TrackType.video
        ? model.linkedAudioForVideo(source.clip.id)?.id
        : null;
    final timelineDelta = moved.timelineStart - source.clip.timelineStart;
    return model.copyWith(
      tracks: [
        for (final track in model.tracks)
          if (track.id == source.track.id && track.id == target.id)
            track.copyWith(
              clips: [
                for (final clip in track.clips)
                  if (clip.id == clipId) moved else clip,
              ],
            )
          else if (track.id == source.track.id)
            track.copyWith(
              clips: track.clips.where((clip) => clip.id != clipId).toList(),
            )
          else if (track.id == target.id)
            track.copyWith(clips: [...track.clips, moved])
          else if (linkedAudioId != null && track.type == TrackType.audio)
            track.copyWith(
              clips: [
                for (final clip in track.clips)
                  if (clip.id == linkedAudioId)
                    clip.copyWith(
                      timelineStart: math
                          .max(0, clip.timelineStart + timelineDelta)
                          .toDouble(),
                    )
                  else
                    clip,
              ],
            )
          else
            track,
      ],
    );
  }

  /// One drag transaction, resolved from the starting model. A companion
  /// selected alongside its video moves once, through that video's ownership.
  TimelineModel moveClips(
    TimelineModel model, {
    required Set<String> clipIds,
    required String anchorClipId,
    required String targetTrackId,
    required double timelineStart,
    double? playhead,
    List<double> markers = const [],
    bool snap = true,
  }) {
    final anchor = model.clipById(anchorClipId);
    final target = model.trackById(targetTrackId);
    final ids = {...clipIds, anchorClipId};
    if (anchor == null ||
        target == null ||
        target.isLocked ||
        anchor.track.type != target.type ||
        ids.any((id) =>
            model.clipById(id) == null || model.clipById(id)!.track.isLocked) ||
        LinkedAudioEditGuard.blocks(model, ids)) return model;
    final companions = <String>{
      for (final id in ids)
        if (model.clipById(id)!.track.type == TrackType.video &&
            model.linkedAudioForVideo(id) != null)
          model.linkedAudioForVideo(id)!.id,
    };
    // A linked-audio anchor is still moved by its selected owner; do not issue
    // both operations against a progressively mutated timeline.
    final proposed = snap
        ? snapTime(model,
                movingClipId: anchorClipId,
                proposedStart: timelineStart,
                clipDuration: anchor.clip.duration,
                playhead: playhead,
                markers: markers)
            .time
        : timelineStart;
    final earliest = ids
        .map((id) => model.clipById(id)!.clip.timelineStart)
        .reduce(math.min);
    final delta = math.max(-earliest, proposed - anchor.clip.timelineStart);
    var next = model;
    for (final id in ids.where((id) => !companions.contains(id))) {
      final original = model.clipById(id)!;
      next = moveClip(next,
          clipId: id,
          targetTrackId: id == anchorClipId ? targetTrackId : original.track.id,
          timelineStart: original.clip.timelineStart + delta,
          snap: false);
    }
    return next;
  }

  TimelineModel splitClip(
    TimelineModel model, {
    required String clipId,
    required double playhead,
  }) {
    final result = model.clipById(clipId);
    if (result == null || result.track.isLocked) return model;
    final clip = result.clip;
    if (result.track.type == TrackType.video &&
        _linkedAudioTrackLocked(model, clip.id)) return model;
    if (playhead <= clip.timelineStart + 0.04 ||
        playhead >= clip.timelineEnd - 0.04) {
      return model;
    }
    final firstDuration = playhead - clip.timelineStart;
    final secondDuration = clip.duration - firstDuration;
    final first = clip.copyWith(
      id: '${clip.id}-a-${(playhead * 1000).round()}',
      duration: firstDuration,
      replacesClipId: clip.replacesClipId ?? clip.id,
      keyframes: result.track.type == TrackType.text
          ? clip.keyframes
          : clip.keyframes
              .where((keyframe) => keyframe.offset <= firstDuration)
              .toList(),
    );
    final second = clip.copyWith(
      id: '${clip.id}-b-${(playhead * 1000).round()}',
      timelineStart: playhead,
      sourceStart: clip.sourceStart +
          firstDuration * (programTime ? clip.resolvedPlaybackSpeed() : 1),
      textAnimationOffset: result.track.type == TrackType.text
          ? clip.textAnimationOffset + firstDuration
          : clip.textAnimationOffset,
      duration: secondDuration,
      replacesClipId: clip.replacesClipId ?? clip.id,
      clearTransitionIn: true,
      keyframes: [
        if (result.track.type == TrackType.text && clip.keyframes.isNotEmpty)
          ClipKeyframe(offset: 0, transform: clip.transformAt(firstDuration)),
        for (final keyframe in clip.keyframes)
          if (keyframe.offset >= firstDuration)
            ClipKeyframe(
              offset: keyframe.offset - firstDuration,
              transform: keyframe.transform,
            ),
      ],
    );
    final linkedAudioId = result.track.type == TrackType.video
        ? model.linkedAudioForVideo(clip.id)?.id
        : null;
    return model.copyWith(
      tracks: [
        for (final track in model.tracks)
          if (track.id == result.track.id)
            track.copyWith(
              clips: [
                for (final item in track.clips)
                  if (item.id == clip.id) ...[first, second] else item,
              ],
            )
          else if (linkedAudioId != null && track.type == TrackType.audio)
            track.copyWith(
              clips: [
                for (final item in track.clips)
                  if (item.id == linkedAudioId) ...[
                    item.copyWith(
                      id: 'audio-${first.id}',
                      duration: firstDuration,
                      isLinkedAudio: true,
                      linkedClipId: first.id,
                      keyframes: const [],
                    ),
                    item.copyWith(
                      id: 'audio-${second.id}',
                      timelineStart: playhead,
                      sourceStart: item.sourceStart +
                          firstDuration *
                              (programTime ? item.resolvedPlaybackSpeed() : 1),
                      duration: secondDuration,
                      isLinkedAudio: true,
                      linkedClipId: second.id,
                      clearTransitionIn: true,
                      keyframes: const [],
                    ),
                  ] else
                    item,
              ],
            )
          else
            track,
      ],
    );
  }

  /// Removes everything in [clipId] before [playhead]. On the primary video
  /// track this is a ripple edit: the kept right-hand piece and every later
  /// primary clip close the removed gap together with their linked audio.
  TimelineModel keepClipAfterPlayhead(
    TimelineModel model, {
    required String clipId,
    required double playhead,
  }) {
    final split = splitClip(model, clipId: clipId, playhead: playhead);
    if (identical(split, model)) return model;
    final firstId = '$clipId-a-${(playhead * 1000).round()}';
    return deleteClip(split, firstId);
  }

  /// Removes everything in [clipId] after [playhead]. On the primary video
  /// track, later primary clips and their linked audio close the removed gap.
  TimelineModel keepClipBeforePlayhead(
    TimelineModel model, {
    required String clipId,
    required double playhead,
  }) {
    final split = splitClip(model, clipId: clipId, playhead: playhead);
    if (identical(split, model)) return model;
    final secondId = '$clipId-b-${(playhead * 1000).round()}';
    return deleteClip(split, secondId);
  }

  TimelineModel deleteClip(TimelineModel model, String clipId) {
    final result = model.clipById(clipId);
    if (result == null || result.track.isLocked) return model;
    if (result.track.type == TrackType.video &&
        _linkedAudioTrackLocked(model, clipId)) return model;
    if (result.track.type == TrackType.video &&
        result.track.id == model.videoTracks.firstOrNull?.id) {
      return magneticTrackResolver.rippleDelete(
        timeline: model,
        clipId: clipId,
      );
    }
    final linkedAudioId = result.track.type == TrackType.video
        ? model.linkedAudioForVideo(result.clip.id)?.id
        : null;
    final ripplePrimaryVideo =
        result.track.type == TrackType.video && result.track.index == 1;
    final shiftedVideoStarts = <String, double>{};

    if (ripplePrimaryVideo) {
      final remaining = result.track.clips
          .where((clip) => clip.id != clipId)
          .toList()
        ..sort((a, b) => a.timelineStart.compareTo(b.timelineStart));
      for (final clip in remaining) {
        final start = TimelineBoundary.atOrAfter(
                clip.timelineStart, result.clip.timelineEnd)
            ? math.max(0, clip.timelineStart - result.clip.duration).toDouble()
            : clip.timelineStart;
        shiftedVideoStarts[clip.id] = start;
      }
    }

    final shiftedAudioStarts = <String, double>{};
    for (final entry in shiftedVideoStarts.entries) {
      final audio = model.linkedAudioForVideo(entry.key);
      if (audio != null) shiftedAudioStarts[audio.id] = entry.value;
    }

    return model.copyWith(
      tracks: [
        for (final track in model.tracks)
          if (track.id == result.track.id)
            track.copyWith(
              clips: [
                for (final clip in track.clips)
                  if (clip.id != clipId)
                    shiftedVideoStarts.containsKey(clip.id)
                        ? clip.copyWith(
                            timelineStart: shiftedVideoStarts[clip.id],
                          )
                        : clip,
              ],
            )
          else if (track.type == TrackType.audio &&
              (linkedAudioId != null || shiftedAudioStarts.isNotEmpty))
            track.copyWith(
              clips: [
                for (final clip in track.clips)
                  if (clip.id != linkedAudioId)
                    shiftedAudioStarts.containsKey(clip.id)
                        ? clip.copyWith(
                            timelineStart: shiftedAudioStarts[clip.id],
                          )
                        : clip,
              ],
            )
          else
            track,
      ],
    );
  }

  TimelineModel insertClip(
    TimelineModel model, {
    required String trackId,
    required ClipModel clip,
  }) {
    final track = model.trackById(trackId);
    if (track == null || track.isLocked) return model;
    final primary = model.videoTracks.firstOrNull;
    if (track.type == TrackType.video && track.id == primary?.id) {
      final ordered = [...track.clips]..sort(
          (left, right) => left.timelineStart.compareTo(right.timelineStart));
      var insertIndex = ordered.indexWhere(
        (item) =>
            TimelineBoundary.atOrAfter(item.timelineStart, clip.timelineStart),
      );
      if (insertIndex < 0) insertIndex = ordered.length;
      return magneticTrackResolver.rippleInsert(
        timeline: model,
        clip: clip,
        insertIndex: insertIndex,
      );
    }
    return updateTrack(
      model,
      trackId,
      (item) => item.copyWith(
        clips: [
          ...item.clips.where((existing) => existing.id != clip.id),
          clip.copyWith(
              zIndex: track.type == TrackType.video ? track.index - 1 : 0),
        ],
      ),
    ).copyWith();
  }

  TimelineModel updateClipTransform(
    TimelineModel model,
    String clipId,
    ClipTransform transform,
  ) {
    final result = model.clipById(clipId);
    if (result == null || result.track.isLocked) return model;
    return updateTrack(
      model,
      result.track.id,
      (track) => track.copyWith(
        clips: [
          for (final clip in track.clips)
            if (clip.id == clipId)
              clip.copyWith(transform: transform)
            else
              clip,
        ],
      ),
    );
  }

  TimelineModel addClipEffect(
    TimelineModel model,
    String clipId,
    ClipEffect effect,
  ) {
    final result = model.clipById(clipId);
    if (result == null || result.track.isLocked) return model;
    return updateTrack(
      model,
      result.track.id,
      (track) => track.copyWith(
        clips: [
          for (final clip in track.clips)
            if (clip.id == clipId)
              clip.copyWith(effects: [...clip.effects, effect])
            else
              clip,
        ],
      ),
    );
  }

  TimelineModel updateClipEffect(
    TimelineModel model,
    String clipId,
    String effectId,
    ClipEffect Function(ClipEffect effect) update,
  ) {
    final result = model.clipById(clipId);
    if (result == null || result.track.isLocked) return model;
    return updateTrack(
      model,
      result.track.id,
      (track) => track.copyWith(
        clips: [
          for (final clip in track.clips)
            if (clip.id == clipId)
              clip.copyWith(
                effects: [
                  for (final effect in clip.effects)
                    if (effect.id == effectId) update(effect) else effect,
                ],
              )
            else
              clip,
        ],
      ),
    );
  }

  TimelineModel removeClipEffect(
    TimelineModel model,
    String clipId,
    String effectId,
  ) {
    final result = model.clipById(clipId);
    if (result == null || result.track.isLocked) return model;
    return updateTrack(
      model,
      result.track.id,
      (track) => track.copyWith(
        clips: [
          for (final clip in track.clips)
            if (clip.id == clipId)
              clip.copyWith(
                effects: clip.effects
                    .where((effect) => effect.id != effectId)
                    .toList(),
              )
            else
              clip,
        ],
      ),
    );
  }

  TimelineModel setClipTransition(
    TimelineModel model,
    String clipId,
    ClipTransition? transition,
  ) {
    final result = model.clipById(clipId);
    if (result == null ||
        result.track.isLocked ||
        result.track.type != TrackType.video) {
      return model;
    }
    if (_linkedAudioTrackLocked(model, clipId)) return model;
    final ordered = [...result.track.clips]
      ..sort((a, b) => a.timelineStart.compareTo(b.timelineStart));
    final index = ordered.indexWhere((clip) => clip.id == clipId);
    if (index <= 0) return model;
    final previous = ordered[index - 1];
    final clip = ordered[index];
    if (_linkedAudioTrackLocked(model, previous.id)) return model;
    if (transition != null &&
        (!transition.duration.isFinite ||
            transition.duration <= 0 ||
            !TransitionBoundary.joins(previous, clip))) return model;
    if (transition == null && clip.transitionIn == null) return model;
    // Only undo a placement change when this is still the original joined pair.
    final restoreJoin = TransitionBoundary.overlaps(previous, clip);
    final safeTransition = transition == null
        ? null
        : ClipTransition(
            type: transition.type,
            duration: math
                .min(
                  transition.duration,
                  math.min(
                          previous.duration /
                              (programTime
                                  ? 1
                                  : previous.resolvedPlaybackSpeed()),
                          clip.duration /
                              (programTime
                                  ? 1
                                  : clip.resolvedPlaybackSpeed())) *
                      (programTime ? 1 : clip.resolvedPlaybackSpeed()) *
                      0.49,
                )
                .clamp(0, 5)
                .toDouble(),
          );
    if (safeTransition?.type == clip.transitionIn?.type &&
        safeTransition?.duration == clip.transitionIn?.duration) return model;
    final start = safeTransition == null
        ? (restoreJoin ? previous.timelineEnd : clip.timelineStart)
        : previous.timelineEnd - safeTransition.duration;
    final nextStart = math.max(0, start).toDouble();
    final tracks = [
      for (final track in model.tracks)
        if (track.id == result.track.id)
          track.copyWith(
            clips: [
              for (final item in track.clips)
                if (item.id == clipId)
                  item.copyWith(
                    timelineStart: nextStart,
                    transitionIn: safeTransition,
                    clearTransitionIn: safeTransition == null,
                  )
                else
                  item,
            ],
          )
        else if (track.type == TrackType.audio && !track.isLocked)
          track.copyWith(
            clips: [
              for (final item in track.clips)
                if (item.isLinkedAudio && item.linkedClipId == clip.id)
                  item.copyWith(
                    timelineStart: nextStart,
                    transitionIn: safeTransition,
                    clearTransitionIn: safeTransition == null,
                  )
                else
                  item,
            ],
          )
        else
          track,
    ];
    return model.copyWith(tracks: tracks, duration: model.duration);
  }

  TimelineModel setClipKeyframe(
    TimelineModel model,
    String clipId,
    ClipKeyframe keyframe,
  ) {
    final result = model.clipById(clipId);
    if (result == null || result.track.isLocked) return model;
    final safe = ClipKeyframe(
      offset: keyframe.offset.clamp(0, result.clip.duration).toDouble(),
      transform: keyframe.transform,
    );
    final keyframes = [
      for (final item in result.clip.keyframes)
        if ((item.offset - safe.offset).abs() >= 0.03) item,
      safe,
    ]..sort((a, b) => a.offset.compareTo(b.offset));
    return updateTrack(
      model,
      result.track.id,
      (track) => track.copyWith(
        clips: [
          for (final clip in track.clips)
            if (clip.id == clipId)
              clip.copyWith(keyframes: keyframes)
            else
              clip,
        ],
      ),
    );
  }

  TimelineModel removeClipKeyframe(
    TimelineModel model,
    String clipId,
    double offset,
  ) {
    final result = model.clipById(clipId);
    if (result == null || result.track.isLocked) return model;
    return updateTrack(
      model,
      result.track.id,
      (track) => track.copyWith(
        clips: [
          for (final clip in track.clips)
            if (clip.id == clipId)
              clip.copyWith(
                keyframes: clip.keyframes
                    .where((item) => (item.offset - offset).abs() >= 0.08)
                    .toList(),
              )
            else
              clip,
        ],
      ),
    );
  }

  TimelineModel resizeClip(
    TimelineModel model, {
    required String clipId,
    required bool startEdge,
    required double deltaSeconds,
  }) {
    final result = model.clipById(clipId);
    if (result == null || result.track.isLocked) return model;
    if (programTime && result.track.type != TrackType.text) {
      final clip = result.clip;
      final speed = clip.resolvedPlaybackSpeed();
      if (startEdge) {
        deltaSeconds = math.max(deltaSeconds, -clip.sourceStart / speed);
      } else {
        final sourceDuration = sourceDurations[clip.mediaPath];
        if (sourceDuration != null) {
          deltaSeconds = math.min(deltaSeconds,
              (sourceDuration - clip.sourceStart) / speed - clip.duration);
        }
      }
    }
    if (result.track.type == TrackType.video &&
        _linkedAudioTrackLocked(model, clipId)) return model;
    if (result.track.type == TrackType.video &&
        result.track.id == model.videoTracks.firstOrNull?.id) {
      final removedSeconds = startEdge ? deltaSeconds : -deltaSeconds;
      return magneticTrackResolver.rippleTrim(
        timeline: model,
        clipId: clipId,
        deltaDuration: Duration(
          microseconds: (removedSeconds * 1000000).round(),
        ),
        edge: startEdge ? TrimEdge.start : TrimEdge.end,
      );
    }
    final clip = result.clip;
    const minimumDuration = 0.15;
    var start = clip.timelineStart;
    var duration = clip.duration;
    var sourceStart = clip.sourceStart;
    if (startEdge) {
      final delta = deltaSeconds.clamp(-start, duration - minimumDuration);
      start += delta;
      duration -= delta;
      if (result.track.type != TrackType.text) {
        sourceStart += delta * (programTime ? clip.resolvedPlaybackSpeed() : 1);
      }
    } else {
      duration = math.max(minimumDuration, duration + deltaSeconds).toDouble();
    }
    final linkedAudioId = result.track.type == TrackType.video
        ? model.linkedAudioForVideo(clip.id)?.id
        : null;
    final titleKeyframes = result.track.type == TrackType.text &&
            startEdge &&
            clip.keyframes.isNotEmpty
        ? <ClipKeyframe>[
            ClipKeyframe(
                offset: 0,
                transform: clip.transformAt(start - clip.timelineStart)),
            for (final frame in clip.keyframes)
              if (frame.offset > start - clip.timelineStart)
                ClipKeyframe(
                    offset: frame.offset - (start - clip.timelineStart),
                    transform: frame.transform),
          ]
        : clip.keyframes;
    return model.copyWith(
      tracks: [
        for (final track in model.tracks)
          if (track.id == result.track.id)
            track.copyWith(
              clips: [
                for (final item in track.clips)
                  if (item.id == clipId)
                    item.copyWith(
                      timelineStart: start,
                      duration: duration,
                      sourceStart: math.max(0, sourceStart).toDouble(),
                      keyframes: titleKeyframes,
                      textAnimationOffset: result.track.type == TrackType.text
                          ? clip.textAnimationOffset +
                              start -
                              clip.timelineStart
                          : clip.textAnimationOffset,
                    )
                  else
                    item,
              ],
            )
          else if (linkedAudioId != null && track.type == TrackType.audio)
            track.copyWith(
              clips: [
                for (final item in track.clips)
                  if (item.id == linkedAudioId)
                    item.copyWith(
                      timelineStart: start,
                      duration: duration,
                      sourceStart: math.max(0, sourceStart).toDouble(),
                    )
                  else
                    item,
              ],
            )
          else
            track,
      ],
    );
  }

  TimelineSnapResult snapTime(
    TimelineModel model, {
    required String movingClipId,
    required double proposedStart,
    required double clipDuration,
    double? playhead,
    List<double> markers = const [],
  }) {
    final candidates = <double>{0, ...markers};
    if (playhead != null) candidates.add(playhead);
    for (final track in model.tracks) {
      for (final clip in track.clips) {
        if (clip.id == movingClipId) continue;
        candidates
          ..add(clip.timelineStart)
          ..add(clip.timelineEnd);
      }
    }
    var bestStart = math.max(0, proposedStart).toDouble();
    double? guide;
    var bestDistance = snapThreshold;
    for (final candidate in candidates) {
      final startDistance = (proposedStart - candidate).abs();
      if (startDistance <= bestDistance) {
        bestDistance = startDistance;
        bestStart = candidate;
        guide = candidate;
      }
      final proposedEnd = proposedStart + clipDuration;
      final endDistance = (proposedEnd - candidate).abs();
      if (endDistance <= bestDistance) {
        bestDistance = endDistance;
        bestStart = candidate - clipDuration;
        guide = candidate;
      }
    }
    return TimelineSnapResult(
      time: math.max(0, bestStart).toDouble(),
      guideTime: guide,
    );
  }
}
