import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/preview/program_monitor/interactive_transform_overlay.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  testWidgets('transform overlay exposes complete direct manipulation handles',
      (tester) async {
    var transform = const ClipTransform();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: StatefulBuilder(
              builder: (context, setHarnessState) =>
                  InteractiveTransformOverlay(
                frame: const Rect.fromLTWH(100, 60, 200, 160),
                transform: transform,
                onTransformChanged: (value) => setHarnessState(
                  () => transform = value,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('transform-move')), findsOneWidget);
    expect(find.byKey(const ValueKey('transform-rotate')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('transform-corner--1.0--1.0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('transform-edge-1.0-0.0')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('transform-move')),
      const Offset(40, 25),
    );
    expect(transform.positionX, greaterThan(0.5));
    expect(transform.positionY, greaterThan(0.5));

    await tester.drag(
      find.byKey(const ValueKey('transform-rotate')),
      const Offset(30, 0),
    );
    expect(transform.rotationDegrees, isNot(0));
  });
}
