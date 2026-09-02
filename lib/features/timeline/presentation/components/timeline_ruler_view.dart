import 'package:flutter/material.dart';

import '../timeline_ruler.dart';

class TimelineRulerView extends StatelessWidget {
  const TimelineRulerView({
    super.key,
    required this.duration,
    required this.pixelsPerSecond,
    required this.onSeek,
  });

  final double duration;
  final double pixelsPerSecond;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) => TimelineRuler(
        duration: duration,
        pixelsPerSecond: pixelsPerSecond,
        onSeek: onSeek,
      );
}
