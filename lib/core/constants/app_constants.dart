const String klipioProjectFileName = 'project.klipio.json';
const String klipioProjectMetaFileName = 'project-meta.json';

/// Application defaults shared by project creation, preview and export.
abstract final class AppConstants {
  static const String appName = 'Klipio';
  static const String currentVersion = '2.0.17';
  static const int projectSchemaVersion = 2;
  static const double defaultFrameRate = 30;
  static const List<double> supportedFrameRates = [24, 25, 30, 50, 60];
  static const List<String> aspectRatios = [
    'Original',
    '16:9',
    '9:16',
    '4:5',
    '1:1',
    '3:4',
    '4:3',
  ];
}
