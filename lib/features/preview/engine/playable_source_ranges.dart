/// Edit membership is exact and half-open. Backend seek accuracy must not
/// shorten the user's retained source ranges.
abstract final class PlayableSourceRanges {
  /// A paused near-end frame is not EOF. Completion is reported by the
  /// backend, with an exact endpoint fallback for adapters without that event.
  static bool hasCompleted(
          {required Duration position,
          required Duration duration,
          required bool isPlaying,
          required bool backendCompleted}) =>
      !isPlaying &&
      duration > Duration.zero &&
      (backendCompleted || position >= duration);

  static bool contains(
          double seconds, List<({double start, double end})> ranges) =>
      ranges.any((range) => seconds >= range.start && seconds < range.end);

  /// Returns the current position, the next retained start, or null at end.
  static double? resolve(
      double seconds, List<({double start, double end})> ranges) {
    if (contains(seconds, ranges)) return seconds;
    for (final range in ranges) {
      if (seconds < range.start && range.end > range.start) return range.start;
    }
    return null;
  }
}
