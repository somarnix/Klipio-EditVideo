import 'package:flutter/material.dart';

import '../../../../core/theme/editor_colors.dart';
import 'clip_widget.dart';

class CaptionClipItem extends StatelessWidget {
  const CaptionClipItem({
    super.key,
    required this.text,
    required this.selected,
    required this.onSelected,
  });

  final String text;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => TimelineClipWidget(
        label: text,
        selected: selected,
        color: EditorColors.textTrack,
        onTap: onSelected,
        child: const ColoredBox(color: Color(0x663d160c)),
      );
}
