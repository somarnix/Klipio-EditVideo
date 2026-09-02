import 'package:flutter/material.dart';

import '../../../../core/theme/editor_colors.dart';
import '../../rendering/waveform_painter.dart';
import 'clip_widget.dart';

class AudioClipItem extends StatelessWidget {
  const AudioClipItem({
    super.key,
    required this.label,
    required this.selected,
    required this.peaks,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final List<double> peaks;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => TimelineClipWidget(
        label: label,
        selected: selected,
        color: EditorColors.audioTrack,
        onTap: onSelected,
        child: CustomPaint(
          painter: WaveformPainter(
            peaks: peaks,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      );
}
