import 'package:flutter/material.dart';

import '../../features/timeline/domain/timeline_models.dart';
import 'app_colors.dart';

/// Timeline-specific theming kept separate from the application ThemeData.
abstract final class EditorTheme {
  static Color trackColor(TrackType type) => switch (type) {
        TrackType.video => AppColors.videoTrack,
        TrackType.audio => AppColors.audioTrack,
        TrackType.text => AppColors.textTrack,
      };

  static Color clipColor(TrackType type, {bool caption = false}) =>
      caption ? AppColors.captionTrack : trackColor(type);
}
