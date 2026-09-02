import 'dart:math' as math;

import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  const WaveformPainter({
    required this.peaks,
    required this.color,
    this.startFraction = 0,
    this.endFraction = 1,
  });

  final List<double> peaks;
  final Color color;
  final double startFraction;
  final double endFraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || size.isEmpty) return;
    final start = startFraction.clamp(0, 1).toDouble();
    final end = endFraction.clamp(start, 1).toDouble();
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final center = size.height / 2;
    final bars = math.max(1, (size.width / 2).floor());
    for (var bar = 0; bar < bars; bar++) {
      final fraction = start + (end - start) * bar / math.max(1, bars - 1);
      final index = (fraction * (peaks.length - 1)).round();
      final amplitude = peaks[index].abs().clamp(0, 1).toDouble();
      final height = math.max(1.0, amplitude * center * 0.92);
      final x = (bar + 0.5) * size.width / bars;
      canvas.drawLine(
        Offset(x, center - height),
        Offset(x, center + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) =>
      oldDelegate.peaks != peaks ||
      oldDelegate.color != color ||
      oldDelegate.startFraction != startFraction ||
      oldDelegate.endFraction != endFraction;
}
