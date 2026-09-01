import 'dart:math' as math;

import '../domain/keyframe_track.dart';

class KeyframeInterpolator {
  const KeyframeInterpolator();

  double valueAt(KeyframeTrack track, double time, {double fallback = 0}) {
    if (track.keyframes.isEmpty) return fallback;
    final frames = [...track.keyframes]
      ..sort((a, b) => a.time.compareTo(b.time));
    if (time <= frames.first.time) return frames.first.value;
    if (time >= frames.last.time) return frames.last.value;
    for (var index = 1; index < frames.length; index++) {
      final right = frames[index];
      final left = frames[index - 1];
      if (time > right.time) continue;
      final raw =
          (time - left.time) / math.max(0.000001, right.time - left.time);
      final t = switch (right.interpolation) {
        KeyframeInterpolation.linear => raw,
        KeyframeInterpolation.easeIn => raw * raw,
        KeyframeInterpolation.easeOut => 1 - (1 - raw) * (1 - raw),
        KeyframeInterpolation.easeInOut =>
          raw < 0.5 ? 2 * raw * raw : 1 - math.pow(-2 * raw + 2, 2) / 2,
      };
      return left.value + (right.value - left.value) * t;
    }
    return fallback;
  }
}
