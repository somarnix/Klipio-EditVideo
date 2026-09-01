import 'package:flutter/material.dart';

enum AppThemeChoice { system, light, dark }

enum PreviewQuality { full, half, low }

class AppTheme {
  static ThemeData get dark => ThemeData.dark(useMaterial3: true);
  static ThemeData get light => ThemeData.light(useMaterial3: true);

  static ThemeMode themeMode(AppThemeChoice choice) {
    return switch (choice) {
      AppThemeChoice.system => ThemeMode.system,
      AppThemeChoice.light => ThemeMode.light,
      AppThemeChoice.dark => ThemeMode.dark,
    };
  }
}
