import 'export_settings.dart';

class ExportPreset {
  const ExportPreset({
    required this.id,
    required this.name,
    required this.settings,
  });

  final String id;
  final String name;
  final ExportSettings settings;

  static const hd1080 = ExportPreset(
    id: '1080p',
    name: '1080p',
    settings: ExportSettings(),
  );

  static const hd720 = ExportPreset(
    id: '720p',
    name: '720p',
    settings: ExportSettings(width: 1280, height: 720, bitrateKbps: 5000),
  );

  static const uhd4k = ExportPreset(
    id: '4k',
    name: '4K',
    settings: ExportSettings(width: 3840, height: 2160, bitrateKbps: 35000),
  );
}
