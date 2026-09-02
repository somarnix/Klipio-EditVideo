import 'package:flutter/material.dart';

class ExportProgressTile extends StatelessWidget {
  const ExportProgressTile({
    super.key,
    required this.title,
    required this.itemNumber,
    required this.itemCount,
    required this.progress,
    this.status,
    this.onCancel,
  });

  final String title;
  final int itemNumber;
  final int itemCount;
  final double progress;
  final String? status;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0, 1).toDouble();
    final percent = (value * 100).round();
    return ListTile(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exporting $itemNumber of $itemCount • $percent%'),
          if (status != null && status!.isNotEmpty) Text(status!),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: value),
        ],
      ),
      trailing: onCancel == null
          ? null
          : IconButton(
              tooltip: 'Cancel export',
              onPressed: onCancel,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
    );
  }
}
