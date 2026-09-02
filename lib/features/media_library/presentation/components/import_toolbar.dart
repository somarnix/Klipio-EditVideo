import 'package:flutter/material.dart';

class ImportToolbar extends StatelessWidget {
  const ImportToolbar({
    super.key,
    required this.onImportFiles,
    required this.onImportFolder,
    this.busy = false,
  });

  final VoidCallback onImportFiles;
  final VoidCallback onImportFolder;
  final bool busy;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          FilledButton.icon(
            onPressed: busy ? null : onImportFiles,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Import'),
          ),
          IconButton(
            tooltip: 'Import folder',
            onPressed: busy ? null : onImportFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          if (busy) ...[
            const Spacer(),
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      );
}
