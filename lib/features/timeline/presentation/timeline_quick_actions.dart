import 'package:flutter/material.dart';

/// Contextual batch actions displayed only while timeline items are selected.
class TimelineQuickActions extends StatelessWidget {
  const TimelineQuickActions({
    super.key,
    required this.selectionCount,
    required this.onSplit,
    required this.onSpeedChanged,
    required this.onDeleteRipple,
    required this.onSyncSettings,
  });

  final int selectionCount;
  final VoidCallback onSplit;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onDeleteRipple;
  final VoidCallback onSyncSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 5,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        key: const ValueKey('timeline-quick-actions'),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.primary.withOpacity(0.35)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$selectionCount selected',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const VerticalDivider(indent: 8, endIndent: 8),
            _button(Icons.content_cut, 'Split', onSplit),
            PopupMenuButton<double>(
              key: const ValueKey('timeline-quick-speed'),
              tooltip: 'Set selected clip speed',
              onSelected: onSpeedChanged,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 0.5, child: Text('Speed 0.5x')),
                PopupMenuItem(value: 1, child: Text('Speed 1x')),
                PopupMenuItem(value: 1.5, child: Text('Speed 1.5x')),
                PopupMenuItem(value: 2, child: Text('Speed 2x')),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.speed, size: 17),
                    SizedBox(width: 4),
                    Text('Speed', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
            _button(Icons.delete_outline, 'Delete', onDeleteRipple,
                semanticKey: 'delete-ripple'),
            IconButton(
              key: const ValueKey('timeline-quick-sync-settings'),
              tooltip: 'Sync settings',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              padding: EdgeInsets.zero,
              onPressed: onSyncSettings,
              icon: const Icon(Icons.more_horiz, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(IconData icon, String label, VoidCallback onPressed,
      {String? semanticKey}) {
    return TextButton.icon(
      key: ValueKey(
          'timeline-quick-${semanticKey ?? label.toLowerCase().replaceAll(' ', '-')}'),
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}
