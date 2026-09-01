import 'package:flutter/material.dart';

class CaptionStyle {
  const CaptionStyle({
    required this.id,
    required this.name,
    this.fontFamily = 'Arial',
    this.fontSize = 42,
    this.color = Colors.white,
    this.highlightColor,
    this.backgroundColor = Colors.transparent,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2,
    this.bold = true,
    this.italic = false,
    this.underline = false,
    this.opacity = 1,
    this.shadowColor = Colors.black,
    this.shadowBlur = 0,
    this.shadowOffsetX = 0,
    this.shadowOffsetY = 0,
    this.backgroundOpacity = 0,
    this.borderRadius = 0,
    this.padding = 0,
    this.alignment = TextAlign.center,
    this.position = const Offset(0.5, 0.78),
    this.scale = 1,
    this.rotation = 0,
    this.letterSpacing = 0,
    this.wordSpacing = 0,
    this.lineSpacing = 0,
    this.animation = 'none',
    this.keyframes = const <CaptionStyleKeyframe>[],
    this.wordsPerLine = 4,
  });

  final String id;
  final String name;
  final String fontFamily;
  final double fontSize;
  final Color color;
  final Color? highlightColor;
  final Color backgroundColor;
  final Color strokeColor;
  final double strokeWidth;
  final bool bold;
  final bool italic;
  final bool underline;
  final double opacity;
  final Color shadowColor;
  final double shadowBlur;
  final double shadowOffsetX;
  final double shadowOffsetY;
  final double backgroundOpacity;
  final double borderRadius;
  final double padding;
  final TextAlign alignment;
  final Offset position;
  final double scale;
  final double rotation;
  final double letterSpacing;
  final double wordSpacing;
  final double lineSpacing;
  final String animation;
  final List<CaptionStyleKeyframe> keyframes;
  final int wordsPerLine;

  CaptionStyle copyWith({
    String? fontFamily,
    double? fontSize,
    Color? color,
    Color? highlightColor,
    Color? backgroundColor,
    Color? strokeColor,
    double? strokeWidth,
    bool? bold,
    bool? italic,
    bool? underline,
    double? opacity,
    Color? shadowColor,
    double? shadowBlur,
    double? shadowOffsetX,
    double? shadowOffsetY,
    double? backgroundOpacity,
    double? borderRadius,
    double? padding,
    TextAlign? alignment,
    Offset? position,
    double? scale,
    double? rotation,
    double? letterSpacing,
    double? wordSpacing,
    double? lineSpacing,
    String? animation,
    List<CaptionStyleKeyframe>? keyframes,
    int? wordsPerLine,
  }) =>
      CaptionStyle(
        id: id,
        name: name,
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        color: color ?? this.color,
        highlightColor: highlightColor ?? this.highlightColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        strokeColor: strokeColor ?? this.strokeColor,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        opacity: opacity ?? this.opacity,
        shadowColor: shadowColor ?? this.shadowColor,
        shadowBlur: shadowBlur ?? this.shadowBlur,
        shadowOffsetX: shadowOffsetX ?? this.shadowOffsetX,
        shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
        backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
        borderRadius: borderRadius ?? this.borderRadius,
        padding: padding ?? this.padding,
        alignment: alignment ?? this.alignment,
        position: position ?? this.position,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
        letterSpacing: letterSpacing ?? this.letterSpacing,
        wordSpacing: wordSpacing ?? this.wordSpacing,
        lineSpacing: lineSpacing ?? this.lineSpacing,
        animation: animation ?? this.animation,
        keyframes: keyframes ?? this.keyframes,
        wordsPerLine: wordsPerLine ?? this.wordsPerLine,
      );
}

class CaptionStyleKeyframe {
  const CaptionStyleKeyframe({
    required this.seconds,
    this.position,
    this.scale,
    this.rotation,
    this.opacity,
  });

  final double seconds;
  final Offset? position;
  final double? scale;
  final double? rotation;
  final double? opacity;
}
