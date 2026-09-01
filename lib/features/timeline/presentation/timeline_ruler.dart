import 'dart:math' as math;

import 'package:flutter/material.dart';

class TimelineRuler extends StatelessWidget {
  const TimelineRuler({
    super.key,
    required this.duration,
    required this.pixelsPerSecond,
    required this.onSeek,
    this.height = 28,
  });

  final double duration;
  final double pixelsPerSecond;
  final ValueChanged<double> onSeek;
  final double height;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => onSeek(
          (details.localPosition.dx / pixelsPerSecond)
              .clamp(0, duration)
              .toDouble(),
        ),
        onHorizontalDragUpdate: (details) => onSeek(
          (details.localPosition.dx / pixelsPerSecond)
              .clamp(0, duration)
              .toDouble(),
        ),
        child: SizedBox(
          width: math.max(1, duration * pixelsPerSecond),
          height: height,
          child: CustomPaint(
            painter: _RulerPainter(
              pixelsPerSecond: pixelsPerSecond,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
}

class _RulerPainter extends CustomPainter {
  const _RulerPainter({required this.pixelsPerSecond, required this.color});
  final double pixelsPerSecond;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.65)
      ..strokeWidth = 1;
    final stepSeconds = pixelsPerSecond >= 100
        ? 1.0
        : pixelsPerSecond >= 30
            ? 5.0
            : 10.0;
    final minor = stepSeconds / 5;
    for (var seconds = 0.0;
        seconds * pixelsPerSecond <= size.width;
        seconds += minor) {
      final major =
          ((seconds / stepSeconds).round() - seconds / stepSeconds).abs() <
              0.001;
      final x = seconds * pixelsPerSecond;
      canvas.drawLine(Offset(x, 0), Offset(x, major ? 10 : 5), paint);
      if (!major) continue;
      final minutes = seconds ~/ 60;
      final remainder = seconds.round() % 60;
      final text = '$minutes:${remainder.toString().padLeft(2, '0')}';
      final painter = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(x + 2, 11));
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) =>
      oldDelegate.pixelsPerSecond != pixelsPerSecond ||
      oldDelegate.color != color;
}
