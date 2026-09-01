import 'package:flutter/material.dart';

/// Typography scale optimized for a high-density editing workspace.
abstract final class AppTypography {
  static const TextStyle micro = TextStyle(fontSize: 10, height: 1.15);
  static const TextStyle label = TextStyle(fontSize: 11, height: 1.2);
  static const TextStyle body = TextStyle(fontSize: 13, height: 1.3);
  static const TextStyle section = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle panelTitle = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.35,
  );
  static const TextStyle pageTitle = TextStyle(
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
}
