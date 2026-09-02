/// Shared scalar interpolation contract. Times are clip-local seconds.
abstract final class KeyframeCurve {
  static double span(double start, double end) => end > start ? end - start : 1;

  static double progress(double time, double start, double end) =>
      ((time - start) / span(start, end)).clamp(0.0, 1.0);

  static String ffmpeg(List<({double time, double value})> points,
      {double timelineOffset = 0, String clock = 't'}) {
    final sorted = [...points]..sort((a, b) => a.time.compareTo(b.time));
    String n(double value) =>
        value.toStringAsFixed(9).replaceFirst(RegExp(r'\.?0+$'), '');
    String segment(int index) {
      final left = sorted[index];
      if (index == sorted.length - 1) return n(left.value);
      final right = sorted[index + 1];
      final start = left.time + timelineOffset;
      final end = right.time + timelineOffset;
      final interpolation = '${n(left.value)}+(${n(right.value - left.value)})*'
          '(($clock-${n(start)})/${n(span(left.time, right.time))})';
      return 'if(lt($clock\\,${n(start)})\\,${n(left.value)}\\,'
          'if(lt($clock\\,${n(end)})\\,$interpolation\\,${segment(index + 1)}))';
    }

    return segment(0);
  }
}
