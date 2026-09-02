import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/editor_shell/presentation/modular_editor_workspace.dart';
import 'app_bindings.dart';
import 'app_routes.dart';
import 'dependencies.dart';

class ModularKlipioApp extends StatelessWidget {
  const ModularKlipioApp({
    super.key,
    required this.dependencies,
    this.home,
    this.editor,
    this.themeMode = ThemeMode.dark,
  });

  final AppDependencies dependencies;
  final Widget? home;
  final Widget? editor;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) => AppDependenciesScope(
        dependencies: dependencies,
        child: MaterialApp(
          title: 'Klipio Video Editor',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          initialRoute: AppRoutes.home,
          onGenerateRoute: (settings) => AppRoutes.onGenerateRoute(
            settings,
            homeBuilder: (_) => home ?? const ModularEditorWorkspace(),
            editorBuilder: (_) => editor ?? const ModularEditorWorkspace(),
          ),
        ),
      );
}
