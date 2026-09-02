import '../../timeline/domain/timeline_models.dart';

class CompositionModel {
  const CompositionModel({
    required this.width,
    required this.height,
    required this.frameRate,
    this.backgroundColor = 'black',
  });

  final int width;
  final int height;
  final double frameRate;
  final String backgroundColor;
}

class RenderClipNode {
  const RenderClipNode({
    required this.clipId,
    required this.originalMediaPath,
    required this.sourceSeconds,
    required this.timelineSeconds,
    required this.centerX,
    required this.centerY,
    required this.boxWidth,
    required this.boxHeight,
    required this.rotationDegrees,
    required this.opacity,
    required this.blendMode,
  });

  final String clipId;
  final String originalMediaPath;
  final double sourceSeconds;
  final double timelineSeconds;
  final double centerX;
  final double centerY;
  final double boxWidth;
  final double boxHeight;
  final double rotationDegrees;
  final double opacity;
  final String blendMode;

  double get left => centerX - boxWidth / 2;
  double get top => centerY - boxHeight / 2;
}

class RenderScene {
  const RenderScene({
    required this.composition,
    required this.timelineSeconds,
    required this.clips,
  });

  final CompositionModel composition;
  final double timelineSeconds;
  final List<RenderClipNode> clips;
}

/// Resolves timeline data into stable composition coordinates.
///
/// Preview scales these coordinates to the monitor widget. Export uses the
/// same coordinates directly, so resizing the Flutter window cannot change
/// crop, scale, position, rotation, opacity, or source timing.
abstract final class RenderSceneResolver {
  static RenderScene resolve({
    required TimelineModel timeline,
    required CompositionModel composition,
    required double timelineSeconds,
    Map<String, double> playbackSpeedsByMediaPath = const <String, double>{},
  }) {
    final nodes = <RenderClipNode>[];
    for (final track in timeline.videoTracks) {
      if (track.isMuted) continue;
      for (final clip in track.clips) {
        if (clip.isMuted ||
            timelineSeconds < clip.timelineStart ||
            timelineSeconds >= clip.timelineEnd) {
          continue;
        }
        nodes.add(resolveClip(
          clip: clip,
          composition: composition,
          timelineSeconds: timelineSeconds,
          playbackSpeed: clip.resolvedPlaybackSpeed(
              playbackSpeedsByMediaPath[clip.mediaPath] ?? 1),
        ));
      }
    }
    nodes.sort((left, right) {
      final leftClip = timeline.clipById(left.clipId)!.clip;
      final rightClip = timeline.clipById(right.clipId)!.clip;
      return leftClip.zIndex.compareTo(rightClip.zIndex);
    });
    return RenderScene(
      composition: composition,
      timelineSeconds: timelineSeconds,
      clips: nodes,
    );
  }

  static RenderClipNode resolveClip({
    required ClipModel clip,
    required CompositionModel composition,
    required double timelineSeconds,
    double playbackSpeed = 1,
  }) {
    final local =
        (timelineSeconds - clip.timelineStart).clamp(0.0, clip.duration);
    final transform = clip.transformAt(local);
    return RenderClipNode(
      clipId: clip.id,
      originalMediaPath: clip.mediaPath,
      sourceSeconds: clip.sourceStart + local * playbackSpeed,
      timelineSeconds: timelineSeconds,
      centerX: composition.width * transform.positionX,
      centerY: composition.height * transform.positionY,
      boxWidth: composition.width * transform.scaleX,
      boxHeight: composition.height * transform.scaleY,
      rotationDegrees: transform.rotationDegrees,
      opacity: transform.opacity,
      blendMode: transform.blendMode,
    );
  }
}
