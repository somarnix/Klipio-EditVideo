import 'package:flutter/material.dart';

extension KlipioBuildContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textStyles => Theme.of(this).textTheme;
  MediaQueryData get media => MediaQuery.of(this);
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  bool get isCompactWidth => MediaQuery.sizeOf(this).width < 720;
}
