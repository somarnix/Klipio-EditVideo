import '../../core/utils/duration_utils.dart';

extension KlipioDurationExtension on Duration {
  double get seconds => inMicroseconds / Duration.microsecondsPerSecond;

  String toEditorTimecode({double frameRate = 30}) =>
      formatEditorTimecode(this, frameRate: frameRate);

  Duration clampTo(Duration minimum, Duration maximum) {
    if (this < minimum) return minimum;
    if (this > maximum) return maximum;
    return this;
  }
}
