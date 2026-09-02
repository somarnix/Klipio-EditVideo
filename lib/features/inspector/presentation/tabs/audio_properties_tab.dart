import 'package:flutter/material.dart';

import '../../application/inspector_controller.dart';

class AudioPropertiesTab extends StatelessWidget {
  const AudioPropertiesTab({super.key, required this.controller});

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
        Text('Source audio ${(settings.originalVolume * 100).round()}%'),
        Slider(
          value: settings.originalVolume.clamp(0, 1),
          onChanged: controller.updateSourceVolume,
        ),
        const ListTile(
          enabled: false,
          leading: Icon(Icons.graphic_eq),
          title: Text('Voice enhance'),
          subtitle: Text('Available when an enhancement engine is connected'),
        ),
      ],
    );
  }
}
