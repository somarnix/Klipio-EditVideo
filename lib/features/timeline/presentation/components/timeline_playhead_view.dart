import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/theme/editor_colors.dart';

class TimelinePlayheadView extends StatelessWidget {
  const TimelinePlayheadView({
    super.key,
    required this.position,
    required this.pixelsPerSecond,
    required this.height,
  });

  final ValueListenable<Duration> position;
  final double pixelsPerSecond;
  final double height;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: ValueListenableBuilder<Duration>(
          valueListenable: position,
          builder: (context, value, _) {
            final left = value.inMicroseconds /
                Duration.microsecondsPerSecond *
                pixelsPerSecond;
            return Positioned(
              left: left - 1,
              top: 0,
              bottom: 0,
              child: const IgnorePointer(
                child: SizedBox(
                  width: 2,
                  child: ColoredBox(color: EditorColors.playhead),
                ),
              ),
            );
          },
        ),
      );
}
