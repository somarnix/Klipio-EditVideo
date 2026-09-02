import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/text/presentation/project_text.dart';

void main() {
  testWidgets('project content preserves Unicode and ignores UI text scaling',
      (tester) async {
    const content = 'Home\nសួស្តី Khmer 👩🏽‍💻 Café';
    Future<Size> render(double scale) async {
      await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Center(
                  child: SizedBox(
                      width: 250,
                      child: ProjectText(content,
                          style: TextStyle(fontSize: 24, height: 1.2)))))));
      final text = tester.widget<Text>(find.text(content));
      expect(text.data, content);
      expect(text.textScaler, TextScaler.noScaling);
      expect(text.softWrap, isTrue);
      return tester.getSize(find.text(content));
    }

    final normal = await render(1);
    expect(await render(3), normal);
    expect(normal.height, greaterThan(24));
  });
}
