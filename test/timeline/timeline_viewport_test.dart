import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/timeline/application/timeline_viewport.dart';

void main() {
  test('program/pixel mapping round trips and zoom preserves pointer anchor',
      () {
    const viewport = TimelineViewport(
      pixelsPerSecond: 40,
      visibleProgramStart: 10,
      viewportWidth: 800,
      projectDuration: 600,
    );
    expect(viewport.xToProgramTime(viewport.programTimeToX(25)),
        closeTo(25, 1e-9));
    final zoomed = viewport.zoomAround(factor: 2, pointerX: 300);
    expect(zoomed.xToProgramTime(300),
        closeTo(viewport.xToProgramTime(300), 1e-9));
  });

  test('fit range remains bounded by project duration', () {
    const viewport = TimelineViewport(
      pixelsPerSecond: 2,
      visibleProgramStart: 0,
      viewportWidth: 500,
      projectDuration: 100,
    );
    expect(viewport.visibleProgramEnd, 100);
  });
}
