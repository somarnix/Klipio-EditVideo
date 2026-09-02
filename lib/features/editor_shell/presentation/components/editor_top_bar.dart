import 'package:flutter/material.dart';

import '../../../../core/constants/layout_dimensions.dart';
import '../../../../core/theme/editor_colors.dart';

class EditorTopBar extends StatelessWidget {
  const EditorTopBar({
    super.key,
    required this.projectName,
    this.onHome,
    this.onUndo,
    this.onRedo,
    this.onSave,
    this.onExport,
  });

  final String projectName;
  final VoidCallback? onHome;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onSave;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: LayoutDimensions.topBarHeight,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: EditorColors.panel,
            border: Border(bottom: BorderSide(color: EditorColors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Home',
                onPressed: onHome,
                icon: const Icon(Icons.home_outlined),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.movie_filter_outlined,
                  color: EditorColors.gizmo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  projectName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                  tooltip: 'Undo',
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo)),
              IconButton(
                  tooltip: 'Redo',
                  onPressed: onRedo,
                  icon: const Icon(Icons.redo)),
              IconButton(
                tooltip: 'Save project',
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('Export'),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      );
}
