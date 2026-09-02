import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/text/domain/text_case.dart';

void main() {
  test('title case preserves whitespace and paragraph boundaries', () {
    expect(applyTextCase('  HELLO\tWORLD\r\nAGAIN  ', 'title'),
        '  Hello\tWorld\r\nAgain  ');
  });
  test('title case preserves emoji clusters and Khmer text', () {
    expect(applyTextCase('👩🏽‍💻HELLO ខ្មែរ', 'title'), '👩🏽‍💻hello ខ្មែរ');
    expect(applyTextCase('e\u0301COLE', 'title'), 'E\u0301cole');
  });
  test('supplementary-plane letter is uppercased as a whole character', () {
    expect(applyTextCase('\u{10428}TEST', 'title'), '\u{10400}test');
  });
  test('empty and original content are preserved', () {
    expect(applyTextCase('', 'title'), '');
    expect(applyTextCase('MiXeD\nខ្មែរ', 'original'), 'MiXeD\nខ្មែរ');
    expect(applyTextCase('Test', 'upper'), 'TEST');
    expect(applyTextCase('Test', 'lower'), 'test');
  });
}
