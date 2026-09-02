import 'dart:math' as math;
import 'package:characters/characters.dart';
import '../../export/domain/export_models.dart';
import '../../timeline/domain/timeline_models.dart';
import '../../timeline/domain/keyframe_curve.dart';

/// Project-space composition, never wall clock, device ratio or widget state.
/// Position is the layout anchor plus the centered clip-transform offset.
class TitleVisualState {
  const TitleVisualState(
      {required this.active,
      required this.text,
      required this.x,
      required this.y,
      required this.scaleX,
      required this.scaleY,
      required this.rotation,
      required this.opacity,
      required this.phase,
      required this.lineWidth});
  final bool active;
  final String text;
  final double x, y, scaleX, scaleY, rotation, opacity, phase, lineWidth;
  List<Object> get compositionKey =>
      [active, text, x, y, scaleX, scaleY, rotation, opacity, lineWidth];
}

abstract final class TitleTimelineResolver {
  static TitleVisualState resolve(TextOverlaySettings title, double time) {
    final local = time - title.timelineStart;
    final active = title.visible &&
        local >= 0 &&
        (title.timelineEnd <= 0 || time < title.timelineEnd);
    final phase = title.animationDuration <= 0
        ? 1.0
        : KeyframeCurve.progress(
            local + title.animationOffset, 0, title.animationDuration);
    final eased = 1 - math.pow(1 - phase, 3).toDouble();
    var opacity = 1.0, scale = 1.0, x = title.x, y = title.y, line = 0.0;
    var text = title.text;
    final animation = title.animation.replaceAll('-', ' ');
    switch (animation) {
      case 'fade in':
        opacity = phase;
      case 'fade out':
        opacity = 1 - phase;
      case 'flow up':
      case 'flow down':
      case 'flow left':
      case 'flow right':
        x = title.startX + (title.x - title.startX) * eased;
        y = title.startY + (title.y - title.startY) * eased;
        opacity = eased;
      case 'pop up line':
        opacity = eased;
        scale = .7 + .3 * eased;
        line = eased;
      case 'pulse':
        final pulse = phase < .5 ? phase * 2 : (1 - phase) * 2;
        opacity = .72 + .28 * pulse;
        scale = .96 + .04 * pulse;
      case 'text typing':
        text = text.characters
            .take((text.characters.length * phase).ceil())
            .toString();
    }
    final clip = ClipModel(
        id: title.id,
        mediaPath: title.id,
        timelineStart: title.timelineStart,
        duration: math.max(0, title.timelineEnd - title.timelineStart),
        sourceStart: 0,
        zIndex: 0,
        transform: title.transform,
        keyframes: title.keyframes);
    final transform = clip.transformAt(local);
    return TitleVisualState(
        active: active,
        text: text,
        x: x + transform.positionX - .5,
        y: y + transform.positionY - .5,
        scaleX: transform.scaleX * scale,
        scaleY: transform.scaleY * scale,
        rotation:
            transform.rotationDegrees * math.pi / 180 + title.curve / 100 * .12,
        opacity: (transform.opacity * opacity).clamp(0, 1),
        phase: phase,
        lineWidth: line);
  }

  static TextOverlaySettings bind(
      TextOverlaySettings title, TimelineModel timeline) {
    final location = timeline.clipById(title.id);
    if (location == null || location.track.type != TrackType.text) {
      return title.withComposition();
    }
    final clip = location.clip;
    return title.withComposition(
        transform: clip.transform,
        keyframes: clip.keyframes,
        start: clip.timelineStart,
        end: clip.timelineEnd,
        animationOffset:
            clip.textAnimationOffset / clip.resolvedPlaybackSpeed(1),
        animationDuration:
            title.animationDuration / clip.resolvedPlaybackSpeed(1));
  }
}
