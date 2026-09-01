class SrtEntry {
  const SrtEntry({
    required this.startMicroseconds,
    required this.endMicroseconds,
    required this.text,
  });

  final int startMicroseconds;
  final int endMicroseconds;
  final String text;
}

String buildSrtDocument(Iterable<SrtEntry> entries) {
  final ordered = entries.toList()
    ..sort(
      (first, second) =>
          first.startMicroseconds.compareTo(second.startMicroseconds),
    );
  final buffer = StringBuffer();
  for (var index = 0; index < ordered.length; index++) {
    final entry = ordered[index];
    buffer
      ..writeln(index + 1)
      ..writeln(
        '${formatSrtTimestamp(entry.startMicroseconds)} --> '
        '${formatSrtTimestamp(entry.endMicroseconds)}',
      )
      ..writeln(entry.text)
      ..writeln();
  }
  return buffer.toString();
}

String formatSrtTimestamp(int microseconds) {
  final milliseconds = (microseconds.clamp(0, 1 << 62) / 1000).round();
  final hours = milliseconds ~/ 3600000;
  final minutes = (milliseconds ~/ 60000) % 60;
  final seconds = (milliseconds ~/ 1000) % 60;
  final remainder = milliseconds % 1000;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')},'
      '${remainder.toString().padLeft(3, '0')}';
}
