import 'dart:async';

import 'package:flutter/foundation.dart';

typedef TimelineSeekRequest = Future<void> Function(
  Duration position,
  bool exact,
);

/// Isolates high-frequency playhead motion from the editor widget tree.
///
/// Drag updates publish immediately through [playhead] but allow only one
/// approximate seek at a time. Intermediate requests are coalesced. Releasing
/// the pointer waits for that work and performs one exact final seek.
class TimelineScrubController {
  TimelineScrubController({
    required this.onSeek,
    this.minimumSeekInterval = const Duration(milliseconds: 16),
    Duration initialPosition = Duration.zero,
  }) : playhead = ValueNotifier<Duration>(initialPosition);

  final TimelineSeekRequest onSeek;
  final Duration minimumSeekInterval;
  final ValueNotifier<Duration> playhead;

  bool _scrubbing = false;
  bool _seekInFlight = false;
  bool _disposed = false;
  Duration? _pendingApproximate;
  DateTime? _lastSeekStarted;
  Timer? _throttleTimer;
  Completer<void>? _idleCompleter;

  bool get isScrubbing => _scrubbing;

  void setExternalPosition(Duration position) {
    if (_disposed || _scrubbing) return;
    playhead.value = _safe(position);
  }

  void begin(Duration position) {
    if (_disposed) return;
    _scrubbing = true;
    update(position);
  }

  void update(Duration position) {
    if (_disposed) return;
    final safe = _safe(position);
    playhead.value = safe;
    _pendingApproximate = safe;
    _scheduleApproximate();
  }

  Future<void> end(Duration position) async {
    if (_disposed) return;
    final safe = _safe(position);
    playhead.value = safe;
    _scrubbing = false;
    _pendingApproximate = null;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    await _waitForIdle();
    if (!_disposed) await onSeek(safe, true);
  }

  void _scheduleApproximate() {
    if (_seekInFlight || _disposed) return;
    final elapsed = _lastSeekStarted == null
        ? minimumSeekInterval
        : DateTime.now().difference(_lastSeekStarted!);
    final wait = minimumSeekInterval - elapsed;
    if (wait <= Duration.zero) {
      _dispatchApproximate();
      return;
    }
    _throttleTimer ??= Timer(wait, () {
      _throttleTimer = null;
      _dispatchApproximate();
    });
  }

  void _dispatchApproximate() {
    if (_seekInFlight || _disposed) return;
    final target = _pendingApproximate;
    if (target == null) return;
    _pendingApproximate = null;
    _seekInFlight = true;
    _lastSeekStarted = DateTime.now();
    _idleCompleter ??= Completer<void>();
    unawaited(
      onSeek(target, false).whenComplete(() {
        _seekInFlight = false;
        final idle = _idleCompleter;
        if (_pendingApproximate == null) {
          _idleCompleter = null;
          if (idle != null && !idle.isCompleted) idle.complete();
        } else {
          _scheduleApproximate();
        }
      }),
    );
  }

  Future<void> _waitForIdle() async {
    while (_seekInFlight) {
      final idle = _idleCompleter;
      if (idle == null) return;
      await idle.future;
    }
  }

  Duration _safe(Duration value) => value.isNegative ? Duration.zero : value;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _throttleTimer?.cancel();
    playhead.dispose();
  }
}
