import 'package:flutter/material.dart';

/// Central route resolver. Feature pages register builders without making the
/// routing layer depend on editor state or platform services.
class KlipioRouter {
  KlipioRouter(Map<String, WidgetBuilder> routes)
      : _routes = Map.unmodifiable(routes);

  final Map<String, WidgetBuilder> _routes;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final builder = _routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute<void>(
        builder: builder,
        settings: settings,
      );
    }
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => Scaffold(
        body: Center(
          child: Text('Unknown Klipio route: ${settings.name ?? '(null)'}'),
        ),
      ),
    );
  }
}
