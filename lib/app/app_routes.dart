import 'package:flutter/material.dart';

abstract final class AppRoutes {
  static const editor = '/editor';
  static const home = '/';

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings, {
    required WidgetBuilder homeBuilder,
    required WidgetBuilder editorBuilder,
  }) {
    final builder = settings.name == editor ? editorBuilder : homeBuilder;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: builder,
    );
  }
}
