import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/timeline/presentation/timeline_quick_actions.dart';

void main() {
  testWidgets('selected clip toolbar invokes batch actions', (tester) async {
    var split = 0;
    var deleted = 0;
    var synced = 0;
    var speed = 0.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineQuickActions(
            selectionCount: 3,
            onSplit: () => split++,
            onSpeedChanged: (value) => speed = value,
            onDeleteRipple: () => deleted++,
            onSyncSettings: () => synced++,
          ),
        ),
      ),
    );

    expect(find.text('3 selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timeline-quick-split')));
    await tester.tap(
      find.byKey(const ValueKey('timeline-quick-delete-ripple')),
    );
    await tester.tap(
      find.byKey(const ValueKey('timeline-quick-sync-settings')),
    );
    await tester.tap(find.byKey(const ValueKey('timeline-quick-speed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speed 1.5x'));
    await tester.pumpAndSettle();

    expect(split, 1);
    expect(deleted, 1);
    expect(synced, 1);
    expect(speed, 1.5);
  });
}
