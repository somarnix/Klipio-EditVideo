import 'package:flutter/material.dart';

class KlipioIconButton extends StatelessWidget {
  const KlipioIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.size = 30,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        style: IconButton.styleFrom(
          fixedSize: Size.square(size),
          padding: EdgeInsets.zero,
          foregroundColor: selected ? colors.onPrimaryContainer : null,
          backgroundColor: selected ? colors.primaryContainer : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      ),
    );
  }
}
