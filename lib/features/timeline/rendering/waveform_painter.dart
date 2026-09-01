import 'dart:math' as math;

import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  const WaveformPainter({
    required this.peaks,
    required this.color,
    this.strokeWidth = 1,
  });

  final List<double> peaks;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || size.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final center = size.height / 2;
    final visibleSamples = math.max(1, size.width.floor());
    for (var pixel = 0; pixel < visibleSamples; pixel++) {
      final start = (pixel * peaks.length / visibleSamples).floor();
      final end = math
          .max(
            start + 1,
            ((pixel + 1) * peaks.length / visibleSamples).ceil(),
          )
          .clamp(0, peaks.length);
      var peak = 0.0;
      for (var index = start; index < end; index++) {
        peak = math.max(peak, peaks[index].abs());
      }
      final height = peak.clamp(0, 1) * center;
      canvas.drawLine(
        Offset(pixel.toDouble(), center - height),
        Offset(pixel.toDouble(), center + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) =>
      oldDelegate.peaks != peaks ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
