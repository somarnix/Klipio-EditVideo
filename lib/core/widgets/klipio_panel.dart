import 'package:flutter/material.dart';

class KlipioPanel extends StatelessWidget {
  const KlipioPanel({
    super.key,
    required this.child,
    this.header,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Widget? header;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[
            header!,
            Divider(height: 1, color: divider),
          ],
          Expanded(child: Padding(padding: padding, child: child)),
        ],
      ),
    );
  }
}
