import 'package:flutter/material.dart';

class KlipioIconToggle extends StatelessWidget {
  const KlipioIconToggle({
    super.key,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.tooltip,
    this.selectedColor,
  });

  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String tooltip;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onChanged == null ? null : () => onChanged!(!value),
        icon: Icon(
          icon,
          size: 18,
          color: value
              ? selectedColor ?? Theme.of(context).colorScheme.primary
              : null,
        ),
      );
}
