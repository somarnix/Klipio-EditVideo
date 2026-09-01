import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/captions/domain/srt_document.dart';

void main() {
  test('formats SRT timestamps with millisecond precision', () {
    expect(formatSrtTimestamp(3723456000), '01:02:03,456');
    expect(formatSrtTimestamp(-1000), '00:00:00,000');
  });

  test('orders and serializes caption entries', () {
    final document = buildSrtDocument(const [
      SrtEntry(
        startMicroseconds: 2500000,
        endMicroseconds: 3000000,
        text: 'Second line',
      ),
      SrtEntry(
        startMicroseconds: 500000,
        endMicroseconds: 1250000,
        text: 'First\ncaption',
      ),
    ]);

    expect(
      document,
      '1\n'
      '00:00:00,500 --> 00:00:01,250\n'
      'First\ncaption\n\n'
      '2\n'
      '00:00:02,500 --> 00:00:03,000\n'
      'Second line\n\n',
    );
  });
}
