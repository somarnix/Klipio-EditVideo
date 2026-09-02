import 'package:flutter/material.dart';

import '../../domain/caption_style.dart';

class SubtitleStylePicker extends StatelessWidget {
  const SubtitleStylePicker({
    super.key,
    required this.presets,
    required this.selectedId,
    required this.onSelected,
  });

  final List<CaptionStyle> presets;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          childAspectRatio: 1.6,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: presets.length,
        itemBuilder: (context, index) {
          final preset = presets[index];
          return ChoiceChip(
            label: Text(preset.name),
            selected: preset.id == selectedId,
            onSelected: (_) => onSelected(preset.id),
          );
        },
      );
}
