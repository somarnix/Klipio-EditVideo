import 'package:flutter/material.dart';

class CaptionsPanelView extends StatelessWidget {
  const CaptionsPanelView({
    super.key,
    required this.language,
    required this.onLanguageChanged,
    required this.onGenerate,
    this.progress,
    this.status,
  });

  final String language;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback? onGenerate;
  final double? progress;
  final String? status;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          DropdownButtonFormField<String>(
            value: language,
            decoration: const InputDecoration(labelText: 'Language'),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('Auto detect')),
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'km', child: Text('Khmer')),
              DropdownMenuItem(value: 'es', child: Text('Spanish')),
            ],
            onChanged: (value) {
              if (value != null) onLanguageChanged(value);
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate captions'),
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress!.clamp(0, 1)),
          ],
          if (status != null) ...[
            const SizedBox(height: 6),
            Text(status!),
          ],
        ],
      );
}
