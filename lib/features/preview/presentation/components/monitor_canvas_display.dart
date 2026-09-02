import 'package:flutter/material.dart';

class MonitorCanvasDisplay extends StatelessWidget {
  const MonitorCanvasDisplay({
    super.key,
    required this.aspectRatio,
    required this.child,
    this.background = Colors.black,
    this.overlays = const [],
  });

  final double aspectRatio;
  final Widget child;
  final Color background;
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: background,
        child: Center(
          child: AspectRatio(
            aspectRatio: aspectRatio <= 0 ? 16 / 9 : aspectRatio,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [child, ...overlays],
              ),
            ),
          ),
        ),
      );
}
