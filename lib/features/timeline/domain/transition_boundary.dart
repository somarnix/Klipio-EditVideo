import 'timeline_boundary.dart';
import 'timeline_models.dart';

/// Same-track transition ownership: exact join, or an explicit incoming
/// transition whose interval ends at the predecessor's end. Not arbitrary overlap.
abstract final class TransitionBoundary {
  static bool overlaps(ClipModel previous, ClipModel incoming) {
    final transition = incoming.transitionIn;
    return transition != null &&
        transition.duration.isFinite &&
        transition.duration > 0 &&
        incoming.timelineStart < previous.timelineEnd &&
        TimelineBoundary.adjacent(
            previous.timelineEnd, incoming.timelineStart + transition.duration);
  }

  static bool joins(ClipModel previous, ClipModel incoming) =>
      TimelineBoundary.adjacent(previous.timelineEnd, incoming.timelineStart) ||
      overlaps(previous, incoming);
  static double progress(ClipModel clip, double time) {
    final duration = clip.transitionIn?.duration;
    if (duration == null || !duration.isFinite || duration <= 0) return 1;
    return ((time - clip.timelineStart) / duration).clamp(0, 1).toDouble();
  }
}
