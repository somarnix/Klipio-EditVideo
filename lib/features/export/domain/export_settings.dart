enum ExportContainer { mp4, mov }

enum ExportVideoCodec { h264, hevc, proRes }

class ExportSettings {
  const ExportSettings({
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
}
