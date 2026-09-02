import 'package:flutter/material.dart';

import 'editor_colors.dart';

abstract final class EditorStyles {
  static const panelBorder = BorderSide(color: EditorColors.border);
  static const timecode = TextStyle(
    color: EditorColors.text,
    fontSize: 11,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
  static const panelTitle = TextStyle(
    color: EditorColors.text,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.35,
  );
  static const clipRadius = BorderRadius.all(Radius.circular(5));
}
