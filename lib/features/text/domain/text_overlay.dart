import 'package:flutter/material.dart';

enum TextAnimation {
  none,
  fadeIn,
  fadeOut,
  typewriter,
  slideUp,
  slideDown,
  pop
}

class TextOverlay {
  const TextOverlay({
    required this.id,
    required this.text,
    required this.timelineStart,
    required this.duration,
    this.fontFamily = 'Arial',
    this.fontSize = 48,
    this.color = Colors.white,
    this.strokeColor = Colors.black,
    this.strokeWidth = 0,
    this.shadowColor = Colors.black54,
    this.position = const Offset(0.5, 0.8),
    this.animation = TextAnimation.none,
    this.visible = true,
    this.locked = false,
  });

  final String id;
  final String text;
  final double timelineStart;
  final double duration;
  final String fontFamily;
  final double fontSize;
  final Color color;
  final Color strokeColor;
  final double strokeWidth;
  final Color shadowColor;
  final Offset position;
  final TextAnimation animation;
  final bool visible;
  final bool locked;

  double get timelineEnd => timelineStart + duration;
}
