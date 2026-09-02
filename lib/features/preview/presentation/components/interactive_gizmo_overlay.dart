import 'package:flutter/material.dart';

import '../../../timeline/domain/timeline_models.dart';
import '../../application/transform_gizmo_controller.dart';
import '../../program_monitor/interactive_transform_overlay.dart';

class InteractiveGizmoOverlay extends StatelessWidget {
  const InteractiveGizmoOverlay({
    super.key,
    required this.controller,
    required this.frame,
    required this.onCommitted,
  });

  final TransformGizmoController controller;
  final Rect frame;
  final ValueChanged<ClipTransform> onCommitted;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => InteractiveTransformOverlay(
          frame: frame,
          transform: controller.transform,
          onTransformChanged: controller.load,
          onTransformEnd: () => onCommitted(controller.transform),
        ),
      );
}
