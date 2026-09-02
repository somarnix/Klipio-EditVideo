/// Compatibility policy for polling the native video player. This is NOT
/// timeline membership: the mapper/render scene still use exact [start, end).
///
/// The current native preview loops and can wrap without a terminal completion
/// tick. Preserve the historical 100ms SOURCE-time lookahead until the native
/// adapter supplies reliable, seek-correlated completion events. At 2x this is
/// 50ms of program time; it must never alter saved trims or exported duration.
/// Completion alone is deliberately insufficient (it may belong to an old seek).
abstract final class BackendClipEndPolicy {
  static const sourceLookaheadSeconds = 0.1;

  static bool shouldAdvance({
    required double sourceSeconds,
    required double sourceStart,
    required double sourceEnd,
    required bool isPlaying,
    required bool hasError,
    required bool seekPending,
  }) {
    if (!isPlaying ||
        hasError ||
        seekPending ||
        !sourceSeconds.isFinite ||
        !sourceStart.isFinite ||
        !sourceEnd.isFinite ||
        sourceEnd <= sourceStart) return false;
    // Do not advance before entering a very short clip, or after loop wrap
    // into an unrelated source range.
    return sourceSeconds >= sourceStart &&
        sourceSeconds >= sourceEnd - sourceLookaheadSeconds;
  }
}
