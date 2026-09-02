import 'package:flutter/material.dart';

import '../../application/inspector_controller.dart';

class SpeedCurveTab extends StatelessWidget {
  const SpeedCurveTab({super.key, required this.controller});

  final InspectorController controller;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    if (settings == null) {
      return const Center(child: Text('Select a video clip'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Constant speed ${settings.speed.toStringAsFixed(2)}x'),
        Slider(
          value: settings.speed.clamp(0.25, 4),
          min: 0.25,
          max: 4,
          divisions: 75,
          onChanged: controller.updateSpeed,
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final speed in const [0.5, 1.0, 1.5, 2.0, 4.0])
              ChoiceChip(
                label: Text('${speed}x'),
                selected: (settings.speed - speed).abs() < 0.001,
                onSelected: (_) => controller.updateSpeed(speed),
              ),
          ],
        ),
      ],
    );
  }
}
