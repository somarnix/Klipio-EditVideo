import 'package:flutter/material.dart';

import '../timeline_quick_actions.dart';

class TimelineToolbarView extends StatelessWidget {
  const TimelineToolbarView({
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
    if (selectionCount == 0) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child:
              Text('TIMELINE', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
    }
    return Align(
      alignment: Alignment.center,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: TimelineQuickActions(
          selectionCount: selectionCount,
          onSplit: onSplit,
          onSpeedChanged: onSpeedChanged,
          onDeleteRipple: onDeleteRipple,
          onSyncSettings: onSyncSettings,
        ),
      ),
    );
  }
}
