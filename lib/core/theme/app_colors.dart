import 'package:flutter/material.dart';

/// Central color tokens for light and dark editor surfaces.
abstract final class AppColors {
  static const Color accent = Color(0xFF12B8C5);
  static const Color accentStrong = Color(0xFF087E88);
  static const Color videoTrack = Color(0xFF00BCD4);
  static const Color audioTrack = Color(0xFF28B87A);
  static const Color captionTrack = Color(0xFFFF7A1A);
  static const Color textTrack = Color(0xFF7554A6);
  static const Color destructive = Color(0xFFE5484D);

  static const Color darkCanvas = Color(0xFF121316);
  static const Color darkPanel = Color(0xFF1E1F24);
  static const Color darkSurface = Color(0xFF26262A);
  static const Color darkDivider = Color(0xFF35363C);
  static const Color darkText = Color(0xFFF4F4F5);
  static const Color darkMutedText = Color(0xFFA7A9B0);

  static const Color lightCanvas = Color(0xFFF4F6F9);
  static const Color lightPanel = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFEDF1F5);
  static const Color lightDivider = Color(0xFFD5DBE3);
  static const Color lightText = Color(0xFF18202B);
  static const Color lightMutedText = Color(0xFF657083);
}
