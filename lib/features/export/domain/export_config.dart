import 'export_settings.dart';

/// Stable feature-level export contract used by dialogs and coordinators.
class ExportConfig {
  const ExportConfig({
    this.width = 1920,
    this.height = 1080,
    this.frameRate = 30,
    this.bitrateKbps = 8000,
    this.audioBitrateKbps = 192,
    this.container = ExportContainer.mp4,
    this.codec = ExportVideoCodec.h264,
    this.encoder = 'auto',
    this.hardwareAcceleration = true,
  });

  final int width;
  final int height;
  final double frameRate;
  final int bitrateKbps;
  final int audioBitrateKbps;
  final ExportContainer container;
  final ExportVideoCodec codec;
  final String encoder;
  final bool hardwareAcceleration;

  String get resolutionLabel => '${width}x$height';

  ExportSettings toSettings() => ExportSettings(
        width: width,
        height: height,
        frameRate: frameRate,
        bitrateKbps: bitrateKbps,
        audioBitrateKbps: audioBitrateKbps,
        container: container,
        codec: codec,
        encoder: encoder,
        hardwareAcceleration: hardwareAcceleration,
      );

  factory ExportConfig.fromSettings(ExportSettings settings) => ExportConfig(
        width: settings.width,
        height: settings.height,
        frameRate: settings.frameRate,
        bitrateKbps: settings.bitrateKbps,
        audioBitrateKbps: settings.audioBitrateKbps,
        container: settings.container,
        codec: settings.codec,
        encoder: settings.encoder,
        hardwareAcceleration: settings.hardwareAcceleration,
      );

  ExportConfig copyWith({
    int? width,
    int? height,
    double? frameRate,
    int? bitrateKbps,
    int? audioBitrateKbps,
    ExportContainer? container,
    ExportVideoCodec? codec,
    String? encoder,
    bool? hardwareAcceleration,
  }) =>
      ExportConfig(
        width: width ?? this.width,
        height: height ?? this.height,
        frameRate: frameRate ?? this.frameRate,
        bitrateKbps: bitrateKbps ?? this.bitrateKbps,
        audioBitrateKbps: audioBitrateKbps ?? this.audioBitrateKbps,
        container: container ?? this.container,
        codec: codec ?? this.codec,
        encoder: encoder ?? this.encoder,
        hardwareAcceleration: hardwareAcceleration ?? this.hardwareAcceleration,
      );
}
