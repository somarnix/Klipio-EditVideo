/// Dense editor dimensions and interaction thresholds used across Klipio.
abstract final class EditorConstants {
  static const double minTimelineZoom = 0.05;
  static const double maxTimelineZoom = 20;
  static const double defaultPixelsPerSecond = 72;
  static const double videoTrackHeight = 76;
  static const double audioTrackHeight = 54;
  static const double textTrackHeight = 42;
  static const double trackHeaderWidth = 104;
  static const double timelineToolbarHeight = 42;
  static const double rulerHeight = 28;
  static const double trimHandleWidth = 7;
  static const double snapThresholdSeconds = 0.12;
  static const double panelDividerWidth = 1;
  static const Duration autosaveInterval = Duration(seconds: 20);
}
