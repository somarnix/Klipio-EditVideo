class SilenceRange {
  const SilenceRange({required this.start, required this.end});
  final double start;
  final double end;
  double get duration => end - start;
}

class SilenceRemover {
  const SilenceRemover();

  List<SilenceRange> parse(String ffmpegOutput) {
    final starts = RegExp(r'silence_start:\s*([0-9.]+)')
        .allMatches(ffmpegOutput)
        .map((match) => double.parse(match.group(1)!))
        .toList();
    final ends = RegExp(r'silence_end:\s*([0-9.]+)')
        .allMatches(ffmpegOutput)
        .map((match) => double.parse(match.group(1)!))
        .toList();
    return [
      for (var index = 0; index < starts.length && index < ends.length; index++)
        if (ends[index] > starts[index])
          SilenceRange(start: starts[index], end: ends[index]),
    ];
  }

  String filter({double decibels = -35, double minimumDuration = 0.35}) =>
      'silencedetect=noise=${decibels.toStringAsFixed(1)}dB:'
      'd=${minimumDuration.toStringAsFixed(3)}';
}
