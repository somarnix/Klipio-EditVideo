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
        wordsPerLine: wordsPerLine ?? this.wordsPerLine,
      );
}
