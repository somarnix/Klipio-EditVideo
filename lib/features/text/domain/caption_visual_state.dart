import 'dart:math' as math;
import 'package:characters/characters.dart';
import 'text_case.dart';

class CaptionTimedWord {
  const CaptionTimedWord(
      {required this.id,
      required this.text,
      required this.start,
      required this.end,
      this.rangeStart,
      this.rangeEnd});
  final String id, text;
  final double start, end;
  final int? rangeStart, rangeEnd;
}

typedef CaptionWordVisual = ({
  String id,
  int start,
  int end,
  double phase,
  double scale,
  double offsetY
});

/// Pure editing meaning. Geometry is supplied by the shaped paragraph adapter;
/// offsets are in font-em units, never monitor pixels or wall-clock time.
class CaptionVisualState {
  CaptionVisualState(
      {required this.cueId,
      required this.text,
      required this.active,
      required this.motion,
      required List<CaptionWordVisual> words})
      : words = List.unmodifiable(words);
  final String cueId, text, motion;
  final bool active;
  final List<CaptionWordVisual> words;
  List<({int start, int end})> get ranges => List.unmodifiable(
      [for (final word in words) (start: word.start, end: word.end)]);
}

/// Captures word identity/ranges once. Only the explicit legacy binding step
/// below matches token text; resolving a timestamp never searches strings.
class CaptionTimelineResolver {
  CaptionTimelineResolver(
      {required this.cueId,
      required String text,
      required this.start,
      required this.end,
      required Iterable<CaptionTimedWord> words,
      this.motion = 'highlight',
      String textCase = 'none'})
      : text = applyTextCase(text, textCase) {
    final boundaries = <int>{0};
    var offset = 0;
    for (final cluster in this.text.characters) {
      offset += cluster.length;
      boundaries.add(offset);
    }
    var cursor = 0;
    final bound = <({CaptionTimedWord word, int start, int end})>[];
    for (final word in words) {
      final token = applyTextCase(word.text, textCase);
      // Compatibility for captions without stored displayed-text ranges.
      final a = word.rangeStart ??
          (token.isEmpty ? -1 : this.text.indexOf(token, cursor));
      final b = word.rangeEnd ?? (a + token.length);
      if (a < 0 || b <= a || b > this.text.length) continue;
      cursor = b;
      if (!boundaries.contains(a) || !boundaries.contains(b)) continue;
      bound.add((word: word, start: a, end: b));
    }
    _words = List.unmodifiable(bound);
  }
  final String cueId, text, motion;
  final double start, end;
  late final List<({CaptionTimedWord word, int start, int end})> _words;
  Map<String, ({int start, int end})> get wordRangesById => Map.unmodifiable({
        for (final entry in _words)
          entry.word.id: (start: entry.start, end: entry.end)
      });

  CaptionVisualState resolve(double time) {
    final active = time.isFinite && time >= start && time < end;
    return CaptionVisualState(
        cueId: cueId,
        text: text,
        active: active,
        motion: motion,
        words: [
          if (active)
            for (final entry in _words)
              if (time >= entry.word.start && time < entry.word.end)
                _visual(entry, time)
        ]);
  }

  CaptionWordVisual _visual(
      ({CaptionTimedWord word, int start, int end}) entry, double time) {
    final phase =
        (time - entry.word.start) / (entry.word.end - entry.word.start);
    // A symmetric pulse replaces wall-clock AnimatedScale. Peak preserves the
    // old 1.18 scale / -0.12 em bounce, and seeking is deterministic.
    final pulse = math.sin(math.pi * phase);
    final animated = motion == 'bounce' || motion == 'pop';
    return (
      id: entry.word.id,
      start: entry.start,
      end: entry.end,
      phase: phase,
      scale: animated ? 1 + .18 * pulse : 1,
      offsetY: motion == 'bounce' ? -.12 * pulse : 0
    );
  }
}
