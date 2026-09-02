import 'package:flutter/material.dart';

import '../../../../core/constants/layout_dimensions.dart';
import '../../../../core/theme/editor_colors.dart';

class EditorCenterWorkspace extends StatelessWidget {
  const EditorCenterWorkspace({
    super.key,
    required this.left,
    required this.center,
    required this.inspector,
    required this.leftWidth,
    required this.inspectorWidth,
    required this.onLeftWidthChanged,
    required this.onInspectorWidthChanged,
  });

  final Widget left;
  final Widget center;
  final Widget inspector;
  final double leftWidth;
  final double inspectorWidth;
  final ValueChanged<double> onLeftWidthChanged;
  final ValueChanged<double> onInspectorWidthChanged;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: leftWidth, child: left),
          _WorkspaceDivider(
            onDrag: (delta) => onLeftWidthChanged(leftWidth + delta),
          ),
          Expanded(child: center),
          _WorkspaceDivider(
            onDrag: (delta) => onInspectorWidthChanged(inspectorWidth - delta),
          ),
          SizedBox(width: inspectorWidth, child: inspector),
        ],
      );
}

class _WorkspaceDivider extends StatelessWidget {
  const _WorkspaceDivider({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
          child: const SizedBox(
            width: LayoutDimensions.splitterThickness,
            child: ColoredBox(color: EditorColors.border),
          ),
        ),
      );
}
