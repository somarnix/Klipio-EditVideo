import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/editor/presentation/creative_browser.dart';

void main() {
  const items = [
    CreativeBrowserItem(
        id: 'fade',
        label: 'Fade',
        value: 1,
        icon: Icons.gradient,
        tags: ['soft']),
    CreativeBrowserItem(
        id: 'slide', label: 'Slide', value: 2, icon: Icons.arrow_back),
  ];
  testWidgets('search filters real entries and apply preserves typed identity',
      (tester) async {
    int? applied;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CreativeBrowser<int>(
                items: items, onApply: (value) => applied = value))));
    await tester.enterText(find.byType(TextField), 'soft');
    await tester.pump();
    expect(find.text('Slide'), findsNothing);
    await tester.tap(find.text('Fade'));
    expect(applied, 1);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    expect(find.text('No matching assets'), findsOneWidget);
  });
  testWidgets('disabled target explains why and cannot apply', (tester) async {
    var applied = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CreativeBrowser<int>(
                items: items,
                disabledReason: 'Unlock track',
                onApply: (_) => applied = true))));
    expect(find.text('Unlock track'), findsOneWidget);
    await tester.tap(find.text('Fade'));
    expect(applied, isFalse);
  });
}
