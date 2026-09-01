import 'package:flutter/material.dart';

import '../../../core/widgets/klipio_icon_button.dart';

class TimelineToolbar extends StatelessWidget {
  const TimelineToolbar({
    super.key,
    required this.onUndo,
    required this.onRedo,
    required this.onSplit,
    required this.onDelete,
    required this.onToggleSnap,
    required this.snapEnabled,
    required this.zoom,
    required this.onZoomChanged,
  });

  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onSplit;
  final VoidCallback? onDelete;
  final VoidCallback onToggleSnap;
  final bool snapEnabled;
  final double zoom;
  final ValueChanged<double> onZoomChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          KlipioIconButton(
              icon: Icons.undo, tooltip: 'Undo', onPressed: onUndo),
          KlipioIconButton(
              icon: Icons.redo, tooltip: 'Redo', onPressed: onRedo),
          const VerticalDivider(width: 8),
          KlipioIconButton(
            icon: Icons.content_cut,
            tooltip: 'Split',
            onPressed: onSplit,
          ),
          KlipioIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
          KlipioIconButton(
            icon: Icons.attach_file,
            tooltip: 'Snapping',
            selected: snapEnabled,
            onPressed: onToggleSnap,
          ),
          const Spacer(),
          const Icon(Icons.zoom_out, size: 16),
          SizedBox(
            width: 120,
            child: Slider(
              value: zoom.clamp(0.05, 20),
              min: 0.05,
              max: 20,
              onChanged: onZoomChanged,
            ),
          ),
          const Icon(Icons.zoom_in, size: 16),
        ],
      );
}
