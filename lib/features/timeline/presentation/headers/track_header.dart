import 'package:flutter/material.dart';

class TrackHeader extends StatelessWidget {
  const TrackHeader({
    super.key,
    required this.label,
    required this.muted,
    required this.locked,
    required this.hidden,
    required this.onMute,
    required this.onLock,
    required this.onVisibility,
    this.onDelete,
  });

  final String label;
  final bool muted;
  final bool locked;
  final bool hidden;
  final VoidCallback onMute;
  final VoidCallback onLock;
  final VoidCallback onVisibility;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(label, textAlign: TextAlign.center),
          ),
          IconButton(
            tooltip: hidden ? 'Show track' : 'Hide track',
            onPressed: onVisibility,
            icon: Icon(hidden ? Icons.visibility_off : Icons.visibility,
                size: 16),
          ),
          IconButton(
            tooltip: locked ? 'Unlock track' : 'Lock track',
            onPressed: onLock,
            icon: Icon(locked ? Icons.lock : Icons.lock_open, size: 16),
          ),
          IconButton(
            tooltip: muted ? 'Unmute track' : 'Mute track',
            onPressed: onMute,
            icon: Icon(muted ? Icons.volume_off : Icons.volume_up, size: 16),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete track',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 16),
            ),
        ],
      );
}
