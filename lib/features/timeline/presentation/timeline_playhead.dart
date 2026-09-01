import 'package:flutter/material.dart';

class TimelinePlayhead extends StatelessWidget {
  const TimelinePlayhead({
    super.key,
    required this.left,
    required this.height,
    this.color = const Color(0xFF1769FF),
  });

  final double left;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Positioned(
        left: left - 6,
        top: 0,
        child: IgnorePointer(
          child: SizedBox(
            width: 12,
            height: height,
            child: CustomPaint(painter: _PlayheadPainter(color)),
          ),
        ),
      );
}

class _PlayheadPainter extends CustomPainter {
  const _PlayheadPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(1, 0)
        ..lineTo(size.width - 1, 0)
        ..lineTo(size.width / 2, 7)
        ..close(),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - 1, 6, 2, size.height - 6),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PlayheadPainter oldDelegate) =>
      oldDelegate.color != color;
}
