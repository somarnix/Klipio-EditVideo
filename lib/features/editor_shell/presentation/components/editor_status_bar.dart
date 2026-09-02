import 'package:flutter/material.dart';

import '../../../../core/constants/layout_dimensions.dart';
import '../../../../core/theme/editor_colors.dart';

class EditorStatusBar extends StatelessWidget {
  const EditorStatusBar({
    super.key,
    required this.status,
    this.busy = false,
    this.frameRate,
    this.workerCount,
    this.driveLabel,
  });

  final String status;
  final bool busy;
  final double? frameRate;
  final int? workerCount;
  final String? driveLabel;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: LayoutDimensions.statusBarHeight,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: EditorColors.panel,
            border: Border(top: BorderSide(color: EditorColors.border)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              if (busy) ...[
                const SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(
                  status,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              if (frameRate != null)
                Text('${frameRate!.toStringAsFixed(1)} FPS'),
              if (workerCount != null) ...[
                const SizedBox(width: 14),
                Text('$workerCount worker${workerCount == 1 ? '' : 's'}'),
              ],
              if (driveLabel != null) ...[
                const SizedBox(width: 14),
                Text(driveLabel!),
              ],
              const SizedBox(width: 10),
            ],
          ),
        ),
      );
}
