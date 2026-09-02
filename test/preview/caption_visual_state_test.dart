import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/text/domain/caption_visual_state.dart';
import 'dart:convert';
import 'package:klipio/features/captions/domain/editable_caption.dart';

void main() {
  test('explicit invalid ranges never rebind after trimming other words', () {
    final resolver = CaptionTimelineResolver(
        cueId: 'trim',
        text: 'Hi Hi',
        start: 0,
        end: 1,
        words: const [
          CaptionTimedWord(
              id: 'invalid',
              text: 'Hi',
              start: 0,
              end: 1,
              rangeStart: -1,
              rangeEnd: -1)
        ]);
    expect(resolver.resolve(.5).words, isEmpty);
  });
  for (final speed in [.5, 1.0, 2.0]) {
    test('trimmed bounce retains phase after retiming at $speed and reopen',
        () {
      final cue = EditableCaptionCue(
          id: 'cue',
          start: .25,
          end: 1,
          text: 'Hi Hi',
          metadata: {
            'animation': {'type': 'bounce'}
          },
          words: [
            EditableCaptionWord(
                id: 'word',
                start: 0,
                end: 1,
                text: 'Hi',
                metadata: {
                  'range': [3, 5]
                })
          ]);
      final reopened = EditableCaptionCue.fromJson(
          jsonDecode(jsonEncode(cue.toJson())) as Map,
          migrationKey: 'ignored');
      CaptionTimelineResolver resolver(EditableCaptionCue c, double rate) =>
          CaptionTimelineResolver(
              cueId: c.id,
              text: c.text,
              start: c.start / rate,
              end: c.end / rate,
              motion: (c.metadata['animation'] as Map)['type'] as String,
              words: c.words.map((w) => CaptionTimedWord(
                  id: w.id,
                  text: w.text,
                  start: w.start / rate,
                  end: w.end / rate,
                  rangeStart: (w.metadata['range'] as List)[0] as int,
                  rangeEnd: (w.metadata['range'] as List)[1] as int)));
      for (final t in [.25, .5, .75, .999999]) {
        final source = resolver(cue, 1).resolve(t).words.single;
        final output =
            resolver(reopened, speed).resolve(t / speed).words.single;
        expect(output, source);
      }
      expect(resolver(reopened, speed).resolve(1 / speed).active, isFalse);
    });
  }
  for (final motion in ['bounce', 'pop']) {
    test('$motion resolves half-open boundaries and symmetric timeline pulse',
        () {
      final resolver = CaptionTimelineResolver(
          cueId: 'cue',
          text: 'Hi Hi',
          start: 1,
          end: 3,
          motion: motion,
          words: const [
            CaptionTimedWord(
                id: 'first',
                text: 'Hi',
                start: 1.25,
                end: 2,
                rangeStart: 0,
                rangeEnd: 2),
            CaptionTimedWord(
                id: 'second',
                text: 'Hi',
                start: 2,
                end: 3,
                rangeStart: 3,
                rangeEnd: 5)
          ]);
      expect(resolver.resolve(.999999).active, isFalse);
      expect(resolver.resolve(1).active, isTrue);
      expect(resolver.resolve(1.249999).words, isEmpty);
      final start = resolver.resolve(1.25).words.single;
      expect(start.id, 'first');
      expect(start.phase, 0);
      expect(start.scale, 1);
      final rising = resolver.resolve(1.4375).words.single;
      final peak = resolver.resolve(1.625).words.single;
      final falling = resolver.resolve(1.8125).words.single;
      expect(rising.phase, .25);
      expect(peak.phase, .5);
      expect(peak.scale, 1.18);
      expect(peak.offsetY, motion == 'bounce' ? -.12 : 0);
      expect(falling.scale, closeTo(rising.scale, 1e-14));
      expect(resolver.resolve(1.999999).words.single.id, 'first');
      expect(resolver.resolve(2).words.single.id, 'second');
      expect(resolver.resolve(2).ranges.single, (start: 3, end: 5));
      expect(resolver.resolve(3).active, isFalse);
      expect(resolver.resolve(3.000001).words, isEmpty);
    });
  }
  test('explicit ranges target repeated words independently of token matching',
      () {
    final resolver = CaptionTimelineResolver(
        cueId: 'trimmed',
        text: 'Hi Hi',
        start: 2,
        end: 3,
        words: const [
          CaptionTimedWord(
              id: 'second',
              text: 'Hi',
              start: 2,
              end: 3,
              rangeStart: 3,
              rangeEnd: 5)
        ]);
    expect(resolver.resolve(2).ranges.single, (start: 3, end: 5));
    expect(resolver.resolve(2).words.single.id, 'second');
  });
  test('Unicode ranges reject partial graphemes and retain short word phase',
      () {
    const text = 'ខ្មែរ e\u0301 👩🏽‍💻';
    final emoji = text.indexOf('👩');
    final resolver = CaptionTimelineResolver(
        cueId: 'unicode',
        text: text,
        start: 0,
        end: 1,
        motion: 'pop',
        words: [
          CaptionTimedWord(
              id: 'emoji',
              text: 'ignored',
              start: 0,
              end: .000002,
              rangeStart: emoji,
              rangeEnd: text.length),
          CaptionTimedWord(
              id: 'invalid',
              text: 'e',
              start: 0,
              end: 1,
              rangeStart: text.indexOf('e'),
              rangeEnd: text.indexOf('e') + 1)
        ]);
    expect(resolver.resolve(.000001).words.single.id, 'emoji');
    expect(resolver.resolve(.000001).words.single.phase, .5);
    expect(resolver.resolve(.000002).words, isEmpty);
  });
  test('resolver captures words and resolved state is immutable', () {
    final words = [
      const CaptionTimedWord(id: 'w', text: 'Hi', start: 0, end: 1)
    ];
    final resolver = CaptionTimelineResolver(
        cueId: 'c',
        text: 'Hi',
        start: 0,
        end: 1,
        words: words,
        motion: 'bounce');
    words.clear();
    final state = resolver.resolve(.5);
    expect(state.words.single.scale, 1.18);
    expect(() => state.words.clear(), throwsUnsupportedError);
  });
}
