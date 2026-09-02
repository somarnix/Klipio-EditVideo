import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/preview/engine/playable_source_ranges.dart';

void main() {
  test('pause near EOF never masquerades as completion', () {
    const end = Duration(seconds: 10);
    for (final remaining in [250000, 120000, 100000, 1]) {
      expect(
          PlayableSourceRanges.hasCompleted(
              position: end - Duration(microseconds: remaining),
              duration: end,
              isPlaying: false,
              backendCompleted: false),
          isFalse);
    }
    expect(
        PlayableSourceRanges.hasCompleted(
            position: end,
            duration: end,
            isPlaying: false,
            backendCompleted: false),
        isTrue);
    expect(
        PlayableSourceRanges.hasCompleted(
            position: end,
            duration: end,
            isPlaying: true,
            backendCompleted: true),
        isFalse);
    expect(
        PlayableSourceRanges.hasCompleted(
            position: Duration.zero,
            duration: Duration.zero,
            isPlaying: false,
            backendCompleted: true),
        isFalse);
    expect(
        PlayableSourceRanges.hasCompleted(
            position: end - const Duration(milliseconds: 1),
            duration: end,
            isPlaying: false,
            backendCompleted: true),
        isTrue);
  });
  const ranges = [(start: 1.0, end: 2.0), (start: 4.0, end: 5.0)];
  test('retains the final 120ms and excludes exact end', () {
    for (final time in [1.0, 1.5, 1.88, 1.999999]) {
      expect(PlayableSourceRanges.contains(time, ranges), isTrue);
      expect(PlayableSourceRanges.resolve(time, ranges), time);
    }
    expect(PlayableSourceRanges.contains(0.999999, ranges), isFalse);
    expect(PlayableSourceRanges.resolve(0.999999, ranges), 1);
    expect(PlayableSourceRanges.resolve(2, ranges), 4);
    expect(PlayableSourceRanges.resolve(3, ranges), 4);
    expect(PlayableSourceRanges.resolve(5, ranges), isNull);
  });
  test('adjacent ranges do not seek or skip at their shared boundary', () {
    const adjacent = [(start: 0.0, end: 1.0), (start: 1.0, end: 2.0)];
    expect(PlayableSourceRanges.resolve(1, adjacent), 1);
    expect(PlayableSourceRanges.resolve(0, const []), isNull);
  });
}
