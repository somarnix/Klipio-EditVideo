import 'package:flutter/material.dart';

import '../domain/export_preset.dart';
import '../domain/export_settings.dart';
import 'components/export_preset_selector.dart';

class ExportDialog extends StatefulWidget {
  const ExportDialog({
    super.key,
    required this.initialSettings,
    required this.onExport,
    this.presets = const [
      ExportPreset.hd720,
      ExportPreset.hd1080,
      ExportPreset.uhd4k,
    ],
  });

  final ExportSettings initialSettings;
  final List<ExportPreset> presets;
  final Future<void> Function(ExportSettings settings) onExport;

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  late ExportPreset _preset;
  late ExportSettings _settings;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _preset = widget.presets.firstWhere(
      (preset) =>
          preset.settings.width == _settings.width &&
          preset.settings.height == _settings.height,
      orElse: () => widget.presets.first,
    );
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await widget.onExport(_settings);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Export'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExportPresetSelector(
                presets: widget.presets,
                selected: _preset,
                onSelected: (preset) => setState(() {
                  _preset = preset;
                  _settings = preset.settings;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ExportVideoCodec>(
                value: _settings.codec,
                decoration: const InputDecoration(labelText: 'Codec'),
                items: [
                  for (final codec in ExportVideoCodec.values)
                    DropdownMenuItem(
                      value: codec,
                      child: Text(codec.name.toUpperCase()),
                    ),
                ],
                onChanged: (codec) {
                  if (codec == null) return;
                  setState(() => _settings = ExportSettings(
                        width: _settings.width,
                        height: _settings.height,
                        frameRate: _settings.frameRate,
                        bitrateKbps: _settings.bitrateKbps,
                        audioBitrateKbps: _settings.audioBitrateKbps,
                        container: _settings.container,
                        codec: codec,
                        encoder: _settings.encoder,
                        hardwareAcceleration: _settings.hardwareAcceleration,
                      ));
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hardware acceleration'),
                value: _settings.hardwareAcceleration,
                onChanged: (enabled) => setState(() {
                  _settings = ExportSettings(
                    width: _settings.width,
                    height: _settings.height,
                    frameRate: _settings.frameRate,
                    bitrateKbps: _settings.bitrateKbps,
                    audioBitrateKbps: _settings.audioBitrateKbps,
                    container: _settings.container,
                    codec: _settings.codec,
                    encoder: _settings.encoder,
                    hardwareAcceleration: enabled,
                  );
                }),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _starting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _starting ? null : _start,
            icon: _starting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload_outlined),
            label: const Text('Export'),
          ),
        ],
      );
}
