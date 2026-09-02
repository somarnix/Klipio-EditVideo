import 'dart:math' as math;

abstract final class TimecodeFormatter {
  static String format(Duration value, {double frameRate = 30}) {
    final safeMicros = math.max(0, value.inMicroseconds);
    final totalSeconds = safeMicros ~/ Duration.microsecondsPerSecond;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds ~/ 60) % 60;
    final seconds = totalSeconds % 60;
    final frame = ((safeMicros % Duration.microsecondsPerSecond) /
            Duration.microsecondsPerSecond *
            frameRate)
        .floor()
        .clamp(0, math.max(0, frameRate.ceil() - 1));
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}:'
        '${frame.toString().padLeft(2, '0')}';
  }

  static Duration parse(String value, {double frameRate = 30}) {
    final parts = value.trim().split(':');
    if (parts.length != 4 || frameRate <= 0) return Duration.zero;
    final numbers = parts.map(int.tryParse).toList(growable: false);
    if (numbers.any((number) => number == null)) return Duration.zero;
    final hours = math.max(0, numbers[0]!);
    final minutes = numbers[1]!.clamp(0, 59);
    final seconds = numbers[2]!.clamp(0, 59);
    final frames = math.max(0, numbers[3]!);
    final micros = (((hours * 3600 + minutes * 60 + seconds) * 1000000) +
            frames / frameRate * 1000000)
        .round();
    return Duration(microseconds: micros);
  }
}
