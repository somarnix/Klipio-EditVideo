import 'package:flutter/material.dart';

class KlipioContextMenuItem<T> {
  const KlipioContextMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;
}

Future<T?> showKlipioContextMenu<T>(
  BuildContext context, {
  required Offset position,
  required List<KlipioContextMenuItem<T>> items,
}) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final item in items)
        PopupMenuItem<T>(
          value: item.value,
          enabled: item.enabled,
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 17),
                const SizedBox(width: 8),
              ],
              Text(item.label),
            ],
          ),
        ),
    ],
  );
}
