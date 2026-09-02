import '../../timeline/domain/timeline_models.dart';
import '../../timeline/domain/clip_speed_edit.dart';

/// Settings-dialog transaction. Reject all targets together when a selected
/// change would touch a locked video or its linked audio. Detached audio is
/// never included. Speed remains owned by the existing clip-instance command.
TimelineModel? applyVideoSettingsBatch({
  required TimelineModel timeline,
  required VideoRenderSettings settings,
  required Set<String> targetClipIds,
  required bool copySpeed,
  required bool copyFrame,
  required bool copyAudio,
  required bool copyCanvas,
}) {
  if (timeline.tracks.any((track) =>
      track.isLocked &&
      track.clips.any((clip) =>
          targetClipIds.contains(clip.id) ||
          ((copySpeed || copyAudio) &&
              clip.isLinkedAudio &&
              targetClipIds.contains(clip.linkedClipId))))) return null;
  final timed = copySpeed
      ? ClipSpeedEdit.apply(timeline, targetClipIds, settings.speed)
      : timeline;
  return applyVideoRenderSettingsToClipIds(
    timeline: timed,
    settings: settings,
    targetClipIds: targetClipIds,
    copyFrame: copyFrame,
    copyAudio: copyAudio,
    copyCanvas: copyCanvas,
  );
}

/// Immutable render settings for one imported video.
///
/// The editor may expose separate scale and zoom controls, but rendering uses
/// one resolved [transform]. Capturing that resolved value here prevents a
/// later inspector selection from changing what preview, apply-to-many, or
/// export sees.
class VideoRenderSettings {
  const VideoRenderSettings({
    required this.mediaPath,
    required this.speed,
    required this.originalVolume,
    required this.transform,
  });

  final String mediaPath;
  final double speed;
  final double originalVolume;
  final ClipTransform transform;

  VideoRenderSettings copyWith({
    String? mediaPath,
    double? speed,
    double? originalVolume,
    ClipTransform? transform,
  }) {
    return VideoRenderSettings(
      mediaPath: mediaPath ?? this.mediaPath,
      speed: speed ?? this.speed,
      originalVolume: originalVolume ?? this.originalVolume,
      transform: transform ?? this.transform,
    );
  }
}

/// Applies a captured video setting snapshot to every matching timeline clip.
///
/// Locked tracks remain untouched. Video and linked source-audio clips are
/// updated together, so batch application cannot leave picture and sound in
/// different states.
TimelineModel applyVideoRenderSettings({
  required TimelineModel timeline,
  required VideoRenderSettings settings,
  bool copyFrame = true,
  bool copyAudio = true,
  bool copyCanvas = true,
}) {
  final tracks = <TrackModel>[
    for (final track in timeline.tracks)
      if (track.isLocked)
        track
      else
        track.copyWith(
          clips: [
            for (final clip in track.clips)
              if (clip.mediaPath != settings.mediaPath)
                clip
              else if (track.type == TrackType.video)
                clip.copyWith(
                  transform: clip.transform.copyWith(
                    scaleX: copyFrame
                        ? settings.transform.scaleX
                        : clip.transform.scaleX,
                    scaleY: copyFrame
                        ? settings.transform.scaleY
                        : clip.transform.scaleY,
                    positionX: copyFrame
                        ? settings.transform.positionX
                        : clip.transform.positionX,
                    positionY: copyFrame
                        ? settings.transform.positionY
                        : clip.transform.positionY,
                    flip: copyFrame
                        ? settings.transform.flip
                        : clip.transform.flip,
                    rotationDegrees: copyFrame
                        ? settings.transform.rotationDegrees
                        : clip.transform.rotationDegrees,
                    canvasMode: copyCanvas
                        ? settings.transform.canvasMode
                        : clip.transform.canvasMode,
                    canvasColor: copyCanvas
                        ? settings.transform.canvasColor
                        : clip.transform.canvasColor,
                    canvasPattern: copyCanvas
                        ? settings.transform.canvasPattern
                        : clip.transform.canvasPattern,
                    canvasBlur: copyCanvas
                        ? settings.transform.canvasBlur
                        : clip.transform.canvasBlur,
                  ),
                )
              else if (track.type == TrackType.audio &&
                  copyAudio &&
                  clip.isLinkedAudio)
                clip.copyWith(volume: settings.originalVolume)
              else
                clip,
          ],
        ),
  ];
  return timeline.copyWith(
    tracks: tracks,
    duration: TimelineModel.calculateDuration(tracks),
  );
}

/// Applies one captured snapshot to exact timeline video clips.
///
/// This is used by the contextual multi-selection toolbar. Unlike
/// [applyVideoRenderSettings], it never changes another split merely because
/// that split points at the same media file. Linked source audio follows its
/// owning video clip; unrelated music and locked tracks remain unchanged.
TimelineModel applyVideoRenderSettingsToClipIds({
  required TimelineModel timeline,
  required VideoRenderSettings settings,
  required Set<String> targetClipIds,
  bool copyFrame = true,
  bool copyAudio = true,
  bool copyCanvas = true,
}) {
  if (targetClipIds.isEmpty) return timeline;
  final editableVideoIds = <String>{
    for (final track in timeline.videoTracks)
      if (!track.isLocked)
        for (final clip in track.clips)
          if (targetClipIds.contains(clip.id)) clip.id,
  };
  final linkedAudioIds = <String>{
    if (copyAudio)
      for (final track in timeline.audioTracks)
        if (!track.isLocked)
          for (final clip in track.clips)
            if (clip.isLinkedAudio &&
                clip.linkedClipId != null &&
                editableVideoIds.contains(clip.linkedClipId))
              clip.id,
  };
  final tracks = <TrackModel>[
    for (final track in timeline.tracks)
      if (track.isLocked)
        track
      else
        track.copyWith(
          clips: [
            for (final clip in track.clips)
              if (track.type == TrackType.video &&
                  editableVideoIds.contains(clip.id))
                clip.copyWith(
                  transform: clip.transform.copyWith(
                    scaleX: copyFrame
                        ? settings.transform.scaleX
                        : clip.transform.scaleX,
                    scaleY: copyFrame
                        ? settings.transform.scaleY
                        : clip.transform.scaleY,
                    positionX: copyFrame
                        ? settings.transform.positionX
                        : clip.transform.positionX,
                    positionY: copyFrame
                        ? settings.transform.positionY
                        : clip.transform.positionY,
                    flip: copyFrame
                        ? settings.transform.flip
                        : clip.transform.flip,
                    rotationDegrees: copyFrame
                        ? settings.transform.rotationDegrees
                        : clip.transform.rotationDegrees,
                    opacity: copyFrame
                        ? settings.transform.opacity
                        : clip.transform.opacity,
                    blendMode: copyFrame
                        ? settings.transform.blendMode
                        : clip.transform.blendMode,
                    canvasMode: copyCanvas
                        ? settings.transform.canvasMode
                        : clip.transform.canvasMode,
                    canvasColor: copyCanvas
                        ? settings.transform.canvasColor
                        : clip.transform.canvasColor,
                    canvasPattern: copyCanvas
                        ? settings.transform.canvasPattern
                        : clip.transform.canvasPattern,
                    canvasBlur: copyCanvas
                        ? settings.transform.canvasBlur
                        : clip.transform.canvasBlur,
                  ),
                )
              else if (track.type == TrackType.audio &&
                  linkedAudioIds.contains(clip.id))
                clip.copyWith(volume: settings.originalVolume)
              else
                clip,
          ],
        ),
  ];
  return timeline.copyWith(
    tracks: tracks,
    duration: TimelineModel.calculateDuration(tracks),
  );
}
