import 'dart:io';

import 'package:flutter/services.dart';

typedef WindowCommand = Future<void> Function();

/// Window-command boundary. Native implementations can be injected by the
/// Windows runner without coupling feature widgets to a plugin.
class WindowsWindowManager {
  const WindowsWindowManager({
    this.onMinimize,
    this.onToggleMaximize,
    this.onClose,
  });

  final WindowCommand? onMinimize;
  final WindowCommand? onToggleMaximize;
  final WindowCommand? onClose;

  bool get supported => Platform.isWindows;

  Future<void> minimize() async => onMinimize?.call();

  Future<void> toggleMaximize() async => onToggleMaximize?.call();

  Future<void> close() async {
    final command = onClose;
    if (command != null) {
      await command();
      return;
    }
    await SystemNavigator.pop();
  }
}
