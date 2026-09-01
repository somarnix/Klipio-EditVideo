import 'package:flutter_test/flutter_test.dart';
import 'package:klipio/features/composition/domain/render_scene.dart';
import 'package:klipio/features/timeline/domain/timeline_models.dart';

void main() {
  test('render scene resolves stable composition-space geometry and timing',
      () {
    const clip = ClipModel(
      id: 'clip-1',
      mediaPath: r'D:\original.mp4',
      timelineStart: 10,
      duration: 5,
      sourceStart: 100,
      zIndex: 1,
      transform: ClipTransform(
        scaleX: 1.2,
        scaleY: 0.5,
        positionX: 0.25,
        positionY: 0.75,
        rotationDegrees: 15,
        opacity: 0.8,
      ),
    );
    const composition = CompositionModel(
      width: 1920,
      height: 1080,
      frameRate: 30,
    );
    final node = RenderSceneResolver.resolveClip(
      clip: clip,
      composition: composition,
      timelineSeconds: 12,
      playbackSpeed: 1.5,
    );

    expect(node.sourceSeconds, 103);
    expect(node.centerX, 480);
    expect(node.centerY, 810);
    expect(node.boxWidth, 2304);
    expect(node.boxHeight, 540);
    expect(node.left, -672);
    expect(node.top, 540);
    expect(node.rotationDegrees, 15);
    expect(node.opacity, 0.8);
    expect(node.originalMediaPath, r'D:\original.mp4');
  });
}
