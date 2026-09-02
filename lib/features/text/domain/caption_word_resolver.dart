import 'package:characters/characters.dart';
import 'text_case.dart';

/// UTF-16 ranges in the displayed cue. Timing is half-open; text remains whole
/// during shaping. Unmatched or partial-grapheme recognition tokens are ignored.
abstract final class CaptionWordResolver {
  static List<({int start, int end})> resolve(
      {required String text,
      required double cueStart,
      required double cueEnd,
      required double time,
      required Iterable<({String text, double start, double end})> words,
      String textCase = 'none'}) {
    if (time < cueStart || time >= cueEnd) return const [];
    final displayed = applyTextCase(text, textCase);
    final boundaries = <int>{0};
    var offset = 0;
    for (final cluster in displayed.characters) {
      offset += cluster.length;
      boundaries.add(offset);
    }
    var cursor = 0;
    final ranges = <({int start, int end})>[];
    for (final word in words) {
      final token = applyTextCase(word.text, textCase);
      if (token.isEmpty) continue;
      final start = displayed.indexOf(token, cursor);
      if (start < 0) continue;
      final end = start + token.length;
      cursor = end;
      if (time >= word.start &&
          time < word.end &&
          boundaries.contains(start) &&
          boundaries.contains(end)) {
        ranges.add((start: start, end: end));
      }
    }
    return List.unmodifiable(ranges);
  }
}
