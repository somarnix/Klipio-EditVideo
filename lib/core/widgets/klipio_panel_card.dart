import 'package:flutter/material.dart';

import '../theme/editor_colors.dart';

class KlipioPanelCard extends StatelessWidget {
  const KlipioPanelCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? EditorColors.panel,
          border: Border.all(color: EditorColors.border),
        ),
        child: Padding(padding: padding, child: child),
      );
}
