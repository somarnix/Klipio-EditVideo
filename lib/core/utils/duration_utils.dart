import 'dart:math' as math;

String formatEditorTimecode(
  Duration duration, {
  double frameRate = 30,
  bool includeFrames = true,
}) {
  final totalMilliseconds = math.max(0, duration.inMilliseconds);
  final hours = totalMilliseconds ~/ Duration.millisecondsPerHour;
  final minutes = (totalMilliseconds ~/ Duration.millisecondsPerMinute) % 60;
  final seconds = (totalMilliseconds ~/ Duration.millisecondsPerSecond) % 60;
  final frames = ((totalMilliseconds % 1000) * frameRate / 1000).floor();
  final base = '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
  return includeFrames ? '$base:${frames.toString().padLeft(2, '0')}' : base;
}

Duration durationFromSeconds(num seconds) =>
    Duration(microseconds: (math.max(0, seconds) * 1000000).round());
