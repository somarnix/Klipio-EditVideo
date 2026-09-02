import 'package:flutter/material.dart';

import '../../application/inspector_controller.dart';

class VideoTransformTab extends StatelessWidget {
  const VideoTransformTab({super.key, required this.controller});

  final InspectorController controller;

  @override
  Widget build(BuildContext context) {
    final transform = controller.settings?.transform;
    if (transform == null) {
      return const Center(child: Text('Select a video clip'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _slider(
          label: 'Scale X',
          value: transform.scaleX,
          min: 0.05,
          max: 4,
          onChanged: (value) =>
              controller.updateTransform(transform.copyWith(scaleX: value)),
        ),
        _slider(
          label: 'Scale Y',
          value: transform.scaleY,
          min: 0.05,
          max: 4,
          onChanged: (value) =>
              controller.updateTransform(transform.copyWith(scaleY: value)),
        ),
        _slider(
          label: 'Position X',
          value: transform.positionX,
          min: 0,
          max: 1,
          onChanged: (value) =>
              controller.updateTransform(transform.copyWith(positionX: value)),
        ),
        _slider(
          label: 'Position Y',
          value: transform.positionY,
          min: 0,
          max: 1,
          onChanged: (value) =>
              controller.updateTransform(transform.copyWith(positionY: value)),
        ),
        _slider(
          label: 'Rotation',
          value: transform.rotationDegrees.clamp(-180, 180).toDouble(),
          min: -180,
          max: 180,
          onChanged: (value) => controller.updateTransform(
            transform.copyWith(rotationDegrees: value),
          ),
        ),
        _slider(
          label: 'Opacity',
          value: transform.opacity,
          min: 0,
          max: 1,
          onChanged: (value) =>
              controller.updateTransform(transform.copyWith(opacity: value)),
        ),
      ],
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label  ${value.toStringAsFixed(2)}'),
          Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged),
        ],
      );
}
