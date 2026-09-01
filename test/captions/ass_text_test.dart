import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/captions/domain/ass_text.dart';

void main() {
  test('ASS control escapes become clean editor display text', () {
    expect(
      normalizeAssDisplayText(
        r'{\b1}TO\hJUST\\hCHECK\NEVERYTHING{\b0}',
      ),
      'TO JUST CHECK EVERYTHING',
    );
  });

  test('normal caption text remains unchanged', () {
    expect(
      normalizeAssDisplayText('IN THE SECOND MINE'),
      'IN THE SECOND MINE',
    );
  });
}
