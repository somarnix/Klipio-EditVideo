import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/text/domain/caption_word_resolver.dart';

void main() {
  test('timed word boundaries remain half-open without time offsets', () {
    const words = [
      (text: 'Hello', start: 1.2, end: 1.5),
      (text: 'ខ្មែរ', start: 1.5, end: 1.8)
    ];
    List<({int start, int end})> resolve(double time) =>
        CaptionWordResolver.resolve(
            text: 'Hello ខ្មែរ',
            cueStart: 1,
            cueEnd: 2,
            time: time,
            words: words);
    for (final time in [0.999999, 1.0, 1.199999, 1.8, 2.0, 2.000001]) {
      expect(resolve(time), isEmpty, reason: '$time');
    }
    for (final time in [1.2, 1.35, 1.499999]) {
      expect(resolve(time), [(start: 0, end: 5)], reason: '$time');
    }
    expect(resolve(1.5), [(start: 6, end: 'Hello ខ្មែរ'.length)]);
  });
  test('repeated words, multiline and emoji keep exact source offsets', () {
    const text = 'Hi\nHi 👩🏽‍💻';
    final ranges = CaptionWordResolver.resolve(
        text: text,
        cueStart: 0,
        cueEnd: 3,
        time: 2,
        words: [
          (text: 'Hi', start: 0.0, end: 1.0),
          (text: 'Hi', start: 1.0, end: 2.0),
          (text: '👩🏽‍💻', start: 2.0, end: 3.0)
        ]);
    expect(ranges, [(start: 6, end: text.length)]);
  });
  test('recognition fragments cannot split combining or emoji clusters', () {
    expect(
        CaptionWordResolver.resolve(
            text: 'e\u0301 👩🏽‍💻',
            cueStart: 0,
            cueEnd: 1,
            time: .5,
            words: [
              (text: 'e', start: 0.0, end: 1.0),
              (text: '👩', start: 0.0, end: 1.0)
            ]),
        isEmpty);
  });
}
