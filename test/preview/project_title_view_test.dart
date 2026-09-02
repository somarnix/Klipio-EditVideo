import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/export/domain/export_models.dart';
import 'package:klipio/features/text/presentation/project_title_view.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  testWidgets(
      'active title hit region survives unchanged rebuild, rotation and exact end',
      (tester) async {
    var taps = 0;
    Future<void> show(double time, {double rotation = 0}) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: SizedBox(
          width: 400,
          height: 300,
          child: GestureDetector(
            onTap: () => taps++,
            child: ProjectTitleView(
                time: time,
                title: TextOverlaySettings(
                  text: 'Title',
                  size: 100,
                  x: .5,
                  y: .5,
                  timelineStart: 1,
                  timelineEnd: 3,
                  transform: ClipTransform(
                      rotationDegrees: rotation, scaleX: 1.3, scaleY: .8),
                )),
          ),
        )),
      ));
    }

    await show(1);
    final center = tester.getCenter(find.byType(ProjectTitleView));
    await tester.tapAt(center);
    expect(taps, 1);
    // Same painting values, so Flutter need not repaint the new painter.
    await show(1);
    await tester.tapAt(center);
    expect(taps, 2);
    await tester.tapAt(center + const Offset(190, 140));
    expect(taps, 2);
    await show(2, rotation: 90);
    await tester.tapAt(center);
    expect(taps, 3);
    await show(3);
    await tester.tapAt(center);
    expect(taps, 3);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
