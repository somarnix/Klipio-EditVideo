import 'package:flutter/material.dart';

import '../../domain/export_preset.dart';

class ExportPresetSelector extends StatelessWidget {
  const ExportPresetSelector({
    super.key,
    required this.presets,
    required this.selected,
    required this.onSelected,
  });

  final List<ExportPreset> presets;
  final ExportPreset selected;
  final ValueChanged<ExportPreset> onSelected;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        value: selected.id,
        decoration: const InputDecoration(labelText: 'Export preset'),
        items: [
          for (final preset in presets)
            DropdownMenuItem(value: preset.id, child: Text(preset.name)),
        ],
        onChanged: (id) {
          if (id == null) return;
          onSelected(presets.firstWhere((preset) => preset.id == id));
        },
      );
}
