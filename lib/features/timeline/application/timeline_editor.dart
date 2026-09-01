import 'dart:math' as math;

import '../domain/timeline_models.dart';

class TimelineSnapResult {
  const TimelineSnapResult({required this.time, this.guideTime});

  final double time;
  final double? guideTime;

  bool get snapped => guideTime != null;
}

class TimelineEditor {
  const TimelineEditor({this.snapThreshold = 0.12});

  final double snapThreshold;

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

  TimelineModel splitClip(
    TimelineModel model, {
    required String clipId,
    required double playhead,
  }) {
    final result = model.clipById(clipId);
    if (result == null || result.track.isLocked) return model;
    final clip = result.clip;
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
      keyframes: clip.keyframes
          .where((keyframe) => keyframe.offset <= firstDuration)
          .toList(),
    );
    final second = clip.copyWith(
      id: '${clip.id}-b-${(playhead * 1000).round()}',
      timelineStart: playhead,
      sourceStart: clip.sourceStart + firstDuration,
      duration: secondDuration,
      replacesClipId: clip.replacesClipId ?? clip.id,
      clearTransitionIn: true,
      keyframes: [
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
                      sourceStart: item.sourceStart + firstDuration,
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
        final start = clip.timelineStart >= result.clip.timelineEnd - 0.001
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
    final ordered = [...result.track.clips]
      ..sort((a, b) => a.timelineStart.compareTo(b.timelineStart));
    final index = ordered.indexWhere((clip) => clip.id == clipId);
    if (index <= 0) return model;
    final previous = ordered[index - 1];
    final clip = ordered[index];
    final safeTransition = transition == null
        ? null
        : ClipTransition(
            type: transition.type,
            duration: math
                .min(
                  transition.duration,
                  math.min(previous.duration, clip.duration) * 0.49,
                )
                .clamp(0.05, 5)
                .toDouble(),
          );
    final start = safeTransition == null
        ? previous.timelineEnd
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
    return model.copyWith(tracks: tracks);
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
    final clip = result.clip;
    const minimumDuration = 0.15;
    var start = clip.timelineStart;
    var duration = clip.duration;
    var sourceStart = clip.sourceStart;
    if (startEdge) {
      final delta = deltaSeconds.clamp(-start, duration - minimumDuration);
      start += delta;
      duration -= delta;
      if (result.track.type != TrackType.text) sourceStart += delta;
    } else {
      duration = math.max(minimumDuration, duration + deltaSeconds).toDouble();
    }
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
                  if (item.id == clipId)
                    item.copyWith(
                      timelineStart: start,
                      duration: duration,
                      sourceStart: math.max(0, sourceStart).toDouble(),
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
