import 'package:flutter/material.dart';

import '../../application/inspector_controller.dart';

class CanvasBackgroundTab extends StatelessWidget {
  const CanvasBackgroundTab({super.key, required this.controller});

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
        DropdownButtonFormField<String>(
          value: transform.canvasMode,
          decoration: const InputDecoration(labelText: 'Canvas background'),
          items: const [
            DropdownMenuItem(value: 'none', child: Text('None')),
            DropdownMenuItem(value: 'blur', child: Text('Blur')),
            DropdownMenuItem(value: 'color', child: Text('Color')),
            DropdownMenuItem(value: 'pattern', child: Text('Pattern')),
          ],
          onChanged: (value) {
            if (value != null) {
              controller.updateTransform(transform.copyWith(canvasMode: value));
            }
          },
        ),
        const SizedBox(height: 14),
        Text('Blur strength ${transform.canvasBlur.round()}'),
        Slider(
          value: transform.canvasBlur.clamp(4, 80),
          min: 4,
          max: 80,
          onChanged: (value) => controller.updateTransform(
            transform.copyWith(canvasBlur: value),
          ),
        ),
      ],
    );
  }
}
