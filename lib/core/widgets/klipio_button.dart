import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class KlipioButton extends StatelessWidget {
  const KlipioButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
    this.filled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool destructive;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? Theme.of(context).colorScheme.error : null;
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(0, AppSpacing.compactControlHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      foregroundColor:
          foreground == null ? null : WidgetStatePropertyAll(foreground),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.panelRadius),
        ),
      ),
    );
    if (icon == null) {
      return filled
          ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
          : OutlinedButton(
              onPressed: onPressed, style: style, child: Text(label));
    }
    return filled
        ? FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 16),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 16),
            label: Text(label),
          );
  }
}
