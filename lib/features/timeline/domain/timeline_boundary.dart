/// Arithmetic noise only, not a frame tolerance or native-player workaround.
/// A real microsecond/millisecond gap remains a gap.
abstract final class TimelineBoundary {
  static bool atOrAfter(double time, double boundary) =>
      time.isFinite &&
      boundary.isFinite &&
      (time >= boundary || adjacent(boundary, time));

  static bool adjacent(double precedingEnd, double followingStart) =>
      precedingEnd.isFinite &&
      followingStart.isFinite &&
      (followingStart - precedingEnd).abs() < 1e-12;
}
